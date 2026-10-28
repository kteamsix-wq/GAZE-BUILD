package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end

import core.base.MusicBeatState;
import gameplay.Conductor;
import core.utils.CoolUtil;
import gameplay.chart.Song;
import gameplay.chart.Section.SwagSection;
import gameplay.objects.Boyfriend;
import gameplay.objects.Character;
import gameplay.objects.Stage;
import gameplay.PlayState;
import menus.MainMenuState;
import editors.camera.CameraEditorEvent;
import editors.camera.VirtualCameraRectangle;
import core.system.Paths;

using StringTools;

typedef EditorChartNote = {
	var time:Float;
	var data:Int;
	var length:Float;
	var isPlayer:Bool;
	var alt:Bool;
}

/**
 * Camera Editor for Friday Night Funkin' (K-Slice / Gaze Engine).
 * Ported and adapted faithfully from FNF V-Slice Camera Editor.
 */
class CameraEditor extends MusicBeatState
{
	public static var instance:CameraEditor;

	var _song:SwagSong;

	// Chart notes for singing
	var allNotes:Array<EditorChartNote> = [];
	var cachedNoteIndex:Int = 0;
	var cachedEventIndex:Int = 0;
	var lastSection:Int = -1;

	// Stage & Characters
	var stageBuild:Stage;
	var boyfriend:Boyfriend;
	var dadOpponent:Character;
	var gf:Character;
	var defaultStageZoom:Float = 1.05;

	// Virtual Camera Rectangle
	var cameraRect:VirtualCameraRectangle;

	// Cameras
	var camGame:FlxCamera;
	var camUI:FlxCamera;

	// Audio & Conductor
	var songMusic:FlxSound;
	var vocals:FlxSound;
	var isPlaying:Bool = false;

	// Camera Events
	public var events:Array<CameraEditorEvent> = [];
	public var selectedEvent:Null<CameraEditorEvent> = null;

	// Timeline Configuration
	var timelineScrollMs:Float = 0;
	var timelinePixelsPerMs:Float = 0.12; // Base scale: 120px per second
	var timelineZoomScale:Float = 1.0;
	var snapEnabled:Bool = true;
	var snapToBeat:Bool = false; // true = beat (4 steps), false = step (1 step)
	var shiftEnabled:Bool = false;

	public var layers:Array<String> = ["Default", "Focus", "Zoom"];
	var layerColors:Array<FlxColor> = [0xFF2A82BE, 0xFF00AA88, 0xFFCC7700, 0xFFAA3388, 0xFF6655AA];
	public var selectedLayerIndex:Int = 0;

	// High-Performance Object Pools (prevents FPS drops & memory leaks)
	var blockItemPool:Array<TimelineBlockItem> = [];
	var measureTextPool:Array<FlxText> = [];
	var layerLabelPool:Array<FlxText> = [];
	var lastDisplayedSongPos:Float = -999999;
	var loadedChartPath:String = null;

	// UI Groups & Controls
	var uiGroup:FlxTypedGroup<FlxBasic>;
	var timelineGroup:FlxTypedGroup<FlxBasic>;
	var timelineBlocksGroup:FlxTypedGroup<FlxBasic>;
	var inspectorGroup:FlxTypedGroup<FlxBasic>;
	var rulerTextGroup:FlxTypedGroup<FlxText>;

	// Top Bar Elements
	var topBarBG:FlxSprite;
	var titleText:FlxText;
	var songInfoText:FlxText;
	var timeText:FlxText;

	// Mode Buttons
	var btnRelativeView:FlxButton;
	var btnPassepartout:FlxButton;
	var btnExtendedBounds:FlxButton;
	var btnCameraBop:FlxButton;
	var btnCamMarkers:FlxButton;

	// Character Camera Anchor Markers (in world space on camGame)
	var charCamMarkersGroup:FlxTypedGroup<FlxBasic>;
	var markerDad:FlxSprite;
	var markerBf:FlxSprite;
	var markerGf:FlxSprite;
	var labelDad:FlxText;
	var labelBf:FlxText;
	var labelGf:FlxText;
	var showCamMarkers:Bool = true;

	// Timeline Controls
	var btnPlayPause:FlxButton;
	var btnSnap:FlxButton;
	var btnShift:FlxButton;
	var btnAddLayer:FlxButton;
	var btnDeleteLayer:FlxButton;
	var btnZoomIn:FlxButton;
	var btnZoomOut:FlxButton;

	// Timeline Rendering
	var timelineRulerBG:FlxSprite;
	var timelineLanesBG:FlxSprite;
	var playheadLine:FlxSprite;
	var playheadTopper:FlxSprite;

	// Inspector / Properties UI
	var inspectorBG:FlxSprite;
	var inspectorTitle:FlxText;
	var eventTypeLabel:FlxText;

	var focusTargetLabel:FlxText;
	var focusTargetDropDown:FlxUIDropDownMenu;
	var focusOffsetLabel:FlxText;
	var focusXStepper:FlxUINumericStepper;
	var focusYStepper:FlxUINumericStepper;
	var focusDurationLabel:FlxText;
	var focusDurationStepper:FlxUINumericStepper;
	var focusEaseLabel:FlxText;
	var focusEaseInput:FlxUIInputText;
	var focusEaseDropDown:FlxUIDropDownMenu;

	var zoomValLabel:FlxText;
	var zoomValueStepper:FlxUINumericStepper;
	var zoomDurLabel:FlxText;
	var zoomDurationStepper:FlxUINumericStepper;
	var zoomEaseLabel:FlxText;
	var zoomEaseInput:FlxUIInputText;
	var zoomEaseDropDown:FlxUIDropDownMenu;

	var dropdownLastVisible:Map<FlxUIDropDownMenu, Bool> = new Map();
	var dropdownScrollOffsets:Map<FlxUIDropDownMenu, Int> = new Map();
	final MAX_DROPDOWN_VISIBLE:Int = 10;

	var btnDeleteEvent:FlxButton;
	var btnAddFocusEvent:FlxButton;
	var btnAddZoomEvent:FlxButton;
	var btnAutoGen:FlxButton;
	var shortcutsGuideText:FlxText;

	// Mouse Dragging & Timeline Interactions
	var isDraggingPlayhead:Bool = false;
	var isDraggingEventBlock:Bool = false;
	var isResizingEventBlock:Bool = false;
	var draggedEvent:Null<CameraEditorEvent> = null;
	var dragStartMouseX:Float = 0;
	var dragStartEventTime:Float = 0;
	var dragStartEventDuration:Float = 0;

	// Viewport Pan & Zoom
	var isPanningViewport:Bool = false;
	var panStartMouse:FlxPoint = new FlxPoint();
	var panStartCamScroll:FlxPoint = new FlxPoint();

	// Cursor state
	var lastCursor:String = '';

	// Timeline bounds constants
	final TIMELINE_Y:Float = 505;
	final TIMELINE_HEIGHT:Float = 215;
	final TIMELINE_RULER_HEIGHT:Float = 26;
	final LANE_HEIGHT:Float = 44;
	final TIMELINE_LEFT_X:Float = 120;
	final INSPECTOR_X:Float = 980;
	final INSPECTOR_WIDTH:Float = 295;

	var availableEases:Array<String> = [
		"CLASSIC", "INSTANT", "linear",
		"quadIn", "quadOut", "quadInOut",
		"cubeIn", "cubeOut", "cubeInOut",
		"sineIn", "sineOut", "sineInOut",
		"expoIn", "expoOut", "expoInOut",
		"circIn", "circOut", "circInOut",
		"backIn", "backOut", "backInOut",
		"bounceIn", "bounceOut", "bounceInOut",
		"elasticIn", "elasticOut", "elasticInOut",
		"smoothStepIn", "smoothStepOut", "smoothStepInOut"
	];

	override function create():Void
	{
		super.create();
		instance = this;

		// 1. Initialize Mouse Cursor
		FlxG.mouse.visible = true;
		FlxG.mouse.enabled = true;
		FlxG.mouse.useSystemCursor = false;

		var cursorGraphic = Paths.image('menus/editors/cursor-default');
		if (cursorGraphic != null && cursorGraphic.bitmap != null)
		{
			FlxG.mouse.load(cursorGraphic.bitmap);
			lastCursor = 'cursor-default';
		}
		else
		{
			FlxG.mouse.useSystemCursor = true;
		}

		// 2. Resolve Song Data
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
			_song = Song.loadFromJson("bopeebo", "bopeebo");

		#if sys
		var songFolder = _song.song.toLowerCase().trim();
		loadedChartPath = gameplay.chart.ChartConverter.findChartPath(songFolder, songFolder);
		#end

		if (_song.stage == null || _song.stage.trim() == "")
			_song.stage = "stage";

		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);
		Conductor.songPosition = 0;

		// 3. Setup Dual Cameras
		camGame = new FlxCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camUI, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// 4. Load Stage & Characters
		stageBuild = new Stage(_song.stage);
		add(stageBuild.background);

		defaultStageZoom = (stageBuild.stageData != null && stageBuild.stageData.zoom > 0) ? stageBuild.stageData.zoom : 1.05;

		var initBfX:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.BF_POS != null && (stageBuild.stageData.BF_POS[0] != 0 || stageBuild.stageData.BF_POS[1] != 0)) ? stageBuild.stageData.BF_POS[0] : 770;
		var initBfY:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.BF_POS != null && (stageBuild.stageData.BF_POS[0] != 0 || stageBuild.stageData.BF_POS[1] != 0)) ? stageBuild.stageData.BF_POS[1] : 450;
		var initDadX:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.DAD_POS != null && (stageBuild.stageData.DAD_POS[0] != 0 || stageBuild.stageData.DAD_POS[1] != 0)) ? stageBuild.stageData.DAD_POS[0] : 100;
		var initDadY:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.DAD_POS != null && (stageBuild.stageData.DAD_POS[0] != 0 || stageBuild.stageData.DAD_POS[1] != 0)) ? stageBuild.stageData.DAD_POS[1] : 100;
		var initGfX:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.GF_POS != null && (stageBuild.stageData.GF_POS[0] != 0 || stageBuild.stageData.GF_POS[1] != 0)) ? stageBuild.stageData.GF_POS[0] : 400;
		var initGfY:Float = (stageBuild != null && stageBuild.stageData != null && stageBuild.stageData.GF_POS != null && (stageBuild.stageData.GF_POS[0] != 0 || stageBuild.stageData.GF_POS[1] != 0)) ? stageBuild.stageData.GF_POS[1] : 130;

		var daGF:String = (_song.gfVersion != null && _song.gfVersion.length > 0) ? _song.gfVersion : ((_song.player3 != null && _song.player3.length > 0) ? _song.player3 : stageBuild.returnGFtype(_song.stage));
		gf = new Character();
		gf.adjustPos = false;
		gf.setCharacter(initGfX, initGfY, daGF);
		gf.scrollFactor.set(0.95, 0.95);

		dadOpponent = new Character().setCharacter(initDadX, initDadY, _song.player2);
		boyfriend = new Boyfriend();
		boyfriend.setCharacter(initBfX, initBfY, _song.player1);

		var camPos = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
		stageBuild.repositionPlayers(_song.stage, boyfriend, dadOpponent, gf);
		stageBuild.dadPosition(_song.stage, boyfriend, dadOpponent, gf, camPos);
		camPos.put();

		dadOpponent.updateHitbox();
		boyfriend.updateHitbox();
		gf.updateHitbox();

		add(gf);
		add(dadOpponent);
		add(boyfriend);
		add(stageBuild.foreground);

		#if sys
		if (stageBuild != null && stageBuild.interp != null) {
			stageBuild.interp.variables.set("boyfriend", boyfriend);
			stageBuild.interp.variables.set("dad", dadOpponent);
			stageBuild.interp.variables.set("dadOpponent", dadOpponent);
			stageBuild.interp.variables.set("gf", gf);
			stageBuild.interp.variables.set("camGame", camGame);
			stageBuild.interp.variables.set("camHUD", camUI);
		}
		#end

		stageBuild.callScript("onCreatePost", []);
		stageBuild.callScript("createPost", []);
		stageBuild.callScript("postCreate", []);

		dadOpponent.dance();
		gf.dance();
		boyfriend.dance();

		// 5. Virtual Camera Rectangle
		cameraRect = new VirtualCameraRectangle(0, 0);
		cameraRect.currentStage = stageBuild;
		cameraRect.boyfriend = boyfriend;
		cameraRect.dad = dadOpponent;
		cameraRect.gf = gf;
		cameraRect.zoom = defaultStageZoom;
		cameraRect.cacheIdleCameraPoints();
		add(cameraRect);

		// Character Base Camera Anchor Markers (drawn in world space on camGame)
		charCamMarkersGroup = new FlxTypedGroup<FlxBasic>();
		charCamMarkersGroup.cameras = [camGame];

		markerDad = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_center'));
		markerDad.color = 0xFFFF2255;
		charCamMarkersGroup.add(markerDad);

		labelDad = new FlxText(0, 0, 0, "DAD CAM", 12);
		labelDad.setFormat(Paths.font("vcr.ttf"), 12, 0xFFFF2255, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charCamMarkersGroup.add(labelDad);

		markerBf = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_center'));
		markerBf.color = 0xFF00FFCC;
		charCamMarkersGroup.add(markerBf);

		labelBf = new FlxText(0, 0, 0, "BF CAM", 12);
		labelBf.setFormat(Paths.font("vcr.ttf"), 12, 0xFF00FFCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charCamMarkersGroup.add(labelBf);

		markerGf = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_center'));
		markerGf.color = 0xFFFF66CC;
		charCamMarkersGroup.add(markerGf);

		labelGf = new FlxText(0, 0, 0, "GF CAM", 12);
		labelGf.setFormat(Paths.font("vcr.ttf"), 12, 0xFFFF66CC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charCamMarkersGroup.add(labelGf);

		add(charCamMarkersGroup);
		updateCamMarkers();

		// Center camera viewport on stage default
		var defPos = cameraRect.getDefaultPosition();
		cameraRect.setFocusPoint(defPos.x, defPos.y, true);
		camGame.focusOn(new FlxPoint(defPos.x, defPos.y));
		camGame.zoom = 0.75; // Comfortable overview zoom for editing
		defPos.put();

		// 6. Load Audio
		loadAudio();

		// 7. Build UI System (All explicitly bound to camUI)
		uiGroup = new FlxTypedGroup<FlxBasic>();
		timelineGroup = new FlxTypedGroup<FlxBasic>();
		timelineBlocksGroup = new FlxTypedGroup<FlxBasic>();
		rulerTextGroup = new FlxTypedGroup<FlxText>();
		inspectorGroup = new FlxTypedGroup<FlxBasic>();

		uiGroup.cameras = [camUI];
		timelineGroup.cameras = [camUI];
		timelineBlocksGroup.cameras = [camUI];
		rulerTextGroup.cameras = [camUI];
		inspectorGroup.cameras = [camUI];

		buildTopBar();
		buildInspector();
		buildTimeline();

		add(uiGroup);
		add(timelineGroup);
		add(timelineBlocksGroup);
		add(rulerTextGroup);
		add(inspectorGroup);

		// 8. Parse Song Events into Camera Events & Notes
		loadEventsFromSong();
		loadNotesFromSong();

		// Replay timeline at start
		replayCameraTimeline(0);
		refreshEventBlocks();
		updateInspectorUI();
	}

	override function destroy():Void
	{
		FlxG.mouse.unload();
		FlxG.mouse.visible = false;
		super.destroy();
	}

	function changeCursor(cursorType:String):Void
	{
		if (lastCursor != cursorType)
		{
			var grp = Paths.image('menus/editors/' + cursorType);
			if (grp != null && grp.bitmap != null)
			{
				FlxG.mouse.load(grp.bitmap);
			}
			lastCursor = cursorType;
		}
	}

	/**
	 * Helper function that sets an element's camera to camUI and resets scrollFactor.
	 */
	function bindUI<T:FlxBasic>(basic:T):T
	{
		if (basic == null) return null;
		basic.cameras = [camUI];
		if (Std.isOfType(basic, FlxSprite))
		{
			var spr:FlxSprite = cast basic;
			spr.scrollFactor.set(0, 0);
		}
		if (Std.isOfType(basic, FlxButton))
		{
			var btn:FlxButton = cast basic;
			btn.scrollFactor.set(0, 0);
			if (btn.label != null)
			{
				btn.label.cameras = [camUI];
				btn.label.scrollFactor.set(0, 0);
			}
		}
		if (Std.isOfType(basic, FlxSpriteGroup))
		{
			var grp:FlxSpriteGroup = cast basic;
			grp.scrollFactor.set(0, 0);
			grp.forEach(function(s) {
				s.cameras = [camUI];
				s.scrollFactor.set(0, 0);
			});
		}
		return basic;
	}

	inline function resizeButton(btn:FlxButton, w:Int, h:Int):Void
	{
		btn.setGraphicSize(w, h);
		btn.updateHitbox();
		if (btn.label != null)
		{
			btn.label.fieldWidth = w;
		}
	}

	function loadAudio():Void
	{
		if (songMusic != null)
		{
			songMusic.stop();
			songMusic.destroy();
			songMusic = null;
		}

		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
			vocals = null;
		}

		try
		{
			songMusic = new FlxSound().load(Paths.inst(_song.song));
			songMusic.autoDestroy = false;
			FlxG.sound.list.add(songMusic);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Could not load inst for ${_song.song}: $e');
		}

		if (_song.needsVoices)
		{
			try
			{
				vocals = new FlxSound().load(Paths.voices(_song.song));
				vocals.autoDestroy = false;
				FlxG.sound.list.add(vocals);
			}
			catch (e:Dynamic) {}
		}
	}

	function loadEventsFromSong():Void
	{
		events = [];
		if (_song.events != null)
		{
			for (evRaw in _song.events)
			{
				var parsedList = CameraEditorEvent.parseAllFromRaw(evRaw);
				for (parsed in parsedList)
				{
					parsed.layer = (parsed.name == "ZoomCamera") ? 2 : 1;
					events.push(parsed);
				}
			}
		}

		var hasFocusEvents = false;
		for (e in events)
		{
			if (e.name == "FocusCamera")
			{
				hasFocusEvents = true;
				break;
			}
		}

		if (!hasFocusEvents)
		{
			autoGenEvents(false);
		}
		else
		{
			sortEvents();
		}
	}

	function sortEvents():Void
	{
		events.sort(function(a, b) {
			if (a.time < b.time) return -1;
			if (a.time > b.time) return 1;
			return 0;
		});
	}

	function loadNotesFromSong():Void
	{
		allNotes = [];
		if (_song == null || _song.notes == null) return;

		for (sec in _song.notes)
		{
			if (sec == null || sec.sectionNotes == null) continue;
			var secAlt:Bool = (sec.altAnim == true);

			for (n in sec.sectionNotes)
			{
				if (n == null || n.length < 2) continue;
				var strumTime:Float = n[0];
				var rawData:Int = Std.int(n[1]);
				var susLen:Float = (n.length > 2 && n[2] != null) ? Math.max(0, n[2]) : 0;
				var isPlayer:Bool = (rawData >= 4);

				var noteAlt:Bool = secAlt;
				if (n.length > 3 && n[3] != null)
				{
					var noteType = Std.string(n[3]).toLowerCase().trim();
					if (noteType == "alt" || noteType == "alt animation" || noteType == "1")
						noteAlt = true;
				}

				allNotes.push({
					time: strumTime,
					data: rawData % 4,
					length: susLen,
					isPlayer: isPlayer,
					alt: noteAlt
				});
			}
		}

		allNotes.sort(function(a, b) {
			if (a.time < b.time) return -1;
			if (a.time > b.time) return 1;
			return 0;
		});
	}

	/* =================================================================================
	 * TOP MENU BAR
	 * ================================================================================= */
	function buildTopBar():Void
	{
		topBarBG = bindUI(new FlxSprite(0, 0).makeGraphic(FlxG.width, 42, 0xEE14141E));
		uiGroup.add(topBarBG);

		var borderLine = bindUI(new FlxSprite(0, 41).makeGraphic(FlxG.width, 2, 0xFF2A2A3E));
		uiGroup.add(borderLine);

		titleText = bindUI(new FlxText(12, 10, 0, "CAMERA EDITOR", 16));
		titleText.setFormat(Paths.font("vcr.ttf"), 16, 0xFF00FFCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		uiGroup.add(titleText);

		songInfoText = bindUI(new FlxText(180, 12, 0, '${_song.song.toUpperCase()}  (${_song.bpm} BPM)', 13));
		songInfoText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		uiGroup.add(songInfoText);

		// View Mode Buttons with V-Slice Icons
		var btnY:Int = 6;

		// 1. Relative View Toggle
		btnRelativeView = bindUI(new FlxButton(430, btnY, "", function() {
			cameraRect.isRelative = !cameraRect.isRelative;
			btnRelativeView.color = cameraRect.isRelative ? 0xFF00FFCC : FlxColor.WHITE;
			if (!cameraRect.isRelative)
			{
				var defPos = cameraRect.getDefaultPosition();
				camGame.focusOn(defPos);
				camGame.zoom = 0.75;
				defPos.put();
			}
			else
			{
				camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
				camGame.zoom = cameraRect.zoom;
			}
		}));
		btnRelativeView.loadGraphic(Paths.image('menus/editors/camera/menu-bar/relative_view'));
		btnRelativeView.setGraphicSize(28, 28);
		btnRelativeView.updateHitbox();
		uiGroup.add(btnRelativeView);

		// 2. Passepartout Toggle
		btnPassepartout = bindUI(new FlxButton(465, btnY, "", function() {
			cameraRect.showPassepartout = !cameraRect.showPassepartout;
			btnPassepartout.color = cameraRect.showPassepartout ? 0xFF00FFCC : FlxColor.WHITE;
		}));
		btnPassepartout.loadGraphic(Paths.image('menus/editors/camera/menu-bar/passepartout'));
		btnPassepartout.setGraphicSize(28, 28);
		btnPassepartout.updateHitbox();
		uiGroup.add(btnPassepartout);

		// 3. Extended Bounds Toggle
		btnExtendedBounds = bindUI(new FlxButton(500, btnY, "", function() {
			cameraRect.showExtendedBounds = !cameraRect.showExtendedBounds;
			btnExtendedBounds.color = cameraRect.showExtendedBounds ? 0xFF00FFCC : FlxColor.WHITE;
		}));
		btnExtendedBounds.loadGraphic(Paths.image('menus/editors/camera/menu-bar/extended_vcam'));
		btnExtendedBounds.setGraphicSize(28, 28);
		btnExtendedBounds.updateHitbox();
		uiGroup.add(btnExtendedBounds);

		// 4. Camera Bop Toggle
		btnCameraBop = bindUI(new FlxButton(535, btnY + 2, "BOP: OFF", function() {
			cameraRect.doBopping = !cameraRect.doBopping;
			btnCameraBop.text = cameraRect.doBopping ? "BOP: ON" : "BOP: OFF";
			btnCameraBop.color = cameraRect.doBopping ? 0xFF00FFCC : FlxColor.WHITE;
		}));
		resizeButton(btnCameraBop, 60, 24);
		uiGroup.add(btnCameraBop);

		// 5. Camera Anchor Points Toggle
		btnCamMarkers = bindUI(new FlxButton(600, btnY + 2, "PTS: ON", function() {
			showCamMarkers = !showCamMarkers;
			if (charCamMarkersGroup != null)
				charCamMarkersGroup.visible = showCamMarkers;
			btnCamMarkers.text = showCamMarkers ? "PTS: ON" : "PTS: OFF";
			btnCamMarkers.color = showCamMarkers ? 0xFF00FFCC : FlxColor.WHITE;
		}));
		resizeButton(btnCamMarkers, 60, 24);
		btnCamMarkers.color = 0xFF00FFCC;
		uiGroup.add(btnCamMarkers);

		// Time readout
		timeText = bindUI(new FlxText(665, 12, 255, "00:00.00 | Step 0 | Beat 0", 12));
		timeText.setFormat(Paths.font("vcr.ttf"), 12, 0xFFEEEEEE, RIGHT);
		uiGroup.add(timeText);

		// Top Actions
		var btnSave = bindUI(new FlxButton(930, btnY + 2, "Save Chart", saveEventsToSong));
		resizeButton(btnSave, 75, 24);
		uiGroup.add(btnSave);

		var btnChartEd = bindUI(new FlxButton(1015, btnY + 2, "Chart Editor", function() {
			saveEventsToSong();
			Main.switchState(this, new ChartEditor());
		}));
		resizeButton(btnChartEd, 80, 24);
		uiGroup.add(btnChartEd);

		var btnExit = bindUI(new FlxButton(1105, btnY + 2, "Exit", function() {
			saveEventsToSong();
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new MainMenuState());
		}));
		resizeButton(btnExit, 60, 24);
		btnExit.color = 0xFFFF5555;
		uiGroup.add(btnExit);
	}

	function updateCamMarkers():Void
	{
		if (cameraRect == null) return;
		var dadPt = cameraRect.getCharacterCameraPoint(1);
		var bfPt = cameraRect.getCharacterCameraPoint(0);
		var gfPt = cameraRect.getCharacterCameraPoint(2);

		if (markerDad != null)
			markerDad.setPosition(dadPt.x - (markerDad.width / 2.0), dadPt.y - (markerDad.height / 2.0));
		if (labelDad != null)
		{
			labelDad.text = 'DAD CAM [${Math.round(dadPt.x)}, ${Math.round(dadPt.y)}]';
			labelDad.setPosition(dadPt.x + 12, dadPt.y - 16);
		}

		if (markerBf != null)
			markerBf.setPosition(bfPt.x - (markerBf.width / 2.0), bfPt.y - (markerBf.height / 2.0));
		if (labelBf != null)
		{
			labelBf.text = 'BF CAM [${Math.round(bfPt.x)}, ${Math.round(bfPt.y)}]';
			labelBf.setPosition(bfPt.x + 12, bfPt.y - 16);
		}

		if (markerGf != null)
			markerGf.setPosition(gfPt.x - (markerGf.width / 2.0), gfPt.y - (markerGf.height / 2.0));
		if (labelGf != null)
		{
			labelGf.text = 'GF CAM [${Math.round(gfPt.x)}, ${Math.round(gfPt.y)}]';
			labelGf.setPosition(gfPt.x + 12, gfPt.y - 16);
		}

		dadPt.put();
		bfPt.put();
		gfPt.put();
	}

	/* =================================================================================
	 * RIGHT INSPECTOR & PROPERTIES PANEL
	 * ================================================================================= */
	function buildInspector():Void
	{
		inspectorBG = bindUI(new FlxSprite(INSPECTOR_X, 42).makeGraphic(Std.int(INSPECTOR_WIDTH), Std.int(TIMELINE_Y - 42), 0xEE181824));
		inspectorGroup.add(inspectorBG);

		var leftBorder = bindUI(new FlxSprite(INSPECTOR_X - 2, 42).makeGraphic(2, Std.int(TIMELINE_Y - 42), 0xFF2A2A3E));
		inspectorGroup.add(leftBorder);

		inspectorTitle = bindUI(new FlxText(INSPECTOR_X + 12, 50, INSPECTOR_WIDTH - 24, "STAGE & CAMERA", 15));
		inspectorTitle.setFormat(Paths.font("vcr.ttf"), 15, 0xFF00FFCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		inspectorGroup.add(inspectorTitle);

		eventTypeLabel = bindUI(new FlxText(INSPECTOR_X + 12, 75, INSPECTOR_WIDTH - 24, "No event selected", 12));
		eventTypeLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE);
		inspectorGroup.add(eventTypeLabel);

		// Focus Camera UI
		focusTargetLabel = bindUI(new FlxText(INSPECTOR_X + 12, 100, 0, "Target Character:"));
		inspectorGroup.add(focusTargetLabel);

		var charChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)", "Custom Point (-1)"];
		focusTargetDropDown = bindUI(new FlxUIDropDownMenu(INSPECTOR_X + 12, 118, FlxUIDropDownMenu.makeStrIdLabelArray(charChoices, true), function(chosen:String) {
			if (selectedEvent != null && selectedEvent.name == "FocusCamera")
			{
				var idx = Std.parseInt(chosen);
				selectedEvent.target = (idx == 3) ? -1 : idx;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		focusTargetDropDown.dropDirection = Down;
		focusTargetDropDown.selectedLabel = charChoices[0];

		focusOffsetLabel = bindUI(new FlxText(INSPECTOR_X + 12, 150, 0, "Offset X / Y:"));
		inspectorGroup.add(focusOffsetLabel);

		focusXStepper = bindUI(new FlxUINumericStepper(INSPECTOR_X + 12, 168, 10, 0, -2000, 2000, 0));
		focusXStepper.name = 'focus_x';
		inspectorGroup.add(focusXStepper);

		focusYStepper = bindUI(new FlxUINumericStepper(INSPECTOR_X + 110, 168, 10, 0, -2000, 2000, 0));
		focusYStepper.name = 'focus_y';
		inspectorGroup.add(focusYStepper);

		focusDurationLabel = bindUI(new FlxText(INSPECTOR_X + 12, 200, 0, "Duration (steps):"));
		inspectorGroup.add(focusDurationLabel);

		focusDurationStepper = bindUI(new FlxUINumericStepper(INSPECTOR_X + 12, 218, 0.5, 4.0, 0, 128, 1));
		focusDurationStepper.name = 'focus_duration';
		inspectorGroup.add(focusDurationStepper);

		focusEaseLabel = bindUI(new FlxText(INSPECTOR_X + 12, 250, 0, "Easing Function (Type / Select):"));
		inspectorGroup.add(focusEaseLabel);

		focusEaseInput = bindUI(new FlxUIInputText(INSPECTOR_X + 12, 268, 115, "CLASSIC", 8));
		focusEaseInput.backgroundColor = 0xFF222233;
		focusEaseInput.color = FlxColor.WHITE;
		focusEaseInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "FocusCamera")
			{
				selectedEvent.ease = text.trim();
				focusEaseDropDown.selectedLabel = text.trim();
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		};
		inspectorGroup.add(focusEaseInput);

		focusEaseDropDown = bindUI(new FlxUIDropDownMenu(INSPECTOR_X + 133, 268, FlxUIDropDownMenu.makeStrIdLabelArray(availableEases, true), function(easeIdx:String) {
			if (selectedEvent != null)
			{
				var chosen = availableEases[Std.parseInt(easeIdx)];
				selectedEvent.ease = chosen;
				if (focusEaseInput != null)
					focusEaseInput.text = chosen;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		focusEaseDropDown.dropDirection = Down;

		// Zoom UI
		zoomValLabel = bindUI(new FlxText(INSPECTOR_X + 12, 100, 0, "Target Zoom:"));
		inspectorGroup.add(zoomValLabel);

		zoomValueStepper = bindUI(new FlxUINumericStepper(INSPECTOR_X + 12, 118, 0.05, 1.0, 0.1, 5.0, 2));
		zoomValueStepper.name = 'zoom_val';
		inspectorGroup.add(zoomValueStepper);

		zoomDurLabel = bindUI(new FlxText(INSPECTOR_X + 12, 150, 0, "Duration (steps):"));
		inspectorGroup.add(zoomDurLabel);

		zoomDurationStepper = bindUI(new FlxUINumericStepper(INSPECTOR_X + 12, 168, 0.5, 4.0, 0, 128, 1));
		zoomDurationStepper.name = 'zoom_dur';
		inspectorGroup.add(zoomDurationStepper);

		zoomEaseLabel = bindUI(new FlxText(INSPECTOR_X + 12, 200, 0, "Easing Function (Type / Select):"));
		inspectorGroup.add(zoomEaseLabel);

		zoomEaseInput = bindUI(new FlxUIInputText(INSPECTOR_X + 12, 218, 115, "linear", 8));
		zoomEaseInput.backgroundColor = 0xFF222233;
		zoomEaseInput.color = FlxColor.WHITE;
		zoomEaseInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "ZoomCamera")
			{
				selectedEvent.ease = text.trim();
				zoomEaseDropDown.selectedLabel = text.trim();
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		};
		inspectorGroup.add(zoomEaseInput);

		zoomEaseDropDown = bindUI(new FlxUIDropDownMenu(INSPECTOR_X + 133, 218, FlxUIDropDownMenu.makeStrIdLabelArray(availableEases, true), function(easeIdx:String) {
			if (selectedEvent != null)
			{
				var chosen = availableEases[Std.parseInt(easeIdx)];
				selectedEvent.ease = chosen;
				if (zoomEaseInput != null)
					zoomEaseInput.text = chosen;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		zoomEaseDropDown.dropDirection = Down;

		// Buttons
		btnDeleteEvent = bindUI(new FlxButton(INSPECTOR_X + 12, 310, "Delete Event", function() {
			if (selectedEvent != null)
			{
				events.remove(selectedEvent);
				selectedEvent = null;
				refreshEventBlocks();
				updateInspectorUI();
				replayCameraTimeline(Conductor.songPosition);
			}
		}));
		resizeButton(btnDeleteEvent, 100, 25);
		btnDeleteEvent.color = 0xFFFF4444;
		inspectorGroup.add(btnDeleteEvent);

		btnAddFocusEvent = bindUI(new FlxButton(INSPECTOR_X + 12, 345, "+ Add Focus Event", function() {
			var ev = new CameraEditorEvent(Conductor.songPosition, "FocusCamera", 1);
			ev.target = 0; // BF
			ev.duration = 4.0;
			ev.ease = "CLASSIC";
			events.push(ev);
			sortEvents();
			selectedEvent = ev;
			refreshEventBlocks();
			updateInspectorUI();
			replayCameraTimeline(Conductor.songPosition);
		}));
		resizeButton(btnAddFocusEvent, 120, 25);
		btnAddFocusEvent.color = 0xFF00AA88;
		inspectorGroup.add(btnAddFocusEvent);

		btnAddZoomEvent = bindUI(new FlxButton(INSPECTOR_X + 140, 345, "+ Add Zoom Event", function() {
			var ev = new CameraEditorEvent(Conductor.songPosition, "ZoomCamera", 2);
			ev.zoom = 1.2;
			ev.duration = 4.0;
			ev.ease = "linear";
			events.push(ev);
			sortEvents();
			selectedEvent = ev;
			refreshEventBlocks();
			updateInspectorUI();
			replayCameraTimeline(Conductor.songPosition);
		}));
		resizeButton(btnAddZoomEvent, 120, 25);
		btnAddZoomEvent.color = 0xFFCC7700;
		inspectorGroup.add(btnAddZoomEvent);

		btnAutoGen = bindUI(new FlxButton(INSPECTOR_X + 12, 380, "Auto-Generate Events", function() {
			autoGenEvents(true);
		}));
		resizeButton(btnAutoGen, 160, 25);
		btnAutoGen.color = 0xFF5577AA;
		inspectorGroup.add(btnAutoGen);

		shortcutsGuideText = bindUI(new FlxText(INSPECTOR_X + 12, 415, INSPECTOR_WIDTH - 24,
			"SHORTCUTS:\n" +
			"Space: Play/Pause | Home: Rewind\n" +
			"Left/Right: Step (Shift: Measure)\n" +
			"Right Drag: Pan View | Wheel: Zoom View\n" +
			"R: Reset View | P: Cam Points | Del: Remove\n" +
			"Drag Block: Move | Drag Edge: Duration", 9));
		shortcutsGuideText.setFormat(Paths.font("vcr.ttf"), 9, 0xFFAAAAAA, LEFT);
		inspectorGroup.add(shortcutsGuideText);

		// Dropdowns added last so they overlay on top
		inspectorGroup.add(focusEaseDropDown);
		inspectorGroup.add(focusTargetDropDown);
		inspectorGroup.add(zoomEaseDropDown);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			if (selectedEvent != null)
			{
				switch (nums.name)
				{
					case 'focus_x':
						selectedEvent.x = nums.value;
						if (cameraRect != null)
						{
							var base = cameraRect.getCharacterCameraPoint(selectedEvent.target);
							var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : ((selectedEvent.target == 2) ? "GF" : "CUSTOM"));
							eventTypeLabel.text = 'Time: ${Math.round(selectedEvent.time)}ms | Target: ${targetName}\nCam Point: (${Math.round(base.x + selectedEvent.x)}, ${Math.round(base.y + selectedEvent.y)})';
							base.put();
						}
					case 'focus_y':
						selectedEvent.y = nums.value;
						if (cameraRect != null)
						{
							var base = cameraRect.getCharacterCameraPoint(selectedEvent.target);
							var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : ((selectedEvent.target == 2) ? "GF" : "CUSTOM"));
							eventTypeLabel.text = 'Time: ${Math.round(selectedEvent.time)}ms | Target: ${targetName}\nCam Point: (${Math.round(base.x + selectedEvent.x)}, ${Math.round(base.y + selectedEvent.y)})';
							base.put();
						}
					case 'focus_duration':
						selectedEvent.duration = Math.max(0.5, nums.value);
						refreshEventBlocks();
					case 'zoom_val':
						selectedEvent.zoom = nums.value;
					case 'zoom_dur':
						selectedEvent.duration = Math.max(0.5, nums.value);
						refreshEventBlocks();
				}
				replayCameraTimeline(Conductor.songPosition);
			}
		}
	}

	function updateInspectorUI():Void
	{
		var hasSel:Bool = (selectedEvent != null);

		// Hide any open dropdown lists when updating inspector state
		if (focusEaseDropDown != null && focusEaseDropDown.dropPanel != null && focusEaseDropDown.dropPanel.visible)
			@:privateAccess focusEaseDropDown.showList(false);
		if (zoomEaseDropDown != null && zoomEaseDropDown.dropPanel != null && zoomEaseDropDown.dropPanel.visible)
			@:privateAccess zoomEaseDropDown.showList(false);
		if (focusTargetDropDown != null && focusTargetDropDown.dropPanel != null && focusTargetDropDown.dropPanel.visible)
			@:privateAccess focusTargetDropDown.showList(false);

		if (!hasSel)
		{
			inspectorTitle.text = "STAGE & CAMERA";
			eventTypeLabel.text = 'Stage: ${_song.stage}\nDefault Zoom: ${defaultStageZoom}x';

			focusTargetLabel.visible = false;
			focusTargetDropDown.visible = false;
			focusOffsetLabel.visible = false;
			focusXStepper.visible = false;
			focusYStepper.visible = false;
			focusDurationLabel.visible = false;
			focusDurationStepper.visible = false;
			focusEaseLabel.visible = false;
			focusEaseInput.visible = false;
			focusEaseDropDown.visible = false;

			zoomValLabel.visible = false;
			zoomDurLabel.visible = false;
			zoomEaseLabel.visible = false;
			zoomValueStepper.visible = false;
			zoomDurationStepper.visible = false;
			zoomEaseInput.visible = false;
			zoomEaseDropDown.visible = false;

			btnDeleteEvent.visible = false;
		}
		else if (selectedEvent.name == "FocusCamera")
		{
			inspectorTitle.text = "FOCUS CAMERA";
			var base = cameraRect != null ? cameraRect.getCharacterCameraPoint(selectedEvent.target) : FlxPoint.get(0, 0);
			var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : ((selectedEvent.target == 2) ? "GF" : "CUSTOM"));
			eventTypeLabel.text = 'Time: ${Math.round(selectedEvent.time)}ms | Target: ${targetName}\nCam Point: (${Math.round(base.x + selectedEvent.x)}, ${Math.round(base.y + selectedEvent.y)})';
			base.put();

			focusTargetLabel.visible = true;
			focusTargetDropDown.visible = true;
			focusOffsetLabel.visible = true;
			focusXStepper.visible = true;
			focusYStepper.visible = true;
			focusDurationLabel.visible = true;
			focusDurationStepper.visible = true;
			focusEaseLabel.visible = true;
			focusEaseInput.visible = true;
			focusEaseDropDown.visible = true;

			focusXStepper.value = selectedEvent.x;
			focusYStepper.value = selectedEvent.y;
			focusDurationStepper.value = selectedEvent.duration;
			focusEaseInput.text = selectedEvent.ease;
			focusEaseDropDown.selectedLabel = selectedEvent.ease;

			var targetIdx = (selectedEvent.target == -1) ? 3 : selectedEvent.target;
			var charChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)", "Custom Point (-1)"];
			if (targetIdx >= 0 && targetIdx < charChoices.length)
				focusTargetDropDown.selectedLabel = charChoices[targetIdx];

			zoomValLabel.visible = false;
			zoomDurLabel.visible = false;
			zoomEaseLabel.visible = false;
			zoomValueStepper.visible = false;
			zoomDurationStepper.visible = false;
			zoomEaseInput.visible = false;
			zoomEaseDropDown.visible = false;

			btnDeleteEvent.visible = true;
		}
		else if (selectedEvent.name == "ZoomCamera")
		{
			inspectorTitle.text = "ZOOM CAMERA";
			eventTypeLabel.text = 'Time: ${Math.round(selectedEvent.time)}ms';

			focusTargetLabel.visible = false;
			focusTargetDropDown.visible = false;
			focusOffsetLabel.visible = false;
			focusXStepper.visible = false;
			focusYStepper.visible = false;
			focusDurationLabel.visible = false;
			focusDurationStepper.visible = false;
			focusEaseLabel.visible = false;
			focusEaseInput.visible = false;
			focusEaseDropDown.visible = false;

			zoomValLabel.visible = true;
			zoomDurLabel.visible = true;
			zoomEaseLabel.visible = true;
			zoomValueStepper.visible = true;
			zoomDurationStepper.visible = true;
			zoomEaseInput.visible = true;
			zoomEaseDropDown.visible = true;

			zoomValueStepper.value = selectedEvent.zoom;
			zoomDurationStepper.value = selectedEvent.duration;
			zoomEaseInput.text = selectedEvent.ease;
			zoomEaseDropDown.selectedLabel = selectedEvent.ease;

			btnDeleteEvent.visible = true;
		}
	}

	/* =================================================================================
	 * MULTI-TRACK EVENT TIMELINE
	 * ================================================================================= */
	function buildTimeline():Void
	{
		// 1. Timeline Toolbar Bar (y: 505 to 535)
		var toolbarBG = bindUI(new FlxSprite(0, TIMELINE_Y).makeGraphic(FlxG.width, 30, 0xEE161622));
		timelineGroup.add(toolbarBG);

		var toolBorder = bindUI(new FlxSprite(0, TIMELINE_Y + 29).makeGraphic(FlxG.width, 1, 0xFF2A2A3E));
		timelineGroup.add(toolBorder);

		// Play / Pause Button with V-Slice Icons
		btnPlayPause = bindUI(new FlxButton(8, TIMELINE_Y + 3, "", togglePlayback));
		btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/play'));
		btnPlayPause.setGraphicSize(24, 24);
		btnPlayPause.updateHitbox();
		timelineGroup.add(btnPlayPause);

		// Magnet Snap Toggle
		btnSnap = bindUI(new FlxButton(40, TIMELINE_Y + 3, "", function() {
			snapEnabled = !snapEnabled;
			btnSnap.loadGraphic(Paths.image(snapEnabled ? 'menus/editors/camera/magnet_snap_on' : 'menus/editors/camera/magnet_snap_off'));
			btnSnap.setGraphicSize(24, 24);
			btnSnap.updateHitbox();
		}));
		btnSnap.loadGraphic(Paths.image('menus/editors/camera/magnet_snap_on'));
		btnSnap.setGraphicSize(24, 24);
		btnSnap.updateHitbox();
		timelineGroup.add(btnSnap);

		// Magnet Shift Toggle
		btnShift = bindUI(new FlxButton(70, TIMELINE_Y + 3, "", function() {
			shiftEnabled = !shiftEnabled;
			btnShift.loadGraphic(Paths.image(shiftEnabled ? 'menus/editors/camera/magnet_shift_on' : 'menus/editors/camera/magnet_shift_off'));
			btnShift.setGraphicSize(24, 24);
			btnShift.updateHitbox();
		}));
		btnShift.loadGraphic(Paths.image('menus/editors/camera/magnet_shift_off'));
		btnShift.setGraphicSize(24, 24);
		btnShift.updateHitbox();
		timelineGroup.add(btnShift);

		// Add Layer / Delete Layer
		btnAddLayer = bindUI(new FlxButton(104, TIMELINE_Y + 3, "", function() {
			layers.push('Layer ${layers.length}');
			refreshTimelineLanes();
		}));
		btnAddLayer.loadGraphic(Paths.image('menus/editors/camera/add_layer'));
		btnAddLayer.setGraphicSize(24, 24);
		btnAddLayer.updateHitbox();
		timelineGroup.add(btnAddLayer);

		btnDeleteLayer = bindUI(new FlxButton(134, TIMELINE_Y + 3, "", function() {
			if (layers.length > 1)
			{
				layers.pop();
				refreshTimelineLanes();
			}
		}));
		btnDeleteLayer.loadGraphic(Paths.image('menus/editors/camera/delete_layer'));
		btnDeleteLayer.setGraphicSize(24, 24);
		btnDeleteLayer.updateHitbox();
		timelineGroup.add(btnDeleteLayer);

		// Zoom in / out buttons
		btnZoomIn = bindUI(new FlxButton(170, TIMELINE_Y + 4, "+", function() {
			timelineZoomScale = Math.min(3.0, timelineZoomScale + 0.25);
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
		}));
		resizeButton(btnZoomIn, 22, 22);
		timelineGroup.add(btnZoomIn);

		btnZoomOut = bindUI(new FlxButton(196, TIMELINE_Y + 4, "-", function() {
			timelineZoomScale = Math.max(0.4, timelineZoomScale - 0.25);
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
		}));
		resizeButton(btnZoomOut, 22, 22);
		timelineGroup.add(btnZoomOut);

		// 2. Timeline Ruler Header (y: 535 to 561) - 1x1 scaled sprite
		timelineRulerBG = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFF1C1C28));
		timelineRulerBG.scale.set(FlxG.width - TIMELINE_LEFT_X, TIMELINE_RULER_HEIGHT);
		timelineRulerBG.updateHitbox();
		timelineGroup.add(timelineRulerBG);

		// Track Left Headers Panel
		var leftHeaderBG = bindUI(new FlxSprite(0, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFF12121A));
		leftHeaderBG.scale.set(TIMELINE_LEFT_X, TIMELINE_HEIGHT - 30);
		leftHeaderBG.updateHitbox();
		timelineGroup.add(leftHeaderBG);

		// 3. Timeline Lanes BG
		timelineLanesBG = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT).makeGraphic(1, 1, 0xFF0E0E16));
		timelineLanesBG.scale.set(FlxG.width - TIMELINE_LEFT_X, TIMELINE_HEIGHT - 30 - TIMELINE_RULER_HEIGHT);
		timelineLanesBG.updateHitbox();
		timelineGroup.add(timelineLanesBG);

		// Playhead Line & Topper
		playheadLine = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFFFF3333));
		playheadLine.scale.set(2, TIMELINE_HEIGHT - 30);
		playheadLine.updateHitbox();
		timelineGroup.add(playheadLine);

		playheadTopper = bindUI(new FlxSprite(TIMELINE_LEFT_X - 6, TIMELINE_Y + 28).loadGraphic(Paths.image('menus/editors/camera/triangle')));
		timelineGroup.add(playheadTopper);

		refreshTimelineLanes();
	}

	function refreshTimelineLanes():Void
	{
		if (rulerTextGroup == null) return;

		// 1. Layer Labels on Left (Pool & Reuse to prevent GC stutter)
		for (i in 0...layers.length)
		{
			var laneY = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (i * LANE_HEIGHT);
			var layerLabel:FlxText;
			if (i < layerLabelPool.length)
			{
				layerLabel = layerLabelPool[i];
			}
			else
			{
				layerLabel = bindUI(new FlxText(8, laneY + 12, TIMELINE_LEFT_X - 16, "", 11));
				rulerTextGroup.add(layerLabel);
				layerLabelPool.push(layerLabel);
			}
			layerLabel.visible = true;
			layerLabel.y = laneY + 12;
			layerLabel.text = layers[i];
			layerLabel.setFormat(Paths.font("vcr.ttf"), 11, layerColors[i % layerColors.length], LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		}
		for (i in layers.length...layerLabelPool.length)
		{
			layerLabelPool[i].visible = false;
		}

		// 2. Measure Marks across the ruler (Pool & Reuse)
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var stepCrochetMs = Conductor.stepCrochet;
		var measureMs = stepCrochetMs * 16.0;

		var startMeasure = Math.floor(timelineScrollMs / measureMs);
		var endMeasure = startMeasure + Math.ceil((FlxG.width - TIMELINE_LEFT_X) / (measureMs * effectivePixelsPerMs)) + 2;
		var poolIdx = 0;

		for (m in startMeasure...endMeasure)
		{
			var ms = m * measureMs;
			var rx = TIMELINE_LEFT_X + (ms - timelineScrollMs) * effectivePixelsPerMs;
			if (rx >= TIMELINE_LEFT_X && rx <= FlxG.width)
			{
				var mText:FlxText;
				if (poolIdx < measureTextPool.length)
				{
					mText = measureTextPool[poolIdx];
				}
				else
				{
					mText = bindUI(new FlxText(0, TIMELINE_Y + 34, 40, "", 10));
					mText.setFormat(Paths.font("vcr.ttf"), 10, 0xFFAAAAAA);
					rulerTextGroup.add(mText);
					measureTextPool.push(mText);
				}

				mText.visible = true;
				mText.x = rx + 2;
				mText.text = Std.string(m * 4);
				poolIdx++;
			}
		}

		for (i in poolIdx...measureTextPool.length)
		{
			measureTextPool[i].visible = false;
		}
	}

	function refreshEventBlocks():Void
	{
		if (timelineBlocksGroup == null) return;

		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var stepCrochetMs = Conductor.stepCrochet;
		var poolIdx = 0;

		for (ev in events)
		{
			var laneIdx = ev.layer % layers.length;
			var blockX = TIMELINE_LEFT_X + (ev.time - timelineScrollMs) * effectivePixelsPerMs;
			var blockY = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (laneIdx * LANE_HEIGHT) + 3;
			var blockWidth = Math.max(30.0, (ev.duration * stepCrochetMs) * effectivePixelsPerMs);
			var blockHeight = LANE_HEIGHT - 6;

			// Skip if to the left of the screen view
			if (blockX + blockWidth < TIMELINE_LEFT_X)
				continue;

			// Since events is sorted chronologically, once blockX is past the right edge, all next ones are too
			if (blockX > FlxG.width + 50)
				break;

			// Get or instantiate pooled item (no GC churn, 60+ FPS rock solid)
			var item:TimelineBlockItem;
			if (poolIdx < blockItemPool.length)
			{
				item = blockItemPool[poolIdx];
			}
			else
			{
				item = new TimelineBlockItem();
				bindUI(item);
				timelineBlocksGroup.add(item);
				blockItemPool.push(item);
			}

			item.setup(ev, (selectedEvent == ev), blockX, blockY, blockWidth, blockHeight);
			poolIdx++;
		}

		// Hide any unused pooled items
		for (i in poolIdx...blockItemPool.length)
		{
			blockItemPool[i].visible = false;
			blockItemPool[i].active = false;
			blockItemPool[i].event = null;
		}
	}

	/* =================================================================================
	 * PLAYBACK & TIME NAVIGATION
	 * ================================================================================= */
	function togglePlayback():Void
	{
		isPlaying = !isPlaying;
		if (isPlaying)
		{
			cachedNoteIndex = 0;
			cachedEventIndex = 0;
			lastSection = Math.floor(Conductor.songPosition / (Conductor.stepCrochet * 16));

			if (songMusic != null)
			{
				songMusic.time = Conductor.songPosition;
				songMusic.play();
			}
			if (vocals != null)
			{
				vocals.time = Conductor.songPosition;
				vocals.play();
			}
			btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/pause'));
		}
		else
		{
			if (songMusic != null) songMusic.pause();
			if (vocals != null) vocals.pause();
			btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/play'));
			replayCameraTimeline(Conductor.songPosition);
		}
		btnPlayPause.setGraphicSize(24, 24);
		btnPlayPause.updateHitbox();
	}

	public function setTimePosition(positionMs:Float):Void
	{
		var clampedMs = Math.max(0, positionMs);
		Conductor.songPosition = clampedMs;

		if (songMusic != null)
			songMusic.time = clampedMs;
		if (vocals != null)
			vocals.time = clampedMs;

		cachedNoteIndex = 0;
		cachedEventIndex = 0;
		lastSection = -1;
		lastDisplayedSongPos = -1;

		// Center timeline scroll around current time if playhead goes offscreen
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var playheadX = TIMELINE_LEFT_X + (clampedMs - timelineScrollMs) * effectivePixelsPerMs;
		if (playheadX > FlxG.width - 50 || playheadX < TIMELINE_LEFT_X)
		{
			timelineScrollMs = Math.max(0, clampedMs - (200 / effectivePixelsPerMs));
			refreshTimelineLanes();
		}

		replayCameraTimeline(clampedMs);
		refreshEventBlocks();
	}

	public function replayCameraTimeline(positionMs:Float):Void
	{
		if (cameraRect == null) return;

		cameraRect.cancelAllTweens();

		// Single pass backwards scan: ZERO array allocations, ZERO sort overhead (maximum FPS)
		var latestZoom:CameraEditorEvent = null;
		var prevZoom:CameraEditorEvent = null;
		var latestFocus:CameraEditorEvent = null;
		var prevFocus:CameraEditorEvent = null;

		for (ev in events)
		{
			if (ev.time > positionMs) break;
			if (ev.name == "ZoomCamera")
			{
				prevZoom = latestZoom;
				latestZoom = ev;
			}
			else if (ev.name == "FocusCamera")
			{
				prevFocus = latestFocus;
				latestFocus = ev;
			}
		}

		// 1. Zoom Camera Replay
		if (latestZoom != null)
		{
			var targetZoom = latestZoom.zoom;
			if (latestZoom.mode == "stage") targetZoom *= defaultStageZoom;

			var durMs = (latestZoom.duration * Conductor.stepCrochet);
			if (durMs <= 0 || latestZoom.ease == "INSTANT" || positionMs >= latestZoom.time + durMs)
			{
				cameraRect.zoom = targetZoom;
			}
			else
			{
				var easeFunc = CoolUtil.getEaseFromString(latestZoom.ease);
				var t = FlxMath.bound((positionMs - latestZoom.time) / durMs, 0.0, 1.0);
				var startZ = (prevZoom != null) ? (prevZoom.mode == "stage" ? prevZoom.zoom * defaultStageZoom : prevZoom.zoom) : defaultStageZoom;
				cameraRect.zoom = FlxMath.lerp(startZ, targetZoom, easeFunc != null ? easeFunc(t) : t);
			}
		}
		else
		{
			cameraRect.zoom = defaultStageZoom;
		}

		// 2. Focus Camera Replay
		if (latestFocus != null)
		{
			var durMs = (latestFocus.duration * Conductor.stepCrochet);

			if (durMs <= 0 || latestFocus.ease == "INSTANT" || positionMs >= latestFocus.time + durMs)
			{
				cameraRect.focusOnTarget(latestFocus.target, latestFocus.x, latestFocus.y, "INSTANT", 0, true);
			}
			else
			{
				var startPos:FlxPoint = null;
				if (prevFocus != null)
				{
					var prevPt = cameraRect.getCharacterCameraPoint(prevFocus.target);
					startPos = FlxPoint.get(prevPt.x + prevFocus.x - (FlxG.width / 2.0), prevPt.y + prevFocus.y - (FlxG.height / 2.0));
					prevPt.put();
				}
				else
				{
					var def = cameraRect.getDefaultPosition();
					startPos = FlxPoint.get(def.x - (FlxG.width / 2.0), def.y - (FlxG.height / 2.0));
					def.put();
				}

				cameraRect.focusOnTarget(latestFocus.target, latestFocus.x, latestFocus.y, latestFocus.ease, latestFocus.duration, false);
				@:privateAccess {
					cameraRect.cameraFollowTween = latestFocus.time;
					cameraRect.cameraFollowStart.copyFrom(startPos);
					var dtMs:Float = positionMs - latestFocus.time;
					if (latestFocus.ease == "CLASSIC")
					{
						var progress:Float = FlxMath.bound(1.0 - Math.pow(1.0 - 0.04, dtMs / 1000.0 * 60.0), 0.0, 1.0);
						cameraRect.vcamPoint.x = FlxMath.lerp(startPos.x, cameraRect.scrollTarget.x, progress);
						cameraRect.vcamPoint.y = FlxMath.lerp(startPos.y, cameraRect.scrollTarget.y, progress);
					}
					else if (cameraRect.cameraFollowEase != null && cameraRect.cameraFollowDuration > 0)
					{
						var t:Float = FlxMath.bound(dtMs / (cameraRect.cameraFollowDuration * 1000.0), 0.0, 1.0);
						var progress:Float = cameraRect.cameraFollowEase(t);
						cameraRect.vcamPoint.x = FlxMath.lerp(startPos.x, cameraRect.scrollTarget.x, progress);
						cameraRect.vcamPoint.y = FlxMath.lerp(startPos.y, cameraRect.scrollTarget.y, progress);
					}
				}
				if (startPos != null) startPos.put();
			}
		}
		else
		{
			// Check if any FocusCamera event exists in the song
			var firstFocus:CameraEditorEvent = null;
			for (ev in events)
			{
				if (ev.name == "FocusCamera")
				{
					firstFocus = ev;
					break;
				}
			}

			if (firstFocus != null)
			{
				cameraRect.focusOnTarget(firstFocus.target, firstFocus.x, firstFocus.y, "INSTANT", 0, true);
			}
			else
			{
				// No FocusCamera events at all - follow section target from chart!
				var curSec = Math.floor(positionMs / (Conductor.stepCrochet * 16));
				var targetChar:Int = 1; // default Dad
				if (_song != null && _song.notes != null && curSec >= 0 && curSec < _song.notes.length)
				{
					var sec = _song.notes[curSec];
					var isGf = (Reflect.field(sec, "gfSection") == true);
					targetChar = isGf ? 2 : (sec.mustHitSection ? 0 : 1);
				}
				cameraRect.focusOnTarget(targetChar, 0, 0, "INSTANT", 0, true);
			}
		}

		cameraRect.update(0);
		if (cameraRect.isRelative)
		{
			camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
			camGame.zoom = cameraRect.zoom;
		}

		// 3. Characters singing pose replay on scrub
		replayCharacterSinging(positionMs);
	}

	inline function getCharAnim(char:Character):String
	{
		if (char == null) return "";
		var anim = char.getAnimName();
		return anim != null ? anim : "";
	}

	function replayCharacterSinging(positionMs:Float):Void
	{
		if (allNotes == null || allNotes.length == 0)
		{
			if (boyfriend != null) boyfriend.dance(true);
			if (dadOpponent != null) dadOpponent.dance(true);
			if (gf != null) gf.dance(true);
			return;
		}

		var latestBfNote:EditorChartNote = null;
		var latestDadNote:EditorChartNote = null;

		for (n in allNotes)
		{
			if (n.time > positionMs) break;
			if (n.isPlayer)
				latestBfNote = n;
			else
				latestDadNote = n;
		}

		// Boyfriend pose
		if (boyfriend != null)
		{
			if (latestBfNote != null)
			{
				var holdLen = Math.max(Conductor.stepCrochet * boyfriend.singDuration, latestBfNote.length);
				if (positionMs <= latestBfNote.time + holdLen)
				{
					var dirName = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'][latestBfNote.data % 4];
					var anim = (latestBfNote.alt && boyfriend.hasAnimation(dirName + '-alt')) ? (dirName + '-alt') : dirName;
					boyfriend.playAnim(anim, true);
					boyfriend.holdTimer = (positionMs - latestBfNote.time) / 1000.0;
				}
				else
				{
					var bAnim = getCharAnim(boyfriend);
					if (!bAnim.startsWith('idle') && !bAnim.startsWith('dance'))
						boyfriend.dance(true);
				}
			}
			else
			{
				var bAnim = getCharAnim(boyfriend);
				if (!bAnim.startsWith('idle') && !bAnim.startsWith('dance'))
					boyfriend.dance(true);
			}
		}

		// Dad pose
		if (dadOpponent != null)
		{
			if (latestDadNote != null)
			{
				var holdLen = Math.max(Conductor.stepCrochet * dadOpponent.singDuration, latestDadNote.length);
				if (positionMs <= latestDadNote.time + holdLen)
				{
					var dirName = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'][latestDadNote.data % 4];
					var anim = (latestDadNote.alt && dadOpponent.hasAnimation(dirName + '-alt')) ? (dirName + '-alt') : dirName;
					dadOpponent.playAnim(anim, true);
					dadOpponent.holdTimer = (positionMs - latestDadNote.time) / 1000.0;
				}
				else
				{
					var dAnim = getCharAnim(dadOpponent);
					if (!dAnim.startsWith('idle') && !dAnim.startsWith('dance'))
						dadOpponent.dance(true);
				}
			}
			else
			{
				var dAnim = getCharAnim(dadOpponent);
				if (!dAnim.startsWith('idle') && !dAnim.startsWith('dance'))
					dadOpponent.dance(true);
			}
		}

		// GF pose
		if (gf != null)
		{
			var gAnim = getCharAnim(gf);
			if (!gAnim.startsWith('dance') && !gAnim.startsWith('idle'))
				gf.dance(true);
		}
	}

	/* =================================================================================
	 * AUTO-GENERATOR
	 * ================================================================================= */
	public function autoGenEvents(?playSound:Bool = true):Void
	{
		if (_song == null || _song.notes == null || _song.notes.length == 0) return;

		var stepCrochetMs = Conductor.stepCrochet;
		var newEvents:Array<CameraEditorEvent> = [];
		var currentTimeMs:Float = 0;
		var lastTargetChar:Int = -1;

		for (i in 0..._song.notes.length)
		{
			var section:SwagSection = _song.notes[i];
			var targetChar:Int = 1;

			if (Reflect.field(section, "gfSection") == true)
			{
				targetChar = 2;
			}
			else
			{
				var bfNotes:Int = 0;
				var dadNotes:Int = 0;
				var firstNoteChar:Int = -1;
				if (section.sectionNotes != null)
				{
					for (n in section.sectionNotes)
					{
						if (n != null && n.length > 1)
						{
							var lane:Int = Std.int(n[1]);
							if (lane >= 4 && lane <= 7)
							{
								bfNotes++;
								if (firstNoteChar == -1) firstNoteChar = 0;
							}
							else if (lane >= 0 && lane <= 3)
							{
								dadNotes++;
								if (firstNoteChar == -1) firstNoteChar = 1;
							}
						}
					}
				}

				if (bfNotes > 0 && dadNotes == 0)
					targetChar = 0;
				else if (dadNotes > 0 && bfNotes == 0)
					targetChar = 1;
				else if (firstNoteChar != -1)
					targetChar = firstNoteChar;
				else if (section.mustHitSection)
					targetChar = 0;
				else
					targetChar = (lastTargetChar != -1) ? lastTargetChar : 1;
			}

			// Add camera event only when character focus changes or at the very beginning
			if (i == 0 || targetChar != lastTargetChar)
			{
				var ev = new CameraEditorEvent(currentTimeMs, "FocusCamera", 1);
				ev.target = targetChar;
				ev.duration = 4.0; // 1 beat ease duration
				ev.ease = "CLASSIC";
				newEvents.push(ev);
				lastTargetChar = targetChar;
			}

			var sectionSteps = (section.lengthInSteps > 0) ? section.lengthInSteps : 16;
			currentTimeMs += sectionSteps * stepCrochetMs;
		}

		// Merge or replace focus events
		events = events.filter(function(e) return e.name != "FocusCamera");
		for (e in newEvents)
			events.push(e);

		sortEvents();
		if (timelineBlocksGroup != null)
			refreshEventBlocks();
		replayCameraTimeline(Conductor.songPosition);
		if (playSound)
			FlxG.sound.play(Paths.sound('system/confirm'));
	}

	/* =================================================================================
	 * SAVE / EXPORT
	 * ================================================================================= */
	function saveEventsToSongInMemory():Void
	{
		var isVSliceChart = (_song.format == "vslice");
		if (!isVSliceChart && _song.events != null)
		{
			for (e in _song.events)
			{
				if (Reflect.isObject(e) && Reflect.hasField(e, "e"))
				{
					isVSliceChart = true;
					break;
				}
			}
		}

		if (isVSliceChart)
		{
			var nonCamEvents:Array<Dynamic> = [];
			if (_song.events != null)
			{
				for (e in _song.events)
				{
					if (!CameraEditorEvent.isCameraEvent(e))
						nonCamEvents.push(e);
				}
			}
			for (ev in events)
				nonCamEvents.push(ev.toVSlice());

			nonCamEvents.sort(function(a:Dynamic, b:Dynamic) {
				var ta:Float = Reflect.hasField(a, "t") ? Std.parseFloat(Std.string(Reflect.field(a, "t"))) : 0.0;
				var tb:Float = Reflect.hasField(b, "t") ? Std.parseFloat(Std.string(Reflect.field(b, "t"))) : 0.0;
				if (ta < tb) return -1;
				if (ta > tb) return 1;
				return 0;
			});
			_song.events = nonCamEvents;
		}
		else
		{
			var eventsArr:Array<Dynamic> = [];

			// 1. Preserve existing non-camera events from song
			if (_song.events != null)
			{
				for (e in _song.events)
				{
					if (e != null && Std.isOfType(e, Array))
					{
						var arr:Array<Dynamic> = cast e;
						if (arr.length >= 2 && !Std.isOfType(arr[0], String))
						{
							var eTime:Float = Std.parseFloat(Std.string(arr[0]));
							if (Math.isNaN(eTime)) eTime = 0;
							var subList:Dynamic = arr[1];
							var filteredSub:Array<Dynamic> = [];
							if (subList != null && Std.isOfType(subList, Array))
							{
								var sList:Array<Dynamic> = cast subList;
								for (sub in sList)
								{
									if (sub != null && Std.isOfType(sub, Array))
									{
										var sArr:Array<Dynamic> = cast sub;
										var sName:String = sArr.length > 0 ? Std.string(sArr[0]) : "";
										if (!CameraEditorEvent.isCameraEventName(sName))
											filteredSub.push(sub);
									}
								}
							}
							if (filteredSub.length > 0)
								eventsArr.push([eTime, filteredSub]);
						}
					}
				}
			}

			// 2. Add all camera events with proper timestamp merging (Psych / Gaze 2D list)
			for (ev in events)
			{
				var eName = ev.name;
				var v1 = "";
				var v2 = '${ev.duration},${ev.ease}';
				if (eName == "ZoomCamera")
				{
					v1 = Std.string(ev.zoom);
				}
				else
				{
					v1 = '${ev.target},${ev.x},${ev.y}';
				}

				addEventToPsychList(eventsArr, ev.time, eName, v1, v2);
			}

			// Sort chronologically
			eventsArr.sort(function(a:Dynamic, b:Dynamic) {
				var ta:Float = Std.parseFloat(Std.string(a[0]));
				var tb:Float = Std.parseFloat(Std.string(b[0]));
				if (ta < tb) return -1;
				if (ta > tb) return 1;
				return 0;
			});

			_song.events = eventsArr;
		}

		PlayState.SONG = _song;
	}

	static function addEventToPsychList(eventsArr:Array<Dynamic>, time:Float, name:String, v1:String, v2:String):Void
	{
		if (name == null || name.trim() == "") return;

		for (e in eventsArr)
		{
			if (e != null && Std.isOfType(e, Array))
			{
				var arr:Array<Dynamic> = cast e;
				if (arr.length >= 2)
				{
					var t:Float = Std.parseFloat(Std.string(arr[0]));
					if (Math.abs(t - time) < 1.0)
					{
						var subList:Array<Dynamic> = cast arr[1];
						subList.push([name, v1, v2]);
						return;
					}
				}
			}
		}

		eventsArr.push([time, [[name, v1, v2]]]);
	}

	public function saveEventsToSong():Void
	{
		saveEventsToSongInMemory();

		#if sys
		var songFolder = _song.song.toLowerCase().trim();
		var targetPath:String = loadedChartPath;

		if (targetPath == null || !FileSystem.exists(targetPath))
		{
			var curMod = core.scripting.Mods.currentModDirectory;
			var candidates:Array<String> = [];

			if (curMod != null && curMod.length > 0)
			{
				candidates.push('mods/$curMod/songs/$songFolder/$songFolder.json');
				candidates.push('mods/$curMod/songs/$songFolder/chart/chart.json');
				candidates.push('mods/$curMod/songs/$songFolder/charts/$songFolder.json');
				candidates.push('mods/$curMod/data/$songFolder/$songFolder.json');
			}
			candidates.push('mods/songs/$songFolder/$songFolder.json');
			candidates.push('mods/songs/$songFolder/chart/chart.json');
			candidates.push('assets/songs/$songFolder/$songFolder.json');
			candidates.push('assets/songs/$songFolder/chart/chart.json');
			candidates.push('assets/songs/$songFolder/charts/$songFolder.json');
			candidates.push('assets/data/$songFolder/$songFolder.json');

			for (c in candidates)
			{
				if (FileSystem.exists(c))
				{
					targetPath = c;
					break;
				}
			}
		}

		if (targetPath == null)
		{
			targetPath = 'assets/songs/$songFolder/$songFolder.json';
		}

		try
		{
			var dir = Path.directory(targetPath);
			if (dir != null && dir.length > 0 && !FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var jsonContent = Json.stringify({song: _song}, "\t");
			File.saveContent(targetPath, jsonContent);
			loadedChartPath = targetPath;

			// Update autosave in FlxG.save
			FlxG.save.data.cameraEditorAutosave = jsonContent;
			FlxG.save.flush();

			FlxG.sound.play(Paths.sound('system/confirm'));
			timeText.text = 'SAVED TO: $targetPath';
			lastDisplayedSongPos = -1;
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Error saving song JSON: $e');
			timeText.text = 'ERROR SAVING: $e';
			lastDisplayedSongPos = -1;
		}
		#else
		var jsonContent = Json.stringify({song: _song}, "\t");
		var _file = new FileReference();
		_file.save(jsonContent, _song.song.toLowerCase() + ".json");
		#end
	}

	function isHoveringEventBlock(mx:Float, my:Float):Bool
	{
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var stepCrochetMs = Conductor.stepCrochet;
		for (ev in events)
		{
			var laneIdx = ev.layer % layers.length;
			var bx = TIMELINE_LEFT_X + (ev.time - timelineScrollMs) * effectivePixelsPerMs;
			var by = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (laneIdx * LANE_HEIGHT) + 3;
			var bw = Math.max(30.0, (ev.duration * stepCrochetMs) * effectivePixelsPerMs);
			var bh = LANE_HEIGHT - 6;

			if (bx > FlxG.width + 50)
				break;

			if (mx >= bx && mx <= bx + bw && my >= by && my <= by + bh)
				return true;
		}
		return false;
	}

	function isHoveringButton(mx:Float, my:Float):Bool
	{
		var allButtons:Array<FlxButton> = [
			btnPlayPause, btnSnap, btnShift, btnAddLayer, btnDeleteLayer, btnZoomIn, btnZoomOut,
			btnRelativeView, btnPassepartout, btnExtendedBounds, btnCameraBop,
			btnDeleteEvent, btnAddFocusEvent, btnAddZoomEvent, btnAutoGen
		];

		for (btn in allButtons)
		{
			if (btn != null && btn.visible && mx >= btn.x && mx <= btn.x + btn.width && my >= btn.y && my <= btn.y + btn.height)
				return true;
		}
		return false;
	}

	function isHoveringDropdown(mx:Float, my:Float):Bool
	{
		var dropdowns = [focusEaseDropDown, zoomEaseDropDown, focusTargetDropDown];
		for (dd in dropdowns)
		{
			if (dd != null && dd.visible)
			{
				if (mx >= dd.x && mx <= dd.x + dd.header.background.width
					&& my >= dd.y && my <= dd.y + dd.header.background.height)
					return true;

				if (dd.dropPanel != null && dd.dropPanel.visible)
				{
					var numVisible = Std.int(Math.min(dd.list.length, MAX_DROPDOWN_VISIBLE));
					var panelH = numVisible * dd.header.background.height;
					if (mx >= dd.x && mx <= dd.x + dd.header.background.width
						&& my >= dd.dropPanel.y && my <= dd.dropPanel.y + panelH)
						return true;
				}
			}
		}
		return false;
	}

	function handleDropdownScroll(dd:FlxUIDropDownMenu):Void
	{
		if (dd == null || dd.dropPanel == null || dd.list == null || dd.list.length == 0)
			return;

		var isOpen = dd.dropPanel.visible;
		var wasOpen = dropdownLastVisible.exists(dd) ? dropdownLastVisible.get(dd) : false;
		dropdownLastVisible.set(dd, isOpen);

		if (!isOpen)
			return;

		var mousePos = FlxG.mouse.getViewPosition(camUI);
		var mx = mousePos.x;
		var my = mousePos.y;
		mousePos.put();

		var btnH:Float = dd.header.background.height;
		var numVisible:Int = Std.int(Math.min(dd.list.length, MAX_DROPDOWN_VISIBLE));
		var panelH:Float = numVisible * btnH;

		// Just opened this frame: auto-scroll to selected item
		if (!wasOpen)
		{
			var selIdx:Int = -1;
			for (i in 0...dd.list.length)
			{
				if (dd.list[i].label != null && (dd.list[i].label.text == dd.selectedLabel || dd.list[i].name == dd.selectedLabel))
				{
					selIdx = i;
					break;
				}
			}
			var initOffset:Int = 0;
			if (selIdx >= 0)
			{
				initOffset = Std.int(FlxMath.bound(selIdx - 2, 0, Math.max(0, dd.list.length - numVisible)));
			}
			dropdownScrollOffsets.set(dd, initOffset);
		}

		// Check if mouse is hovering over the dropdown area
		var isHover = (mx >= dd.x && mx <= dd.x + dd.header.background.width
			&& my >= dd.y && my <= dd.dropPanel.y + panelH);

		var curOffset:Int = dropdownScrollOffsets.exists(dd) ? dropdownScrollOffsets.get(dd) : 0;

		if (isHover && FlxG.mouse.wheel != 0)
		{
			var maxOffset = Std.int(Math.max(0, dd.list.length - numVisible));
			curOffset = Std.int(FlxMath.bound(curOffset - FlxG.mouse.wheel, 0, maxOffset));
			dropdownScrollOffsets.set(dd, curOffset);
		}

		// Resize drop panel to visible items
		dd.dropPanel.resize(dd.header.background.width, panelH);

		// Position and show only visible window of buttons
		for (i in 0...dd.list.length)
		{
			var btn = dd.list[i];
			if (btn == null) continue;

			if (i >= curOffset && i < curOffset + numVisible)
			{
				btn.visible = true;
				btn.active = true;
				btn.y = dd.dropPanel.y + ((i - curOffset) * btnH);
			}
			else
			{
				btn.visible = false;
				btn.active = false;
			}
		}
	}

	function cycleEaseOnHover(dd:FlxUIDropDownMenu, input:FlxUIInputText, mx:Float, my:Float):Void
	{
		if (dd == null || input == null || !dd.visible || (dd.dropPanel != null && dd.dropPanel.visible))
			return;

		var overDD = (mx >= dd.x && mx <= dd.x + dd.header.background.width && my >= dd.y && my <= dd.y + dd.header.background.height);
		var overInput = (mx >= input.x && mx <= input.x + input.width && my >= input.y && my <= input.y + input.height);

		if ((overDD || overInput) && FlxG.mouse.wheel != 0)
		{
			var curEase = input.text.trim();
			var idx = -1;
			for (i in 0...availableEases.length)
			{
				if (availableEases[i].toLowerCase() == curEase.toLowerCase())
				{
					idx = i;
					break;
				}
			}

			var nextIdx = 0;
			if (idx >= 0)
			{
				nextIdx = Std.int(FlxMath.bound(idx - FlxG.mouse.wheel, 0, availableEases.length - 1));
			}
			else
			{
				nextIdx = (FlxG.mouse.wheel < 0) ? 0 : (availableEases.length - 1);
			}

			var chosen = availableEases[nextIdx];
			input.text = chosen;
			dd.selectedLabel = chosen;
			if (selectedEvent != null)
			{
				selectedEvent.ease = chosen;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}
	}

	/* =================================================================================
	 * MAIN UPDATE LOOP
	 * ================================================================================= */
	override function update(elapsed:Float):Void
	{
		// Accurate Screen Coordinates on camUI (0 to 1280, 0 to 720)
		var mousePos = FlxG.mouse.getViewPosition(camUI);
		var mouseX:Float = mousePos.x;
		var mouseY:Float = mousePos.y;

		var prevSongTime = Conductor.songPosition;

		// 1. Audio Sync & Song Position Tracking
		if (isPlaying && songMusic != null && songMusic.playing)
		{
			Conductor.songPosition = songMusic.time;
			var currentSongTime = Conductor.songPosition;

			// Process live note hits for character singing
			processNotesPlayback(prevSongTime, currentSongTime);

			// Process live camera events
			processCameraEventsPlayback(prevSongTime, currentSongTime);

			// Process live section camera transitions
			processSectionChangePlayback(prevSongTime, currentSongTime);

			// Reset boyfriend animation to idle once note hold ends
			if (boyfriend != null && boyfriend.holdTimer > Conductor.stepCrochet * boyfriend.singDuration * 0.001)
			{
				var bAnim = getCharAnim(boyfriend);
				if (bAnim.startsWith('sing') && !bAnim.endsWith('miss') && !boyfriend.animLocked)
					boyfriend.dance();
			}

			// Reset dad animation to idle once note hold ends
			if (dadOpponent != null && dadOpponent.holdTimer > Conductor.stepCrochet * dadOpponent.singDuration * 0.001)
			{
				var dAnim = getCharAnim(dadOpponent);
				if (dAnim.startsWith('sing') && !dAnim.endsWith('miss') && !dadOpponent.animLocked)
					dadOpponent.dance();
			}
		}

		// Update Conductor Steps and Beats
		var stepCrochetMs = Conductor.stepCrochet;
		curStep = Math.floor(Conductor.songPosition / stepCrochetMs);
		curBeat = Math.floor(curStep / 4);

		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;

		// Format time readout and playhead only when time position actually changes (saves massive text redraws)
		if (Conductor.songPosition != lastDisplayedSongPos)
		{
			lastDisplayedSongPos = Conductor.songPosition;
			var totalSec = Math.floor(Conductor.songPosition / 1000);
			var mins = Math.floor(totalSec / 60);
			var secs = totalSec % 60;
			var ms = Math.floor(Conductor.songPosition % 1000 / 10);
			var strMins = (mins < 10 ? "0" : "") + mins;
			var strSecs = (secs < 10 ? "0" : "") + secs;
			var strMs = (ms < 10 ? "0" : "") + ms;
			timeText.text = '$strMins:$strSecs.$strMs | Step $curStep | Beat $curBeat';

			// Update playhead position on screen
			var px = TIMELINE_LEFT_X + (Conductor.songPosition - timelineScrollMs) * effectivePixelsPerMs;
			playheadLine.x = px;
			playheadTopper.x = px - 6;

			// Auto-scroll timeline while playing
			if (isPlaying && px > FlxG.width - 60)
			{
				timelineScrollMs = Math.max(0, Conductor.songPosition - (200 / effectivePixelsPerMs));
				refreshTimelineLanes();
				refreshEventBlocks();
			}
		}

		// 2. Cursor Icon Feedback
		var insideTimeline = (mouseY >= TIMELINE_Y && mouseY <= FlxG.height && mouseX >= TIMELINE_LEFT_X);
		var onRuler = (insideTimeline && mouseY <= TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT);

		if (isDraggingEventBlock)
		{
			changeCursor('cursor-grabbing');
		}
		else if (isResizingEventBlock)
		{
			changeCursor('cursor-scroll');
		}
		else if (isDraggingPlayhead || onRuler)
		{
			changeCursor('cursor-cross');
		}
		else if (isHoveringEventBlock(mouseX, mouseY) || isHoveringButton(mouseX, mouseY) || isHoveringDropdown(mouseX, mouseY))
		{
			changeCursor('cursor-pointer');
		}
		else
		{
			changeCursor('cursor-default');
		}

		// 3. Mouse Timeline Interactions
		handleTimelineMouseInput(mouseX, mouseY);

		// Dropdown scroll & viewport mouse interactions
		var dropdownOpen = (focusEaseDropDown != null && focusEaseDropDown.dropPanel != null && focusEaseDropDown.dropPanel.visible)
			|| (zoomEaseDropDown != null && zoomEaseDropDown.dropPanel != null && zoomEaseDropDown.dropPanel.visible)
			|| (focusTargetDropDown != null && focusTargetDropDown.dropPanel != null && focusTargetDropDown.dropPanel.visible);

		if (dropdownOpen)
		{
			handleDropdownScroll(focusEaseDropDown);
			handleDropdownScroll(zoomEaseDropDown);
			handleDropdownScroll(focusTargetDropDown);
		}

		var hoveringEaseControl = (!dropdownOpen && (
			(focusEaseDropDown != null && focusEaseDropDown.visible && (
				(mouseX >= focusEaseDropDown.x && mouseX <= focusEaseDropDown.x + focusEaseDropDown.header.background.width && mouseY >= focusEaseDropDown.y && mouseY <= focusEaseDropDown.y + focusEaseDropDown.header.background.height)
				|| (focusEaseInput != null && mouseX >= focusEaseInput.x && mouseX <= focusEaseInput.x + focusEaseInput.width && mouseY >= focusEaseInput.y && mouseY <= focusEaseInput.y + focusEaseInput.height)
			))
			|| (zoomEaseDropDown != null && zoomEaseDropDown.visible && (
				(mouseX >= zoomEaseDropDown.x && mouseX <= zoomEaseDropDown.x + zoomEaseDropDown.header.background.width && mouseY >= zoomEaseDropDown.y && mouseY <= zoomEaseDropDown.y + zoomEaseDropDown.header.background.height)
				|| (zoomEaseInput != null && mouseX >= zoomEaseInput.x && mouseX <= zoomEaseInput.x + zoomEaseInput.width && mouseY >= zoomEaseInput.y && mouseY <= zoomEaseInput.y + zoomEaseInput.height)
			))
		));

		if (hoveringEaseControl)
		{
			cycleEaseOnHover(focusEaseDropDown, focusEaseInput, mouseX, mouseY);
			cycleEaseOnHover(zoomEaseDropDown, zoomEaseInput, mouseX, mouseY);
		}

		// 4. Stage Viewport Mouse Interactions (Pan & Zoom)
		if (!dropdownOpen && !hoveringEaseControl)
			handleViewportMouseInput(mouseX, mouseY);

		// 5. Keyboard Shortcuts
		handleKeyboardInput();

		// 6. Update Relative View positioning
		if (cameraRect.isRelative)
		{
			camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
			camGame.zoom = cameraRect.zoom;
		}

		mousePos.put();

		super.update(elapsed);
	}

	function handleTimelineMouseInput(mx:Float, my:Float):Void
	{
		if (isHoveringDropdown(mx, my))
			return;

		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var stepCrochetMs = Conductor.stepCrochet;

		var insideTimeline = (my >= TIMELINE_Y && my <= FlxG.height && mx >= TIMELINE_LEFT_X);

		if (FlxG.mouse.justPressed)
		{
			// Click on ruler: scrub song position
			if (insideTimeline && my <= TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT)
			{
				isDraggingPlayhead = true;
				var targetMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / effectivePixelsPerMs;
				if (snapEnabled)
				{
					var snapUnit = snapToBeat ? (stepCrochetMs * 4) : stepCrochetMs;
					targetMs = Math.round(targetMs / snapUnit) * snapUnit;
				}
				setTimePosition(targetMs);
			}
			// Click on lanes: check block hits
			else if (insideTimeline && my > TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT)
			{
				var clickedOnBlock:Bool = false;

				for (ev in events)
				{
					var laneIdx = ev.layer % layers.length;
					var bx = TIMELINE_LEFT_X + (ev.time - timelineScrollMs) * effectivePixelsPerMs;
					var by = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (laneIdx * LANE_HEIGHT) + 3;
					var bw = Math.max(30.0, (ev.duration * stepCrochetMs) * effectivePixelsPerMs);
					var bh = LANE_HEIGHT - 6;

					if (mx >= bx && mx <= bx + bw && my >= by && my <= by + bh)
					{
						clickedOnBlock = true;
						selectedEvent = ev;
						draggedEvent = ev;
						dragStartMouseX = mx;
						dragStartEventTime = ev.time;
						dragStartEventDuration = ev.duration;

						// Check if dragging right edge (resize duration)
						if (mx >= bx + bw - 10)
							isResizingEventBlock = true;
						else
							isDraggingEventBlock = true;

						updateInspectorUI();
						refreshEventBlocks();
						break;
					}
				}

				if (!clickedOnBlock)
				{
					selectedEvent = null;
					updateInspectorUI();
					refreshEventBlocks();
				}
			}
		}

		if (FlxG.mouse.pressed)
		{
			if (isDraggingPlayhead)
			{
				var targetMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / effectivePixelsPerMs;
				if (snapEnabled)
				{
					var snapUnit = snapToBeat ? (stepCrochetMs * 4) : stepCrochetMs;
					targetMs = Math.round(targetMs / snapUnit) * snapUnit;
				}
				setTimePosition(targetMs);
			}
			else if (isDraggingEventBlock && draggedEvent != null)
			{
				var deltaMs = (mx - dragStartMouseX) / effectivePixelsPerMs;
				var newTime = Math.max(0, dragStartEventTime + deltaMs);
				if (snapEnabled)
				{
					var snapUnit = snapToBeat ? (stepCrochetMs * 4) : stepCrochetMs;
					newTime = Math.round(newTime / snapUnit) * snapUnit;
				}
				draggedEvent.time = newTime;
				sortEvents();
				refreshEventBlocks();
				updateInspectorUI();
			}
			else if (isResizingEventBlock && draggedEvent != null)
			{
				var deltaMs = (mx - dragStartMouseX) / effectivePixelsPerMs;
				var deltaSteps = deltaMs / stepCrochetMs;
				var newDur = Math.max(0.5, dragStartEventDuration + deltaSteps);
				if (snapEnabled)
					newDur = Math.max(0.5, Math.round(newDur * 2) / 2); // Snap to half-step

				draggedEvent.duration = newDur;
				refreshEventBlocks();
				updateInspectorUI();
			}
		}

		if (FlxG.mouse.justReleased)
		{
			if (isDraggingPlayhead || isDraggingEventBlock || isResizingEventBlock)
			{
				isDraggingPlayhead = false;
				isDraggingEventBlock = false;
				isResizingEventBlock = false;
				draggedEvent = null;
				replayCameraTimeline(Conductor.songPosition);
			}
		}

		// Horizontal scroll with mouse wheel over timeline
		if (insideTimeline && FlxG.mouse.wheel != 0)
		{
			if (FlxG.keys.pressed.CONTROL)
			{
				timelineZoomScale = FlxMath.bound(timelineZoomScale + (FlxG.mouse.wheel * 0.15), 0.3, 3.0);
			}
			else
			{
				timelineScrollMs = Math.max(0, timelineScrollMs - (FlxG.mouse.wheel * stepCrochetMs * 8));
			}
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
		}
	}

	function handleViewportMouseInput(mx:Float, my:Float):Void
	{
		var insideViewport = (my > 42 && my < TIMELINE_Y && mx < INSPECTOR_X);

		// Pan viewport with Right Mouse Button
		if (FlxG.mouse.justPressedRight && insideViewport)
		{
			isPanningViewport = true;
			panStartMouse.set(mx, my);
			panStartCamScroll.set(camGame.scroll.x, camGame.scroll.y);
		}

		if (FlxG.mouse.pressedRight && isPanningViewport)
		{
			var dx = (mx - panStartMouse.x) / camGame.zoom;
			var dy = (my - panStartMouse.y) / camGame.zoom;
			camGame.scroll.set(panStartCamScroll.x - dx, panStartCamScroll.y - dy);
		}

		if (FlxG.mouse.justReleasedRight)
		{
			isPanningViewport = false;
		}

		// Zoom viewport with mouse wheel
		if (insideViewport && FlxG.mouse.wheel != 0 && !FlxG.keys.pressed.CONTROL)
		{
			camGame.zoom = FlxMath.bound(camGame.zoom + (FlxG.mouse.wheel * 0.08), 0.2, 2.5);
		}
	}

	function isTyping():Bool
	{
		return (focusEaseInput != null && focusEaseInput.hasFocus) || (zoomEaseInput != null && zoomEaseInput.hasFocus);
	}

	function handleKeyboardInput():Void
	{
		// Don't trigger shortcuts while user is typing in text inputs
		if (isTyping())
		{
			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE)
			{
				if (focusEaseInput != null) focusEaseInput.hasFocus = false;
				if (zoomEaseInput != null) zoomEaseInput.hasFocus = false;
			}
			return;
		}

		var shift = FlxG.keys.pressed.SHIFT;
		var ctrl = FlxG.keys.pressed.CONTROL;
		var stepCrochetMs = Conductor.stepCrochet;

		// Space: Play/Pause
		if (FlxG.keys.justPressed.SPACE)
		{
			togglePlayback();
		}

		// Home: Rewind to 0
		if (FlxG.keys.justPressed.HOME)
		{
			setTimePosition(0);
		}

		// Left / Right: Step backward / forward
		if (FlxG.keys.justPressed.LEFT)
		{
			var delta = shift ? (stepCrochetMs * 16) : stepCrochetMs;
			setTimePosition(Math.max(0, Conductor.songPosition - delta));
		}
		if (FlxG.keys.justPressed.RIGHT)
		{
			var delta = shift ? (stepCrochetMs * 16) : stepCrochetMs;
			setTimePosition(Conductor.songPosition + delta);
		}

		// W / A / S / D: Pan game camera
		if (!cameraRect.isRelative)
		{
			var speed = shift ? 20.0 : 8.0;
			if (FlxG.keys.pressed.W) camGame.scroll.y -= speed;
			if (FlxG.keys.pressed.S) camGame.scroll.y += speed;
			if (FlxG.keys.pressed.A) camGame.scroll.x -= speed;
			if (FlxG.keys.pressed.D) camGame.scroll.x += speed;

			if (FlxG.keys.pressed.Q) camGame.zoom = FlxMath.bound(camGame.zoom - 0.02, 0.2, 2.5);
			if (FlxG.keys.pressed.E) camGame.zoom = FlxMath.bound(camGame.zoom + 0.02, 0.2, 2.5);
			if (FlxG.keys.justPressed.R)
			{
				var defPos = cameraRect.getDefaultPosition();
				camGame.focusOn(defPos);
				camGame.zoom = 0.75;
				defPos.put();
			}
		}

		// P: Toggle Character Camera Anchor Markers
		if (FlxG.keys.justPressed.P)
		{
			showCamMarkers = !showCamMarkers;
			if (charCamMarkersGroup != null)
				charCamMarkersGroup.visible = showCamMarkers;
			if (btnCamMarkers != null)
			{
				btnCamMarkers.text = showCamMarkers ? "PTS: ON" : "PTS: OFF";
				btnCamMarkers.color = showCamMarkers ? 0xFF00FFCC : FlxColor.WHITE;
			}
		}

		// Delete / Backspace: Remove selected event
		if ((FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) && selectedEvent != null)
		{
			events.remove(selectedEvent);
			selectedEvent = null;
			refreshEventBlocks();
			updateInspectorUI();
			replayCameraTimeline(Conductor.songPosition);
		}

		// Ctrl + S: Save
		if (ctrl && FlxG.keys.justPressed.S)
		{
			saveEventsToSong();
		}

		// ESCAPE: Save and return to MainMenu
		if (FlxG.keys.justPressed.ESCAPE)
		{
			saveEventsToSong();
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new MainMenuState());
		}
	}

	function processNotesPlayback(prevTime:Float, curTime:Float):Void
	{
		if (allNotes == null || allNotes.length == 0) return;

		if (curTime < prevTime)
			cachedNoteIndex = 0;

		for (i in cachedNoteIndex...allNotes.length)
		{
			var note = allNotes[i];
			if (note.time > curTime) break;
			if (note.time >= prevTime)
			{
				var dirName = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'][note.data % 4];
				if (note.isPlayer && boyfriend != null)
				{
					var anim = (note.alt && boyfriend.hasAnimation(dirName + '-alt')) ? (dirName + '-alt') : dirName;
					boyfriend.playAnim(anim, true);
					boyfriend.holdTimer = 0;
				}
				else if (dadOpponent != null)
				{
					var anim = (note.alt && dadOpponent.hasAnimation(dirName + '-alt')) ? (dirName + '-alt') : dirName;
					dadOpponent.playAnim(anim, true);
					dadOpponent.holdTimer = 0;
				}
				cachedNoteIndex = i + 1;
			}
		}

		// Keep characters holding notes while sustains are active
		var startScan = Math.max(0, cachedNoteIndex - 10);
		for (i in Std.int(startScan)...Std.int(Math.min(allNotes.length, cachedNoteIndex + 5)))
		{
			var note = allNotes[i];
			if (note.length > 0 && note.time <= curTime && curTime <= (note.time + note.length))
			{
				if (note.isPlayer && boyfriend != null)
					boyfriend.holdTimer = 0;
				else if (dadOpponent != null)
					dadOpponent.holdTimer = 0;
			}
		}
	}

	function processCameraEventsPlayback(prevTime:Float, curTime:Float):Void
	{
		if (events == null || events.length == 0) return;

		if (curTime < prevTime)
			cachedEventIndex = 0;

		for (i in cachedEventIndex...events.length)
		{
			var ev = events[i];
			if (ev.time > curTime) break;
			if (ev.time >= prevTime)
			{
				if (ev.name == "FocusCamera")
					cameraRect.handleFocusCamera(ev);
				else if (ev.name == "ZoomCamera")
					cameraRect.handleZoomCamera(defaultStageZoom, ev);

				cachedEventIndex = i + 1;
			}
		}
	}

	function processSectionChangePlayback(prevTime:Float, curTime:Float):Void
	{
		if (_song == null || _song.notes == null || _song.notes.length == 0) return;

		var curSection = Std.int(curStep / 16);
		if (curSection != lastSection && curSection >= 0 && curSection < _song.notes.length)
		{
			lastSection = curSection;

			var hasAnyFocusEvents:Bool = false;
			for (ev in events)
			{
				if (ev.name == "FocusCamera")
				{
					hasAnyFocusEvents = true;
					break;
				}
			}

			// If song has FocusCamera events, sections do NOT move the camera!
			if (!hasAnyFocusEvents)
			{
				var sec = _song.notes[curSection];
				var isGf = (Reflect.field(sec, "gfSection") == true);
				var targetChar = isGf ? 2 : (sec.mustHitSection ? 0 : 1);
				cameraRect.focusOnTarget(targetChar, 0, 0, "CLASSIC", 4.0, false);
			}
		}
	}

	override function beatHit():Void
	{
		super.beatHit();

		if (curBeat % 1 == 0 && gf != null)
		{
			var gAnim = getCharAnim(gf);
			if (gAnim.startsWith("idle") || gAnim.startsWith("dance"))
				gf.dance();
		}

		if (boyfriend != null)
		{
			var bAnim = getCharAnim(boyfriend);
			if (bAnim.startsWith("idle") || bAnim.startsWith("dance"))
			{
				if (curBeat % 2 == 0 || (boyfriend.characterData != null && boyfriend.characterData.quickDancer))
					boyfriend.dance();
			}
		}

		if (dadOpponent != null)
		{
			var dAnim = getCharAnim(dadOpponent);
			if (dAnim.startsWith("idle") || dAnim.startsWith("dance"))
			{
				if (curBeat % 2 == 0 || (dadOpponent.characterData != null && dadOpponent.characterData.quickDancer))
					dadOpponent.dance();
			}
		}

		// Virtual Camera bop
		if (cameraRect != null && cameraRect.doBopping)
		{
			if (curBeat % Math.round(cameraRect.cameraZoomRate / 4) == 0)
				cameraRect.triggerBop();
		}
	}
}

/**
 * Pooled sprite container for rendering timeline camera event blocks.
 * Uses 1x1 scalable graphics to guarantee zero GPU texture churn and stable 60+ FPS.
 */
class TimelineBlockItem extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var inner:FlxSprite;
	public var icon:FlxSprite;
	public var label:FlxText;
	public var tri:FlxSprite;
	public var event:Null<CameraEditorEvent> = null;

	public function new()
	{
		super();

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bg.origin.set(0, 0);
		add(bg);

		inner = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		inner.origin.set(0, 0);
		inner.visible = false;
		add(inner);

		icon = new FlxSprite(4, 4);
		add(icon);

		label = new FlxText(24, 5, 0, "", 11);
		label.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(label);

		tri = new FlxSprite(0, 4).loadGraphic(Paths.image('menus/editors/camera/triangle'));
		tri.setGraphicSize(10, 10);
		tri.updateHitbox();
		tri.alpha = 0.7;
		tri.visible = false;
		add(tri);
	}

	public function setup(ev:CameraEditorEvent, isSel:Bool, bx:Float, by:Float, bw:Float, bh:Float):Void
	{
		this.event = ev;
		this.visible = true;
		this.active = true;

		var baseColor:FlxColor = (ev.name == "ZoomCamera") ? 0xFFCC7700 : 0xFF00AA88;

		// Outer block
		bg.scale.set(bw, bh);
		bg.updateHitbox();
		bg.x = bx;
		bg.y = by;
		bg.color = isSel ? 0xFFFFFFFF : baseColor;
		bg.alpha = isSel ? 1.0 : 0.85;

		// Inner fill if selected
		if (isSel)
		{
			inner.visible = true;
			inner.scale.set(Math.max(1, bw - 4), Math.max(1, bh - 4));
			inner.updateHitbox();
			inner.x = bx + 2;
			inner.y = by + 2;
			inner.color = baseColor;
		}
		else
		{
			inner.visible = false;
		}

		// Icon
		icon.x = bx + 4;
		icon.y = by + 4;
		icon.loadGraphic(Paths.image(ev.name == "ZoomCamera" ? 'menus/editors/camera/event-icons/zoom_event' : 'menus/editors/camera/event-icons/focus_event'));
		icon.setGraphicSize(18, 18);
		icon.updateHitbox();

		// Label
		if (bw > 45)
		{
			var labelStr:String = "";
			if (ev.name == "ZoomCamera")
			{
				labelStr = '${ev.zoom}x';
			}
			else
			{
				switch (ev.target)
				{
					case 0: labelStr = "BF";
					case 1: labelStr = "DAD";
					case 2: labelStr = "GF";
					default: labelStr = "POS";
				}
			}
			label.visible = true;
			label.text = labelStr;
			label.fieldWidth = Std.int(bw - 26);
			label.x = bx + 24;
			label.y = by + 5;
		}
		else
		{
			label.visible = false;
		}

		// Instant marker
		if (ev.duration <= 0.5 || ev.ease == "INSTANT")
		{
			tri.visible = true;
			tri.x = bx + bw - 12;
			tri.y = by + 4;
		}
		else
		{
			tri.visible = false;
		}
	}
}

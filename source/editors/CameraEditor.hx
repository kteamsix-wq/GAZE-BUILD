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
import openfl.display.BitmapData;
import openfl.display.Shape;
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

	// Dedicated Cameras (prevents conflicts with any other cameras in the engine)
	public var camEditor:FlxCamera; // Dedicated viewport camera for Stage, Characters, and Virtual Camera
	public var camEditorHUD:FlxCamera; // Dedicated stage HUD camera for stage scripts (isolated from UI)
	public var camEditorUI:FlxCamera; // Dedicated UI camera for editor panels, timeline, topbar, inspector
	public var camEditorOverlay:FlxCamera; // Dedicated topmost camera for dropdowns, tooltips, and toast notices

	var camGame:FlxCamera;
	var camUI:FlxCamera;

	// Audio & Conductor
	var songMusic:FlxSound;
	var vocals:FlxSound;
	var opponentVocals:FlxSound;
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

	public var layers:Array<String> = ["Stages", "Focus Camera", "Zoom Camera", "Characters", "Animations"];
	var layerColors:Array<FlxColor> = [0xFF2A82BE, 0xFF00AA88, 0xFFCC7700, 0xFF9933CC, 0xFFDDAA00];
	public var selectedLayerIndex:Int = 0;

	// Stage Tracking & Caching for Change Stage Events
	var initialStageName:String = "stage";
	var activeStageName:String = "stage";
	var initialStageZoom:Float = 1.05;
	var stageCache:Map<String, Stage> = new Map();
	var stageList:Array<String> = [];

	// Character State Tracking for Real-Time Timeline Replay & Swapping
	var initialBf:String = "bf";
	var initialDad:String = "dad";
	var initialGf:String = "gf";
	var curBfChar:String = "";
	var curDadChar:String = "";
	var curGfChar:String = "";
	var initialBfPos:Array<Float> = [770, 450];
	var initialDadPos:Array<Float> = [100, 100];
	var initialGfPos:Array<Float> = [400, 130];
	var characterPositions:Map<String, Array<Float>> = new Map();
	var characterList:Array<String> = [];

	// Active Character Tracking for Timeline Replay (prevents per-frame re-trigger)
	var activeBfChar:String = "";
	var activeBfCustomX:Null<Float> = null;
	var activeBfCustomY:Null<Float> = null;

	var activeDadChar:String = "";
	var activeDadCustomX:Null<Float> = null;
	var activeDadCustomY:Null<Float> = null;

	var activeGfChar:String = "";
	var activeGfCustomX:Null<Float> = null;
	var activeGfCustomY:Null<Float> = null;

	// High-Performance Object Pools (prevents FPS drops & memory leaks)
	var blockItemPool:Array<TimelineBlockItem> = [];
	var measureTextPool:Array<FlxText> = [];
	var gridLinePool:Array<FlxSprite> = [];
	var horizGridLinePool:Array<FlxSprite> = [];
	var layerLabelPool:Array<FlxText> = [];
	var lastDisplayedSongPos:Float = -999999;
	var loadedChartPath:String = null;

	// UI Groups & Controls
	var uiGroup:FlxTypedGroup<FlxBasic>;
	var timelineGroup:FlxTypedGroup<FlxBasic>;
	var gridLinesGroup:FlxTypedGroup<FlxSprite>;
	var timelineBlocksGroup:FlxTypedGroup<FlxBasic>;
	var leftHeadersGroup:FlxTypedGroup<FlxBasic>;
	var rulerTextGroup:FlxTypedGroup<FlxText>;
	var playheadGroup:FlxTypedGroup<FlxBasic>;
	var inspectorGroup:FlxTypedGroup<FlxBasic>;

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

	// Character Camera Anchor Markers (in world space on camEditor)
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
	var btnRewind:FlxButton;
	var btnSnap:FlxButton;
	var btnShift:FlxButton;
	var btnAddLayer:FlxButton;
	var btnDeleteLayer:FlxButton;
	var btnZoomIn:FlxButton;
	var btnZoomOut:FlxButton;
	var timelineZoomText:FlxText;

	// Timeline Rendering
	var timelineRulerBG:FlxSprite;
	var timelineLanesBG:FlxSprite;
	var playheadLine:FlxSprite;
	var playheadTopper:FlxSprite;

	// Inspector / Properties UI
	var inspectorBG:FlxSprite;
	var inspectorTitle:FlxText;
	var eventTypeLabel:FlxText;

	// Overview Mode (when no event is selected)
	var overviewStageText:FlxText;
	var overviewEventsText:FlxText;
	var btnQuickAddFocus:FlxButton;
	var btnQuickAddZoom:FlxButton;
	var btnQuickAddChar:FlxButton;
	var btnQuickAddAnim:FlxButton;
	var btnQuickAddStage:FlxButton;
	var btnAutoGen:FlxButton;
	var shortcutsGuideText:FlxText;

	// Common Selected Event Controls
	var eventTimeLabel:FlxText;
	var btnNudgeBack:FlxButton;
	var btnNudgeForward:FlxButton;
	var btnDuplicateEvent:FlxButton;
	var btnDeleteEvent:FlxButton;
	var btnDeselectEvent:FlxButton;

	// Event Group Controls (Overview & Selected Event)
	var overviewGroupsText:FlxText;
	var btnOverviewCreateGroup:FlxButton;
	var btnOverviewNextGroup:FlxButton;
	var groupSectionLabel:FlxText;
	var groupNameInput:FlxUIInputText;
	var btnAssignGroup:FlxButton;
	var btnGroupSameTime:FlxButton;
	var btnPrevGroupEv:FlxButton;
	var groupMemberText:FlxText;
	var btnNextGroupEv:FlxButton;
	var btnUngroupEvent:FlxButton;
	var btnAddToGroup:FlxButton;
	var btnDeleteGroupAll:FlxButton;
	var groupDragMoveCheck:FlxUICheckBox;
	var computedBlockBounds:Array<{ev:CameraEditorEvent, x:Float, y:Float, w:Float, h:Float, slotIdx:Int, slotCount:Int}> = [];
	var dragGroupStartTimes:Map<CameraEditorEvent, Float> = new Map();

	// Focus Camera Controls
	var focusTargetLabel:FlxText;
	var focusTargetDropDown:FlxUIDropDownMenu;
	var focusOffsetLabel:FlxText;
	var focusXStepper:FlxUINumericStepper;
	var focusYStepper:FlxUINumericStepper;
	var btnResetOffset:FlxButton;
	var focusDurationLabel:FlxText;
	var focusDurationStepper:FlxUINumericStepper;
	var focusDurationSub:FlxText;
	var focusEaseLabel:FlxText;
	var focusEaseInput:FlxUIInputText;
	var focusEaseDropDown:FlxUIDropDownMenu;

	// Zoom Camera Controls
	var zoomValLabel:FlxText;
	var zoomValueStepper:FlxUINumericStepper;
	var btnZoomPresetStage:FlxButton;
	var btnZoomPresetClose:FlxButton;
	var btnZoomPresetWide:FlxButton;
	var zoomDurLabel:FlxText;
	var zoomDurationStepper:FlxUINumericStepper;
	var zoomDurationSub:FlxText;
	var zoomEaseLabel:FlxText;
	var zoomEaseInput:FlxUIInputText;
	var zoomEaseDropDown:FlxUIDropDownMenu;

	// Change Character Controls
	var charTargetLabel:FlxText;
	var charTargetDropDown:FlxUIDropDownMenu;
	var charNameLabel:FlxText;
	var charNameInput:FlxUIInputText;
	var charNameDropDown:FlxUIDropDownMenu;
	var charOffsetLabel:FlxText;
	var charXStepper:FlxUINumericStepper;
	var charYStepper:FlxUINumericStepper;
	var btnResetCharOffset:FlxButton;

	// Play Animation Controls
	var animTargetLabel:FlxText;
	var animTargetDropDown:FlxUIDropDownMenu;
	var animNameLabel:FlxText;
	var animNameInput:FlxUIInputText;
	var animNameDropDown:FlxUIDropDownMenu;
	var animLockCheckbox:FlxUICheckBox;
	var btnTestAnim:FlxButton;

	// Change Stage Controls
	var stageTargetLabel:FlxText;
	var stageNameInput:FlxUIInputText;
	var stageNameDropDown:FlxUIDropDownMenu;
	var stageOptionsLabel:FlxText;
	var stageOptionsInput:FlxUIInputText;
	var btnStageOptNoRepos:FlxButton;
	var btnStageOptNoZoom:FlxButton;
	var btnStageOptFlash:FlxButton;
	var btnPreviewStage:FlxButton;

	var dropdownLastVisible:Map<FlxUIDropDownMenu, Bool> = new Map();
	var dropdownScrollOffsets:Map<FlxUIDropDownMenu, Int> = new Map();
	final MAX_DROPDOWN_VISIBLE:Int = 5;
	var blockInputUntilMouseRelease:Bool = false;

	// Toast Feedback
	var toastSprite:FlxSprite;
	var toastText:FlxText;
	var toastTimer:Float = 0;

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
	final LANE_HEIGHT:Float = 30;
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
		CursorManager.show();
		CursorManager.change('default');

		// 2. Resolve Song Data
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
			_song = Song.loadFromJson("bopeebo", "bopeebo");

		#if sys
		if (_song != null && _song.chartPath != null && _song.chartPath.trim() != "" && FileSystem.exists(_song.chartPath))
		{
			loadedChartPath = _song.chartPath;
		}
		else if (_song != null)
		{
			var songFolder = _song.song.toLowerCase().trim();
			var diffSuffix = "";
			if (PlayState.storyDifficulty == 0) diffSuffix = "-easy";
			else if (PlayState.storyDifficulty == 2) diffSuffix = "-hard";
			var chartNameWithDiff = songFolder + diffSuffix;
			loadedChartPath = gameplay.chart.ChartConverter.findChartPath(songFolder, chartNameWithDiff);
			if (loadedChartPath == null && diffSuffix == "")
				loadedChartPath = gameplay.chart.ChartConverter.findChartPath(songFolder, songFolder);
			if (loadedChartPath == null)
				loadedChartPath = 'assets/songs/$songFolder/$chartNameWithDiff.json';
			_song.chartPath = loadedChartPath;
		}
		#end

		if (_song.stage == null || _song.stage.trim() == "")
			_song.stage = "stage";

		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);
		Conductor.songPosition = 0;

		// 3. Setup Dedicated Editor Cameras to prevent conflict with other cameras
		camEditor = new FlxCamera();
		camEditorHUD = new FlxCamera();
		camEditorHUD.bgColor.alpha = 0;
		camEditorUI = new FlxCamera();
		camEditorUI.bgColor.alpha = 0;
		camEditorOverlay = new FlxCamera();
		camEditorOverlay.bgColor.alpha = 0;

		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camEditorHUD, false);
		FlxG.cameras.add(camEditorUI, false);
		FlxG.cameras.add(camEditorOverlay, false);
		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		camGame = camEditor;
		camUI = camEditorUI;

		// 4. Load Stage & Characters
		stageBuild = new Stage(_song.stage);
		add(stageBuild.background);

		defaultStageZoom = (stageBuild.stageData != null && stageBuild.stageData.zoom > 0) ? stageBuild.stageData.zoom : 1.05;
		initialStageName = _song.stage;
		activeStageName = _song.stage;
		initialStageZoom = defaultStageZoom;
		stageCache = new Map();
		stageCache.set(initialStageName, stageBuild);
		stageList = CoolUtil.getStageList();
		if (stageList == null || stageList.length == 0)
			stageList = [initialStageName];
		else if (stageList.indexOf(initialStageName) == -1)
			stageList.unshift(initialStageName);

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

		dadOpponent = new Character();
		dadOpponent.adjustPos = false;
		dadOpponent.setCharacter(initDadX, initDadY, _song.player2);

		boyfriend = new Boyfriend();
		boyfriend.adjustPos = false;
		boyfriend.setCharacter(initBfX, initBfY, _song.player1);

		var camPos = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
		stageBuild.repositionPlayers(_song.stage, boyfriend, dadOpponent, gf);
		stageBuild.dadPosition(_song.stage, boyfriend, dadOpponent, gf, camPos);
		camPos.put();

		dadOpponent.updateHitbox();
		boyfriend.updateHitbox();
		gf.updateHitbox();

		initialBf = (boyfriend.curCharacter != null && boyfriend.curCharacter.trim() != "") ? boyfriend.curCharacter.trim() : "bf";
		initialDad = (dadOpponent.curCharacter != null && dadOpponent.curCharacter.trim() != "") ? dadOpponent.curCharacter.trim() : "bf";
		initialGf = (gf.curCharacter != null && gf.curCharacter.trim() != "") ? gf.curCharacter.trim() : "gf";
		curBfChar = initialBf;
		curDadChar = initialDad;
		curGfChar = initialGf;

		activeBfChar = initialBf;
		activeDadChar = initialDad;
		activeGfChar = initialGf;
		activeBfCustomX = null;
		activeBfCustomY = null;
		activeDadCustomX = null;
		activeDadCustomY = null;
		activeGfCustomX = null;
		activeGfCustomY = null;

		initialBfPos = [initBfX, initBfY];
		initialDadPos = [initDadX, initDadY];
		initialGfPos = [initGfX, initGfY];

		characterPositions.set(initialBf, [initialBfPos[0], initialBfPos[1]]);
		characterPositions.set(initialDad, [initialDadPos[0], initialDadPos[1]]);
		characterPositions.set(initialGf, [initialGfPos[0], initialGfPos[1]]);

		characterList = CoolUtil.getCharacterList();

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
			stageBuild.interp.variables.set("camGame", camEditor);
			stageBuild.interp.variables.set("camHUD", camEditorHUD);
			stageBuild.interp.variables.set("camEditor", camEditor);
			stageBuild.interp.variables.set("camEditorHUD", camEditorHUD);
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

		// Character Base Camera Anchor Markers (drawn in world space on camEditor)
		charCamMarkersGroup = new FlxTypedGroup<FlxBasic>();
		charCamMarkersGroup.cameras = [camEditor];

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

		// 7. Build UI System (All explicitly bound to camEditorUI)
		uiGroup = new FlxTypedGroup<FlxBasic>();
		timelineGroup = new FlxTypedGroup<FlxBasic>();
		gridLinesGroup = new FlxTypedGroup<FlxSprite>();
		timelineBlocksGroup = new FlxTypedGroup<FlxBasic>();
		leftHeadersGroup = new FlxTypedGroup<FlxBasic>();
		rulerTextGroup = new FlxTypedGroup<FlxText>();
		playheadGroup = new FlxTypedGroup<FlxBasic>();
		inspectorGroup = new FlxTypedGroup<FlxBasic>();

		uiGroup.cameras = [camEditorUI];
		timelineGroup.cameras = [camEditorUI];
		gridLinesGroup.cameras = [camEditorUI];
		timelineBlocksGroup.cameras = [camEditorUI];
		leftHeadersGroup.cameras = [camEditorUI];
		rulerTextGroup.cameras = [camEditorUI];
		playheadGroup.cameras = [camEditorUI];
		inspectorGroup.cameras = [camEditorUI];

		buildTopBar();
		buildInspector();
		buildTimeline();
		setupToast();

		// Layer order: Background lanes -> Grid lines -> Blocks -> Track headers panel -> Ruler text -> Playhead -> Inspector -> UI
		add(timelineGroup);
		add(gridLinesGroup);
		add(timelineBlocksGroup);
		add(leftHeadersGroup);
		add(rulerTextGroup);
		add(playheadGroup);
		add(inspectorGroup);
		add(uiGroup);

		// 8. Load Persistent Editor Preferences
		loadEditorPreferences();
		updateModeButtonVisuals();

		if (cameraRect.isRelative)
		{
			camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
			camGame.zoom = cameraRect.zoom;
		}

		// 9. Parse Song Events into Camera Events & Notes
		loadEventsFromSong();
		loadNotesFromSong();

		// Replay timeline at start
		replayCameraTimeline(0);
		refreshTimelineLanes();
		refreshEventBlocks();
		updateInspectorUI();
	}

	override function destroy():Void
	{
		CursorManager.reset();
		saveEditorPreferences();
		if (songMusic != null)
		{
			songMusic.stop();
			FlxG.sound.list.remove(songMusic, true);
			songMusic.destroy();
			songMusic = null;
		}
		if (vocals != null)
		{
			vocals.stop();
			FlxG.sound.list.remove(vocals, true);
			vocals.destroy();
			vocals = null;
		}
		if (opponentVocals != null)
		{
			opponentVocals.stop();
			FlxG.sound.list.remove(opponentVocals, true);
			opponentVocals.destroy();
			opponentVocals = null;
		}
		// Reset cameras to restore clean single camera state for subsequent game scenes
		FlxG.cameras.reset();
		super.destroy();
	}

	function setupToast():Void
	{
		toastSprite = new FlxSprite(0, 50).makeGraphic(1, 1, 0xEE161626);
		toastSprite.cameras = [camEditorOverlay];
		toastSprite.scrollFactor.set(0, 0);
		toastSprite.visible = false;
		add(toastSprite);

		toastText = new FlxText(0, 56, FlxG.width, "", 13);
		toastText.setFormat(Paths.font("vcr.ttf"), 13, 0xFF00FFCC, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		toastText.cameras = [camEditorOverlay];
		toastText.scrollFactor.set(0, 0);
		toastText.visible = false;
		add(toastText);
	}

	public function showToast(msg:String, duration:Float = 2.0):Void
	{
		if (toastSprite == null || toastText == null) return;
		toastText.text = msg;
		var tw = Math.max(260.0, toastText.textField.textWidth + 50);
		var th = 32.0;
		toastSprite.scale.set(tw, th);
		toastSprite.updateHitbox();
		toastSprite.x = (FlxG.width - tw) / 2;
		toastSprite.y = 50;
		toastText.y = 57;

		toastSprite.visible = true;
		toastText.visible = true;
		toastSprite.alpha = 1.0;
		toastText.alpha = 1.0;
		toastTimer = duration;
	}

	function loadEditorPreferences():Void
	{
		if (FlxG.save.data == null) return;

		if (FlxG.save.data.camEd_relativeView != null)
			cameraRect.isRelative = FlxG.save.data.camEd_relativeView;
		if (FlxG.save.data.camEd_showPassepartout != null)
			cameraRect.showPassepartout = FlxG.save.data.camEd_showPassepartout;
		if (FlxG.save.data.camEd_showExtendedBounds != null)
			cameraRect.showExtendedBounds = FlxG.save.data.camEd_showExtendedBounds;
		if (FlxG.save.data.camEd_doBopping != null)
			cameraRect.doBopping = FlxG.save.data.camEd_doBopping;
		if (FlxG.save.data.camEd_showCamMarkers != null)
			showCamMarkers = FlxG.save.data.camEd_showCamMarkers;
		if (FlxG.save.data.camEd_snapEnabled != null)
			snapEnabled = FlxG.save.data.camEd_snapEnabled;
		if (FlxG.save.data.camEd_snapToBeat != null)
			snapToBeat = FlxG.save.data.camEd_snapToBeat;
		if (FlxG.save.data.camEd_timelineZoomScale != null)
		{
			var z:Float = FlxG.save.data.camEd_timelineZoomScale;
			if (z >= 0.25 && z <= 4.0)
				timelineZoomScale = z;
		}
	}

	function saveEditorPreferences():Void
	{
		if (FlxG.save.data == null) return;

		FlxG.save.data.camEd_relativeView = (cameraRect != null) ? cameraRect.isRelative : false;
		FlxG.save.data.camEd_showPassepartout = (cameraRect != null) ? cameraRect.showPassepartout : false;
		FlxG.save.data.camEd_showExtendedBounds = (cameraRect != null) ? cameraRect.showExtendedBounds : false;
		FlxG.save.data.camEd_doBopping = (cameraRect != null) ? cameraRect.doBopping : false;
		FlxG.save.data.camEd_showCamMarkers = showCamMarkers;
		FlxG.save.data.camEd_snapEnabled = snapEnabled;
		FlxG.save.data.camEd_snapToBeat = snapToBeat;
		FlxG.save.data.camEd_timelineZoomScale = timelineZoomScale;

		FlxG.save.flush();
	}

	function updateModeButtonVisuals():Void
	{
		if (btnRelativeView != null && cameraRect != null)
		{
			btnRelativeView.color = cameraRect.isRelative ? 0xFF00FFCC : 0xFF666677;
		}
		if (btnPassepartout != null && cameraRect != null)
		{
			btnPassepartout.color = cameraRect.showPassepartout ? 0xFF00FFCC : 0xFF666677;
		}
		if (btnExtendedBounds != null && cameraRect != null)
		{
			btnExtendedBounds.color = cameraRect.showExtendedBounds ? 0xFF00FFCC : 0xFF666677;
		}
		if (btnCameraBop != null && cameraRect != null)
		{
			btnCameraBop.text = cameraRect.doBopping ? "BOP: ON" : "BOP: OFF";
			btnCameraBop.color = cameraRect.doBopping ? 0xFF00FFCC : 0xFF666677;
		}
		if (btnCamMarkers != null)
		{
			btnCamMarkers.text = showCamMarkers ? "PTS: ON" : "PTS: OFF";
			btnCamMarkers.color = showCamMarkers ? 0xFF00FFCC : 0xFF666677;
			if (charCamMarkersGroup != null)
				charCamMarkersGroup.visible = showCamMarkers;
		}
		if (btnSnap != null)
		{
			var snapIcon = snapEnabled ? 'menus/editors/camera/magnet_snap_on' : 'menus/editors/camera/magnet_snap_off';
			var snapGfx = Paths.image(snapIcon);
			if (snapGfx != null)
			{
				btnSnap.loadGraphic(snapGfx);
				btnSnap.setGraphicSize(24, 24);
				btnSnap.updateHitbox();
			}
			btnSnap.color = snapEnabled ? (snapToBeat ? 0xFFFFCC00 : 0xFF00FFCC) : 0xFF666677;
		}
		if (timelineZoomText != null)
		{
			timelineZoomText.text = '${Math.round(timelineZoomScale * 100)}%';
		}
	}

	/**
	 * Calculates the song time in milliseconds from a continuous or integer step,
	 * fully respecting dynamic BPM change maps from Conductor.
	 */
	public function getTimeFromStep(step:Float):Float
	{
		if (step <= 0) return 0;
		if (Conductor.bpmChangeMap == null || Conductor.bpmChangeMap.length == 0)
		{
			var initBPM:Float = (_song != null && _song.bpm > 0) ? _song.bpm : Conductor.bpm;
			var initSC:Float = ((60.0 / initBPM) * 1000.0) / 4.0;
			return step * initSC;
		}

		var lastChange:BPMChangeEvent = Conductor.bpmChangeMap[0];
		if (step < lastChange.stepTime)
		{
			var initBPM:Float = (_song != null && _song.bpm > 0) ? _song.bpm : Conductor.bpm;
			var initSC:Float = ((60.0 / initBPM) * 1000.0) / 4.0;
			return step * initSC;
		}

		for (i in 0...Conductor.bpmChangeMap.length)
		{
			var change = Conductor.bpmChangeMap[i];
			if (step >= change.stepTime)
			{
				lastChange = change;
			}
			else
			{
				break;
			}
		}

		var stepC:Float = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) ? lastChange.stepCrochet : Conductor.stepCrochet;
		return lastChange.songTime + ((step - lastChange.stepTime) * stepC);
	}

	/**
	 * Returns the active step crochet (ms per step) at a specific song position in milliseconds.
	 */
	public function getStepCrochetAtTime(time:Float):Float
	{
		var change = Conductor.getBPMChangeEvent(time);
		if (change != null && change.stepCrochet != null && change.stepCrochet > 0)
			return change.stepCrochet;
		return Conductor.stepCrochet;
	}

	/**
	 * Finds the song section index corresponding to a given step.
	 */
	public function getSectionAtStep(step:Float):Int
	{
		if (_song == null || _song.notes == null || _song.notes.length == 0) return 0;
		var totalSteps:Int = 0;
		for (i in 0..._song.notes.length)
		{
			var secLen = (_song.notes[i] != null && _song.notes[i].lengthInSteps > 0) ? _song.notes[i].lengthInSteps : 16;
			if (step < totalSteps + secLen)
				return i;
			totalSteps += secLen;
		}
		return _song.notes.length - 1;
	}

	/**
	 * Returns the starting step for a given section index.
	 */
	public function getStepAtSection(secIdx:Int):Int
	{
		if (_song == null || _song.notes == null || _song.notes.length == 0) return secIdx * 16;
		var totalSteps:Int = 0;
		var limit = Math.min(secIdx, _song.notes.length);
		for (i in 0...Std.int(limit))
		{
			var secLen = (_song.notes[i] != null && _song.notes[i].lengthInSteps > 0) ? _song.notes[i].lengthInSteps : 16;
			totalSteps += secLen;
		}
		if (secIdx > _song.notes.length)
			totalSteps += (secIdx - _song.notes.length) * 16;
		return totalSteps;
	}

	function nudgeEventTime(deltaSteps:Float):Void
	{
		if (selectedEvent == null) return;
		var oldTime = selectedEvent.time;
		var evStep = Conductor.calculateDecStep(selectedEvent.time);
		var newStep = Math.max(0, Math.round(evStep) + deltaSteps);
		var newTime = getTimeFromStep(newStep);
		var deltaMs = newTime - oldTime;

		if (selectedEvent.groupName != "" && groupDragMoveCheck != null && groupDragMoveCheck.checked)
		{
			for (ev in getEventsInGroup(selectedEvent.groupName))
			{
				ev.time = Math.max(0, ev.time + deltaMs);
			}
		}
		else
		{
			selectedEvent.time = newTime;
		}
		sortEvents();
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
	}

	function getGroupColor(name:String):FlxColor
	{
		if (name == null || name.trim() == "") return 0xFF00FFCC;
		var palette:Array<FlxColor> = [0xFF00FFCC, 0xFF55AAFF, 0xFFFF66CC, 0xFFAAFF44, 0xFFFFAA33, 0xFFBB77FF];
		var sum:Int = 0;
		for (i in 0...name.length)
			sum += name.charCodeAt(i) * (i + 1);
		return palette[sum % palette.length];
	}

	function getEventsInGroup(groupName:String):Array<CameraEditorEvent>
	{
		var out:Array<CameraEditorEvent> = [];
		if (groupName == null || groupName.trim() == "") return out;
		for (e in events)
		{
			if (e != null && e.groupName == groupName)
				out.push(e);
		}
		return out;
	}

	function getEventsAtSameTime(time:Float, toleranceMs:Float = 2.0):Array<CameraEditorEvent>
	{
		var out:Array<CameraEditorEvent> = [];
		for (e in events)
		{
			if (e != null && Math.abs(e.time - time) <= toleranceMs)
				out.push(e);
		}
		return out;
	}

	function getAllGroupNames():Array<String>
	{
		var names:Array<String> = [];
		for (e in events)
		{
			if (e != null && e.groupName != null && e.groupName.trim() != "" && names.indexOf(e.groupName) == -1)
				names.push(e.groupName);
		}
		return names;
	}

	function generateNextGroupName():String
	{
		var existing = getAllGroupNames();
		var idx = existing.length + 1;
		while (existing.indexOf('Grupo $idx') != -1)
			idx++;
		return 'Grupo $idx';
	}

	function assignGroupNameToSelected():Void
	{
		if (selectedEvent == null) return;
		var gName = (groupNameInput != null && groupNameInput.text != null) ? groupNameInput.text.trim() : "";
		if (gName == "")
			gName = generateNextGroupName();
		selectedEvent.groupName = gName;
		if (groupNameInput != null)
			groupNameInput.text = gName;
		refreshEventBlocks();
		updateInspectorUI();
		showToast('Evento adicionado ao grupo "$gName"');
	}

	function groupSameTimeEventsFor(baseTime:Float, ?preferredName:String):Void
	{
		var sameTime = getEventsAtSameTime(baseTime, 5.0);
		if (sameTime.length == 0)
		{
			showToast("Nenhum evento neste tempo para agrupar!");
			return;
		}
		var gName = (preferredName != null && preferredName.trim() != "") ? preferredName.trim() : "";
		if (gName == "")
		{
			for (ev in sameTime)
			{
				if (ev.groupName != null && ev.groupName.trim() != "")
				{
					gName = ev.groupName;
					break;
				}
			}
		}
		if (gName == "")
			gName = generateNextGroupName();

		for (ev in sameTime)
			ev.groupName = gName;

		if (selectedEvent == null)
			selectedEvent = sameTime[0];
		if (groupNameInput != null)
			groupNameInput.text = gName;
		refreshEventBlocks();
		updateInspectorUI();
		showToast('Grupo "$gName" criado com ${sameTime.length} evento(s)!');
	}

	function getNavigationListForSelected():Array<CameraEditorEvent>
	{
		if (selectedEvent == null) return [];
		if (selectedEvent.groupName != null && selectedEvent.groupName.trim() != "")
			return getEventsInGroup(selectedEvent.groupName);
		return getEventsAtSameTime(selectedEvent.time, 2.0);
	}

	function navigateGroupEvent(dir:Int):Void
	{
		if (selectedEvent == null) return;
		var list = getNavigationListForSelected();
		if (list.length <= 1) return;
		var idx = list.indexOf(selectedEvent);
		if (idx < 0) idx = 0;
		idx = (idx + dir + list.length) % list.length;
		selectedEvent = list[idx];
		refreshEventBlocks();
		updateInspectorUI();
	}

	function ungroupSelectedEvent():Void
	{
		if (selectedEvent == null) return;
		if (selectedEvent.groupName == "")
		{
			showToast("Este evento nao esta em nenhum grupo.");
			return;
		}
		var oldName = selectedEvent.groupName;
		selectedEvent.groupName = "";
		refreshEventBlocks();
		updateInspectorUI();
		showToast('Removido do grupo "$oldName"');
	}

	function deleteSelectedGroup():Void
	{
		if (selectedEvent == null) return;
		var list = getNavigationListForSelected();
		if (list.length == 0) return;
		var count = list.length;
		for (ev in list)
			events.remove(ev);
		selectedEvent = null;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
		showToast('Grupo removido ($count evento(s))!');
	}

	function addEventInsideCurrentGroup():Void
	{
		if (selectedEvent == null) return;
		var gName = selectedEvent.groupName;
		if (gName == null || gName.trim() == "")
		{
			gName = generateNextGroupName();
			for (e in getEventsAtSameTime(selectedEvent.time, 2.0))
				e.groupName = gName;
		}

		// Create a complementary event at the exact same timestamp in this group
		var sameTime = getEventsAtSameTime(selectedEvent.time, 2.0);
		var hasFocus = false;
		var hasZoom = false;
		var usedCharTargets:Array<Int> = [];
		for (e in sameTime)
		{
			if (e.name == "FocusCamera") hasFocus = true;
			else if (e.name == "ZoomCamera") hasZoom = true;
			else if (e.name == "Change Character") usedCharTargets.push(e.target);
		}

		var newEv:CameraEditorEvent;
		if (!hasFocus)
		{
			newEv = new CameraEditorEvent(selectedEvent.time, "FocusCamera", 1);
			newEv.target = 0;
		}
		else if (!hasZoom)
		{
			newEv = new CameraEditorEvent(selectedEvent.time, "ZoomCamera", 2);
			newEv.zoom = defaultStageZoom;
		}
		else if (usedCharTargets.length < 3)
		{
			newEv = new CameraEditorEvent(selectedEvent.time, "Change Character", 3);
			newEv.target = (usedCharTargets.indexOf(1) == -1) ? 1 : ((usedCharTargets.indexOf(0) == -1) ? 0 : 2);
			newEv.charName = (newEv.target == 0) ? curBfChar : ((newEv.target == 2) ? curGfChar : curDadChar);
		}
		else
		{
			newEv = new CameraEditorEvent(selectedEvent.time, "Play Anim", 4);
			newEv.target = 1;
			newEv.animName = "singUP";
		}

		newEv.groupName = gName;
		events.push(newEv);
		sortEvents();
		selectedEvent = newEv;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
		showToast('+ ${newEv.name} adicionado ao grupo "$gName"!');
	}

	function jumpToNextGroup():Void
	{
		var names = getAllGroupNames();
		if (names.length == 0)
		{
			showToast("Nenhum grupo nomeado ainda.");
			return;
		}
		var firstInEach:Array<CameraEditorEvent> = [];
		for (g in names)
		{
			var members = getEventsInGroup(g);
			if (members.length > 0) firstInEach.push(members[0]);
		}
		if (firstInEach.length == 0) return;

		var curT = Conductor.songPosition;
		var targetEv = firstInEach[0];
		for (ev in firstInEach)
		{
			if (ev.time > curT + 5.0)
			{
				targetEv = ev;
				break;
			}
		}
		setTimePosition(targetEv.time);
		selectedEvent = targetEv;
		refreshEventBlocks();
		updateInspectorUI();
	}

	function duplicateEvent():Void
	{
		if (selectedEvent == null) return;
		var evStep = Conductor.calculateDecStep(selectedEvent.time);
		var newStep = evStep + selectedEvent.duration;
		var cloneEv = selectedEvent.clone();
		cloneEv.time = getTimeFromStep(newStep);
		events.push(cloneEv);
		sortEvents();
		selectedEvent = cloneEv;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
		showToast("Event duplicated!");
	}

	function addFocusEventAtCurrentTime():Void
	{
		var eventTime = Conductor.songPosition;
		if (snapEnabled)
		{
			var decStep = Conductor.calculateDecStep(eventTime);
			var snapUnit = snapToBeat ? 4.0 : 1.0;
			var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
			eventTime = getTimeFromStep(Math.max(0, snappedStep));
		}
		var ev = new CameraEditorEvent(eventTime, "FocusCamera", 1);
		ev.target = 0; // BF
		ev.duration = 4.0;
		ev.ease = "CLASSIC";
		events.push(ev);
		sortEvents();
		selectedEvent = ev;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
		showToast("+ Focus Camera Event added!");
	}

	function addZoomEventAtCurrentTime():Void
	{
		var eventTime = Conductor.songPosition;
		if (snapEnabled)
		{
			var decStep = Conductor.calculateDecStep(eventTime);
			var snapUnit = snapToBeat ? 4.0 : 1.0;
			var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
			eventTime = getTimeFromStep(Math.max(0, snappedStep));
		}
		var ev = new CameraEditorEvent(eventTime, "ZoomCamera", 2);
		ev.zoom = defaultStageZoom;
		ev.duration = 4.0;
		ev.ease = "linear";
		events.push(ev);
		sortEvents();
		selectedEvent = ev;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(Conductor.songPosition);
		showToast("+ Zoom Camera Event added!");
	}

	function addCharEventAtCurrentTime():Void
	{
		var eventTime = Conductor.songPosition;
		if (snapEnabled)
		{
			var decStep = Conductor.calculateDecStep(eventTime);
			var snapUnit = snapToBeat ? 4.0 : 1.0;
			var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
			eventTime = getTimeFromStep(Math.max(0, snappedStep));
		}
		if (!isPlaying)
		{
			Conductor.songPosition = eventTime;
			lastDisplayedSongPos = -1;
		}
		var defaultTarget:Int = -1;
		for (cand in [1, 0, 2])
		{
			var used = false;
			for (existing in events)
			{
				if (existing != null && existing.name == "Change Character" && existing.target == cand && Math.abs(existing.time - eventTime) <= 2.0)
				{
					used = true;
					break;
				}
			}
			if (!used)
			{
				defaultTarget = cand;
				break;
			}
		}
		if (defaultTarget == -1)
		{
			for (existing in events)
			{
				if (existing != null && existing.name == "Change Character" && Math.abs(existing.time - eventTime) <= 2.0)
				{
					selectedEvent = existing;
					refreshEventBlocks();
					updateInspectorUI();
					replayCameraTimeline(eventTime);
					showToast("Todos os alvos (BF/DAD/GF) ja possuem evento neste tempo");
					return;
				}
			}
			defaultTarget = 1;
		}
		var ev = new CameraEditorEvent(eventTime, "Change Character", 3);
		ev.target = defaultTarget;
		if (defaultTarget == 0)
			ev.charName = (boyfriend != null && boyfriend.curCharacter != null && boyfriend.curCharacter != "") ? boyfriend.curCharacter : "bf";
		else if (defaultTarget == 2)
			ev.charName = (gf != null && gf.curCharacter != null && gf.curCharacter != "") ? gf.curCharacter : "gf";
		else
			ev.charName = (dadOpponent != null && dadOpponent.curCharacter != null && dadOpponent.curCharacter != "") ? dadOpponent.curCharacter : "dad";
		ev.duration = 1.0;
		events.push(ev);
		sortEvents();
		selectedEvent = ev;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(eventTime);
		showToast("+ Change Character Event added!");
	}

	function addAnimEventAtCurrentTime():Void
	{
		var eventTime = Conductor.songPosition;
		if (snapEnabled)
		{
			var decStep = Conductor.calculateDecStep(eventTime);
			var snapUnit = snapToBeat ? 4.0 : 1.0;
			var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
			eventTime = getTimeFromStep(Math.max(0, snappedStep));
		}
		if (!isPlaying)
		{
			Conductor.songPosition = eventTime;
			lastDisplayedSongPos = -1;
		}
		var ev = new CameraEditorEvent(eventTime, "Play Anim", 4);
		ev.target = 1; // Dad default
		ev.animName = "singUP";
		ev.duration = 1.0;
		ev.animLock = false;
		events.push(ev);
		sortEvents();
		selectedEvent = ev;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(eventTime);
		showToast("+ Play Animation Event added!");
	}

	function addStageEventAtCurrentTime():Void
	{
		var eventTime = Conductor.songPosition;
		if (snapEnabled)
		{
			var decStep = Conductor.calculateDecStep(eventTime);
			var snapUnit = snapToBeat ? 4.0 : 1.0;
			var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
			eventTime = getTimeFromStep(Math.max(0, snappedStep));
		}
		if (!isPlaying)
		{
			Conductor.songPosition = eventTime;
			lastDisplayedSongPos = -1;
		}
		var defaultStage:String = activeStageName != "" ? activeStageName : initialStageName;
		if (stageList != null && stageList.length > 1)
		{
			for (st in stageList)
			{
				if (st != null && st.trim() != "" && st.trim().toLowerCase() != defaultStage.toLowerCase())
				{
					defaultStage = st.trim();
					break;
				}
			}
		}
		var ev = new CameraEditorEvent(eventTime, "Change Stage", 0);
		ev.stageName = defaultStage;
		ev.stageOptions = "";
		ev.duration = 1.0;
		events.push(ev);
		sortEvents();
		selectedEvent = ev;
		refreshEventBlocks();
		updateInspectorUI();
		replayCameraTimeline(eventTime);
		showToast('+ Change Stage ($defaultStage) added!');
	}

	function toggleSnap():Void
	{
		if (!snapEnabled)
		{
			snapEnabled = true;
			snapToBeat = false;
			showToast("Snap: 1 Step");
		}
		else if (!snapToBeat)
		{
			snapToBeat = true;
			showToast("Snap: 1 Beat (4 Steps)");
		}
		else
		{
			snapEnabled = false;
			snapToBeat = false;
			showToast("Snap: OFF");
		}
		saveEditorPreferences();
		updateModeButtonVisuals();
	}

	function changeCursor(cursorType:String):Void
	{
		CursorManager.change(cursorType);
	}

	/**
	 * Helper function that sets an element's camera to camEditorUI (or camEditorOverlay) and resets scrollFactor.
	 */
	function bindUI<T:FlxBasic>(basic:T, isOverlay:Bool = false):T
	{
		if (basic == null) return null;
		var targetCam = isOverlay ? camEditorOverlay : camEditorUI;
		basic.cameras = [targetCam];
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
				btn.label.cameras = [targetCam];
				btn.label.scrollFactor.set(0, 0);
			}
		}
		if (Std.isOfType(basic, FlxUIDropDownMenu))
		{
			var dd:FlxUIDropDownMenu = cast basic;
			dd.cameras = [targetCam];
			dd.scrollFactor.set(0, 0);
			if (dd.header != null)
			{
				dd.header.cameras = [targetCam];
				dd.header.scrollFactor.set(0, 0);
				if (dd.header.text != null) dd.header.text.cameras = [targetCam];
			}
			if (dd.dropPanel != null)
			{
				dd.dropPanel.cameras = [targetCam];
				dd.dropPanel.scrollFactor.set(0, 0);
			}
			if (dd.list != null)
			{
				for (b in dd.list)
				{
					if (b != null)
					{
						b.cameras = [targetCam];
						b.scrollFactor.set(0, 0);
						if (b.label != null) b.label.cameras = [targetCam];
					}
				}
			}
		}
		else if (Std.isOfType(basic, FlxSpriteGroup))
		{
			var grp:FlxSpriteGroup = cast basic;
			grp.scrollFactor.set(0, 0);
			grp.forEach(function(s) {
				s.cameras = [targetCam];
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
			btn.label.alignment = FlxTextAlign.CENTER;
			btn.label.color = FlxColor.WHITE;
			btn.label.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xCC000000, 1);
			for (off in btn.labelOffsets)
				off.set(0, Math.max(0, (h - btn.label.height) * 0.5 - 1));
		}
	}

	function loadAudio():Void
	{
		if (songMusic != null)
		{
			songMusic.stop();
			FlxG.sound.list.remove(songMusic, true);
			songMusic.destroy();
			songMusic = null;
		}

		if (vocals != null)
		{
			vocals.stop();
			FlxG.sound.list.remove(vocals, true);
			vocals.destroy();
			vocals = null;
		}

		if (opponentVocals != null)
		{
			opponentVocals.stop();
			FlxG.sound.list.remove(opponentVocals, true);
			opponentVocals.destroy();
			opponentVocals = null;
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
				var p1Suffix:String = 'bf';
				if (boyfriend != null && boyfriend.vocalsFile != null && boyfriend.vocalsFile.trim().length > 0)
					p1Suffix = boyfriend.vocalsFile.trim();

				var p2Suffix:String = 'dad';
				if (dadOpponent != null && dadOpponent.vocalsFile != null && dadOpponent.vocalsFile.trim().length > 0)
					p2Suffix = dadOpponent.vocalsFile.trim();

				var playerSound:openfl.media.Sound = Paths.voices(_song.song, p1Suffix);
				if (playerSound == null && boyfriend != null && boyfriend.curCharacter != null && boyfriend.curCharacter != 'bf')
					playerSound = Paths.voices(_song.song, boyfriend.curCharacter);
				if (playerSound == null && p1Suffix != 'bf')
					playerSound = Paths.voices(_song.song, 'bf');

				var oppSound:openfl.media.Sound = Paths.voices(_song.song, p2Suffix);
				if (oppSound == null && dadOpponent != null && dadOpponent.curCharacter != null && dadOpponent.curCharacter != 'dad')
					oppSound = Paths.voices(_song.song, dadOpponent.curCharacter);
				if (oppSound == null && p2Suffix != 'dad')
					oppSound = Paths.voices(_song.song, 'dad');

				if (playerSound != null)
				{
					vocals = new FlxSound().load(playerSound);
					vocals.autoDestroy = false;
					FlxG.sound.list.add(vocals);
				}

				if (oppSound != null)
				{
					opponentVocals = new FlxSound().load(oppSound);
					opponentVocals.autoDestroy = false;
					FlxG.sound.list.add(opponentVocals);
				}

				if (vocals == null)
				{
					var defaultVoice:openfl.media.Sound = Paths.voices(_song.song);
					if (defaultVoice != null)
					{
						vocals = new FlxSound().load(defaultVoice);
						vocals.autoDestroy = false;
						FlxG.sound.list.add(vocals);
					}
				}
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
					if (parsed.name == "ZoomCamera")
						parsed.layer = 2;
					else if (parsed.name == "Change Character")
						parsed.layer = 3;
					else if (parsed.name == "Play Anim")
						parsed.layer = 4;
					else if (parsed.name == "Change Stage")
						parsed.layer = 0;
					else
						parsed.layer = 1;

					if (parsed.name == "Change Character")
					{
						var mergedExisting:Bool = false;
						for (existing in events)
						{
							if (existing != null && existing.name == "Change Character" && existing.target == parsed.target && Math.abs(existing.time - parsed.time) <= 2.0)
							{
								if (parsed.charName != null && parsed.charName.trim() != "")
									existing.charName = parsed.charName.trim();
								if (parsed.x != 0 || parsed.y != 0)
								{
									existing.x = parsed.x;
									existing.y = parsed.y;
								}
								mergedExisting = true;
								break;
							}
						}
						if (!mergedExisting)
							events.push(parsed);
					}
					else
					{
						events.push(parsed);
					}
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

		// Restore persisted Event Group names if present on song metadata
		if (_song != null && _song.eventGroups != null)
		{
			for (eg in _song.eventGroups)
			{
				if (eg != null && Reflect.hasField(eg, "time") && Reflect.hasField(eg, "name"))
				{
					var gTime:Float = Std.parseFloat(Std.string(Reflect.field(eg, "time")));
					var gName:String = Std.string(Reflect.field(eg, "name")).trim();
					var gEvName:String = Reflect.hasField(eg, "event") ? Std.string(Reflect.field(eg, "event")) : "";
					var gTarget:Int = Reflect.hasField(eg, "target") ? Std.parseInt(Std.string(Reflect.field(eg, "target"))) : -999;
					if (!Math.isNaN(gTime) && gName != "")
					{
						for (ev in events)
						{
							if (ev != null && Math.abs(ev.time - gTime) <= 3.0)
							{
								if (gEvName == "" || (ev.name == gEvName && (gTarget == -999 || ev.target == gTarget)))
									ev.groupName = gName;
							}
						}
					}
				}
			}
		}
	}

	function sortEvents():Void
	{
		events.sort(function(a, b) {
			if (Math.abs(a.time - b.time) > 2.0)
			{
				return (a.time < b.time) ? -1 : 1;
			}
			var prioA:Int = (a.name == "Change Stage") ? -1 : ((a.name == "Change Character") ? 0 : ((a.name == "Play Anim") ? 1 : 2));
			var prioB:Int = (b.name == "Change Stage") ? -1 : ((b.name == "Change Character") ? 0 : ((b.name == "Play Anim") ? 1 : 2));
			if (prioA != prioB)
				return prioA - prioB;
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

		songInfoText = bindUI(new FlxText(175, 12, 0, '${_song.song.toUpperCase()}  (${_song.bpm} BPM)', 13));
		songInfoText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		uiGroup.add(songInfoText);

		// View Mode Buttons with V-Slice Icons and glowing active state
		var btnY:Int = 6;

		// 1. Relative View Toggle
		btnRelativeView = bindUI(new FlxButton(415, btnY, "", function() {
			cameraRect.isRelative = !cameraRect.isRelative;
			if (!cameraRect.isRelative)
			{
				var defPos = cameraRect.getDefaultPosition();
				camGame.focusOn(defPos);
				camGame.zoom = 0.75;
				defPos.put();
				showToast("View: Free Camera Overview");
			}
			else
			{
				camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
				camGame.zoom = cameraRect.zoom;
				showToast("View: Virtual Camera Follow");
			}
			saveEditorPreferences();
			updateModeButtonVisuals();
		}));
		btnRelativeView.loadGraphic(Paths.image('menus/editors/camera/menu-bar/relative_view'));
		btnRelativeView.setGraphicSize(28, 28);
		btnRelativeView.updateHitbox();
		uiGroup.add(btnRelativeView);

		// 2. Passepartout Toggle
		btnPassepartout = bindUI(new FlxButton(450, btnY, "", function() {
			cameraRect.showPassepartout = !cameraRect.showPassepartout;
			showToast(cameraRect.showPassepartout ? "Letterbox Mask: ON" : "Letterbox Mask: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
		}));
		btnPassepartout.loadGraphic(Paths.image('menus/editors/camera/menu-bar/passepartout'));
		btnPassepartout.setGraphicSize(28, 28);
		btnPassepartout.updateHitbox();
		uiGroup.add(btnPassepartout);

		// 3. Extended Bounds Toggle
		btnExtendedBounds = bindUI(new FlxButton(485, btnY, "", function() {
			cameraRect.showExtendedBounds = !cameraRect.showExtendedBounds;
			showToast(cameraRect.showExtendedBounds ? "Wide Frame: ON" : "Wide Frame: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
		}));
		btnExtendedBounds.loadGraphic(Paths.image('menus/editors/camera/menu-bar/extended_vcam'));
		btnExtendedBounds.setGraphicSize(28, 28);
		btnExtendedBounds.updateHitbox();
		uiGroup.add(btnExtendedBounds);

		// 4. Camera Bop Toggle
		btnCameraBop = bindUI(new FlxButton(520, btnY + 2, "BOP: OFF", function() {
			cameraRect.doBopping = !cameraRect.doBopping;
			showToast(cameraRect.doBopping ? "Camera Beat Bop: ON" : "Camera Beat Bop: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
		}));
		resizeButton(btnCameraBop, 64, 24);
		uiGroup.add(btnCameraBop);

		// 5. Camera Anchor Points Toggle
		btnCamMarkers = bindUI(new FlxButton(590, btnY + 2, "PTS: ON", function() {
			showCamMarkers = !showCamMarkers;
			showToast(showCamMarkers ? "Character Points: ON" : "Character Points: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
		}));
		resizeButton(btnCamMarkers, 64, 24);
		uiGroup.add(btnCamMarkers);

		// Time readout
		timeText = bindUI(new FlxText(660, 12, 270, "00:00.00 | Step 0 | Beat 0", 12));
		timeText.setFormat(Paths.font("vcr.ttf"), 12, 0xFFEEEEEE, RIGHT);
		uiGroup.add(timeText);

		// Top Actions
		var btnSave = bindUI(new FlxButton(940, btnY + 2, "Save (Ctrl+S)", function() {
			saveEventsToSong();
		}));
		resizeButton(btnSave, 90, 24);
		btnSave.color = 0xFF00AA88;
		uiGroup.add(btnSave);

		var btnChartEd = bindUI(new FlxButton(1036, btnY + 2, "Chart Editor", function() {
			saveEventsToSong();
			saveEditorPreferences();
			Main.switchState(this, new ChartEditor());
		}));
		resizeButton(btnChartEd, 85, 24);
		btnChartEd.color = 0xFF2A82BE;
		uiGroup.add(btnChartEd);

		var btnExit = bindUI(new FlxButton(1127, btnY + 2, "Exit (Esc)", function() {
			saveEventsToSong();
			saveEditorPreferences();
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new MainMenuState());
		}));
		resizeButton(btnExit, 70, 24);
		btnExit.color = 0xFFFF4444;
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
		var startX:Float = INSPECTOR_X + 12;

		inspectorBG = bindUI(new FlxSprite(INSPECTOR_X, 42).makeGraphic(Std.int(INSPECTOR_WIDTH), Std.int(TIMELINE_Y - 42), 0xEE181824));
		inspectorGroup.add(inspectorBG);

		var leftBorder = bindUI(new FlxSprite(INSPECTOR_X - 2, 42).makeGraphic(2, Std.int(TIMELINE_Y - 42), 0xFF2A2A3E));
		inspectorGroup.add(leftBorder);

		inspectorTitle = bindUI(new FlxText(startX, 50, INSPECTOR_WIDTH - 24, "INSPECTOR", 15));
		inspectorTitle.setFormat(Paths.font("vcr.ttf"), 15, 0xFF00FFCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		inspectorGroup.add(inspectorTitle);

		eventTypeLabel = bindUI(new FlxText(startX, 74, INSPECTOR_WIDTH - 24, "No event selected", 11));
		eventTypeLabel.setFormat(Paths.font("vcr.ttf"), 11, 0xFFAAAAAA);
		inspectorGroup.add(eventTypeLabel);

		// ================= OVERVIEW (when no event is selected) =================
		overviewStageText = bindUI(new FlxText(startX, 100, INSPECTOR_WIDTH - 24, "", 12));
		overviewStageText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE);
		inspectorGroup.add(overviewStageText);

		overviewEventsText = bindUI(new FlxText(startX, 124, INSPECTOR_WIDTH - 24, "", 12));
		overviewEventsText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF00FFCC);
		inspectorGroup.add(overviewEventsText);

		btnQuickAddFocus = bindUI(new FlxButton(startX, 150, "+ Focus (F)", addFocusEventAtCurrentTime));
		resizeButton(btnQuickAddFocus, 130, 24);
		btnQuickAddFocus.color = 0xFF00AA88;
		inspectorGroup.add(btnQuickAddFocus);

		btnQuickAddZoom = bindUI(new FlxButton(startX + 135, 150, "+ Zoom (Z)", addZoomEventAtCurrentTime));
		resizeButton(btnQuickAddZoom, 130, 24);
		btnQuickAddZoom.color = 0xFFCC7700;
		inspectorGroup.add(btnQuickAddZoom);

		btnQuickAddChar = bindUI(new FlxButton(startX, 178, "+ Char (C)", addCharEventAtCurrentTime));
		resizeButton(btnQuickAddChar, 130, 24);
		btnQuickAddChar.color = 0xFF9933CC;
		inspectorGroup.add(btnQuickAddChar);

		btnQuickAddAnim = bindUI(new FlxButton(startX + 135, 178, "+ Anim (A)", addAnimEventAtCurrentTime));
		resizeButton(btnQuickAddAnim, 130, 24);
		btnQuickAddAnim.color = 0xFFDDAA00;
		inspectorGroup.add(btnQuickAddAnim);

		btnQuickAddStage = bindUI(new FlxButton(startX, 208, "+ Stage (G)", addStageEventAtCurrentTime));
		resizeButton(btnQuickAddStage, 130, 24);
		btnQuickAddStage.color = 0xFF2A82BE;
		inspectorGroup.add(btnQuickAddStage);

		btnAutoGen = bindUI(new FlxButton(startX + 135, 208, "⚡ Auto-Gen Cam", function() {
			autoGenEvents(true);
		}));
		resizeButton(btnAutoGen, 130, 24);
		btnAutoGen.color = 0xFF1F6E9C;
		inspectorGroup.add(btnAutoGen);

		shortcutsGuideText = bindUI(new FlxText(startX, 238, INSPECTOR_WIDTH - 24,
			"SHORTCUTS:\n" +
			"Space: Play / Pause | Home: Rewind\n" +
			"Left/Right: Step (Shift: Measure)\n" +
			"Right-Drag: Pan View | Wheel: Zoom View\n" +
			"R: Reset View | P: Cam Points | B: Bop\n" +
			"F: Focus | Z: Zoom | C: Char | A: Anim | G: Stg\n" +
			"Ctrl+D: Duplicate | Del: Delete Event\n" +
			"Ctrl+S: Save Song Events\n" +
			"Wheel on Steppers: Adjust (Shift: 5x)\n" +
			"Drag Block: Move | Drag Edge: Duration", 9));
		shortcutsGuideText.setFormat(Paths.font("vcr.ttf"), 9, 0xFF888899, LEFT);
		inspectorGroup.add(shortcutsGuideText);

		overviewGroupsText = bindUI(new FlxText(startX, 392, INSPECTOR_WIDTH - 24, "Grupos de Eventos: 0", 11));
		overviewGroupsText.setFormat(Paths.font("vcr.ttf"), 11, 0xFF00FFCC);
		inspectorGroup.add(overviewGroupsText);

		btnOverviewCreateGroup = bindUI(new FlxButton(startX, 412, "+ Agrupar Tempo", function() {
			groupSameTimeEventsFor(Conductor.songPosition);
		}));
		resizeButton(btnOverviewCreateGroup, 130, 24);
		btnOverviewCreateGroup.color = 0xFF2A82BE;
		inspectorGroup.add(btnOverviewCreateGroup);

		btnOverviewNextGroup = bindUI(new FlxButton(startX + 135, 412, "Ir p/ Grupo >", jumpToNextGroup));
		resizeButton(btnOverviewNextGroup, 130, 24);
		btnOverviewNextGroup.color = 0xFF00AA88;
		inspectorGroup.add(btnOverviewNextGroup);

		// ================= COMMON SELECTED EVENT CONTROLS =================
		eventTimeLabel = bindUI(new FlxText(startX, 94, 140, "Time: 0ms", 11));
		eventTimeLabel.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE);
		inspectorGroup.add(eventTimeLabel);

		btnNudgeBack = bindUI(new FlxButton(INSPECTOR_X + 160, 91, "< Step", function() {
			nudgeEventTime(-1.0);
		}));
		resizeButton(btnNudgeBack, 52, 20);
		btnNudgeBack.color = 0xFF333344;
		inspectorGroup.add(btnNudgeBack);

		btnNudgeForward = bindUI(new FlxButton(INSPECTOR_X + 218, 91, "Step >", function() {
			nudgeEventTime(1.0);
		}));
		resizeButton(btnNudgeForward, 52, 20);
		btnNudgeForward.color = 0xFF333344;
		inspectorGroup.add(btnNudgeForward);

		// ================= FOCUS CAMERA CONTROLS =================
		focusTargetLabel = bindUI(new FlxText(startX, 118, 0, "Target Character:"));
		inspectorGroup.add(focusTargetLabel);

		var charChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)", "Custom Point (-1)"];
		focusTargetDropDown = bindUI(new FlxUIDropDownMenu(startX, 136, FlxUIDropDownMenu.makeStrIdLabelArray(charChoices, true), function(chosen:String) {
			if (selectedEvent != null && selectedEvent.name == "FocusCamera")
			{
				var idx = Std.parseInt(chosen);
				selectedEvent.target = (idx == 3) ? -1 : idx;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
				updateInspectorUI();
			}
		}), true);
		focusTargetDropDown.dropDirection = Down;
		focusTargetDropDown.selectedLabel = charChoices[0];

		focusOffsetLabel = bindUI(new FlxText(startX, 168, 0, "Offset X / Y (Pixels):"));
		inspectorGroup.add(focusOffsetLabel);

		focusXStepper = bindUI(new FlxUINumericStepper(startX, 186, 10, 0, -2000, 2000, 0));
		focusXStepper.name = 'focus_x';
		inspectorGroup.add(focusXStepper);

		focusYStepper = bindUI(new FlxUINumericStepper(startX + 85, 186, 10, 0, -2000, 2000, 0));
		focusYStepper.name = 'focus_y';
		inspectorGroup.add(focusYStepper);

		btnResetOffset = bindUI(new FlxButton(startX + 172, 186, "Reset (0,0)", function() {
			if (selectedEvent != null && selectedEvent.name == "FocusCamera")
			{
				selectedEvent.x = 0;
				selectedEvent.y = 0;
				focusXStepper.value = 0;
				focusYStepper.value = 0;
				replayCameraTimeline(Conductor.songPosition);
				updateInspectorUI();
			}
		}));
		resizeButton(btnResetOffset, 78, 20);
		btnResetOffset.color = 0xFF444455;
		inspectorGroup.add(btnResetOffset);

		focusDurationLabel = bindUI(new FlxText(startX, 218, 0, "Duration (steps):"));
		inspectorGroup.add(focusDurationLabel);

		focusDurationStepper = bindUI(new FlxUINumericStepper(startX, 236, 0.5, 4.0, 0.5, 128, 1));
		focusDurationStepper.name = 'focus_duration';
		inspectorGroup.add(focusDurationStepper);

		focusDurationSub = bindUI(new FlxText(startX + 85, 239, 160, "(= 1.0 beat)", 10));
		focusDurationSub.setFormat(Paths.font("vcr.ttf"), 10, 0xFFAAAAAA);
		inspectorGroup.add(focusDurationSub);

		focusEaseLabel = bindUI(new FlxText(startX, 268, 0, "Easing Function:"));
		inspectorGroup.add(focusEaseLabel);

		focusEaseInput = bindUI(new FlxUIInputText(startX, 286, 115, "CLASSIC", 8));
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

		focusEaseDropDown = bindUI(new FlxUIDropDownMenu(startX + 122, 286, FlxUIDropDownMenu.makeStrIdLabelArray(availableEases, true), function(easeIdx:String) {
			if (selectedEvent != null)
			{
				var chosen = availableEases[Std.parseInt(easeIdx)];
				selectedEvent.ease = chosen;
				if (focusEaseInput != null)
					focusEaseInput.text = chosen;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}), true);
		focusEaseDropDown.dropDirection = Down;

		// ================= ZOOM CAMERA CONTROLS =================
		zoomValLabel = bindUI(new FlxText(startX, 118, 0, "Target Zoom Multiplier:"));
		inspectorGroup.add(zoomValLabel);

		zoomValueStepper = bindUI(new FlxUINumericStepper(startX, 136, 0.05, 1.0, 0.1, 5.0, 2));
		zoomValueStepper.name = 'zoom_val';
		inspectorGroup.add(zoomValueStepper);

		btnZoomPresetStage = bindUI(new FlxButton(startX, 168, 'Stage (${defaultStageZoom}x)', function() {
			if (selectedEvent != null && selectedEvent.name == "ZoomCamera")
			{
				selectedEvent.zoom = defaultStageZoom;
				zoomValueStepper.value = defaultStageZoom;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		resizeButton(btnZoomPresetStage, 85, 20);
		btnZoomPresetStage.color = 0xFF333344;
		inspectorGroup.add(btnZoomPresetStage);

		btnZoomPresetClose = bindUI(new FlxButton(startX + 90, 168, "Close (1.3x)", function() {
			if (selectedEvent != null && selectedEvent.name == "ZoomCamera")
			{
				selectedEvent.zoom = 1.3;
				zoomValueStepper.value = 1.3;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		resizeButton(btnZoomPresetClose, 85, 20);
		btnZoomPresetClose.color = 0xFF333344;
		inspectorGroup.add(btnZoomPresetClose);

		btnZoomPresetWide = bindUI(new FlxButton(startX + 180, 168, "Wide (0.8x)", function() {
			if (selectedEvent != null && selectedEvent.name == "ZoomCamera")
			{
				selectedEvent.zoom = 0.8;
				zoomValueStepper.value = 0.8;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}));
		resizeButton(btnZoomPresetWide, 85, 20);
		btnZoomPresetWide.color = 0xFF333344;
		inspectorGroup.add(btnZoomPresetWide);

		zoomDurLabel = bindUI(new FlxText(startX, 198, 0, "Duration (steps):"));
		inspectorGroup.add(zoomDurLabel);

		zoomDurationStepper = bindUI(new FlxUINumericStepper(startX, 216, 0.5, 4.0, 0.5, 128, 1));
		zoomDurationStepper.name = 'zoom_dur';
		inspectorGroup.add(zoomDurationStepper);

		zoomDurationSub = bindUI(new FlxText(startX + 85, 219, 160, "(= 1.0 beat)", 10));
		zoomDurationSub.setFormat(Paths.font("vcr.ttf"), 10, 0xFFAAAAAA);
		inspectorGroup.add(zoomDurationSub);

		zoomEaseLabel = bindUI(new FlxText(startX, 248, 0, "Easing Function:"));
		inspectorGroup.add(zoomEaseLabel);

		zoomEaseInput = bindUI(new FlxUIInputText(startX, 266, 115, "linear", 8));
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

		zoomEaseDropDown = bindUI(new FlxUIDropDownMenu(startX + 122, 266, FlxUIDropDownMenu.makeStrIdLabelArray(availableEases, true), function(easeIdx:String) {
			if (selectedEvent != null)
			{
				var chosen = availableEases[Std.parseInt(easeIdx)];
				selectedEvent.ease = chosen;
				if (zoomEaseInput != null)
					zoomEaseInput.text = chosen;
				replayCameraTimeline(Conductor.songPosition);
				refreshEventBlocks();
			}
		}), true);
		zoomEaseDropDown.dropDirection = Down;

		// ================= CHANGE CHARACTER CONTROLS =================
		charTargetLabel = bindUI(new FlxText(startX, 118, 0, "Target Character:"));
		inspectorGroup.add(charTargetLabel);

		var charTargetChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)"];
		charTargetDropDown = bindUI(new FlxUIDropDownMenu(startX, 136, FlxUIDropDownMenu.makeStrIdLabelArray(charTargetChoices, true), function(chosen:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Character")
			{
				selectedEvent.target = Std.parseInt(chosen);
				applySelectedCharEventPreview();
				refreshEventBlocks();
				updateInspectorUI();
			}
		}), true);
		charTargetDropDown.dropDirection = Down;
		charTargetDropDown.selectedLabel = charTargetChoices[1];

		charNameLabel = bindUI(new FlxText(startX, 168, 0, "Character JSON:"));
		inspectorGroup.add(charNameLabel);

		charNameInput = bindUI(new FlxUIInputText(startX, 186, 120, "", 8));
		charNameInput.backgroundColor = 0xFF222233;
		charNameInput.color = FlxColor.WHITE;
		charNameInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Character")
			{
				selectedEvent.charName = text.trim();
				charNameDropDown.selectedLabel = text.trim();
				applySelectedCharEventPreview();
				refreshEventBlocks();
			}
		};
		inspectorGroup.add(charNameInput);

		var charListChoices = (characterList != null && characterList.length > 0) ? characterList : ["dad", "bf", "gf"];
		charNameDropDown = bindUI(new FlxUIDropDownMenu(startX + 126, 186, FlxUIDropDownMenu.makeStrIdLabelArray(charListChoices, true), function(chosenIdx:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Character")
			{
				var idx = Std.parseInt(chosenIdx);
				if (idx >= 0 && idx < charListChoices.length)
				{
					var chosenChar = charListChoices[idx];
					selectedEvent.charName = chosenChar;
					if (charNameInput != null) charNameInput.text = chosenChar;
					applySelectedCharEventPreview();
					refreshEventBlocks();
				}
			}
		}), true);
		charNameDropDown.dropDirection = Down;

		charOffsetLabel = bindUI(new FlxText(startX, 218, 0, "Custom Offset X / Y (Optional):"));
		inspectorGroup.add(charOffsetLabel);

		charXStepper = bindUI(new FlxUINumericStepper(startX, 236, 10, 0, -3000, 3000, 0));
		charXStepper.name = 'char_x';
		inspectorGroup.add(charXStepper);

		charYStepper = bindUI(new FlxUINumericStepper(startX + 85, 236, 10, 0, -3000, 3000, 0));
		charYStepper.name = 'char_y';
		inspectorGroup.add(charYStepper);

		btnResetCharOffset = bindUI(new FlxButton(startX + 172, 236, "Reset (0,0)", function() {
			if (selectedEvent != null && selectedEvent.name == "Change Character")
			{
				selectedEvent.x = 0;
				selectedEvent.y = 0;
				charXStepper.value = 0;
				charYStepper.value = 0;
				applySelectedCharEventPreview();
				updateInspectorUI();
			}
		}));
		resizeButton(btnResetCharOffset, 78, 20);
		btnResetCharOffset.color = 0xFF444455;
		inspectorGroup.add(btnResetCharOffset);

		// ================= PLAY ANIMATION CONTROLS =================
		animTargetLabel = bindUI(new FlxText(startX, 118, 0, "Target Character:"));
		inspectorGroup.add(animTargetLabel);

		var animTargetChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)"];
		animTargetDropDown = bindUI(new FlxUIDropDownMenu(startX, 136, FlxUIDropDownMenu.makeStrIdLabelArray(animTargetChoices, true), function(chosen:String) {
			if (selectedEvent != null && selectedEvent.name == "Play Anim")
			{
				selectedEvent.target = Std.parseInt(chosen);
				updateAnimDropDownChoices();
				refreshEventBlocks();
				updateInspectorUI();
			}
		}), true);
		animTargetDropDown.dropDirection = Down;
		animTargetDropDown.selectedLabel = animTargetChoices[1];

		animNameLabel = bindUI(new FlxText(startX, 168, 0, "Animation Name:"));
		inspectorGroup.add(animNameLabel);

		animNameInput = bindUI(new FlxUIInputText(startX, 186, 120, "singUP", 8));
		animNameInput.backgroundColor = 0xFF222233;
		animNameInput.color = FlxColor.WHITE;
		animNameInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "Play Anim")
			{
				selectedEvent.animName = text.trim();
				animNameDropDown.selectedLabel = text.trim();
				refreshEventBlocks();
				if (action == "enter")
				{
					playEditorAnimation(selectedEvent.target, selectedEvent.animName, true);
				}
			}
		};
		inspectorGroup.add(animNameInput);

		animNameDropDown = bindUI(new FlxUIDropDownMenu(startX + 126, 186, FlxUIDropDownMenu.makeStrIdLabelArray(["idle", "singUP"], true), function(chosenIdx:String) {
			if (selectedEvent != null && selectedEvent.name == "Play Anim")
			{
				var chosenAnim = animNameDropDown.selectedLabel;
				selectedEvent.animName = chosenAnim;
				if (animNameInput != null) animNameInput.text = chosenAnim;
				refreshEventBlocks();
				playEditorAnimation(selectedEvent.target, chosenAnim, true);
			}
		}), true);
		animNameDropDown.dropDirection = Down;

		animLockCheckbox = bindUI(new FlxUICheckBox(startX, 222, null, null, "Lock Animation (no interrupt)", 250));
		animLockCheckbox.callback = function() {
			if (selectedEvent != null && selectedEvent.name == "Play Anim")
			{
				selectedEvent.animLock = animLockCheckbox.checked;
			}
		};
		inspectorGroup.add(animLockCheckbox);

		btnTestAnim = bindUI(new FlxButton(startX, 252, "▶ Play Animation Now", function() {
			if (selectedEvent != null && selectedEvent.name == "Play Anim")
			{
				var char:Character = (selectedEvent.target == 0) ? boyfriend : ((selectedEvent.target == 2) ? gf : dadOpponent);
				if (char != null)
					char.animLocked = selectedEvent.animLock;
				playEditorAnimation(selectedEvent.target, selectedEvent.animName, true);
			}
		}));
		resizeButton(btnTestAnim, 265, 26);
		btnTestAnim.color = 0xFFDDAA00;
		inspectorGroup.add(btnTestAnim);

		// ================= CHANGE STAGE CONTROLS =================
		stageTargetLabel = bindUI(new FlxText(startX, 118, 0, "Target Stage:"));
		inspectorGroup.add(stageTargetLabel);

		stageNameInput = bindUI(new FlxUIInputText(startX, 136, 120, "", 8));
		stageNameInput.backgroundColor = 0xFF222233;
		stageNameInput.color = FlxColor.WHITE;
		stageNameInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Stage")
			{
				selectedEvent.stageName = text.trim();
				if (stageNameDropDown != null) stageNameDropDown.selectedLabel = text.trim();
				refreshEventBlocks();
				if (action == "enter")
					replayCameraTimeline(Conductor.songPosition);
			}
		};
		inspectorGroup.add(stageNameInput);

		var stageDropdownChoices:Array<String> = (stageList != null && stageList.length > 0) ? stageList.copy() : [initialStageName];
		if (stageDropdownChoices.indexOf("random") == -1) stageDropdownChoices.push("random");
		stageNameDropDown = bindUI(new FlxUIDropDownMenu(startX + 126, 136, FlxUIDropDownMenu.makeStrIdLabelArray(stageDropdownChoices, true), function(chosenIdx:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Stage")
			{
				var idx = Std.parseInt(chosenIdx);
				if (idx >= 0 && idx < stageDropdownChoices.length)
				{
					var chosenStage = stageDropdownChoices[idx];
					selectedEvent.stageName = chosenStage;
					if (stageNameInput != null) stageNameInput.text = chosenStage;
					replayCameraTimeline(Conductor.songPosition);
					refreshEventBlocks();
					updateInspectorUI();
				}
			}
		}), true);
		stageNameDropDown.dropDirection = Down;

		stageOptionsLabel = bindUI(new FlxText(startX, 168, 0, "Options (norepos, nozoom, snap, flash):"));
		inspectorGroup.add(stageOptionsLabel);

		stageOptionsInput = bindUI(new FlxUIInputText(startX, 186, 260, "", 8));
		stageOptionsInput.backgroundColor = 0xFF222233;
		stageOptionsInput.color = FlxColor.WHITE;
		stageOptionsInput.callback = function(text:String, action:String) {
			if (selectedEvent != null && selectedEvent.name == "Change Stage")
			{
				selectedEvent.stageOptions = text.trim();
				if (action == "enter")
					replayCameraTimeline(Conductor.songPosition);
			}
		};
		inspectorGroup.add(stageOptionsInput);

		btnStageOptNoRepos = bindUI(new FlxButton(startX, 212, "norepos", function() {
			toggleStageOptionFlag("norepos");
		}));
		resizeButton(btnStageOptNoRepos, 84, 20);
		btnStageOptNoRepos.color = 0xFF333344;
		inspectorGroup.add(btnStageOptNoRepos);

		btnStageOptNoZoom = bindUI(new FlxButton(startX + 88, 212, "nozoom", function() {
			toggleStageOptionFlag("nozoom");
		}));
		resizeButton(btnStageOptNoZoom, 84, 20);
		btnStageOptNoZoom.color = 0xFF333344;
		inspectorGroup.add(btnStageOptNoZoom);

		btnStageOptFlash = bindUI(new FlxButton(startX + 176, 212, "flash", function() {
			toggleStageOptionFlag("flash");
		}));
		resizeButton(btnStageOptFlash, 84, 20);
		btnStageOptFlash.color = 0xFF333344;
		inspectorGroup.add(btnStageOptFlash);

		btnPreviewStage = bindUI(new FlxButton(startX, 242, "▶ Preview Stage Now", function() {
			if (selectedEvent != null && selectedEvent.name == "Change Stage")
			{
				applyStageEvent(selectedEvent, true, true);
				updateInspectorUI();
				showToast('Stage preview: ${activeStageName}');
			}
		}));
		resizeButton(btnPreviewStage, 265, 26);
		btnPreviewStage.color = 0xFF2A82BE;
		inspectorGroup.add(btnPreviewStage);

		// ================= EVENT GROUP MANAGER (SELECTED EVENT) =================
		groupSectionLabel = bindUI(new FlxText(startX, 314, INSPECTOR_WIDTH - 24, "Grupo de Eventos: [Nenhum]", 10));
		groupSectionLabel.setFormat(Paths.font("vcr.ttf"), 10, 0xFF00FFCC);
		inspectorGroup.add(groupSectionLabel);

		groupNameInput = bindUI(new FlxUIInputText(startX, 331, 120, "", 8));
		groupNameInput.backgroundColor = 0xFF222233;
		groupNameInput.color = FlxColor.WHITE;
		groupNameInput.callback = function(text:String, action:String) {
			if (action == "enter" && selectedEvent != null)
			{
				selectedEvent.groupName = text.trim();
				refreshEventBlocks();
				updateInspectorUI();
			}
		};
		inspectorGroup.add(groupNameInput);

		btnAssignGroup = bindUI(new FlxButton(startX + 124, 329, "Nomear", assignGroupNameToSelected));
		resizeButton(btnAssignGroup, 64, 20);
		btnAssignGroup.color = 0xFF2A82BE;
		inspectorGroup.add(btnAssignGroup);

		btnGroupSameTime = bindUI(new FlxButton(startX + 192, 329, "Agrupar", function() {
			if (selectedEvent != null)
			{
				var typedName = (groupNameInput != null && groupNameInput.text != null) ? groupNameInput.text.trim() : "";
				groupSameTimeEventsFor(selectedEvent.time, typedName);
			}
		}));
		resizeButton(btnGroupSameTime, 70, 20);
		btnGroupSameTime.color = 0xFF00AA88;
		inspectorGroup.add(btnGroupSameTime);

		btnPrevGroupEv = bindUI(new FlxButton(startX, 353, "<", function() {
			navigateGroupEvent(-1);
		}));
		resizeButton(btnPrevGroupEv, 26, 20);
		btnPrevGroupEv.color = 0xFF333344;
		inspectorGroup.add(btnPrevGroupEv);

		groupMemberText = bindUI(new FlxText(startX + 30, 356, 200, "1/1", 10));
		groupMemberText.setFormat(Paths.font("vcr.ttf"), 10, FlxColor.WHITE, CENTER);
		inspectorGroup.add(groupMemberText);

		btnNextGroupEv = bindUI(new FlxButton(startX + 234, 353, ">", function() {
			navigateGroupEvent(1);
		}));
		resizeButton(btnNextGroupEv, 26, 20);
		btnNextGroupEv.color = 0xFF333344;
		inspectorGroup.add(btnNextGroupEv);

		btnUngroupEvent = bindUI(new FlxButton(startX, 377, "Desagrupar", ungroupSelectedEvent));
		resizeButton(btnUngroupEvent, 82, 20);
		btnUngroupEvent.color = 0xFF555566;
		inspectorGroup.add(btnUngroupEvent);

		btnAddToGroup = bindUI(new FlxButton(startX + 86, 377, "+ Add Evento", addEventInsideCurrentGroup));
		resizeButton(btnAddToGroup, 90, 20);
		btnAddToGroup.color = 0xFF00AA88;
		inspectorGroup.add(btnAddToGroup);

		btnDeleteGroupAll = bindUI(new FlxButton(startX + 180, 377, "Del Grupo", deleteSelectedGroup));
		resizeButton(btnDeleteGroupAll, 80, 20);
		btnDeleteGroupAll.color = 0xFFAA3333;
		inspectorGroup.add(btnDeleteGroupAll);

		groupDragMoveCheck = bindUI(new FlxUICheckBox(startX, 401, null, null, "Mover grupo junto ao arrastar", 250));
		groupDragMoveCheck.checked = true;
		inspectorGroup.add(groupDragMoveCheck);

		// ================= BOTTOM ACTIONS (DUPLICATE / DELETE / DESELECT) =================
		// Positioned safely at the bottom (y: 425+) away from dropdown lists
		btnDuplicateEvent = bindUI(new FlxButton(startX, 425, "Duplicate (Ctrl+D)", duplicateEvent));
		resizeButton(btnDuplicateEvent, 126, 26);
		btnDuplicateEvent.color = 0xFF00AA88;
		inspectorGroup.add(btnDuplicateEvent);

		btnDeleteEvent = bindUI(new FlxButton(startX + 134, 425, "Delete (Del)", function() {
			if (selectedEvent != null)
			{
				events.remove(selectedEvent);
				selectedEvent = null;
				refreshEventBlocks();
				updateInspectorUI();
				replayCameraTimeline(Conductor.songPosition);
				showToast("Event deleted!");
			}
		}));
		resizeButton(btnDeleteEvent, 126, 26);
		btnDeleteEvent.color = 0xFFFF4444;
		inspectorGroup.add(btnDeleteEvent);

		btnDeselectEvent = bindUI(new FlxButton(startX, 458, "Deselect Event", function() {
			selectedEvent = null;
			updateInspectorUI();
			refreshEventBlocks();
		}));
		resizeButton(btnDeselectEvent, 260, 24);
		btnDeselectEvent.color = 0xFF444455;
		inspectorGroup.add(btnDeselectEvent);

		// Dropdowns added last to ensure top overlay
		inspectorGroup.add(focusEaseDropDown);
		inspectorGroup.add(focusTargetDropDown);
		inspectorGroup.add(zoomEaseDropDown);
		inspectorGroup.add(charTargetDropDown);
		inspectorGroup.add(charNameDropDown);
		inspectorGroup.add(animTargetDropDown);
		inspectorGroup.add(animNameDropDown);
		inspectorGroup.add(stageNameDropDown);
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
						updateInspectorUI();
					case 'focus_y':
						selectedEvent.y = nums.value;
						updateInspectorUI();
					case 'focus_duration':
						selectedEvent.duration = Math.max(0.5, nums.value);
						if (focusDurationSub != null)
							focusDurationSub.text = '(= ${(Math.round(selectedEvent.duration / 4 * 10) / 10)} beats)';
						refreshEventBlocks();
					case 'zoom_val':
						selectedEvent.zoom = nums.value;
						updateInspectorUI();
					case 'zoom_dur':
						selectedEvent.duration = Math.max(0.5, nums.value);
						if (zoomDurationSub != null)
							zoomDurationSub.text = '(= ${(Math.round(selectedEvent.duration / 4 * 10) / 10)} beats)';
						refreshEventBlocks();
					case 'char_x':
						selectedEvent.x = nums.value;
						applySelectedCharEventPreview();
						updateInspectorUI();
						return;
					case 'char_y':
						selectedEvent.y = nums.value;
						applySelectedCharEventPreview();
						updateInspectorUI();
						return;
				}
				replayCameraTimeline(Conductor.songPosition);
			}
		}
		else if (id == FlxUICheckBox.CLICK_EVENT && (sender is FlxUICheckBox))
		{
			var cb:FlxUICheckBox = cast sender;
			if (selectedEvent != null && selectedEvent.name == "Play Anim" && cb == animLockCheckbox)
			{
				selectedEvent.animLock = cb.checked;
			}
		}
	}

	function applySelectedCharEventPreview():Void
	{
		if (selectedEvent == null || selectedEvent.name != "Change Character") return;
		var customX:Null<Float> = (selectedEvent.x != 0 || selectedEvent.y != 0) ? selectedEvent.x : null;
		var customY:Null<Float> = (selectedEvent.x != 0 || selectedEvent.y != 0) ? selectedEvent.y : null;

		if (selectedEvent.target == 0)
		{
			activeBfChar = selectedEvent.charName;
			activeBfCustomX = customX;
			activeBfCustomY = customY;
		}
		else if (selectedEvent.target == 2)
		{
			activeGfChar = selectedEvent.charName;
			activeGfCustomX = customX;
			activeGfCustomY = customY;
		}
		else
		{
			activeDadChar = selectedEvent.charName;
			activeDadCustomX = customX;
			activeDadCustomY = customY;
		}

		changeEditorCharacter(selectedEvent.target, selectedEvent.charName, customX, customY);
		var previewTime = (!isPlaying) ? Math.max(Conductor.songPosition, selectedEvent.time) : Conductor.songPosition;
		replayCameraTimeline(previewTime);
	}

	function updateInspectorUI():Void
	{
		var hasSel:Bool = (selectedEvent != null);

		// Hide any open dropdown lists when updating inspector state
		closeAllDropdowns();

		// Common event controls visibility
		if (eventTimeLabel != null) eventTimeLabel.visible = hasSel;
		if (btnNudgeBack != null) btnNudgeBack.visible = hasSel;
		if (btnNudgeForward != null) btnNudgeForward.visible = hasSel;
		if (btnDuplicateEvent != null) btnDuplicateEvent.visible = hasSel;
		if (btnDeleteEvent != null) btnDeleteEvent.visible = hasSel;
		if (btnDeselectEvent != null) btnDeselectEvent.visible = hasSel;

		if (overviewGroupsText != null) overviewGroupsText.visible = !hasSel;
		if (btnOverviewCreateGroup != null) btnOverviewCreateGroup.visible = !hasSel;
		if (btnOverviewNextGroup != null) btnOverviewNextGroup.visible = !hasSel;

		if (groupSectionLabel != null) groupSectionLabel.visible = hasSel;
		if (groupNameInput != null) groupNameInput.visible = hasSel;
		if (btnAssignGroup != null) btnAssignGroup.visible = hasSel;
		if (btnGroupSameTime != null) btnGroupSameTime.visible = hasSel;
		if (btnPrevGroupEv != null) btnPrevGroupEv.visible = hasSel;
		if (groupMemberText != null) groupMemberText.visible = hasSel;
		if (btnNextGroupEv != null) btnNextGroupEv.visible = hasSel;
		if (btnUngroupEvent != null) btnUngroupEvent.visible = hasSel;
		if (btnAddToGroup != null) btnAddToGroup.visible = hasSel;
		if (btnDeleteGroupAll != null) btnDeleteGroupAll.visible = hasSel;
		if (groupDragMoveCheck != null) groupDragMoveCheck.visible = hasSel;

		if (!hasSel)
		{
			inspectorTitle.text = "INSPECTOR";
			inspectorTitle.color = 0xFF00FFCC;
			eventTypeLabel.text = "STAGE & CAMERA OVERVIEW";

			// Show overview widgets
			overviewStageText.visible = true;
			overviewEventsText.visible = true;
			btnQuickAddFocus.visible = true;
			btnQuickAddZoom.visible = true;
			btnQuickAddChar.visible = true;
			btnQuickAddAnim.visible = true;
			if (btnQuickAddStage != null) btnQuickAddStage.visible = true;
			btnAutoGen.visible = true;
			shortcutsGuideText.visible = true;

			var focusCount = 0;
			var zoomCount = 0;
			var charCount = 0;
			var animCount = 0;
			var stageCount = 0;
			for (e in events)
			{
				if (e.name == "FocusCamera") focusCount++;
				else if (e.name == "ZoomCamera") zoomCount++;
				else if (e.name == "Change Character") charCount++;
				else if (e.name == "Play Anim") animCount++;
				else if (e.name == "Change Stage") stageCount++;
			}
			overviewStageText.text = 'Stage: ${activeStageName} | Zoom: ${defaultStageZoom}x';
			overviewEventsText.text = 'Events: ${events.length} (Stg:$stageCount Foc:$focusCount)\nZoom:$zoomCount | Char:$charCount | Anim:$animCount';
			if (overviewGroupsText != null)
			{
				var gNames = getAllGroupNames();
				overviewGroupsText.text = 'Grupos de Eventos: ${gNames.length}';
			}

			// Hide specific controls
			setFocusControlsVisible(false);
			setZoomControlsVisible(false);
			setCharControlsVisible(false);
			setAnimControlsVisible(false);
			setStageControlsVisible(false);
		}
		else
		{
			// Hide overview widgets
			overviewStageText.visible = false;
			overviewEventsText.visible = false;
			btnQuickAddFocus.visible = false;
			btnQuickAddZoom.visible = false;
			btnQuickAddChar.visible = false;
			btnQuickAddAnim.visible = false;
			if (btnQuickAddStage != null) btnQuickAddStage.visible = false;
			btnAutoGen.visible = false;
			shortcutsGuideText.visible = false;

			var evStep = Conductor.calculateDecStep(selectedEvent.time);
			var roundedStep = Math.round(evStep * 10) / 10;
			var evBeat = Math.round((evStep / 4.0) * 10) / 10;
			eventTimeLabel.text = 'Time: ${Math.round(selectedEvent.time)}ms\n(S: $roundedStep | B: $evBeat)';

			if (groupSectionLabel != null)
			{
				var gList = getNavigationListForSelected();
				var gIdx = gList.indexOf(selectedEvent);
				if (gIdx < 0) gIdx = 0;
				var sameTimeCount = getEventsAtSameTime(selectedEvent.time, 2.0).length;
				if (selectedEvent.groupName != "")
				{
					groupSectionLabel.text = 'Grupo: "${selectedEvent.groupName}" (${gList.length} ev)';
					groupSectionLabel.color = getGroupColor(selectedEvent.groupName);
				}
				else
				{
					groupSectionLabel.text = (sameTimeCount > 1)
						? 'Sem grupo ($sameTimeCount no mesmo tempo!)'
						: 'Grupo: [Nenhum]';
					groupSectionLabel.color = (sameTimeCount > 1) ? 0xFFFFAA33 : 0xFFAAAAAA;
				}
				if (groupNameInput != null && !groupNameInput.hasFocus)
					groupNameInput.text = selectedEvent.groupName;
				if (groupMemberText != null)
					groupMemberText.text = '${gIdx + 1}/${Math.max(1, gList.length)}: ${selectedEvent.name}';
			}

			if (selectedEvent.name == "FocusCamera")
			{
				inspectorTitle.text = "FOCUS CAMERA";
				inspectorTitle.color = 0xFF00AA88;
				var base = cameraRect != null ? cameraRect.getCharacterCameraPoint(selectedEvent.target) : FlxPoint.get(0, 0);
				var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : ((selectedEvent.target == 2) ? "GF" : "CUSTOM"));
				eventTypeLabel.text = 'Target: $targetName | Pos: (${Math.round(base.x + selectedEvent.x)}, ${Math.round(base.y + selectedEvent.y)})';
				base.put();

				setFocusControlsVisible(true);
				setZoomControlsVisible(false);
				setCharControlsVisible(false);
				setAnimControlsVisible(false);
				setStageControlsVisible(false);

				focusXStepper.value = selectedEvent.x;
				focusYStepper.value = selectedEvent.y;
				focusDurationStepper.value = selectedEvent.duration;
				focusDurationSub.text = '(= ${(Math.round(selectedEvent.duration / 4 * 10) / 10)} beats)';
				focusEaseInput.text = selectedEvent.ease;
				focusEaseDropDown.selectedLabel = selectedEvent.ease;

				var targetIdx = (selectedEvent.target == -1) ? 3 : selectedEvent.target;
				var charChoices:Array<String> = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)", "Custom Point (-1)"];
				if (targetIdx >= 0 && targetIdx < charChoices.length)
					focusTargetDropDown.selectedLabel = charChoices[targetIdx];
			}
			else if (selectedEvent.name == "ZoomCamera")
			{
				inspectorTitle.text = "ZOOM CAMERA";
				inspectorTitle.color = 0xFFCC7700;
				eventTypeLabel.text = 'Target Zoom: ${selectedEvent.zoom}x';

				setFocusControlsVisible(false);
				setZoomControlsVisible(true);
				setCharControlsVisible(false);
				setAnimControlsVisible(false);
				setStageControlsVisible(false);

				zoomValueStepper.value = selectedEvent.zoom;
				zoomDurationStepper.value = selectedEvent.duration;
				zoomDurationSub.text = '(= ${(Math.round(selectedEvent.duration / 4 * 10) / 10)} beats)';
				zoomEaseInput.text = selectedEvent.ease;
				zoomEaseDropDown.selectedLabel = selectedEvent.ease;
			}
			else if (selectedEvent.name == "Change Character")
			{
				inspectorTitle.text = "CHANGE CHARACTER";
				inspectorTitle.color = 0xFF9933CC;
				var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : "GF");
				eventTypeLabel.text = 'Target: $targetName | Character: ${selectedEvent.charName}';

				setFocusControlsVisible(false);
				setZoomControlsVisible(false);
				setCharControlsVisible(true);
				setAnimControlsVisible(false);
				setStageControlsVisible(false);

				var targetChoices = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)"];
				var tidx = (selectedEvent.target == 0) ? 0 : ((selectedEvent.target == 2) ? 2 : 1);
				charTargetDropDown.selectedLabel = targetChoices[tidx];

				charNameInput.text = selectedEvent.charName;
				charNameDropDown.selectedLabel = selectedEvent.charName;

				charXStepper.value = selectedEvent.x;
				charYStepper.value = selectedEvent.y;
			}
			else if (selectedEvent.name == "Play Anim")
			{
				inspectorTitle.text = "PLAY ANIMATION";
				inspectorTitle.color = 0xFFDDAA00;
				var targetName = (selectedEvent.target == 0) ? "BF" : ((selectedEvent.target == 1) ? "DAD" : "GF");
				eventTypeLabel.text = 'Target: $targetName | Anim: ${selectedEvent.animName}';

				setFocusControlsVisible(false);
				setZoomControlsVisible(false);
				setCharControlsVisible(false);
				setAnimControlsVisible(true);
				setStageControlsVisible(false);

				var targetChoices = ["Boyfriend (0)", "Opponent (1)", "Girlfriend (2)"];
				var tidx = (selectedEvent.target == 0) ? 0 : ((selectedEvent.target == 2) ? 2 : 1);
				animTargetDropDown.selectedLabel = targetChoices[tidx];

				updateAnimDropDownChoices();
				animNameInput.text = selectedEvent.animName;
				animNameDropDown.selectedLabel = selectedEvent.animName;
				animLockCheckbox.checked = selectedEvent.animLock;
			}
			else if (selectedEvent.name == "Change Stage")
			{
				inspectorTitle.text = "CHANGE STAGE";
				inspectorTitle.color = 0xFF2A82BE;
				eventTypeLabel.text = 'Stage: ${(selectedEvent.stageName != "" ? selectedEvent.stageName : "stage")}';

				setFocusControlsVisible(false);
				setZoomControlsVisible(false);
				setCharControlsVisible(false);
				setAnimControlsVisible(false);
				setStageControlsVisible(true);

				if (stageNameInput != null && !stageNameInput.hasFocus)
					stageNameInput.text = selectedEvent.stageName;
				if (stageNameDropDown != null)
					stageNameDropDown.selectedLabel = selectedEvent.stageName;
				if (stageOptionsInput != null && !stageOptionsInput.hasFocus)
					stageOptionsInput.text = selectedEvent.stageOptions;
			}
		}
	}

	function setFocusControlsVisible(vis:Bool):Void
	{
		if (focusTargetLabel != null) focusTargetLabel.visible = vis;
		if (focusTargetDropDown != null) focusTargetDropDown.visible = vis;
		if (focusOffsetLabel != null) focusOffsetLabel.visible = vis;
		if (focusXStepper != null) focusXStepper.visible = vis;
		if (focusYStepper != null) focusYStepper.visible = vis;
		if (btnResetOffset != null) btnResetOffset.visible = vis;
		if (focusDurationLabel != null) focusDurationLabel.visible = vis;
		if (focusDurationStepper != null) focusDurationStepper.visible = vis;
		if (focusDurationSub != null) focusDurationSub.visible = vis;
		if (focusEaseLabel != null) focusEaseLabel.visible = vis;
		if (focusEaseInput != null) focusEaseInput.visible = vis;
		if (focusEaseDropDown != null) focusEaseDropDown.visible = vis;
	}

	function setZoomControlsVisible(vis:Bool):Void
	{
		if (zoomValLabel != null) zoomValLabel.visible = vis;
		if (zoomValueStepper != null) zoomValueStepper.visible = vis;
		if (btnZoomPresetStage != null) btnZoomPresetStage.visible = vis;
		if (btnZoomPresetClose != null) btnZoomPresetClose.visible = vis;
		if (btnZoomPresetWide != null) btnZoomPresetWide.visible = vis;
		if (zoomDurLabel != null) zoomDurLabel.visible = vis;
		if (zoomDurationStepper != null) zoomDurationStepper.visible = vis;
		if (zoomDurationSub != null) zoomDurationSub.visible = vis;
		if (zoomEaseLabel != null) zoomEaseLabel.visible = vis;
		if (zoomEaseInput != null) zoomEaseInput.visible = vis;
		if (zoomEaseDropDown != null) zoomEaseDropDown.visible = vis;
	}

	function setCharControlsVisible(vis:Bool):Void
	{
		if (charTargetLabel != null) charTargetLabel.visible = vis;
		if (charTargetDropDown != null) charTargetDropDown.visible = vis;
		if (charNameLabel != null) charNameLabel.visible = vis;
		if (charNameInput != null) charNameInput.visible = vis;
		if (charNameDropDown != null) charNameDropDown.visible = vis;
		if (charOffsetLabel != null) charOffsetLabel.visible = vis;
		if (charXStepper != null) charXStepper.visible = vis;
		if (charYStepper != null) charYStepper.visible = vis;
		if (btnResetCharOffset != null) btnResetCharOffset.visible = vis;
	}

	function setAnimControlsVisible(vis:Bool):Void
	{
		if (animTargetLabel != null) animTargetLabel.visible = vis;
		if (animTargetDropDown != null) animTargetDropDown.visible = vis;
		if (animNameLabel != null) animNameLabel.visible = vis;
		if (animNameInput != null) animNameInput.visible = vis;
		if (animNameDropDown != null) animNameDropDown.visible = vis;
		if (animLockCheckbox != null) animLockCheckbox.visible = vis;
		if (btnTestAnim != null) btnTestAnim.visible = vis;
	}

	function setStageControlsVisible(vis:Bool):Void
	{
		if (stageTargetLabel != null) stageTargetLabel.visible = vis;
		if (stageNameInput != null) stageNameInput.visible = vis;
		if (stageNameDropDown != null) stageNameDropDown.visible = vis;
		if (stageOptionsLabel != null) stageOptionsLabel.visible = vis;
		if (stageOptionsInput != null) stageOptionsInput.visible = vis;
		if (btnStageOptNoRepos != null) btnStageOptNoRepos.visible = vis;
		if (btnStageOptNoZoom != null) btnStageOptNoZoom.visible = vis;
		if (btnStageOptFlash != null) btnStageOptFlash.visible = vis;
		if (btnPreviewStage != null) btnPreviewStage.visible = vis;
	}

	function toggleStageOptionFlag(flag:String):Void
	{
		if (selectedEvent == null || selectedEvent.name != "Change Stage") return;
		var cleanFlag = flag.trim().toLowerCase();
		var existing = selectedEvent.stageOptions != null ? selectedEvent.stageOptions.split(",") : [];
		var kept:Array<String> = [];
		var removed = false;

		var aliases:Array<String> = switch (cleanFlag)
		{
			case "norepos": ["norepos", "no-repos", "stay", "dontreposition", "keep-pos", "keeppos"];
			case "nozoom": ["nozoom", "keepzoom", "no-zoom", "keep-zoom"];
			case "flash": ["flash", "flashwhite", "flash-white", "flashblack", "flash-black"];
			default: [cleanFlag];
		};

		for (tok in existing)
		{
			var t = tok.trim();
			if (t == "") continue;
			if (aliases.indexOf(t.toLowerCase()) != -1)
				removed = true;
			else
				kept.push(t);
		}
		if (!removed)
			kept.push(cleanFlag);

		selectedEvent.stageOptions = kept.join(", ");
		if (stageOptionsInput != null)
			stageOptionsInput.text = selectedEvent.stageOptions;
		saveEventsToSongInMemory();
		applyStageEvent(selectedEvent, false, false);
		updateInspectorUI();
		refreshEventBlocks();
	}

	function resolveStageTargetForEditor(raw:String, deterministic:Bool = false):String
	{
		var clean = raw != null ? raw.trim() : "";
		if (clean == "") return activeStageName != "" ? activeStageName : initialStageName;

		var lower = clean.toLowerCase();
		var pool = (stageList != null && stageList.length > 0) ? stageList : [initialStageName];

		if (lower == "initial" || lower == "default" || lower == "song")
			return initialStageName;

		if (lower == "next" || lower == "prev")
		{
			var curIdx = pool.indexOf(activeStageName);
			if (curIdx < 0) curIdx = 0;
			var nextIdx = (lower == "next") ? ((curIdx + 1) % pool.length) : ((curIdx - 1 + pool.length) % pool.length);
			return pool[nextIdx];
		}

		if (lower == "random" || lower == "rnd")
		{
			var candidates:Array<String> = [];
			for (s in pool)
				if (s != activeStageName) candidates.push(s);
			if (candidates.length == 0) return activeStageName;
			if (deterministic) return candidates[0];
			return candidates[Std.int(Math.floor(Math.random() * candidates.length))];
		}

		if (clean.indexOf("|") != -1 || clean.indexOf(";") != -1)
		{
			var sep = clean.indexOf("|") != -1 ? "|" : ";";
			var parts = clean.split(sep);
			var candidates:Array<String> = [];
			for (p in parts)
			{
				var t = p.trim();
				if (t != "" && t != activeStageName) candidates.push(t);
			}
			if (candidates.length == 0)
			{
				for (p in parts)
					if (p.trim() != "") candidates.push(p.trim());
			}
			if (candidates.length > 0)
				return candidates[0];
		}

		return clean;
	}

	function parseStageEventOptions(rawV2:String):{
		reposition:Bool,
		changeZoom:Bool,
		customZoom:Null<Float>,
		snap:Bool,
		flash:Bool,
		flashColor:FlxColor
	}
	{
		var res = {
			reposition: true,
			changeZoom: true,
			customZoom: (null : Null<Float>),
			snap: false,
			flash: false,
			flashColor: FlxColor.WHITE
		};
		if (rawV2 == null || rawV2.trim() == "") return res;

		for (part in rawV2.split(","))
		{
			var p = part.trim();
			var lower = p.toLowerCase();
			if (lower == "") continue;

			if (lower == "norepos" || lower == "no-repos" || lower == "stay" || lower == "dontreposition" || lower == "keep-pos" || lower == "keeppos")
				res.reposition = false;
			else if (lower == "nozoom" || lower == "keepzoom" || lower == "no-zoom" || lower == "keep-zoom")
				res.changeZoom = false;
			else if (lower == "snap" || lower == "instant")
				res.snap = true;
			else if (lower == "flash" || lower == "flashwhite" || lower == "flash-white")
			{
				res.flash = true;
				res.flashColor = FlxColor.WHITE;
			}
			else if (lower == "flashblack" || lower == "flash-black")
			{
				res.flash = true;
				res.flashColor = FlxColor.BLACK;
			}
			else if (StringTools.startsWith(lower, "zoom:") || StringTools.startsWith(lower, "zoom="))
			{
				var parsed = Std.parseFloat(p.substr(5).trim());
				if (!Math.isNaN(parsed) && parsed > 0)
				{
					res.customZoom = parsed;
					res.changeZoom = true;
				}
			}
			else
			{
				var num = Std.parseFloat(p);
				if (!Math.isNaN(num) && num > 0)
				{
					res.customZoom = num;
					res.changeZoom = true;
				}
			}
		}

		return res;
	}

	function getOrLoadEditorStage(stageName:String):Stage
	{
		if (stageName == null || stageName.trim() == "") return null;
		stageName = stageName.trim();

		if (stageCache != null && stageCache.exists(stageName))
			return stageCache.get(stageName);

		var newStage = new Stage(stageName);
		if (newStage.background != null)
		{
			newStage.background.cameras = [camEditor];
			newStage.background.visible = true;
			newStage.background.active = true;
		}
		if (newStage.foreground != null)
		{
			newStage.foreground.cameras = [camEditor];
			newStage.foreground.visible = true;
			newStage.foreground.active = true;
		}
		if (stageCache == null) stageCache = new Map();
		stageCache.set(stageName, newStage);
		return newStage;
	}

	function replaceStageInEditorMembers(oldStage:Stage, newStage:Stage):Void
	{
		if (newStage == null || oldStage == newStage) return;

		if (oldStage != null)
		{
			if (oldStage.background != null) remove(oldStage.background, true);
			if (oldStage.foreground != null) remove(oldStage.foreground, true);
		}

		if (newStage.background != null)
		{
			newStage.background.cameras = [camEditor];
			var anchorIdx = (gf != null) ? members.indexOf(gf) : -1;
			if (anchorIdx < 0 && dadOpponent != null) anchorIdx = members.indexOf(dadOpponent);
			if (anchorIdx < 0 && boyfriend != null) anchorIdx = members.indexOf(boyfriend);
			if (anchorIdx >= 0)
				insert(anchorIdx, newStage.background);
			else
				add(newStage.background);
		}

		if (newStage.foreground != null)
		{
			newStage.foreground.cameras = [camEditor];
			var bfIdx = (boyfriend != null) ? members.indexOf(boyfriend) : -1;
			if (bfIdx >= 0)
				insert(bfIdx + 1, newStage.foreground);
			else
				add(newStage.foreground);
		}
	}

	public function changeEditorStage(targetStage:String, repositionChars:Bool = true, ?customZoom:Null<Float> = null, allowChangeZoom:Bool = true):Void
	{
		if (targetStage == null || targetStage.trim() == "") return;
		targetStage = targetStage.trim();

		var prevStage = stageBuild;
		var wasFirstLoad = (stageCache == null || !stageCache.exists(targetStage));
		var switchingStage = (prevStage == null || activeStageName != targetStage);
		var newStage = switchingStage ? getOrLoadEditorStage(targetStage) : prevStage;
		if (newStage == null) return;

		if (switchingStage)
		{
			replaceStageInEditorMembers(prevStage, newStage);
			stageBuild = newStage;
			activeStageName = targetStage;

			#if sys
			if (newStage.interp != null)
			{
				newStage.interp.variables.set("boyfriend", boyfriend);
				newStage.interp.variables.set("dad", dadOpponent);
				newStage.interp.variables.set("dadOpponent", dadOpponent);
				newStage.interp.variables.set("gf", gf);
				newStage.interp.variables.set("camGame", camEditor);
				newStage.interp.variables.set("camHUD", camEditorHUD);
				newStage.interp.variables.set("camEditor", camEditor);
				newStage.interp.variables.set("camEditorHUD", camEditorHUD);
			}
			#end

			if (wasFirstLoad)
			{
				newStage.callScript("onCreatePost", []);
				newStage.callScript("createPost", []);
				newStage.callScript("postCreate", []);
			}
			newStage.callScript("onStageChange", [targetStage]);
		}

		if (customZoom != null && customZoom > 0)
		{
			defaultStageZoom = customZoom;
		}
		else if (allowChangeZoom)
		{
			defaultStageZoom = (newStage.stageData != null && newStage.stageData.zoom > 0)
				? newStage.stageData.zoom
				: initialStageZoom;
		}
		PlayState.defaultCamZoom = defaultStageZoom;

		if (repositionChars && newStage.stageData != null)
		{
			var sd = newStage.stageData;
			var bfX:Float = (sd.BF_POS != null && (sd.BF_POS[0] != 0 || sd.BF_POS[1] != 0)) ? sd.BF_POS[0] : 770;
			var bfY:Float = (sd.BF_POS != null && (sd.BF_POS[0] != 0 || sd.BF_POS[1] != 0)) ? sd.BF_POS[1] : 450;
			var dadX:Float = (sd.DAD_POS != null && (sd.DAD_POS[0] != 0 || sd.DAD_POS[1] != 0)) ? sd.DAD_POS[0] : 100;
			var dadY:Float = (sd.DAD_POS != null && (sd.DAD_POS[0] != 0 || sd.DAD_POS[1] != 0)) ? sd.DAD_POS[1] : 100;
			var gfX:Float = (sd.GF_POS != null && (sd.GF_POS[0] != 0 || sd.GF_POS[1] != 0)) ? sd.GF_POS[0] : 400;
			var gfY:Float = (sd.GF_POS != null && (sd.GF_POS[0] != 0 || sd.GF_POS[1] != 0)) ? sd.GF_POS[1] : 130;

			initialBfPos = [bfX, bfY];
			initialDadPos = [dadX, dadY];
			initialGfPos = [gfX, gfY];

			if (gf != null)
			{
				gf.visible = !sd.GF_HIDE;
				var gOffX = (gf.characterData != null) ? gf.characterData.offsetX : 0;
				var gOffY = (gf.characterData != null) ? gf.characterData.offsetY : 0;
				gf.setPosition(gfX + (activeGfCustomX != null ? activeGfCustomX : 0) + gOffX,
					gfY + (activeGfCustomY != null ? activeGfCustomY : 0) + gOffY);
				gf.updateHitbox();
			}
			if (dadOpponent != null)
			{
				var dOffX = (dadOpponent.characterData != null) ? dadOpponent.characterData.offsetX : 0;
				var dOffY = (dadOpponent.characterData != null) ? dadOpponent.characterData.offsetY : 0;
				dadOpponent.setPosition(dadX + (activeDadCustomX != null ? activeDadCustomX : 0) + dOffX,
					dadY + (activeDadCustomY != null ? activeDadCustomY : 0) + dOffY);
				dadOpponent.updateHitbox();
			}
			if (boyfriend != null)
			{
				var bOffX = (boyfriend.characterData != null) ? boyfriend.characterData.offsetX : 0;
				var bOffY = (boyfriend.characterData != null) ? boyfriend.characterData.offsetY : 0;
				boyfriend.setPosition(bfX + (activeBfCustomX != null ? activeBfCustomX : 0) + bOffX,
					bfY + (activeBfCustomY != null ? activeBfCustomY : 0) + bOffY);
				boyfriend.updateHitbox();
			}

			var camPos = new FlxPoint(
				(gf != null ? gf.getMidpoint().x : bfX) - 100,
				(boyfriend != null ? boyfriend.getMidpoint().y : bfY) - 100
			);
			newStage.repositionPlayers(targetStage, boyfriend, dadOpponent, gf);
			newStage.dadPosition(targetStage, boyfriend, dadOpponent, gf, camPos);
			camPos.put();
		}

		if (cameraRect != null)
		{
			cameraRect.currentStage = newStage;
			cameraRect.boyfriend = boyfriend;
			cameraRect.dad = dadOpponent;
			cameraRect.gf = gf;
			cameraRect.cacheIdleCameraPoints();
		}

		updateCamMarkers();
	}

	public function applyStageEvent(ev:CameraEditorEvent, allowFlash:Bool = false, snapCam:Bool = false):Void
	{
		if (ev == null) return;
		var targetStage = resolveStageTargetForEditor(ev.stageName);
		var opts = parseStageEventOptions(ev.stageOptions);

		changeEditorStage(targetStage, opts.reposition, opts.customZoom, opts.changeZoom);

		if (cameraRect != null && (opts.changeZoom || snapCam || opts.snap))
		{
			if (snapCam || opts.snap)
			{
				cameraRect.cancelAllTweens();
				if (opts.changeZoom) cameraRect.zoom = defaultStageZoom;
				var snapTarget:Int = 0;
				var snapX:Float = 0;
				var snapY:Float = 0;
				for (fe in events)
				{
					if (fe.time > Conductor.songPosition + 1.0) break;
					if (fe.name == "FocusCamera")
					{
						snapTarget = fe.target;
						snapX = fe.x;
						snapY = fe.y;
					}
				}
				cameraRect.focusOnTarget(snapTarget, snapX, snapY, "INSTANT", 0, true);
			}
			else if (allowFlash && opts.changeZoom)
			{
				cameraRect.zoom = defaultStageZoom;
			}
		}

		if (allowFlash && opts.flash && camEditor != null)
			camEditor.flash(opts.flashColor, 0.35, null, true);
	}

	function updateAnimDropDownChoices():Void
	{
		if (animNameDropDown == null) return;
		var targetIdx = (selectedEvent != null && selectedEvent.name == "Play Anim") ? selectedEvent.target : 1;
		var targetChar:Character = (targetIdx == 0) ? boyfriend : ((targetIdx == 2) ? gf : dadOpponent);

		var animList:Array<String> = [];
		if (targetChar != null && targetChar.animOffsets != null)
		{
			for (k in targetChar.animOffsets.keys())
			{
				if (k != null && k.trim() != "" && !animList.contains(k))
					animList.push(k);
			}
		}
		if (animList.length == 0)
			animList = ["idle", "singLEFT", "singDOWN", "singUP", "singRIGHT"];
		else
			animList.sort((a, b) -> Reflect.compare(a.toLowerCase(), b.toLowerCase()));

		animNameDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(animList, true));
		if (selectedEvent != null && selectedEvent.name == "Play Anim" && selectedEvent.animName != "")
			animNameDropDown.selectedLabel = selectedEvent.animName;
	}

	public function changeEditorCharacter(target:Int, newChar:String, ?customX:Null<Float>, ?customY:Null<Float>):Void
	{
		if (newChar == null || newChar.trim() == "") return;
		newChar = newChar.trim();

		switch (target)
		{
			case 0: // Boyfriend
				if (boyfriend == null) return;
				boyfriend.adjustPos = false;
				var baseX:Float = initialBfPos[0] + (customX != null ? customX : 0);
				var baseY:Float = initialBfPos[1] + (customY != null ? customY : 0);

				if (boyfriend.curCharacter != newChar)
				{
					boyfriend.setCharacter(baseX, baseY, newChar);
					boyfriend.adjustPos = false;
					curBfChar = boyfriend.curCharacter;
				}
				else
				{
					boyfriend.x = baseX + (boyfriend.characterData != null ? boyfriend.characterData.offsetX : 0);
					boyfriend.y = baseY + (boyfriend.characterData != null ? boyfriend.characterData.offsetY : 0);
					boyfriend.updateHitbox();
				}

			case 2: // Girlfriend
				if (gf == null) return;
				gf.adjustPos = false;
				var baseX:Float = initialGfPos[0] + (customX != null ? customX : 0);
				var baseY:Float = initialGfPos[1] + (customY != null ? customY : 0);

				if (gf.curCharacter != newChar)
				{
					gf.setCharacter(baseX, baseY, newChar);
					gf.adjustPos = false;
					curGfChar = gf.curCharacter;
				}
				else
				{
					gf.x = baseX + (gf.characterData != null ? gf.characterData.offsetX : 0);
					gf.y = baseY + (gf.characterData != null ? gf.characterData.offsetY : 0);
					gf.updateHitbox();
				}

			default: // Opponent / Dad (1)
				if (dadOpponent == null) return;
				dadOpponent.adjustPos = false;
				var baseX:Float = initialDadPos[0] + (customX != null ? customX : 0);
				var baseY:Float = initialDadPos[1] + (customY != null ? customY : 0);

				if (dadOpponent.curCharacter != newChar)
				{
					dadOpponent.setCharacter(baseX, baseY, newChar);
					dadOpponent.adjustPos = false;
					curDadChar = dadOpponent.curCharacter;
				}
				else
				{
					dadOpponent.x = baseX + (dadOpponent.characterData != null ? dadOpponent.characterData.offsetX : 0);
					dadOpponent.y = baseY + (dadOpponent.characterData != null ? dadOpponent.characterData.offsetY : 0);
					dadOpponent.updateHitbox();
				}
		}

		if (stageBuild != null)
		{
			var curStage = (activeStageName != null && activeStageName != "") ? activeStageName : _song.stage;
			stageBuild.repositionPlayers(curStage, boyfriend, dadOpponent, gf);
		}

		if (cameraRect != null)
		{
			cameraRect.boyfriend = boyfriend;
			cameraRect.dad = dadOpponent;
			cameraRect.gf = gf;
			cameraRect.cacheIdleCameraPoints();
		}
		updateCamMarkers();
		updateAnimDropDownChoices();
	}

	public function playEditorAnimation(target:Int, animName:String, force:Bool = true):Void
	{
		if (animName == null || animName.trim() == "") return;
		animName = animName.trim();

		var char:Character = (target == 0) ? boyfriend : ((target == 2) ? gf : dadOpponent);
		if (char != null)
		{
			char.playAnim(animName, force);
			char.holdTimer = 0;
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

		// Rewind Button
		btnRewind = bindUI(new FlxButton(36, TIMELINE_Y + 3, "", function() {
			setTimePosition(0);
			showToast("Rewound to 0:00");
		}));
		btnRewind.loadGraphic(Paths.image('menus/editors/camera/triangle'));
		btnRewind.angle = 180;
		btnRewind.setGraphicSize(20, 20);
		btnRewind.updateHitbox();
		timelineGroup.add(btnRewind);

		// Magnet Snap Toggle
		btnSnap = bindUI(new FlxButton(68, TIMELINE_Y + 3, "", toggleSnap));
		btnSnap.loadGraphic(Paths.image('menus/editors/camera/magnet_snap_on'));
		btnSnap.setGraphicSize(24, 24);
		btnSnap.updateHitbox();
		timelineGroup.add(btnSnap);

		// Timeline Zoom Buttons & Label
		btnZoomOut = bindUI(new FlxButton(104, TIMELINE_Y + 4, "-", function() {
			var centerX = TIMELINE_LEFT_X + (FlxG.width - TIMELINE_LEFT_X) / 2.0;
			var oldEffective = timelinePixelsPerMs * timelineZoomScale;
			var centerMs = timelineScrollMs + (centerX - TIMELINE_LEFT_X) / oldEffective;

			timelineZoomScale = Math.max(0.25, timelineZoomScale - 0.25);
			var newEffective = timelinePixelsPerMs * timelineZoomScale;
			timelineScrollMs = Math.max(0, centerMs - (centerX - TIMELINE_LEFT_X) / newEffective);

			saveEditorPreferences();
			updateModeButtonVisuals();
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
			var currentPx = TIMELINE_LEFT_X + (Conductor.songPosition - timelineScrollMs) * newEffective;
			if (playheadLine != null) playheadLine.x = currentPx;
			if (playheadTopper != null) playheadTopper.x = currentPx - 5;
		}));
		resizeButton(btnZoomOut, 22, 22);
		timelineGroup.add(btnZoomOut);

		timelineZoomText = bindUI(new FlxText(128, TIMELINE_Y + 7, 40, "100%", 10));
		timelineZoomText.setFormat(Paths.font("vcr.ttf"), 10, FlxColor.WHITE, CENTER);
		timelineGroup.add(timelineZoomText);

		btnZoomIn = bindUI(new FlxButton(170, TIMELINE_Y + 4, "+", function() {
			var centerX = TIMELINE_LEFT_X + (FlxG.width - TIMELINE_LEFT_X) / 2.0;
			var oldEffective = timelinePixelsPerMs * timelineZoomScale;
			var centerMs = timelineScrollMs + (centerX - TIMELINE_LEFT_X) / oldEffective;

			timelineZoomScale = Math.min(4.0, timelineZoomScale + 0.25);
			var newEffective = timelinePixelsPerMs * timelineZoomScale;
			timelineScrollMs = Math.max(0, centerMs - (centerX - TIMELINE_LEFT_X) / newEffective);

			saveEditorPreferences();
			updateModeButtonVisuals();
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
			var currentPx = TIMELINE_LEFT_X + (Conductor.songPosition - timelineScrollMs) * newEffective;
			if (playheadLine != null) playheadLine.x = currentPx;
			if (playheadTopper != null) playheadTopper.x = currentPx - 5;
		}));
		resizeButton(btnZoomIn, 22, 22);
		timelineGroup.add(btnZoomIn);

		// Add Layer / Delete Layer
		btnAddLayer = bindUI(new FlxButton(205, TIMELINE_Y + 3, "", function() {
			layers.push('Layer ${layers.length}');
			refreshTimelineLanes();
			refreshEventBlocks();
		}));
		btnAddLayer.loadGraphic(Paths.image('menus/editors/camera/add_layer'));
		btnAddLayer.setGraphicSize(24, 24);
		btnAddLayer.updateHitbox();
		timelineGroup.add(btnAddLayer);

		btnDeleteLayer = bindUI(new FlxButton(235, TIMELINE_Y + 3, "", function() {
			if (layers.length > 5)
			{
				layers.pop();
				refreshTimelineLanes();
				refreshEventBlocks();
			}
		}));
		btnDeleteLayer.loadGraphic(Paths.image('menus/editors/camera/delete_layer'));
		btnDeleteLayer.setGraphicSize(24, 24);
		btnDeleteLayer.updateHitbox();
		timelineGroup.add(btnDeleteLayer);

		// 2. Timeline Ruler Header (y: 535 to 561) - 1x1 scaled sprite
		timelineRulerBG = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFF1C1C28));
		timelineRulerBG.scale.set(FlxG.width - TIMELINE_LEFT_X, TIMELINE_RULER_HEIGHT);
		timelineRulerBG.updateHitbox();
		timelineGroup.add(timelineRulerBG);

		// Track Left Headers Panel (renders in leftHeadersGroup over blocks)
		var leftHeaderBG = bindUI(new FlxSprite(0, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFF12121A));
		leftHeaderBG.scale.set(TIMELINE_LEFT_X, TIMELINE_HEIGHT - 30);
		leftHeaderBG.updateHitbox();
		leftHeadersGroup.add(leftHeaderBG);

		var headerBorder = bindUI(new FlxSprite(TIMELINE_LEFT_X - 1, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFF2A2A3A));
		headerBorder.scale.set(1, TIMELINE_HEIGHT - 30);
		headerBorder.updateHitbox();
		leftHeadersGroup.add(headerBorder);

		// 3. Timeline Lanes BG
		timelineLanesBG = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT).makeGraphic(1, 1, 0xFF0E0E16));
		timelineLanesBG.scale.set(FlxG.width - TIMELINE_LEFT_X, TIMELINE_HEIGHT - 30 - TIMELINE_RULER_HEIGHT);
		timelineLanesBG.updateHitbox();
		timelineGroup.add(timelineLanesBG);

		// Playhead Line & Topper (renders in playheadGroup on top of everything)
		playheadLine = bindUI(new FlxSprite(TIMELINE_LEFT_X, TIMELINE_Y + 30).makeGraphic(1, 1, 0xFFFF3333));
		playheadLine.scale.set(2, TIMELINE_HEIGHT - 30);
		playheadLine.updateHitbox();
		playheadGroup.add(playheadLine);

		// Compact DAW playhead marker (downward-pointing indicator inside ruler)
		var topperW = 13;
		var topperH = 14;
		var shape = new Shape();
		shape.graphics.beginFill(0xFFFF3333);
		shape.graphics.moveTo(0, 0);
		shape.graphics.lineTo(12, 0);
		shape.graphics.lineTo(12, 7);
		shape.graphics.lineTo(6, 13);
		shape.graphics.lineTo(0, 7);
		shape.graphics.lineTo(0, 0);
		shape.graphics.endFill();

		shape.graphics.lineStyle(1, 0xFFFFFFFF, 0.7);
		shape.graphics.moveTo(0, 0);
		shape.graphics.lineTo(12, 0);
		shape.graphics.lineTo(12, 7);
		shape.graphics.lineTo(6, 13);
		shape.graphics.lineTo(0, 7);
		shape.graphics.lineTo(0, 0);

		var topperBmp = new BitmapData(topperW, topperH, true, 0x00000000);
		topperBmp.draw(shape);

		playheadTopper = bindUI(new FlxSprite(TIMELINE_LEFT_X - 5, TIMELINE_Y + 30));
		playheadTopper.loadGraphic(topperBmp);
		playheadGroup.add(playheadTopper);

		refreshTimelineLanes();
	}

	inline function getLaneHeight():Float
	{
		var availH:Float = TIMELINE_HEIGHT - 30 - TIMELINE_RULER_HEIGHT;
		var count:Int = (layers != null && layers.length > 0) ? layers.length : 5;
		return Math.min(LANE_HEIGHT, Math.floor(availH / count));
	}

	function refreshTimelineLanes():Void
	{
		if (rulerTextGroup == null || leftHeadersGroup == null) return;

		var curLaneH:Float = getLaneHeight();

		// 1. Layer Labels on Left & Horizontal Lane Dividers (Pool & Reuse to prevent GC stutter)
		for (i in 0...layers.length)
		{
			var laneY = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (i * curLaneH);
			var layerLabel:FlxText;
			if (i < layerLabelPool.length)
			{
				layerLabel = layerLabelPool[i];
			}
			else
			{
				layerLabel = bindUI(new FlxText(8, laneY + 7, TIMELINE_LEFT_X - 16, "", 11));
				leftHeadersGroup.add(layerLabel);
				layerLabelPool.push(layerLabel);
			}
			layerLabel.visible = true;
			layerLabel.y = laneY + Math.max(2, Math.floor((curLaneH - 15) * 0.5));
			layerLabel.text = layers[i];
			layerLabel.setFormat(Paths.font("vcr.ttf"), 11, layerColors[i % layerColors.length], LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

			if (gridLinesGroup != null)
			{
				var hLine:FlxSprite;
				if (i < horizGridLinePool.length)
				{
					hLine = horizGridLinePool[i];
				}
				else
				{
					hLine = bindUI(new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF));
					gridLinesGroup.add(hLine);
					horizGridLinePool.push(hLine);
				}
				hLine.visible = true;
				hLine.x = TIMELINE_LEFT_X;
				hLine.y = laneY + curLaneH - 1;
				hLine.scale.set(FlxG.width - TIMELINE_LEFT_X, 1);
				hLine.updateHitbox();
				hLine.color = 0xFF1F1F2E;
			}
		}
		for (i in layers.length...layerLabelPool.length)
		{
			layerLabelPool[i].visible = false;
		}
		for (i in layers.length...horizGridLinePool.length)
		{
			horizGridLinePool[i].visible = false;
		}

		// 2. Real Step Marks across the ruler
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var visibleWidth = FlxG.width - TIMELINE_LEFT_X;
		var startMs = timelineScrollMs;
		var endMs = timelineScrollMs + (visibleWidth / effectivePixelsPerMs);

		var startStep = Math.max(0, Math.floor(Conductor.calculateDecStep(startMs)));
		var endStep = Math.ceil(Conductor.calculateDecStep(endMs)) + 4;

		// Estimate average pixels per 16 steps to decide label & grid line density
		var curStepCrochet = getStepCrochetAtTime(timelineScrollMs);
		var pixelsPer16Steps = (curStepCrochet * 16.0) * effectivePixelsPerMs;
		var pixelsPerBeat = (curStepCrochet * 4.0) * effectivePixelsPerMs;
		var pixelsPerStep = curStepCrochet * effectivePixelsPerMs;

		var showSteps:Bool = (pixelsPerStep >= 18.0);
		var showBeats:Bool = (pixelsPerBeat >= 14.0);

		var stepSkip:Int = 16;
		if (pixelsPer16Steps < 40.0) stepSkip = 64;
		else if (pixelsPer16Steps < 75.0) stepSkip = 32;

		var loopInterval:Int = showSteps ? 1 : (showBeats ? 4 : stepSkip);
		var firstAlignedStep = Math.floor(startStep / loopInterval) * loopInterval;
		if (firstAlignedStep < 0) firstAlignedStep = 0;

		var poolIdx = 0;
		var linePoolIdx = 0;

		var s = firstAlignedStep;
		while (s <= endStep)
		{
			var sTime = getTimeFromStep(s);
			var rx = TIMELINE_LEFT_X + (sTime - timelineScrollMs) * effectivePixelsPerMs;

			if (rx >= TIMELINE_LEFT_X - 15 && rx <= FlxG.width + 15)
			{
				var isMajor = (s % stepSkip == 0);
				var isBeat = (s % 4 == 0);
				var shouldShowText = isMajor || (showBeats && isBeat && pixelsPerBeat >= 28.0) || (showSteps && pixelsPerStep >= 32.0);

				if (shouldShowText && rx >= TIMELINE_LEFT_X && rx <= FlxG.width - 20)
				{
					var mText:FlxText;
					if (poolIdx < measureTextPool.length)
					{
						mText = measureTextPool[poolIdx];
					}
					else
					{
						mText = bindUI(new FlxText(0, TIMELINE_Y + 34, 50, "", 10));
						rulerTextGroup.add(mText);
						measureTextPool.push(mText);
					}

					mText.visible = true;
					mText.x = rx + 3;
					mText.y = isMajor ? (TIMELINE_Y + 34) : (TIMELINE_Y + 35);
					mText.text = Std.string(s);

					if (isMajor)
					{
						mText.setFormat(Paths.font("vcr.ttf"), 10, 0xFFFFFFFF, LEFT);
					}
					else if (isBeat)
					{
						mText.setFormat(Paths.font("vcr.ttf"), 9, 0xFF9999AA, LEFT);
					}
					else
					{
						mText.setFormat(Paths.font("vcr.ttf"), 8, 0xFF666677, LEFT);
					}
					poolIdx++;
				}

				// Vertical grid line down the timeline lanes (Major, Beat, and Step)
				if (gridLinesGroup != null && rx >= TIMELINE_LEFT_X && rx <= FlxG.width)
				{
					var isGridLine = isMajor || (showBeats && isBeat) || showSteps;
					if (isGridLine)
					{
						var line:FlxSprite;
						if (linePoolIdx < gridLinePool.length)
						{
							line = gridLinePool[linePoolIdx];
						}
						else
						{
							line = bindUI(new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF));
							gridLinesGroup.add(line);
							gridLinePool.push(line);
						}

						line.visible = true;
						line.x = rx;
						line.y = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT;
						line.scale.set(1, TIMELINE_HEIGHT - 30 - TIMELINE_RULER_HEIGHT);
						line.updateHitbox();
						line.color = isMajor ? 0xFF5A5A78 : (isBeat ? 0xFF2E2E42 : 0xFF1F1F2E);
						linePoolIdx++;
					}
				}
			}

			s += loopInterval;
		}

		for (i in poolIdx...measureTextPool.length)
		{
			measureTextPool[i].visible = false;
		}

		for (i in linePoolIdx...gridLinePool.length)
		{
			gridLinePool[i].visible = false;
		}
	}

	public function getEventBlockWidth(ev:CameraEditorEvent, effectivePixelsPerMs:Float, maxDistMs:Float = -1):Float
	{
		if (ev == null) return 24.0;

		var isInstant = (ev.duration <= 0.1 || ev.ease == "INSTANT");
		var naturalW:Float;

		if (isInstant)
		{
			naturalW = 24.0;
		}
		else
		{
			var durMs = getTimeFromStep(Conductor.calculateDecStep(ev.time) + ev.duration) - ev.time;
			if (durMs <= 0) durMs = 0;
			naturalW = Math.max(24.0, durMs * effectivePixelsPerMs);
		}

		if (maxDistMs > 0)
		{
			var distPx = maxDistMs * effectivePixelsPerMs;
			// Guarantee a visible separation gap between adjacent events on the same lane
			var gap = (distPx >= 20.0) ? 4.0 : ((distPx >= 8.0) ? 3.0 : 2.0);
			var maxAllowedW = Math.max(2.0, distPx - gap);
			if (naturalW > maxAllowedW)
				naturalW = maxAllowedW;
		}

		return Math.max(2.0, naturalW);
	}

	function computeTimelineBlockLayout():Void
	{
		computedBlockBounds = [];
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var curLaneH:Float = getLaneHeight();
		var numLayers:Int = (layers != null && layers.length > 0) ? layers.length : 5;

		// Build per-lane entries with raw X & W
		var perLane:Array<Array<{ev:CameraEditorEvent, bx:Float, bw:Float, slotIdx:Int, slotCount:Int}>> = [];
		for (_ in 0...numLayers)
			perLane.push([]);

		for (i in 0...events.length)
		{
			var ev = events[i];
			var laneIdx = ev.layer % numLayers;

			var nextDistMs:Float = -1;
			for (j in (i + 1)...events.length)
			{
				var nextEv = events[j];
				if ((nextEv.layer % numLayers) == laneIdx && nextEv.time > ev.time + 0.5)
				{
					nextDistMs = nextEv.time - ev.time;
					break;
				}
			}

			var bx = TIMELINE_LEFT_X + (ev.time - timelineScrollMs) * effectivePixelsPerMs;
			var bw = getEventBlockWidth(ev, effectivePixelsPerMs, nextDistMs);
			perLane[laneIdx].push({ev: ev, bx: bx, bw: bw, slotIdx: 0, slotCount: 1});
		}

		// Assign non-overlapping vertical sub-slots per overlapping cluster on each lane
		for (laneIdx in 0...numLayers)
		{
			var list = perLane[laneIdx];
			if (list.length == 0) continue;

			var clusterStart = 0;
			while (clusterStart < list.length)
			{
				var clusterEndX:Float = list[clusterStart].bx + list[clusterStart].bw;
				var clusterEnd = clusterStart + 1;
				while (clusterEnd < list.length)
				{
					var cand = list[clusterEnd];
					var sameTime = Math.abs(cand.ev.time - list[clusterEnd - 1].ev.time) <= 2.0;
					if (sameTime || cand.bx < clusterEndX - 0.5)
					{
						var candEndX = cand.bx + cand.bw;
						if (candEndX > clusterEndX) clusterEndX = candEndX;
						clusterEnd++;
					}
					else
					{
						break;
					}
				}

				// Greedy interval slot assignment inside [clusterStart, clusterEnd)
				var slotRightEdges:Array<Float> = [];
				for (k in clusterStart...clusterEnd)
				{
					var item = list[k];
					var assignedSlot:Int = -1;
					for (s in 0...slotRightEdges.length)
					{
						if (slotRightEdges[s] <= item.bx - 0.5 && (k == clusterStart || Math.abs(item.ev.time - list[k - 1].ev.time) > 2.0))
						{
							assignedSlot = s;
							slotRightEdges[s] = item.bx + item.bw;
							break;
						}
					}
					if (assignedSlot == -1)
					{
						assignedSlot = slotRightEdges.length;
						slotRightEdges.push(item.bx + item.bw);
					}
					item.slotIdx = assignedSlot;
				}

				var totalSlots = Std.int(Math.max(1, slotRightEdges.length));
				var laneTop = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (laneIdx * curLaneH);
				for (k in clusterStart...clusterEnd)
				{
					var item = list[k];
					item.slotCount = totalSlots;

					var by:Float;
					var bh:Float;
					if (totalSlots <= 1)
					{
						by = laneTop + 4;
						bh = Math.max(10.0, curLaneH - 8);
					}
					else
					{
						var usableH = Math.max(12.0, curLaneH - 4);
						var subH = Math.max(7.0, usableH / totalSlots);
						by = laneTop + 2 + (item.slotIdx * subH);
						bh = Math.max(6.0, subH - 1);
						if (by + bh > laneTop + curLaneH - 1)
							bh = Math.max(5.0, (laneTop + curLaneH - 1) - by);
					}

					computedBlockBounds.push({
						ev: item.ev,
						x: item.bx,
						y: by,
						w: item.bw,
						h: bh,
						slotIdx: item.slotIdx,
						slotCount: totalSlots
					});
				}

				clusterStart = clusterEnd;
			}
		}
	}

	function refreshEventBlocks():Void
	{
		if (timelineBlocksGroup == null) return;

		computeTimelineBlockLayout();
		var poolIdx = 0;

		for (b in computedBlockBounds)
		{
			var blockX = b.x;
			var blockY = b.y;
			var blockWidth = b.w;
			var blockHeight = b.h;

			// Skip if completely outside horizontal viewport
			if (blockX + blockWidth < TIMELINE_LEFT_X || blockX > FlxG.width + 50)
				continue;

			// Horizontal clipping to prevent bleeding into track headers or past screen
			var drawX = blockX;
			var drawW = blockWidth;
			if (drawX < TIMELINE_LEFT_X)
			{
				drawW -= (TIMELINE_LEFT_X - drawX);
				drawX = TIMELINE_LEFT_X;
			}
			if (drawX + drawW > FlxG.width)
			{
				drawW = FlxG.width - drawX;
			}
			if (drawW <= 1)
				continue;

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

			var gColor = (b.ev.groupName != null && b.ev.groupName.trim() != "") ? getGroupColor(b.ev.groupName) : FlxColor.TRANSPARENT;
			item.setup(b.ev, (selectedEvent == b.ev), drawX, blockY, drawW, blockHeight, gColor, b.slotCount > 1);
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
			lastSection = getSectionAtStep(curStep);

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
			if (opponentVocals != null)
			{
				opponentVocals.time = Conductor.songPosition;
				opponentVocals.play();
			}
			btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/pause'));
		}
		else
		{
			if (songMusic != null) songMusic.pause();
			if (vocals != null) vocals.pause();
			if (opponentVocals != null) opponentVocals.pause();
			btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/play'));
			replayCameraTimeline(Conductor.songPosition);
		}
		btnPlayPause.setGraphicSize(24, 24);
		btnPlayPause.updateHitbox();
	}

	public function setTimePosition(positionMs:Float, isScrubbing:Bool = false):Void
	{
		var clampedMs = Math.max(0, positionMs);
		Conductor.songPosition = clampedMs;

		if (songMusic != null)
			songMusic.time = clampedMs;
		if (vocals != null)
			vocals.time = clampedMs;
		if (opponentVocals != null)
			opponentVocals.time = clampedMs;

		var bpmEvent = Conductor.getBPMChangeEvent(clampedMs);
		if (bpmEvent != null && bpmEvent.bpm > 0 && bpmEvent.bpm != Conductor.bpm)
		{
			Conductor.changeBPM(bpmEvent.bpm);
		}

		curDecStep = Conductor.calculateDecStep(clampedMs);
		curStep = Math.floor(curDecStep);
		curDecBeat = curDecStep / 4.0;
		curBeat = Math.floor(curDecBeat);

		cachedNoteIndex = 0;
		cachedEventIndex = 0;
		lastSection = -1;
		lastDisplayedSongPos = clampedMs;

		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var playheadX = TIMELINE_LEFT_X + (clampedMs - timelineScrollMs) * effectivePixelsPerMs;

		if (!isScrubbing)
		{
			// Center timeline scroll around current time if playhead goes offscreen (keyboard / programmatic jumps)
			if (playheadX > FlxG.width - 50 || playheadX < TIMELINE_LEFT_X)
			{
				timelineScrollMs = Math.max(0, clampedMs - (200 / effectivePixelsPerMs));
				refreshTimelineLanes();
				playheadX = TIMELINE_LEFT_X + (clampedMs - timelineScrollMs) * effectivePixelsPerMs;
			}
		}

		// Update playhead visual positions immediately (eliminates 1-frame drag lag)
		if (playheadLine != null)
			playheadLine.x = playheadX;
		if (playheadTopper != null)
			playheadTopper.x = playheadX - 5;

		// Format time readout text immediately
		if (timeText != null)
		{
			var totalSec = Math.floor(clampedMs / 1000);
			var mins = Math.floor(totalSec / 60);
			var secs = totalSec % 60;
			var ms = Math.floor(clampedMs % 1000 / 10);
			var strMins = (mins < 10 ? "0" : "") + mins;
			var strSecs = (secs < 10 ? "0" : "") + secs;
			var strMs = (ms < 10 ? "0" : "") + ms;
			timeText.text = '$strMins:$strSecs.$strMs | Step $curStep | Beat $curBeat';
		}

		replayCameraTimeline(clampedMs);

		if (!isScrubbing)
		{
			refreshEventBlocks();
		}
	}

	public function replayCameraTimeline(positionMs:Float):Void
	{
		if (cameraRect == null) return;

		cameraRect.cancelAllTweens();

		// 0A. Stage State Replay up to positionMs
		var targetStage = initialStageName;
		var targetStageZoom = initialStageZoom;
		var targetStageRepos = true;
		var lastStageCustomZoom:Null<Float> = null;
		var lastStageAllowZoom = true;

		for (ev in events)
		{
			if (ev.time > positionMs + 1.0) break;
			if (ev.name == "Change Stage")
			{
				var resolved = resolveStageTargetForEditor(ev.stageName, true);
				if (resolved != "")
					targetStage = resolved;
				var opts = parseStageEventOptions(ev.stageOptions);
				targetStageRepos = opts.reposition;
				lastStageAllowZoom = opts.changeZoom;
				if (opts.customZoom != null && opts.customZoom > 0)
					targetStageZoom = opts.customZoom;
				else if (opts.changeZoom)
				{
					var stg = getOrLoadEditorStage(targetStage);
					targetStageZoom = (stg != null && stg.stageData != null && stg.stageData.zoom > 0) ? stg.stageData.zoom : initialStageZoom;
				}
				lastStageCustomZoom = targetStageZoom;
			}
		}

		if (targetStage != activeStageName)
		{
			changeEditorStage(targetStage, targetStageRepos, targetStageZoom, true);
			if (targetStageRepos)
			{
				activeBfChar = "";
				activeDadChar = "";
				activeGfChar = "";
			}
		}
		else
		{
			var desiredZoom = (lastStageCustomZoom != null) ? lastStageCustomZoom : initialStageZoom;
			if (Math.abs(defaultStageZoom - desiredZoom) > 0.0001)
			{
				defaultStageZoom = desiredZoom;
				PlayState.defaultCamZoom = defaultStageZoom;
			}
		}

		// 0B. Character State Replay up to positionMs
		var targetBfChar = initialBf;
		var targetBfX:Null<Float> = null;
		var targetBfY:Null<Float> = null;

		var targetDadChar = initialDad;
		var targetDadX:Null<Float> = null;
		var targetDadY:Null<Float> = null;

		var targetGfChar = initialGf;
		var targetGfX:Null<Float> = null;
		var targetGfY:Null<Float> = null;

		for (ev in events)
		{
			if (ev.time > positionMs + 1.0) break;
			if (ev.name == "Change Character")
			{
				if (ev.target == 0)
				{
					targetBfChar = ev.charName;
					targetBfX = (ev.x != 0 || ev.y != 0) ? ev.x : null;
					targetBfY = (ev.x != 0 || ev.y != 0) ? ev.y : null;
				}
				else if (ev.target == 2)
				{
					targetGfChar = ev.charName;
					targetGfX = (ev.x != 0 || ev.y != 0) ? ev.x : null;
					targetGfY = (ev.x != 0 || ev.y != 0) ? ev.y : null;
				}
				else
				{
					targetDadChar = ev.charName;
					targetDadX = (ev.x != 0 || ev.y != 0) ? ev.x : null;
					targetDadY = (ev.x != 0 || ev.y != 0) ? ev.y : null;
				}
			}
		}

		if (boyfriend != null && (activeBfChar != targetBfChar || activeBfCustomX != targetBfX || activeBfCustomY != targetBfY))
		{
			activeBfChar = targetBfChar;
			activeBfCustomX = targetBfX;
			activeBfCustomY = targetBfY;
			changeEditorCharacter(0, targetBfChar, targetBfX, targetBfY);
		}

		if (dadOpponent != null && (activeDadChar != targetDadChar || activeDadCustomX != targetDadX || activeDadCustomY != targetDadY))
		{
			activeDadChar = targetDadChar;
			activeDadCustomX = targetDadX;
			activeDadCustomY = targetDadY;
			changeEditorCharacter(1, targetDadChar, targetDadX, targetDadY);
		}

		if (gf != null && (activeGfChar != targetGfChar || activeGfCustomX != targetGfX || activeGfCustomY != targetGfY))
		{
			activeGfChar = targetGfChar;
			activeGfCustomX = targetGfX;
			activeGfCustomY = targetGfY;
			changeEditorCharacter(2, targetGfChar, targetGfX, targetGfY);
		}

		if (!isPlaying)
		{
			for (ev in events)
			{
				if (ev.time > positionMs + 2.0) break;
				if (ev.name == "Play Anim" && Math.abs(ev.time - positionMs) <= 2.0)
				{
					var char:Character = (ev.target == 0) ? boyfriend : ((ev.target == 2) ? gf : dadOpponent);
					if (char != null)
						char.animLocked = ev.animLock;
					playEditorAnimation(ev.target, ev.animName, true);
				}
			}
		}

		// Single pass backwards scan: ZERO array allocations, ZERO sort overhead (maximum FPS)
		var latestZoom:CameraEditorEvent = null;
		var prevZoom:CameraEditorEvent = null;
		var latestFocus:CameraEditorEvent = null;
		var prevFocus:CameraEditorEvent = null;

		for (ev in events)
		{
			if (ev.time > positionMs + 1.0) break;
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

			var durMs = getTimeFromStep(Conductor.calculateDecStep(latestZoom.time) + latestZoom.duration) - latestZoom.time;
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
			var durMs = getTimeFromStep(Conductor.calculateDecStep(latestFocus.time) + latestFocus.duration) - latestFocus.time;

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
				var curSec = getSectionAtStep(Conductor.calculateDecStep(positionMs));
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

		// 4. Play Animation Replay on scrub (if event was triggered within the last 500ms)
		for (ev in events)
		{
			if (ev.time > positionMs) break;
			if (ev.name == "Play Anim" && positionMs >= ev.time && positionMs - ev.time < 500)
			{
				playEditorAnimation(ev.target, ev.animName, false);
			}
		}
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
				var curStepC = getStepCrochetAtTime(positionMs);
				var holdLen = Math.max(curStepC * boyfriend.singDuration, latestBfNote.length);
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
				var curStepC = getStepCrochetAtTime(positionMs);
				var holdLen = Math.max(curStepC * dadOpponent.singDuration, latestDadNote.length);
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

		var newEvents:Array<CameraEditorEvent> = [];
		var currentStep:Float = 0;
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
				var eventTimeMs = getTimeFromStep(currentStep);
				var ev = new CameraEditorEvent(eventTimeMs, "FocusCamera", 1);
				ev.target = targetChar;
				ev.duration = 4.0; // 1 beat ease duration
				ev.ease = "CLASSIC";
				newEvents.push(ev);
				lastTargetChar = targetChar;
			}

			var sectionSteps = (section.lengthInSteps > 0) ? section.lengthInSteps : 16;
			currentStep += sectionSteps;
		}

		// Merge or replace focus events
		events = events.filter(function(e) return e.name != "FocusCamera");
		for (e in newEvents)
			events.push(e);

		sortEvents();
		if (timelineBlocksGroup != null)
			refreshEventBlocks();
		replayCameraTimeline(Conductor.songPosition);
		updateInspectorUI();
		if (playSound)
			FlxG.sound.play(Paths.sound('confirm'));
		showToast('Generated ${newEvents.length} camera focus events!');
	}

	/* =================================================================================
	 * SAVE / EXPORT
	 * ================================================================================= */
	private function prepareSongForSave():Void
	{
		_song.format = "gaze";

		// Clean and sort notes in each section
		if (_song.notes != null)
		{
			for (sec in _song.notes)
			{
				if (sec == null) continue;
				if (sec.sectionNotes == null) sec.sectionNotes = [];

				var cleanedNotes:Array<Dynamic> = [];
				for (n in sec.sectionNotes)
				{
					if (n == null || !Std.isOfType(n, Array) || cast(n, Array<Dynamic>).length < 2) continue;
					var noteArr:Array<Dynamic> = cast n;
					var strum:Float = Math.round(Std.parseFloat(Std.string(noteArr[0])) * 1000) / 1000;
					var data:Int = Std.parseInt(Std.string(noteArr[1]));
					var sus:Float = (noteArr.length > 2 && noteArr[2] != null) ? Math.max(0, Math.round(Std.parseFloat(Std.string(noteArr[2])) * 1000) / 1000) : 0;
					var type:Dynamic = (noteArr.length > 3 && noteArr[3] != null) ? noteArr[3] : null;

					if (type == 'default' || type == '0' || type == 0 || type == '')
						cleanedNotes.push([strum, data, sus]);
					else if (type != null)
						cleanedNotes.push([strum, data, sus, type]);
					else
						cleanedNotes.push([strum, data, sus]);
				}

				cleanedNotes.sort(function(a:Dynamic, b:Dynamic):Int {
					var t1:Float = a[0];
					var t2:Float = b[0];
					if (t1 < t2) return -1;
					if (t1 > t2) return 1;
					return 0;
				});

				sec.sectionNotes = cleanedNotes;
			}
		}
	}

	function saveEventsToSongInMemory():Void
	{
		prepareSongForSave();

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
			sortEvents();
			for (ev in events)
			{
				var eName = ev.name;
				var v1 = "";
				var v2 = '${ev.duration},${ev.ease}';
				if (eName == "ZoomCamera")
				{
					v1 = Std.string(ev.zoom);
				}
				else if (eName == "Change Character")
				{
					var targetStr = (ev.target == 0) ? "bf" : ((ev.target == 1) ? "dad" : "gf");
					v1 = (ev.x != 0 || ev.y != 0) ? '$targetStr,${ev.x},${ev.y}' : targetStr;
					v2 = ev.charName;
				}
				else if (eName == "Play Anim")
				{
					var targetStr = (ev.target == 0) ? "bf" : ((ev.target == 1) ? "dad" : "gf");
					v1 = targetStr;
					v2 = ev.animLock ? '${ev.animName},lock' : ev.animName;
				}
				else if (eName == "Change Stage")
				{
					v1 = ev.stageName != null ? ev.stageName : "";
					v2 = ev.stageOptions != null ? ev.stageOptions : "";
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

		// Persist Event Group assignments cleanly without altering PlayState compatibility
		var savedGroups:Array<Dynamic> = [];
		if (_song.eventGroups != null)
		{
			for (eg in _song.eventGroups)
			{
				if (eg != null && Reflect.hasField(eg, "name"))
				{
					var eName:String = Reflect.hasField(eg, "event") ? Std.string(Reflect.field(eg, "event")) : "";
					if (eName != "" && !CameraEditorEvent.isCameraEventName(eName))
						savedGroups.push(eg);
				}
			}
		}
		for (ev in events)
		{
			if (ev != null && ev.groupName != null && ev.groupName.trim() != "")
			{
				savedGroups.push({
					time: Math.round(ev.time * 1000) / 1000,
					name: ev.groupName.trim(),
					event: ev.name,
					target: ev.target
				});
			}
		}
		_song.eventGroups = (savedGroups.length > 0) ? savedGroups : null;

		PlayState.SONG = _song;
	}

	static function addEventToPsychList(eventsArr:Array<Dynamic>, time:Float, name:String, v1:String, v2:String):Void
	{
		if (name == null || name.trim() == "") return;

		var roundedTime = Math.round(time * 1000) / 1000;
		var incomingTarget:Int = -999;
		if (name == "Change Character" || name == "Play Anim")
		{
			var v1Parts = CameraEditorEvent.splitEventParams(v1);
			incomingTarget = (v1Parts.length > 0) ? CameraEditorEvent.parseTargetToken(v1Parts[0], 1) : 1;
		}

		for (e in eventsArr)
		{
			if (e != null && Std.isOfType(e, Array))
			{
				var arr:Array<Dynamic> = cast e;
				if (arr.length >= 2)
				{
					var t:Float = Std.parseFloat(Std.string(arr[0]));
					if (Math.abs(t - roundedTime) <= 2.0)
					{
						var subList:Array<Dynamic> = cast arr[1];
						var updatedExisting:Bool = false;
						for (i in 0...subList.length)
						{
							var sub = subList[i];
							if (sub != null && Std.isOfType(sub, Array))
							{
								var sArr:Array<Dynamic> = cast sub;
								if (sArr.length > 0 && Std.string(sArr[0]) == name)
								{
									var sameSlot:Bool = true;
									if (incomingTarget != -999)
									{
										var exV1 = (sArr.length > 1 && sArr[1] != null) ? Std.string(sArr[1]) : "";
										var exParts = CameraEditorEvent.splitEventParams(exV1);
										var exTarget = (exParts.length > 0) ? CameraEditorEvent.parseTargetToken(exParts[0], 1) : 1;
										sameSlot = (exTarget == incomingTarget);
									}
									if (sameSlot)
									{
										// Update existing event rather than duplicating
										subList[i] = [name, v1, v2];
										updatedExisting = true;
										break;
									}
								}
							}
						}
						if (!updatedExisting)
						{
							subList.push([name, v1, v2]);
						}
						subList.sort(function(sa:Dynamic, sb:Dynamic):Int {
							var na = (sa != null && sa.length > 0 && sa[0] != null) ? Std.string(sa[0]).toLowerCase().trim() : "";
							var nb = (sb != null && sb.length > 0 && sb[0] != null) ? Std.string(sb[0]).toLowerCase().trim() : "";
							var pa:Int = (na == "change character" || na == "changechar") ? 0 : ((na == "play anim" || na == "playanim" || na == "play animation") ? 1 : 2);
							var pb:Int = (nb == "change character" || nb == "changechar") ? 0 : ((nb == "play anim" || nb == "playanim" || nb == "play animation") ? 1 : 2);
							return pa - pb;
						});
						return;
					}
				}
			}
		}

		eventsArr.push([roundedTime, [[name, v1, v2]]]);
	}

	public function saveEventsToSong():Void
	{
		saveEventsToSongInMemory();

		#if sys
		var songFolder = _song.song.toLowerCase().trim();
		var diffSuffix = "";
		if (PlayState.storyDifficulty == 0) diffSuffix = "-easy";
		else if (PlayState.storyDifficulty == 2) diffSuffix = "-hard";
		var chartFileName = songFolder + diffSuffix;

		var targetPath:String = loadedChartPath;
		if (targetPath == null || targetPath.trim() == "" || !FileSystem.exists(targetPath))
		{
			if (_song.chartPath != null && _song.chartPath.trim() != "" && FileSystem.exists(_song.chartPath))
			{
				targetPath = _song.chartPath;
			}
		}

		if (targetPath == null || !FileSystem.exists(targetPath))
		{
			var curMod = core.scripting.Mods.currentModDirectory;
			var candidates:Array<String> = [];

			if (curMod != null && curMod.length > 0)
			{
				if (diffSuffix != "")
				{
					candidates.push('mods/$curMod/songs/$songFolder/$chartFileName.json');
					candidates.push('mods/$curMod/data/$songFolder/$chartFileName.json');
					candidates.push('mods/$curMod/songs/$songFolder/charts/$chartFileName.json');
				}
				candidates.push('mods/$curMod/songs/$songFolder/$songFolder.json');
				candidates.push('mods/$curMod/songs/$songFolder/chart/chart.json');
				candidates.push('mods/$curMod/songs/$songFolder/charts/$songFolder.json');
				candidates.push('mods/$curMod/data/$songFolder/$songFolder.json');
			}
			if (diffSuffix != "")
			{
				candidates.push('mods/songs/$songFolder/$chartFileName.json');
				candidates.push('assets/songs/$songFolder/$chartFileName.json');
				candidates.push('assets/songs/$songFolder/charts/$chartFileName.json');
				candidates.push('assets/data/$songFolder/$chartFileName.json');
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

			if (targetPath == null)
			{
				targetPath = gameplay.chart.ChartConverter.findChartPath(songFolder, chartFileName);
			}
		}

		if (targetPath == null)
		{
			targetPath = 'assets/songs/$songFolder/$chartFileName.json';
		}

		try
		{
			var dir = Path.directory(targetPath);
			if (dir != null && dir.length > 0 && !FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var jsonContent = Json.stringify({song: _song}, "\t");
			File.saveContent(targetPath, jsonContent);
			loadedChartPath = targetPath;
			_song.chartPath = targetPath;

			// Update autosave in FlxG.save
			FlxG.save.data.cameraEditorAutosave = jsonContent;
			FlxG.save.flush();

			FlxG.sound.play(Paths.sound('confirm'));
			timeText.text = 'SAVED TO: $targetPath';
			showToast("✔ Saved chart & camera events!");
			lastDisplayedSongPos = -1;
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Error saving song JSON: $e');
			timeText.text = 'ERROR SAVING: $e';
			lastDisplayedSongPos = -1;
		}
		#else
		var diffSuffix = "";
		if (PlayState.storyDifficulty == 0) diffSuffix = "-easy";
		else if (PlayState.storyDifficulty == 2) diffSuffix = "-hard";
		var saveFileName = _song.song.toLowerCase() + diffSuffix + ".json";

		var jsonContent = Json.stringify({song: _song}, "\t");
		var _file = new FileReference();
		_file.save(jsonContent, saveFileName);
		#end
	}

	function isHoveringEventBlock(mx:Float, my:Float):Bool
	{
		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;
		var curLaneH:Float = getLaneHeight();
		for (i in 0...events.length)
		{
			var ev = events[i];
			var laneIdx = ev.layer % layers.length;

			var nextDistMs:Float = -1;
			for (j in (i + 1)...events.length)
			{
				var nextEv = events[j];
				if ((nextEv.layer % layers.length) == laneIdx && nextEv.time > ev.time + 0.5)
				{
					nextDistMs = nextEv.time - ev.time;
					break;
				}
			}

			var bx = TIMELINE_LEFT_X + (ev.time - timelineScrollMs) * effectivePixelsPerMs;
			var by = TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT + (laneIdx * curLaneH) + 4;
			var bw = getEventBlockWidth(ev, effectivePixelsPerMs, nextDistMs);
			var bh = Math.max(10.0, curLaneH - 8);

			if (bx + bw < TIMELINE_LEFT_X)
				continue;

			if (bx > FlxG.width + 50)
				break;

			var hitLeft = Math.max(TIMELINE_LEFT_X, bx);
			var hitRight = Math.min(FlxG.width, bx + bw);

			if (mx >= hitLeft && mx <= hitRight && my >= by && my <= by + bh)
				return true;
		}
		return false;
	}

	function closeAllDropdowns(?except:FlxUIDropDownMenu):Void
	{
		var dropdowns = [focusEaseDropDown, zoomEaseDropDown, focusTargetDropDown, charTargetDropDown, charNameDropDown, animTargetDropDown, animNameDropDown, stageNameDropDown];
		for (dd in dropdowns)
		{
			if (dd != null && dd != except && dd.dropPanel != null && dd.dropPanel.visible)
			{
				@:privateAccess dd.showList(false);
			}
		}
	}

	function isAnyDropdownOpen():Bool
	{
		var dropdowns = [focusEaseDropDown, zoomEaseDropDown, focusTargetDropDown, charTargetDropDown, charNameDropDown, animTargetDropDown, animNameDropDown, stageNameDropDown];
		for (dd in dropdowns)
		{
			if (dd != null && dd.dropPanel != null && dd.dropPanel.visible)
				return true;
		}
		return false;
	}

	function setInteractiveUIActive(active:Bool):Void
	{
		var allButtons:Array<FlxButton> = [
			btnPlayPause, btnRewind, btnSnap, btnShift, btnAddLayer, btnDeleteLayer, btnZoomIn, btnZoomOut,
			btnRelativeView, btnPassepartout, btnExtendedBounds, btnCameraBop, btnCamMarkers,
			btnDeleteEvent, btnDuplicateEvent, btnDeselectEvent, btnNudgeBack, btnNudgeForward,
			btnQuickAddFocus, btnQuickAddZoom, btnQuickAddChar, btnQuickAddAnim, btnQuickAddStage, btnAutoGen, btnResetOffset,
			btnZoomPresetStage, btnZoomPresetClose, btnZoomPresetWide,
			btnResetCharOffset, btnTestAnim,
			btnStageOptNoRepos, btnStageOptNoZoom, btnStageOptFlash, btnPreviewStage
		];

		for (btn in allButtons)
		{
			if (btn != null) btn.active = active;
		}
	}

	function isHoveringButton(mx:Float, my:Float):Bool
	{
		if (isAnyDropdownOpen() || blockInputUntilMouseRelease)
			return false;

		var allButtons:Array<FlxButton> = [
			btnPlayPause, btnRewind, btnSnap, btnShift, btnAddLayer, btnDeleteLayer, btnZoomIn, btnZoomOut,
			btnRelativeView, btnPassepartout, btnExtendedBounds, btnCameraBop, btnCamMarkers,
			btnDeleteEvent, btnDuplicateEvent, btnDeselectEvent, btnNudgeBack, btnNudgeForward,
			btnQuickAddFocus, btnQuickAddZoom, btnQuickAddChar, btnQuickAddAnim, btnQuickAddStage, btnAutoGen, btnResetOffset,
			btnZoomPresetStage, btnZoomPresetClose, btnZoomPresetWide,
			btnResetCharOffset, btnTestAnim,
			btnStageOptNoRepos, btnStageOptNoZoom, btnStageOptFlash, btnPreviewStage
		];

		for (btn in allButtons)
		{
			if (btn != null && btn.visible && mx >= btn.x && mx <= btn.x + btn.width && my >= btn.y && my <= btn.y + btn.height)
				return true;
		}
		return false;
	}

	function isHoveringStepper(mx:Float, my:Float):Bool
	{
		if (isAnyDropdownOpen() || blockInputUntilMouseRelease)
			return false;

		var steppers:Array<FlxUINumericStepper> = [];
		if (selectedEvent != null)
		{
			if (selectedEvent.name == "FocusCamera")
				steppers = [focusXStepper, focusYStepper, focusDurationStepper];
			else if (selectedEvent.name == "ZoomCamera")
				steppers = [zoomValueStepper, zoomDurationStepper];
			else if (selectedEvent.name == "Change Character")
				steppers = [charXStepper, charYStepper];
		}
		for (s in steppers)
		{
			if (s != null && s.visible)
			{
				var sw = Math.max(s.width, 75);
				var sh = Math.max(s.height, 22);
				if (mx >= s.x && mx <= s.x + sw && my >= s.y && my <= s.y + sh)
					return true;
			}
		}
		return false;
	}

	function handleStepperMouseWheel(mx:Float, my:Float):Bool
	{
		if (FlxG.mouse.wheel == 0 || isAnyDropdownOpen() || blockInputUntilMouseRelease)
			return false;

		var steppers:Array<FlxUINumericStepper> = [];
		if (selectedEvent != null)
		{
			if (selectedEvent.name == "FocusCamera")
				steppers = [focusXStepper, focusYStepper, focusDurationStepper];
			else if (selectedEvent.name == "ZoomCamera")
				steppers = [zoomValueStepper, zoomDurationStepper];
			else if (selectedEvent.name == "Change Character")
				steppers = [charXStepper, charYStepper];
		}

		for (s in steppers)
		{
			if (s != null && s.visible)
			{
				var sw = Math.max(s.width, 75);
				var sh = Math.max(s.height, 22);
				if (mx >= s.x && mx <= s.x + sw && my >= s.y && my <= s.y + sh)
				{
					var step = s.stepSize;
					var mult:Float = 1.0;
					if (FlxG.keys.pressed.SHIFT)
					{
						// Fast stepping with Shift:
						// X / Y offsets: 10 * 5 = 50 per tick
						// Zoom: 0.05 * 4 = 0.20 per tick
						// Duration: 0.5 * 8 = 4.0 steps (1 whole beat!) per tick
						if (s == focusXStepper || s == focusYStepper || s == charXStepper || s == charYStepper)
							mult = 5.0;
						else if (s == zoomValueStepper)
							mult = 4.0;
						else
							mult = 8.0;
					}
					else if (FlxG.keys.pressed.CONTROL)
					{
						// Ultra fast stepping with Ctrl:
						// X / Y offsets: 10 * 10 = 100 per tick
						// Zoom: 0.05 * 10 = 0.50 per tick
						// Duration: 0.5 * 16 = 8.0 steps (2 beats!) per tick
						if (s == focusXStepper || s == focusYStepper || s == charXStepper || s == charYStepper)
							mult = 10.0;
						else if (s == zoomValueStepper)
							mult = 10.0;
						else
							mult = 16.0;
					}

					var delta = FlxG.mouse.wheel * step * mult;
					var newVal = s.value + delta;
					if (s.decimals > 0)
					{
						var power = Math.pow(10, s.decimals);
						newVal = Math.round(newVal * power) / power;
					}
					else
					{
						newVal = Math.round(newVal);
					}
					newVal = FlxMath.bound(newVal, s.min, s.max);

					if (newVal != s.value)
					{
						s.value = newVal;
						getEvent(FlxUINumericStepper.CHANGE_EVENT, s, s.value);
					}
					return true;
				}
			}
		}
		return false;
	}

	function isHoveringDropdown(mx:Float, my:Float):Bool
	{
		var dropdowns = [focusEaseDropDown, zoomEaseDropDown, focusTargetDropDown, charTargetDropDown, charNameDropDown, animTargetDropDown, animNameDropDown, stageNameDropDown];
		for (dd in dropdowns)
		{
			if (dd != null && dd.visible)
			{
				var w = Math.max(dd.header.background.width, 120);
				if (mx >= dd.x && mx <= dd.x + w
					&& my >= dd.y && my <= dd.y + dd.header.background.height)
					return true;

				if (dd.dropPanel != null && dd.dropPanel.visible)
				{
					var numVisible = Std.int(Math.min(dd.list.length, MAX_DROPDOWN_VISIBLE));
					var panelH = numVisible * dd.header.background.height;
					if (mx >= dd.x && mx <= dd.x + w
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

		// Just opened this frame: auto-scroll to selected item & close other dropdowns
		if (!wasOpen)
		{
			closeAllDropdowns(dd);
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

			// Sync Conductor BPM if dynamic BPM change occurs
			var bpmEvent = Conductor.getBPMChangeEvent(currentSongTime);
			if (bpmEvent != null && bpmEvent.bpm > 0 && bpmEvent.bpm != Conductor.bpm)
			{
				Conductor.changeBPM(bpmEvent.bpm);
			}

			// Process live camera events (including Change Character + X/Y and Play Anim) before note hits
			// so characters swap and move to their target X/Y on the exact step before singing
			processCameraEventsPlayback(prevSongTime, currentSongTime);

			// Process live note hits for character singing
			processNotesPlayback(prevSongTime, currentSongTime);

			// Process live section camera transitions
			processSectionChangePlayback(prevSongTime, currentSongTime);

			// Reset boyfriend animation to idle once note hold ends
			var curStepC = getStepCrochetAtTime(currentSongTime);
			if (boyfriend != null && boyfriend.holdTimer > curStepC * boyfriend.singDuration * 0.001)
			{
				var bAnim = getCharAnim(boyfriend);
				if (bAnim.startsWith('sing') && !bAnim.endsWith('miss') && !boyfriend.animLocked)
					boyfriend.dance();
			}

			// Reset dad animation to idle once note hold ends
			if (dadOpponent != null && dadOpponent.holdTimer > curStepC * dadOpponent.singDuration * 0.001)
			{
				var dAnim = getCharAnim(dadOpponent);
				if (dAnim.startsWith('sing') && !dAnim.endsWith('miss') && !dadOpponent.animLocked)
					dadOpponent.dance();
			}
		}
		else if (isPlaying && songMusic != null && !songMusic.playing)
		{
			isPlaying = false;
			if (vocals != null) vocals.pause();
			if (opponentVocals != null) opponentVocals.pause();
			if (btnPlayPause != null)
			{
				btnPlayPause.loadGraphic(Paths.image('menus/editors/camera/play'));
				btnPlayPause.setGraphicSize(24, 24);
				btnPlayPause.updateHitbox();
			}
		}

		// Update Conductor Steps and Beats via Conductor BPM change mapping
		updateContents();

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
			playheadTopper.x = px - 5;

			// Auto-scroll timeline while playing
			if (isPlaying && px > FlxG.width - 60)
			{
				timelineScrollMs = Math.max(0, Conductor.songPosition - (200 / effectivePixelsPerMs));
				refreshTimelineLanes();
				refreshEventBlocks();
			}
		}

		// 2. Dropdown State & Click-Through Protection
		var dropdownOpen:Bool = isAnyDropdownOpen();
		if (!dropdownOpen)
		{
			if (!FlxG.mouse.pressed && !FlxG.mouse.justReleased)
			{
				blockInputUntilMouseRelease = false;
			}
		}
		else
		{
			blockInputUntilMouseRelease = true;
			if (FlxG.mouse.justPressed && !isHoveringDropdown(mouseX, mouseY))
			{
				closeAllDropdowns();
			}
		}

		// Keep all interactive UI buttons disabled while a dropdown is open or releasing
		setInteractiveUIActive(!dropdownOpen && !blockInputUntilMouseRelease);

		// Cursor Icon Feedback
		var insideTimeline = (mouseY >= TIMELINE_Y && mouseY <= FlxG.height && mouseX >= TIMELINE_LEFT_X);
		var onRuler = (insideTimeline && mouseY <= TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT);
		var onPlayhead = (insideTimeline && Math.abs(mouseX - playheadLine.x) <= 8);

		if (isDraggingEventBlock || isDraggingPlayhead || isPanningViewport)
		{
			changeCursor('cursor-grabbing');
		}
		else if (isResizingEventBlock)
		{
			changeCursor('cursor-scroll');
		}
		else if (onRuler || onPlayhead || isHoveringEventBlock(mouseX, mouseY) || isHoveringButton(mouseX, mouseY) || isHoveringDropdown(mouseX, mouseY) || isHoveringStepper(mouseX, mouseY))
		{
			changeCursor('cursor-pointer');
		}
		else
		{
			changeCursor('cursor-default');
		}

		// Stepper Numeric Mouse Wheel Handling (quick value adjustments)
		var handledStepperWheel:Bool = false;
		if (!dropdownOpen && !blockInputUntilMouseRelease)
		{
			handledStepperWheel = handleStepperMouseWheel(mouseX, mouseY);
		}

		// Dropdown scroll interactions
		if (dropdownOpen)
		{
			handleDropdownScroll(focusEaseDropDown);
			handleDropdownScroll(zoomEaseDropDown);
			handleDropdownScroll(focusTargetDropDown);
			handleDropdownScroll(charTargetDropDown);
			handleDropdownScroll(charNameDropDown);
			handleDropdownScroll(animTargetDropDown);
			handleDropdownScroll(animNameDropDown);
			handleDropdownScroll(stageNameDropDown);
		}

		var hoveringEaseControl = (!dropdownOpen && !blockInputUntilMouseRelease && !handledStepperWheel && (
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

		// 3. Mouse Timeline Interactions
		if (!dropdownOpen && !blockInputUntilMouseRelease)
			handleTimelineMouseInput(mouseX, mouseY, handledStepperWheel);

		// 4. Stage Viewport Mouse Interactions (Pan & Zoom)
		if (!dropdownOpen && !hoveringEaseControl && !handledStepperWheel && !blockInputUntilMouseRelease)
			handleViewportMouseInput(mouseX, mouseY);

		// 5. Keyboard Shortcuts
		if (!dropdownOpen && !blockInputUntilMouseRelease)
			handleKeyboardInput();

		// 6. Update Relative View positioning
		if (cameraRect.isRelative)
		{
			camGame.scroll.set(cameraRect.vcamPoint.x, cameraRect.vcamPoint.y);
			camGame.zoom = cameraRect.zoom;
		}

		// 7. Toast notification countdown & fade
		if (toastTimer > 0)
		{
			toastTimer -= elapsed;
			if (toastTimer <= 0.4)
			{
				var a = Math.max(0, toastTimer / 0.4);
				if (toastSprite != null) toastSprite.alpha = a;
				if (toastText != null) toastText.alpha = a;
			}
			if (toastTimer <= 0)
			{
				if (toastSprite != null) toastSprite.visible = false;
				if (toastText != null) toastText.visible = false;
			}
		}

		mousePos.put();

		super.update(elapsed);
	}

	function handleTimelineMouseInput(mx:Float, my:Float, handledStepperWheel:Bool = false):Void
	{
		if (isHoveringDropdown(mx, my) || isAnyDropdownOpen() || blockInputUntilMouseRelease)
			return;

		var effectivePixelsPerMs = timelinePixelsPerMs * timelineZoomScale;

		var insideTimeline = (my >= TIMELINE_Y && my <= FlxG.height && mx >= TIMELINE_LEFT_X);
		var onRuler = (insideTimeline && my <= TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT);
		var isNearPlayhead = (insideTimeline && Math.abs(mx - playheadLine.x) <= 8);

		var maxSongMs:Float = (songMusic != null && songMusic.length > 0) ? songMusic.length : (events.length > 0 ? events[events.length - 1].time + 10000 : 300000);

		if (FlxG.mouse.justPressed)
		{
			// Click on ruler: scrub song position directly
			if (onRuler)
			{
				isDraggingPlayhead = true;
				if (isPlaying)
					togglePlayback();

				var targetMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / effectivePixelsPerMs;
				targetMs = FlxMath.bound(targetMs, 0, maxSongMs);
				setTimePosition(targetMs, true);
			}
			// Click on lanes: check block hits or playhead grab
			else if (insideTimeline && my > TIMELINE_Y + 30 + TIMELINE_RULER_HEIGHT)
			{
				var clickedOnBlock:Bool = false;

				var i = computedBlockBounds.length - 1;
				while (i >= 0)
				{
					var b = computedBlockBounds[i];
					var bx = b.x;
					var by = b.y;
					var bw = b.w;
					var bh = b.h;

					if (bx + bw < TIMELINE_LEFT_X || bx > FlxG.width + 50)
					{
						i--;
						continue;
					}

					var hitLeft = Math.max(TIMELINE_LEFT_X, bx);
					var hitRight = Math.min(FlxG.width, bx + bw);

					if (mx >= hitLeft && mx <= hitRight && my >= by && my <= by + bh)
					{
						var ev = b.ev;
						clickedOnBlock = true;
						selectedEvent = ev;
						draggedEvent = ev;
						dragStartMouseX = mx;
						dragStartEventTime = ev.time;
						dragStartEventDuration = ev.duration;

						dragGroupStartTimes.clear();
						if (ev.groupName != "" && groupDragMoveCheck != null && groupDragMoveCheck.checked)
						{
							for (gEv in getEventsInGroup(ev.groupName))
								dragGroupStartTimes.set(gEv, gEv.time);
						}

						// Check if dragging right edge (resize duration)
						if (bw > 35 && mx >= bx + bw - 10)
							isResizingEventBlock = true;
						else
							isDraggingEventBlock = true;

						updateInspectorUI();
						refreshEventBlocks();
						break;
					}
					i--;
				}

				if (!clickedOnBlock)
				{
					if (isNearPlayhead)
					{
						isDraggingPlayhead = true;
						if (isPlaying)
							togglePlayback();

						var targetMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / effectivePixelsPerMs;
						targetMs = FlxMath.bound(targetMs, 0, maxSongMs);
						setTimePosition(targetMs, true);
					}
					else
					{
						selectedEvent = null;
						updateInspectorUI();
						refreshEventBlocks();
					}
				}
			}
		}

		if (FlxG.mouse.pressed)
		{
			if (isDraggingPlayhead)
			{
				var targetMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / effectivePixelsPerMs;
				targetMs = FlxMath.bound(targetMs, 0, maxSongMs);
				setTimePosition(targetMs, true);
			}
			else if (isDraggingEventBlock && draggedEvent != null)
			{
				// Smooth 1:1 dragging locked to mouse cursor (no jumping or displacement)
				var deltaMs = (mx - dragStartMouseX) / effectivePixelsPerMs;
				var newTime = Math.max(0, dragStartEventTime + deltaMs);
				if (FlxG.keys.pressed.CONTROL && snapEnabled)
				{
					var decStep = Conductor.calculateDecStep(newTime);
					var snapUnit = snapToBeat ? 4.0 : 1.0;
					var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
					newTime = getTimeFromStep(Math.max(0, snappedStep));
				}

				if (draggedEvent.groupName != "" && groupDragMoveCheck != null && groupDragMoveCheck.checked && dragGroupStartTimes.exists(draggedEvent))
				{
					var appliedDelta = newTime - dragStartEventTime;
					for (gEv => startT in dragGroupStartTimes)
					{
						gEv.time = Math.max(0, startT + appliedDelta);
					}
				}
				else
				{
					draggedEvent.time = newTime;
				}
				refreshEventBlocks();

				if (eventTimeLabel != null)
				{
					var tDisplay = draggedEvent.time;
					var totalSec = Math.floor(tDisplay / 1000);
					var mins = Math.floor(totalSec / 60);
					var secs = totalSec % 60;
					var ms = Math.floor(tDisplay % 1000 / 10);
					var strMins = (mins < 10 ? "0" : "") + mins;
					var strSecs = (secs < 10 ? "0" : "") + secs;
					var strMs = (ms < 10 ? "0" : "") + ms;
					var curS = Math.floor(Conductor.calculateDecStep(tDisplay));
					eventTimeLabel.text = 'Time: $strMins:$strSecs.$strMs (Step $curS)';
				}
			}
			else if (isResizingEventBlock && draggedEvent != null)
			{
				// Smooth 1:1 duration resize handle
				var deltaMs = (mx - dragStartMouseX) / effectivePixelsPerMs;
				var curStepC = getStepCrochetAtTime(draggedEvent.time);
				var deltaSteps = deltaMs / curStepC;
				var newDur = Math.max(0.25, dragStartEventDuration + deltaSteps);
				if (FlxG.keys.pressed.CONTROL && snapEnabled)
				{
					newDur = Math.max(0.5, Math.round(newDur * 2) / 2);
				}
				draggedEvent.duration = newDur;
				refreshEventBlocks();

				if (focusDurationStepper != null && selectedEvent != null && selectedEvent.name == "FocusCamera")
				{
					focusDurationStepper.value = newDur;
					if (focusDurationSub != null)
					{
						var durSec = Math.round(((newDur * curStepC) / 1000.0) * 100) / 100;
						focusDurationSub.text = '(= ${durSec}s)';
					}
				}
				else if (zoomDurationStepper != null && selectedEvent != null && selectedEvent.name == "ZoomCamera")
				{
					zoomDurationStepper.value = newDur;
					if (zoomDurationSub != null)
					{
						var durSec = Math.round(((newDur * curStepC) / 1000.0) * 100) / 100;
						zoomDurationSub.text = '(= ${durSec}s)';
					}
				}
			}
		}

		if (FlxG.mouse.justReleased)
		{
			if (isDraggingPlayhead || isDraggingEventBlock || isResizingEventBlock)
			{
				var wasDraggingPlayhead = isDraggingPlayhead;
				var wasDraggingEvent = isDraggingEventBlock;
				var wasResizingEvent = isResizingEventBlock;

				isDraggingPlayhead = false;
				isDraggingEventBlock = false;
				isResizingEventBlock = false;

				if (wasDraggingEvent && draggedEvent != null)
				{
					var movedDist = Math.abs(mx - dragStartMouseX);
					if (movedDist <= 3)
					{
						if (dragGroupStartTimes.exists(draggedEvent))
						{
							for (gEv => startT in dragGroupStartTimes)
								gEv.time = startT;
						}
						draggedEvent.time = dragStartEventTime;
					}
					else if (snapEnabled && !FlxG.keys.pressed.SHIFT)
					{
						var decStep = Conductor.calculateDecStep(draggedEvent.time);
						var snapUnit = snapToBeat ? 4.0 : 1.0;
						var snappedStep = Math.round(decStep / snapUnit) * snapUnit;
						var snappedTime = getTimeFromStep(Math.max(0, snappedStep));
						if (dragGroupStartTimes.exists(draggedEvent))
						{
							var appliedDelta = snappedTime - dragStartEventTime;
							for (gEv => startT in dragGroupStartTimes)
								gEv.time = Math.max(0, startT + appliedDelta);
						}
						else
						{
							draggedEvent.time = snappedTime;
						}
					}
					dragGroupStartTimes.clear();
					sortEvents();
					refreshEventBlocks();
					updateInspectorUI();
				}
				else if (wasResizingEvent && draggedEvent != null)
				{
					var movedDist = Math.abs(mx - dragStartMouseX);
					if (movedDist > 3 && snapEnabled && !FlxG.keys.pressed.SHIFT)
					{
						draggedEvent.duration = Math.max(0.5, Math.round(draggedEvent.duration * 2) / 2);
					}
					refreshEventBlocks();
					updateInspectorUI();
				}

				draggedEvent = null;
				if (!isPlaying && selectedEvent != null && selectedEvent.name == "Change Character")
					applySelectedCharEventPreview();
				else
					replayCameraTimeline(Conductor.songPosition);

				if (wasDraggingPlayhead)
				{
					refreshEventBlocks();
				}
			}
		}

		// Horizontal scroll with mouse wheel over timeline
		if (insideTimeline && FlxG.mouse.wheel != 0 && !handledStepperWheel)
		{
			if (FlxG.keys.pressed.CONTROL)
			{
				var oldEffective = timelinePixelsPerMs * timelineZoomScale;
				var mouseMs = timelineScrollMs + (mx - TIMELINE_LEFT_X) / oldEffective;
				timelineZoomScale = FlxMath.bound(timelineZoomScale + (FlxG.mouse.wheel * 0.15), 0.25, 4.0);
				var newEffective = timelinePixelsPerMs * timelineZoomScale;
				timelineScrollMs = Math.max(0, mouseMs - (mx - TIMELINE_LEFT_X) / newEffective);
				saveEditorPreferences();
				updateModeButtonVisuals();
			}
			else
			{
				var curStepC = getStepCrochetAtTime(timelineScrollMs);
				timelineScrollMs = Math.max(0, timelineScrollMs - (FlxG.mouse.wheel * curStepC * 8));
			}
			refreshTimelineLanes();
			refreshEventBlocks();
			lastDisplayedSongPos = -1;
			var currentPx = TIMELINE_LEFT_X + (Conductor.songPosition - timelineScrollMs) * (timelinePixelsPerMs * timelineZoomScale);
			if (playheadLine != null) playheadLine.x = currentPx;
			if (playheadTopper != null) playheadTopper.x = currentPx - 5;
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
		if ((focusEaseInput != null && focusEaseInput.hasFocus) 
			|| (zoomEaseInput != null && zoomEaseInput.hasFocus)
			|| (charNameInput != null && charNameInput.hasFocus)
			|| (animNameInput != null && animNameInput.hasFocus)
			|| (stageNameInput != null && stageNameInput.hasFocus)
			|| (stageOptionsInput != null && stageOptionsInput.hasFocus)
			|| (groupNameInput != null && groupNameInput.hasFocus))
			return true;

		var steppers = [focusXStepper, focusYStepper, focusDurationStepper, zoomValueStepper, zoomDurationStepper, charXStepper, charYStepper];
		for (s in steppers)
		{
			if (s != null && s.visible)
			{
				@:privateAccess if (s.text_field != null && (s.text_field is flixel.addons.ui.FlxInputText))
				{
					var fit:flixel.addons.ui.FlxInputText = cast s.text_field;
					if (fit.hasFocus) return true;
				}
			}
		}
		return false;
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
				if (charNameInput != null) charNameInput.hasFocus = false;
				if (animNameInput != null) animNameInput.hasFocus = false;
				if (stageNameInput != null) stageNameInput.hasFocus = false;
				if (stageOptionsInput != null) stageOptionsInput.hasFocus = false;
				if (groupNameInput != null) groupNameInput.hasFocus = false;
				var steppers = [focusXStepper, focusYStepper, focusDurationStepper, zoomValueStepper, zoomDurationStepper, charXStepper, charYStepper];
				for (s in steppers)
				{
					if (s != null)
					{
						@:privateAccess if (s.text_field != null && (s.text_field is flixel.addons.ui.FlxInputText))
						{
							var fit:flixel.addons.ui.FlxInputText = cast s.text_field;
							fit.hasFocus = false;
						}
					}
				}
			}
			return;
		}

		var shift = FlxG.keys.pressed.SHIFT;
		var ctrl = FlxG.keys.pressed.CONTROL;

		// Space: Play/Pause
		if (FlxG.keys.justPressed.SPACE)
		{
			togglePlayback();
		}

		// Home: Rewind to 0
		if (FlxG.keys.justPressed.HOME)
		{
			setTimePosition(0);
			showToast("Rewound to 0:00");
		}

		// Left / Right: Step backward / forward
		if (FlxG.keys.justPressed.LEFT)
		{
			var currentStep = Conductor.calculateDecStep(Conductor.songPosition);
			var targetStep = shift ? (Math.ceil(currentStep / 16.0) - 1) * 16.0 : Math.ceil(currentStep - 1.0);
			if (targetStep < 0) targetStep = 0;
			setTimePosition(getTimeFromStep(targetStep));
		}
		if (FlxG.keys.justPressed.RIGHT)
		{
			var currentStep = Conductor.calculateDecStep(Conductor.songPosition);
			var targetStep = shift ? (Math.floor(currentStep / 16.0) + 1) * 16.0 : Math.floor(currentStep + 1.0);
			setTimePosition(getTimeFromStep(targetStep));
		}

		// F: Quick add Focus Camera Event
		if (FlxG.keys.justPressed.F)
		{
			addFocusEventAtCurrentTime();
		}

		// Z: Quick add Zoom Camera Event
		if (FlxG.keys.justPressed.Z && !ctrl)
		{
			addZoomEventAtCurrentTime();
		}

		// C: Quick add Change Character Event
		if (FlxG.keys.justPressed.C && !ctrl)
		{
			addCharEventAtCurrentTime();
		}

		// A: Quick add Play Animation Event (only when cursor is on Timeline/Inspector or Relative View is active, so WASD stage panning doesn't spam events)
		var mousePos = FlxG.mouse.getViewPosition(camEditorUI);
		var isHoveringStageViewport = (mousePos.y > 42 && mousePos.y < TIMELINE_Y && mousePos.x < INSPECTOR_X);
		mousePos.put();
		if (FlxG.keys.justPressed.A && !ctrl && (!isHoveringStageViewport || cameraRect.isRelative))
		{
			addAnimEventAtCurrentTime();
		}

		// G: Quick add Change Stage Event
		if (FlxG.keys.justPressed.G && !ctrl)
		{
			addStageEventAtCurrentTime();
		}

		// Ctrl + D: Duplicate selected event
		if (ctrl && FlxG.keys.justPressed.D)
		{
			duplicateEvent();
		}

		// M: Cycle Magnet Snap (Step -> Beat -> OFF)
		if (FlxG.keys.justPressed.M)
		{
			toggleSnap();
		}

		// B: Toggle Camera Beat Bop
		if (FlxG.keys.justPressed.B)
		{
			cameraRect.doBopping = !cameraRect.doBopping;
			showToast(cameraRect.doBopping ? "Camera Beat Bop: ON" : "Camera Beat Bop: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
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
				showToast("Camera View Reset");
			}
		}

		// P: Toggle Character Camera Anchor Markers
		if (FlxG.keys.justPressed.P)
		{
			showCamMarkers = !showCamMarkers;
			showToast(showCamMarkers ? "Character Points: ON" : "Character Points: OFF");
			saveEditorPreferences();
			updateModeButtonVisuals();
		}

		// Delete / Backspace: Remove selected event
		if ((FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) && selectedEvent != null)
		{
			events.remove(selectedEvent);
			selectedEvent = null;
			refreshEventBlocks();
			updateInspectorUI();
			replayCameraTimeline(Conductor.songPosition);
			showToast("Event deleted!");
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
			saveEditorPreferences();
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
				else if (ev.name == "Change Character")
				{
					var customX:Null<Float> = (ev.x != 0 || ev.y != 0) ? ev.x : null;
					var customY:Null<Float> = (ev.x != 0 || ev.y != 0) ? ev.y : null;
					if (ev.target == 0)
					{
						activeBfChar = ev.charName;
						activeBfCustomX = customX;
						activeBfCustomY = customY;
					}
					else if (ev.target == 2)
					{
						activeGfChar = ev.charName;
						activeGfCustomX = customX;
						activeGfCustomY = customY;
					}
					else
					{
						activeDadChar = ev.charName;
						activeDadCustomX = customX;
						activeDadCustomY = customY;
					}
					changeEditorCharacter(ev.target, ev.charName, customX, customY);
				}
				else if (ev.name == "Play Anim")
				{
					var char:Character = (ev.target == 0) ? boyfriend : ((ev.target == 2) ? gf : dadOpponent);
					if (char != null)
						char.animLocked = ev.animLock;
					playEditorAnimation(ev.target, ev.animName, true);
				}
				else if (ev.name == "Change Stage")
				{
					applyStageEvent(ev, true, false);
				}

				cachedEventIndex = i + 1;
			}
		}
	}

	function processSectionChangePlayback(prevTime:Float, curTime:Float):Void
	{
		if (_song == null || _song.notes == null || _song.notes.length == 0) return;

		var curSection = getSectionAtStep(curStep);
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
	public var border:FlxSprite;
	public var bg:FlxSprite;
	public var inner:FlxSprite;
	public var icon:FlxSprite;
	public var label:FlxText;
	public var tri:FlxSprite;
	public var edgeGrip:FlxSprite;
	public var event:Null<CameraEditorEvent> = null;

	public function new()
	{
		super();

		border = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		border.origin.set(0, 0);
		add(border);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bg.origin.set(0, 0);
		add(bg);

		inner = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		inner.origin.set(0, 0);
		inner.visible = false;
		add(inner);

		groupStripe = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		groupStripe.origin.set(0, 0);
		groupStripe.visible = false;
		add(groupStripe);

		icon = new FlxSprite(4, 4);
		add(icon);

		label = new FlxText(24, 5, 0, "", 11);
		label.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(label);

		edgeGrip = new FlxSprite().makeGraphic(1, 1, 0xAAFFFFFF);
		edgeGrip.origin.set(0, 0);
		edgeGrip.visible = false;
		add(edgeGrip);

		tri = new FlxSprite(0, 4).loadGraphic(Paths.image('menus/editors/camera/triangle'));
		tri.setGraphicSize(10, 10);
		tri.updateHitbox();
		tri.alpha = 0.7;
		tri.visible = false;
		add(tri);
	}

	public var groupStripe:FlxSprite;

	public function setup(ev:CameraEditorEvent, isSel:Bool, bx:Float, by:Float, bw:Float, bh:Float, ?groupColor:FlxColor = FlxColor.TRANSPARENT, isStacked:Bool = false):Void
	{
		this.event = ev;
		this.visible = true;
		this.active = true;

		var baseColor:FlxColor = 0xFF00AA88;
		if (ev.name == "ZoomCamera")
			baseColor = 0xFFCC7700;
		else if (ev.name == "Change Character")
			baseColor = 0xFF9933CC;
		else if (ev.name == "Play Anim")
			baseColor = 0xFFDDAA00;
		else if (ev.name == "Change Stage")
			baseColor = 0xFF2A82BE;

		var isInstant = (ev.duration <= 0.1 || ev.ease == "INSTANT");
		var hasGroup = (ev.groupName != null && ev.groupName.trim() != "");

		// 1. Crisp Outer Framing Border (1px)
		border.visible = true;
		border.scale.set(bw, bh);
		border.updateHitbox();
		border.x = bx;
		border.y = by;
		border.color = isSel ? 0xFFFFFFFF : (hasGroup && groupColor != FlxColor.TRANSPARENT ? groupColor : 0xFF14141E);
		border.alpha = isSel ? 1.0 : 0.90;

		// 2. Inset Body
		var pad:Float = (bw >= 6.0 && bh >= 6.0) ? 1.0 : 0.0;
		var innerW = Math.max(1.0, bw - (pad * 2.0));
		var innerH = Math.max(1.0, bh - (pad * 2.0));

		// Duration Tail / Body
		bg.visible = true;
		bg.scale.set(innerW, innerH);
		bg.updateHitbox();
		bg.x = bx + pad;
		bg.y = by + pad;
		bg.color = baseColor;
		bg.alpha = isSel ? 0.95 : (isInstant ? 0.90 : 0.50);

		// Badge Header on the left (solid up to 24px wide, holds icon)
		var badgeW = Math.min(innerW, (bh < 15) ? 16.0 : 24.0);
		inner.visible = true;
		inner.scale.set(badgeW, innerH);
		inner.updateHitbox();
		inner.x = bx + pad;
		inner.y = by + pad;
		inner.color = baseColor;
		inner.alpha = 1.0;

		// Group accent stripe along top edge of block
		if (hasGroup && groupColor != FlxColor.TRANSPARENT && innerW >= 4)
		{
			groupStripe.visible = true;
			groupStripe.scale.set(innerW, 2);
			groupStripe.updateHitbox();
			groupStripe.x = bx + pad;
			groupStripe.y = by + pad;
			groupStripe.color = groupColor;
		}
		else
		{
			groupStripe.visible = false;
		}

		// Icon (scales down cleanly inside split sub-rows)
		var iconSize:Int = (bh < 16) ? Std.int(Math.max(8, innerH - 2)) : 16;
		if (badgeW >= iconSize && iconSize >= 8)
		{
			icon.visible = true;
			icon.x = bx + pad + Math.floor((badgeW - iconSize) / 2);
			icon.y = by + pad + Math.floor((innerH - iconSize) / 2);
			if (ev.name == "ZoomCamera")
				icon.loadGraphic(Paths.image('menus/editors/camera/event-icons/zoom_event'));
			else
				icon.loadGraphic(Paths.image('menus/editors/camera/event-icons/focus_event'));
			icon.setGraphicSize(iconSize, iconSize);
			icon.updateHitbox();
		}
		else
		{
			icon.visible = false;
		}

		// Label
		var labelLeftPad:Float = icon.visible ? (badgeW + 3) : 3;
		if (bw > labelLeftPad + 16)
		{
			var labelStr:String = "";
			if (ev.name == "ZoomCamera")
			{
				labelStr = '${ev.zoom}x';
			}
			else if (ev.name == "Change Character")
			{
				var tName = (ev.target == 0 ? "BF" : (ev.target == 1 ? "DAD" : "GF"));
				labelStr = '$tName: ${ev.charName}';
			}
			else if (ev.name == "Play Anim")
			{
				var tName = (ev.target == 0 ? "BF" : (ev.target == 1 ? "DAD" : "GF"));
				labelStr = '$tName: ${ev.animName}';
			}
			else if (ev.name == "Change Stage")
			{
				labelStr = (ev.stageName != null && ev.stageName != "") ? ev.stageName : "stage";
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
			if (hasGroup)
				labelStr = '[${ev.groupName}] $labelStr';
			var fontSize = (bh < 15) ? 8 : 11;
			label.size = fontSize;
			label.visible = true;
			label.text = labelStr;
			label.fieldWidth = Std.int(Math.max(10, bw - labelLeftPad - 4));
			label.x = bx + labelLeftPad;
			label.y = by + Math.max(0, Math.floor((bh - (fontSize + 4)) * 0.5));
		}
		else
		{
			label.visible = false;
		}

		// Right edge resize grip handle
		if (bw > 35 && !isInstant)
		{
			edgeGrip.visible = true;
			edgeGrip.scale.set(3, Math.max(1, innerH - 4));
			edgeGrip.updateHitbox();
			edgeGrip.x = bx + bw - 4;
			edgeGrip.y = by + pad + 2;
		}
		else
		{
			edgeGrip.visible = false;
		}

		// Instant marker
		if (isInstant || ev.duration <= 0.5)
		{
			if (bw >= 16 && bh >= 13)
			{
				tri.visible = true;
				tri.x = bx + bw - 11;
				tri.y = by + Math.max(1, Math.floor((bh - 10) * 0.5));
			}
			else
			{
				tri.visible = false;
			}
		}
		else
		{
			tri.visible = false;
		}
	}
}

package editors;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import flixel.text.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import haxe.Json;
import core.system.Assets;
import core.base.MusicBeatState;
import gameplay.Conductor.BPMChangeEvent;
import gameplay.chart.Section.SwagSection;
import gameplay.chart.Song.SwagSong;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import gameplay.objects.FunkinArrows;
import gameplay.objects.FunkinArrows.Note;
import gameplay.Conductor;
import core.utils.CoolUtil;
import gameplay.chart.Song;
import gameplay.Timings;
import gameplay.PlayState;
using StringTools;

/**
 * The Chart Editor allows developers to create, edit, and visualize note placement, 
 * BPM changes, character swapping, and stage events for custom songs in the engine.
 * Serves as an alternative to external charting tools.
 */
class ChartEditor extends MusicBeatState
{
	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	var curNoteType:Int = 0;

	public static var lastSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;
	var curSong:String = 'Dadbattle';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;

	var dummyArrow:FlxSprite;
	var dummyArrows:Array<FlxSprite> = [];
	var lastDummyData:Int = -1;

	var bgGradient:FlxSprite;
	var bgPulse:Float = 0;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<Note>;

	var gridBG:FlxBackdrop;
	var eventGridBG:FlxBackdrop;
	var gridBlackLine:FlxBackdrop;
	var negativeSpace:FlxSprite;

	var _song:SwagSong;

	var typingShit:FlxInputText;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;
	var curSelectedEvent:Array<Dynamic>;
	var pulsingNote:Array<Dynamic> = null;
	var pulsingEvent:Array<Dynamic> = null;

	var tempBpm:Float = 0;

	var vocals:FlxSound;
	var opponentVocals:FlxSound;

	var playTicksBf:FlxUICheckBox = null;
	var playTicksDad:FlxUICheckBox = null;
	var playedSound:Array<Bool> = [false, false, false, false, false, false, false, false];

	var grabbedNoteData:Array<Dynamic> = null;
	var grabbedNoteProxy:Note = null;
	var dragStartPos:flixel.math.FlxPoint = flixel.math.FlxPoint.get();
	var isDraggingNote:Bool = false;
	var isDraggingSustain:Bool = false;

	var lastCursor:String = "cursor-default";
	function changeCursor(cursorType:String) {
		if (lastCursor != cursorType) {
			FlxG.mouse.load(Paths.image('menus/editors/' + cursorType).bitmap);
			lastCursor = cursorType;
		}
	}

	var curRenderedEvents:FlxTypedGroup<FlxSprite>;

	override function create()
	{
		super.create();
		
		curRenderedEvents = new FlxTypedGroup<FlxSprite>();

		FlxG.mouse.load(Paths.image('menus/editors/cursor-default').bitmap);

		bgGradient = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [flixel.util.FlxColor.BLACK, 0xFF141445, flixel.util.FlxColor.BLACK]);
		bgGradient.scrollFactor.set();
		bgGradient.alpha = 0.4;
		add(bgGradient);

		curSection = lastSection;

		var gridGraphic = flixel.addons.display.FlxGridOverlay.createGrid(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * 2, true, 0xffe7e6e6, 0xffd9d5d5);
		gridBG = new FlxBackdrop(gridGraphic, FlxAxes.Y);
		add(gridBG);

		var eventGridGraphic = flixel.addons.display.FlxGridOverlay.createGrid(GRID_SIZE, GRID_SIZE, GRID_SIZE, GRID_SIZE * 2, true, 0xffd1e3ce, 0xffb7c7b4);
		eventGridBG = new FlxBackdrop(eventGridGraphic, FlxAxes.Y);
		eventGridBG.x = gridBG.x + (GRID_SIZE * 8);
		add(eventGridBG);

		var lineGraphic = new FlxSprite().makeGraphic(2, GRID_SIZE * 2, flixel.util.FlxColor.BLACK).graphic;
		gridBlackLine = new FlxBackdrop(lineGraphic, FlxAxes.Y);
		gridBlackLine.x = gridBG.x + (GRID_SIZE * 4);
		add(gridBlackLine);

		negativeSpace = new FlxSprite(gridBG.x, gridBG.y - 100000).makeGraphic(1, 1, 0xFF000000);
		negativeSpace.scale.set(GRID_SIZE * 8, 100000);
		negativeSpace.updateHitbox();
		negativeSpace.x = gridBG.x;
		negativeSpace.y = gridBG.y - 100000;
		negativeSpace.alpha = 0.4;
		add(negativeSpace);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<Note>();

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			/*
				_song = {
					song: 'Test',
					notes: [],
					bpm: 150,
					needsVoices: true,
					player1: 'bf',
					player2: 'dad',
					speed: 1,
					validScore: false
			};*/
		}

		FlxG.mouse.visible = true;
		FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		if (_song.notes.length == 0) addSection();
		
		if (curSection >= _song.notes.length) curSection = _song.notes.length - 1;
		if (curSection < 0) curSection = 0;

		// sections = _song.notes;

		updateGrid();

		loadSong(_song.song);
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		bpmTxt = new FlxText(20, FlxG.height - 120, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(GRID_SIZE * 8, 4);
		add(strumLine);

		for (i in 0...9) {
			var dArrow = new FlxSprite();
			dArrow.makeGraphic(GRID_SIZE, GRID_SIZE);
			dArrow.visible = false;
			dArrow.ID = -1; // Force visual update later
			dummyArrows.push(dArrow);
			add(dArrow);
		}
		dummyArrow = dummyArrows[0];
		updateDummyArrows();

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 420);
		UI_box.x = FlxG.width - UI_box.width - 20;
		UI_box.y = 20;
		add(UI_box);

		addSongUI();
		addSectionUI();
		addEventUI();
		addNoteUI();

		add(curRenderedEvents);
		add(curRenderedNotes);
		add(curRenderedSustains);
	}

	function addSongUI():Void
	{
		var songNameLabel = new FlxText(10, 8, 0, "Song Name:");
		var UI_songTitle = new FlxInputText(10, 22, 110, _song.song, 8);
		typingShit = UI_songTitle;

		var bpmLabel = new FlxText(135, 8, 0, "BPM:");
		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(135, 22, 1, Conductor.bpm, 1, 999, 1);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';

		var speedLabel = new FlxText(215, 8, 0, "Speed:");
		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(215, 22, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';

		// Character, stage, and asset lists
		var characters:Array<String> = CoolUtil.getCharacterList();
		var stages:Array<String> = CoolUtil.getStageList();
		var assetModifiers:Array<String> = CoolUtil.returnAssetsLibrary('UI/notes');

		// Ensure defaults
		if (_song.stage == null || _song.stage == '') _song.stage = 'stage';
		if (_song.gfVersion == null || _song.gfVersion == '') _song.gfVersion = (_song.player3 != null ? _song.player3 : 'gf');
		if (_song.player3 == null || _song.player3 == '') _song.player3 = _song.gfVersion;

		// Row 1 Dropdowns: Boyfriend & Opponent
		var p1Label = new FlxText(10, 50, 0, "Boyfriend:");
		var player1DropDown = new FlxUIDropDownMenu(10, 65, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
		});
		player1DropDown.selectedLabel = _song.player1;

		var p2Label = new FlxText(150, 50, 0, "Opponent:");
		var player2DropDown = new FlxUIDropDownMenu(150, 65, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
		});
		player2DropDown.selectedLabel = _song.player2;

		// Row 2 Dropdowns: Girlfriend & Stage
		var gfLabel = new FlxText(10, 96, 0, "Girlfriend:");
		var gfDropDown = new FlxUIDropDownMenu(10, 111, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			_song.player3 = _song.gfVersion;
		});
		gfDropDown.selectedLabel = _song.gfVersion;

		var stageLabel = new FlxText(150, 96, 0, "Stage:");
		var stageDropDown = new FlxUIDropDownMenu(150, 111, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(stage:String)
		{
			_song.stage = stages[Std.parseInt(stage)];
		});
		stageDropDown.selectedLabel = _song.stage;

		// Row 3: Note Skin Dropdown & Has Voices Checkbox
		var noteSkinLabel = new FlxText(10, 142, 0, "Note Skin:");
		var assetModifierDropDown = new FlxUIDropDownMenu(10, 157, FlxUIDropDownMenu.makeStrIdLabelArray(assetModifiers, true), function(character:String)
		{
			_song.assetModifier = assetModifiers[Std.parseInt(character)];
		});
		assetModifierDropDown.selectedLabel = _song.assetModifier;

		var check_voices = new FlxUICheckBox(150, 160, null, null, "Has voice track", 120);
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			trace('CHECKED!');
		};

		// Audio Mute Checkboxes
		var check_mute_inst = new FlxUICheckBox(10, 198, null, null, "Mute Instrumental", 125);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;
			if (check_mute_inst.checked) vol = 0;
			songMusic.volume = vol;
		};

		var check_mute_vocals = new FlxUICheckBox(150, 198, null, null, "Mute Vocals", 125);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			var vol:Float = 1;
			if (check_mute_vocals.checked) vol = 0;
			if (vocals != null)
				vocals.volume = vol;
			if (opponentVocals != null)
				opponentVocals.volume = vol;
		};

		// Hitsound Checkboxes
		playTicksBf = new FlxUICheckBox(10, 223, null, null, 'Hitsounds (BF)', 125);
		playTicksBf.checked = false;

		playTicksDad = new FlxUICheckBox(150, 223, null, null, 'Hitsounds (Dad)', 125);
		playTicksDad.checked = false;

		// Action Buttons (2x2 grid)
		var saveButton:FlxButton = new FlxButton(10, 255, "Save", function()
		{
			saveLevel();
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(150, 255, 'Load Autosave', loadAutosave);

		var reloadSong:FlxButton = new FlxButton(10, 285, "Reload Audio", function()
		{
			loadSong(_song.song);
		});

		var cameraEditorBtn:FlxButton = new FlxButton(10, 315, "Camera Editor", function()
		{
			PlayState.SONG = _song;
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new editors.CameraEditor());
		});

		var reloadSongJson:FlxButton = new FlxButton(150, 285, "Reload JSON", function()
		{
			loadJson(_song.song.toLowerCase());
		});

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";

		// Add static labels and controls first
		tab_group_song.add(songNameLabel);
		tab_group_song.add(UI_songTitle);
		tab_group_song.add(bpmLabel);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(speedLabel);
		tab_group_song.add(stepperSpeed);

		tab_group_song.add(p1Label);
		tab_group_song.add(p2Label);
		tab_group_song.add(gfLabel);
		tab_group_song.add(stageLabel);
		tab_group_song.add(noteSkinLabel);
		tab_group_song.add(check_voices);

		tab_group_song.add(check_mute_inst);
		tab_group_song.add(check_mute_vocals);
		tab_group_song.add(playTicksBf);
		tab_group_song.add(playTicksDad);

		tab_group_song.add(saveButton);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(cameraEditorBtn);

		// Add dropdowns in reverse vertical order so open menus draw on top!
		tab_group_song.add(assetModifierDropDown);
		tab_group_song.add(gfDropDown);
		tab_group_song.add(stageDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(player2DropDown);

		UI_box.addGroup(tab_group_song);
		UI_box.scrollFactor.set();

		FlxG.camera.follow(strumLine);
	}

	var stepperLength:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = _song.notes[curSection].lengthInSteps;
		stepperLength.name = "section_length";

		stepperSectionBPM = new FlxUINumericStepper(10, 80, 1, Conductor.bpm, 0, 999, 0);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';

		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 130, 1, 1, -999, 999, 0);

		var copyButton:FlxButton = new FlxButton(10, 130, "Copy last section", function()
		{
			copySection(Std.int(stepperCopy.value));
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 150, "Clear", clearSection);

		var swapSection:FlxButton = new FlxButton(10, 170, "Swap section", function()
		{
			var notesToSwap = _song.notes[curSection].sectionNotes.copy();
			for (i in 0...notesToSwap.length)
			{
				var noteInfo = notesToSwap[i];
				var strum = noteInfo[0];
				var data = noteInfo[1];
				var sus = noteInfo[2];
				var type = (noteInfo.length > 3) ? noteInfo[3] : 0;
				
				var oldMustPress = (data > 3);
				var oldBaseData = data % 4;
				
				var oldNotes = [];
				for (n in curRenderedNotes.members) {
					if (n != null && n.alive && Math.abs(n.strumTime - strum) < 1 && n.noteData == oldBaseData && n.mustPress == oldMustPress) oldNotes.push(n);
				}
				for (n in oldNotes) {
					curRenderedNotes.remove(n, true);
					n.destroy();
				}
				
				var oldSustains = [];
				for (s in curRenderedSustains.members) {
					if (s != null && s.alive) {
						var isMatchData = (s.noteData == oldBaseData && s.mustPress == oldMustPress);
						var isMatchTime = (s.strumTime > strum - 10 && s.strumTime <= strum + sus + 10);
						if (isMatchData && isMatchTime) oldSustains.push(s);
					}
				}
				for (s in oldSustains) {
					curRenderedSustains.remove(s, true);
					s.destroy();
				}
				
				var newData = (data + 4) % 8;
				_song.notes[curSection].sectionNotes[i][1] = newData;
				
				curSelectedNote = _song.notes[curSection].sectionNotes[i];
				var n:Note = FunkinArrows.generateArrow(PlayState.assetModifier, strum, newData % 4, type, 0);
				n.sustainLength = sus;
				n.noteType = type;
				n.setGraphicSize(GRID_SIZE, GRID_SIZE);
				n.updateHitbox();
				n.x = Math.floor(newData * GRID_SIZE) + gridBG.x;
				n.y = Math.floor(getYfromStrum(strum) - (GRID_SIZE / 2));
				n.mustPress = (newData > 3);
				curRenderedNotes.add(n);
				
				if (n.sustainLength > 0) updateGridForCurrentNote();
			}
		});

		var btnSectionCamEditor:FlxButton = new FlxButton(10, 30, "Camera Editor", function()
		{
			PlayState.SONG = _song;
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new editors.CameraEditor());
		});

		var txtCamInfo:FlxText = new FlxText(100, 34, 180, "Camera: Events", 8);
		txtCamInfo.color = 0xFFAAAAAA;

		check_altAnim = new FlxUICheckBox(10, 400, null, null, "Alt Animation", 100);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 60, null, null, 'Change BPM', 100);
		check_changeBPM.name = 'check_changeBPM';

		tab_group_section.add(stepperLength);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(btnSectionCamEditor);
		tab_group_section.add(txtCamInfo);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(swapSection);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var noteSkinDropdown:FlxUIDropDownMenu;
	var curNoteSkin:String = 'default';
	var lastDummySkin:String = '';

	var eventDropdown:FlxUIDropDownMenu;
	var eventVal1:FlxInputText;
	var eventVal2:FlxInputText;
	var eventSkinDropdown:FlxUIDropDownMenu;
	var eventDescText:FlxText;
	var eventsOptions:Array<String> = ['FocusCamera', 'ZoomCamera', 'Change Scroll Speed', 'Change Character', 'Cam Pos To', 'Change Note Skins', 'Play Anim', 'Add Cam Zoom', 'playVideo'];

	function updateEventDesc():Void
	{
		if (eventDescText == null) return;
		var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
		switch (evName)
		{
			case 'FocusCamera':
				eventDescText.text = "Val 1: Target (0=BF, 1=Dad, 2=GF), x, y\nVal 2: duration (steps), ease (CLASSIC, linear...)";
			case 'ZoomCamera':
				eventDescText.text = "Val 1: Zoom value (e.g. 1.05)\nVal 2: duration (steps), ease";
			case 'Change Character':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/gf), x, y\nVal 2: Character JSON";
			case 'Change Scroll Speed':
				eventDescText.text = "Val 1: Speed number (or reset)\nVal 2: steps, ease";
			case 'Cam Pos To':
				eventDescText.text = "Val 1: x, y (blank to reset)\nVal 2: steps, ease";
			case 'Change Note Skins':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/ambos)\nVal 2: Note Skin";
			case 'Play Anim':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/gf)\nVal 2: anim, lock (optional), ignoreArrows (optional)";
			case 'Add Cam Zoom' | 'Add Camera Zoom':
				eventDescText.text = "Val 1: Cam zoom (default: 0.015)\nVal 2: HUD zoom (default: 0.03)";
			case 'playVideo' | 'Play Video':
				eventDescText.text = "Val 1: Video name (in videos/)\nVal 2: true (screenCenter), scale";
			default:
				eventDescText.text = "";
		}
	}

	function updateEventValueFields():Void
	{
		var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
		var isSkinEvent:Bool = (evName == 'Change Note Skins');
		if (eventVal2 != null) eventVal2.visible = !isSkinEvent;
		if (eventSkinDropdown != null)
		{
			eventSkinDropdown.visible = isSkinEvent;
			if (isSkinEvent)
			{
				var skinList = FunkinArrows.getAvailableNoteSkins();
				var curVal:String = (eventVal2 != null && eventVal2.text != null && eventVal2.text.length > 0) ? eventVal2.text.trim() : 'default';
				var idx = skinList.indexOf(curVal);
				if (idx < 0) idx = 0;
				eventSkinDropdown.selectedLabel = skinList[idx];
				eventSkinDropdown.selectedId = Std.string(idx);
			}
		}
	}

	function applySelectedEvent():Void
	{
		if (curSelectedEvent != null && curSelectedEvent[1] != null && curSelectedEvent[1].length > 0)
		{
			var selectedIdx = Std.parseInt(eventDropdown.selectedId);
			var selectedEvent = (selectedIdx >= 0 && selectedIdx < eventsOptions.length) ? eventsOptions[selectedIdx] : eventDropdown.selectedLabel;
			if (selectedEvent == 'Change Note Skins' && eventSkinDropdown != null && eventSkinDropdown.visible)
			{
				eventVal2.text = eventSkinDropdown.selectedLabel;
			}
			curSelectedEvent[1][0][0] = selectedEvent;
			curSelectedEvent[1][0][1] = eventVal1.text;
			curSelectedEvent[1][0][2] = eventVal2.text;
		}
	}

	function addEventUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		eventDropdown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray(eventsOptions, true), function(event:String)
		{
			var selectedIndex:Int = Std.parseInt(event);
			if (selectedIndex >= 0 && selectedIndex < eventsOptions.length) {
				eventDropdown.selectedLabel = eventsOptions[selectedIndex];
				eventDropdown.selectedId = Std.string(selectedIndex);
				updateEventDesc();
				updateEventValueFields();
				applySelectedEvent();
			}
		});
		eventDropdown.selectedLabel = eventsOptions[0];
		eventDropdown.selectedId = "0";

		var val1Label = new FlxText(10, 60, 0, "Value 1:");
		eventVal1 = new FlxInputText(10, 75, 140, "");

		var val2Label = new FlxText(10, 100, 0, "Value 2:");
		eventVal2 = new FlxInputText(10, 115, 140, "");

		var skinList = FunkinArrows.getAvailableNoteSkins(true);
		eventSkinDropdown = new FlxUIDropDownMenu(10, 115, FlxUIDropDownMenu.makeStrIdLabelArray(skinList, true), function(selectedId:String)
		{
			var idx = Std.parseInt(selectedId);
			if (idx >= 0 && idx < skinList.length)
			{
				eventSkinDropdown.selectedLabel = skinList[idx];
				eventSkinDropdown.selectedId = Std.string(idx);
				eventVal2.text = skinList[idx];
				applySelectedEvent();
			}
		});
		eventSkinDropdown.selectedLabel = skinList[0];
		eventSkinDropdown.selectedId = "0";
		eventSkinDropdown.visible = false;

		eventDescText = new FlxText(10, 142, 160, "");
		eventDescText.setFormat(null, 8, 0xFFAAAAAA);
		updateEventDesc();

		tab_group_event.add(new FlxText(10, 10, 0, "Event Type:"));
		tab_group_event.add(val1Label);
		tab_group_event.add(eventVal1);
		tab_group_event.add(val2Label);
		tab_group_event.add(eventVal2);
		tab_group_event.add(eventSkinDropdown);
		tab_group_event.add(eventDescText);
		tab_group_event.add(eventDropdown);

		UI_box.addGroup(tab_group_event);
		updateEventValueFields();
	}

	function updateDummyArrows():Void
	{
		if (dummyArrows == null || dummyArrows.length < 9) return;
		for (i in 0...9)
		{
			var oldArrow = dummyArrows[i];
			if (oldArrow != null)
			{
				var oldIndex = members.indexOf(oldArrow);
				if (oldIndex < 0) oldIndex = members.indexOf(strumLine) + 1;

				remove(oldArrow, true);
				oldArrow.destroy();

				var newArrow:FlxSprite;
				if (i == 8)
				{
					newArrow = new FlxSprite().loadGraphic(Paths.image('menus/editors/chart/event_icon'));
				}
				else
				{
					newArrow = FunkinArrows.generateArrow(PlayState.assetModifier, 0, i % 4, curNoteSkin, 0);
				}
				newArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
				newArrow.updateHitbox();
				newArrow.alpha = 0.6;
				newArrow.ID = i;
				newArrow.visible = false;

				insert(oldIndex, newArrow);
				dummyArrows[i] = newArrow;
			}
		}
		lastDummySkin = curNoteSkin;
		lastDummyData = -1;
	}

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		var susLabel = new FlxText(10, 10, 0, 'Sustain Length:');
		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 16);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		var applyLength:FlxButton = new FlxButton(100, 25, 'Apply');

		tab_group_note.add(susLabel);
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(applyLength);

		var skinLabel = new FlxText(10, 55, 0, 'Note Skin / Type:');
		tab_group_note.add(skinLabel);

		var skinList = FunkinArrows.getAvailableNoteSkins(true);
		noteSkinDropdown = new FlxUIDropDownMenu(10, 70, FlxUIDropDownMenu.makeStrIdLabelArray(skinList, true), function(selectedId:String)
		{
			var idx = Std.parseInt(selectedId);
			if (idx >= 0 && idx < skinList.length)
			{
				curNoteSkin = skinList[idx];
				noteSkinDropdown.selectedLabel = curNoteSkin;
				noteSkinDropdown.selectedId = Std.string(idx);
				if (curSelectedNote != null)
				{
					curSelectedNote[3] = curNoteSkin;
					updateGrid();
				}
				updateDummyArrows();
			}
		});
		noteSkinDropdown.selectedLabel = curNoteSkin;
		var defaultIdx = skinList.indexOf(curNoteSkin);
		noteSkinDropdown.selectedId = Std.string(defaultIdx >= 0 ? defaultIdx : 0);

		tab_group_note.add(noteSkinDropdown);

		UI_box.addGroup(tab_group_note);
	}

	var songMusic:FlxSound;

	function loadSong(daSong:String):Void
	{
		if (songMusic != null)
			songMusic.stop();

		if (vocals != null)
			vocals.stop();

		if (opponentVocals != null)
			opponentVocals.stop();

		songMusic = new FlxSound().load(Paths.inst(daSong));
		songMusic.autoDestroy = false;

		vocals = new FlxSound();
		vocals.autoDestroy = false;

		opponentVocals = new FlxSound();
		opponentVocals.autoDestroy = false;

		if (_song.needsVoices)
		{
			var p1Suffix:String = (_song.player1 != null && _song.player1.length > 0 && _song.player1 != 'bf') ? _song.player1 : 'bf';
			var p2Suffix:String = (_song.player2 != null && _song.player2.length > 0 && _song.player2 != 'dad') ? _song.player2 : 'dad';

			var playerSound:openfl.media.Sound = Paths.voices(daSong, p1Suffix);
			if (playerSound == null && p1Suffix != 'bf')
				playerSound = Paths.voices(daSong, 'bf');

			var oppSound:openfl.media.Sound = Paths.voices(daSong, p2Suffix);
			if (oppSound == null && p2Suffix != 'dad')
				oppSound = Paths.voices(daSong, 'dad');

			if (playerSound != null)
				vocals.load(playerSound);

			if (oppSound != null)
				opponentVocals.load(oppSound);

			if (playerSound == null && oppSound == null)
			{
				var defaultVoice:openfl.media.Sound = Paths.voices(daSong);
				if (defaultVoice != null)
					vocals.load(defaultVoice);
			}
			else if (playerSound == null)
			{
				var defaultVoice:openfl.media.Sound = Paths.voices(daSong);
				if (defaultVoice != null)
					vocals.load(defaultVoice);
			}
		}

		FlxG.sound.list.add(songMusic);
		if (vocals != null && vocals.exists && vocals.length > 0) FlxG.sound.list.add(vocals);
		if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0) FlxG.sound.list.add(opponentVocals);

		songMusic.play();
		if (vocals != null && vocals.exists && vocals.length > 0) vocals.play();
		if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0) opponentVocals.play();

		pauseMusic();

		songMusic.onComplete = function()
		{
			Utils.killMusic([songMusic, vocals, opponentVocals]);
			loadSong(daSong);
			changeSection();
		};
	}

	function pauseMusic()
	{
		songMusic.time = Math.max(songMusic.time, 0);
		songMusic.time = Math.min(songMusic.time, songMusic.length);

		songMusic.pause();
		if (vocals != null) vocals.pause();
		if (opponentVocals != null) opponentVocals.pause();
	}

	function generateUI():Void
	{
		bullshitUI.clear();

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSection].mustHitSection = check.checked;

				case 'Change BPM':
					_song.notes[curSection].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSection].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			switch (wname)
			{
				case 'section_length':
					_song.notes[curSection].lengthInSteps = Std.int(nums.value); // change length
					updateGrid(); // vrrrrmmm
				case 'song_speed':
					_song.speed = nums.value; // change the song speed
					_song.defaultSpeed = nums.value;
				case 'song_bpm':
					tempBpm = Std.int(nums.value);
					Conductor.mapBPMChanges(_song);
					Conductor.changeBPM(Std.int(nums.value));
				case 'note_susLength': // STOP POSTING ABOUT AMONG US
					curSelectedNote[2] = nums.value; // change the currently selected note's length
					updateGrid(); // oh btw I know sus stands for sustain it just bothers me
				case 'note_type':
					curNoteType = Std.int(nums.value); // oh yeah dont forget this has to be an integer
				// set the new note type for when placing notes next!
				case 'section_bpm':
					_song.notes[curSection].bpm = Std.int(nums.value); // redefine the section's bpm
					updateGrid(); // update the note grid
			}
		}
		else if (id == FlxUITabMenu.CLICK_EVENT)
		{
			var tabName:String = Std.string(data);
			if (tabName == 'Events')
			{
				updateEventDesc();
				updateEventValueFields();
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	/* this function got owned LOL
		function lengthBpmBullshit():Float
		{
			if (_song.notes[curSection].changeBPM)
				return _song.notes[curSection].lengthInSteps * (_song.notes[curSection].bpm / _song.bpm);
			else
				return _song.notes[curSection].lengthInSteps;
	}*/
	function sectionStartTime():Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSection)
		{
			if (_song.notes[i].changeBPM)
			{
				daBPM = _song.notes[i].bpm;
			}
			daPos += ((60 / daBPM) * 1000 / 4) * _song.notes[i].lengthInSteps;
		}
		return daPos;
	}

	var lastSongPos:Null<Float> = null;

	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if (songMusic.time < 0) songMusic.time = 0;
		Conductor.songPosition = songMusic.time;
		_song.song = typingShit.text;

		if (songMusic != null && songMusic.playing) {
			bgPulse = flixel.math.FlxMath.lerp(bgPulse, 0, 0.1);
			
			bgGradient.alpha = flixel.math.FlxMath.lerp(bgGradient.alpha, 0.2 + (bgPulse * 0.6), 0.5);
			if (bgGradient.alpha > 0.8) bgGradient.alpha = 0.8;
		} else {
			bgPulse = 0;
			bgGradient.alpha = flixel.math.FlxMath.lerp(bgGradient.alpha, 0.2, 0.1);
		}

		// real thanks for the help with this ShadowMario, you are the best -Ghost
		for (i in 0...8)
		{
			playedSound[i] = false;
		}
		strumLine.y = getYfromStrum(Conductor.songPosition);

		var camY = strumLine.y - (FlxG.height / 2);
		var camHeight = FlxG.height;
		var cullMargin = 500; // pixels to render above and below camera bounds

		for (note in curRenderedNotes.members)
		{
			if (note != null && note.alive)
			{
				// Render culling to massively boost FPS
				if (note.y > camY - cullMargin && note.y < camY + camHeight + cullMargin)
				{
					note.visible = true;
					note.active = true;
				}
				else
				{
					note.visible = false;
					note.active = false;
				}

				if (note.strumTime < songMusic.time)
				{
					var data:Int = (note.noteData % 4) + (note.mustPress ? 4 : 0);

					if (songMusic.playing && !playedSound[data] && note.noteData > -1 && note.strumTime >= lastSongPos)
					{
						var soundPlayed = false;
						if (playTicksBf.checked && note.mustPress)
						{
							FlxG.sound.play(Paths.sound('system/chart/hitPlayer'));
							soundPlayed = true;
						}
						else if (playTicksDad.checked && !note.mustPress)
						{
							FlxG.sound.play(Paths.sound('system/chart/hitOpp'));
							soundPlayed = true;
						}
						
						if (soundPlayed)
						{
							playedSound[data] = true;
							bgPulse = 1.0;
						}
					}
				}
			}
		}

		for (note in curRenderedSustains.members)
		{
			if (note != null && note.alive)
			{
				if (note.y + note.height > camY - cullMargin && note.y < camY + camHeight + cullMargin)
				{
					note.visible = true;
					note.active = true;
				}
				else
				{
					note.visible = false;
					note.active = false;
				}
			}
		}

		var expectedSection = getSectionFromStrumTime(Conductor.songPosition);
		if (expectedSection < 0) expectedSection = 0;
		if (expectedSection != curSection)
		{
			if (expectedSection >= _song.notes.length)
			{
				while (_song.notes.length <= expectedSection)
					addSection();
			}
			changeSection(expectedSection, false);
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		// RIGHT CLICK - DELETE
		if (FlxG.mouse.justPressedRight)
		{
			var eventToDelete:FlxSprite = null;
			if (FlxG.mouse.overlaps(curRenderedEvents)) {
				curRenderedEvents.forEach(function(ev:FlxSprite) {
					if (FlxG.mouse.overlaps(ev)) {
						eventToDelete = ev;
					}
				});
			}

			if (eventToDelete != null) {
				var evStrum = getStrumTime(eventToDelete.y);
				if (_song.events != null) {
					for (i in 0..._song.events.length) {
						if (Math.abs(_song.events[i][0] - evStrum) < 5) {
							if (curSelectedEvent == _song.events[i]) curSelectedEvent = null;
							_song.events.remove(_song.events[i]);
							break;
						}
					}
				}
				pulsingNote = null;
				pulsingEvent = null;
				updateGrid();
			}
			else if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				var noteToDelete:Note = null;
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						noteToDelete = note;
					}
				});

				if (noteToDelete != null)
				{
					if (curSelectedNote != null && Math.abs(curSelectedNote[0] - noteToDelete.strumTime) < 1 && curSelectedNote[1] % 4 == noteToDelete.noteData)
						curSelectedNote = null;

					pulsingNote = null;
					pulsingEvent = null;

					deleteNote(noteToDelete);
					
					// Remove visual sustains of the deleted note
					var oldSustains = [];
					for (s in curRenderedSustains.members) {
						if (s != null && s.alive) {
							var isMatchData = (s.noteData == noteToDelete.noteData % 4 && s.mustPress == noteToDelete.mustPress);
							var isMatchTime = (s.strumTime > noteToDelete.strumTime - 10 && s.strumTime <= noteToDelete.strumTime + noteToDelete.sustainLength + 10);
							if (isMatchData && isMatchTime) {
								oldSustains.push(s);
							}
						}
					}
					for (s in oldSustains) {
						curRenderedSustains.remove(s, true);
						s.destroy();
					}
					
					curRenderedNotes.remove(noteToDelete, true);
					noteToDelete.destroy();
				}
			}
		}

		// LEFT CLICK - SELECT OR ADD
		if (FlxG.mouse.justPressed)
		{
			var eventToSelect:FlxSprite = null;
			if (FlxG.mouse.overlaps(curRenderedEvents)) {
				curRenderedEvents.forEach(function(ev:FlxSprite) {
					if (FlxG.mouse.overlaps(ev)) {
						eventToSelect = ev;
					}
				});
			}

			if (eventToSelect != null) {
				var evStrum = getStrumTime(eventToSelect.y);
				if (_song.events != null) {
					for (i in 0..._song.events.length) {
						if (Math.abs(_song.events[i][0] - evStrum) < 5) {
							curSelectedEvent = _song.events[i];
							curSelectedNote = null;
							pulsingEvent = curSelectedEvent;
							pulsingNote = null;
							
							// Update UI
							UI_box.selected_tab_id = 'Events';
							if (curSelectedEvent[1] != null && curSelectedEvent[1].length > 0) {
								var evData = curSelectedEvent[1][0]; // Take the first event at this time
								var evName:String = evData[0];
								eventVal1.text = evData[1];
								eventVal2.text = evData[2];
								
								var normEv:String = evName != null ? StringTools.replace(evName.toLowerCase(), " ", "") : "";
								for (optIdx in 0...eventsOptions.length) {
									var opt:String = eventsOptions[optIdx];
									if (opt == evName || StringTools.replace(opt.toLowerCase(), " ", "") == normEv) {
										eventDropdown.selectedLabel = opt;
										eventDropdown.selectedId = Std.string(optIdx);
										break;
									}
								}
								updateEventDesc();
								updateEventValueFields();
							}
							break;
						}
					}
				}
			}
			else if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				var noteToSelect:Note = null;
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						noteToSelect = note;
					}
				});

				if (noteToSelect != null)
				{
					selectNote(noteToSelect);
					curSelectedEvent = null;
					pulsingNote = curSelectedNote;
					pulsingEvent = null;
				}
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + (GRID_SIZE * 9))
				{
					if (addNote()) {
						isDraggingSustain = true;
					}
				}
			}
		}

		if (grabbedNoteProxy != null) {
			if (FlxG.mouse.pressed) {
				var dist = dragStartPos.distanceTo(flixel.math.FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y));
				if (dist > 5) isDraggingNote = true;
				
				if (isDraggingNote) {
					grabbedNoteProxy.x = flixel.math.FlxMath.lerp(grabbedNoteProxy.x, FlxG.mouse.x - GRID_SIZE/2, 0.4);
					grabbedNoteProxy.y = flixel.math.FlxMath.lerp(grabbedNoteProxy.y, FlxG.mouse.y - GRID_SIZE/2, 0.4);
					changeCursor('cursor-grabbing');
				}
			}
			if (FlxG.mouse.justReleased) {
				if (isDraggingNote) {
					if (FlxG.mouse.x > gridBG.x && FlxG.mouse.x < gridBG.x + (GRID_SIZE * 9)) {
						var newData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);
						var newStrum = getStrumTime(FlxG.mouse.y);
						if (newStrum >= 0) {
							var targetSection = getSectionFromStrumTime(newStrum);
							while (_song.notes.length <= targetSection) { addSection(); }
							
							_song.notes[targetSection].sectionNotes.push([newStrum, newData, grabbedNoteData[2], grabbedNoteData[3]]);
							FlxG.sound.play(Paths.sound('system/chart/grab/stretchSNAP_UI'));
							
							curSelectedNote = _song.notes[targetSection].sectionNotes[_song.notes[targetSection].sectionNotes.length - 1];
							
							var n:Note = FunkinArrows.generateArrow(PlayState.assetModifier, newStrum, newData % 4, grabbedNoteData[3], 0);
							n.sustainLength = grabbedNoteData[2];
							n.noteType = grabbedNoteData[3];
							n.setGraphicSize(GRID_SIZE, GRID_SIZE);
							n.updateHitbox();
							n.x = Math.floor(newData * GRID_SIZE) + gridBG.x;
							n.y = Math.floor(getYfromStrum(newStrum) - (GRID_SIZE / 2));
							n.mustPress = (newData > 3);
							curRenderedNotes.add(n);
							
							if (n.sustainLength > 0) updateGridForCurrentNote();
						}
					}
				} else {
					FlxG.sound.play(Paths.sound('system/chart/noteErase'));
				}
				
				remove(grabbedNoteProxy, true);
				grabbedNoteProxy.destroy();
				grabbedNoteProxy = null;
				grabbedNoteData = null;
			}
		}

		if (isDraggingSustain) {
			if (FlxG.mouse.pressed && curSelectedNote != null) {
				changeCursor('cursor-scroll');
				var currentStrum = getStrumTime(FlxG.mouse.y);
				var newSus = Math.max(0, currentStrum - curSelectedNote[0]);
				var noteStepCrochet = getStepCrochetAtTime(curSelectedNote[0]);
				newSus = Math.round(newSus / noteStepCrochet) * noteStepCrochet;
				
				if (curSelectedNote[2] != newSus) {
					curSelectedNote[2] = newSus;
					updateGridForCurrentNote();
					FlxG.sound.play(Paths.sound('system/chart/grab/stretch1_UI'), 0.5);
				}
			} else if (FlxG.mouse.justReleased) {
				isDraggingSustain = false;
			}
		}

		if (!isDraggingNote && !isDraggingSustain) {
			if (FlxG.mouse.x > gridBG.x && FlxG.mouse.x < gridBG.x + (GRID_SIZE * 9)) {
				if (getStrumTime(FlxG.mouse.y) < 0) {
					changeCursor('cursor-cross');
				} else {
					changeCursor('cursor-pointer');
				}
			} else {
				changeCursor('cursor-default');
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + (GRID_SIZE * 9))
		{
			var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);
			
			// Only recreate graphics if the user changed the note type in the UI
			if (curNoteSkin != lastDummySkin)
			{
				updateDummyArrows();
			}

			if (noteData != lastDummyData)
			{
				if (lastDummyData >= 0 && lastDummyData < 9) dummyArrows[lastDummyData].visible = false;
				dummyArrow = dummyArrows[noteData];
				dummyArrow.visible = true;
				lastDummyData = noteData;
			}

			dummyArrow.x = Math.floor(noteData * GRID_SIZE) + gridBG.x;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
				dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
		}
		else
		{
			if (dummyArrow != null) dummyArrow.visible = false;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			lastSection = curSection;

			PlayState.SONG = _song;
			songMusic.stop();
			vocals.stop();
			if (opponentVocals != null)
				opponentVocals.stop();
			FlxG.mouse.unload();
			Main.switchState(this, new PlayState());
		}

		if (FlxG.keys.justPressed.E)
		{
			changeNoteSustain(Conductor.stepCrochet);
		}
		if (FlxG.keys.justPressed.Q)
		{
			changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FlxG.keys.justPressed.TAB)
		{
			if (FlxG.keys.pressed.SHIFT)
			{
				UI_box.selected_tab -= 1;
				if (UI_box.selected_tab < 0)
					UI_box.selected_tab = 3;
			}
			else
			{
				UI_box.selected_tab += 1;
				if (UI_box.selected_tab >= 4)
					UI_box.selected_tab = 0;
			}
			if (UI_box.selected_tab_id == 'Events')
			{
				updateEventDesc();
				updateEventValueFields();
			}
		}

		if (UI_box != null)
		{
			if (UI_box.selected_tab_id == 'Events')
			{
				var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
				var isSkinEvent:Bool = (evName == 'Change Note Skins');
				if (eventVal2 != null && eventVal2.visible == isSkinEvent)
					eventVal2.visible = !isSkinEvent;
				if (eventSkinDropdown != null && eventSkinDropdown.visible != isSkinEvent)
					eventSkinDropdown.visible = isSkinEvent;
			}
			else
			{
				if (eventSkinDropdown != null && eventSkinDropdown.visible)
					eventSkinDropdown.visible = false;
			}
		}

		if (curSelectedEvent != null && ((eventVal1 != null && eventVal1.hasFocus) || (eventVal2 != null && eventVal2.hasFocus)))
		{
			applySelectedEvent();
		}

		var isTyping:Bool = (typingShit != null && typingShit.hasFocus) || (eventVal1 != null && eventVal1.hasFocus) || (eventVal2 != null && eventVal2.hasFocus);
		if (!isTyping)
		{
			if (FlxG.keys.justPressed.SPACE)
			{
				if (songMusic.playing)
				{
					songMusic.pause();
					if (vocals != null) vocals.pause();
					if (opponentVocals != null) opponentVocals.pause();
				}
				else
				{
					if (vocals != null && vocals.exists && vocals.length > 0) vocals.play();
					if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0) opponentVocals.play();
					songMusic.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				songMusic.pause();
				if (vocals != null) vocals.pause();
				if (opponentVocals != null) opponentVocals.pause();

				songMusic.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.4);
				if (vocals != null) vocals.time = songMusic.time;
				if (opponentVocals != null) opponentVocals.time = songMusic.time;
			}

			if (!FlxG.keys.pressed.SHIFT)
			{
				if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
				{
					songMusic.pause();
					if (vocals != null) vocals.pause();
					if (opponentVocals != null) opponentVocals.pause();

					var daTime:Float = 700 * FlxG.elapsed;

					if (FlxG.keys.pressed.W)
					{
						songMusic.time -= daTime;
					}
					else
						songMusic.time += daTime;

					if (vocals != null) vocals.time = songMusic.time;
					if (opponentVocals != null) opponentVocals.time = songMusic.time;
				}
			}
			else
			{
				if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S)
				{
					songMusic.pause();
					if (vocals != null) vocals.pause();
					if (opponentVocals != null) opponentVocals.pause();

					var daTime:Float = Conductor.stepCrochet * 2;

					if (FlxG.keys.justPressed.W)
					{
						songMusic.time -= daTime;
					}
					else
						songMusic.time += daTime;

					if (vocals != null) vocals.time = songMusic.time;
					if (opponentVocals != null) opponentVocals.time = songMusic.time;
				}
			}
		}

		_song.bpm = tempBpm;

		/* if (FlxG.keys.justPressed.UP)
				Conductor.changeBPM(Conductor.bpm + 1);
			if (FlxG.keys.justPressed.DOWN)
				Conductor.changeBPM(Conductor.bpm - 1); */

		var shiftThing:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftThing = 4;
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
			changeSection(curSection + shiftThing);
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
			changeSection(curSection - shiftThing);

		bpmTxt.text = bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(songMusic.length / 1000, 2))
			+ "\nSection: "
			+ curSection
			+ "\nBeat: "
			+ curBeat
			+ "\nStep: "
			+ curStep;
		var pulseAlpha:Float = 0.4 + 0.6 * Math.sin(flixel.FlxG.game.ticks / 100);

		curRenderedNotes.forEachAlive(function(n:Note) {
			if (pulsingNote != null && Math.abs(n.strumTime - pulsingNote[0]) < 1 && n.noteData == pulsingNote[1] % 4 && n.mustPress == (pulsingNote[1] > 3)) {
				n.alpha = pulseAlpha;
			} else {
				n.alpha = 1;
			}
		});

		curRenderedEvents.forEachAlive(function(ev:FlxSprite) {
			if (pulsingEvent != null && Math.abs(getStrumTime(ev.y) - pulsingEvent[0]) < 5) {
				ev.alpha = pulseAlpha;
			} else {
				ev.alpha = 1;
			}
		});

		super.update(elapsed);

		lastSongPos = Conductor.songPosition;
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGridForCurrentNote();
	}

	function updateGridForCurrentNote():Void
	{
		if (curSelectedNote == null) return;
		var strum:Float = curSelectedNote[0];
		var data:Int = curSelectedNote[1];
		var sus:Float = curSelectedNote[2];
		var type:Int = (curSelectedNote.length > 3) ? curSelectedNote[3] : 0;

		var headNote:Note = null;
		curRenderedNotes.forEachAlive(function(n:Note) {
			if (Math.abs(n.strumTime - strum) < 1 && n.noteData == data % 4 && n.mustPress == (data > 3)) {
				headNote = n;
			}
		});

		if (headNote == null) return;
		
		headNote.sustainLength = sus;

		var toDelete = [];
		curRenderedSustains.forEachAlive(function(susNote:Note) {
			var p = susNote.prevNote;
			while (p != null && p.isSustainNote) p = p.prevNote;
			if (p == headNote) toDelete.push(susNote);
		});
		for (n in toDelete) {
			curRenderedSustains.remove(n, true);
			n.destroy();
		}

		if (sus > 0)
		{
			var noteStepCrochet = getStepCrochetAtTime(strum);
			var stepSusLength:Int = Std.int(sus / noteStepCrochet);
			var oldNote:Note = headNote;
			
			if (stepSusLength > 0)
			{
				var susNotes:Array<Note> = [];
				for (susIdx in 0...stepSusLength)
				{
					var sustainTime:Float = strum + (noteStepCrochet * susIdx) + noteStepCrochet;
					var sustainNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, sustainTime, data % 4, type, 0, true, oldNote);
					sustainNote.mustPress = (data > 3);
					susNotes.push(sustainNote);
					oldNote = sustainNote;
				}
				
				for (sustainNote in susNotes)
				{
					sustainNote.y = Math.floor(getYfromStrum(sustainNote.strumTime));
					sustainNote.scale.set(1, 1);
					sustainNote.updateHitbox();
					
					if (sustainNote.animation.curAnim != null && sustainNote.animation.curAnim.name.endsWith('end'))
					{
						sustainNote.setGraphicSize(Std.int(GRID_SIZE * 0.35));
					}
					else
					{
						sustainNote.setGraphicSize(Std.int(GRID_SIZE * 0.35), GRID_SIZE + 1);
					}
					sustainNote.updateHitbox();
					sustainNote.x = Math.floor(data * GRID_SIZE) + (GRID_SIZE / 2) - (sustainNote.width / 2);
					
					curRenderedSustains.add(sustainNote);
				}
			}
		}
	}

	function recalculateSteps():Int
	{
		curDecStep = Conductor.calculateDecStep(songMusic.time);
		curStep = Math.floor(curDecStep);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		songMusic.pause();
		if (vocals != null) vocals.pause();
		if (opponentVocals != null) opponentVocals.pause();

		// Basically old shit from changeSection???
		songMusic.time = sectionStartTime();

		if (songBeginning)
		{
			songMusic.time = 0;
			curSection = 0;
		}

		if (vocals != null) vocals.time = songMusic.time;
		if (opponentVocals != null) opponentVocals.time = songMusic.time;
		updateCurStep();

		updateSectionUI();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		//trace('changing section' + sec);

		if (_song.notes[sec] != null)
		{
			curSection = sec;

			if (updateMusic)
			{
				songMusic.pause();
				if (vocals != null) vocals.pause();
				if (opponentVocals != null) opponentVocals.pause();

				songMusic.time = sectionStartTime();
				if (vocals != null) vocals.time = songMusic.time;
				if (opponentVocals != null) opponentVocals.time = songMusic.time;
				updateCurStep();
			}

			updateSectionUI();
		}
	}

	function copySection(?sectionNum:Int = 1)
	{
		var daSec = FlxMath.maxInt(curSection, sectionNum);

		for (note in _song.notes[daSec - sectionNum].sectionNotes)
		{
			var strum = note[0] + Conductor.stepCrochet * (_song.notes[daSec].lengthInSteps * sectionNum);

			var copiedNote:Array<Dynamic> = [strum, note[1], note[2]];
			_song.notes[daSec].sectionNotes.push(copiedNote);
		}

		updateGrid();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSection];

		stepperLength.value = sec.lengthInSteps;
		if (check_mustHitSection != null)
			check_mustHitSection.checked = sec.mustHitSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null)
		{
			stepperSusLength.value = curSelectedNote[2];
			var noteTypeVal:Dynamic = (curSelectedNote.length > 3) ? curSelectedNote[3] : 'default';
			var skinName:String = FunkinArrows.getSkinFromType(noteTypeVal);
			curNoteSkin = skinName;
			if (noteSkinDropdown != null)
			{
				var skinList = FunkinArrows.getAvailableNoteSkins();
				var idx = skinList.indexOf(skinName);
				if (idx < 0) idx = 0;
				noteSkinDropdown.selectedLabel = skinList[idx];
				noteSkinDropdown.selectedId = Std.string(idx);
			}
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEachAlive(function(n) n.destroy());
		curRenderedNotes.clear();

		curRenderedSustains.forEachAlive(function(n) n.destroy());
		curRenderedSustains.clear();

		curRenderedEvents.forEachAlive(function(e) e.destroy());
		curRenderedEvents.clear();

		if (_song.events != null)
		{
			for (e in _song.events)
			{
				var evSprite = new FlxSprite();
				evSprite.loadGraphic(Paths.image('menus/editors/chart/event_icon'));
				evSprite.setGraphicSize(GRID_SIZE, GRID_SIZE);
				evSprite.updateHitbox();
				evSprite.x = gridBG.x + (GRID_SIZE * 8);
				evSprite.y = Math.floor(getYfromStrum(e[0]));
				curRenderedEvents.add(evSprite);
			}
		}

		if (_song.notes[curSection].changeBPM && _song.notes[curSection].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSection].bpm);
			FlxG.log.add('CHANGED BPM!');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSection)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		for (sec in 0..._song.notes.length)
		{
			var sectionInfo:Array<Dynamic> = _song.notes[sec].sectionNotes;
			for (i in sectionInfo)
			{
			var daNoteInfo = i[1];
			var daStrumTime = i[0];
			var daSus = i[2];
			var daNoteType:Dynamic = 'default';

			if (i.length > 3 && i[3] != null)
				daNoteType = i[3];

			var note:Note = FunkinArrows.generateArrow(PlayState.assetModifier, daStrumTime, daNoteInfo % 4, daNoteType, 0);
			note.sustainLength = daSus;
			note.noteType = daNoteType;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.x = Math.floor(daNoteInfo * GRID_SIZE);
			note.y = Math.floor(getYfromStrum(daStrumTime));
			note.mustPress = (i[1] > 3);

			curRenderedNotes.add(note);

			if (daSus > 0)
			{
				var noteStepCrochet = getStepCrochetAtTime(daStrumTime);
				var stepSusLength:Int = Std.int(daSus / noteStepCrochet);
				var oldNote:Note = note;
				
				if (stepSusLength > 0)
				{
					var susNotes:Array<Note> = [];
					for (susNote in 0...stepSusLength)
					{
						var sustainTime:Float = daStrumTime + (noteStepCrochet * susNote) + noteStepCrochet;
						var sustainNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, sustainTime, daNoteInfo % 4, daNoteType, 0, true, oldNote);
						sustainNote.mustPress = (daNoteInfo > 3);
						susNotes.push(sustainNote);
						oldNote = sustainNote;
					}
					
					for (sustainNote in susNotes)
					{
						sustainNote.y = Math.floor(getYfromStrum(sustainNote.strumTime));
						
						sustainNote.scale.set(1, 1);
						sustainNote.updateHitbox();
						
						if (sustainNote.animation.curAnim != null && sustainNote.animation.curAnim.name.endsWith('end'))
						{
							sustainNote.setGraphicSize(Std.int(GRID_SIZE * 0.35));
						}
						else
						{
							sustainNote.setGraphicSize(Std.int(GRID_SIZE * 0.35), GRID_SIZE + 1);
						}
						sustainNote.updateHitbox();
						sustainNote.x = Math.floor(daNoteInfo * GRID_SIZE) + (GRID_SIZE / 2) - (sustainNote.width / 2);
						
						curRenderedSustains.add(sustainNote);
					}
				}
			}
		}
		}
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var swagNum:Int = 0;

		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i.strumTime == note.strumTime && i.noteData % 4 == note.noteData)
			{
				curSelectedNote = _song.notes[curSection].sectionNotes[swagNum];
			}

			swagNum += 1;
		}

		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		var data:Null<Int> = note.noteData;

		if (data > -1 && note.mustPress)
			data += 4;

		if (data > -1)
		{
			var found = false;
			for (sec in 0..._song.notes.length)
			{
				for (i in _song.notes[sec].sectionNotes)
				{
					if (Math.abs(i[0] - note.strumTime) < 1 && i[1] == data)
					{
						FlxG.log.add('FOUND EVIL NUMBER');
						_song.notes[sec].sectionNotes.remove(i);
						found = true;
						break;
					}
				}
				if (found) break;
			}
		}

		// Don't call updateGrid() here! It clears curRenderedNotes while we are inside curRenderedNotes.forEach().
		// We will set a flag or just wait for the next update.
	}

	function clearSection():Void
	{
		var notesToClear = _song.notes[curSection].sectionNotes.copy();
		for (i in 0...notesToClear.length)
		{
			var noteInfo = notesToClear[i];
			var strum = noteInfo[0];
			var data = noteInfo[1];
			var sus = noteInfo[2];
			var oldMustPress = (data > 3);
			var oldBaseData = data % 4;
			
			var oldNotes = [];
			for (n in curRenderedNotes.members) {
				if (n != null && n.alive && Math.abs(n.strumTime - strum) < 1 && n.noteData == oldBaseData && n.mustPress == oldMustPress) oldNotes.push(n);
			}
			for (n in oldNotes) {
				curRenderedNotes.remove(n, true);
				n.destroy();
			}
			
			var oldSustains = [];
			for (s in curRenderedSustains.members) {
				if (s != null && s.alive) {
					var isMatchData = (s.noteData == oldBaseData && s.mustPress == oldMustPress);
					var isMatchTime = (s.strumTime > strum - 10 && s.strumTime <= strum + sus + 10);
					if (isMatchData && isMatchTime) oldSustains.push(s);
				}
			}
			for (s in oldSustains) {
				curRenderedSustains.remove(s, true);
				s.destroy();
			}
		}
		
		_song.notes[curSection].sectionNotes = [];
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote():Bool
	{
		var noteStrum = getStrumTime(dummyArrow.y);
		if (noteStrum < 0) return false;
		
		pulsingNote = null;
		pulsingEvent = null;

		var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);

		if (noteData == 8) {
			if (_song.events == null) _song.events = [];
			var selectedEvent = eventsOptions[Std.parseInt(eventDropdown.selectedId)];
			var v2 = (selectedEvent == 'Change Note Skins' && eventSkinDropdown != null) ? eventSkinDropdown.selectedLabel : eventVal2.text;
			
			var found = false;
			for (e in _song.events) {
				if (Math.abs(e[0] - noteStrum) < 1) {
					e[1].push([selectedEvent, eventVal1.text, v2]);
					curSelectedEvent = e;
					curSelectedNote = null;
					found = true;
					break;
				}
			}
			if (!found) {
				var newEv:Array<Dynamic> = [noteStrum, [[selectedEvent, eventVal1.text, v2]]];
				_song.events.push(newEv);
				curSelectedEvent = newEv;
				curSelectedNote = null;
			}
			UI_box.selected_tab_id = 'Events';
			updateGrid();
			return false; // Cannot drag sustain on events
		}

		var noteType:Dynamic = curNoteSkin; // define notes as the current type
		var noteSus = 0; // ninja you will NOT get away with this

		var targetSection = getSectionFromStrumTime(noteStrum);
		while (_song.notes.length <= targetSection) {
			_song.notes.push({
				lengthInSteps: 16,
				bpm: _song.bpm,
				changeBPM: false,
				mustHitSection: true,
				sectionNotes: [],
				typeOfSection: 0,
				altAnim: false
			});
		}

		_song.notes[targetSection].sectionNotes.push([noteStrum, noteData, noteSus, noteType]);

		curSelectedNote = _song.notes[targetSection].sectionNotes[_song.notes[targetSection].sectionNotes.length - 1];

		if (FlxG.keys.pressed.CONTROL)
		{
			_song.notes[targetSection].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, noteType]);
		}

		var note:Note = FunkinArrows.generateArrow(PlayState.assetModifier, noteStrum, noteData % 4, noteType, 0);
		note.sustainLength = noteSus;
		note.noteType = noteType;
		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(noteData * GRID_SIZE);
		note.y = Math.floor(getYfromStrum(noteStrum));
		note.mustPress = (noteData > 3);
		curRenderedNotes.add(note);

		if (FlxG.keys.pressed.CONTROL)
		{
			var noteCtrl:Note = FunkinArrows.generateArrow(PlayState.assetModifier, noteStrum, ((noteData + 4) % 8) % 4, noteType, 0);
			noteCtrl.sustainLength = noteSus;
			noteCtrl.noteType = noteType;
			noteCtrl.setGraphicSize(GRID_SIZE, GRID_SIZE);
			noteCtrl.updateHitbox();
			noteCtrl.x = Math.floor(((noteData + 4) % 8) * GRID_SIZE);
			noteCtrl.y = Math.floor(getYfromStrum(noteStrum));
			noteCtrl.mustPress = (((noteData + 4) % 8) > 3);
			curRenderedNotes.add(noteCtrl);
		}

		updateNoteUI();
		return true;
	}

	function getStepCrochetAtTime(time:Float):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0..._song.notes.length)
		{
			if (_song.notes[i].changeBPM) daBPM = _song.notes[i].bpm;
			var sectionDuration = ((60 / daBPM) * 1000 / 4) * _song.notes[i].lengthInSteps;
			if (time >= daPos && time < daPos + sectionDuration) return ((60 / daBPM) * 1000) / 4;
			daPos += sectionDuration;
		}
		return ((60 / daBPM) * 1000) / 4;
	}

	function getStrumTime(yPos:Float):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		var daY:Float = gridBG.y;
		for (i in 0..._song.notes.length)
		{
			if (_song.notes[i].changeBPM)
			{
				daBPM = _song.notes[i].bpm;
			}
			
			var sectionDuration = ((60 / daBPM) * 1000 / 4) * _song.notes[i].lengthInSteps;
			var sectionHeight = GRID_SIZE * _song.notes[i].lengthInSteps;
			
			if (yPos >= daY && yPos <= daY + sectionHeight)
			{
				return daPos + FlxMath.remapToRange(yPos - daY, 0, sectionHeight, 0, sectionDuration);
			}
			
			daPos += sectionDuration;
			daY += sectionHeight;
		}
		
		var yPast = yPos - daY;
		var stepsPast = yPast / GRID_SIZE;
		return daPos + (stepsPast * ((60 / daBPM) * 1000 / 4));
	}

	function getYfromStrum(strumTime:Float):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		var daY:Float = gridBG.y;
		for (i in 0..._song.notes.length)
		{
			if (_song.notes[i].changeBPM)
			{
				daBPM = _song.notes[i].bpm;
			}
			
			var sectionDuration = ((60 / daBPM) * 1000 / 4) * _song.notes[i].lengthInSteps;
			var sectionHeight = GRID_SIZE * _song.notes[i].lengthInSteps;
			
			if (strumTime >= daPos && strumTime <= daPos + sectionDuration)
			{
				return daY + FlxMath.remapToRange(strumTime - daPos, 0, sectionDuration, 0, sectionHeight);
			}
			
			daPos += sectionDuration;
			daY += sectionHeight;
		}
		
		var timePast = strumTime - daPos;
		var stepsPast = timePast / ((60 / daBPM) * 1000 / 4);
		return daY + (stepsPast * GRID_SIZE);
	}

	function getSectionFromStrumTime(strumTime:Float):Int
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0..._song.notes.length)
		{
			if (_song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
				
			var sectionDuration = ((60 / daBPM) * 1000 / 4) * _song.notes[i].lengthInSteps;
			if (strumTime >= daPos && strumTime < daPos + sectionDuration)
				return i;
				
			daPos += sectionDuration;
		}
		
		var timePast = strumTime - daPos;
		var stepsPast = timePast / ((60 / daBPM) * 1000 / 4);
		return _song.notes.length + Math.floor(stepsPast / 16);
	}

	private var daSpacing:Float = 0.3;

	function loadLevel():Void
	{
		trace(_song.notes);
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
		FlxG.resetState();
	}

	function loadAutosave():Void
	{
		PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
		FlxG.resetState();
	}

	function autosaveSong():Void
	{
		_song.format = "gaze";
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	private function saveLevel()
	{
		_song.format = "gaze";
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, null, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), _song.song.toLowerCase() + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}



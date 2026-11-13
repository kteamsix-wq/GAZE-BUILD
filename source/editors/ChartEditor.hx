package editors;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;
import flixel.FlxBasic;
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
	var loadedChartPath:String = null;
	var saveFeedbackText:FlxText = null;

	var typingShit:FlxInputText;
	var allSteppers:Array<FlxUINumericStepper> = [];
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;
	var curSelectedEvent:Array<Dynamic>;
	var pulsingNote:Array<Dynamic> = null;
	var pulsingEvent:Array<Dynamic> = null;
	var pulsingNoteSprite:Note = null;
	var pulsingEventSprite:FlxSprite = null;

	var hitPlayerSound:Sound = null;
	var hitOppSound:Sound = null;

	var tempBpm:Float = 0;

	var vocals:FlxSound;
	var opponentVocals:FlxSound;

	var playTicksBf:FlxUICheckBox = null;
	var playTicksDad:FlxUICheckBox = null;
	var playedSound:Array<Bool> = [false, false, false, false, false, false, false, false];

	var grabbedNoteData:Array<Dynamic> = null;
	var grabbedNoteProxy:Note = null;
	var dragStartPos:flixel.math.FlxPoint = null;
	var isDraggingNote:Bool = false;
	var isDraggingSustain:Bool = false;

	function changeCursor(cursorType:String) {
		CursorManager.change(cursorType);
	}

	function clearPulsing():Void
	{
		if (pulsingNoteSprite != null)
		{
			pulsingNoteSprite.alpha = 1;
			pulsingNoteSprite = null;
		}
		if (pulsingEventSprite != null)
		{
			pulsingEventSprite.alpha = 1;
			pulsingEventSprite = null;
		}
		pulsingNote = null;
		pulsingEvent = null;
	}

	function isInputFocused():Bool
	{
		if (FlxInputText.globalManager != null && FlxInputText.globalManager.focus != null)
		{
			if ((FlxInputText.globalManager.focus is flixel.FlxBasic))
			{
				var b:flixel.FlxBasic = cast FlxInputText.globalManager.focus;
				if (!b.visible || !b.active)
				{
					FlxInputText.globalManager.setFocus(null);
					return false;
				}
			}
			return FlxInputText.globalManager.isTyping;
		}
		if (typingShit != null && typingShit.hasFocus && typingShit.visible && typingShit.active)
			return true;
		if (eventVal1 != null && eventVal1.hasFocus && eventVal1.visible && eventVal1.active)
			return true;
		if (eventVal2 != null && eventVal2.hasFocus && eventVal2.visible && eventVal2.active)
			return true;
		if (eventGroupNameInput != null && eventGroupNameInput.hasFocus && eventGroupNameInput.visible && eventGroupNameInput.active)
			return true;
		return false;
	}

	function unfocusAllInputs():Void
	{
		if (FlxInputText.globalManager != null)
			FlxInputText.globalManager.setFocus(null);

		if (typingShit != null && typingShit.hasFocus)
			typingShit.endFocus();
		if (eventVal1 != null && eventVal1.hasFocus)
			eventVal1.endFocus();
		if (eventVal2 != null && eventVal2.hasFocus)
			eventVal2.endFocus();
		if (eventGroupNameInput != null && eventGroupNameInput.hasFocus)
			eventGroupNameInput.endFocus();

		#if lime
		if (FlxG.stage != null && FlxG.stage.window != null)
			FlxG.stage.window.textInputEnabled = false;
		#end
	}

	function isMouseOverlappingInput():Bool
	{
		if (typingShit != null && typingShit.visible && typingShit.active && FlxG.mouse.overlaps(typingShit))
			return true;
		if (eventVal1 != null && eventVal1.visible && eventVal1.active && FlxG.mouse.overlaps(eventVal1))
			return true;
		if (eventVal2 != null && eventVal2.visible && eventVal2.active && FlxG.mouse.overlaps(eventVal2))
			return true;
		if (eventGroupNameInput != null && eventGroupNameInput.visible && eventGroupNameInput.active && FlxG.mouse.overlaps(eventGroupNameInput))
			return true;
		if (allSteppers != null)
		{
			for (s in allSteppers)
			{
				if (s != null && s.visible && s.active && FlxG.mouse.overlaps(s))
					return true;
			}
		}
		return false;
	}

	var curRenderedEvents:FlxTypedGroup<FlxSprite>;
	var curRenderedEventExtras:FlxTypedGroup<FlxBasic>;
	var curRenderedEventChips:FlxTypedGroup<FlxSprite>;
	var renderedEventChipsData:Array<{sprite:FlxSprite, event:Array<Dynamic>, subIndex:Int}> = [];

	override function create()
	{
		super.create();
		allSteppers = [];
		
		curRenderedEvents = new FlxTypedGroup<FlxSprite>();
		curRenderedEventExtras = new FlxTypedGroup<FlxBasic>();
		curRenderedEventChips = new FlxTypedGroup<FlxSprite>();
		renderedEventChipsData = [];

		dragStartPos = flixel.math.FlxPoint.get();
		hitPlayerSound = Paths.sound('chart/hitPlayer');
		hitOppSound = Paths.sound('chart/hitOpp');
		CursorManager.show();
		changeCursor('cursor-default');

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

		#if sys
		if (_song != null && _song.chartPath != null && _song.chartPath != "")
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
		}
		#end

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

		bpmTxt = new FlxText(20, FlxG.height - 120, 360, "", 16);
		bpmTxt.autoSize = false;
		bpmTxt.fieldHeight = 120;
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		saveFeedbackText = new FlxText(20, FlxG.height - 150, FlxG.width - 40, "", 14);
		saveFeedbackText.setFormat(null, 14, FlxColor.LIME, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		saveFeedbackText.scrollFactor.set();
		saveFeedbackText.alpha = 0;
		add(saveFeedbackText);

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
		add(curRenderedEventChips);
		add(curRenderedEventExtras);
		add(curRenderedNotes);
		add(curRenderedSustains);
	}

	function addSongUI():Void
	{
		var songNameLabel = new FlxText(10, 8, 0, "Song Name:");
		var UI_songTitle = new FlxInputText(10, 22, 110, _song.song, 8);
		UI_songTitle.scrollFactor.set(0, 0);
		typingShit = UI_songTitle;

		var bpmLabel = new FlxText(135, 8, 0, "BPM:");
		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(135, 22, 1, Conductor.bpm, 1, 999, 1);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		stepperBPM.scrollFactor.set(0, 0);
		allSteppers.push(stepperBPM);

		var speedLabel = new FlxText(215, 8, 0, "Speed:");
		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(215, 22, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		stepperSpeed.scrollFactor.set(0, 0);
		allSteppers.push(stepperSpeed);

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

		// Action Buttons
		var saveButton:FlxButton = new FlxButton(10, 255, "Save", function()
		{
			saveLevel();
		});

		var saveAsButton:FlxButton = new FlxButton(150, 255, "Save As...", function()
		{
			saveLevelAs();
		});

		var reloadSong:FlxButton = new FlxButton(10, 285, "Reload Audio", function()
		{
			loadSong(_song.song);
		});

		var reloadSongJson:FlxButton = new FlxButton(150, 285, "Reload JSON", function()
		{
			loadJson(_song.song.toLowerCase());
		});

		var cameraEditorBtn:FlxButton = new FlxButton(10, 315, "Camera Editor", function()
		{
			PlayState.SONG = _song;
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new editors.CameraEditor());
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(150, 315, 'Load Autosave', loadAutosave);

		var exportPsychBtn:FlxButton = new FlxButton(10, 345, "Export Psych", function()
		{
			exportPsychLevel();
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
		tab_group_song.add(saveAsButton);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(cameraEditorBtn);
		tab_group_song.add(exportPsychBtn);

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
		stepperLength.scrollFactor.set(0, 0);
		allSteppers.push(stepperLength);

		check_mustHitSection = new FlxUICheckBox(10, 32, null, null, "Must hit section", 110);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSection].mustHitSection;

		check_altAnim = new FlxUICheckBox(130, 32, null, null, "Alt Animation", 100);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 56, null, null, 'Change BPM', 100);
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, 78, 1, Conductor.bpm, 0, 999, 0);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';
		stepperSectionBPM.scrollFactor.set(0, 0);
		allSteppers.push(stepperSectionBPM);

		var btnSectionCamEditor:FlxButton = new FlxButton(10, 104, "Camera Editor", function()
		{
			if (curSelectedEvent != null)
				applySelectedEvent();
			PlayState.SONG = _song;
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new editors.CameraEditor());
		});
		btnSectionCamEditor.color = 0xFF00AA88;

		var txtCamInfo:FlxText = new FlxText(100, 108, 180, "Camera: Camera Editor", 8);
		txtCamInfo.color = 0xFFAAAAAA;

		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 130, 1, 1, -999, 999, 0);
		stepperCopy.scrollFactor.set(0, 0);
		allSteppers.push(stepperCopy);

		var copyButton:FlxButton = new FlxButton(10, 130, "Copy last section", function()
		{
			copySection(Std.int(stepperCopy.value));
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 154, "Clear", clearSection);

		var swapSection:FlxButton = new FlxButton(10, 178, "Swap section", function()
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

		tab_group_section.add(stepperLength);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(btnSectionCamEditor);
		tab_group_section.add(txtCamInfo);
		tab_group_section.add(copyButton);
		tab_group_section.add(stepperCopy);
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
	var eventLyricsCheck:FlxUICheckBox;
	var eventCharOffsetLabel:FlxText;
	var eventCharXStepper:FlxUINumericStepper;
	var eventCharYStepper:FlxUINumericStepper;
	var eventDescText:FlxText;
	var curSelectedSubIndex:Int = 0;
	var eventsOptions:Array<String> = ['Change Character', 'Change Stage', 'Change Scroll Speed', 'Change Note Skins', 'Play Anim', 'playVideo', 'lyrics'];

	// Event Group UI & State
	var eventGroupStatusText:FlxText;
	var eventGroupNameInput:FlxInputText;
	var btnCreateEventGroup:FlxButton;
	var btnDeleteEventGroup:FlxButton;
	var btnAddToEventGroup:FlxButton;
	var btnDeleteSubEvent:FlxButton;
	var btnEventGroupUp:FlxButton;
	var btnEventGroupDown:FlxButton;
	var eventGroupPageOffset:Int = 0;
	var eventGroupSlotBtns:Array<FlxButton> = [];
	var eventGroupSlotDelBtns:Array<FlxButton> = [];
	var eventGroupHintText:FlxText;

	function updateEventDesc():Void
	{
		if (eventDescText == null) return;
		var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
		switch (evName)
		{
			case 'FocusCamera' | 'ZoomCamera' | 'Cam Pos To' | 'Add Cam Zoom' | 'Add Camera Zoom':
				eventDescText.text = "Camera Event: Coordinated in Camera Editor.\nClick [Open Camera Editor] below to edit visually.";
			case 'Change Character':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/gf), x, y\nVal 2: Character JSON";
			case 'Change Stage' | 'change stage':
				eventDescText.text = "Val 1: Stage name (ou 'random' / 'aleatorio')\nVal 2: Opcoes (norepos, nozoom, snap, flash)";
			case 'Change Scroll Speed':
				eventDescText.text = "Val 1: Speed number (or reset)\nVal 2: steps, ease";
			case 'Change Note Skins':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/ambos)\nVal 2: Note Skin";
			case 'Play Anim':
				eventDescText.text = "Val 1: Target (0/bf, 1/dad, 2/gf)\nVal 2: anim, lock (optional), ignoreArrows (optional)";
			case 'playVideo' | 'Play Video':
				eventDescText.text = "Val 1: Video name (in videos/)\nVal 2: true (screenCenter), scale";
			case 'lyrics' | 'Lyrics':
				eventDescText.text = "Val 1: Texto da letra\nVal 2: 'digitalizado' (maquina de escrever)\nSome apos ~4 segundos.";
			default:
				eventDescText.text = "";
		}
	}

	function syncCharSteppersFromValFields():Void
	{
		if (eventCharXStepper == null || eventCharYStepper == null) return;
		var v1 = (eventVal1 != null && eventVal1.text != null) ? eventVal1.text : "";
		var v2 = (eventVal2 != null && eventVal2.text != null) ? eventVal2.text : "";
		var parsed = editors.camera.CameraEditorEvent.parseChangeCharParams(v1, v2);
		eventCharXStepper.value = (parsed.x != null) ? parsed.x : 0;
		eventCharYStepper.value = (parsed.y != null) ? parsed.y : 0;
	}

	function syncValFieldsFromCharSteppers():Void
	{
		if (eventVal1 == null || eventCharXStepper == null || eventCharYStepper == null) return;
		var v1 = (eventVal1.text != null) ? eventVal1.text : "";
		var v2 = (eventVal2 != null && eventVal2.text != null) ? eventVal2.text : "";
		var parsed = editors.camera.CameraEditorEvent.parseChangeCharParams(v1, v2);

		var rawTokens = editors.camera.CameraEditorEvent.splitEventParams(v1);
		var targetToken:String = (rawTokens.length > 0 && editors.camera.CameraEditorEvent.isTargetToken(rawTokens[0]))
			? rawTokens[0]
			: Std.string(parsed.target);

		var cx:Float = eventCharXStepper.value;
		var cy:Float = eventCharYStepper.value;
		if (cx != 0 || cy != 0)
			eventVal1.text = '$targetToken, $cx, $cy';
		else
			eventVal1.text = targetToken;

		if (eventVal2 != null && (eventVal2.text == null || eventVal2.text.trim() == "") && parsed.charName != "")
			eventVal2.text = parsed.charName;
	}

	function updateEventValueFields():Void
	{
		var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
		var isSkinEvent:Bool = (evName == 'Change Note Skins');
		var isLyricsEvent:Bool = (evName == 'lyrics' || evName == 'Lyrics');
		var isChangeCharEvent:Bool = (evName == 'Change Character' || evName == 'changeChar');
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
		if (eventLyricsCheck != null)
		{
			eventLyricsCheck.visible = isLyricsEvent;
			if (isLyricsEvent)
			{
				var curV2:String = (eventVal2 != null && eventVal2.text != null) ? eventVal2.text.toLowerCase() : "";
				eventLyricsCheck.checked = (curV2.indexOf('digitalizado') != -1 || curV2.indexOf('typewriter') != -1 || curV2.indexOf('maquina') != -1 || curV2.indexOf('typed') != -1 || curV2 == 'true' || curV2 == '1' || curV2 == 'sim');
			}
		}
		if (eventCharOffsetLabel != null) eventCharOffsetLabel.visible = isChangeCharEvent;
		if (eventCharXStepper != null) eventCharXStepper.visible = isChangeCharEvent;
		if (eventCharYStepper != null) eventCharYStepper.visible = isChangeCharEvent;
		if (isChangeCharEvent)
		{
			syncCharSteppersFromValFields();
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
			var subList:Array<Dynamic> = curSelectedEvent[1];
			if (curSelectedSubIndex < 0 || curSelectedSubIndex >= subList.length)
				curSelectedSubIndex = 0;

			if (selectedEvent == 'Change Character' || selectedEvent == 'changeChar')
			{
				var parsed = editors.camera.CameraEditorEvent.parseChangeCharParams(eventVal1.text, eventVal2.text);
				var rawTokens = editors.camera.CameraEditorEvent.splitEventParams(eventVal1.text);
				var targetToken:String = (rawTokens.length > 0 && editors.camera.CameraEditorEvent.isTargetToken(rawTokens[0]))
					? rawTokens[0]
					: Std.string(parsed.target);
				var normV1:String = targetToken;
				if (parsed.x != null || parsed.y != null)
				{
					var px:Float = (parsed.x != null) ? parsed.x : 0;
					var py:Float = (parsed.y != null) ? parsed.y : 0;
					if (px != 0 || py != 0)
						normV1 = '$targetToken, $px, $py';
				}
				var normV2:String = (parsed.charName != "") ? parsed.charName : eventVal2.text.trim();
				subList[curSelectedSubIndex][0] = 'Change Character';
				subList[curSelectedSubIndex][1] = normV1;
				subList[curSelectedSubIndex][2] = normV2;

				// Remove any duplicate Change Character sub-events for the same target at this timestamp
				var i = subList.length - 1;
				while (i >= 0)
				{
					if (i != curSelectedSubIndex && subList[i] != null)
					{
						var otherName = Std.string(subList[i][0]).toLowerCase().trim();
						if (otherName == 'change character' || otherName == 'changechar')
						{
							var otherParsed = editors.camera.CameraEditorEvent.parseChangeCharParams(
								Std.string(subList[i][1]),
								Std.string(subList[i][2])
							);
							if (otherParsed.target == parsed.target)
							{
								subList.splice(i, 1);
								if (i < curSelectedSubIndex)
									curSelectedSubIndex--;
							}
						}
					}
					i--;
				}
			}
			else
			{
				subList[curSelectedSubIndex][0] = selectedEvent;
				subList[curSelectedSubIndex][1] = eventVal1.text;
				subList[curSelectedSubIndex][2] = eventVal2.text;
			}
			refreshEventGroupUI();
		}
	}

	function resizeEventBtn(btn:FlxButton, w:Int, h:Int):Void
	{
		if (btn == null) return;
		btn.setGraphicSize(w, h);
		btn.updateHitbox();
		if (btn.label != null)
		{
			btn.label.fieldWidth = w;
			btn.label.alignment = CENTER;
			btn.label.y = btn.y + Math.floor((h - btn.label.height) * 0.5);
		}
	}

	function getEventGroupName(time:Float):String
	{
		if (_song == null || _song.eventGroups == null) return "";
		for (g in _song.eventGroups)
		{
			if (g != null && Reflect.hasField(g, "time"))
			{
				var gt:Float = Std.parseFloat(Std.string(Reflect.field(g, "time")));
				if (!Math.isNaN(gt) && Math.abs(gt - time) < 3.0)
				{
					var nm:String = Reflect.hasField(g, "name") ? Std.string(Reflect.field(g, "name")).trim() : "";
					if (nm != "") return nm;
				}
			}
		}
		return "";
	}

	function setEventGroupName(time:Float, name:String):Void
	{
		if (_song == null) return;
		if (_song.eventGroups == null) _song.eventGroups = [];
		var cleanName = (name != null) ? name.trim() : "";
		var i = _song.eventGroups.length - 1;
		while (i >= 0)
		{
			var g = _song.eventGroups[i];
			if (g != null && Reflect.hasField(g, "time"))
			{
				var gt:Float = Std.parseFloat(Std.string(Reflect.field(g, "time")));
				if (!Math.isNaN(gt) && Math.abs(gt - time) < 3.0)
					_song.eventGroups.splice(i, 1);
			}
			i--;
		}
		if (cleanName != "")
		{
			_song.eventGroups.push({time: Math.round(time * 1000) / 1000, name: cleanName});
		}
	}

	function getEventChipColor(evName:String):Int
	{
		var clean = (evName != null) ? StringTools.replace(evName.toLowerCase(), " ", "") : "";
		return switch (clean)
		{
			case "changecharacter" | "changechar": 0xFF9933CC;
			case "focuscamera": 0xFF00AA88;
			case "zoomcamera" | "addcamzoom" | "addcamerazoom": 0xFFCC7700;
			case "playanim" | "playanimation": 0xFFDDAA00;
			case "changestage": 0xFF2A82BE;
			case "changescrollspeed": 0xFF33AA55;
			case "changenoteskins": 0xFFCC4488;
			case "playvideo": 0xFFCC4444;
			case "lyrics": 0xFFBBBB33;
			default: 0xFF556688;
		}
	}

	function getEventShortTag(evName:String):String
	{
		var clean = (evName != null) ? StringTools.replace(evName.toLowerCase(), " ", "") : "";
		return switch (clean)
		{
			case "changecharacter" | "changechar": "CC";
			case "focuscamera": "FC";
			case "zoomcamera" | "addcamzoom" | "addcamerazoom": "ZC";
			case "playanim" | "playanimation": "PA";
			case "changestage": "ST";
			case "changescrollspeed": "SP";
			case "changenoteskins": "SK";
			case "playvideo": "VD";
			case "lyrics": "LY";
			default: "EV";
		}
	}

	function formatSubEventSummary(sub:Dynamic, idx:Int):String
	{
		if (sub == null) return '${idx + 1}. (vazio)';
		var eName:String = (sub.length > 0 && sub[0] != null) ? Std.string(sub[0]) : "Event";
		var v1:String = (sub.length > 1 && sub[1] != null) ? Std.string(sub[1]).trim() : "";
		var v2:String = (sub.length > 2 && sub[2] != null) ? Std.string(sub[2]).trim() : "";
		var detail:String = "";
		if (v1 != "" && v2 != "")
			detail = '$v1 | $v2';
		else if (v1 != "")
			detail = v1;
		else if (v2 != "")
			detail = v2;
		var txt = '${idx + 1}. $eName';
		if (detail != "")
			txt += ': $detail';
		if (txt.length > 31)
			txt = txt.substr(0, 29) + '..';
		return txt;
	}

	function loadSubEventIntoFields(ev:Array<Dynamic>, subIdx:Int):Void
	{
		if (ev == null || ev[1] == null) return;
		var subList:Array<Dynamic> = cast ev[1];
		if (subList.length == 0) return;

		if (subIdx < 0) subIdx = 0;
		if (subIdx >= subList.length) subIdx = subList.length - 1;

		curSelectedEvent = ev;
		curSelectedSubIndex = subIdx;

		var evData = subList[curSelectedSubIndex];
		var evName:String = (evData[0] != null) ? Std.string(evData[0]) : "";
		eventVal1.text = (evData[1] != null) ? Std.string(evData[1]) : "";
		eventVal2.text = (evData[2] != null) ? Std.string(evData[2]) : "";

		var normEv:String = evName != null ? StringTools.replace(evName.toLowerCase(), " ", "") : "";
		for (optIdx in 0...eventsOptions.length)
		{
			var opt:String = eventsOptions[optIdx];
			if (opt == evName || StringTools.replace(opt.toLowerCase(), " ", "") == normEv)
			{
				eventDropdown.selectedLabel = opt;
				eventDropdown.selectedId = Std.string(optIdx);
				break;
			}
		}
		updateEventDesc();
		updateEventValueFields();
		refreshEventGroupUI();
	}

	function deleteSubEventFromGroup(ev:Array<Dynamic>, subIdx:Int):Void
	{
		if (_song.events == null || ev == null || ev[1] == null) return;
		var subList:Array<Dynamic> = cast ev[1];
		if (subIdx < 0 || subIdx >= subList.length) return;

		subList.splice(subIdx, 1);
		if (subList.length == 0)
		{
			setEventGroupName(ev[0], "");
			_song.events.remove(ev);
			if (curSelectedEvent == ev)
			{
				curSelectedEvent = null;
				curSelectedSubIndex = 0;
			}
		}
		else if (curSelectedEvent == ev)
		{
			if (curSelectedSubIndex >= subList.length)
				curSelectedSubIndex = subList.length - 1;
			loadSubEventIntoFields(ev, curSelectedSubIndex);
		}

		clearPulsing();
		updateGrid();
		refreshEventGroupUI();
		autosaveSong();
	}

	function addCurrentEventToGroup():Void
	{
		if (_song.events == null) _song.events = [];
		var selectedIdx:Int = Std.parseInt(eventDropdown.selectedId);
		var selectedEvent:String = (selectedIdx >= 0 && selectedIdx < eventsOptions.length) ? eventsOptions[selectedIdx] : eventDropdown.selectedLabel;
		var v1:String = eventVal1.text;
		var v2:String = (selectedEvent == 'Change Note Skins' && eventSkinDropdown != null) ? eventSkinDropdown.selectedLabel : eventVal2.text;

		if (selectedEvent == 'Change Character' || selectedEvent == 'changeChar')
		{
			var parsed = editors.camera.CameraEditorEvent.parseChangeCharParams(v1, v2);
			var rawTokens = editors.camera.CameraEditorEvent.splitEventParams(v1);
			var targetToken:String = (rawTokens.length > 0 && editors.camera.CameraEditorEvent.isTargetToken(rawTokens[0]))
				? rawTokens[0]
				: Std.string(parsed.target);
			v1 = targetToken;
			if (parsed.x != null || parsed.y != null)
			{
				var px:Float = (parsed.x != null) ? parsed.x : 0;
				var py:Float = (parsed.y != null) ? parsed.y : 0;
				if (px != 0 || py != 0)
					v1 = '$targetToken, $px, $py';
			}
			if (parsed.charName != "")
				v2 = parsed.charName;
		}

		var newSubEv:Array<Dynamic> = [selectedEvent, v1, v2];
		var targetEvent:Array<Dynamic> = curSelectedEvent;

		if (targetEvent == null)
		{
			var stepCro = getStepCrochetAtTime(Conductor.songPosition);
			var targetTime:Float = Math.round(Conductor.songPosition / stepCro) * stepCro;
			for (e in _song.events)
			{
				if (Math.abs(e[0] - targetTime) < 2.0)
				{
					targetEvent = e;
					break;
				}
			}
			if (targetEvent == null)
			{
				targetEvent = [targetTime, []];
				_song.events.push(targetEvent);
			}
		}

		var subList:Array<Dynamic> = cast targetEvent[1];
		subList.push(newSubEv);
		curSelectedEvent = targetEvent;
		curSelectedSubIndex = subList.length - 1;
		eventGroupPageOffset = Std.int(Math.max(0, subList.length - 3));
		UI_box.selected_tab_id = 'Events';
		updateGrid();
		refreshEventGroupUI();
		autosaveSong();
	}

	function refreshEventGroupUI():Void
	{
		if (eventGroupStatusText == null) return;

		if (curSelectedEvent == null || curSelectedEvent[1] == null)
		{
			eventGroupStatusText.text = "Grupo: Nenhum selecionado";
			eventGroupStatusText.color = 0xFFAAAAAA;
			if (eventGroupNameInput != null && !eventGroupNameInput.hasFocus)
				eventGroupNameInput.text = "";
			for (i in 0...eventGroupSlotBtns.length)
			{
				eventGroupSlotBtns[i].visible = false;
				eventGroupSlotBtns[i].active = false;
				eventGroupSlotDelBtns[i].visible = false;
				eventGroupSlotDelBtns[i].active = false;
			}
			if (btnDeleteEventGroup != null) { btnDeleteEventGroup.visible = false; btnDeleteEventGroup.active = false; }
			if (btnDeleteSubEvent != null) { btnDeleteSubEvent.visible = false; btnDeleteSubEvent.active = false; }
			if (btnEventGroupUp != null) { btnEventGroupUp.visible = false; btnEventGroupUp.active = false; }
			if (btnEventGroupDown != null) { btnEventGroupDown.visible = false; btnEventGroupDown.active = false; }
			return;
		}

		var subList:Array<Dynamic> = cast curSelectedEvent[1];
		if (curSelectedSubIndex < 0) curSelectedSubIndex = 0;
		if (curSelectedSubIndex >= subList.length && subList.length > 0) curSelectedSubIndex = subList.length - 1;

		var gName = getEventGroupName(curSelectedEvent[0]);
		if (eventGroupNameInput != null && !eventGroupNameInput.hasFocus)
			eventGroupNameInput.text = gName;

		var labelPrefix = (gName != "") ? 'Grupo "$gName"' : "Grupo no Tempo";
		eventGroupStatusText.text = '$labelPrefix (${subList.length} ev) - Sel: ${curSelectedSubIndex + 1}/${subList.length}';
		eventGroupStatusText.color = (subList.length > 1 || gName != "") ? 0xFF00FFCC : 0xFFFFFFFF;

		if (btnDeleteEventGroup != null) { btnDeleteEventGroup.visible = true; btnDeleteEventGroup.active = true; }
		if (btnDeleteSubEvent != null) { btnDeleteSubEvent.visible = (subList.length > 0); btnDeleteSubEvent.active = (subList.length > 0); }

		var maxPage = Std.int(Math.max(0, subList.length - 3));
		if (eventGroupPageOffset > maxPage) eventGroupPageOffset = maxPage;
		if (eventGroupPageOffset < 0) eventGroupPageOffset = 0;

		var showScroll = (subList.length > 3);
		if (btnEventGroupUp != null) { btnEventGroupUp.visible = showScroll; btnEventGroupUp.active = showScroll && (eventGroupPageOffset > 0); }
		if (btnEventGroupDown != null) { btnEventGroupDown.visible = showScroll; btnEventGroupDown.active = showScroll && (eventGroupPageOffset < maxPage); }

		for (row in 0...eventGroupSlotBtns.length)
		{
			var sIdx = eventGroupPageOffset + row;
			var btn = eventGroupSlotBtns[row];
			var delBtn = eventGroupSlotDelBtns[row];
			if (sIdx < subList.length)
			{
				btn.visible = true;
				btn.active = true;
				delBtn.visible = true;
				delBtn.active = true;

				var sub = subList[sIdx];
				var isSel = (sIdx == curSelectedSubIndex);
				if (btn.label != null)
					btn.label.text = (isSel ? "> " : "  ") + formatSubEventSummary(sub, sIdx);
				var evN:String = (sub != null && sub.length > 0 && sub[0] != null) ? Std.string(sub[0]) : "";
				btn.color = isSel ? 0xFF00AA88 : getEventChipColor(evN);
				btn.alpha = isSel ? 1.0 : 0.78;
			}
			else
			{
				btn.visible = false;
				btn.active = false;
				delBtn.visible = false;
				delBtn.active = false;
			}
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
		eventVal1.scrollFactor.set(0, 0);

		var val2Label = new FlxText(10, 100, 0, "Value 2:");
		eventVal2 = new FlxInputText(10, 115, 140, "");
		eventVal2.scrollFactor.set(0, 0);

		eventCharOffsetLabel = new FlxText(156, 60, 0, "Offset X / Y:");
		eventCharXStepper = new FlxUINumericStepper(156, 75, 10, 0, -3000, 3000, 0);
		eventCharXStepper.name = 'event_char_x';
		eventCharXStepper.scrollFactor.set(0, 0);
		allSteppers.push(eventCharXStepper);

		eventCharYStepper = new FlxUINumericStepper(156, 115, 10, 0, -3000, 3000, 0);
		eventCharYStepper.name = 'event_char_y';
		eventCharYStepper.scrollFactor.set(0, 0);
		allSteppers.push(eventCharYStepper);

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

		eventLyricsCheck = new FlxUICheckBox(160, 115, null, null, "Digitalizado", 110);
		eventLyricsCheck.callback = function()
		{
			var isChecked:Bool = eventLyricsCheck.checked;
			var curVal:String = (eventVal2 != null && eventVal2.text != null) ? eventVal2.text.trim() : "";
			if (isChecked)
			{
				if (curVal == "")
					eventVal2.text = "digitalizado";
				else if (curVal.toLowerCase().indexOf("digitalizado") == -1)
					eventVal2.text = "digitalizado, " + curVal;
			}
			else
			{
				curVal = StringTools.replace(curVal, "digitalizado, ", "");
				curVal = StringTools.replace(curVal, ", digitalizado", "");
				curVal = StringTools.replace(curVal, "digitalizado", "");
				eventVal2.text = curVal.trim();
			}
			applySelectedEvent();
		};
		eventLyricsCheck.visible = false;

		eventDescText = new FlxText(10, 142, 160, "");
		eventDescText.setFormat(null, 8, 0xFFAAAAAA);
		updateEventDesc();

		var btnGoCamEditor:FlxButton = new FlxButton(10, 195, "Camera Editor", function()
		{
			if (curSelectedEvent != null)
				applySelectedEvent();
			PlayState.SONG = _song;
			if (songMusic != null) songMusic.stop();
			if (vocals != null) vocals.stop();
			Main.switchState(this, new editors.CameraEditor());
		});
		resizeEventBtn(btnGoCamEditor, 115, 20);
		btnGoCamEditor.color = 0xFF00AA88;

		var txtCamHint:FlxText = new FlxText(132, 194, 158, "Eventos de camera podem ser\najustados no Camera Editor.", 8);
		txtCamHint.color = 0xFF888899;

		var groupDivider = new FlxSprite(10, 219).makeGraphic(278, 1, 0xFF445566);

		eventGroupStatusText = new FlxText(10, 224, 280, "Grupo: Nenhum selecionado", 9);
		eventGroupStatusText.setFormat(null, 9, 0xFFAAAAAA, LEFT);

		eventGroupNameInput = new FlxInputText(10, 242, 126, "");
		eventGroupNameInput.scrollFactor.set(0, 0);

		btnCreateEventGroup = new FlxButton(140, 240, "Nomear", function()
		{
			var gName:String = (eventGroupNameInput != null && eventGroupNameInput.text != null) ? eventGroupNameInput.text.trim() : "";
			if (curSelectedEvent != null)
			{
				if (gName == "")
				{
					var nextNum = (_song != null && _song.eventGroups != null) ? (_song.eventGroups.length + 1) : 1;
					gName = 'Grupo $nextNum';
				}
				setEventGroupName(curSelectedEvent[0], gName);
			}
			else
			{
				addCurrentEventToGroup();
				if (curSelectedEvent != null)
				{
					if (gName == "")
					{
						var nextNum = (_song != null && _song.eventGroups != null) ? (_song.eventGroups.length + 1) : 1;
						gName = 'Grupo $nextNum';
					}
					setEventGroupName(curSelectedEvent[0], gName);
				}
			}
			updateGrid();
			refreshEventGroupUI();
			autosaveSong();
		});
		resizeEventBtn(btnCreateEventGroup, 76, 20);
		btnCreateEventGroup.color = 0xFF2A82BE;

		btnDeleteEventGroup = new FlxButton(220, 240, "Del Grupo", function()
		{
			if (curSelectedEvent != null && _song.events != null)
			{
				setEventGroupName(curSelectedEvent[0], "");
				_song.events.remove(curSelectedEvent);
				curSelectedEvent = null;
				curSelectedSubIndex = 0;
				clearPulsing();
				updateGrid();
				refreshEventGroupUI();
				autosaveSong();
			}
		});
		resizeEventBtn(btnDeleteEventGroup, 68, 20);
		btnDeleteEventGroup.color = 0xFFCC3333;

		btnAddToEventGroup = new FlxButton(10, 264, "+ Add no Grupo", function()
		{
			addCurrentEventToGroup();
		});
		resizeEventBtn(btnAddToEventGroup, 130, 20);
		btnAddToEventGroup.color = 0xFF00AA88;

		btnDeleteSubEvent = new FlxButton(144, 264, "Del Item", function()
		{
			if (curSelectedEvent != null)
				deleteSubEventFromGroup(curSelectedEvent, curSelectedSubIndex);
		});
		resizeEventBtn(btnDeleteSubEvent, 72, 20);
		btnDeleteSubEvent.color = 0xFFDD6633;

		btnEventGroupUp = new FlxButton(222, 264, "^", function()
		{
			if (eventGroupPageOffset > 0)
			{
				eventGroupPageOffset--;
				refreshEventGroupUI();
			}
		});
		resizeEventBtn(btnEventGroupUp, 30, 20);
		btnEventGroupUp.color = 0xFF333344;

		btnEventGroupDown = new FlxButton(256, 264, "v", function()
		{
			if (curSelectedEvent != null && curSelectedEvent[1] != null)
			{
				var maxPage = Std.int(Math.max(0, cast(curSelectedEvent[1], Array<Dynamic>).length - 3));
				if (eventGroupPageOffset < maxPage)
				{
					eventGroupPageOffset++;
					refreshEventGroupUI();
				}
			}
		});
		resizeEventBtn(btnEventGroupDown, 30, 20);
		btnEventGroupDown.color = 0xFF333344;

		eventGroupSlotBtns = [];
		eventGroupSlotDelBtns = [];
		function addGroupSlotRow(rowIdx:Int):Void
		{
			var ry = 288 + (rowIdx * 25);
			var slotBtn = new FlxButton(10, ry, "", function()
			{
				if (curSelectedEvent != null)
					loadSubEventIntoFields(curSelectedEvent, eventGroupPageOffset + rowIdx);
			});
			resizeEventBtn(slotBtn, 248, 22);
			if (slotBtn.label != null) slotBtn.label.alignment = LEFT;
			eventGroupSlotBtns.push(slotBtn);

			var delBtn = new FlxButton(262, ry, "X", function()
			{
				if (curSelectedEvent != null)
					deleteSubEventFromGroup(curSelectedEvent, eventGroupPageOffset + rowIdx);
			});
			resizeEventBtn(delBtn, 24, 22);
			delBtn.color = 0xFFCC3333;
			eventGroupSlotDelBtns.push(delBtn);
		}
		for (row in 0...3)
			addGroupSlotRow(row);

		eventGroupHintText = new FlxText(10, 366, 280, "Shift+Clique na grid/icone adiciona ao grupo sem sobrepor.", 8);
		eventGroupHintText.color = 0xFF8899AA;

		tab_group_event.add(new FlxText(10, 10, 0, "Event Type:"));
		tab_group_event.add(val1Label);
		tab_group_event.add(eventVal1);
		tab_group_event.add(val2Label);
		tab_group_event.add(eventVal2);
		tab_group_event.add(eventCharOffsetLabel);
		tab_group_event.add(eventCharXStepper);
		tab_group_event.add(eventCharYStepper);
		tab_group_event.add(eventSkinDropdown);
		tab_group_event.add(eventLyricsCheck);
		tab_group_event.add(eventDescText);
		tab_group_event.add(btnGoCamEditor);
		tab_group_event.add(txtCamHint);
		tab_group_event.add(groupDivider);
		tab_group_event.add(eventGroupStatusText);
		tab_group_event.add(eventGroupNameInput);
		tab_group_event.add(btnCreateEventGroup);
		tab_group_event.add(btnDeleteEventGroup);
		tab_group_event.add(btnAddToEventGroup);
		tab_group_event.add(btnDeleteSubEvent);
		tab_group_event.add(btnEventGroupUp);
		tab_group_event.add(btnEventGroupDown);
		for (row in 0...3)
		{
			tab_group_event.add(eventGroupSlotBtns[row]);
			tab_group_event.add(eventGroupSlotDelBtns[row]);
		}
		tab_group_event.add(eventGroupHintText);
		tab_group_event.add(eventDropdown);

		UI_box.addGroup(tab_group_event);
		updateEventValueFields();
		refreshEventGroupUI();
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
		stepperSusLength.scrollFactor.set(0, 0);
		allSteppers.push(stepperSusLength);

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
		if (songMusic != null || vocals != null || opponentVocals != null)
		{
			Utils.killMusic([songMusic, vocals, opponentVocals]);
			songMusic = null;
			vocals = null;
			opponentVocals = null;
		}

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
					tempBpm = nums.value;
					_song.bpm = nums.value;
					Conductor.mapBPMChanges(_song);
					Conductor.changeBPM(nums.value);
				case 'note_susLength': // STOP POSTING ABOUT AMONG US
					if (curSelectedNote != null) curSelectedNote[2] = nums.value; // change the currently selected note's length
					updateGrid(); // oh btw I know sus stands for sustain it just bothers me
				case 'note_type':
					curNoteType = Std.int(nums.value); // oh yeah dont forget this has to be an integer
				// set the new note type for when placing notes next!
				case 'section_bpm':
					_song.notes[curSection].bpm = nums.value; // redefine the section's bpm
					updateGrid(); // update the note grid
				case 'event_char_x' | 'event_char_y':
					syncValFieldsFromCharSteppers();
					applySelectedEvent();
			}
		}
		else if (id == FlxUITabMenu.CLICK_EVENT)
		{
			if (typingShit != null && typingShit.text != null && typingShit.text.trim().length > 0)
				_song.song = typingShit.text.trim();
			applySelectedEvent();
			unfocusAllInputs();
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
		if (typingShit != null && typingShit.text != null && typingShit.text.trim().length > 0)
			_song.song = typingShit.text.trim();

		if (saveFeedbackText != null && saveFeedbackText.alpha > 0)
			saveFeedbackText.alpha -= elapsed * 0.5;

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
		{
			if (FlxG.keys.pressed.SHIFT)
				saveLevelAs();
			else
				saveLevel();
		}

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
							if (hitPlayerSound != null)
								FlxG.sound.play(hitPlayerSound);
							soundPlayed = true;
						}
						else if (playTicksDad.checked && !note.mustPress)
						{
							if (hitOppSound != null)
								FlxG.sound.play(hitOppSound);
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

		if (FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
		{
			if (!isMouseOverlappingInput())
			{
				if (curSelectedEvent != null)
					applySelectedEvent();
				if (typingShit != null && typingShit.text != null && typingShit.text.trim().length > 0)
					_song.song = typingShit.text.trim();
				unfocusAllInputs();
			}
		}

		if (typingShit != null && (!typingShit.visible || !typingShit.active) && typingShit.hasFocus)
			typingShit.endFocus();
		if (eventVal1 != null && (!eventVal1.visible || !eventVal1.active) && eventVal1.hasFocus)
			eventVal1.endFocus();
		if (eventVal2 != null && (!eventVal2.visible || !eventVal2.active) && eventVal2.hasFocus)
			eventVal2.endFocus();
		if (eventGroupNameInput != null && (!eventGroupNameInput.visible || !eventGroupNameInput.active) && eventGroupNameInput.hasFocus)
			eventGroupNameInput.endFocus();

		// RIGHT CLICK - DELETE
		if (FlxG.mouse.justPressedRight)
		{
			var chipToDelete:{sprite:FlxSprite, event:Array<Dynamic>, subIndex:Int} = null;
			for (chip in renderedEventChipsData)
			{
				if (chip != null && chip.sprite != null && chip.sprite.alive && FlxG.mouse.overlaps(chip.sprite))
				{
					chipToDelete = chip;
				}
			}

			var eventToDelete:FlxSprite = null;
			if (chipToDelete == null && FlxG.mouse.overlaps(curRenderedEvents)) {
				curRenderedEvents.forEach(function(ev:FlxSprite) {
					if (FlxG.mouse.overlaps(ev)) {
						eventToDelete = ev;
					}
				});
			}

			if (chipToDelete != null)
			{
				deleteSubEventFromGroup(chipToDelete.event, chipToDelete.subIndex);
			}
			else if (eventToDelete != null) {
				var evStrum = getStrumTime(eventToDelete.y);
				if (_song.events != null) {
					for (i in 0..._song.events.length) {
						if (Math.abs(_song.events[i][0] - evStrum) < 5) {
							setEventGroupName(_song.events[i][0], "");
							if (curSelectedEvent == _song.events[i]) curSelectedEvent = null;
							_song.events.remove(_song.events[i]);
							break;
						}
					}
				}
				clearPulsing();
				updateGrid();
				refreshEventGroupUI();
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

					clearPulsing();

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
			var chipToSelect:{sprite:FlxSprite, event:Array<Dynamic>, subIndex:Int} = null;
			for (chip in renderedEventChipsData)
			{
				if (chip != null && chip.sprite != null && chip.sprite.alive && FlxG.mouse.overlaps(chip.sprite))
				{
					chipToSelect = chip;
				}
			}

			var eventToSelect:FlxSprite = null;
			if (chipToSelect == null && FlxG.mouse.overlaps(curRenderedEvents)) {
				curRenderedEvents.forEach(function(ev:FlxSprite) {
					if (FlxG.mouse.overlaps(ev)) {
						eventToSelect = ev;
					}
				});
			}

			if (chipToSelect != null)
			{
				curSelectedNote = null;
				clearPulsing();
				UI_box.selected_tab_id = 'Events';
				loadSubEventIntoFields(chipToSelect.event, chipToSelect.subIndex);
				updateGrid();
			}
			else if (eventToSelect != null) {
				var evStrum = getStrumTime(eventToSelect.y);
				if (_song.events != null) {
					for (i in 0..._song.events.length) {
						if (Math.abs(_song.events[i][0] - evStrum) < 5) {
							if (FlxG.keys.pressed.SHIFT)
							{
								curSelectedEvent = _song.events[i];
								curSelectedNote = null;
								addCurrentEventToGroup();
								break;
							}
							var wasAlreadySelected:Bool = (curSelectedEvent == _song.events[i]);
							curSelectedEvent = _song.events[i];
							curSelectedNote = null;
							clearPulsing();
							pulsingEvent = curSelectedEvent;
							pulsingEventSprite = eventToSelect;
							
							// Update UI
							UI_box.selected_tab_id = 'Events';
							if (curSelectedEvent[1] != null && curSelectedEvent[1].length > 0) {
								var subList:Array<Dynamic> = curSelectedEvent[1];
								var nextSubIdx:Int = 0;
								if (wasAlreadySelected && subList.length > 1)
								{
									nextSubIdx = (curSelectedSubIndex + 1) % subList.length;
								}
								else
								{
									var preferredLabel:String = (eventDropdown != null && eventDropdown.selectedLabel != null)
										? StringTools.replace(eventDropdown.selectedLabel.toLowerCase(), " ", "") : "";
									var foundMatch:Bool = false;
									for (sIdx in 0...subList.length)
									{
										var sName:String = (subList[sIdx] != null && subList[sIdx][0] != null)
											? StringTools.replace(Std.string(subList[sIdx][0]).toLowerCase(), " ", "") : "";
										if (preferredLabel != "" && sName == preferredLabel)
										{
											nextSubIdx = sIdx;
											foundMatch = true;
											break;
										}
									}
									if (!foundMatch)
									{
										for (sIdx in 0...subList.length)
										{
											var sName:String = (subList[sIdx] != null && subList[sIdx][0] != null)
												? StringTools.replace(Std.string(subList[sIdx][0]).toLowerCase(), " ", "") : "";
											if (sName == "changecharacter" || sName == "changechar")
											{
												nextSubIdx = sIdx;
												foundMatch = true;
												break;
											}
										}
									}
									if (!foundMatch)
									{
										for (sIdx in 0...subList.length)
										{
											var sName:String = (subList[sIdx] != null && subList[sIdx][0] != null)
												? StringTools.replace(Std.string(subList[sIdx][0]).toLowerCase(), " ", "") : "";
											if (sName != "focuscamera" && sName != "zoomcamera")
											{
												nextSubIdx = sIdx;
												break;
											}
										}
									}
								}

								loadSubEventIntoFields(curSelectedEvent, nextSubIdx);
								updateGrid();
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
					refreshEventGroupUI();
					clearPulsing();
					pulsingNote = curSelectedNote;
					pulsingNoteSprite = noteToSelect;
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
				var dx:Float = FlxG.mouse.x - dragStartPos.x;
				var dy:Float = FlxG.mouse.y - dragStartPos.y;
				var dist:Float = Math.sqrt(dx * dx + dy * dy);
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
							FlxG.sound.play(Paths.sound('chart/grab/stretchSNAP_UI'));
							
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
					FlxG.sound.play(Paths.sound('chart/noteErase'));
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
					FlxG.sound.play(Paths.sound('chart/grab/stretch1_UI'), 0.5);
				}
			} else if (FlxG.mouse.justReleased) {
				isDraggingSustain = false;
			}
		}

		if (isDraggingNote) {
			changeCursor('cursor-grabbing');
		} else if (isDraggingSustain) {
			changeCursor('cursor-scroll');
		} else if (isMouseOverlappingInput()) {
			changeCursor('cursor-text');
		} else if (FlxG.mouse.x > gridBG.x && FlxG.mouse.x < gridBG.x + (GRID_SIZE * 9)) {
			if (getStrumTime(FlxG.mouse.y) < 0) {
				changeCursor('cursor-cross');
			} else {
				changeCursor('cursor-pointer');
			}
		} else if (UI_box != null && FlxG.mouse.overlaps(UI_box)) {
			changeCursor('cursor-pointer');
		} else {
			changeCursor('cursor-default');
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

		if (UI_box != null)
		{
			if (UI_box.selected_tab_id == 'Events')
			{
				var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
				var isSkinEvent:Bool = (evName == 'Change Note Skins');
				var isLyricsEvent:Bool = (evName == 'lyrics' || evName == 'Lyrics');
				var isChangeCharEvent:Bool = (evName == 'Change Character' || evName == 'changeChar');
				if (eventVal2 != null && eventVal2.visible == isSkinEvent)
					eventVal2.visible = !isSkinEvent;
				if (eventSkinDropdown != null && eventSkinDropdown.visible != isSkinEvent)
					eventSkinDropdown.visible = isSkinEvent;
				if (eventLyricsCheck != null && eventLyricsCheck.visible != isLyricsEvent)
					eventLyricsCheck.visible = isLyricsEvent;
				if (eventCharOffsetLabel != null && eventCharOffsetLabel.visible != isChangeCharEvent)
					eventCharOffsetLabel.visible = isChangeCharEvent;
				if (eventCharXStepper != null && eventCharXStepper.visible != isChangeCharEvent)
					eventCharXStepper.visible = isChangeCharEvent;
				if (eventCharYStepper != null && eventCharYStepper.visible != isChangeCharEvent)
					eventCharYStepper.visible = isChangeCharEvent;
			}
			else
			{
				if (eventSkinDropdown != null && eventSkinDropdown.visible)
					eventSkinDropdown.visible = false;
				if (eventLyricsCheck != null && eventLyricsCheck.visible)
					eventLyricsCheck.visible = false;
				if (eventCharOffsetLabel != null && eventCharOffsetLabel.visible)
					eventCharOffsetLabel.visible = false;
				if (eventCharXStepper != null && eventCharXStepper.visible)
					eventCharXStepper.visible = false;
				if (eventCharYStepper != null && eventCharYStepper.visible)
					eventCharYStepper.visible = false;
			}
		}

		if ((eventVal1 != null && eventVal1.hasFocus) || (eventVal2 != null && eventVal2.hasFocus))
		{
			var evName:String = eventDropdown != null ? eventDropdown.selectedLabel : '';
			if (evName == 'Change Character' || evName == 'changeChar')
				syncCharSteppersFromValFields();
			if (curSelectedEvent != null)
				applySelectedEvent();
			if (eventLyricsCheck != null && eventLyricsCheck.visible && eventVal2 != null)
			{
				var curV2:String = eventVal2.text.toLowerCase();
				eventLyricsCheck.checked = (curV2.indexOf('digitalizado') != -1 || curV2.indexOf('typewriter') != -1 || curV2.indexOf('maquina') != -1 || curV2.indexOf('typed') != -1 || curV2 == 'true' || curV2 == '1' || curV2 == 'sim');
			}
		}

		var isTyping:Bool = isInputFocused();
		var justUnfocusedWithKey:Bool = false;
		if (isTyping)
		{
			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE)
			{
				if (curSelectedEvent != null)
					applySelectedEvent();
				if (typingShit != null && typingShit.text != null && typingShit.text.trim().length > 0)
					_song.song = typingShit.text.trim();
				unfocusAllInputs();
				isTyping = false;
				justUnfocusedWithKey = true;
			}
			else if (FlxG.keys.justPressed.TAB)
			{
				if (eventVal1 != null && eventVal1.hasFocus && eventVal2 != null && eventVal2.visible)
				{
					eventVal1.endFocus();
					eventVal2.startFocus();
				}
				else if (eventVal2 != null && eventVal2.hasFocus && eventVal1 != null && eventVal1.visible)
				{
					eventVal2.endFocus();
					eventVal1.startFocus();
				}
			}
		}

		if (!isTyping)
		{
			if (FlxG.keys.justPressed.ENTER && !justUnfocusedWithKey)
			{
				if (curSelectedEvent != null)
					applySelectedEvent();
				lastSection = curSection;

				PlayState.SONG = _song;
				songMusic.stop();
				vocals.stop();
				if (opponentVocals != null)
					opponentVocals.stop();
				CursorManager.reset();
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

			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;
			if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
				changeSection(curSection + shiftThing);
			if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
				changeSection(curSection - shiftThing);
		}

		_song.bpm = tempBpm;

		var songPosSec = FlxMath.roundDecimal(Conductor.songPosition / 1000, 2);
		var songLenSec = songMusic != null ? FlxMath.roundDecimal(songMusic.length / 1000, 2) : 0;
		var newBpmText = songPosSec
			+ " / "
			+ songLenSec
			+ "\nSection: "
			+ curSection
			+ "\nBeat: "
			+ curBeat
			+ "\nStep: "
			+ curStep;
		if (bpmTxt.text != newBpmText)
			bpmTxt.text = newBpmText;

		var pulseAlpha:Float = 0.4 + 0.6 * Math.sin(flixel.FlxG.game.ticks / 100);

		if (pulsingNoteSprite != null && pulsingNoteSprite.alive)
		{
			pulsingNoteSprite.alpha = pulseAlpha;
		}

		if (pulsingEventSprite != null && pulsingEventSprite.alive)
		{
			pulsingEventSprite.alpha = pulseAlpha;
		}

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
		for (n in curRenderedNotes.members) {
			if (n != null && n.alive && Math.abs(n.strumTime - strum) < 1 && n.noteData == data % 4 && n.mustPress == (data > 3)) {
				headNote = n;
				break;
			}
		}

		if (headNote == null) return;
		
		headNote.sustainLength = sus;
		if (pulsingNote != null && pulsingNote == curSelectedNote)
			pulsingNoteSprite = headNote;

		var toDelete = [];
		for (susNote in curRenderedSustains.members) {
			if (susNote != null && susNote.alive) {
				var p = susNote.prevNote;
				while (p != null && p.isSustainNote) p = p.prevNote;
				if (p == headNote) toDelete.push(susNote);
			}
		}
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

		var srcSec = _song.notes[daSec - sectionNum];
		var srcBpm = (srcSec.changeBPM && srcSec.bpm > 0) ? srcSec.bpm : _song.bpm;
		var srcStepCrochet = ((60 / srcBpm) * 1000) / 4;
		var timeOffset = srcStepCrochet * (srcSec.lengthInSteps * sectionNum);

		for (note in srcSec.sectionNotes)
		{
			var strum = note[0] + timeOffset;
			var copiedNote:Array<Dynamic> = [strum, note[1], note[2]];
			if (note.length > 3 && note[3] != null)
				copiedNote.push(note[3]);
			_song.notes[daSec].sectionNotes.push(copiedNote);
		}

		_song.notes[daSec].sectionNotes.sort(function(a:Dynamic, b:Dynamic):Int return a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0));
		updateGrid();
		autosaveSong();
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
		clearPulsing();

		for (n in curRenderedNotes.members)
		{
			if (n != null) n.destroy();
		}
		curRenderedNotes.clear();

		for (s in curRenderedSustains.members)
		{
			if (s != null) s.destroy();
		}
		curRenderedSustains.clear();

		for (e in curRenderedEvents.members)
		{
			if (e != null) e.destroy();
		}
		curRenderedEvents.clear();

		if (curRenderedEventChips != null)
		{
			for (c in curRenderedEventChips.members)
			{
				if (c != null) c.destroy();
			}
			curRenderedEventChips.clear();
		}
		if (curRenderedEventExtras != null)
		{
			for (ex in curRenderedEventExtras.members)
			{
				if (ex != null) ex.destroy();
			}
			curRenderedEventExtras.clear();
		}
		renderedEventChipsData = [];

		if (_song.events != null)
		{
			for (e in _song.events)
			{
				var evY = Math.floor(getYfromStrum(e[0]));
				var subList:Array<Dynamic> = (e.length > 1 && e[1] != null && Std.isOfType(e[1], Array)) ? cast e[1] : [];
				var groupTitle = getEventGroupName(e[0]);
				var isGroup = (subList.length > 1 || groupTitle != "");
				var isSelectedGroup = (curSelectedEvent == e);

				if (isGroup)
				{
					// Stacked card backing to visually signify multiple grouped events
					var stackBack = new FlxSprite(gridBG.x + (GRID_SIZE * 8) + 4, evY + 4).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, isSelectedGroup ? 0xFF00FFCC : 0xFF2A82BE);
					stackBack.alpha = 0.7;
					curRenderedEventExtras.add(stackBack);
				}

				var evSprite = new FlxSprite();
				evSprite.loadGraphic(Paths.image('menus/editors/chart/event_icon'));
				evSprite.setGraphicSize(GRID_SIZE, GRID_SIZE);
				evSprite.updateHitbox();
				evSprite.x = gridBG.x + (GRID_SIZE * 8);
				evSprite.y = evY;
				curRenderedEvents.add(evSprite);

				if (isGroup && curRenderedEventExtras != null)
				{
					// Count badge pill in top-right of column 8 icon
					var badgeBG = new FlxSprite(evSprite.x + GRID_SIZE - 15, evSprite.y + 1).makeGraphic(14, 12, isSelectedGroup ? 0xFF00FFCC : 0xFF1A1A2E);
					curRenderedEventExtras.add(badgeBG);

					var badgeTxt = new FlxText(evSprite.x + GRID_SIZE - 16, evSprite.y, 16, Std.string(subList.length), 8);
					badgeTxt.setFormat(Paths.font("vcr.ttf"), 8, isSelectedGroup ? FlxColor.BLACK : 0xFF00FFCC, CENTER, FlxTextBorderStyle.OUTLINE, isSelectedGroup ? 0xFF00FFCC : FlxColor.BLACK);
					curRenderedEventExtras.add(badgeTxt);

					if (groupTitle != "")
					{
						var gTitleTxt = new FlxText(gridBG.x + (GRID_SIZE * 9) + 6, evY - 1, 140, '[$groupTitle]', 8);
						gTitleTxt.setFormat(Paths.font("vcr.ttf"), 8, 0xFF00FFCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
						curRenderedEventExtras.add(gTitleTxt);
					}

					// Non-overlapping clickable side-by-side mini-chips for every sub-event in the group
					var baseChipY = evY + (groupTitle != "" ? 11 : 2);
					for (sIdx in 0...subList.length)
					{
						var sub = subList[sIdx];
						var subName:String = (sub != null && sub.length > 0 && sub[0] != null) ? Std.string(sub[0]) : "Event";
						var col = sIdx % 4;
						var row = Math.floor(sIdx / 4);
						var cx = gridBG.x + (GRID_SIZE * 9) + 6 + (col * 28);
						var cy = baseChipY + (row * 18);
						var isChipSel = (isSelectedGroup && curSelectedSubIndex == sIdx);

						var border = new FlxSprite(cx - 1, cy - 1).makeGraphic(26, 16, isChipSel ? 0xFFFFFFFF : 0xFF0F0F1A);
						curRenderedEventExtras.add(border);

						var chipSprite = new FlxSprite(cx, cy).makeGraphic(24, 14, getEventChipColor(subName));
						chipSprite.alpha = isChipSel ? 1.0 : 0.85;
						curRenderedEventChips.add(chipSprite);
						renderedEventChipsData.push({sprite: chipSprite, event: e, subIndex: sIdx});

						var tagTxt = new FlxText(cx, cy + 1, 24, getEventShortTag(subName), 8);
						tagTxt.setFormat(Paths.font("vcr.ttf"), 8, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
						curRenderedEventExtras.add(tagTxt);
					}
				}
				else if (subList.length == 1 && curRenderedEventExtras != null)
				{
					var singleName:String = (subList[0] != null && subList[0].length > 0 && subList[0][0] != null) ? Std.string(subList[0][0]) : "";
					if (singleName != "")
					{
						var miniTag = new FlxText(evSprite.x + GRID_SIZE - 18, evSprite.y + GRID_SIZE - 11, 18, getEventShortTag(singleName), 8);
						miniTag.setFormat(Paths.font("vcr.ttf"), 8, getEventChipColor(singleName), RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
						curRenderedEventExtras.add(miniTag);
					}
				}
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
			if (curSelectedNote != null && Math.abs(daStrumTime - curSelectedNote[0]) < 1 && (daNoteInfo % 4) == (curSelectedNote[1] % 4) && (i[1] > 3) == (curSelectedNote[1] > 3))
			{
				pulsingNote = curSelectedNote;
				pulsingNoteSprite = note;
			}

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
		curSelectedNote = null;
		var noteBaseData = note.noteData % 4;
		var isMustPress = note.mustPress;
		var expectedData = noteBaseData + (isMustPress ? 4 : 0);

		for (sec in 0..._song.notes.length)
		{
			for (i in _song.notes[sec].sectionNotes)
			{
				if (i != null && Math.abs(i[0] - note.strumTime) < 1 && i[1] == expectedData)
				{
					curSelectedNote = i;
					break;
				}
			}
			if (curSelectedNote != null) break;
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
			autosaveSong();
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
		autosaveSong();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
		autosaveSong();
	}

	private function addNote():Bool
	{
		var noteStrum = getStrumTime(dummyArrow.y);
		if (noteStrum < 0) return false;
		
		clearPulsing();

		var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);

		if (noteData == 8) {
			if (_song.events == null) _song.events = [];
			var selectedIdx:Int = Std.parseInt(eventDropdown.selectedId);
			var selectedEvent:String = (selectedIdx >= 0 && selectedIdx < eventsOptions.length) ? eventsOptions[selectedIdx] : eventDropdown.selectedLabel;
			var v1:String = eventVal1.text;
			var v2:String = (selectedEvent == 'Change Note Skins' && eventSkinDropdown != null) ? eventSkinDropdown.selectedLabel : eventVal2.text;

			var isCharEv:Bool = (selectedEvent == 'Change Character' || selectedEvent == 'changeChar');
			var parsedCharTarget:Int = 1;
			if (isCharEv)
			{
				var parsed = editors.camera.CameraEditorEvent.parseChangeCharParams(v1, v2);
				parsedCharTarget = parsed.target;
				var rawTokens = editors.camera.CameraEditorEvent.splitEventParams(v1);
				var targetToken:String = (rawTokens.length > 0 && editors.camera.CameraEditorEvent.isTargetToken(rawTokens[0]))
					? rawTokens[0]
					: Std.string(parsed.target);
				v1 = targetToken;
				if (parsed.x != null || parsed.y != null)
				{
					var px:Float = (parsed.x != null) ? parsed.x : 0;
					var py:Float = (parsed.y != null) ? parsed.y : 0;
					if (px != 0 || py != 0)
						v1 = '$targetToken, $px, $py';
				}
				if (parsed.charName != "")
					v2 = parsed.charName;
				eventVal1.text = v1;
				eventVal2.text = v2;
				syncCharSteppersFromValFields();
			}

			var forceAppendGroup:Bool = FlxG.keys.pressed.SHIFT;
			var newSubEv:Array<Dynamic> = [selectedEvent, v1, v2];
			var found = false;
			for (e in _song.events) {
				if (Math.abs(e[0] - noteStrum) < 2.0) {
					var subList:Array<Dynamic> = e[1];
					var replacedExisting = false;
					if (!forceAppendGroup)
					{
						for (sIdx in 0...subList.length)
						{
							var sub = subList[sIdx];
							if (sub != null && Std.string(sub[0]) == selectedEvent)
							{
								if (isCharEv)
								{
									var exParsed = editors.camera.CameraEditorEvent.parseChangeCharParams(
										Std.string(sub[1]),
										Std.string(sub[2])
									);
									if (exParsed.target == parsedCharTarget)
									{
										subList[sIdx] = newSubEv;
										replacedExisting = true;
										break;
									}
								}
								else
								{
									subList[sIdx] = newSubEv;
									replacedExisting = true;
									break;
								}
							}
						}
					}
					if (!replacedExisting)
						subList.push(newSubEv);

					subList.sort(function(sa:Dynamic, sb:Dynamic):Int {
						var na = (sa != null && sa.length > 0 && sa[0] != null) ? Std.string(sa[0]).toLowerCase().trim() : "";
						var nb = (sb != null && sb.length > 0 && sb[0] != null) ? Std.string(sb[0]).toLowerCase().trim() : "";
						var pa:Int = (na == "change character" || na == "changechar") ? 0 : ((na == "play anim" || na == "playanim" || na == "play animation") ? 1 : 2);
						var pb:Int = (nb == "change character" || nb == "changechar") ? 0 : ((nb == "play anim" || nb == "playanim" || nb == "play animation") ? 1 : 2);
						return pa - pb;
					});

					curSelectedEvent = e;
					curSelectedSubIndex = subList.indexOf(newSubEv);
					if (curSelectedSubIndex < 0) curSelectedSubIndex = 0;
					curSelectedNote = null;
					found = true;
					break;
				}
			}
			if (!found) {
				var newEv:Array<Dynamic> = [noteStrum, [newSubEv]];
				_song.events.push(newEv);
				curSelectedEvent = newEv;
				curSelectedSubIndex = 0;
				curSelectedNote = null;
			}
			UI_box.selected_tab_id = 'Events';
			updateGrid();
			refreshEventGroupUI();
			return false; // Cannot drag sustain on events
		}

		var noteType:Dynamic = (curNoteSkin != null && curNoteSkin != 'default' && curNoteSkin != '') ? curNoteSkin : null;
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

		if (noteType != null)
			_song.notes[targetSection].sectionNotes.push([noteStrum, noteData, noteSus, noteType]);
		else
			_song.notes[targetSection].sectionNotes.push([noteStrum, noteData, noteSus]);

		curSelectedNote = _song.notes[targetSection].sectionNotes[_song.notes[targetSection].sectionNotes.length - 1];

		if (FlxG.keys.pressed.CONTROL)
		{
			if (noteType != null)
				_song.notes[targetSection].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, noteType]);
			else
				_song.notes[targetSection].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus]);
		}

		var note:Note = FunkinArrows.generateArrow(PlayState.assetModifier, noteStrum, noteData % 4, noteType != null ? noteType : 0, 0);
		note.sustainLength = noteSus;
		note.noteType = noteType != null ? noteType : 0;
		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(noteData * GRID_SIZE);
		note.y = Math.floor(getYfromStrum(noteStrum));
		note.mustPress = (noteData > 3);
		curRenderedNotes.add(note);
		pulsingNote = curSelectedNote;
		pulsingNoteSprite = note;

		if (FlxG.keys.pressed.CONTROL)
		{
			var noteCtrl:Note = FunkinArrows.generateArrow(PlayState.assetModifier, noteStrum, ((noteData + 4) % 8) % 4, noteType != null ? noteType : 0, 0);
			noteCtrl.sustainLength = noteSus;
			noteCtrl.noteType = noteType != null ? noteType : 0;
			noteCtrl.setGraphicSize(GRID_SIZE, GRID_SIZE);
			noteCtrl.updateHitbox();
			noteCtrl.x = Math.floor(((noteData + 4) % 8) * GRID_SIZE);
			noteCtrl.y = Math.floor(getYfromStrum(noteStrum));
			noteCtrl.mustPress = (((noteData + 4) % 8) > 3);
			curRenderedNotes.add(noteCtrl);
		}

		updateNoteUI();
		autosaveSong();
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
		var diffSuffix = "";
		if (PlayState.storyDifficulty == 0) diffSuffix = "-easy";
		else if (PlayState.storyDifficulty == 2) diffSuffix = "-hard";
		var chartToLoad = song.toLowerCase() + diffSuffix;
		PlayState.SONG = Song.loadFromJson(chartToLoad, song.toLowerCase());
		FlxG.resetState();
	}

	function loadAutosave():Void
	{
		if (FlxG.save.data.autosave != null && Std.string(FlxG.save.data.autosave).trim().length > 0)
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			FlxG.resetState();
		}
	}

	function autosaveSong():Void
	{
		if (_song == null) return;
		_song.format = "gaze";
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	private function prepareSongForSave():Void
	{
		if (curSelectedEvent != null)
			applySelectedEvent();

		if (typingShit != null && typingShit.text != null && typingShit.text.trim().length > 0)
			_song.song = typingShit.text.trim();

		_song.format = "gaze";

		// Sort events chronologically and prioritize Change Character within each timestamp
		if (_song.events != null)
		{
			for (e in _song.events)
			{
				if (e != null && e.length > 1 && e[1] != null && Std.isOfType(e[1], Array))
				{
					var subList:Array<Dynamic> = cast e[1];
					subList.sort(function(sa:Dynamic, sb:Dynamic):Int {
						var na = (sa != null && sa.length > 0 && sa[0] != null) ? Std.string(sa[0]).toLowerCase().trim() : "";
						var nb = (sb != null && sb.length > 0 && sb[0] != null) ? Std.string(sb[0]).toLowerCase().trim() : "";
						var pa:Int = (na == "change character" || na == "changechar") ? 0 : ((na == "play anim" || na == "playanim" || na == "play animation") ? 1 : 2);
						var pb:Int = (nb == "change character" || nb == "changechar") ? 0 : ((nb == "play anim" || nb == "playanim" || nb == "play animation") ? 1 : 2);
						return pa - pb;
					});
				}
			}

			_song.events.sort(function(a:Dynamic, b:Dynamic):Int {
				var t1:Float = a[0];
				var t2:Float = b[0];
				if (t1 < t2) return -1;
				if (t1 > t2) return 1;
				return 0;
			});
		}
		else
		{
			_song.events = [];
		}

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

	private function saveLevel()
	{
		prepareSongForSave();

		var json = {
			"song": _song
		};
		var data:String = Json.stringify(json, null, "\t");

		#if sys
		var targetPath:String = loadedChartPath;
		if (targetPath == null || targetPath.trim() == "")
		{
			var songFolder:String = _song.song.toLowerCase().trim();
			var diffName:String = CoolUtil.difficultyFromNumber(PlayState.storyDifficulty).toLowerCase();
			var chartFileName:String = songFolder + (diffName == 'normal' ? '' : '-' + diffName);
			targetPath = gameplay.chart.ChartConverter.findChartPath(songFolder, chartFileName);

			if (targetPath == null)
				targetPath = 'assets/songs/$songFolder/$chartFileName.json';
		}

		try
		{
			var dir = haxe.io.Path.directory(targetPath);
			if (dir != null && dir.length > 0 && !sys.FileSystem.exists(dir))
				sys.FileSystem.createDirectory(dir);

			sys.io.File.saveContent(targetPath, data);
			loadedChartPath = targetPath;

			// Also update autosave
			FlxG.save.data.autosave = data;
			FlxG.save.flush();

			FlxG.sound.play(Paths.sound('confirm'));
			if (saveFeedbackText != null)
			{
				saveFeedbackText.text = 'SAVED TO: $targetPath';
				saveFeedbackText.alpha = 1;
			}
			FlxG.log.notice("Successfully saved chart to " + targetPath);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error("Problem saving chart to disk: " + e);
			// Fallback to Save As dialog
			saveLevelAs();
		}
		#else
		saveLevelAs();
		#end
	}

	private function saveLevelAs()
	{
		prepareSongForSave();

		var json = {
			"song": _song
		};
		var data:String = Json.stringify(json, null, "\t");

		if ((data != null) && (data.length > 0))
		{
			var songFolder:String = _song.song.toLowerCase().trim();
			var diffName:String = CoolUtil.difficultyFromNumber(PlayState.storyDifficulty).toLowerCase();
			var defaultFileName:String = songFolder + (diffName == 'normal' ? '' : '-' + diffName) + ".json";

			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), defaultFileName);
		}
	}

	private function exportPsychLevel()
	{
		prepareSongForSave();

		// Clone song structure with flipped notes for Psych Engine compatibility
		var psychNotes:Array<SwagSection> = [];
		for (sec in _song.notes)
		{
			var mustHit:Bool = sec.mustHitSection;
			var flippedNotes:Array<Dynamic> = [];

			for (n in sec.sectionNotes)
			{
				var strum:Float = n[0];
				var data:Int = n[1];
				var sus:Float = n[2];
				var type:Dynamic = (n.length > 3) ? n[3] : null;

				var psychData:Int = data;
				if (mustHit)
				{
					// In Psych: when mustHitSection is true, 0..3 is BF, 4..7 is Dad
					// In Gaze: 0..3 is Dad, 4..7 is BF
					if (data >= 4)
						psychData = data - 4; // BF -> 0..3
					else
						psychData = data + 4; // Dad -> 4..7
				}

				if (type != null)
					flippedNotes.push([strum, psychData, sus, type]);
				else
					flippedNotes.push([strum, psychData, sus]);
			}

			flippedNotes.sort(function(a:Dynamic, b:Dynamic):Int {
				var t1:Float = a[0];
				var t2:Float = b[0];
				if (t1 < t2) return -1;
				if (t1 > t2) return 1;
				return 0;
			});

			psychNotes.push({
				sectionNotes: flippedNotes,
				lengthInSteps: sec.lengthInSteps,
				typeOfSection: sec.typeOfSection,
				mustHitSection: sec.mustHitSection,
				bpm: sec.bpm,
				changeBPM: sec.changeBPM,
				altAnim: sec.altAnim
			});
		}

		var psychSong:Dynamic = {
			song: _song.song,
			notes: psychNotes,
			events: _song.events,
			bpm: _song.bpm,
			needsVoices: _song.needsVoices,
			speed: _song.speed,
			player1: _song.player1,
			player2: _song.player2,
			player3: _song.player3,
			gfVersion: _song.gfVersion,
			stage: _song.stage,
			validScore: true
		};

		var json = { "song": psychSong };
		var data:String = Json.stringify(json, null, "\t");

		if ((data != null) && (data.length > 0))
		{
			var songFolder:String = _song.song.toLowerCase().trim();
			var diffName:String = CoolUtil.difficultyFromNumber(PlayState.storyDifficulty).toLowerCase();
			var defaultFileName:String = songFolder + (diffName == 'normal' ? '' : '-' + diffName) + ".json";

			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), defaultFileName);
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

	override function destroy():Void
	{
		unfocusAllInputs();
		allSteppers = [];
		clearPulsing();

		if (songMusic != null || vocals != null || opponentVocals != null)
		{
			Utils.killMusic([songMusic, vocals, opponentVocals]);
			songMusic = null;
			vocals = null;
			opponentVocals = null;
		}

		if (dummyArrows != null)
		{
			for (d in dummyArrows)
			{
				if (d != null)
				{
					remove(d, true);
					d.destroy();
				}
			}
			dummyArrows = [];
		}
		dummyArrow = null;

		if (curRenderedNotes != null)
		{
			for (n in curRenderedNotes.members)
			{
				if (n != null) n.destroy();
			}
			curRenderedNotes.clear();
		}

		if (curRenderedSustains != null)
		{
			for (s in curRenderedSustains.members)
			{
				if (s != null) s.destroy();
			}
			curRenderedSustains.clear();
		}

		if (curRenderedEvents != null)
		{
			for (e in curRenderedEvents.members)
			{
				if (e != null) e.destroy();
			}
			curRenderedEvents.clear();
		}

		if (curRenderedEventChips != null)
		{
			for (c in curRenderedEventChips.members)
			{
				if (c != null) c.destroy();
			}
			curRenderedEventChips.clear();
		}

		if (curRenderedEventExtras != null)
		{
			for (ex in curRenderedEventExtras.members)
			{
				if (ex != null) ex.destroy();
			}
			curRenderedEventExtras.clear();
		}
		renderedEventChipsData = [];

		if (grabbedNoteProxy != null)
		{
			remove(grabbedNoteProxy, true);
			grabbedNoteProxy.destroy();
			grabbedNoteProxy = null;
		}

		if (dragStartPos != null)
		{
			dragStartPos = flixel.util.FlxDestroyUtil.put(dragStartPos);
		}

		CursorManager.reset();

		hitPlayerSound = null;
		hitOppSound = null;

		super.destroy();
	}
}



package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.text.FlxInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUICheckBox;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import core.base.MusicBeatState;
import core.utils.CoolUtil;
import gameplay.hud.HealthIcon;
import gameplay.objects.Character;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import core.system.Paths;
import core.system.CursorManager;

using StringTools;

class CharacterEditor extends MusicBeatState
{
	var char:Character;
	var ghost:Character;
	var curCharFile:CharacterFile;
	
	var UI_box:FlxUITabMenu;
	
	// Character UI
	var charDropDown:FlxUIDropDownMenu;
	var inputIcon:FlxInputText;
	var stepColorR:FlxUINumericStepper;
	var stepColorG:FlxUINumericStepper;
	var stepColorB:FlxUINumericStepper;
	var checkFlipX:FlxUICheckBox;
	var checkPlayer:FlxUICheckBox;
	var checkNoAntialiasing:FlxUICheckBox;
	var inputImage:FlxInputText;
	var stepScale:FlxUINumericStepper;
	var stepSingDuration:FlxUINumericStepper;
	var stepPosX:FlxUINumericStepper;
	var stepPosY:FlxUINumericStepper;
	var stepCamPosX:FlxUINumericStepper;
	var stepCamPosY:FlxUINumericStepper;
	var checkQuickDancer:FlxUICheckBox;
	
	// Animations UI
	var animDropDown:FlxUIDropDownMenu;
	var inputAnim:FlxInputText;
	var inputSuffix:FlxInputText;
	var stepFps:FlxUINumericStepper;
	var checkLoop:FlxUICheckBox;
	var inputIndices:FlxInputText;
	var checkGhost:FlxUICheckBox;
	
	// Data UI
	var dropGameOver:FlxUIDropDownMenu;
	var inputFirstDeath:FlxInputText;
	var inputLoopDeath:FlxInputText;
	var inputConfirmDeath:FlxInputText;
	var inputFirstDeathSound:FlxInputText;
	var inputLoopDeathMusic:FlxInputText;
	var inputConfirmDeathSound:FlxInputText;
	
	// Health Bar & Icon
	var healthBarBG:FlxSprite;
	var healthBar:FlxBar;
	var healthIcon:HealthIcon;

	// Icon UI
	var inputIconSuffix:FlxInputText;
	var stepIconBarOffsetX:FlxUINumericStepper;
	var stepIconBarOffsetY:FlxUINumericStepper;
	var stepIconScale:FlxUINumericStepper;
	var iconAnimDropDown:FlxUIDropDownMenu;
	var inputIconAnim:FlxInputText;
	var inputIconAnimSuffix:FlxInputText;
	var stepIconAnimFps:FlxUINumericStepper;
	var checkIconAnimLoop:FlxUICheckBox;
	var inputIconAnimIndices:FlxInputText;
	var stepIconAnimOffsetX:FlxUINumericStepper;
	var stepIconAnimOffsetY:FlxUINumericStepper;
	var curIconAnim:String = "neutral";
	
	// Camera marker
	var cameraCross:FlxText;

	var curAnim:String = "";
	var curCharName:String = "bf";
	var isPlayer:Bool = false;
	var lastLoadedChar:String = "";
	
	var camHUD:FlxCamera;
	var camGame:FlxCamera;
	
	var textAnim:FlxText;

	// Mouse control variables
	var draggingLeft:Bool = false;
	var draggingMiddle:Bool = false;
	var draggingRight:Bool = false;
	var lastMouseX:Float = 0;
	var lastMouseY:Float = 0;
	var lastMouseScreenX:Float = 0;
	var lastMouseScreenY:Float = 0;

	// Trackers for reactive UI
	var lastIcon:String = "";
	var lastR:Float = -1;
	var lastG:Float = -1;
	var lastB:Float = -1;
	var lastScale:Float = 1.0;
	var lastSingDur:Float = 4.0;
	var lastPosX:Float = 0;
	var lastPosY:Float = 0;
	var lastCamPosX:Float = 0;
	var lastCamPosY:Float = 0;
	var lastIconOffX:Float = 0;
	var lastIconOffY:Float = 0;
	var lastIconScale:Float = 1.0;

	var testAudioSound:flixel.sound.FlxSound;

	public function new(?character:String = "bf")
	{
		super();
		if (character != null && character.trim().length > 0)
			curCharName = character.trim();
	}

	override function create()
	{
		super.create();
		
		CursorManager.show();
		CursorManager.change('default');
		
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		
		var gridBG:FlxSprite = FlxGridOverlay.create(10, 10, FlxG.width * 2, FlxG.height * 2, true, 0xffe7e6e6, 0xffd9d5d5);
		gridBG.scrollFactor.set(0.5, 0.5);
		gridBG.screenCenter();
		add(gridBG);
		
		// Camera Cross (+)
		cameraCross = new FlxText(0, 0, 0, "(+)", 24);
		cameraCross.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
		cameraCross.borderSize = 1.5;
		cameraCross.scrollFactor.set(1, 1);
		cameraCross.cameras = [camGame];
		add(cameraCross);

		textAnim = new FlxText(20, 16, 0, "", 16);
		textAnim.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, LEFT, OUTLINE, 0xFF000000);
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

		// Health Bar & Icon
		healthBarBG = new FlxSprite(0, FlxG.height - 50);
		healthBarBG.loadGraphic(Paths.image('UI/healthBar', null, false));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.cameras = [camHUD];

		var detectedBounds:FlxRect = CoolUtil.detectHealthBarBounds(healthBarBG);
		var innerX:Float = (detectedBounds != null) ? detectedBounds.x : 4;
		var innerY:Float = (detectedBounds != null) ? detectedBounds.y : 4;
		var innerW:Int = (detectedBounds != null) ? Std.int(detectedBounds.width) : Std.int(healthBarBG.width - 8);
		var innerH:Int = (detectedBounds != null) ? Std.int(detectedBounds.height) : Std.int(healthBarBG.height - 8);

		healthBar = new FlxBar(healthBarBG.x + innerX, healthBarBG.y + innerY, RIGHT_TO_LEFT, innerW, innerH);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];
		healthBar.setRange(0, 2);
		healthBar.value = 1;
		add(healthBar);
		add(healthBarBG);

		healthIcon = new HealthIcon("face", isPlayer);
		healthIcon.cameras = [camHUD];
		healthIcon.scrollFactor.set();
		healthIcon.y = healthBar.y - (healthIcon.height / 2);
		add(healthIcon);
		
		var tabs = [
			{name: "Character", label: "Character"},
			{name: "Animations", label: "Animations"},
			{name: "Icon", label: "Icon"},
			{name: "Data", label: "Data"}
		];
		
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(320, 420);
		UI_box.x = FlxG.width - 345;
		UI_box.y = 20;
		UI_box.cameras = [camHUD];
		add(UI_box);
		
		addCharacterUI();
		addAnimationUI();
		addIconUI();
		addDataUI();
		
		loadChar(curCharName);

		lastMouseX = FlxG.mouse.x;
		lastMouseY = FlxG.mouse.y;
		lastMouseScreenX = FlxG.mouse.viewX;
		lastMouseScreenY = FlxG.mouse.viewY;
	}

	function addCharacterUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Character";
		
		var charsList = getCharactersList();
		if (!charsList.contains(curCharName))
			charsList.push(curCharName);

		charDropDown = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(charsList, true), function(character:String)
		{
			var idx = Std.parseInt(character);
			if (idx != null && idx >= 0 && idx < charsList.length)
				loadChar(charsList[idx]);
		});
		charDropDown.selectedLabel = curCharName;
		
		checkFlipX = new FlxUICheckBox(160, 25, null, null, "Flip X", 60);
		checkFlipX.callback = function() {
			if (curCharFile != null) curCharFile.flip_x = checkFlipX.checked;
			var daFlip = (isPlayer ? !checkFlipX.checked : checkFlipX.checked);
			if (char != null) char.flipX = daFlip;
			if (ghost != null) ghost.flipX = daFlip;
			updateCameraCross();
		};

		checkPlayer = new FlxUICheckBox(225, 25, null, null, "Player", 65);
		checkPlayer.checked = isPlayer;
		checkPlayer.callback = function() {
			isPlayer = checkPlayer.checked;
			loadChar(curCharName);
		};

		inputImage = new FlxInputText(10, 70, 205, "characters/bf", 8);
		var btnReloadImage = new FlxButton(225, 68, "Reload", function() {
			reloadImage();
		});

		checkNoAntialiasing = new FlxUICheckBox(10, 95, null, null, "No Antialiasing", 110);
		checkNoAntialiasing.callback = function() {
			var noAA = checkNoAntialiasing.checked;
			if (char != null) char.antialiasing = !noAA;
			if (ghost != null) ghost.antialiasing = !noAA;
			if (curCharFile != null) curCharFile.no_antialiasing = noAA;
		};

		inputIcon = new FlxInputText(10, 135, 130, "face", 8);
		var btnGetColor = new FlxButton(150, 133, "Get Color", function() {
			getIconColor();
		});

		stepColorR = new FlxUINumericStepper(10, 180, 1, 161, 0, 255);
		stepColorG = new FlxUINumericStepper(70, 180, 1, 161, 0, 255);
		stepColorB = new FlxUINumericStepper(130, 180, 1, 161, 0, 255);

		stepScale = new FlxUINumericStepper(10, 225, 0.05, 1, 0.05, 10, 2);
		stepSingDuration = new FlxUINumericStepper(80, 225, 0.5, 4, 0.5, 20, 1);
		stepPosX = new FlxUINumericStepper(150, 225, 5, 0, -5000, 5000);
		stepPosY = new FlxUINumericStepper(225, 225, 5, 0, -5000, 5000);

		stepCamPosX = new FlxUINumericStepper(10, 275, 5, 0, -5000, 5000);
		stepCamPosY = new FlxUINumericStepper(85, 275, 5, 0, -5000, 5000);
		checkQuickDancer = new FlxUICheckBox(165, 275, null, null, "Quick Dancer", 100);
		checkQuickDancer.callback = function() {
			if (char != null && char.characterData != null) char.characterData.quickDancer = checkQuickDancer.checked;
			if (curCharFile != null) curCharFile.quickDancer = checkQuickDancer.checked;
		};

		var btnTemplate = new FlxButton(10, 320, "Create Template", function() {
			createTemplate();
		});

		var saveBtn = new FlxButton(150, 320, "Save Character", function() {
			saveCharacter();
		});
		
		tab.add(new FlxText(10, 10, 0, "Character:"));
		tab.add(checkFlipX);
		tab.add(checkPlayer);

		tab.add(new FlxText(10, 55, 0, "Image Path:"));
		tab.add(inputImage);
		tab.add(btnReloadImage);

		tab.add(checkNoAntialiasing);

		tab.add(new FlxText(10, 120, 0, "Health Icon:"));
		tab.add(inputIcon);
		tab.add(btnGetColor);

		tab.add(new FlxText(10, 165, 0, "Color (R / G / B):"));
		tab.add(stepColorR);
		tab.add(stepColorG);
		tab.add(stepColorB);

		tab.add(new FlxText(10, 210, 0, "Scale:"));
		tab.add(new FlxText(80, 210, 0, "Sing Dur:"));
		tab.add(new FlxText(150, 210, 0, "Position (X / Y):"));
		tab.add(stepScale);
		tab.add(stepSingDuration);
		tab.add(stepPosX);
		tab.add(stepPosY);

		tab.add(new FlxText(10, 260, 0, "Camera Offset (X / Y):"));
		tab.add(stepCamPosX);
		tab.add(stepCamPosY);
		tab.add(checkQuickDancer);

		tab.add(btnTemplate);
		tab.add(saveBtn);

		// Dropdown added last so dropPanel appears on top of other elements
		tab.add(charDropDown);
		
		UI_box.addGroup(tab);
	}
	
	function addAnimationUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Animations";
		
		animDropDown = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(["idle"], true), function(animIndex:String)
		{
			var idx = Std.parseInt(animIndex);
			var anims = getAnimList();
			if (idx != null && idx >= 0 && idx < anims.length)
			{
				curAnim = anims[idx];
				loadAnimToUI(curAnim);
				if (char != null) char.playAnim(curAnim);
				updateGhost();
			}
		});
		
		checkGhost = new FlxUICheckBox(160, 25, null, null, "Show Ghost", 100);
		checkGhost.checked = true;
		checkGhost.callback = function() {
			if (ghost != null) ghost.visible = checkGhost.checked;
		};

		inputAnim = new FlxInputText(10, 75, 120, "idle", 8);
		inputSuffix = new FlxInputText(140, 75, 140, "idle", 8);

		stepFps = new FlxUINumericStepper(10, 120, 1, 24, 1, 120);
		checkLoop = new FlxUICheckBox(100, 120, null, null, "Loop", 70);

		inputIndices = new FlxInputText(10, 165, 270, "", 8);

		var addAnimBtn = new FlxButton(10, 210, "Add/Update", function() {
			addOrUpdateAnimation();
		});

		var removeAnimBtn = new FlxButton(100, 210, "Remove", function() {
			removeAnimation();
		});

		var applyOffsetsBtn = new FlxButton(190, 210, "Print Offsets", function() {
			if (char != null) trace(char.animOffsets);
		});
		
		tab.add(new FlxText(10, 10, 0, "Select Animation:"));
		tab.add(checkGhost);
		tab.add(new FlxText(10, 60, 0, "Animation:"));
		tab.add(new FlxText(140, 60, 0, "Anim Suffix in XML:"));
		tab.add(inputAnim);
		tab.add(inputSuffix);
		tab.add(new FlxText(10, 105, 0, "Anim FPS:"));
		tab.add(stepFps);
		tab.add(checkLoop);
		tab.add(new FlxText(10, 150, 0, "Indices (e.g. 0,1,2):"));
		tab.add(inputIndices);
		tab.add(addAnimBtn);
		tab.add(removeAnimBtn);
		tab.add(applyOffsetsBtn);
		tab.add(animDropDown);
		
		UI_box.addGroup(tab);
	}

	function addDataUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Data";

		var charsList = getCharactersList();
		var defaultGameOver = (curCharFile != null && curCharFile.gameOverChar != null) ? curCharFile.gameOverChar : "bf-dead";
		if (!charsList.contains(defaultGameOver))
			charsList.push(defaultGameOver);

		dropGameOver = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(charsList, true), function(selected:String)
		{
			var idx = Std.parseInt(selected);
			if (idx != null && idx >= 0 && idx < charsList.length && curCharFile != null)
				curCharFile.gameOverChar = charsList[idx];
		});
		dropGameOver.selectedLabel = defaultGameOver;

		inputFirstDeath = new FlxInputText(10, 75, 120, "firstDeath", 8);
		inputLoopDeath = new FlxInputText(140, 75, 120, "deathLoop", 8);
		inputConfirmDeath = new FlxInputText(10, 120, 120, "deathConfirm", 8);

		inputFirstDeathSound = new FlxInputText(10, 165, 120, "gameover/fnf_loss_sfx", 8);
		inputLoopDeathMusic = new FlxInputText(140, 165, 120, "gameover/gameOver", 8);
		inputConfirmDeathSound = new FlxInputText(10, 210, 120, "gameover/gameOverEnd", 8);

		var btnTestAudio = new FlxButton(140, 208, "Test Audio", function() {
			testDeathAudio();
		});

		tab.add(new FlxText(10, 10, 0, "GameOver Json:"));
		tab.add(new FlxText(10, 60, 0, "FirstDeath:"));
		tab.add(new FlxText(140, 60, 0, "LoopDeath:"));
		tab.add(inputFirstDeath);
		tab.add(inputLoopDeath);
		tab.add(new FlxText(10, 105, 0, "ConfirmDeath:"));
		tab.add(inputConfirmDeath);
		tab.add(new FlxText(10, 150, 0, "FirstDeath Sound:"));
		tab.add(new FlxText(140, 150, 0, "LoopDeath Music:"));
		tab.add(inputFirstDeathSound);
		tab.add(inputLoopDeathMusic);
		tab.add(new FlxText(10, 195, 0, "ConfirmDeath Sound:"));
		tab.add(inputConfirmDeathSound);
		tab.add(btnTestAudio);
		tab.add(dropGameOver);

		UI_box.addGroup(tab);
	}
	
	function addIconUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Icon";

		inputIconSuffix = new FlxInputText(10, 25, 140, "", 8);
		var btnApplySuffix = new FlxButton(160, 23, "Apply Suffix", function() {
			if (curCharFile == null) return;
			curCharFile.icon_suffix = inputIconSuffix.text.trim();
			if (healthIcon != null)
			{
				healthIcon.iconSuffix = curCharFile.icon_suffix;
				healthIcon.autoSetupAnimations(curCharFile.icon_suffix);
				updateIconPos();
			}
		});

		stepIconBarOffsetX = new FlxUINumericStepper(10, 70, 1, 0, -500, 500);
		stepIconBarOffsetY = new FlxUINumericStepper(80, 70, 1, 0, -500, 500);
		stepIconScale = new FlxUINumericStepper(160, 70, 0.05, 1, 0.1, 5, 2);

		var stateList = ["neutral", "losing", "winning"];
		iconAnimDropDown = new FlxUIDropDownMenu(10, 115, FlxUIDropDownMenu.makeStrIdLabelArray(stateList, true), function(selected:String) {
			var idx = Std.parseInt(selected);
			if (idx != null && idx >= 0 && idx < stateList.length) {
				curIconAnim = stateList[idx];
				loadIconAnimToUI(curIconAnim);
				if (healthIcon != null) healthIcon.playAnim(curIconAnim, true);
			}
		});

		inputIconAnim = new FlxInputText(10, 160, 90, "neutral", 8);
		inputIconAnimSuffix = new FlxInputText(110, 160, 140, "neutral", 8);

		stepIconAnimFps = new FlxUINumericStepper(10, 205, 1, 24, 1, 120);
		checkIconAnimLoop = new FlxUICheckBox(80, 205, null, null, "Loop", 55);
		checkIconAnimLoop.checked = true;

		stepIconAnimOffsetX = new FlxUINumericStepper(145, 205, 1, 0, -500, 500);
		stepIconAnimOffsetY = new FlxUINumericStepper(205, 205, 1, 0, -500, 500);

		inputIconAnimIndices = new FlxInputText(10, 245, 245, "", 8);

		var btnAddIconAnim = new FlxButton(10, 275, "Add/Update", function() {
			addOrUpdateIconAnimation();
		});

		var btnAutoXml = new FlxButton(95, 275, "Auto XML", function() {
			autoDetectIconFromXml();
		});

		var btnRemoveIconAnim = new FlxButton(180, 275, "Remove", function() {
			removeIconAnimation();
		});

		var btnTestLose = new FlxButton(10, 308, "Lose 15%", function() {
			previewHealthState(15);
		});
		var btnTestNeutral = new FlxButton(95, 308, "Neutral 50%", function() {
			previewHealthState(50);
		});
		var btnTestWin = new FlxButton(180, 308, "Win 90%", function() {
			previewHealthState(90);
		});

		tab.add(new FlxText(10, 10, 0, "Icon Suffix:"));
		tab.add(inputIconSuffix);
		tab.add(btnApplySuffix);

		tab.add(new FlxText(10, 55, 0, "Bar Offsets (X / Y):"));
		tab.add(new FlxText(160, 55, 0, "Scale:"));
		tab.add(stepIconBarOffsetX);
		tab.add(stepIconBarOffsetY);
		tab.add(stepIconScale);

		tab.add(new FlxText(10, 100, 0, "Select State:"));

		tab.add(new FlxText(10, 145, 0, "State:"));
		tab.add(new FlxText(110, 145, 0, "Anim Suffix in XML:"));
		tab.add(inputIconAnim);
		tab.add(inputIconAnimSuffix);

		tab.add(new FlxText(10, 190, 0, "FPS:"));
		tab.add(new FlxText(145, 190, 0, "Anim Offsets:"));
		tab.add(stepIconAnimFps);
		tab.add(checkIconAnimLoop);
		tab.add(stepIconAnimOffsetX);
		tab.add(stepIconAnimOffsetY);

		tab.add(new FlxText(10, 230, 0, "Indices (optional, e.g. 0,1,2):"));
		tab.add(inputIconAnimIndices);

		tab.add(btnAddIconAnim);
		tab.add(btnAutoXml);
		tab.add(btnRemoveIconAnim);

		tab.add(btnTestLose);
		tab.add(btnTestNeutral);
		tab.add(btnTestWin);

		// Dropdown added last so dropPanel appears on top of other elements
		tab.add(iconAnimDropDown);

		UI_box.addGroup(tab);
	}

	function updateIconPos()
	{
		if (healthIcon == null || healthBar == null) return;
		healthIcon.updateHitbox();
		var percentMath:Float = (healthBar != null) ? (1.0 - (healthBar.value / 2.0)) : 0.5;
		var iconPos:Float = healthBar.x + (healthBar.width * percentMath);
		var offX:Float = (healthIcon.iconOffsets != null && healthIcon.iconOffsets.length >= 1) ? healthIcon.iconOffsets[0] : 0;
		var offY:Float = (healthIcon.iconOffsets != null && healthIcon.iconOffsets.length >= 2) ? healthIcon.iconOffsets[1] : 0;

		healthIcon.x = iconPos - (healthIcon.width / 2) + offX;
		healthIcon.y = healthBar.y - (healthIcon.height / 2) + offY;
	}

	function previewHealthState(percent:Float)
	{
		if (healthBar != null)
		{
			healthBar.value = (percent / 100.0) * 2.0;
			healthBar.updateBar();
		}
		if (healthIcon != null)
		{
			healthIcon.updateAnim(percent);
			updateIconPos();
		}
	}

	function loadIconAnimToUI(stateName:String)
	{
		if (inputIconAnim != null) inputIconAnim.text = stateName;
		if (curCharFile != null && curCharFile.icon_animations != null)
		{
			for (a in curCharFile.icon_animations)
			{
				if (a != null && a.anim == stateName)
				{
					if (inputIconAnimSuffix != null) inputIconAnimSuffix.text = a.name != null ? a.name : "";
					if (stepIconAnimFps != null) stepIconAnimFps.value = a.fps > 0 ? a.fps : 24;
					if (checkIconAnimLoop != null) checkIconAnimLoop.checked = a.loop != false;
					if (inputIconAnimIndices != null) inputIconAnimIndices.text = (a.indices != null && a.indices.length > 0) ? a.indices.join(", ") : "";
					if (stepIconAnimOffsetX != null && stepIconAnimOffsetY != null)
					{
						if (a.offsets != null && a.offsets.length >= 2)
						{
							stepIconAnimOffsetX.value = a.offsets[0];
							stepIconAnimOffsetY.value = a.offsets[1];
						}
						else
						{
							stepIconAnimOffsetX.value = 0;
							stepIconAnimOffsetY.value = 0;
						}
					}
					return;
				}
			}
		}

		var suffix = (inputIconSuffix != null) ? inputIconSuffix.text.trim() : "";
		if (inputIconAnimSuffix != null) inputIconAnimSuffix.text = stateName + suffix;
		if (stepIconAnimFps != null) stepIconAnimFps.value = 24;
		if (checkIconAnimLoop != null) checkIconAnimLoop.checked = true;
		if (inputIconAnimIndices != null) inputIconAnimIndices.text = "";
		if (stepIconAnimOffsetX != null) stepIconAnimOffsetX.value = 0;
		if (stepIconAnimOffsetY != null) stepIconAnimOffsetY.value = 0;
	}

	function addOrUpdateIconAnimation()
	{
		if (curCharFile == null || inputIconAnim == null) return;
		var aName = inputIconAnim.text.trim();
		if (aName.length == 0) return;
		var aSuffix = inputIconAnimSuffix != null ? inputIconAnimSuffix.text.trim() : aName;
		var aFps = stepIconAnimFps != null ? Std.int(stepIconAnimFps.value) : 24;
		var aLoop = checkIconAnimLoop != null ? checkIconAnimLoop.checked : true;

		var indicesArr:Array<Int> = [];
		if (inputIconAnimIndices != null && inputIconAnimIndices.text.trim().length > 0)
		{
			var parts = inputIconAnimIndices.text.trim().split(',');
			for (p in parts)
			{
				var val = Std.parseInt(p.trim());
				if (val != null) indicesArr.push(val);
			}
		}

		var offsetsArr:Array<Float> = [
			stepIconAnimOffsetX != null ? stepIconAnimOffsetX.value : 0,
			stepIconAnimOffsetY != null ? stepIconAnimOffsetY.value : 0
		];

		var newAnim:CharacterAnim = {
			anim: aName,
			name: aSuffix,
			fps: aFps,
			loop: aLoop,
			indices: indicesArr,
			offsets: offsetsArr
		};

		if (curCharFile.icon_animations == null) curCharFile.icon_animations = [];
		var found = false;
		for (i in 0...curCharFile.icon_animations.length)
		{
			if (curCharFile.icon_animations[i] != null && curCharFile.icon_animations[i].anim == aName)
			{
				curCharFile.icon_animations[i] = newAnim;
				found = true;
				break;
			}
		}
		if (!found) curCharFile.icon_animations.push(newAnim);

		if (healthIcon != null)
		{
			healthIcon.applyIconAnimations(curCharFile.icon_animations);
			healthIcon.playAnim(aName, true);
			updateIconPos();
		}
	}

	function autoDetectIconFromXml()
	{
		if (healthIcon == null || healthIcon.frames == null) return;
		var suffix = (inputIconSuffix != null) ? inputIconSuffix.text.trim() : "";
		healthIcon.autoSetupAnimations(suffix);

		if (curCharFile == null) return;
		curCharFile.icon_animations = [];

		var uniquePrefixes:Array<String> = [];
		if (healthIcon.frames.frames != null)
		{
			for (f in healthIcon.frames.frames)
			{
				if (f == null || f.name == null) continue;
				var prefix = HealthIcon.stripFrameNumbers(f.name);
				if (prefix.length > 0 && !uniquePrefixes.contains(prefix))
					uniquePrefixes.push(prefix);
			}
		}

		var neutralMatch:String = HealthIcon.findBestMatch(uniquePrefixes, ["neutral", "idle", "normal"], suffix);
		var losingMatch:String = HealthIcon.findBestMatch(uniquePrefixes, ["losing", "lose", "defeat", "danger", "dead"], suffix);
		var winningMatch:String = HealthIcon.findBestMatch(uniquePrefixes, ["winning", "win", "victory"], suffix);

		if (neutralMatch != null)
		{
			curCharFile.icon_animations.push({
				anim: "neutral",
				name: neutralMatch,
				fps: 24,
				loop: true,
				indices: [],
				offsets: [0, 0]
			});
		}
		if (losingMatch != null)
		{
			curCharFile.icon_animations.push({
				anim: "losing",
				name: losingMatch,
				fps: 24,
				loop: true,
				indices: [],
				offsets: [0, 0]
			});
		}
		if (winningMatch != null)
		{
			curCharFile.icon_animations.push({
				anim: "winning",
				name: winningMatch,
				fps: 24,
				loop: true,
				indices: [],
				offsets: [0, 0]
			});
		}

		loadIconAnimToUI(curIconAnim);
		updateIconPos();
	}

	function removeIconAnimation()
	{
		if (curCharFile == null || curCharFile.icon_animations == null || inputIconAnim == null) return;
		var aName = inputIconAnim.text.trim();
		for (i in 0...curCharFile.icon_animations.length)
		{
			if (curCharFile.icon_animations[i] != null && curCharFile.icon_animations[i].anim == aName)
			{
				curCharFile.icon_animations.splice(i, 1);
				break;
			}
		}
		loadIconAnimToUI(curIconAnim);
	}

	function getCharactersList():Array<String>
	{
		return CoolUtil.getCharacterList();
	}
	
	function getAnimList():Array<String>
	{
		var list = [];
		if (char != null) {
			list = char.getAnimList();
		}
		return list;
	}
	
	function loadChar(name:String)
	{
		curCharName = name;

		// Detect default Player side if switching to a new character
		if (name != lastLoadedChar)
		{
			lastLoadedChar = name;
			isPlayer = name.startsWith('bf');
			if (checkPlayer != null)
				checkPlayer.checked = isPlayer;
		}
		else if (checkPlayer != null)
		{
			isPlayer = checkPlayer.checked;
		}
		
		if (char != null) {
			remove(char);
			char.destroy();
		}
		if (ghost != null) {
			remove(ghost);
			ghost.destroy();
		}
		
		var jsonPath = Paths.getPath('data/char/' + curCharName + '.json', TEXT);
		if (sys.FileSystem.exists(jsonPath))
		{
			try {
				var rawJson = sys.io.File.getContent(jsonPath);
				curCharFile = haxe.Json.parse(rawJson);
			} catch (e:Dynamic) {
				trace("Error parsing character JSON: " + e);
				curCharFile = createDefaultTemplate();
			}
		}
		else
		{
			curCharFile = createDefaultTemplate();
		}

		ghost = new Character(isPlayer);
		ghost.curCharacter = curCharName;
		ghost.debugMode = true;
		ghost.alpha = 0.5;
		if (checkGhost != null) {
			ghost.visible = checkGhost.checked;
		}
		add(ghost);
		
		char = new Character(isPlayer);
		char.curCharacter = curCharName;
		char.debugMode = true;
		add(char);
		
		char.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		ghost.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);

		if (char.cameraPosition == null || char.cameraPosition.length < 2)
			char.cameraPosition = [0, 0];
		if (curCharFile.camera_position == null || curCharFile.camera_position.length < 2)
			curCharFile.camera_position = [char.cameraPosition[0], char.cameraPosition[1]];
		
		// Update Character UI
		if (inputIcon != null) {
			inputIcon.text = curCharFile.healthicon != null ? curCharFile.healthicon : "face";
			lastIcon = inputIcon.text;
		}
		if (inputImage != null) {
			inputImage.text = curCharFile.image != null ? curCharFile.image : "characters/bf";
		}
		if (stepColorR != null && stepColorG != null && stepColorB != null) {
			var colors = (curCharFile.healthbar_colors != null && curCharFile.healthbar_colors.length > 2) ? curCharFile.healthbar_colors : [161, 161, 161];
			stepColorR.value = colors[0];
			stepColorG.value = colors[1];
			stepColorB.value = colors[2];
			lastR = colors[0];
			lastG = colors[1];
			lastB = colors[2];
		}
		if (checkFlipX != null) {
			checkFlipX.checked = (curCharFile.flip_x == true);
		}
		if (checkPlayer != null) {
			checkPlayer.checked = isPlayer;
		}
		if (checkNoAntialiasing != null) {
			checkNoAntialiasing.checked = (curCharFile.no_antialiasing == true);
		}
		if (checkQuickDancer != null) {
			checkQuickDancer.checked = (curCharFile.quickDancer == true);
		}
		if (stepScale != null) {
			stepScale.value = (curCharFile.scale != null && curCharFile.scale > 0) ? curCharFile.scale : 1.0;
			lastScale = stepScale.value;
		}
		if (stepSingDuration != null) {
			stepSingDuration.value = (curCharFile.sing_duration != null && curCharFile.sing_duration > 0) ? curCharFile.sing_duration : 4.0;
			lastSingDur = stepSingDuration.value;
		}
		if (stepPosX != null && stepPosY != null) {
			var px:Float = (curCharFile.position != null && curCharFile.position.length >= 1) ? curCharFile.position[0] : 0;
			var py:Float = (curCharFile.position != null && curCharFile.position.length >= 2) ? curCharFile.position[1] : 0;
			stepPosX.value = px;
			stepPosY.value = py;
			lastPosX = px;
			lastPosY = py;
		}
		if (stepCamPosX != null && stepCamPosY != null) {
			var cx:Float = (curCharFile.camera_position != null && curCharFile.camera_position.length >= 1) ? curCharFile.camera_position[0] : 0;
			var cy:Float = (curCharFile.camera_position != null && curCharFile.camera_position.length >= 2) ? curCharFile.camera_position[1] : 0;
			stepCamPosX.value = cx;
			stepCamPosY.value = cy;
			lastCamPosX = cx;
			lastCamPosY = cy;
		}

		// Update Icon UI
		if (stepIconBarOffsetX != null && stepIconBarOffsetY != null)
		{
			if (curCharFile.icon_offsets != null && curCharFile.icon_offsets.length >= 2)
			{
				stepIconBarOffsetX.value = curCharFile.icon_offsets[0];
				stepIconBarOffsetY.value = curCharFile.icon_offsets[1];
			}
			else
			{
				stepIconBarOffsetX.value = 0;
				stepIconBarOffsetY.value = 0;
			}
			lastIconOffX = stepIconBarOffsetX.value;
			lastIconOffY = stepIconBarOffsetY.value;
		}
		if (inputIconSuffix != null)
			inputIconSuffix.text = curCharFile.icon_suffix != null ? curCharFile.icon_suffix : "";
		if (stepIconScale != null) {
			stepIconScale.value = (curCharFile.icon_scale != null && curCharFile.icon_scale > 0) ? curCharFile.icon_scale : 1.0;
			lastIconScale = stepIconScale.value;
		}
		loadIconAnimToUI(curIconAnim);

		// Update Data UI
		if (dropGameOver != null) {
			dropGameOver.selectedLabel = curCharFile.gameOverChar != null ? curCharFile.gameOverChar : "bf-dead";
		}
		if (inputFirstDeath != null) {
			inputFirstDeath.text = curCharFile.firstDeath != null ? curCharFile.firstDeath : "firstDeath";
		}
		if (inputLoopDeath != null) {
			inputLoopDeath.text = curCharFile.loopDeath != null ? curCharFile.loopDeath : "deathLoop";
		}
		if (inputConfirmDeath != null) {
			inputConfirmDeath.text = curCharFile.confirmDeath != null ? curCharFile.confirmDeath : "deathConfirm";
		}
		if (inputFirstDeathSound != null) {
			inputFirstDeathSound.text = curCharFile.firstDeathSound != null ? curCharFile.firstDeathSound : "gameover/fnf_loss_sfx";
		}
		if (inputLoopDeathMusic != null) {
			inputLoopDeathMusic.text = curCharFile.loopDeathMusic != null ? curCharFile.loopDeathMusic : "gameover/gameOver";
		}
		if (inputConfirmDeathSound != null) {
			inputConfirmDeathSound.text = curCharFile.confirmDeathSound != null ? curCharFile.confirmDeathSound : "gameover/gameOverEnd";
		}
		
		var anims = getAnimList();
		if (anims.length > 0) {
			curAnim = anims[0];
			char.playAnim(curAnim);
		}
		else
		{
			curAnim = "";
		}
		
		if (animDropDown != null) {
			var dropAnims = anims.length > 0 ? anims : [""];
			animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(dropAnims, true));
			animDropDown.selectedLabel = curAnim;
		}

		// Re-add cameraCross so it renders on top of char and ghost
		if (cameraCross != null)
		{
			remove(cameraCross);
			add(cameraCross);
		}

		loadAnimToUI(curAnim);
		updateGhost();
		updateHealthBar(true);
		updateCameraCross();
	}

	function createDefaultTemplate():CharacterFile
	{
		return {
			animations: [
				{anim: "idle", name: "idle", fps: 24, loop: false, indices: [], offsets: [0, 0]},
				{anim: "singLEFT", name: "left", fps: 24, loop: false, indices: [], offsets: [0, 0]},
				{anim: "singDOWN", name: "down", fps: 24, loop: false, indices: [], offsets: [0, 0]},
				{anim: "singUP", name: "up", fps: 24, loop: false, indices: [], offsets: [0, 0]},
				{anim: "singRIGHT", name: "right", fps: 24, loop: false, indices: [], offsets: [0, 0]}
			],
			image: "characters/bf",
			scale: 1,
			sing_duration: 4,
			healthicon: "face",
			position: [0, 0],
			camera_position: [0, 0],
			flip_x: false,
			no_antialiasing: false,
			healthbar_colors: [161, 161, 161],
			gameOverChar: "bf-dead",
			firstDeath: "firstDeath",
			loopDeath: "deathLoop",
			confirmDeath: "deathConfirm",
			firstDeathSound: "gameover/fnf_loss_sfx",
			loopDeathMusic: "gameover/gameOver",
			confirmDeathSound: "gameover/gameOverEnd"
		};
	}

	function createTemplate()
	{
		curCharName = "template";
		curCharFile = createDefaultTemplate();
		loadChar("template");
	}

	function reloadImage()
	{
		if (curCharFile == null) return;
		curCharFile.image = inputImage.text.trim();
		if (char != null) char.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		if (ghost != null) ghost.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		if (curAnim.length > 0 && char != null) char.playAnim(curAnim, true);
		updateGhost();
		updateCameraCross();
	}

	function loadAnimToUI(animName:String)
	{
		if (inputAnim != null) inputAnim.text = animName;
		if (curCharFile == null || curCharFile.animations == null) return;
		for (a in curCharFile.animations)
		{
			if (a != null && a.anim == animName)
			{
				if (inputSuffix != null) inputSuffix.text = a.name != null ? a.name : "";
				if (stepFps != null) stepFps.value = a.fps > 0 ? a.fps : 24;
				if (checkLoop != null) checkLoop.checked = a.loop == true;
				if (inputIndices != null) inputIndices.text = (a.indices != null && a.indices.length > 0) ? a.indices.join(", ") : "";
				return;
			}
		}
		if (inputSuffix != null) inputSuffix.text = animName;
		if (stepFps != null) stepFps.value = 24;
		if (checkLoop != null) checkLoop.checked = false;
		if (inputIndices != null) inputIndices.text = "";
	}

	function addOrUpdateAnimation()
	{
		if (curCharFile == null || char == null || ghost == null) return;
		var aName = inputAnim.text.trim();
		if (aName.length == 0) return;

		var aSuffix = inputSuffix.text.trim();
		var aFps = Std.int(stepFps.value);
		var aLoop = checkLoop.checked;

		var indicesArr:Array<Int> = [];
		if (inputIndices.text.trim().length > 0)
		{
			var parts = inputIndices.text.trim().split(',');
			for (p in parts)
			{
				var val = Std.parseInt(p.trim());
				if (val != null) indicesArr.push(val);
			}
		}

		var animOffsets:Array<Float> = [0, 0];
		if (char.animOffsets.exists(aName) && char.animOffsets.get(aName) != null && char.animOffsets.get(aName).length >= 2)
		{
			animOffsets = [char.animOffsets.get(aName)[0], char.animOffsets.get(aName)[1]];
		}
		else if (curCharFile.animations != null)
		{
			for (a in curCharFile.animations)
			{
				if (a != null && a.anim == aName && a.offsets != null && a.offsets.length >= 2)
				{
					animOffsets = [a.offsets[0], a.offsets[1]];
					break;
				}
			}
		}

		var newAnimData:CharacterAnim = {
			anim: aName,
			name: aSuffix,
			fps: aFps,
			loop: aLoop,
			indices: indicesArr,
			offsets: animOffsets
		};

		var found:Bool = false;
		if (curCharFile.animations == null) curCharFile.animations = [];
		for (i in 0...curCharFile.animations.length)
		{
			if (curCharFile.animations[i] != null && curCharFile.animations[i].anim == aName)
			{
				curCharFile.animations[i] = newAnimData;
				found = true;
				break;
			}
		}
		if (!found)
		{
			curCharFile.animations.push(newAnimData);
		}

		char.addAnimationFromData(newAnimData);
		ghost.addAnimationFromData(newAnimData);

		curAnim = aName;
		var anims = getAnimList();
		if (!anims.contains(curAnim)) anims.push(curAnim);
		animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, true));
		animDropDown.selectedLabel = curAnim;

		char.playAnim(curAnim, true);
		updateGhost();
	}

	function removeAnimation()
	{
		if (curCharFile == null || curCharFile.animations == null || char == null || ghost == null || curAnim.length == 0) return;
		for (i in 0...curCharFile.animations.length)
		{
			if (curCharFile.animations[i] != null && curCharFile.animations[i].anim == curAnim)
			{
				curCharFile.animations.splice(i, 1);
				break;
			}
		}
		if (char.animOffsets.exists(curAnim))
			char.animOffsets.remove(curAnim);
		if (ghost.animOffsets.exists(curAnim))
			ghost.animOffsets.remove(curAnim);

		if (char.animation != null)
			char.animation.destroyAnimations();
		if (ghost.animation != null)
			ghost.animation.destroyAnimations();

		for (anim in curCharFile.animations)
		{
			char.addAnimationFromData(anim);
			ghost.addAnimationFromData(anim);
		}

		var anims = getAnimList();
		if (anims.length > 0) curAnim = anims[0]; else curAnim = "";
		animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims.length > 0 ? anims : [""], true));
		animDropDown.selectedLabel = curAnim;
		loadAnimToUI(curAnim);
		if (curAnim.length > 0) char.playAnim(curAnim, true);
		updateGhost();
	}
	
	function updateGhost()
	{
		if (ghost == null) return;
		if (ghost.hasAnimation('idle')) {
			ghost.playAnim('idle', true);
			ghost.pauseAnim();
		} else if (ghost.hasAnimation('danceRight')) {
			ghost.playAnim('danceRight', true);
			ghost.pauseAnim();
		} else if (ghost.hasAnimation('danceLeft')) {
			ghost.playAnim('danceLeft', true);
			ghost.pauseAnim();
		}
	}

	function updateHealthBar(forceReloadIcon:Bool = false)
	{
		if (forceReloadIcon)
			updateHealthIcon();
		updateHealthBarColor();
	}

	function updateHealthBarColor()
	{
		if (healthBar == null || char == null) return;
		
		var r = Std.int(stepColorR != null ? stepColorR.value : (char.healthColorArray != null && char.healthColorArray.length > 0 ? char.healthColorArray[0] : 161));
		var g = Std.int(stepColorG != null ? stepColorG.value : (char.healthColorArray != null && char.healthColorArray.length > 1 ? char.healthColorArray[1] : 161));
		var b = Std.int(stepColorB != null ? stepColorB.value : (char.healthColorArray != null && char.healthColorArray.length > 2 ? char.healthColorArray[2] : 161));
		var charColor = FlxColor.fromRGB(r, g, b);

		if (isPlayer)
			healthBar.createFilledBar(0xFFFF0000, charColor);
		else
			healthBar.createFilledBar(charColor, 0xFF31B0D1);
		healthBar.updateBar();

		if (curCharFile != null)
			curCharFile.healthbar_colors = [r, g, b];
		char.healthColorArray = [r, g, b];
	}

	function updateHealthIcon()
	{
		if (healthIcon == null || char == null) return;

		var iconName = (inputIcon != null && inputIcon.text.trim().length > 0) ? inputIcon.text.trim() : char.healthIcon;
		healthIcon.isPlayer = isPlayer;
		healthIcon.changeIcon(iconName);
		if (curCharFile != null)
		{
			if (curCharFile.icon_offsets != null && curCharFile.icon_offsets.length >= 2)
				healthIcon.iconOffsets = [curCharFile.icon_offsets[0], curCharFile.icon_offsets[1]];
			if (curCharFile.icon_suffix != null)
				healthIcon.iconSuffix = curCharFile.icon_suffix;
			if (curCharFile.icon_scale != null && curCharFile.icon_scale > 0)
			{
				healthIcon.iconScale = curCharFile.icon_scale;
				healthIcon.scale.set(healthIcon.iconScale, healthIcon.iconScale);
			}
			if (curCharFile.icon_animations != null && curCharFile.icon_animations.length > 0)
				healthIcon.applyIconAnimations(curCharFile.icon_animations);
		}
		updateIconPos();
	}

	function getIconColor()
	{
		var iconName = (inputIcon != null && inputIcon.text.trim().length > 0) ? inputIcon.text.trim() : (char != null ? char.healthIcon : "face");
		if (healthIcon == null || healthIcon.char != iconName)
		{
			updateHealthIcon();
		}

		var bitmap:openfl.display.BitmapData = null;
		var tempBitmap:openfl.display.BitmapData = null;

		// 1. Check if healthIcon has directly readable CPU pixels
		if (healthIcon != null && healthIcon.graphic != null && healthIcon.graphic.bitmap != null)
		{
			var raw = healthIcon.graphic.bitmap;
			if (raw.readable && raw.image != null && raw.image.data != null)
			{
				bitmap = raw;
			}
		}

		// 2. When GPU Caching is active, CPU pixels were discarded; load an uncompressed CPU copy
		if (bitmap == null && healthIcon != null && healthIcon.graphic != null)
		{
			var key:String = healthIcon.graphic.assetsKey;
			if (key == null || key.length == 0)
				key = healthIcon.graphic.key;
			if (key != null && key.length > 0)
			{
				tempBitmap = Paths.loadBitmap(key);
				if (tempBitmap != null)
					bitmap = tempBitmap;
			}
		}

		// 3. Fallback search across candidate directories, prefixes, and formats (PNG, WebP, Sparrow Atlas)
		if (bitmap == null)
		{
			var trimmedCharacter:String = iconName;
			var dashIndex:Int = trimmedCharacter.indexOf('-');
			var underIndex:Int = trimmedCharacter.indexOf('_');
			if (dashIndex != -1 && underIndex != -1)
				trimmedCharacter = trimmedCharacter.substring(0, Std.int(Math.min(dashIndex, underIndex)));
			else if (dashIndex != -1)
				trimmedCharacter = trimmedCharacter.substring(0, dashIndex);
			else if (underIndex != -1)
				trimmedCharacter = trimmedCharacter.substring(0, underIndex);

			var candidateNames:Array<String> = [
				iconName,
				'icon-' + iconName,
				trimmedCharacter,
				'icon-' + trimmedCharacter,
				'bf',
				'icon-bf',
				'face',
				'icon-face'
			];

			for (cand in candidateNames)
			{
				if (cand == null || cand.trim().length == 0) continue;

				var atlasKey = HealthIcon.findAtlasKey(cand);
				if (atlasKey != null)
				{
					var p = Paths.getImagePath(atlasKey);
					tempBitmap = Paths.loadBitmap(p);
					if (tempBitmap != null)
					{
						bitmap = tempBitmap;
						break;
					}
				}

				if (Paths.imageExists('UI/icons/' + cand))
				{
					var p = Paths.getImagePath('UI/icons/' + cand);
					tempBitmap = Paths.loadBitmap(p);
					if (tempBitmap != null) { bitmap = tempBitmap; break; }
				}
				else if (Paths.imageExists('icons/' + cand))
				{
					var p = Paths.getImagePath('icons/' + cand);
					tempBitmap = Paths.loadBitmap(p);
					if (tempBitmap != null) { bitmap = tempBitmap; break; }
				}
				else if (Paths.imageExists(cand))
				{
					var p = Paths.getImagePath(cand);
					tempBitmap = Paths.loadBitmap(p);
					if (tempBitmap != null) { bitmap = tempBitmap; break; }
				}
			}
		}

		if (bitmap == null) return;

		var startX:Int = 0;
		var endX:Int = 0;
		var startY:Int = 0;
		var endY:Int = 0;

		if (healthIcon != null && healthIcon.frame != null && healthIcon.frame.frame != null 
			&& healthIcon.graphic != null && healthIcon.graphic.bitmap != null
			&& bitmap.width == healthIcon.graphic.bitmap.width && bitmap.height == healthIcon.graphic.bitmap.height)
		{
			var r = healthIcon.frame.frame;
			startX = Std.int(Math.max(0, r.x));
			endX = Std.int(Math.min(bitmap.width, r.x + r.width));
			startY = Std.int(Math.max(0, r.y));
			endY = Std.int(Math.min(bitmap.height, r.y + r.height));
		}
		else
		{
			var frameCount:Int = Math.round(bitmap.width / bitmap.height);
			if (frameCount < 1) frameCount = 1;
			startX = 0;
			endX = Std.int(bitmap.width / frameCount);
			startY = 0;
			endY = bitmap.height;
		}

		var bucketCounts:Map<Int, Int> = new Map();
		var bucketR:Map<Int, Float> = new Map();
		var bucketG:Map<Int, Float> = new Map();
		var bucketB:Map<Int, Float> = new Map();

		var bestBucket:Int = -1;
		var maxCount:Int = 0;

		inline function samplePixel(px:Int, py:Int, pass:Int)
		{
			var pixel:Int = bitmap.getPixel32(px, py);
			var alpha:Int = (pixel >>> 24) & 0xFF;
			if (alpha > 90)
			{
				var r:Int = (pixel >> 16) & 0xFF;
				var g:Int = (pixel >> 8) & 0xFF;
				var b:Int = pixel & 0xFF;

				var isValid:Bool = false;
				if (pass == 1)
				{
					var brightness:Int = r + g + b;
					var isWhite:Bool = (r > 240 && g > 240 && b > 240);
					if (brightness > 60 && !isWhite)
						isValid = true;
				}
				else if (pass == 2)
				{
					isValid = true;
				}

				if (isValid)
				{
					var qr:Int = (r >> 3);
					var qg:Int = (g >> 3);
					var qb:Int = (b >> 3);
					var bucketKey:Int = (qr << 10) | (qg << 5) | qb;

					var count:Int = (bucketCounts.exists(bucketKey) ? bucketCounts.get(bucketKey) : 0) + 1;
					bucketCounts.set(bucketKey, count);
					bucketR.set(bucketKey, (bucketR.exists(bucketKey) ? bucketR.get(bucketKey) : 0) + r);
					bucketG.set(bucketKey, (bucketG.exists(bucketKey) ? bucketG.get(bucketKey) : 0) + g);
					bucketB.set(bucketKey, (bucketB.exists(bucketKey) ? bucketB.get(bucketKey) : 0) + b);

					if (count > maxCount)
					{
						maxCount = count;
						bestBucket = bucketKey;
					}
				}
			}
		}

		// Pass 1: Exclude black outlines and pure white
		for (x in startX...endX)
		{
			for (y in startY...endY)
			{
				samplePixel(x, y, 1);
			}
		}

		// Pass 2: Fallback for dark/monochrome icons
		if (maxCount == 0)
		{
			bucketCounts.clear();
			bucketR.clear();
			bucketB.clear();
			bestBucket = -1;

			for (x in startX...endX)
			{
				for (y in startY...endY)
				{
					samplePixel(x, y, 2);
				}
			}
		}

		if (maxCount > 0 && bestBucket != -1)
		{
			var r:Int = Math.round(bucketR.get(bestBucket) / maxCount);
			var g:Int = Math.round(bucketG.get(bestBucket) / maxCount);
			var b:Int = Math.round(bucketB.get(bestBucket) / maxCount);

			r = Std.int(FlxMath.bound(r, 0, 255));
			g = Std.int(FlxMath.bound(g, 0, 255));
			b = Std.int(FlxMath.bound(b, 0, 255));

			if (stepColorR != null) stepColorR.value = r;
			if (stepColorG != null) stepColorG.value = g;
			if (stepColorB != null) stepColorB.value = b;
			lastR = r;
			lastG = g;
			lastB = b;

			if (char != null) char.healthColorArray = [r, g, b];
			if (curCharFile != null) curCharFile.healthbar_colors = [r, g, b];

			updateHealthBarColor();
		}

		if (tempBitmap != null)
		{
			tempBitmap.dispose();
		}
	}

	function updateCameraCross()
	{
		if (char != null && cameraCross != null)
		{
			if (char.cameraPosition == null || char.cameraPosition.length < 2)
				char.cameraPosition = [0, 0];
			var mid = char.getMidpoint();
			var ox:Float = (isPlayer ? (char.flipX ? char.cameraPosition[0] : -char.cameraPosition[0]) : (char.flipX ? -char.cameraPosition[0] : char.cameraPosition[0]));
			cameraCross.x = mid.x + ox - (cameraCross.width / 2);
			cameraCross.y = mid.y + char.cameraPosition[1] - (cameraCross.height / 2);
			mid.put();
		}
	}

	function testDeathAudio()
	{
		if (testAudioSound != null && testAudioSound.playing)
		{
			testAudioSound.stop();
			testAudioSound = null;
			return;
		}

		var snd = inputFirstDeathSound != null ? inputFirstDeathSound.text.trim() : "";
		if (snd.length > 0)
		{
			var sndAsset = Paths.sound(snd);
			if (sndAsset == null && !snd.startsWith('gameover/'))
				sndAsset = Paths.sound('gameover/' + snd);
			if (sndAsset == null && !snd.startsWith('system/gameover/'))
				sndAsset = Paths.sound('system/gameover/' + snd);
			if (sndAsset != null)
				testAudioSound = FlxG.sound.play(sndAsset);
			else
				trace('Sound not found: ' + snd);
		}
	}

	function isMouseOnUI():Bool
	{
		var mouseHUD = FlxG.mouse.getViewPosition(camHUD);
		var mx = mouseHUD.x;
		var my = mouseHUD.y;
		mouseHUD.put();
		
		if (UI_box != null && mx >= UI_box.x - 10 && mx <= UI_box.x + UI_box.width + 10 &&
			my >= UI_box.y - 10 && my <= UI_box.y + UI_box.height + 10)
		{
			return true;
		}

		if (healthBarBG != null && my >= healthBarBG.y - 40)
		{
			return true;
		}

		if (charDropDown != null && charDropDown.visible && charDropDown.dropPanel != null && charDropDown.dropPanel.visible)
			return true;
		if (animDropDown != null && animDropDown.visible && animDropDown.dropPanel != null && animDropDown.dropPanel.visible)
			return true;
		if (iconAnimDropDown != null && iconAnimDropDown.visible && iconAnimDropDown.dropPanel != null && iconAnimDropDown.dropPanel.visible)
			return true;
		if (dropGameOver != null && dropGameOver.visible && dropGameOver.dropPanel != null && dropGameOver.dropPanel.visible)
			return true;

		return false;
	}

	function isTyping():Bool
	{
		if (inputIcon != null && inputIcon.hasFocus) return true;
		if (inputImage != null && inputImage.hasFocus) return true;
		if (inputAnim != null && inputAnim.hasFocus) return true;
		if (inputSuffix != null && inputSuffix.hasFocus) return true;
		if (inputIndices != null && inputIndices.hasFocus) return true;
		if (inputFirstDeath != null && inputFirstDeath.hasFocus) return true;
		if (inputLoopDeath != null && inputLoopDeath.hasFocus) return true;
		if (inputConfirmDeath != null && inputConfirmDeath.hasFocus) return true;
		if (inputFirstDeathSound != null && inputFirstDeathSound.hasFocus) return true;
		if (inputLoopDeathMusic != null && inputLoopDeathMusic.hasFocus) return true;
		if (inputConfirmDeathSound != null && inputConfirmDeathSound.hasFocus) return true;
		if (inputIconSuffix != null && inputIconSuffix.hasFocus) return true;
		if (inputIconAnim != null && inputIconAnim.hasFocus) return true;
		if (inputIconAnimSuffix != null && inputIconAnimSuffix.hasFocus) return true;
		if (inputIconAnimIndices != null && inputIconAnimIndices.hasFocus) return true;
		return false;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (gameplay.PlayState.SONG != null)
				Main.switchState(this, new gameplay.PlayState());
			else
				Main.switchState(this, new menus.MainMenuState());
			return;
		}

		// Reactive UI updates
		if (inputIcon != null && inputIcon.text.trim() != lastIcon)
		{
			lastIcon = inputIcon.text.trim();
			updateHealthIcon();
		}
		if (stepColorR != null && stepColorG != null && stepColorB != null &&
			(stepColorR.value != lastR || stepColorG.value != lastG || stepColorB.value != lastB))
		{
			lastR = stepColorR.value;
			lastG = stepColorG.value;
			lastB = stepColorB.value;
			updateHealthBarColor();
		}

		if (stepScale != null && stepScale.value != lastScale)
		{
			lastScale = stepScale.value;
			if (curCharFile != null) curCharFile.scale = lastScale;
			if (char != null)
			{
				char.scale.set(lastScale, lastScale);
				char.updateHitbox();
			}
			if (ghost != null)
			{
				ghost.scale.set(lastScale, lastScale);
				ghost.updateHitbox();
			}
			updateCameraCross();
		}

		if (stepSingDuration != null && stepSingDuration.value != lastSingDur)
		{
			lastSingDur = stepSingDuration.value;
			if (curCharFile != null) curCharFile.sing_duration = lastSingDur;
			if (char != null) char.singDuration = lastSingDur;
		}

		if (stepPosX != null && stepPosY != null && (stepPosX.value != lastPosX || stepPosY.value != lastPosY))
		{
			lastPosX = stepPosX.value;
			lastPosY = stepPosY.value;
			if (curCharFile != null) curCharFile.position = [lastPosX, lastPosY];
			if (char != null)
			{
				char.characterData.offsetX = lastPosX;
				char.characterData.offsetY = lastPosY;
				char.positionArray = [lastPosX, lastPosY];
				char.x = (FlxG.width / 2) + lastPosX;
				char.y = (FlxG.height / 2) + lastPosY - (char.frameHeight * char.scale.y);
			}
			if (ghost != null)
			{
				ghost.characterData.offsetX = lastPosX;
				ghost.characterData.offsetY = lastPosY;
				ghost.positionArray = [lastPosX, lastPosY];
				ghost.x = (FlxG.width / 2) + lastPosX;
				ghost.y = (FlxG.height / 2) + lastPosY - (ghost.frameHeight * ghost.scale.y);
			}
			updateCameraCross();
		}

		if (stepCamPosX != null && stepCamPosY != null && (stepCamPosX.value != lastCamPosX || stepCamPosY.value != lastCamPosY))
		{
			lastCamPosX = stepCamPosX.value;
			lastCamPosY = stepCamPosY.value;
			if (curCharFile != null) curCharFile.camera_position = [lastCamPosX, lastCamPosY];
			if (char != null)
			{
				char.cameraPosition = [lastCamPosX, lastCamPosY];
				char.characterData.camOffsetX = lastCamPosX;
				char.characterData.camOffsetY = lastCamPosY;
			}
			updateCameraCross();
		}

		if (stepIconBarOffsetX != null && stepIconBarOffsetY != null && stepIconScale != null &&
			(stepIconBarOffsetX.value != lastIconOffX || stepIconBarOffsetY.value != lastIconOffY || stepIconScale.value != lastIconScale))
		{
			lastIconOffX = stepIconBarOffsetX.value;
			lastIconOffY = stepIconBarOffsetY.value;
			lastIconScale = stepIconScale.value;
			if (healthIcon != null && curCharFile != null)
			{
				healthIcon.iconOffsets = [lastIconOffX, lastIconOffY];
				curCharFile.icon_offsets = [lastIconOffX, lastIconOffY];
				healthIcon.iconScale = lastIconScale;
				curCharFile.icon_scale = lastIconScale;
				healthIcon.scale.set(lastIconScale, lastIconScale);
				updateIconPos();
			}
		}
		
		var onUI = isMouseOnUI();

		// Cursor feedback
		if (draggingLeft || draggingRight)
		{
			CursorManager.change('grabbing');
		}
		else if (draggingMiddle)
		{
			CursorManager.change('scroll');
		}
		else if (isTyping())
		{
			CursorManager.change('text');
		}
		else if (onUI)
		{
			CursorManager.change('pointer');
		}
		else
		{
			CursorManager.change('default');
		}

		// Mouse Controls
		if (FlxG.mouse.justPressed && !onUI)
		{
			draggingLeft = true;
		}
		if (FlxG.mouse.justPressedMiddle)
		{
			draggingMiddle = true;
		}
		if (FlxG.mouse.justPressedRight && !onUI)
		{
			draggingRight = true;
		}

		if (!FlxG.mouse.pressed) draggingLeft = false;
		if (!FlxG.mouse.pressedMiddle) draggingMiddle = false;
		if (!FlxG.mouse.pressedRight) draggingRight = false;

		var deltaWorldX = FlxG.mouse.x - lastMouseX;
		var deltaWorldY = FlxG.mouse.y - lastMouseY;
		var deltaScreenX = FlxG.mouse.viewX - lastMouseScreenX;
		var deltaScreenY = FlxG.mouse.viewY - lastMouseScreenY;

		// 1. Left button: move only offset of current animation
		if (draggingLeft && curAnim.length > 0 && char != null && (deltaWorldX != 0 || deltaWorldY != 0))
		{
			var offset = char.animOffsets.get(curAnim);
			if (offset == null)
			{
				offset = [0, 0];
				char.animOffsets.set(curAnim, offset);
			}
			offset[0] -= Math.round(deltaWorldX);
			offset[1] -= Math.round(deltaWorldY);
			char.addOffset(curAnim, offset[0], offset[1]);
			char.playAnim(curAnim, true);
		}

		// 2. Middle button: pan editor camera
		if (draggingMiddle && (deltaScreenX != 0 || deltaScreenY != 0))
		{
			camGame.scroll.x -= deltaScreenX / camGame.zoom;
			camGame.scroll.y -= deltaScreenY / camGame.zoom;
		}

		// 3. Right button: move character camera
		if (draggingRight && char != null && (deltaWorldX != 0 || deltaWorldY != 0))
		{
			if (char.cameraPosition == null || char.cameraPosition.length < 2)
				char.cameraPosition = [0, 0];
			var dX:Float = (isPlayer ? (char.flipX ? deltaWorldX : -deltaWorldX) : (char.flipX ? -deltaWorldX : deltaWorldX));
			char.cameraPosition[0] += Math.round(dX);
			char.cameraPosition[1] += Math.round(deltaWorldY);
			char.characterData.camOffsetX = char.cameraPosition[0];
			char.characterData.camOffsetY = char.cameraPosition[1];
			if (curCharFile != null)
				curCharFile.camera_position = [char.cameraPosition[0], char.cameraPosition[1]];
			if (stepCamPosX != null)
			{
				stepCamPosX.value = char.cameraPosition[0];
				lastCamPosX = stepCamPosX.value;
			}
			if (stepCamPosY != null)
			{
				stepCamPosY.value = char.cameraPosition[1];
				lastCamPosY = stepCamPosY.value;
			}
			updateCameraCross();
		}

		// Zoom using mouse wheel
		if (!onUI && FlxG.mouse.wheel != 0)
		{
			camGame.zoom += FlxG.mouse.wheel * 0.1;
			camGame.zoom = FlxMath.bound(camGame.zoom, 0.2, 3.0);
		}

		// Keyboard controls when not typing in text boxes
		if (!isTyping())
		{
			if (FlxG.keys.justPressed.W) changeAnim(-1);
			if (FlxG.keys.justPressed.S) changeAnim(1);
			
			var shiftMult = FlxG.keys.pressed.SHIFT ? 10 : 1;
			if (FlxG.keys.justPressed.LEFT) updateOffset(-1 * shiftMult, 0);
			if (FlxG.keys.justPressed.RIGHT) updateOffset(1 * shiftMult, 0);
			if (FlxG.keys.justPressed.UP) updateOffset(0, 1 * shiftMult);
			if (FlxG.keys.justPressed.DOWN) updateOffset(0, -1 * shiftMult);
			
			if (FlxG.keys.justPressed.SPACE && curAnim.length > 0 && char != null)
			{
				char.playAnim(curAnim, true);
			}
		}

		lastMouseX = FlxG.mouse.x;
		lastMouseY = FlxG.mouse.y;
		lastMouseScreenX = FlxG.mouse.viewX;
		lastMouseScreenY = FlxG.mouse.viewY;
		
		var camX:Float = (char != null && char.cameraPosition != null && char.cameraPosition.length > 0) ? char.cameraPosition[0] : 0;
		var camY:Float = (char != null && char.cameraPosition != null && char.cameraPosition.length > 1) ? char.cameraPosition[1] : 0;
		var curOff:Array<Dynamic> = (char != null && char.animOffsets != null && char.animOffsets.exists(curAnim)) ? char.animOffsets.get(curAnim) : [0, 0];
		if (curOff == null || curOff.length < 2) curOff = [0, 0];

		textAnim.text = "Character: " + curCharName + " (" + (isPlayer ? "Player Side" : "Opponent Side") + ")" +
			"\nAnim: " + curAnim + 
			"\nOffsets: [" + Math.round(curOff[0]) + ", " + Math.round(curOff[1]) + "]" +
			"\nCam Pos: [" + Math.round(camX) + ", " + Math.round(camY) + "]" +
			"\n[W / S]: Change Anim | [Space]: Replay" +
			"\n[Arrows]: Move Offset (Shift = x10)" +
			"\n[LMB Drag]: Anim Offset | [MMB Drag]: Pan View | [RMB Drag]: Cam Target";
	}
	
	function changeAnim(change:Int)
	{
		var anims = getAnimList();
		if (anims.length == 0) return;

		var curIdx = anims.indexOf(curAnim);
		if (curIdx == -1) curIdx = 0;

		curIdx += change;
		if (curIdx < 0)
			curIdx = anims.length - 1;
		else if (curIdx >= anims.length)
			curIdx = 0;

		curAnim = anims[curIdx];
		if (animDropDown != null)
			animDropDown.selectedLabel = curAnim;

		loadAnimToUI(curAnim);
		if (char != null) char.playAnim(curAnim, true);
		updateGhost();
	}
	
	function updateOffset(x:Float, y:Float)
	{
		if (curAnim.length == 0 || char == null) return;
		var offset = char.animOffsets.get(curAnim);
		if (offset == null) {
			offset = [0, 0];
			char.animOffsets.set(curAnim, offset);
		}
		offset[0] += x;
		offset[1] += y;
		char.addOffset(curAnim, offset[0], offset[1]);
		char.playAnim(curAnim, true);
	}
	
	var _file:FileReference;
	function saveCharacter()
	{
		if (curCharFile == null || char == null) return;
		
		curCharFile.healthicon = inputIcon.text.trim();
		curCharFile.healthbar_colors = [Std.int(stepColorR.value), Std.int(stepColorG.value), Std.int(stepColorB.value)];
		curCharFile.flip_x = checkFlipX.checked;
		curCharFile.no_antialiasing = checkNoAntialiasing.checked;
		curCharFile.scale = stepScale.value;
		curCharFile.sing_duration = stepSingDuration.value;
		curCharFile.position = [stepPosX.value, stepPosY.value];
		curCharFile.image = inputImage.text.trim();

		if (char.cameraPosition == null || char.cameraPosition.length < 2)
			char.cameraPosition = [0, 0];
		curCharFile.camera_position = [char.cameraPosition[0], char.cameraPosition[1]];

		if (stepIconBarOffsetX != null && stepIconBarOffsetY != null)
			curCharFile.icon_offsets = [stepIconBarOffsetX.value, stepIconBarOffsetY.value];
		if (inputIconSuffix != null)
			curCharFile.icon_suffix = inputIconSuffix.text.trim();
		if (stepIconScale != null)
			curCharFile.icon_scale = stepIconScale.value;

		if (dropGameOver != null) curCharFile.gameOverChar = dropGameOver.selectedLabel;
		if (inputFirstDeath != null) curCharFile.firstDeath = inputFirstDeath.text.trim();
		if (inputLoopDeath != null) curCharFile.loopDeath = inputLoopDeath.text.trim();
		if (inputConfirmDeath != null) curCharFile.confirmDeath = inputConfirmDeath.text.trim();
		if (inputFirstDeathSound != null) curCharFile.firstDeathSound = inputFirstDeathSound.text.trim();
		if (inputLoopDeathMusic != null) curCharFile.loopDeathMusic = inputLoopDeathMusic.text.trim();
		if (inputConfirmDeathSound != null) curCharFile.confirmDeathSound = inputConfirmDeathSound.text.trim();
		if (checkQuickDancer != null) curCharFile.quickDancer = checkQuickDancer.checked;
		
		if (curCharFile.animations != null)
		{
			for (anim in curCharFile.animations) {
				if (anim != null && char.animOffsets.exists(anim.anim)) {
					var offset = char.animOffsets.get(anim.anim);
					if (offset != null && offset.length >= 2)
						anim.offsets = [offset[0], offset[1]];
				}
			}
		}
		
		var data:String = haxe.Json.stringify(curCharFile, "\t");
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(data, curCharName + ".json");
	}
	
	function onSaveComplete(_):Void { 
		if (_file != null)
		{
			_file.removeEventListener(Event.COMPLETE, onSaveComplete);
			_file.removeEventListener(Event.CANCEL, onSaveCancel); 
			_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError); 
			_file = null; 
		}
	}

	function onSaveCancel(_):Void { 
		onSaveComplete(_); 
	}

	function onSaveError(_):Void { 
		onSaveComplete(_); 
	}

	override function destroy():Void
	{
		CursorManager.reset();
		super.destroy();
	}
}

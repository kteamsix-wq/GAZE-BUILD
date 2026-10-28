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
	var inputImage:FlxInputText;
	
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
	
	// Health Bar & Icon (Item 5)
	var healthBarBG:FlxSprite;
	var healthBar:FlxBar;
	var healthIcon:HealthIcon;
	
	// Camera marker (Item 7)
	var cameraCross:FlxText;

	var curAnim:String = "";
	var curCharName:String = "bf";
	
	var camHUD:FlxCamera;
	var camGame:FlxCamera;
	
	var textAnim:FlxText;

	// Mouse control variables (Item 8)
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

	override function create()
	{
		super.create();
		
		FlxG.mouse.visible = true;
		
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
		
		// Camera Cross (+) (Item 7)
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

		// Health Bar & Icon (Item 5)
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

		healthIcon = new HealthIcon("face", false);
		healthIcon.cameras = [camHUD];
		healthIcon.scrollFactor.set();
		healthIcon.y = healthBar.y - (healthIcon.height / 2);
		add(healthIcon);
		
		var tabs = [
			{name: "Character", label: "Character"},
			{name: "Animations", label: "Animations"},
			{name: "Data", label: "Data"}
		];
		
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 360);
		UI_box.x = FlxG.width - 325;
		UI_box.y = 20;
		UI_box.cameras = [camHUD];
		add(UI_box);
		
		addCharacterUI();
		addAnimationUI();
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
		charDropDown = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(charsList, true), function(character:String)
		{
			loadChar(charsList[Std.parseInt(character)]);
		});
		charDropDown.selectedLabel = curCharName;
		
		// Item 1: FlipX Checkbox
		checkFlipX = new FlxUICheckBox(160, 25, null, null, "Flip X", 100);
		checkFlipX.callback = function() {
			if (char != null) char.flipX = checkFlipX.checked;
			if (curCharFile != null) curCharFile.flip_x = checkFlipX.checked;
		};

		inputIcon = new FlxInputText(10, 75, 130, "face", 8);
		
		stepColorR = new FlxUINumericStepper(10, 120, 1, 161, 0, 255);
		stepColorG = new FlxUINumericStepper(65, 120, 1, 161, 0, 255);
		stepColorB = new FlxUINumericStepper(120, 120, 1, 161, 0, 255);
		
		// Item 6: Get Icon Color Button
		var btnGetColor = new FlxButton(180, 118, "Get Color", function() {
			getIconColor();
		});

		inputImage = new FlxInputText(10, 165, 170, "characters/bf", 8);
		var btnReloadImage = new FlxButton(190, 163, "Reload", function() {
			reloadImage();
		});

		// Item 2: Create Template Button
		var btnTemplate = new FlxButton(10, 210, "Create Template", function() {
			createTemplate();
		});

		var saveBtn = new FlxButton(120, 210, "Save Character", function() {
			saveCharacter();
		});
		
		tab.add(new FlxText(10, 10, 0, "Character:"));
		tab.add(checkFlipX);
		tab.add(new FlxText(10, 60, 0, "Health Icon:"));
		tab.add(inputIcon);
		tab.add(new FlxText(10, 105, 0, "Color (R / G / B):"));
		tab.add(stepColorR);
		tab.add(stepColorG);
		tab.add(stepColorB);
		tab.add(btnGetColor);
		tab.add(new FlxText(10, 150, 0, "Image Path:"));
		tab.add(inputImage);
		tab.add(btnReloadImage);
		tab.add(btnTemplate);
		tab.add(saveBtn);
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
			if (idx >= 0 && idx < anims.length)
			{
				curAnim = anims[idx];
				loadAnimToUI(curAnim);
				char.playAnim(curAnim);
				updateGhost();
			}
		});
		
		checkGhost = new FlxUICheckBox(160, 25, null, null, "Show Ghost", 100);
		checkGhost.checked = true;
		checkGhost.callback = function() {
			ghost.visible = checkGhost.checked;
		};

		// Item 3: Anim inputs
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
			trace(char.animOffsets);
		});
		
		tab.add(new FlxText(10, 10, 0, "Select Animation:"));
		tab.add(checkGhost);
		tab.add(new FlxText(10, 60, 0, "Animation:"));
		tab.add(new FlxText(140, 60, 0, "Anim Suffix:"));
		tab.add(inputAnim);
		tab.add(inputSuffix);
		tab.add(new FlxText(10, 105, 0, "Anim FPS:"));
		tab.add(stepFps);
		tab.add(checkLoop);
		tab.add(new FlxText(10, 150, 0, "Indices:"));
		tab.add(inputIndices);
		tab.add(addAnimBtn);
		tab.add(removeAnimBtn);
		tab.add(applyOffsetsBtn);
		tab.add(animDropDown);
		
		UI_box.addGroup(tab);
	}

	// Item 4: Data Tab
	function addDataUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Data";

		var charsList = getCharactersList();
		dropGameOver = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(charsList, true), function(selected:String)
		{
			if (curCharFile != null)
				curCharFile.gameOverChar = charsList[Std.parseInt(selected)];
		});
		dropGameOver.selectedLabel = "bf-dead";

		inputFirstDeath = new FlxInputText(10, 75, 120, "firstDeath", 8);
		inputLoopDeath = new FlxInputText(140, 75, 120, "deathLoop", 8);
		inputConfirmDeath = new FlxInputText(10, 120, 120, "deathConfirm", 8);

		inputFirstDeathSound = new FlxInputText(10, 165, 120, "fnf_loss_sfx", 8);
		inputLoopDeathMusic = new FlxInputText(140, 165, 120, "gameOver", 8);
		inputConfirmDeathSound = new FlxInputText(10, 210, 120, "gameOverEnd", 8);

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
			var rawJson = sys.io.File.getContent(jsonPath);
			curCharFile = haxe.Json.parse(rawJson);
		}
		else
		{
			curCharFile = createDefaultTemplate();
		}

		ghost = new Character(false);
		ghost.debugMode = true;
		ghost.alpha = 0.5;
		if (checkGhost != null) {
			ghost.visible = checkGhost.checked;
		}
		add(ghost);
		
		char = new Character(false);
		char.debugMode = true;
		add(char);
		
		char.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		ghost.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		
		// Update Character UI
		if (inputIcon != null) {
			inputIcon.text = curCharFile.healthicon != null ? curCharFile.healthicon : "face";
			lastIcon = inputIcon.text;
		}
		if (inputImage != null) {
			inputImage.text = curCharFile.image != null ? curCharFile.image : "characters/placeman";
		}
		if (stepColorR != null) {
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
			inputFirstDeathSound.text = curCharFile.firstDeathSound != null ? curCharFile.firstDeathSound : "fnf_loss_sfx";
		}
		if (inputLoopDeathMusic != null) {
			inputLoopDeathMusic.text = curCharFile.loopDeathMusic != null ? curCharFile.loopDeathMusic : "gameOver";
		}
		if (inputConfirmDeathSound != null) {
			inputConfirmDeathSound.text = curCharFile.confirmDeathSound != null ? curCharFile.confirmDeathSound : "gameOverEnd";
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

		loadAnimToUI(curAnim);
		updateGhost();
		updateHealthBar();
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
			image: "characters/placeman",
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
			firstDeathSound: "fnf_loss_sfx",
			loopDeathMusic: "gameOver",
			confirmDeathSound: "gameOverEnd"
		};
	}

	// Item 2: Create Template
	function createTemplate()
	{
		curCharName = "template";
		curCharFile = createDefaultTemplate();

		if (char != null) {
			remove(char);
			char.destroy();
		}
		if (ghost != null) {
			remove(ghost);
			ghost.destroy();
		}

		ghost = new Character(false);
		ghost.debugMode = true;
		ghost.alpha = 0.5;
		if (checkGhost != null) {
			ghost.visible = checkGhost.checked;
		}
		add(ghost);

		char = new Character(false);
		char.debugMode = true;
		add(char);

		char.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		ghost.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);

		if (inputIcon != null) inputIcon.text = curCharFile.healthicon;
		if (inputImage != null) inputImage.text = curCharFile.image;
		if (stepColorR != null) {
			stepColorR.value = curCharFile.healthbar_colors[0];
			stepColorG.value = curCharFile.healthbar_colors[1];
			stepColorB.value = curCharFile.healthbar_colors[2];
		}
		if (checkFlipX != null) checkFlipX.checked = false;

		if (dropGameOver != null) dropGameOver.selectedLabel = curCharFile.gameOverChar;
		if (inputFirstDeath != null) inputFirstDeath.text = curCharFile.firstDeath;
		if (inputLoopDeath != null) inputLoopDeath.text = curCharFile.loopDeath;
		if (inputConfirmDeath != null) inputConfirmDeath.text = curCharFile.confirmDeath;
		if (inputFirstDeathSound != null) inputFirstDeathSound.text = curCharFile.firstDeathSound;
		if (inputLoopDeathMusic != null) inputLoopDeathMusic.text = curCharFile.loopDeathMusic;
		if (inputConfirmDeathSound != null) inputConfirmDeathSound.text = curCharFile.confirmDeathSound;

		var anims = getAnimList();
		if (anims.length > 0) curAnim = anims[0]; else curAnim = "";
		if (animDropDown != null) {
			animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims.length > 0 ? anims : [""], true));
			animDropDown.selectedLabel = curAnim;
		}
		loadAnimToUI(curAnim);

		updateGhost();
		updateHealthBar();
		updateCameraCross();
	}

	function reloadImage()
	{
		if (curCharFile == null) return;
		curCharFile.image = inputImage.text.trim();
		char.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		ghost.loadCharacterFile(curCharFile, FlxG.width / 2, FlxG.height / 2);
		if (curAnim.length > 0) char.playAnim(curAnim, true);
		updateGhost();
	}

	function loadAnimToUI(animName:String)
	{
		if (curCharFile == null || curCharFile.animations == null) return;
		inputAnim.text = animName;
		for (a in curCharFile.animations)
		{
			if (a.anim == animName)
			{
				inputSuffix.text = a.name != null ? a.name : "";
				stepFps.value = a.fps > 0 ? a.fps : 24;
				checkLoop.checked = a.loop == true;
				inputIndices.text = (a.indices != null && a.indices.length > 0) ? a.indices.join(", ") : "";
				return;
			}
		}
		inputSuffix.text = animName;
		stepFps.value = 24;
		checkLoop.checked = false;
		inputIndices.text = "";
	}

	function addOrUpdateAnimation()
	{
		if (curCharFile == null) return;
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
		if (char.animOffsets.exists(aName))
		{
			animOffsets = [char.animOffsets.get(aName)[0], char.animOffsets.get(aName)[1]];
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
			if (curCharFile.animations[i].anim == aName)
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
		if (curCharFile == null || curCharFile.animations == null) return;
		for (i in 0...curCharFile.animations.length)
		{
			if (curCharFile.animations[i].anim == curAnim)
			{
				curCharFile.animations.splice(i, 1);
				break;
			}
		}
		var anims = getAnimList();
		if (anims.contains(curAnim)) anims.remove(curAnim);
		if (anims.length > 0) curAnim = anims[0]; else curAnim = "";
		animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims.length > 0 ? anims : [""], true));
		animDropDown.selectedLabel = curAnim;
		loadAnimToUI(curAnim);
		if (curAnim.length > 0) char.playAnim(curAnim, true);
	}
	
	function updateGhost()
	{
		if (ghost.hasAnimation('idle')) {
			ghost.playAnim('idle');
			ghost.pauseAnim();
		} else if (ghost.hasAnimation('danceRight')) {
			ghost.playAnim('danceRight');
			ghost.pauseAnim();
		}
	}

	// Item 5: Health Bar update
	function updateHealthBar()
	{
		if (healthBar == null || char == null) return;
		
		var r = Std.int(stepColorR != null ? stepColorR.value : char.healthColorArray[0]);
		var g = Std.int(stepColorG != null ? stepColorG.value : char.healthColorArray[1]);
		var b = Std.int(stepColorB != null ? stepColorB.value : char.healthColorArray[2]);
		var charColor = FlxColor.fromRGB(r, g, b);

		healthBar.createFilledBar(charColor, charColor);
		healthBar.updateBar();

		if (healthIcon != null)
		{
			var iconName = (inputIcon != null && inputIcon.text.trim().length > 0) ? inputIcon.text.trim() : char.healthIcon;
			healthIcon.changeIcon(iconName);
			healthIcon.updateHitbox();
			healthIcon.y = healthBar.y - (healthIcon.height / 2);
			healthIcon.x = healthBar.x + (healthBar.width * 0.5) - (healthIcon.width / 2);
		}
	}

	// Item 6: Get Icon Color
	function getIconColor()
	{
		var iconName = (inputIcon != null && inputIcon.text.trim().length > 0) ? inputIcon.text.trim() : char.healthIcon;
		var iconPath = 'images/UI/icons/' + iconName + '.png';
		if (!sys.FileSystem.exists(Paths.getPath(iconPath, IMAGE)))
		{
			if (iconName.contains('-'))
				iconName = iconName.substring(0, iconName.indexOf('-'));
			iconPath = 'images/UI/icons/' + iconName + '.png';
			if (!sys.FileSystem.exists(Paths.getPath(iconPath, IMAGE)))
				iconPath = 'images/UI/icons/face.png';
		}

		var fullPath = Paths.getPath(iconPath, IMAGE);
		if (!sys.FileSystem.exists(fullPath)) return;

		var bitmap = openfl.display.BitmapData.fromFile(fullPath);
		if (bitmap == null) return;

		var frameCount:Int = Math.round(bitmap.width / bitmap.height);
		if (frameCount < 1) frameCount = 1;
		var frameWidth:Int = Std.int(bitmap.width / frameCount);
		var frameHeight:Int = bitmap.height;

		var colorCounts:Map<Int, Int> = new Map();
		var dominantColor:Int = 0;
		var maxCount:Int = 0;

		for (x in 0...frameWidth)
		{
			for (y in 0...frameHeight)
			{
				var pixel:Int = bitmap.getPixel32(x, y);
				var alpha:Int = (pixel >> 24) & 0xFF;
				if (alpha > 80)
				{
					var rgb:Int = pixel & 0x00FFFFFF;
					var r:Int = (rgb >> 16) & 0xFF;
					var g:Int = (rgb >> 8) & 0xFF;
					var b:Int = rgb & 0xFF;

					if ((r + g + b) > 60)
					{
						var count = (colorCounts.exists(rgb) ? colorCounts.get(rgb) : 0) + 1;
						colorCounts.set(rgb, count);
						if (count > maxCount)
						{
							maxCount = count;
							dominantColor = rgb;
						}
					}
				}
			}
		}

		if (maxCount == 0)
		{
			for (x in 0...frameWidth)
			{
				for (y in 0...frameHeight)
				{
					var pixel:Int = bitmap.getPixel32(x, y);
					var alpha:Int = (pixel >> 24) & 0xFF;
					if (alpha > 80)
					{
						var rgb:Int = pixel & 0x00FFFFFF;
						var count = (colorCounts.exists(rgb) ? colorCounts.get(rgb) : 0) + 1;
						colorCounts.set(rgb, count);
						if (count > maxCount)
						{
							maxCount = count;
							dominantColor = rgb;
						}
					}
				}
			}
		}

		if (maxCount > 0)
		{
			var r:Int = (dominantColor >> 16) & 0xFF;
			var g:Int = (dominantColor >> 8) & 0xFF;
			var b:Int = dominantColor & 0xFF;

			stepColorR.value = r;
			stepColorG.value = g;
			stepColorB.value = b;

			char.healthColorArray = [r, g, b];
			if (curCharFile != null)
				curCharFile.healthbar_colors = [r, g, b];

			updateHealthBar();
		}
	}

	// Item 7: Camera Cross update
	function updateCameraCross()
	{
		if (char != null && cameraCross != null)
		{
			var mid = char.getMidpoint();
			var ox:Float = (char.flipX) ? -char.cameraPosition[0] : char.cameraPosition[0];
			cameraCross.x = mid.x + ox - (cameraCross.width / 2);
			cameraCross.y = mid.y + char.cameraPosition[1] - (cameraCross.height / 2);
			mid.put();
		}
	}

	function testDeathAudio()
	{
		var snd = inputFirstDeathSound.text.trim();
		if (snd.length > 0)
		{
			var sndPath = Paths.getPath('sounds/' + snd + '.' + Paths.SOUND_EXT, SOUND);
			if (sys.FileSystem.exists(sndPath))
				FlxG.sound.play(Paths.sound(snd));
			else
				trace('Sound not found: ' + sndPath);
		}
	}

	function isMouseOnUI():Bool
	{
		var mouseHUD = FlxG.mouse.getViewPosition(camHUD);
		
		if (mouseHUD.x >= UI_box.x - 10 && mouseHUD.x <= UI_box.x + UI_box.width + 10 &&
			mouseHUD.y >= UI_box.y - 10 && mouseHUD.y <= UI_box.y + UI_box.height + 10)
		{
			return true;
		}

		if (healthBarBG != null && mouseHUD.y >= healthBarBG.y - 40)
		{
			return true;
		}

		if (charDropDown != null && charDropDown.dropPanel != null && charDropDown.dropPanel.visible)
			return true;
		if (animDropDown != null && animDropDown.dropPanel != null && animDropDown.dropPanel.visible)
			return true;
		if (dropGameOver != null && dropGameOver.dropPanel != null && dropGameOver.dropPanel.visible)
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
		return false;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE)
		{
			Main.switchState(this, new gameplay.PlayState());
			return;
		}

		// Reactive UI updates
		if (inputIcon != null && inputIcon.text.trim() != lastIcon)
		{
			lastIcon = inputIcon.text.trim();
			updateHealthBar();
		}
		if (stepColorR != null && (stepColorR.value != lastR || stepColorG.value != lastG || stepColorB.value != lastB))
		{
			lastR = stepColorR.value;
			lastG = stepColorG.value;
			lastB = stepColorB.value;
			updateHealthBar();
		}
		
		var onUI = isMouseOnUI();

		// Item 8: Mouse Controls
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
		if (draggingLeft && (deltaWorldX != 0 || deltaWorldY != 0))
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

		// 2. Middle button: pan editor camera (replaces WASD)
		if (draggingMiddle && (deltaScreenX != 0 || deltaScreenY != 0))
		{
			camGame.scroll.x -= deltaScreenX / camGame.zoom;
			camGame.scroll.y -= deltaScreenY / camGame.zoom;
		}

		// 3. Right button: move character camera
		if (draggingRight && (deltaWorldX != 0 || deltaWorldY != 0))
		{
			var dX:Float = (char != null && char.flipX) ? -deltaWorldX : deltaWorldX;
			char.cameraPosition[0] += Math.round(dX);
			char.cameraPosition[1] += Math.round(deltaWorldY);
			char.characterData.camOffsetX = char.cameraPosition[0];
			char.characterData.camOffsetY = char.cameraPosition[1];
			if (curCharFile != null)
				curCharFile.camera_position = [char.cameraPosition[0], char.cameraPosition[1]];
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
			
			if (FlxG.keys.justPressed.SPACE)
			{
				char.playAnim(curAnim, true);
			}
		}

		lastMouseX = FlxG.mouse.x;
		lastMouseY = FlxG.mouse.y;
		lastMouseScreenX = FlxG.mouse.viewX;
		lastMouseScreenY = FlxG.mouse.viewY;
		
		var camX = char != null ? char.cameraPosition[0] : 0;
		var camY = char != null ? char.cameraPosition[1] : 0;
		textAnim.text = "Anim: " + curAnim + "\nOffsets: " + (char != null ? char.animOffsets.get(curAnim) : [0, 0]) + 
			"\nCam Pos: [" + camX + ", " + camY + "]" +
			"\n[W / S]: Change Anim | [Space]: Replay" +
			"\n[LMB Drag]: Anim Offset | [MMB Drag]: Pan Cam | [RMB Drag]: Char Cam";
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
		char.playAnim(curAnim, true);
		updateGhost();
	}
	
	function updateOffset(x:Float, y:Float)
	{
		var offset = char.animOffsets.get(curAnim);
		if (offset != null) {
			offset[0] += x;
			offset[1] += y;
			char.addOffset(curAnim, offset[0], offset[1]);
			char.playAnim(curAnim, true);
		}
	}
	
	var _file:FileReference;
	function saveCharacter()
	{
		if (curCharFile == null) return;
		
		curCharFile.healthicon = inputIcon.text.trim();
		curCharFile.healthbar_colors = [Std.int(stepColorR.value), Std.int(stepColorG.value), Std.int(stepColorB.value)];
		curCharFile.flip_x = checkFlipX.checked;
		curCharFile.image = inputImage.text.trim();
		curCharFile.camera_position = [char.cameraPosition[0], char.cameraPosition[1]];

		if (dropGameOver != null) curCharFile.gameOverChar = dropGameOver.selectedLabel;
		if (inputFirstDeath != null) curCharFile.firstDeath = inputFirstDeath.text.trim();
		if (inputLoopDeath != null) curCharFile.loopDeath = inputLoopDeath.text.trim();
		if (inputConfirmDeath != null) curCharFile.confirmDeath = inputConfirmDeath.text.trim();
		if (inputFirstDeathSound != null) curCharFile.firstDeathSound = inputFirstDeathSound.text.trim();
		if (inputLoopDeathMusic != null) curCharFile.loopDeathMusic = inputLoopDeathMusic.text.trim();
		if (inputConfirmDeathSound != null) curCharFile.confirmDeathSound = inputConfirmDeathSound.text.trim();
		
		if (curCharFile.animations != null)
		{
			for (anim in curCharFile.animations) {
				if (char.animOffsets.exists(anim.anim)) {
					var offset = char.animOffsets.get(anim.anim);
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
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel); 
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError); 
		_file = null; 
	}

	function onSaveCancel(_):Void { 
		onSaveComplete(_); 
	}

	function onSaveError(_):Void { 
		onSaveComplete(_); 
	}
}

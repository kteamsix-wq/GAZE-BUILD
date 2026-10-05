package funkin.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUICheckBox;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import backend.MusicBeatState;
import funkin.objects.Character;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import Paths;

using StringTools;

class CharacterEditor extends MusicBeatState
{
	var char:Character;
	var ghost:Character;
	
	var UI_box:FlxUITabMenu;
	
	var charDropDown:FlxUIDropDownMenu;
	var animDropDown:FlxUIDropDownMenu;
	var inputIcon:FlxUIInputText;
	var stepColorR:FlxUINumericStepper;
	var stepColorG:FlxUINumericStepper;
	var stepColorB:FlxUINumericStepper;
	
	var checkGhost:FlxUICheckBox;
	var curAnim:String = "";
	var curCharName:String = "bf";
	
	var camHUD:FlxCamera;
	var camGame:FlxCamera;
	
	var textAnim:FlxText;

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
		
		textAnim = new FlxText(300, 16, 0, "", 16);
		textAnim.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, LEFT, OUTLINE, 0xFF000000);
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);
		
		var tabs = [
			{name: "Character", label: "Character"},
			{name: "Animations", label: "Animations"}
		];
		
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 250);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.cameras = [camHUD];
		add(UI_box);
		
		addCharacterUI();
		addAnimationUI();
		
		loadChar(curCharName);
	}

	function addCharacterUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Character";
		
		var charsList = getCharactersList();
		charDropDown = new FlxUIDropDownMenu(10, 10, FlxUIDropDownMenu.makeStrIdLabelArray(charsList, true), function(character:String)
		{
			loadChar(charsList[Std.parseInt(character)]);
		});
		charDropDown.selectedLabel = curCharName;
		
		inputIcon = new FlxUIInputText(10, 50, 100, "face", 8);
		
		stepColorR = new FlxUINumericStepper(10, 80, 1, 161, 0, 255);
		stepColorG = new FlxUINumericStepper(60, 80, 1, 161, 0, 255);
		stepColorB = new FlxUINumericStepper(110, 80, 1, 161, 0, 255);
		
		var saveBtn = new FlxButton(10, 120, "Save Character", function() {
			saveCharacter();
		});
		
		tab.add(new FlxText(10, 35, 0, "Health Icon"));
		tab.add(inputIcon);
		tab.add(new FlxText(10, 65, 0, "Color (R/G/B)"));
		tab.add(stepColorR);
		tab.add(stepColorG);
		tab.add(stepColorB);
		tab.add(saveBtn);
		tab.add(charDropDown);
		
		UI_box.addGroup(tab);
	}
	
	function addAnimationUI()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Animations";
		
		animDropDown = new FlxUIDropDownMenu(10, 10, FlxUIDropDownMenu.makeStrIdLabelArray(["idle"], true), function(animIndex:String)
		{
			var idx = Std.parseInt(animIndex);
			var anims = getAnimList();
			if (idx >= 0 && idx < anims.length)
			{
				curAnim = anims[idx];
				char.playAnim(curAnim);
				updateGhost();
			}
		});
		
		checkGhost = new FlxUICheckBox(10, 40, null, null, "Show Ghost", 100);
		checkGhost.checked = true;
		checkGhost.callback = function() {
			ghost.visible = checkGhost.checked;
		};
		
		var applyOffsetsBtn = new FlxButton(10, 70, "Print Offsets", function() {
			trace(char.animOffsets);
		});
		
		tab.add(checkGhost);
		tab.add(applyOffsetsBtn);
		tab.add(animDropDown);
		
		UI_box.addGroup(tab);
	}
	
	function getCharactersList():Array<String>
	{
		var list = [];
		var dir = sys.FileSystem.readDirectory('assets/data/char');
		for (file in dir) {
			if (file.endsWith(".json")) {
				list.push(file.replace(".json", ""));
			}
		}
		return list;
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
		
		char.setCharacter(FlxG.width / 2, FlxG.height / 2, name);
		ghost.setCharacter(FlxG.width / 2, FlxG.height / 2, name);
		
		if (inputIcon != null) {
			inputIcon.text = char.healthIcon;
			stepColorR.value = char.healthColorArray[0];
			stepColorG.value = char.healthColorArray[1];
			stepColorB.value = char.healthColorArray[2];
		}
		
		var anims = getAnimList();
		if (anims.length > 0) {
			curAnim = anims[0];
			char.playAnim(curAnim);
		}
		
		if (animDropDown != null) {
			var dropAnims = anims.length > 0 ? anims : [""];
			animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(dropAnims, true));
			animDropDown.selectedLabel = curAnim;
		}
		
		updateGhost();
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

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE)
		{
			Main.switchState(this, new funkin.states.PlayState());
			return;
		}
		
		// Camera controls
		if (FlxG.keys.pressed.W) camGame.scroll.y -= 5;
		if (FlxG.keys.pressed.S) camGame.scroll.y += 5;
		if (FlxG.keys.pressed.A) camGame.scroll.x -= 5;
		if (FlxG.keys.pressed.D) camGame.scroll.x += 5;
		
		var shiftMult = FlxG.keys.pressed.SHIFT ? 10 : 1;
		if (FlxG.keys.justPressed.LEFT) updateOffset(-1 * shiftMult, 0);
		if (FlxG.keys.justPressed.RIGHT) updateOffset(1 * shiftMult, 0);
		if (FlxG.keys.justPressed.UP) updateOffset(0, 1 * shiftMult);
		if (FlxG.keys.justPressed.DOWN) updateOffset(0, -1 * shiftMult);
		
		if (FlxG.keys.justPressed.SPACE)
		{
			char.playAnim(curAnim, true);
		}
		
		textAnim.text = "Anim: " + curAnim + "\nOffsets: " + char.animOffsets.get(curAnim) + "\n(Arrows to change, Space to replay)";
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
		var jsonPath = Paths.getPath('data/char/' + curCharName + '.json', TEXT);
		if (!sys.FileSystem.exists(jsonPath)) return;
		
		var rawJson = sys.io.File.getContent(jsonPath);
		var json:funkin.objects.Character.CharacterFile = haxe.Json.parse(rawJson);
		
		json.healthicon = inputIcon.text;
		json.healthbar_colors = [Std.int(stepColorR.value), Std.int(stepColorG.value), Std.int(stepColorB.value)];
		
		for (anim in json.animations) {
			if (char.animOffsets.exists(anim.anim)) {
				var offset = char.animOffsets.get(anim.anim);
				anim.offsets = [offset[0], offset[1]];
			}
		}
		
		var data:String = haxe.Json.stringify(json, "\t");
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(data, curCharName + ".json");
	}
	
	function onSaveComplete(_):Void { _file.removeEventListener(Event.COMPLETE, onSaveComplete); _file.removeEventListener(Event.CANCEL, onSaveCancel); _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError); _file = null; }
	function onSaveCancel(_):Void { onSaveComplete(_); }
	function onSaveError(_):Void { onSaveComplete(_); }
}





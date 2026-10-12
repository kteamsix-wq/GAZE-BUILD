package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.MusicBeatState;
import backend.Mods;
import Paths;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import Main;

typedef ModMetadata = {
	var name:String;
	var description:String;
	var icon:String;
	var version:Dynamic;
}

class ModsMenuState extends MusicBeatState
{
	var modsList:Array<String> = [];
	var modsMeta:Array<ModMetadata> = [];
	
	var curSelected:Int = 0;
	
	var modNameText:FlxText;
	var modDescText:FlxText;
	var modVersionText:FlxText;
	
	var iconGroup:FlxTypedGroup<FlxSprite>;
	var itemGroup:FlxTypedGroup<FlxText>;
	
	var bg:FlxSprite;

	override function create()
	{
		super.create();
		
		bg = new FlxSprite(-85).loadGraphic(Paths.image('menus/menuDesat'));
		bg.scrollFactor.set(0, 0);
		bg.color = 0xFF353535;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);
		
		itemGroup = new FlxTypedGroup<FlxText>();
		add(itemGroup);
		
		iconGroup = new FlxTypedGroup<FlxSprite>();
		add(iconGroup);
		
		modsList = Mods.getModDirectories();
		
		for (i in 0...modsList.length)
		{
			var modFolder = modsList[i];
			var meta:ModMetadata = {
				name: modFolder,
				description: "No description provided.",
				icon: "icon",
				version: "1.0"
			};
			
			var metaPath = 'mods/' + modFolder + '/meta.json';
			if (FileSystem.exists(metaPath))
			{
				try {
					var rawJson = File.getContent(metaPath);
					var parsed:ModMetadata = Json.parse(rawJson);
					if (parsed.name != null) meta.name = parsed.name;
					else if (Reflect.hasField(parsed, "nome")) meta.name = Reflect.field(parsed, "nome");
					
					if (parsed.description != null) meta.description = parsed.description;
					else if (Reflect.hasField(parsed, "descrição")) meta.description = Reflect.field(parsed, "descrição");
					else if (Reflect.hasField(parsed, "descricao")) meta.description = Reflect.field(parsed, "descricao");
					
					if (parsed.icon != null) meta.icon = parsed.icon;
					else if (Reflect.hasField(parsed, "icone")) meta.icon = Reflect.field(parsed, "icone");
					
					if (parsed.version != null) meta.version = parsed.version;
					else if (Reflect.hasField(parsed, "versão")) meta.version = Reflect.field(parsed, "versão");
					else if (Reflect.hasField(parsed, "versao")) meta.version = Reflect.field(parsed, "versao");
				} catch(e:Dynamic) {
					trace("Error parsing meta.json for " + modFolder);
				}
			}
			modsMeta.push(meta);
			
			var text = new FlxText(100, 50 + (i * 100), 0, meta.name, 32);
			text.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.ID = i;
			itemGroup.add(text);
			
			// Load icon
			var iconSpr = new FlxSprite(text.x - 70, text.y - 10);
			var iconPath = 'mods/' + modFolder + '/' + meta.icon + '.png';
			if (!FileSystem.exists(iconPath)) {
				iconPath = 'mods/' + modFolder + '/images/' + meta.icon + '.png';
			}
			
			if (FileSystem.exists(iconPath)) {
				var bmp = BitmapData.fromFile(iconPath);
				if (bmp != null) {
					iconSpr.loadGraphic(FlxGraphic.fromBitmapData(bmp));
					iconSpr.setGraphicSize(50, 50);
					iconSpr.updateHitbox();
				}
			}
			iconSpr.ID = i;
			iconGroup.add(iconSpr);
		}
		
		var box = new FlxSprite(FlxG.width / 2, 0).makeGraphic(Std.int(FlxG.width / 2), FlxG.height, 0x99000000);
		add(box);
		
		modNameText = new FlxText(FlxG.width / 2 + 20, 50, Std.int(FlxG.width / 2) - 40, "", 32);
		modNameText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(modNameText);
		
		modVersionText = new FlxText(FlxG.width / 2 + 20, modNameText.y + 40, Std.int(FlxG.width / 2) - 40, "", 24);
		modVersionText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.GRAY, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(modVersionText);
		
		modDescText = new FlxText(FlxG.width / 2 + 20, modVersionText.y + 50, Std.int(FlxG.width / 2) - 40, "", 24);
		modDescText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(modDescText);
		
		if (modsList.length > 0)
			changeSelection(0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);
			
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('system/cancel'));
			Main.switchState(this, new MainMenuState());
		}
		
		if (controls.ACCEPT)
		{
			if (modsList.length > 0) {
				Mods.currentModDirectory = modsList[curSelected];
				FlxG.sound.play(Paths.sound('system/confirm'));
				Main.switchState(this, new MainMenuState());
			}
		}
		
		// Simple camera follow logic
		for (item in itemGroup.members) {
			item.y = flixel.math.FlxMath.lerp(item.y, 50 + ((item.ID - curSelected) * 100) + (FlxG.height / 2 - 50), Math.exp(-elapsed * 10));
		}
		for (icon in iconGroup.members) {
			icon.y = flixel.math.FlxMath.lerp(icon.y, 40 + ((icon.ID - curSelected) * 100) + (FlxG.height / 2 - 50), Math.exp(-elapsed * 10));
		}
	}
	
	function changeSelection(change:Int)
	{
		if (modsList.length == 0) return;
		
		curSelected += change;
		if (curSelected < 0) curSelected = modsList.length - 1;
		if (curSelected >= modsList.length) curSelected = 0;
		
		FlxG.sound.play(Paths.sound('system/scroll'));
		
		for (item in itemGroup.members)
		{
			item.alpha = 0.6;
			if (item.ID == curSelected)
			{
				item.alpha = 1.0;
			}
		}
		
		for (icon in iconGroup.members)
		{
			icon.alpha = 0.6;
			if (icon.ID == curSelected)
				icon.alpha = 1.0;
		}
		
		var meta = modsMeta[curSelected];
		modNameText.text = meta.name;
		modVersionText.text = "Version: " + Std.string(meta.version);
		modDescText.text = meta.description;
	}
}

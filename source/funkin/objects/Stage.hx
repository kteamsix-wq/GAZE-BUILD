package funkin.objects;

import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;
import Paths;
import Utils;
import Assets;
import Init;

import haxe.io.Path;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import backend.CoolUtil;
import backend.Conductor;
import funkin.objects.FunkinSprites;
import funkin.states.PlayState;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;

#if sys
import hscript.Parser;
import hscript.Interp;
#end

using StringTools;

typedef StageData = {
	var zoom:Float;
	var BF_POS:Array<Float>;
	var DAD_POS:Array<Float>;
	var GF_POS:Array<Float>;
	var GF_HIDE:Bool;
}

/**
	Modernized Stage class using JSON properties and HScript.
**/
class Stage extends FlxTypedGroup<FlxBasic>
{
	public var curStage:String;
	public var stageData:StageData;

	public var background:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	public var foreground:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

	#if sys
	public var interp:Interp;
	#end

	public function new(curStage:String)
	{
		super();
		this.curStage = curStage;

		if (PlayState.determinedChartType == "FNF")
		{
			switch (CoolUtil.spaceToDash(PlayState.SONG.song.toLowerCase()))
			{
				default:
					this.curStage = 'stage';
			}
			PlayState.curStage = this.curStage;
		}

		loadStageData();
		
		#if sys
		loadStageScript();
		#else
		loadHardcodedStage(this.curStage);
		#end
	}

	public function loadStageData()
	{
		var jsonPath = Paths.getPath('data/stages/' + curStage + '.json', TEXT);
		if (FileSystem.exists(jsonPath)) {
			try {
				stageData = Json.parse(File.getContent(jsonPath));
			} catch(e:Dynamic) {
				trace("Error parsing stage data: " + e);
			}
		}

		// Fallback data if JSON doesn't exist
		if (stageData == null) {
			stageData = {
				zoom: 0.9,
				BF_POS: [770, 100],
				DAD_POS: [100, 100],
				GF_POS: [400, 130],
				GF_HIDE: false
			};
		}

		PlayState.defaultCamZoom = stageData.zoom;
	}

	#if sys
	public function loadStageScript()
	{
		var scriptPath = Paths.getPath('data/stages/' + curStage + '.hx', TEXT);
		if (FileSystem.exists(scriptPath)) {
			try {
				var parser = new Parser();
				parser.allowTypes = true;
				var ast = parser.parseString(File.getContent(scriptPath));

				interp = new Interp();

				// Expose useful classes to the script
				interp.variables.set("Math", Math);
				interp.variables.set("Std", Std);
				interp.variables.set("StringTools", StringTools);
				interp.variables.set("FlxG", FlxG);
				interp.variables.set("FlxSprite", FlxSprite);
				interp.variables.set("FlxTween", FlxTween);
				interp.variables.set("FunkinSprites", FunkinSprites);
				interp.variables.set("Paths", Paths);
				interp.variables.set("PlayState", PlayState);
				interp.variables.set("Conductor", Conductor);
				interp.variables.set("CoolUtil", CoolUtil);
				
				// Expose stage properties and add() function (adds to background by default to match old behavior)
				interp.variables.set("stage", this);
				interp.variables.set("background", this.background);
				interp.variables.set("foreground", this.foreground);
				interp.variables.set("add", function(obj:FlxSprite) { this.background.add(obj); });

				interp.execute(ast);
				callScript("create", []);
			} catch (e:Dynamic) {
				trace("Error executing stage script: " + e);
				loadHardcodedStage(this.curStage);
			}
		} else {
			loadHardcodedStage(this.curStage);
		}
	}
	#end

	private function loadHardcodedStage(stageName:String)
	{
		switch (stageName)
		{
			default:
				var bg:FunkinSprites = new FunkinSprites(-600, -200).loadGraphic(Paths.image('backgrounds/' + stageName + '/stageback'));
				bg.antialiasing = true;
				background.add(bg);

				var stageFront:FunkinSprites = new FunkinSprites(-650, 600).loadGraphic(Paths.image('backgrounds/' + stageName + '/stagefront'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				background.add(stageFront);

				var stageCurtains:FunkinSprites = new FunkinSprites(-500, -300).loadGraphic(Paths.image('backgrounds/' + stageName + '/stagecurtains'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				foreground.add(stageCurtains);
		}
	}

	public function callScript(func:String, args:Array<Dynamic>):Dynamic {
		#if sys
		if (interp != null && interp.variables.exists(func)) {
			try {
				return Reflect.callMethod(null, interp.variables.get(func), args);
			} catch (e:Dynamic) {
				trace('Error calling script function $func: $e');
			}
		}
		#end
		return null;
	}

	// return the girlfriend's type
	public function returnGFtype(curStage:String)
	{
		return 'gf';
	}

	// get the dad's position
	public function dadPosition(curStage:String, boyfriend:Character, dad:Character, gf:Character, camPos:FlxPoint):Void
	{
		if (stageData != null) {
			dad.setPosition(stageData.DAD_POS[0], stageData.DAD_POS[1]);
			boyfriend.setPosition(stageData.BF_POS[0], stageData.BF_POS[1]);
			gf.setPosition(stageData.GF_POS[0], stageData.GF_POS[1]);
			gf.visible = !stageData.GF_HIDE;
		} else {
			// Hardcoded fallback
			var characterArray:Array<Character> = [dad, boyfriend];
			for (char in characterArray)
			{
				if (char.curCharacter == 'gf')
				{
					char.setPosition(gf.x, gf.y);
					gf.visible = false;
				}
			}
		}
	}

	public function repositionPlayers(curStage:String, boyfriend:Character, dad:Character, gf:Character):Void
	{
		if (stageData != null) {
			gf.visible = !stageData.GF_HIDE;
		} else {
			gf.visible = false;
		}
	}

	// Note: Flixel might not call update if stageBuild isn't added directly to the state
	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	// Used when state isn't adding the group itself, meaning update() doesn't fire naturally
	public function stageUpdateConstant(elapsed:Float, boyfriend:Boyfriend, gf:Character, dadOpponent:Character)
	{
		callScript("update", [elapsed]);
	}

	public function stageUpdate(curBeat:Int, boyfriend:Boyfriend, gf:Character, dadOpponent:Character)
	{
		callScript("beatHit", [curBeat]);
	}

	public function stageStep(curStep:Int)
	{
		callScript("stepHit", [curStep]);
	}
}

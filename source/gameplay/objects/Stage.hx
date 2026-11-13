package gameplay.objects;

import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.system.Assets;
import core.base.Init;

import haxe.io.Path;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import core.utils.CoolUtil;
import gameplay.Conductor;
import core.system.FunkinSprites;
import gameplay.PlayState;
import Main;
import menus.CreditsState;
import menus.MainMenuState;
import menus.FreeplayState;
import menus.TitleState;
import menus.OptionsMenuState;
import menus.ModsMenuState;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;

#if sys
import core.scripting.HScriptHandler;
import core.scripting.HScriptHandler.CustomInterp;
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

	public var inCreatePost:Bool = false;

	#if sys
	public var script:core.scripting.HScriptHandler;
	public var interp(get, set):core.scripting.HScriptHandler.CustomInterp;
	inline function get_interp():core.scripting.HScriptHandler.CustomInterp return script != null ? script.interp : null;
	inline function set_interp(v:core.scripting.HScriptHandler.CustomInterp):core.scripting.HScriptHandler.CustomInterp {
		if (script != null) script.interp = v;
		return v;
	}
	public var builtinVariables(get, never):Map<String, Dynamic>;
	inline function get_builtinVariables():Map<String, Dynamic> return script != null ? script.builtinVariables : null;
	public var functionCache(get, never):Map<String, Dynamic>;
	inline function get_functionCache():Map<String, Dynamic> return script != null ? script.functionCache : null;
	#end

	public function new(curStage:String)
	{
		super();
		this.curStage = curStage;

		if (PlayState.determinedChartType == "FNF")
		{
			if (this.curStage == null || this.curStage == "")
			{
				switch (CoolUtil.spaceToDash(PlayState.SONG.song.toLowerCase()))
				{
					default:
						this.curStage = 'stage';
				}
				PlayState.curStage = this.curStage;
			}
		}

		Paths.currentStage = this.curStage;

		loadStageData();
		
		#if sys
		loadStageScript();
		#else
		loadHardcodedStage(this.curStage);
		#end
	}

	public function loadStageData()
	{
		Paths.currentStage = curStage;

		var jsonCandidates:Array<String> = [
			'data/stages/' + curStage + '/stage.json',
			'data/stages/' + curStage + '/' + curStage + '.json',
			'data/stages/' + curStage + '.json',
			'stages/' + curStage + '/stage.json',
			'stages/' + curStage + '/' + curStage + '.json',
			'stages/' + curStage + '.json'
		];

		var jsonPath:String = null;
		for (candidate in jsonCandidates)
		{
			var p = Paths.getPath(candidate, TEXT);
			#if sys
			if (FileSystem.exists(p))
			{
				jsonPath = p;
				break;
			}
			#else
			if (openfl.utils.Assets.exists(p, TEXT))
			{
				jsonPath = p;
				break;
			}
			#end
		}

		if (jsonPath != null) {
			try {
				#if sys
				stageData = Json.parse(File.getContent(jsonPath));
				#else
				stageData = Json.parse(openfl.utils.Assets.getText(jsonPath));
				#end
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
		Paths.currentStage = curStage;

		var scriptCandidates:Array<String> = [
			'data/stages/' + curStage + '/script.hxc',
			'data/stages/' + curStage + '/script.hx',
			'data/stages/' + curStage + '/' + curStage + '.hxc',
			'data/stages/' + curStage + '/' + curStage + '.hx',
			'data/stages/' + curStage + '.hxc',
			'data/stages/' + curStage + '.hx',
			'stages/' + curStage + '/script.hxc',
			'stages/' + curStage + '/script.hx',
			'stages/' + curStage + '/' + curStage + '.hxc',
			'stages/' + curStage + '/' + curStage + '.hx',
			'stages/' + curStage + '.hxc',
			'stages/' + curStage + '.hx'
		];

		var scriptPath:String = null;
		for (candidate in scriptCandidates)
		{
			var p = Paths.getPath(candidate, TEXT);
			if (FileSystem.exists(p))
			{
				scriptPath = p;
				break;
			}
		}

		if (scriptPath != null && FileSystem.exists(scriptPath)) {
			try {
				script = new core.scripting.HScriptHandler(scriptPath, this);
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
				var bgImg = Paths.stageImage('stageback', stageName);
				if (bgImg == null) bgImg = Paths.image('backgrounds/' + stageName + '/stageback');
				if (bgImg == null) bgImg = Paths.image('backgrounds/stage/stageback');
				if (bgImg != null)
				{
					var bg:FunkinSprites = new FunkinSprites(-600, -200).loadGraphic(bgImg);
					bg.antialiasing = true;
					background.add(bg);
				}

				var frontImg = Paths.stageImage('stagefront', stageName);
				if (frontImg == null) frontImg = Paths.image('backgrounds/' + stageName + '/stagefront');
				if (frontImg == null) frontImg = Paths.image('backgrounds/stage/stagefront');
				if (frontImg != null)
				{
					var stageFront:FunkinSprites = new FunkinSprites(-650, 600).loadGraphic(frontImg);
					stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
					stageFront.updateHitbox();
					stageFront.antialiasing = true;
					background.add(stageFront);
				}

				var curtImg = Paths.stageImage('stagecurtains', stageName);
				if (curtImg == null) curtImg = Paths.image('backgrounds/' + stageName + '/stagecurtains');
				if (curtImg == null) curtImg = Paths.image('backgrounds/stage/stagecurtains');
				if (curtImg != null)
				{
					var stageCurtains:FunkinSprites = new FunkinSprites(-500, -300).loadGraphic(curtImg);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					stageCurtains.antialiasing = true;
					foreground.add(stageCurtains);
				}
		}
	}

	private function injectGlobals():Void {
		#if sys
		if (script != null && PlayState.instance != null) {
			script.loadPlayStateVariables(PlayState.instance, this);
		}
		#end
	}

	public function callScript(func:String, args:Array<Dynamic>):Dynamic {
		#if sys
		if (script != null && script.active) {
			var isPost:Bool = (func == "onCreatePost" || func == "createPost" || func == "postCreate" || func == "onPostCreate");
			var prevPost:Bool = inCreatePost;
			if (isPost) {
				inCreatePost = true;
				injectGlobals();
			}

			var result = script.call(func, args != null ? args : []);
			inCreatePost = prevPost;
			return result;
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
			var dadX:Float = (stageData.DAD_POS != null && (stageData.DAD_POS[0] != 0 || stageData.DAD_POS[1] != 0)) ? stageData.DAD_POS[0] : 100;
			var dadY:Float = (stageData.DAD_POS != null && (stageData.DAD_POS[0] != 0 || stageData.DAD_POS[1] != 0)) ? stageData.DAD_POS[1] : 100;
			var bfX:Float = (stageData.BF_POS != null && (stageData.BF_POS[0] != 0 || stageData.BF_POS[1] != 0)) ? stageData.BF_POS[0] : 770;
			var bfY:Float = (stageData.BF_POS != null && (stageData.BF_POS[0] != 0 || stageData.BF_POS[1] != 0)) ? stageData.BF_POS[1] : 450;
			var gfX:Float = (stageData.GF_POS != null && (stageData.GF_POS[0] != 0 || stageData.GF_POS[1] != 0)) ? stageData.GF_POS[0] : 400;
			var gfY:Float = (stageData.GF_POS != null && (stageData.GF_POS[0] != 0 || stageData.GF_POS[1] != 0)) ? stageData.GF_POS[1] : 130;

			dad.setPosition(dadX, dadY);
			boyfriend.setPosition(bfX, bfY);
			gf.setPosition(gfX, gfY);
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

	override public function add(basic:FlxBasic):FlxBasic
	{
		if (inCreatePost)
		{
			if (Std.isOfType(basic, FlxSprite))
				foreground.add(cast basic);
		}
		else
		{
			if (Std.isOfType(basic, FlxSprite))
				background.add(cast basic);
		}
		return basic;
	}

	override public function remove(basic:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (Std.isOfType(basic, FlxSprite))
		{
			background.remove(cast basic, splice);
			foreground.remove(cast basic, splice);
		}
		return basic;
	}

	override public function insert(position:Int, object:FlxBasic):FlxBasic
	{
		if (inCreatePost)
		{
			if (Std.isOfType(object, FlxSprite))
				foreground.insert(position, cast object);
		}
		else
		{
			if (Std.isOfType(object, FlxSprite))
				background.insert(position, cast object);
		}
		return object;
	}

	// Note: Flixel might not call update if stageBuild isn't added directly to the state
	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	// Used when state isn't adding the group itself, meaning update() doesn't fire naturally
	public function stageUpdateConstant(elapsed:Float)
	{
		callScript("update", [elapsed]);
	}

	public function stageUpdate(curBeat:Int)
	{
		callScript("beatHit", [curBeat]);
	}

	public function stageStep(curStep:Int)
	{
		callScript("stepHit", [curStep]);
	}

	override public function destroy():Void
	{
		#if sys
		if (script != null)
		{
			try {
				callScript("onDestroy", []);
			} catch(e:Dynamic) {}
			script.destroy();
			script = null;
		}
		#end

		if (background != null)
		{
			background.destroy();
			background = null;
		}
		if (foreground != null)
		{
			foreground.destroy();
			foreground = null;
		}

		stageData = null;
		super.destroy();
	}
}

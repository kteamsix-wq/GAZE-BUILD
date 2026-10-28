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

import sys.io.File;
import sys.FileSystem;
import haxe.Json;

#if sys
import hscript.Parser;
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
	public var interp:CustomInterp;
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
				parser.allowJSON = true;
				parser.allowMetadata = true;

				interp = new CustomInterp();

				// Dynamic import helpers available inside Stage HScript
				interp.variables.set("importClass", function(className:String, ?alias:String):Dynamic {
					return HScriptHandler.importClassToInterp(interp, className, alias);
				});
				interp.variables.set("resolveClass", function(className:String):Dynamic {
					return HScriptHandler.resolveImport(className);
				});

				// Expose useful classes to the script
				interp.variables.set("Math", Math);
				interp.variables.set("Std", Std);
				interp.variables.set("StringTools", StringTools);
				interp.variables.set("Sys", Sys);
				interp.variables.set("Type", Type);
				interp.variables.set("Reflect", Reflect);
				interp.variables.set("Json", haxe.Json);
				interp.variables.set("FlxG", FlxG);
				interp.variables.set("FlxSprite", FlxSprite);
				interp.variables.set("FlxObject", flixel.FlxObject);
				interp.variables.set("FlxMath", flixel.math.FlxMath);
				interp.variables.set("FlxTimer", flixel.util.FlxTimer);
				interp.variables.set("FlxTween", FlxTween);
				interp.variables.set("FlxTweenType", HScriptHandler.getFlxTweenTypeProxy());
				interp.variables.set("FlxEase", flixel.tweens.FlxEase);
				interp.variables.set("FlxFlicker", flixel.effects.FlxFlicker);
				interp.variables.set("FlxGroup", flixel.group.FlxGroup.FlxTypedGroup);
				interp.variables.set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
				interp.variables.set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
				interp.variables.set("FlxBackdrop", flixel.addons.display.FlxBackdrop);
				interp.variables.set("FlxText", flixel.text.FlxText);
				interp.variables.set("FlxColor", HScriptHandler.getFlxColorProxy());
				interp.variables.set("FlxAxes", HScriptHandler.getFlxAxesProxy());
				interp.variables.set("FlxTextAlign", HScriptHandler.getFlxTextAlignProxy());
				interp.variables.set("FlxTextBorderStyle", HScriptHandler.getFlxTextBorderStyleProxy());
				interp.variables.set("FlxKey", HScriptHandler.getFlxKeyProxy());
				interp.variables.set("FlxPoint", flixel.math.FlxPoint.FlxBasePoint);
				interp.variables.set("BlendMode", HScriptHandler.getBlendModeProxy());
				interp.variables.set("FunkinSprites", FunkinSprites);
				interp.variables.set("Paths", Paths);
				interp.variables.set("PlayState", PlayState);
				interp.variables.set("Conductor", Conductor);
				interp.variables.set("CoolUtil", CoolUtil);
				var curSongName:String = (PlayState.SONG != null && PlayState.SONG.song != null) ? PlayState.SONG.song.toLowerCase() : '';
				interp.variables.set("songName", curSongName);
				interp.variables.set("curSong", curSongName);
				
				// Shader Classes & Helpers
				interp.variables.set("FunkinShader", core.system.FunkinShader.FunkinShaderImpl);
				interp.variables.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
				interp.variables.set("ShaderFilter", openfl.filters.ShaderFilter);
				interp.variables.set("createShader", function(frag:String, ?vert:String) {
					return core.system.FunkinShader.FunkinShaderImpl.fromFile(frag, vert);
				});
				interp.variables.set("setCameraShader", function(camera:flixel.FlxCamera, shader:Dynamic) {
					if (camera == null) return;
					if (shader == null) camera.filters = null;
					else camera.filters = [new openfl.filters.ShaderFilter(shader)];
				});
				interp.variables.set("addCameraShader", function(camera:flixel.FlxCamera, shader:Dynamic) {
					if (camera == null || shader == null) return;
					var f = new openfl.filters.ShaderFilter(shader);
					if (camera.filters == null) camera.filters = [f];
					else camera.filters.push(f);
				});
				interp.variables.set("clearCameraShaders", function(camera:flixel.FlxCamera) {
					if (camera != null) camera.filters = null;
				});
				interp.variables.set("tweenShader", function(shader:Dynamic, uniform:String, arg1:Float, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic) {
					return core.system.FunkinShader.FunkinShaderImpl.tweenAnyShader(shader, uniform, arg1, arg2, arg3, arg4, arg5);
				});
				interp.variables.set("cancelShaderTween", function(shader:Dynamic, ?uniform:String) {
					core.system.FunkinShader.FunkinShaderImpl.cancelAnyShaderTween(shader, uniform);
				});

				if (PlayState.instance != null) {
					interp.variables.set("game", PlayState.instance);
					interp.variables.set("camGame2", PlayState.camGame2);
					interp.variables.set("camGame", PlayState.camGame);
					interp.variables.set("camHUD", PlayState.camHUD);
					interp.variables.set("camAlt", PlayState.camAlt);
					interp.variables.set("boyfriend", PlayState.boyfriend);
					interp.variables.set("dad", PlayState.dadOpponent);
					interp.variables.set("dadOpponent", PlayState.dadOpponent);
					interp.variables.set("gf", PlayState.gf);
					interp.variables.set("restartSong", function() { if (PlayState.instance != null) PlayState.instance.restartSong(); });
					interp.variables.set("GameOverSubstate", gameplay.substates.GameOverSubstate);
					interp.variables.set("changeCharacter", function(charType:Dynamic, newChar:String, ?x:Null<Float>, ?y:Null<Float>) {
						if (PlayState.instance != null) {
							var idx:Int = 1;
							if (Std.isOfType(charType, Int)) {
								idx = cast charType;
							} else {
								var str = Std.string(charType).toLowerCase().trim();
								if (str == '0' || str == 'bf' || str == 'boyfriend' || str == 'player') idx = 0;
								else if (str == '2' || str == 'gf' || str == 'girlfriend') idx = 2;
								else idx = 1;
							}
							PlayState.instance.changeCharacter(idx, newChar, x, y);
						}
					});
					interp.variables.set("triggerEvent", function(eventName:String, value1:String, value2:String) {
						if (PlayState.instance != null) PlayState.instance.triggerEvent(eventName, value1, value2);
					});
					interp.variables.set("camPosTo", function(?x:Null<Float>, ?y:Null<Float>, ?timeSteps:Float = 0, ?ease:String = 'linear') {
						if (PlayState.instance != null) PlayState.instance.camPosTo(x, y, timeSteps, ease);
					});
					interp.variables.set("playVideo", function(videoName:String, ?shouldCenter:Bool = true, ?scale:Float = 1.0):Dynamic {
						if (PlayState.instance != null) return PlayState.instance.playVideo(videoName, shouldCenter, scale);
						return null;
					});
					interp.variables.set("startVideo", function(nameOrPath:String, ?onComplete:Void->Void) {
						if (PlayState.instance != null) PlayState.instance.startVideo(nameOrPath, onComplete);
					});
					interp.variables.set("skipCutscene", function() {
						if (PlayState.instance != null) PlayState.instance.skipCutscene();
					});
				}
				#if hxvlc
				interp.variables.set("FlxVideoSprite", hxvlc.flixel.FlxVideoSprite);
				interp.variables.set("FlxVideo", hxvlc.flixel.FlxVideo);
				#end
				interp.variables.set("playSong", gameplay.PlayState.playSong);
				interp.variables.set("setReturnState", gameplay.PlayState.setReturnState);
				interp.variables.set("getReturnState", gameplay.PlayState.getReturnState);

				// Expose stage properties and add() function
				interp.variables.set("stage", this);
				interp.variables.set("add", function(obj:Dynamic) {
					if (inCreatePost)
						this.foreground.add(cast obj);
					else
						this.background.add(cast obj);
				});
				interp.variables.set("remove", function(obj:Dynamic) {
					this.background.remove(cast obj, true);
					this.foreground.remove(cast obj, true);
				});
				interp.variables.set("insert", function(pos:Int, obj:Dynamic) {
					if (inCreatePost)
						this.foreground.insert(pos, cast obj);
					else
						this.background.insert(pos, cast obj);
				});
				interp.variables.set("background", this.background);
				interp.variables.set("foreground", this.foreground);

				// Modchart shortcuts
				interp.variables.set("ModManager", gameplay.modchart.ModManager);
				interp.variables.set("Vector3", core.utils.Vector3);
				interp.variables.set("MathUtil", core.utils.MathUtil);
				interp.variables.set("modManager", PlayState.instance != null ? PlayState.instance.modManager : null);
				interp.variables.set("queueEase", function(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueEase(step, endStep, modName, target, style, player, startVal);
				});
				interp.variables.set("queueSet", function(step:Float, modName:String, target:Float, player:Int = -1) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueSet(step, modName, target, player);
				});
				interp.variables.set("queueEaseP", function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueEaseP(step, endStep, modName, percent, style, player, startVal);
				});
				interp.variables.set("queueSetP", function(step:Float, modName:String, percent:Float, player:Int = -1) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueSetP(step, modName, percent, player);
				});
				interp.variables.set("queueFunc", function(step:Float, endStep:Float, callback:Dynamic) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueFunc(step, endStep, callback);
				});
				interp.variables.set("queueFuncOnce", function(step:Float, callback:Dynamic) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.queueFuncOnce(step, callback);
				});
				interp.variables.set("setValue", function(modName:String, val:Float, player:Int = -1) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.setValue(modName, val, player);
				});
				interp.variables.set("setPercent", function(modName:String, val:Float, player:Int = -1) {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						PlayState.instance.modManager.setPercent(modName, val, player);
				});
				interp.variables.set("getValue", function(modName:String, player:Int = 0):Float {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						return PlayState.instance.modManager.getValue(modName, player);
					return 0.0;
				});
				interp.variables.set("getPercent", function(modName:String, player:Int = 0):Float {
					if (PlayState.instance != null && PlayState.instance.modManager != null)
						return PlayState.instance.modManager.getPercent(modName, player);
					return 0.0;
				});

				var scriptText = File.getContent(scriptPath);
				var strippedText = HScriptHandler.preprocessScript(scriptText, interp);
				var ast = parser.parseString(strippedText);

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
		if (interp != null) {
			if (PlayState.instance != null) {
				if (PlayState.instance.modManager != null)
					interp.variables.set("modManager", PlayState.instance.modManager);
				interp.variables.set("game", PlayState.instance);
				interp.variables.set("camGame2", PlayState.camGame2);
				interp.variables.set("camGame", PlayState.camGame);
				interp.variables.set("camHUD", PlayState.camHUD);
				interp.variables.set("camAlt", PlayState.camAlt);
				interp.variables.set("boyfriend", PlayState.boyfriend);
				interp.variables.set("dad", PlayState.dadOpponent);
				interp.variables.set("dadOpponent", PlayState.dadOpponent);
				interp.variables.set("gf", PlayState.gf);
			}

			var targetFunc:Dynamic = null;
			var aliases:Array<String> = [func];
			if (StringTools.startsWith(func, "on")) {
				aliases.push(func.charAt(2).toLowerCase() + func.substr(3));
			} else {
				aliases.push("on" + func.charAt(0).toUpperCase() + func.substr(1));
			}

			if (func == "onCreatePost" || func == "createPost" || func == "postCreate" || func == "onPostCreate") {
				aliases = ["postCreate", "createPost", "onCreatePost", "onPostCreate"];
			} else if (func == "onCreate" || func == "create") {
				aliases = ["create", "onCreate"];
			}

			var reservedFunctions:Array<String> = [
				"triggerEvent", "restartSong", "changeCharacter", "camPosTo", 
				"add", "remove", "insert", "addCameraZoom", "playCharacterAnim", "playVideo"
			];

			for (name in aliases) {
				if (reservedFunctions.contains(name)) continue;
				if (interp.variables.exists(name)) {
					targetFunc = interp.variables.get(name);
					if (targetFunc != null && Reflect.isFunction(targetFunc)) break;
				}
			}

			var isPost:Bool = (func == "onCreatePost" || func == "createPost" || func == "postCreate" || func == "onPostCreate");
			var prevPost:Bool = inCreatePost;
			if (isPost) inCreatePost = true;

			if (targetFunc != null && Reflect.isFunction(targetFunc)) {
				try {
					var result = Reflect.callMethod(null, targetFunc, args != null ? args : []);
					inCreatePost = prevPost;
					return result;
				} catch (e:Dynamic) {
					inCreatePost = prevPost;
					trace('Error calling script function $func: $e');
					lime.app.Application.current.window.alert('Error calling script function $func:\n$e', 'Stage Script Error');
				}
			} else {
				inCreatePost = prevPost;
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
}

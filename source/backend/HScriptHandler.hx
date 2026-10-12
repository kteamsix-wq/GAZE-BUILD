package backend;

import hscript.Parser;
import hscript.Interp;
import sys.FileSystem;
import sys.io.File;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import funkin.states.PlayState;
import funkin.objects.Character;

class CustomInterp extends hscript.Interp {
	override public function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (Std.isOfType(o, backend.FunkinShader.FunkinShaderImpl) || Std.isOfType(o, flixel.addons.display.FlxRuntimeShader)) {
			var shader:flixel.addons.display.FlxRuntimeShader = cast o;
			if (shader.data != null) {
				var prop:Dynamic = Reflect.field(shader.data, f);
				if (prop != null) {
					if (Std.isOfType(v, Array)) prop.value = v;
					else if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) prop.value = [Std.parseFloat(Std.string(v))];
					else prop.value = [v];
					return v;
				}
			}
		}
		return super.set(o, f, v);
	}

	override public function get(o:Dynamic, f:String):Dynamic {
		if (o == flixel.FlxG.sound && f == "playMusic") {
			return function(asset:Dynamic, vol:Float=1.0, loop:Bool=true) { flixel.FlxG.sound.playMusic(asset, vol, loop); };
		}
		if (Std.isOfType(o, flixel.sound.FlxSound) && f == "fadeIn") {
			return function(dur:Float, from:Float=0.0, to:Float=1.0) { cast(o, flixel.sound.FlxSound).fadeIn(dur, from, to); };
		}
		if (Std.isOfType(o, backend.FunkinShader.FunkinShaderImpl) || Std.isOfType(o, flixel.addons.display.FlxRuntimeShader)) {
			var shader:flixel.addons.display.FlxRuntimeShader = cast o;
			if (shader.data != null) {
				var prop:Dynamic = Reflect.field(shader.data, f);
				if (prop != null) {
					var val:Array<Dynamic> = prop.value;
					if (val != null) return val.length == 1 ? val[0] : val;
					return null;
				}
			}
		}
		return super.get(o, f);
	}
}

class HScriptHandler {
	public var interp:CustomInterp;
	public var parser:Parser;
	public var scriptName:String;
	public var active:Bool = true;

	public function new(scriptPath:String) {
		scriptName = scriptPath;
		parser = new Parser();
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;

		interp = new CustomInterp();

		// Base Haxe/Flixel Classes
		setVar("FlxG", FlxG);
		setVar("FlxSprite", FlxSprite);
		setVar("FlxMath", FlxMath);
		setVar("FlxTimer", FlxTimer);
		setVar("FlxTween", FlxTween);
		setVar("FlxEase", FlxEase);
		setVar("FlxColor", {
			BLACK: flixel.util.FlxColor.BLACK,
			WHITE: flixel.util.FlxColor.WHITE,
			RED: flixel.util.FlxColor.RED,
			GREEN: flixel.util.FlxColor.GREEN,
			BLUE: flixel.util.FlxColor.BLUE,
			TRANSPARENT: flixel.util.FlxColor.TRANSPARENT,
			fromRGB: flixel.util.FlxColor.fromRGB,
			fromString: flixel.util.FlxColor.fromString
		});
		setVar("FlxObject", flixel.FlxObject);
		setVar("FlxFlicker", flixel.effects.FlxFlicker);
		setVar("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
		setVar("FlxText", flixel.text.FlxText);
		setVar("FlxAxes", {
			X: flixel.util.FlxAxes.X,
			Y: flixel.util.FlxAxes.Y,
			XY: flixel.util.FlxAxes.XY
		});
		setVar("Application", lime.app.Application);
		setVar("FlxTextAlign", {
			LEFT: flixel.text.FlxText.FlxTextAlign.LEFT,
			CENTER: flixel.text.FlxText.FlxTextAlign.CENTER,
			RIGHT: flixel.text.FlxText.FlxTextAlign.RIGHT,
			JUSTIFY: flixel.text.FlxText.FlxTextAlign.JUSTIFY
		});
		setVar("FlxTextBorderStyle", {
			NONE: flixel.text.FlxText.FlxTextBorderStyle.NONE,
			SHADOW: flixel.text.FlxText.FlxTextBorderStyle.SHADOW,
			OUTLINE: flixel.text.FlxText.FlxTextBorderStyle.OUTLINE,
			OUTLINE_FAST: flixel.text.FlxText.FlxTextBorderStyle.OUTLINE_FAST
		});
		
		setVar("Math", Math);
		setVar("Std", Std);
		setVar("StringTools", StringTools);
		setVar("Sys", Sys);

		// Shader Classes & Helpers
		setVar("FunkinShader", backend.FunkinShader.FunkinShaderImpl);
		setVar("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		setVar("ShaderFilter", openfl.filters.ShaderFilter);
		setVar("createShader", function(frag:String, ?vert:String) {
			return backend.FunkinShader.FunkinShaderImpl.fromFile(frag, vert);
		});
		setVar("setCameraShader", function(camera:flixel.FlxCamera, shader:Dynamic) {
			if (camera == null) return;
			if (shader == null) camera.filters = null;
			else camera.filters = [new openfl.filters.ShaderFilter(shader)];
		});
		setVar("addCameraShader", function(camera:flixel.FlxCamera, shader:Dynamic) {
			if (camera == null || shader == null) return;
			var f = new openfl.filters.ShaderFilter(shader);
			if (camera.filters == null) camera.filters = [f];
			else camera.filters.push(f);
		});
		setVar("clearCameraShaders", function(camera:flixel.FlxCamera) {
			if (camera != null) camera.filters = null;
		});
		setVar("tweenShader", function(shader:Dynamic, uniform:String, arg1:Float, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic) {
			return backend.FunkinShader.FunkinShaderImpl.tweenAnyShader(shader, uniform, arg1, arg2, arg3, arg4, arg5);
		});
		setVar("cancelShaderTween", function(shader:Dynamic, ?uniform:String) {
			backend.FunkinShader.FunkinShaderImpl.cancelAnyShaderTween(shader, uniform);
		});

		// Game Specific Classes
		setVar("PlayState", PlayState);
		setVar("Paths", Paths);
		setVar("Character", Character);
		setVar("Conductor", backend.Conductor);
		setVar("Mods", backend.Mods);
		setVar("CoolUtil", backend.CoolUtil);

		if (PlayState.instance != null) {
			setVar("game", PlayState.instance);
			
			// Shortcuts requested by the user
			setVar("add", function(obj:flixel.FlxBasic) { PlayState.instance.add(obj); });
			setVar("insert", function(pos:Int, obj:flixel.FlxBasic) { PlayState.instance.insert(pos, obj); });
			setVar("remove", function(obj:flixel.FlxBasic, splice:Bool = false) { PlayState.instance.remove(obj, splice); });
			
			// Character shortcuts
			setVar("boyfriend", PlayState.boyfriend);
			setVar("dad", PlayState.dadOpponent);
			setVar("dadOpponent", PlayState.dadOpponent);
			setVar("gf", PlayState.gf);
			
			// Camera shortcuts
			setVar("camGame", PlayState.camGame);
			setVar("camHUD", PlayState.camHUD);
			setVar("camAlt", PlayState.camAlt);

			// Gameplay controls
			setVar("restartSong", function() { if (PlayState.instance != null) PlayState.instance.restartSong(); });
			setVar("GameOverSubstate", funkin.substates.GameOverSubstate);

			// Modchart shortcuts
			setVar("modManager", PlayState.instance != null ? PlayState.instance.modManager : null);
			setVar("queueEase", function(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueEase(step, endStep, modName, target, style, player, startVal);
			});
			setVar("queueSet", function(step:Float, modName:String, target:Float, player:Int = -1) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueSet(step, modName, target, player);
			});
			setVar("queueEaseP", function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueEaseP(step, endStep, modName, percent, style, player, startVal);
			});
			setVar("queueSetP", function(step:Float, modName:String, percent:Float, player:Int = -1) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueSetP(step, modName, percent, player);
			});
			setVar("queueFunc", function(step:Float, endStep:Float, callback:Dynamic) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueFunc(step, endStep, callback);
			});
			setVar("queueFuncOnce", function(step:Float, callback:Dynamic) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.queueFuncOnce(step, callback);
			});
			setVar("setValue", function(modName:String, val:Float, player:Int = -1) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.setValue(modName, val, player);
			});
			setVar("setPercent", function(modName:String, val:Float, player:Int = -1) {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					PlayState.instance.modManager.setPercent(modName, val, player);
			});
			setVar("getValue", function(modName:String, player:Int = 0):Float {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					return PlayState.instance.modManager.getValue(modName, player);
				return 0.0;
			});
			setVar("getPercent", function(modName:String, player:Int = 0):Float {
				if (PlayState.instance != null && PlayState.instance.modManager != null)
					return PlayState.instance.modManager.getPercent(modName, player);
				return 0.0;
			});
		}

		// Modchart Classes
		setVar("ModManager", funkin.game.modchart.ModManager);
		setVar("Vector3", funkin.backend.math.Vector3);
		setVar("MathUtil", funkin.utils.MathUtil);

		try {
			var scriptText = File.getContent(scriptPath);
			var strippedText = "";
			for (line in scriptText.split("\n")) {
				var trimmed = StringTools.trim(line);
				if (!StringTools.startsWith(trimmed, "import ") && !StringTools.startsWith(trimmed, "package ")) {
					strippedText += line + "\n";
				}
			}
			var expr = parser.parseString(strippedText);
			interp.execute(expr);
		} catch(e:Dynamic) {
			trace("Error loading script " + scriptName + ": " + e);
			active = false;
		}
	}

	public function setVar(name:String, value:Dynamic) {
		interp.variables.set(name, value);
	}

	public function getVar(name:String):Dynamic {
		return interp.variables.get(name);
	}

	public function call(functionName:String, ?args:Array<Dynamic>):Dynamic {
		if (!active) return null;

		var targetFunc:Dynamic = null;
		var aliases:Array<String> = [functionName];
		if (StringTools.startsWith(functionName, "on")) {
			aliases.push(functionName.charAt(2).toLowerCase() + functionName.substr(3));
		} else {
			aliases.push("on" + functionName.charAt(0).toUpperCase() + functionName.substr(1));
		}

		if (functionName == "onCreatePost" || functionName == "createPost" || functionName == "postCreate" || functionName == "onPostCreate") {
			aliases = ["postCreate", "createPost", "onCreatePost", "onPostCreate"];
		} else if (functionName == "onCreate" || functionName == "create") {
			aliases = ["create", "onCreate"];
		}

		for (name in aliases) {
			if (interp.variables.exists(name)) {
				targetFunc = interp.variables.get(name);
				if (targetFunc != null && Reflect.isFunction(targetFunc)) break;
			}
		}

		if (targetFunc != null && Reflect.isFunction(targetFunc)) {
			if (args == null) args = [];
			try {
				return Reflect.callMethod(null, targetFunc, args);
			} catch(e:Dynamic) {
				trace("Error calling function " + functionName + " in " + scriptName + ": " + e);
				lime.app.Application.current.window.alert('Error calling script function ' + functionName + ' in ' + scriptName + ':\n' + e, 'HScript Error');
			}
		}
		return null;
	}
}

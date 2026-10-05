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
import funkin.states.PlayState;
import funkin.objects.Character;

class CustomInterp extends hscript.Interp {
	override public function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (Std.isOfType(o, backend.FunkinShader.FunkinShaderImpl)) {
			var shader:backend.FunkinShader.FunkinShaderImpl = cast o;
			if (shader.data.exists(f)) {
				var prop = Reflect.field(shader.data, f);
				if (Std.isOfType(v, Array)) prop.value = v;
				else prop.value = [v];
				return v;
			}
		}
		return super.set(o, f, v);
	}

	override public function get(o:Dynamic, f:String):Dynamic {
		if (Std.isOfType(o, backend.FunkinShader.FunkinShaderImpl)) {
			var shader:backend.FunkinShader.FunkinShaderImpl = cast o;
			if (shader.data.exists(f)) {
				var prop = Reflect.field(shader.data, f);
				var val:Array<Dynamic> = prop.value;
				if (val != null) return val.length == 1 ? val[0] : val;
				return null;
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
		
		setVar("Math", Math);
		setVar("Std", Std);
		setVar("StringTools", StringTools);
		setVar("Sys", Sys);

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
			setVar("gf", PlayState.gf);
			
			// Camera shortcuts
			setVar("camGame", PlayState.camGame);
			setVar("camHUD", PlayState.camHUD);
		}

		try {
			var scriptText = File.getContent(scriptPath);
			var expr = parser.parseString(scriptText);
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

		if (interp.variables.exists(functionName)) {
			var func = interp.variables.get(functionName);
			if (Reflect.isFunction(func)) {
				if (args == null) args = [];
				try {
					return Reflect.callMethod(null, func, args);
				} catch(e:Dynamic) {
					trace("Error calling function " + functionName + " in " + scriptName + ": " + e);
				}
			}
		}
		return null;
	}
}

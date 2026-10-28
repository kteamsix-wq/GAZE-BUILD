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
		if (o == PlayState || o == PlayState.instance || Std.isOfType(o, PlayState)) {
			switch (f) {
				case "health": PlayState.health = v; return v;
				case "combo": PlayState.combo = v; return v;
				case "songScore" | "score": PlayState.songScore = v; return v;
				case "misses": PlayState.misses = v; return v;
				case "deaths": PlayState.deaths = v; return v;
				case "curStage": PlayState.curStage = v; return v;
				case "defaultCamZoom": PlayState.defaultCamZoom = v; return v;
				case "cameraSpeed": PlayState.cameraSpeed = v; return v;
				case "camZooming": PlayState.camZooming = v; return v;
				case "camZoomingMult": PlayState.camZoomingMult = v; return v;
				case "camZoomingFrequency": PlayState.camZoomingFrequency = v; return v;
				case "boyfriend": PlayState.boyfriend = v; return v;
				case "dad" | "dadOpponent": PlayState.dadOpponent = v; return v;
				case "gf": PlayState.gf = v; return v;
				case "camGame2": PlayState.camGame2 = v; return v;
				case "camGame": PlayState.camGame = v; return v;
				case "camHUD": PlayState.camHUD = v; return v;
				case "camAlt": PlayState.camAlt = v; return v;
			}
		}
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
		try {
			return super.set(o, f, v);
		} catch (e:Dynamic) {
			try {
				Reflect.setField(o, f, v);
				return v;
			} catch(e2:Dynamic) {
				throw e;
			}
		}
	}

	override public function get(o:Dynamic, f:String):Dynamic {
		if (o == PlayState || o == PlayState.instance || Std.isOfType(o, PlayState)) {
			switch (f) {
				case "health": return PlayState.health;
				case "combo": return PlayState.combo;
				case "songScore" | "score": return PlayState.songScore;
				case "misses": return PlayState.misses;
				case "deaths": return PlayState.deaths;
				case "curStage": return PlayState.curStage;
				case "defaultCamZoom": return PlayState.defaultCamZoom;
				case "cameraSpeed": return PlayState.cameraSpeed;
				case "camZooming": return PlayState.camZooming;
				case "camZoomingMult": return PlayState.camZoomingMult;
				case "camZoomingFrequency": return PlayState.camZoomingFrequency;
				case "boyfriend": return PlayState.boyfriend;
				case "dad" | "dadOpponent": return PlayState.dadOpponent;
				case "gf": return PlayState.gf;
				case "camGame2": return PlayState.camGame2;
				case "camGame": return PlayState.camGame;
				case "camHUD": return PlayState.camHUD;
				case "camAlt": return PlayState.camAlt;
				case "songMusic": return PlayState.songMusic;
				case "vocals": return PlayState.vocals;
				case "opponentVocals": return PlayState.opponentVocals;
				case "SONG": return PlayState.SONG;
				case "dadStrums": return PlayState.dadStrums;
				case "boyfriendStrums": return PlayState.boyfriendStrums;
				case "strumLines": return PlayState.strumLines;
				case "triggerEvent": return PlayState.instance != null ? PlayState.instance.triggerEvent : null;
				case "playCharacterAnim": return PlayState.instance != null ? PlayState.instance.playCharacterAnim : null;
				case "addCameraZoom": return PlayState.instance != null ? PlayState.instance.addCameraZoom : null;
				case "playVideo": return PlayState.instance != null ? PlayState.instance.playVideo : null;
				case "startVideo": return PlayState.instance != null ? PlayState.instance.startVideo : null;
				case "skipCutscene": return PlayState.instance != null ? PlayState.instance.skipCutscene : null;
				case "playSong": return PlayState.playSong;
				case "setReturnState": return PlayState.setReturnState;
				case "getReturnState": return PlayState.getReturnState;
			}
		}
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

	override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
		if (f == null) {
			throw 'Attempted to call a null function/method on ' + Std.string(o);
		}
		return Reflect.callMethod(o, f, args);
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic {
		var c:Dynamic = null;
		if (variables.exists(cl)) {
			c = variables.get(cl);
		}
		if (c == null) {
			c = HScriptHandler.resolveImport(cl);
		}
		if (c == null) {
			c = Type.resolveClass(cl);
		}
		if (c == null) {
			c = resolve(cl);
		}
		return Type.createInstance(c, args);
	}

	override function assign(e1:hscript.Expr, e2:hscript.Expr):Dynamic {
		switch (hscript.Tools.expr(e1)) {
			case EIdent(id):
				switch (id) {
					case "health":
						var v = expr(e2);
						PlayState.health = v;
						return v;
					case "combo":
						var v = expr(e2);
						PlayState.combo = v;
						return v;
					case "songScore" | "score":
						var v = expr(e2);
						PlayState.songScore = v;
						return v;
					case "misses":
						var v = expr(e2);
						PlayState.misses = v;
						return v;
					case "deaths":
						var v = expr(e2);
						PlayState.deaths = v;
						return v;
				}
			default:
		}
		return super.assign(e1, e2);
	}

	override function evalAssignOp(op:String, fop:Dynamic->Dynamic->Dynamic, e1:hscript.Expr, e2:hscript.Expr):Dynamic {
		switch (hscript.Tools.expr(e1)) {
			case EIdent(id):
				switch (id) {
					case "health":
						var v = fop(PlayState.health, expr(e2));
						PlayState.health = v;
						return v;
					case "combo":
						var v = fop(PlayState.combo, expr(e2));
						PlayState.combo = v;
						return v;
					case "songScore" | "score":
						var v = fop(PlayState.songScore, expr(e2));
						PlayState.songScore = v;
						return v;
					case "misses":
						var v = fop(PlayState.misses, expr(e2));
						PlayState.misses = v;
						return v;
					case "deaths":
						var v = fop(PlayState.deaths, expr(e2));
						PlayState.deaths = v;
						return v;
				}
			default:
		}
		return super.evalAssignOp(op, fop, e1, e2);
	}

	override function resolve(id:String):Dynamic {
		if (locals.exists(id)) return locals.get(id).r;
		switch (id) {
			case "health": return PlayState.health;
			case "combo": return PlayState.combo;
			case "songScore" | "score": return PlayState.songScore;
			case "misses": return PlayState.misses;
			case "deaths": return PlayState.deaths;
		}
		return super.resolve(id);
	}
}

class HScriptHandler {
	// Keep references to commonly imported classes so Haxe DCE/compiler always includes them for Type.resolveClass
	private static var _keptClasses:Array<Dynamic> = [
		flixel.FlxBasic,
		flixel.FlxCamera,
		flixel.FlxGame,
		flixel.FlxObject,
		flixel.FlxState,
		flixel.FlxSubState,
		flixel.addons.display.FlxBackdrop,
		flixel.addons.display.FlxGridOverlay,
		flixel.addons.display.FlxRuntimeShader,
		flixel.addons.display.FlxTiledSprite,
		flixel.addons.effects.FlxTrail,
		flixel.addons.effects.FlxTrailArea,
		flixel.addons.transition.FlxTransitionableState,
		flixel.effects.FlxFlicker,
		flixel.effects.particles.FlxEmitter.FlxTypedEmitter,
		flixel.effects.particles.FlxParticle,
		flixel.graphics.FlxGraphic,
		flixel.graphics.frames.FlxAtlasFrames,
		flixel.graphics.frames.FlxFilterFrames,
		flixel.group.FlxGroup.FlxTypedGroup,
		flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup,
		flixel.math.FlxAngle,
		flixel.math.FlxMath,
		flixel.math.FlxPoint.FlxBasePoint,
		flixel.math.FlxPoint.FlxCallbackPoint,
		flixel.math.FlxRandom,
		flixel.math.FlxRect,
		flixel.math.FlxVelocity,
		flixel.sound.FlxSound,
		flixel.text.FlxBitmapText,
		flixel.text.FlxText,
		flixel.tweens.FlxEase,
		flixel.tweens.FlxTween,
		flixel.ui.FlxBar,
		flixel.ui.FlxButton,
		flixel.util.FlxCollision,
		flixel.util.FlxGradient,
		flixel.util.FlxSave,
		flixel.util.FlxSort,
		flixel.util.FlxSpriteUtil,
		flixel.util.FlxStringUtil,
		flixel.util.FlxTimer,
		openfl.Lib,
		openfl.display.Bitmap,
		openfl.display.BitmapData,
		openfl.display.Shape,
		openfl.display.Sprite,
		openfl.filters.BlurFilter,
		openfl.filters.ColorMatrixFilter,
		openfl.filters.DropShadowFilter,
		openfl.filters.GlowFilter,
		openfl.filters.ShaderFilter,
		openfl.geom.ColorTransform,
		openfl.geom.Matrix,
		openfl.geom.Point,
		openfl.geom.Rectangle,
		openfl.utils.Assets,
		#if hxvlc
		hxvlc.flixel.FlxVideo,
		hxvlc.flixel.FlxVideoSprite,
		hxvlc.openfl.Video,
		#end
		haxe.Json,
		haxe.Timer
	];

	public static function getFlxColorProxy():Dynamic {
		var proxy:Dynamic = {
			BLACK: flixel.util.FlxColor.BLACK,
			WHITE: flixel.util.FlxColor.WHITE,
			GRAY: flixel.util.FlxColor.GRAY,
			GREY: flixel.util.FlxColor.GRAY,
			RED: flixel.util.FlxColor.RED,
			GREEN: flixel.util.FlxColor.GREEN,
			LIME: flixel.util.FlxColor.LIME,
			BLUE: flixel.util.FlxColor.BLUE,
			YELLOW: flixel.util.FlxColor.YELLOW,
			ORANGE: flixel.util.FlxColor.ORANGE,
			PURPLE: flixel.util.FlxColor.PURPLE,
			BROWN: flixel.util.FlxColor.BROWN,
			PINK: flixel.util.FlxColor.PINK,
			MAGENTA: flixel.util.FlxColor.MAGENTA,
			CYAN: flixel.util.FlxColor.CYAN,
			TRANSPARENT: flixel.util.FlxColor.TRANSPARENT,
			fromInt: function(val:Int):Int return cast flixel.util.FlxColor.fromInt(val),
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int return cast flixel.util.FlxColor.fromRGB(r, g, b, a),
			fromRGBFloat: function(r:Float, g:Float, b:Float, a:Float = 1.0):Int return cast flixel.util.FlxColor.fromRGBFloat(r, g, b, a),
			fromCMYK: function(c:Float, m:Float, y:Float, k:Float, a:Float = 1.0):Int return cast flixel.util.FlxColor.fromCMYK(c, m, y, k, a),
			fromHSB: function(h:Float, s:Float, b:Float, a:Float = 1.0):Int return cast flixel.util.FlxColor.fromHSB(h, s, b, a),
			fromHSL: function(h:Float, s:Float, l:Float, a:Float = 1.0):Int return cast flixel.util.FlxColor.fromHSL(h, s, l, a),
			fromString: function(str:String):Null<Int> return cast flixel.util.FlxColor.fromString(str),
			interpolate: function(c1:Int, c2:Int, factor:Float = 0.5):Int return cast flixel.util.FlxColor.interpolate(c1, c2, factor)
		};
		if (flixel.util.FlxColor.colorLookup != null) {
			for (k => v in flixel.util.FlxColor.colorLookup) {
				Reflect.setField(proxy, k, v);
			}
		}
		return proxy;
	}

	public static function getFlxAxesProxy():Dynamic {
		return {
			X: flixel.util.FlxAxes.X,
			Y: flixel.util.FlxAxes.Y,
			XY: flixel.util.FlxAxes.XY,
			NONE: flixel.util.FlxAxes.NONE,
			fromBools: flixel.util.FlxAxes.fromBools,
			fromString: flixel.util.FlxAxes.fromString
		};
	}

	public static function getFlxTweenTypeProxy():Dynamic {
		return {
			PERSIST: flixel.tweens.FlxTween.FlxTweenType.PERSIST,
			LOOPING: flixel.tweens.FlxTween.FlxTweenType.LOOPING,
			PINGPONG: flixel.tweens.FlxTween.FlxTweenType.PINGPONG,
			ONESHOT: flixel.tweens.FlxTween.FlxTweenType.ONESHOT,
			BACKWARD: flixel.tweens.FlxTween.FlxTweenType.BACKWARD
		};
	}

	public static function getFlxTextAlignProxy():Dynamic {
		return {
			LEFT: flixel.text.FlxText.FlxTextAlign.LEFT,
			CENTER: flixel.text.FlxText.FlxTextAlign.CENTER,
			RIGHT: flixel.text.FlxText.FlxTextAlign.RIGHT,
			JUSTIFY: flixel.text.FlxText.FlxTextAlign.JUSTIFY
		};
	}

	public static function getFlxTextBorderStyleProxy():Dynamic {
		return {
			NONE: flixel.text.FlxText.FlxTextBorderStyle.NONE,
			SHADOW: flixel.text.FlxText.FlxTextBorderStyle.SHADOW,
			OUTLINE: flixel.text.FlxText.FlxTextBorderStyle.OUTLINE,
			OUTLINE_FAST: flixel.text.FlxText.FlxTextBorderStyle.OUTLINE_FAST
		};
	}

	public static function getFlxKeyProxy():Dynamic {
		var proxy:Dynamic = {
			fromString: function(s:String):Int return cast flixel.input.keyboard.FlxKey.fromString(s),
			toStringMap: flixel.input.keyboard.FlxKey.toStringMap,
			fromStringMap: flixel.input.keyboard.FlxKey.fromStringMap
		};
		if (flixel.input.keyboard.FlxKey.fromStringMap != null) {
			for (k => v in flixel.input.keyboard.FlxKey.fromStringMap) {
				Reflect.setField(proxy, k, cast(v, Int));
			}
		}
		return proxy;
	}

	public static function getBlendModeProxy():Dynamic {
		return {
			ADD: openfl.display.BlendMode.ADD,
			ALPHA: openfl.display.BlendMode.ALPHA,
			DARKEN: openfl.display.BlendMode.DARKEN,
			DIFFERENCE: openfl.display.BlendMode.DIFFERENCE,
			ERASE: openfl.display.BlendMode.ERASE,
			HARDLIGHT: openfl.display.BlendMode.HARDLIGHT,
			INVERT: openfl.display.BlendMode.INVERT,
			LAYER: openfl.display.BlendMode.LAYER,
			LIGHTEN: openfl.display.BlendMode.LIGHTEN,
			MULTIPLY: openfl.display.BlendMode.MULTIPLY,
			NORMAL: openfl.display.BlendMode.NORMAL,
			OVERLAY: openfl.display.BlendMode.OVERLAY,
			SCREEN: openfl.display.BlendMode.SCREEN,
			SHADER: openfl.display.BlendMode.SHADER,
			SUBTRACT: openfl.display.BlendMode.SUBTRACT
		};
	}

	public static function getCountdownStepProxy():Dynamic {
		return {
			BEFORE: funkin.play.Countdown.CountdownStep.BEFORE,
			THREE: funkin.play.Countdown.CountdownStep.THREE,
			TWO: funkin.play.Countdown.CountdownStep.TWO,
			ONE: funkin.play.Countdown.CountdownStep.ONE,
			GO: funkin.play.Countdown.CountdownStep.GO,
			AFTER: funkin.play.Countdown.CountdownStep.AFTER
		};
	}

	public static function createEnumProxy(enm:Enum<Dynamic>):Dynamic {
		if (enm == null) return null;
		var proxy:Dynamic = {};
		for (name in Type.getEnumConstructs(enm)) {
			try {
				var val = Type.createEnum(enm, name);
				Reflect.setField(proxy, name, val);
			} catch (e:Dynamic) {
				Reflect.setField(proxy, name, Reflect.makeVarArgs(function(args:Array<Dynamic>) {
					return Type.createEnum(enm, name, args);
				}));
			}
		}
		return proxy;
	}

	public static function resolveImport(fullPath:String):Dynamic {
		if (fullPath == null) return null;
		var cleaned = StringTools.trim(fullPath);
		while (StringTools.endsWith(cleaned, ";")) {
			cleaned = StringTools.trim(cleaned.substr(0, cleaned.length - 1));
		}
		if (cleaned == "") return null;

		// 1. Check special Haxe abstract / typedef / proxy types
		switch (cleaned) {
			case "flixel.util.FlxColor" | "FlxColor":
				return getFlxColorProxy();
			case "flixel.util.FlxAxes" | "FlxAxes":
				return getFlxAxesProxy();
			case "flixel.tweens.FlxTween.FlxTweenType" | "flixel.tweens.FlxTweenType" | "FlxTweenType":
				return getFlxTweenTypeProxy();
			case "flixel.text.FlxTextAlign" | "flixel.text.FlxText.FlxTextAlign" | "FlxTextAlign":
				return getFlxTextAlignProxy();
			case "flixel.text.FlxTextBorderStyle" | "flixel.text.FlxText.FlxTextBorderStyle" | "FlxTextBorderStyle":
				return getFlxTextBorderStyleProxy();
			case "flixel.input.keyboard.FlxKey" | "FlxKey":
				return getFlxKeyProxy();
			case "flixel.math.FlxPoint" | "FlxPoint":
				return flixel.math.FlxPoint.FlxBasePoint;
			case "flixel.group.FlxGroup" | "flixel.group.FlxGroup.FlxTypedGroup" | "flixel.group.FlxTypedGroup" | "FlxGroup" | "FlxTypedGroup":
				return flixel.group.FlxGroup.FlxTypedGroup;
			case "flixel.group.FlxSpriteGroup" | "flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup" | "flixel.group.FlxTypedSpriteGroup" | "FlxSpriteGroup" | "FlxTypedSpriteGroup":
				return flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
			case "flixel.group.FlxContainer" | "flixel.group.FlxContainer.FlxTypedContainer" | "flixel.group.FlxTypedContainer" | "FlxContainer" | "FlxTypedContainer":
				return flixel.group.FlxContainer.FlxTypedContainer;
			case "flixel.group.FlxSpriteContainer" | "flixel.group.FlxSpriteContainer.FlxTypedSpriteContainer" | "flixel.group.FlxTypedSpriteContainer" | "FlxSpriteContainer" | "FlxTypedSpriteContainer":
				return flixel.group.FlxSpriteContainer.FlxTypedSpriteContainer;
			case "flixel.effects.particles.FlxEmitter" | "flixel.effects.particles.FlxEmitter.FlxTypedEmitter" | "flixel.effects.particles.FlxTypedEmitter" | "FlxEmitter" | "FlxTypedEmitter":
				return flixel.effects.particles.FlxEmitter.FlxTypedEmitter;
			case "openfl.display.BlendMode" | "BlendMode":
				return getBlendModeProxy();
			case "backend.FunkinShader" | "FunkinShader":
				return backend.FunkinShader.FunkinShaderImpl;
			case "funkin.play.Countdown.CountdownStep" | "funkin.play.CountdownStep" | "CountdownStep":
				return getCountdownStepProxy();
		}

		// 2. Try standard Class / Enum resolution
		var cls:Dynamic = Type.resolveClass(cleaned);
		if (cls != null) return cls;

		var enm:Enum<Dynamic> = Type.resolveEnum(cleaned);
		if (enm != null) return createEnumProxy(enm);

		// 3. Handle module subtypes (e.g. pkg.Module.SubType -> pkg.SubType)
		var parts = cleaned.split(".");
		if (parts.length >= 2) {
			var subParts = parts.copy();
			subParts.splice(subParts.length - 2, 1);
			var altPath = subParts.join(".");

			cls = Type.resolveClass(altPath);
			if (cls != null) return cls;

			enm = Type.resolveEnum(altPath);
			if (enm != null) return createEnumProxy(enm);
		}

		return null;
	}

	private static var _wildcardPackages:Map<String, Array<String>> = [
		"flixel" => ["flixel.FlxG", "flixel.FlxBasic", "flixel.FlxObject", "flixel.FlxSprite", "flixel.FlxCamera", "flixel.FlxState", "flixel.FlxSubState"],
		"flixel.util" => ["flixel.util.FlxColor", "flixel.util.FlxAxes", "flixel.util.FlxTimer", "flixel.util.FlxSort", "flixel.util.FlxGradient", "flixel.util.FlxSpriteUtil", "flixel.util.FlxStringUtil", "flixel.util.FlxCollision", "flixel.util.FlxSave"],
		"flixel.math" => ["flixel.math.FlxMath", "flixel.math.FlxPoint", "flixel.math.FlxRect", "flixel.math.FlxAngle", "flixel.math.FlxVelocity", "flixel.math.FlxRandom"],
		"flixel.tweens" => ["flixel.tweens.FlxTween", "flixel.tweens.FlxTween.FlxTweenType", "flixel.tweens.FlxEase"],
		"flixel.text" => ["flixel.text.FlxText", "flixel.text.FlxTextAlign", "flixel.text.FlxTextBorderStyle", "flixel.text.FlxBitmapText"],
		"flixel.group" => ["flixel.group.FlxGroup", "flixel.group.FlxGroup.FlxTypedGroup", "flixel.group.FlxSpriteGroup"],
		"flixel.ui" => ["flixel.ui.FlxBar", "flixel.ui.FlxBar.FlxBarFillDirection", "flixel.ui.FlxButton"],
		"flixel.effects" => ["flixel.effects.FlxFlicker"],
		"flixel.effects.particles" => ["flixel.effects.particles.FlxEmitter", "flixel.effects.particles.FlxParticle"],
		"flixel.addons.display" => ["flixel.addons.display.FlxBackdrop", "flixel.addons.display.FlxRuntimeShader", "flixel.addons.display.FlxGridOverlay", "flixel.addons.display.FlxTiledSprite"],
		"flixel.addons.effects" => ["flixel.addons.effects.FlxTrail", "flixel.addons.effects.FlxTrailArea"],
		"flixel.addons.transition" => ["flixel.addons.transition.FlxTransitionableState"],
		"flixel.sound" => ["flixel.sound.FlxSound"],
		"flixel.graphics" => ["flixel.graphics.FlxGraphic"],
		"flixel.graphics.frames" => ["flixel.graphics.frames.FlxAtlasFrames", "flixel.graphics.frames.FlxFilterFrames"],
		"flixel.input.keyboard" => ["flixel.input.keyboard.FlxKey"],
		"openfl.display" => ["openfl.display.Bitmap", "openfl.display.BitmapData", "openfl.display.Sprite", "openfl.display.Shape", "openfl.display.BlendMode"],
		"openfl.filters" => ["openfl.filters.ShaderFilter", "openfl.filters.BlurFilter", "openfl.filters.ColorMatrixFilter", "openfl.filters.DropShadowFilter", "openfl.filters.GlowFilter"],
		"openfl.geom" => ["openfl.geom.Matrix", "openfl.geom.Point", "openfl.geom.Rectangle", "openfl.geom.ColorTransform"],
		"backend" => ["backend.Conductor", "backend.CoolUtil", "backend.Mods", "backend.Timings", "backend.Section", "backend.Song", "backend.Highscore", "backend.HScriptHandler", "backend.ModState", "backend.ModSubState", "backend.FunkinShader"],
		"funkin.objects" => ["funkin.objects.Character", "funkin.objects.Stage", "funkin.objects.FunkinSprites", "funkin.objects.FunkinArrows", "funkin.objects.FunkinArrows.Note", "funkin.objects.FunkinArrows.UIStaticArrow", "funkin.objects.FunkinArrows.NoteSplash", "funkin.objects.FunkinArrows.Strumline", "funkin.objects.HealthIcon", "funkin.objects.Alphabet"],
		"funkin.states" => ["funkin.states.PlayState", "funkin.states.MainMenuState", "funkin.states.FreeplayState", "funkin.states.StoryMenuState", "funkin.states.TitleState", "funkin.states.OptionsMenuState", "funkin.states.CreditsState", "funkin.states.ModsMenuState", "funkin.states.MusicBeatState"],
		"funkin.substates" => ["funkin.substates.GameOverSubstate", "funkin.substates.PauseSubState", "funkin.substates.MusicBeatSubstate"],
		"funkin.game.modchart" => ["funkin.game.modchart.ModManager"]
	];

	public static function importClassToInterp(interp:Interp, fullPath:String, ?alias:String):Dynamic {
		if (interp == null || fullPath == null) return null;
		var cleaned = StringTools.trim(fullPath);
		while (StringTools.endsWith(cleaned, ";")) {
			cleaned = StringTools.trim(cleaned.substr(0, cleaned.length - 1));
		}
		if (cleaned == "") return null;

		// Handle wildcard imports: import pkg.*;
		if (StringTools.endsWith(cleaned, ".*")) {
			var pkg = cleaned.substr(0, cleaned.length - 2);
			if (_wildcardPackages.exists(pkg)) {
				for (clsPath in _wildcardPackages.get(pkg)) {
					importClassToInterp(interp, clsPath, null);
				}
			}
			return null;
		}

		var parts = cleaned.split(".");
		var shortName = (alias != null && StringTools.trim(alias) != "") ? StringTools.trim(alias) : parts[parts.length - 1];
		var resolved = resolveImport(cleaned);

		if (resolved != null) {
			interp.variables.set(shortName, resolved);

			// Also expose companion module subtypes when importing a multi-type module without an alias
			if (alias == null || StringTools.trim(alias) == "") {
				switch (cleaned) {
					case "flixel.ui.FlxBar":
						var dir = resolveImport("flixel.ui.FlxBar.FlxBarFillDirection");
						if (dir != null) interp.variables.set("FlxBarFillDirection", dir);
					case "flixel.group.FlxGroup":
						var tg = resolveImport("flixel.group.FlxGroup.FlxTypedGroup");
						if (tg != null) interp.variables.set("FlxTypedGroup", tg);
					case "flixel.tweens.FlxTween":
						interp.variables.set("FlxTweenType", getFlxTweenTypeProxy());
					case "flixel.text.FlxText":
						interp.variables.set("FlxTextAlign", getFlxTextAlignProxy());
						interp.variables.set("FlxTextBorderStyle", getFlxTextBorderStyleProxy());
					case "funkin.objects.FunkinArrows":
						interp.variables.set("Note", funkin.objects.FunkinArrows.Note);
						interp.variables.set("UIStaticArrow", funkin.objects.FunkinArrows.UIStaticArrow);
						interp.variables.set("NoteSplash", funkin.objects.FunkinArrows.NoteSplash);
						interp.variables.set("Strumline", funkin.objects.FunkinArrows.Strumline);
				}
			}
			return resolved;
		}

		if (interp.variables.exists(shortName)) {
			return interp.variables.get(shortName);
		}

		trace('[HScript] Warning: Could not resolve import "' + cleaned + '"');
		return null;
	}

	public static function preprocessScript(scriptText:String, interp:Interp):String {
		if (scriptText == null) return "";
		var strippedLines:Array<String> = [];

		for (line in scriptText.split("\n")) {
			var trimmed = StringTools.trim(line);
			var commentIdx = trimmed.indexOf("//");
			var checkLine = commentIdx >= 0 ? StringTools.trim(trimmed.substr(0, commentIdx)) : trimmed;

			if (StringTools.startsWith(checkLine, "import ") || StringTools.startsWith(checkLine, "import\t")
				|| StringTools.startsWith(checkLine, "using ") || StringTools.startsWith(checkLine, "using\t")
				|| StringTools.startsWith(checkLine, "package ") || StringTools.startsWith(checkLine, "package\t")
				|| checkLine == "package" || StringTools.startsWith(checkLine, "package;")) {

				var remainingStatements:Array<String> = [];
				for (stmt in checkLine.split(";")) {
					var s = StringTools.trim(stmt);
					if (s == "") continue;

					if (StringTools.startsWith(s, "package ") || StringTools.startsWith(s, "package\t") || s == "package") {
						// Ignore package declarations
					} else if (StringTools.startsWith(s, "import ") || StringTools.startsWith(s, "import\t")) {
						var target = StringTools.trim(s.substr(6));
						var norm = StringTools.replace(target, "\t", " ");
						var asIdx = norm.indexOf(" as ");
						var inIdx = norm.indexOf(" in ");
						if (asIdx > 0) {
							var path = StringTools.trim(norm.substr(0, asIdx));
							var alias = StringTools.trim(norm.substr(asIdx + 4));
							importClassToInterp(interp, path, alias);
						} else if (inIdx > 0) {
							var path = StringTools.trim(norm.substr(0, inIdx));
							var alias = StringTools.trim(norm.substr(inIdx + 4));
							importClassToInterp(interp, path, alias);
						} else {
							importClassToInterp(interp, norm, null);
						}
					} else if (StringTools.startsWith(s, "using ") || StringTools.startsWith(s, "using\t")) {
						var target = StringTools.trim(s.substr(5));
						importClassToInterp(interp, target, null);
					} else {
						remainingStatements.push(stmt);
					}
				}

				if (remainingStatements.length > 0) {
					strippedLines.push(remainingStatements.join(";") + ";");
				} else {
					strippedLines.push("");
				}
			} else {
				strippedLines.push(line);
			}
		}

		return strippedLines.join("\n");
	}

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

		// Dynamic import helpers available inside HScript
		setVar("importClass", function(className:String, ?alias:String):Dynamic {
			return importClassToInterp(interp, className, alias);
		});
		setVar("resolveClass", function(className:String):Dynamic {
			return resolveImport(className);
		});

		// Base Haxe/Flixel Classes
		setVar("FlxG", FlxG);
		setVar("FlxSprite", FlxSprite);
		setVar("FlxMath", FlxMath);
		setVar("FlxTimer", FlxTimer);
		setVar("FlxTween", FlxTween);
		setVar("FlxTweenType", getFlxTweenTypeProxy());
		setVar("FlxEase", FlxEase);
		setVar("FlxColor", getFlxColorProxy());
		setVar("FlxObject", flixel.FlxObject);
		setVar("FlxFlicker", flixel.effects.FlxFlicker);
		setVar("FlxGroup", flixel.group.FlxGroup.FlxTypedGroup);
		setVar("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
		setVar("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
		setVar("FlxBackdrop", flixel.addons.display.FlxBackdrop);
		setVar("FlxText", flixel.text.FlxText);
		setVar("FlxAxes", getFlxAxesProxy());
		setVar("Application", lime.app.Application);
		setVar("FlxTextAlign", getFlxTextAlignProxy());
		setVar("FlxTextBorderStyle", getFlxTextBorderStyleProxy());
		setVar("FlxKey", getFlxKeyProxy());
		setVar("FlxPoint", flixel.math.FlxPoint.FlxBasePoint);
		setVar("BlendMode", getBlendModeProxy());
		
		setVar("Math", Math);
		setVar("Std", Std);
		setVar("StringTools", StringTools);
		setVar("Sys", Sys);
		setVar("Type", Type);
		setVar("Reflect", Reflect);
		setVar("Json", haxe.Json);

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
		setVar("FunkinArrows", funkin.objects.FunkinArrows);
		setVar("Note", funkin.objects.FunkinArrows.Note);
		setVar("UIStaticArrow", funkin.objects.FunkinArrows.UIStaticArrow);
		setVar("NoteSplash", funkin.objects.FunkinArrows.NoteSplash);
		#if hxvlc
		setVar("FlxVideoSprite", hxvlc.flixel.FlxVideoSprite);
		setVar("FlxVideo", hxvlc.flixel.FlxVideo);
		#end
		setVar("playSong", PlayState.playSong);
		setVar("setReturnState", PlayState.setReturnState);
		setVar("getReturnState", PlayState.getReturnState);

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
			setVar("camGame2", PlayState.camGame2);
			setVar("camGame", PlayState.camGame);
			setVar("camHUD", PlayState.camHUD);
			setVar("camAlt", PlayState.camAlt);

			// Gameplay controls
			setVar("restartSong", function() { if (PlayState.instance != null) PlayState.instance.restartSong(); });
			setVar("playVideo", function(videoName:String, ?shouldCenter:Bool = true, ?scale:Float = 1.0):Dynamic {
				if (PlayState.instance != null) return PlayState.instance.playVideo(videoName, shouldCenter, scale);
				return null;
			});
			setVar("startVideo", function(nameOrPath:String, ?onComplete:Void->Void) {
				if (PlayState.instance != null) PlayState.instance.startVideo(nameOrPath, onComplete);
			});
			setVar("skipCutscene", function() {
				if (PlayState.instance != null) PlayState.instance.skipCutscene();
			});
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

		// Countdown
		setVar("Countdown", funkin.play.Countdown);
		setVar("CountdownStep", getCountdownStepProxy());

		try {
			var scriptText = File.getContent(scriptPath);
			var strippedText = preprocessScript(scriptText, interp);
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

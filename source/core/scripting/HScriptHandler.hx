package core.scripting;

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
import gameplay.PlayState;
import gameplay.objects.Character;
import gameplay.objects.Stage;
import Main;
import menus.CreditsState;
import menus.MainMenuState;
import menus.FreeplayState;
import menus.TitleState;
import menus.OptionsMenuState;
import menus.ModsMenuState;

class CustomInterp extends hscript.Interp {
	override public function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o == PlayState || o == PlayState.instance || Std.isOfType(o, PlayState)) {
			switch (f) {
				case "health": PlayState.health = v; return v;
				case "combo": PlayState.combo = v; return v;
				case "songScore" | "score": PlayState.songScore = v; return v;
				case "misses": PlayState.misses = v; return v;
				case "deaths": PlayState.deaths = v; return v;
				case "curStage":
					if (PlayState.instance != null) PlayState.instance.changeStage(v);
					else PlayState.curStage = v;
					return v;
				case "defaultCamZoom": PlayState.defaultCamZoom = v; return v;
				case "cameraSpeed": PlayState.cameraSpeed = v; return v;
				case "camZooming": PlayState.camZooming = v; return v;
				case "camZoomingMult": PlayState.camZoomingMult = v; return v;
				case "camZoomingFrequency": PlayState.camZoomingFrequency = v; return v;
				case "camZoomSpeed":
					if (PlayState.instance != null) PlayState.instance.camZoomSpeed = v;
					return v;
				case "boyfriend": PlayState.boyfriend = v; return v;
				case "dad" | "dadOpponent": PlayState.dadOpponent = v; return v;
				case "gf": PlayState.gf = v; return v;
				case "camGame2": PlayState.camGame2 = v; return v;
				case "camGame": PlayState.camGame = v; return v;
				case "camHUD": PlayState.camHUD = v; return v;
				case "camAlt": PlayState.camAlt = v; return v;
				case "healthBar":
					if (PlayState.instance != null) PlayState.instance.healthBar = v;
					return v;
				case "healthBarBG":
					if (PlayState.instance != null) PlayState.instance.healthBarBG = v;
					return v;
				case "healthBarClipRect":
					if (PlayState.instance != null) {
						PlayState.instance.healthBarClipRect = v;
						if (PlayState.instance.healthBar != null) PlayState.instance.healthBar.clipRect = v;
					}
					return v;
				case "healthBarPosition":
					if (PlayState.instance != null) PlayState.instance.healthBarPosition = v;
					return v;
				case "healthBarOffset":
					if (PlayState.instance != null) PlayState.instance.healthBarOffset = v;
					return v;
				case "healthBarInnerOffset":
					if (PlayState.instance != null) PlayState.instance.healthBarInnerOffset = v;
					return v;
				case "healthBarScale":
					if (PlayState.instance != null) PlayState.instance.healthBarScale = v;
					return v;
				case "healthBarAlpha":
					if (PlayState.instance != null) PlayState.instance.healthBarAlpha = v;
					return v;
				case "showHealthBar":
					if (PlayState.instance != null) PlayState.instance.showHealthBar = v;
					return v;
				case "showIcons":
					if (PlayState.instance != null) PlayState.instance.showIcons = v;
					return v;
				case "iconOffset":
					if (PlayState.instance != null) PlayState.instance.iconOffset = v;
					return v;
				case "iconBopScale":
					if (PlayState.instance != null) PlayState.instance.iconBopScale = v;
					return v;
				case "iconP1Offset":
					if (PlayState.instance != null) PlayState.instance.iconP1Offset = v;
					return v;
				case "iconP2Offset":
					if (PlayState.instance != null) PlayState.instance.iconP2Offset = v;
					return v;
				case "scoreBarOffset":
					if (PlayState.instance != null) PlayState.instance.scoreBarOffset = v;
					return v;
				case "showScoreBar":
					if (PlayState.instance != null) PlayState.instance.showScoreBar = v;
					return v;
				case "scoreTemplate":
					if (PlayState.instance != null) PlayState.instance.scoreTemplate = v;
					return v;
				case "customScoreText":
					if (PlayState.instance != null) PlayState.instance.customScoreText = v;
					return v;
				case "ratingOffset":
					if (PlayState.instance != null) PlayState.instance.ratingOffset = v;
					return v;
				case "comboOffset":
					if (PlayState.instance != null) PlayState.instance.comboOffset = v;
					return v;
				case "ratingScale":
					if (PlayState.instance != null) PlayState.instance.ratingScale = v;
					return v;
				case "comboScale":
					if (PlayState.instance != null) PlayState.instance.comboScale = v;
					return v;
				case "showRating":
					if (PlayState.instance != null) PlayState.instance.showRating = v;
					return v;
				case "showCombo":
					if (PlayState.instance != null) PlayState.instance.showCombo = v;
					return v;
				case "bfCamOffset":
					if (PlayState.instance != null) PlayState.instance.bfCamOffset = v;
					return v;
				case "dadCamOffset":
					if (PlayState.instance != null) PlayState.instance.dadCamOffset = v;
					return v;
				case "gfCamOffset":
					if (PlayState.instance != null) PlayState.instance.gfCamOffset = v;
					return v;
				case "camFollowOffset":
					if (PlayState.instance != null) PlayState.instance.camFollowOffset = v;
					return v;
			}
		}
		if (o == core.utils.WindowUtil || o == "WindowUtil") {
			switch (f) {
				case "borderless": core.utils.WindowUtil.borderless = v; return v;
				case "x": core.utils.WindowUtil.x = Std.int(v); return v;
				case "y": core.utils.WindowUtil.y = Std.int(v); return v;
				case "width": core.utils.WindowUtil.width = Std.int(v); return v;
				case "height": core.utils.WindowUtil.height = Std.int(v); return v;
				case "title": core.utils.WindowUtil.title = Std.string(v); return v;
			}
		}
		if (Std.isOfType(o, core.system.FunkinShader.FunkinShaderImpl) || Std.isOfType(o, flixel.addons.display.FlxRuntimeShader)) {
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
				case "downscroll" | "downScroll":
					return PlayState.instance != null ? PlayState.instance.downscroll : Init.trueSettings.get('Downscroll');
				case "triggerEvent": return PlayState.instance != null ? PlayState.instance.triggerEvent : null;
				case "changeStage": return PlayState.instance != null ? PlayState.instance.changeStage : null;
				case "getRandomStage": return PlayState.getRandomStage;
				case "stageBuild": return PlayState.instance != null ? PlayState.instance.stageBuild : null;
				case "playCharacterAnim": return PlayState.instance != null ? PlayState.instance.playCharacterAnim : null;
				case "addCameraZoom": return PlayState.instance != null ? PlayState.instance.addCameraZoom : null;
				case "playVideo": return PlayState.instance != null ? PlayState.instance.playVideo : null;
				case "startVideo": return PlayState.instance != null ? PlayState.instance.startVideo : null;
				case "skipCutscene": return PlayState.instance != null ? PlayState.instance.skipCutscene : null;
				case "playSong": return PlayState.playSong;
				case "setReturnState": return PlayState.setReturnState;
				case "getReturnState": return PlayState.getReturnState;
				case "endSong": return PlayState.instance != null ? PlayState.instance.endSong : null;
				case "callDefaultSongEnd": return PlayState.instance != null ? PlayState.instance.callDefaultSongEnd : null;
				case "healthBar": return PlayState.instance != null ? PlayState.instance.healthBar : null;
				case "healthBarBG": return PlayState.instance != null ? PlayState.instance.healthBarBG : null;
				case "healthBarClipRect": return PlayState.instance != null ? PlayState.instance.healthBarClipRect : null;
				case "changeHealthBar": return PlayState.instance != null ? PlayState.instance.changeHealthBar : null;
				case "camZoomSpeed": return PlayState.instance != null ? PlayState.instance.camZoomSpeed : 1.0;
				case "inst": return PlayState.songMusic;
				case "playerVocals": return PlayState.vocals;
				case "scoreBar": return PlayState.instance != null ? PlayState.instance.scoreBar : null;
				case "iconP1": return PlayState.instance != null ? PlayState.instance.iconP1 : null;
				case "iconP2": return PlayState.instance != null ? PlayState.instance.iconP2 : null;
				case "centerMark": return PlayState.instance != null ? PlayState.instance.centerMark : null;
				case "autoplayMark": return PlayState.instance != null ? PlayState.instance.autoplayMark : null;
				case "camFollow": return PlayState.instance != null ? PlayState.instance.camFollow : null;
				case "camFollowPos": return PlayState.instance != null ? PlayState.instance.camFollowPos : null;
				case "camFollowOffset": return PlayState.instance != null ? PlayState.instance.camFollowOffset : null;
				case "bfCamOffset": return PlayState.instance != null ? PlayState.instance.bfCamOffset : null;
				case "dadCamOffset": return PlayState.instance != null ? PlayState.instance.dadCamOffset : null;
				case "gfCamOffset": return PlayState.instance != null ? PlayState.instance.gfCamOffset : null;
				case "moveCamera": return PlayState.instance != null ? PlayState.instance.moveCamera : null;
				case "moveCameraTo": return PlayState.instance != null ? PlayState.instance.moveCameraTo : null;
				case "snapCamera": return PlayState.instance != null ? PlayState.instance.snapCamera : null;
				case "setCameraTarget": return PlayState.instance != null ? PlayState.instance.setCameraTarget : null;
				case "camPosTo": return PlayState.instance != null ? PlayState.instance.camPosTo : null;
				case "healthBarPosition": return PlayState.instance != null ? PlayState.instance.healthBarPosition : null;
				case "healthBarOffset": return PlayState.instance != null ? PlayState.instance.healthBarOffset : null;
				case "healthBarInnerOffset": return PlayState.instance != null ? PlayState.instance.healthBarInnerOffset : null;
				case "healthBarScale": return PlayState.instance != null ? PlayState.instance.healthBarScale : null;
				case "healthBarAlpha": return PlayState.instance != null ? PlayState.instance.healthBarAlpha : 1.0;
				case "showHealthBar": return PlayState.instance != null ? PlayState.instance.showHealthBar : true;
				case "showIcons": return PlayState.instance != null ? PlayState.instance.showIcons : true;
				case "iconOffset": return PlayState.instance != null ? PlayState.instance.iconOffset : 26.0;
				case "iconBopScale": return PlayState.instance != null ? PlayState.instance.iconBopScale : 1.2;
				case "iconP1Offset": return PlayState.instance != null ? PlayState.instance.iconP1Offset : null;
				case "iconP2Offset": return PlayState.instance != null ? PlayState.instance.iconP2Offset : null;
				case "scoreBarOffset": return PlayState.instance != null ? PlayState.instance.scoreBarOffset : null;
				case "showScoreBar": return PlayState.instance != null ? PlayState.instance.showScoreBar : true;
				case "scoreTemplate": return PlayState.instance != null ? PlayState.instance.scoreTemplate : "";
				case "customScoreText": return PlayState.instance != null ? PlayState.instance.customScoreText : null;
				case "updateScoreText": return PlayState.instance != null ? PlayState.instance.updateScoreText : null;
				case "ratingOffset": return PlayState.instance != null ? PlayState.instance.ratingOffset : null;
				case "comboOffset": return PlayState.instance != null ? PlayState.instance.comboOffset : null;
				case "ratingScale": return PlayState.instance != null ? PlayState.instance.ratingScale : 0.5;
				case "comboScale": return PlayState.instance != null ? PlayState.instance.comboScale : 0.3;
				case "showRating": return PlayState.instance != null ? PlayState.instance.showRating : true;
				case "showCombo": return PlayState.instance != null ? PlayState.instance.showCombo : true;
				case "setHUDAlpha": return PlayState.instance != null ? PlayState.instance.setHUDAlpha : null;
				case "setHUDVisible": return PlayState.instance != null ? PlayState.instance.setHUDVisible : null;
				case "reloadHUD": return PlayState.instance != null ? PlayState.instance.reloadHUD : null;
				case "updateColors": return PlayState.instance != null ? PlayState.instance.setHealthBarColors : null;
				case "setHealthBarColors": return PlayState.instance != null ? PlayState.instance.setHealthBarColors : null;
				case "modManager": return PlayState.instance != null ? PlayState.instance.modManager : null;
			}
		}
		if (o == flixel.FlxG && f == "switchState") {
			return function(nextState:Dynamic) {
				if (PlayState.instance != null) PlayState.instance.customEndState = true;
				var s:flixel.FlxState = null;
				if (Std.isOfType(nextState, flixel.FlxState)) s = cast nextState;
				else if (Reflect.isFunction(nextState)) {
					var res = nextState();
					if (Std.isOfType(res, flixel.FlxState)) s = cast res;
				}
				if (s != null) {
					var current:flixel.FlxState = (PlayState.instance != null ? PlayState.instance : flixel.FlxG.state);
					Main.switchState(current, s);
				} else {
					flixel.FlxG.switchState(nextState);
				}
			};
		}
		if (o == flixel.FlxG.sound && f == "playMusic") {
			return function(asset:Dynamic, vol:Float=1.0, loop:Bool=true) { flixel.FlxG.sound.playMusic(asset, vol, loop); };
		}
		if (Std.isOfType(o, flixel.sound.FlxSound) && f == "fadeIn") {
			return function(dur:Float, from:Float=0.0, to:Float=1.0) { cast(o, flixel.sound.FlxSound).fadeIn(dur, from, to); };
		}
		if (o == core.utils.WindowUtil || o == "WindowUtil") {
			switch (f) {
				case "borderless": return core.utils.WindowUtil.borderless;
				case "x": return core.utils.WindowUtil.x;
				case "y": return core.utils.WindowUtil.y;
				case "width": return core.utils.WindowUtil.width;
				case "height": return core.utils.WindowUtil.height;
				case "title": return core.utils.WindowUtil.title;
				case "scale": return core.utils.WindowUtil.scale;
				case "defaultWidth": return core.utils.WindowUtil.defaultWidth;
				case "defaultHeight": return core.utils.WindowUtil.defaultHeight;
				case "defaultTitle": return core.utils.WindowUtil.defaultTitle;
			}
		}
		if (Std.isOfType(o, core.system.FunkinShader.FunkinShaderImpl) || Std.isOfType(o, flixel.addons.display.FlxRuntimeShader)) {
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
					case "defaultCamZoom":
						var v = expr(e2);
						PlayState.defaultCamZoom = v;
						return v;
					case "cameraSpeed":
						var v = expr(e2);
						PlayState.cameraSpeed = v;
						return v;
					case "camZoomSpeed":
						var v = expr(e2);
						if (PlayState.instance != null) PlayState.instance.camZoomSpeed = v;
						return v;
					case "camZooming":
						var v = expr(e2);
						PlayState.camZooming = v;
						return v;
					case "camZoomingMult":
						var v = expr(e2);
						PlayState.camZoomingMult = v;
						return v;
					case "camZoomingFrequency":
						var v = expr(e2);
						PlayState.camZoomingFrequency = v;
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
					case "defaultCamZoom":
						var v = fop(PlayState.defaultCamZoom, expr(e2));
						PlayState.defaultCamZoom = v;
						return v;
					case "cameraSpeed":
						var v = fop(PlayState.cameraSpeed, expr(e2));
						PlayState.cameraSpeed = v;
						return v;
					case "camZoomSpeed":
						var cur = PlayState.instance != null ? PlayState.instance.camZoomSpeed : 1.0;
						var v = fop(cur, expr(e2));
						if (PlayState.instance != null) PlayState.instance.camZoomSpeed = v;
						return v;
					case "camZoomingMult":
						var v = fop(PlayState.camZoomingMult, expr(e2));
						PlayState.camZoomingMult = v;
						return v;
					case "camZoomingFrequency":
						var v = fop(PlayState.camZoomingFrequency, expr(e2));
						PlayState.camZoomingFrequency = v;
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
			case "defaultCamZoom": return PlayState.defaultCamZoom;
			case "cameraSpeed": return PlayState.cameraSpeed;
			case "camZoomSpeed": return PlayState.instance != null ? PlayState.instance.camZoomSpeed : 1.0;
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
			case "songMusic" | "inst": return PlayState.songMusic;
			case "vocals" | "playerVocals": return PlayState.vocals;
			case "opponentVocals": return PlayState.opponentVocals;
			case "curStage": return PlayState.curStage;
			case "downscroll" | "downScroll":
				return PlayState.instance != null ? PlayState.instance.downscroll : Init.trueSettings.get('Downscroll');
			case "stageBuild": return PlayState.instance != null ? PlayState.instance.stageBuild : null;
			case "modManager": return PlayState.instance != null ? PlayState.instance.modManager : null;
			case "healthBar": return PlayState.instance != null ? PlayState.instance.healthBar : null;
			case "healthBarBG": return PlayState.instance != null ? PlayState.instance.healthBarBG : null;
			case "healthBarClipRect": return PlayState.instance != null ? PlayState.instance.healthBarClipRect : null;
			case "scoreBar": return PlayState.instance != null ? PlayState.instance.scoreBar : null;
			case "iconP1": return PlayState.instance != null ? PlayState.instance.iconP1 : null;
			case "iconP2": return PlayState.instance != null ? PlayState.instance.iconP2 : null;
			case "centerMark": return PlayState.instance != null ? PlayState.instance.centerMark : null;
			case "autoplayMark": return PlayState.instance != null ? PlayState.instance.autoplayMark : null;
			case "camFollow": return PlayState.instance != null ? PlayState.instance.camFollow : null;
			case "camFollowPos": return PlayState.instance != null ? PlayState.instance.camFollowPos : null;
			case "camFollowOffset": return PlayState.instance != null ? PlayState.instance.camFollowOffset : null;
			case "bfCamOffset": return PlayState.instance != null ? PlayState.instance.bfCamOffset : null;
			case "dadCamOffset": return PlayState.instance != null ? PlayState.instance.dadCamOffset : null;
			case "gfCamOffset": return PlayState.instance != null ? PlayState.instance.gfCamOffset : null;
		}
		return super.resolve(id);
	}
}

class HScriptHandler {
	// Keep references to commonly imported classes so Haxe DCE/compiler always includes them for Type.resolveClass
	private static var _keptClasses:Array<Dynamic> = [
		Main,
		menus.CreditsState,
		menus.MainMenuState,
		menus.FreeplayState,
		menus.TitleState,
		menus.OptionsMenuState,
		menus.ModsMenuState,
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
			BEFORE: gameplay.Countdown.CountdownStep.BEFORE,
			THREE: gameplay.Countdown.CountdownStep.THREE,
			TWO: gameplay.Countdown.CountdownStep.TWO,
			ONE: gameplay.Countdown.CountdownStep.ONE,
			GO: gameplay.Countdown.CountdownStep.GO,
			AFTER: gameplay.Countdown.CountdownStep.AFTER
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
			case "backend.FunkinShader" | "core.system.FunkinShader" | "FunkinShader":
				return core.system.FunkinShader.FunkinShaderImpl;
			case "funkin.play.Countdown.CountdownStep" | "funkin.play.CountdownStep" | "gameplay.Countdown.CountdownStep" | "gameplay.CountdownStep" | "CountdownStep":
				return getCountdownStepProxy();
			case "menus.CreditsState" | "CreditsState":
				return menus.CreditsState;
			case "menus.MainMenuState" | "MainMenuState":
				return menus.MainMenuState;
			case "menus.FreeplayState" | "FreeplayState":
				return menus.FreeplayState;
			case "menus.TitleState" | "TitleState":
				return menus.TitleState;
			case "menus.OptionsMenuState" | "OptionsMenuState":
				return menus.OptionsMenuState;
			case "menus.ModsMenuState" | "ModsMenuState":
				return menus.ModsMenuState;
			case "Main":
				return Main;
			case "core.utils.WindowUtil" | "WindowUtil" | "WinUtil":
				return core.utils.WindowUtil;
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
		"core.base" => ["core.base.Init", "core.base.MusicBeatState", "core.base.MusicBeatSubState", "core.base.FunkinState"],
		"core.system" => ["core.system.Paths", "core.system.Assets", "core.system.Discord", "core.system.FunkinMemory", "core.system.FunkinShader", "core.system.FunkinTransition", "core.system.FunkinSprites", "core.system.CursorManager", "core.system.WebPUtil"],
		"core.save" => ["core.save.SaveData", "core.save.SaveManager", "core.save.Highscore", "core.save.ClientPrefs"],
		"core.input" => ["core.input.Controls", "core.input.PlayerSettings"],
		"core.scripting" => ["core.scripting.HScriptHandler", "core.scripting.Mods", "core.scripting.ModState"],
		"core.utils" => ["core.utils.CoolUtil", "core.utils.Utils", "core.utils.MathUtil", "core.utils.Vector3", "core.utils.WindowUtil"],
		"gameplay" => ["gameplay.PlayState", "gameplay.Conductor", "gameplay.Timings", "gameplay.Countdown"],
		"gameplay.chart" => ["gameplay.chart.Song", "gameplay.chart.Section", "gameplay.chart.ChartLoader", "gameplay.chart.ChartConverter"],
		"gameplay.objects" => ["gameplay.objects.Character", "gameplay.objects.Boyfriend", "gameplay.objects.Stage", "gameplay.objects.FunkinArrows"],
		"gameplay.hud" => ["gameplay.hud.HealthIcon", "gameplay.hud.ClassHUD"],
		"gameplay.dialogue" => ["gameplay.dialogue.Dialogue", "gameplay.dialogue.DialogueBox"],
		"gameplay.substates" => ["gameplay.substates.GameOverSubstate", "gameplay.substates.PauseSubState"],
		"gameplay.modchart" => ["gameplay.modchart.ModManager"],
		"menus" => ["menus.TitleState", "menus.MainMenuState", "menus.FreeplayState", "menus.OptionsMenuState", "menus.CreditsState", "menus.ModsMenuState", "menus.WeekData"],
		"menus.objects" => ["menus.objects.Alphabet", "menus.objects.MenuItem", "menus.objects.MenuCharacter", "menus.objects.Selector", "menus.objects.Checkmark"],
		"editors" => ["editors.ChartEditor", "editors.CharacterEditor", "editors.CameraEditor"],
		"editors.dev" => ["editors.dev.DevConsole", "editors.dev.DebugUI", "editors.dev.Overlay", "editors.dev.TestState"],
		"backend" => ["gameplay.Conductor", "core.utils.CoolUtil", "core.scripting.Mods", "gameplay.Timings", "gameplay.chart.Section", "gameplay.chart.Song", "core.save.Highscore", "core.scripting.HScriptHandler", "core.scripting.ModState", "core.system.FunkinShader"],
		"funkin.objects" => ["gameplay.objects.Character", "gameplay.objects.Stage", "core.system.FunkinSprites", "gameplay.objects.FunkinArrows", "gameplay.hud.HealthIcon", "menus.objects.Alphabet"],
		"funkin.states" => ["gameplay.PlayState", "menus.MainMenuState", "menus.FreeplayState", "menus.TitleState", "menus.OptionsMenuState", "menus.CreditsState", "menus.ModsMenuState", "core.base.MusicBeatState"],
		"funkin.substates" => ["gameplay.substates.GameOverSubstate", "gameplay.substates.PauseSubState", "core.base.MusicBeatSubState"]
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
					case "gameplay.objects.FunkinArrows":
						interp.variables.set("Note", gameplay.objects.FunkinArrows.Note);
						interp.variables.set("UIStaticArrow", gameplay.objects.FunkinArrows.UIStaticArrow);
						interp.variables.set("NoteSplash", gameplay.objects.FunkinArrows.NoteSplash);
						interp.variables.set("Strumline", gameplay.objects.FunkinArrows.Strumline);
					case "core.utils.WindowUtil":
						interp.variables.set("WinUtil", core.utils.WindowUtil);
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
	public var stage:gameplay.objects.Stage;
	public var builtinVariables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var functionCache:Map<String, Dynamic> = new Map<String, Dynamic>();
	private static final NO_FUNC:Dynamic = {};

	public function new(scriptPath:String, ?stage:gameplay.objects.Stage = null) {
		this.stage = stage;
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
		setVar("FunkinShader", core.system.FunkinShader.FunkinShaderImpl);
		setVar("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		setVar("ShaderFilter", openfl.filters.ShaderFilter);
		setVar("createShader", function(frag:String, ?vert:String) {
			return core.system.FunkinShader.FunkinShaderImpl.fromFile(frag, vert);
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
			return core.system.FunkinShader.FunkinShaderImpl.tweenAnyShader(shader, uniform, arg1, arg2, arg3, arg4, arg5);
		});
		setVar("cancelShaderTween", function(shader:Dynamic, ?uniform:String) {
			core.system.FunkinShader.FunkinShaderImpl.cancelAnyShaderTween(shader, uniform);
		});

		// Game Specific Classes & Utilities
		setVar("PlayState", PlayState);
		setVar("Paths", Paths);
		setVar("WebPUtil", core.system.WebPUtil);
		setVar("CursorManager", core.system.CursorManager);
		setVar("Character", Character);
		setVar("Conductor", gameplay.Conductor);
		setVar("Mods", core.scripting.Mods);
		setVar("CoolUtil", core.utils.CoolUtil);
		setVar("WindowUtil", core.utils.WindowUtil);
		setVar("WinUtil", core.utils.WindowUtil);
		setVar("winMove", core.utils.WindowUtil.winMove);
		setVar("winScale", core.utils.WindowUtil.winScale);
		setVar("winName", core.utils.WindowUtil.winName);
		setVar("winBorderless", core.utils.WindowUtil.winBorderless);
		setVar("winCenter", core.utils.WindowUtil.winCenter);
		setVar("winReset", core.utils.WindowUtil.winReset);
		setVar("FunkinArrows", gameplay.objects.FunkinArrows);
		setVar("Note", gameplay.objects.FunkinArrows.Note);
		setVar("UIStaticArrow", gameplay.objects.FunkinArrows.UIStaticArrow);
		setVar("NoteSplash", gameplay.objects.FunkinArrows.NoteSplash);
		setVar("FunkinSprites", core.system.FunkinSprites);
		setVar("GameOverSubstate", gameplay.substates.GameOverSubstate);
		#if hxvlc
		setVar("FlxVideoSprite", hxvlc.flixel.FlxVideoSprite);
		setVar("FlxVideo", hxvlc.flixel.FlxVideo);
		#end

		// Modchart Classes
		setVar("ModManager", gameplay.modchart.ModManager);
		setVar("Vector3", core.utils.Vector3);
		setVar("MathUtil", core.utils.MathUtil);

		// Menus, States & Navigation
		setVar("CreditsState", menus.CreditsState);
		setVar("MainMenuState", menus.MainMenuState);
		setVar("FreeplayState", menus.FreeplayState);
		setVar("TitleState", menus.TitleState);
		setVar("OptionsMenuState", menus.OptionsMenuState);
		setVar("ModsMenuState", menus.ModsMenuState);
		setVar("ModSwitchMenu", menus.ModSwitchMenu);
		setVar("Main", Main);
		setVar("Function_Stop", "stop");
		setVar("Function_Continue", "continue");

		var switchStateFunc = function(target:Dynamic, ?curState:Dynamic) {
			if (PlayState.instance != null) PlayState.instance.customEndState = true;
			var state:flixel.FlxState = null;
			if (Std.isOfType(target, flixel.FlxState)) {
				state = cast target;
			} else if (Std.isOfType(target, Class)) {
				state = Type.createInstance(cast target, []);
			} else if (Reflect.isFunction(target)) {
				var res = target();
				if (Std.isOfType(res, flixel.FlxState)) state = cast res;
			} else if (Std.isOfType(target, String)) {
				var str:String = StringTools.trim(Std.string(target));
				if (StringTools.endsWith(str, ".hx")) str = str.substr(0, str.length - 3);
				switch (str.toLowerCase()) {
					case "creditsstate" | "credits" | "credit":
						state = new menus.CreditsState();
					case "mainmenustate" | "mainmenu" | "main":
						state = new menus.MainMenuState();
					case "freeplaystate" | "freeplay":
						state = new menus.FreeplayState();
					case "titlestate" | "title":
						state = new menus.TitleState();
					case "optionsmenustate" | "optionsstate" | "options" | "option":
						state = new menus.OptionsMenuState();
					case "modsmenustate" | "modsmenu" | "mods":
						state = new menus.ModsMenuState();
					default:
						var resolvedCls:Dynamic = HScriptHandler.resolveImport(str);
						if (resolvedCls != null && Std.isOfType(resolvedCls, Class)) {
							state = Type.createInstance(resolvedCls, []);
						} else {
							state = new core.scripting.ModState(str);
						}
				}
			}
			if (state != null) {
				var current:flixel.FlxState = (curState != null && Std.isOfType(curState, flixel.FlxState)) ? cast curState : (PlayState.instance != null ? PlayState.instance : flixel.FlxG.state);
				Main.switchState(current, state);
			} else {
				trace("[HScript] Error: switchState called with invalid target: " + target);
			}
		};
		setVar("switchState", switchStateFunc);

		// Load PlayState and Stage variables
		loadPlayStateVariables(PlayState.instance, stage);

		// Snapshot built-in variables so call() won't mistake engine helpers for script callbacks
		for (k => v in interp.variables) {
			builtinVariables.set(k, v);
		}

		try {
			if (scriptPath != null && scriptPath != "") {
				var scriptText = File.getContent(scriptPath);
				var strippedText = preprocessScript(scriptText, interp);
				var expr = parser.parseString(strippedText);
				interp.execute(expr);
			}
		} catch(e:Dynamic) {
			trace("Error loading script " + scriptName + ": " + e);
			active = false;
		}
	}

	public static function injectPlayState(script:HScriptHandler, ?ps:PlayState, ?stage:gameplay.objects.Stage):Void {
		if (script != null) script.loadPlayStateVariables(ps, stage);
	}

	public function loadPlayStateVariables(?playState:PlayState, ?targetStage:gameplay.objects.Stage):Void {
		var ps:PlayState = playState != null ? playState : PlayState.instance;
		var st:gameplay.objects.Stage = targetStage != null ? targetStage : this.stage;
		if (st == null && ps != null) {
			st = ps.stageBuild;
		}
		if (this.stage == null && st != null) {
			this.stage = st;
		}

		// Stage-specific variables & object management
		if (st != null) {
			setVar("stage", st);
			setVar("background", st.background);
			setVar("foreground", st.foreground);
			setVar("add", function(obj:Dynamic) {
				if (st.inCreatePost)
					st.foreground.add(cast obj);
				else
					st.background.add(cast obj);
			});
			setVar("remove", function(obj:Dynamic, ?splice:Bool = true) {
				st.background.remove(cast obj, true);
				st.foreground.remove(cast obj, true);
			});
			setVar("insert", function(pos:Int, obj:Dynamic) {
				if (st.inCreatePost)
					st.foreground.insert(pos, cast obj);
				else
					st.background.insert(pos, cast obj);
			});
			setVar("stageImage", function(key:String, ?stageName:String, ?library:String, ?comp:Null<Bool> = null) {
				return Paths.stageImage(key, stageName != null ? stageName : st.curStage, library, comp);
			});
			setVar("sparrowImage", function(key:String, ?stageName:String, ?library:String, ?comp:Null<Bool> = null) {
				return Paths.sparrowImage(key, stageName != null ? stageName : st.curStage, library, comp);
			});
		} else {
			setVar("add", function(obj:flixel.FlxBasic) {
				if (PlayState.instance != null) PlayState.instance.add(obj);
			});
			setVar("remove", function(obj:flixel.FlxBasic, splice:Bool = false) {
				if (PlayState.instance != null) PlayState.instance.remove(obj, splice);
			});
			setVar("insert", function(pos:Int, obj:flixel.FlxBasic) {
				if (PlayState.instance != null) PlayState.instance.insert(pos, obj);
			});
			setVar("stageImage", function(key:String, ?stageName:String, ?library:String, ?comp:Null<Bool> = null) {
				return Paths.stageImage(key, stageName != null ? stageName : Paths.currentStage, library, comp);
			});
			setVar("sparrowImage", function(key:String, ?stageName:String, ?library:String, ?comp:Null<Bool> = null) {
				return Paths.sparrowImage(key, stageName != null ? stageName : Paths.currentStage, library, comp);
			});
		}

		// Song & State variables
		var curSongName:String = (PlayState.SONG != null && PlayState.SONG.song != null) ? PlayState.SONG.song.toLowerCase() : '';
		setVar("songName", curSongName);
		setVar("curSong", curSongName);
		setVar("SONG", PlayState.SONG);
		setVar("curStage", PlayState.curStage);

		// Countdown
		setVar("Countdown", gameplay.Countdown);
		setVar("CountdownStep", {
			BEFORE: gameplay.Countdown.CountdownStep.BEFORE,
			THREE: gameplay.Countdown.CountdownStep.THREE,
			TWO: gameplay.Countdown.CountdownStep.TWO,
			ONE: gameplay.Countdown.CountdownStep.ONE,
			GO: gameplay.Countdown.CountdownStep.GO,
			AFTER: gameplay.Countdown.CountdownStep.AFTER
		});
		setVar("startCountdown", function() {
			if (PlayState.instance != null) PlayState.instance.startCountdown();
		});
		setVar("skipCountdown", gameplay.Countdown.skipCountdown);

		// Song & Gameplay functions
		setVar("triggerEvent", function(eventName:String, value1:String, value2:String) {
			if (PlayState.instance != null) PlayState.instance.triggerEvent(eventName, value1, value2);
		});
		setVar("changeStage", function(target:String, ?reposition:Bool = true, ?zoom:Null<Float> = null) {
			if (PlayState.instance != null) PlayState.instance.changeStage(target, reposition, zoom);
		});
		setVar("getRandomStage", function(?excludeCurrent:String) {
			return PlayState.getRandomStage(excludeCurrent);
		});
		setVar("playCharacterAnim", function(char:Dynamic, anim:String, ?force:Bool = false, ?ignoreArrows:Bool = false) {
			if (PlayState.instance != null) {
				var targetChar:gameplay.objects.Character = null;
				if (Std.isOfType(char, gameplay.objects.Character)) {
					targetChar = cast char;
				} else if (Std.isOfType(char, String)) {
					var str = StringTools.trim(Std.string(char).toLowerCase());
					if (str == '0' || str == 'bf' || str == 'boyfriend' || str == 'player') targetChar = PlayState.boyfriend;
					else if (str == '2' || str == 'gf' || str == 'girlfriend') targetChar = PlayState.gf;
					else targetChar = PlayState.dadOpponent;
				}
				if (targetChar != null) PlayState.instance.playCharacterAnim(targetChar, anim, force, ignoreArrows);
			}
		});
		setVar("addCameraZoom", function(?game:Float = 0.05, ?hud:Float = 0.03) {
			if (PlayState.instance != null) PlayState.instance.addCameraZoom(game, hud);
		});
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
		setVar("playSong", PlayState.playSong);
		setVar("setReturnState", PlayState.setReturnState);
		setVar("getReturnState", PlayState.getReturnState);
		setVar("restartSong", function() {
			if (PlayState.instance != null) PlayState.instance.restartSong();
		});
		setVar("endSong", function() {
			if (PlayState.instance != null) PlayState.instance.endSong();
		});
		setVar("callDefaultSongEnd", function() {
			if (PlayState.instance != null) PlayState.instance.callDefaultSongEnd();
		});
		setVar("changeCharacter", function(charType:Dynamic, newChar:String, ?x:Null<Float>, ?y:Null<Float>) {
			if (PlayState.instance != null) {
				var idx:Int = 1;
				if (Std.isOfType(charType, Int)) idx = cast charType;
				else {
					var str = StringTools.trim(Std.string(charType).toLowerCase());
					if (str == '0' || str == 'bf' || str == 'boyfriend' || str == 'player') idx = 0;
					else if (str == '2' || str == 'gf' || str == 'girlfriend') idx = 2;
					else idx = 1;
				}
				PlayState.instance.changeCharacter(idx, newChar, x, y);
			}
		});

		// Characters
		setVar("boyfriend", PlayState.boyfriend);
		setVar("dad", PlayState.dadOpponent);
		setVar("dadOpponent", PlayState.dadOpponent);
		setVar("gf", PlayState.gf);

		// Music & Vocals
		setVar("songMusic", PlayState.songMusic);
		setVar("inst", PlayState.songMusic);
		setVar("vocals", PlayState.vocals);
		setVar("playerVocals", PlayState.vocals);
		setVar("opponentVocals", PlayState.opponentVocals);

		// Cameras & Display
		setVar("camGame2", PlayState.camGame2);
		setVar("camGame", PlayState.camGame);
		setVar("camHUD", PlayState.camHUD);
		setVar("camAlt", PlayState.camAlt);

		// Camera control methods & variables
		setVar("cameraSpeed", PlayState.cameraSpeed);
		setVar("camZooming", PlayState.camZooming);
		setVar("camZoomingMult", PlayState.camZoomingMult);
		setVar("camZoomingFrequency", PlayState.camZoomingFrequency);
		setVar("defaultCamZoom", PlayState.defaultCamZoom);

		if (ps != null) {
			setVar("game", ps);
			setVar("downscroll", ps.downscroll);
			setVar("downScroll", ps.downscroll);
			setVar("camZoomSpeed", ps.camZoomSpeed);
			setVar("camFollow", ps.camFollow);
			setVar("camFollowPos", ps.camFollowPos);
			setVar("moveCamera", function(char:Dynamic, ?forced:Bool = false) { ps.moveCamera(char, forced); });
			setVar("moveCameraTo", function(targetName:String, ?forced:Bool = false) { ps.moveCameraTo(targetName, forced); });
			setVar("snapCamera", function(?pos:flixel.math.FlxPoint = null) { ps.snapCamera(pos); });
			setVar("setCameraTarget", function(arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic) {
				if (PlayState.instance != null) {
					if (Std.isOfType(arg1, Float) || Std.isOfType(arg1, Int)) {
						var x:Float = cast arg1;
						var y:Float = (arg2 != null) ? cast arg2 : 0.0;
						var snap:Bool = (arg3 != null) ? cast arg3 : false;
						PlayState.instance.setCameraTarget(x, y, snap);
					} else {
						PlayState.instance.moveCamera(arg1, arg2 == true);
					}
				}
			});
			setVar("camPosTo", function(?x:Null<Float>, ?y:Null<Float>, ?timeSteps:Float = 0, ?ease:String = 'linear') {
				ps.camPosTo(x, y, timeSteps, ease);
			});
			setVar("bfCamOffset", ps.bfCamOffset);
			setVar("dadCamOffset", ps.dadCamOffset);
			setVar("gfCamOffset", ps.gfCamOffset);
			setVar("camFollowOffset", ps.camFollowOffset);

			// HUD elements & customization
			setVar("iconP1", ps.iconP1);
			setVar("iconP2", ps.iconP2);
			setVar("healthBar", ps.healthBar);
			setVar("healthBarBG", ps.healthBarBG);
			setVar("healthBarClipRect", ps.healthBarClipRect);
			setVar("scoreBar", ps.scoreBar);
			setVar("centerMark", ps.centerMark);
			setVar("autoplayMark", ps.autoplayMark);
			setVar("healthBarPosition", ps.healthBarPosition);
			setVar("healthBarOffset", ps.healthBarOffset);
			setVar("healthBarInnerOffset", ps.healthBarInnerOffset);
			setVar("healthBarScale", ps.healthBarScale);
			setVar("healthBarAlpha", ps.healthBarAlpha);
			setVar("showHealthBar", ps.showHealthBar);
			setVar("showIcons", ps.showIcons);
			setVar("iconOffset", ps.iconOffset);
			setVar("iconBopScale", ps.iconBopScale);
			setVar("iconP1Offset", ps.iconP1Offset);
			setVar("iconP2Offset", ps.iconP2Offset);
			setVar("scoreBarOffset", ps.scoreBarOffset);
			setVar("showScoreBar", ps.showScoreBar);
			setVar("scoreTemplate", ps.scoreTemplate);
			setVar("customScoreText", ps.customScoreText);
			setVar("updateScoreText", function() { ps.updateScoreText(); });
			setVar("ratingOffset", ps.ratingOffset);
			setVar("comboOffset", ps.comboOffset);
			setVar("ratingScale", ps.ratingScale);
			setVar("comboScale", ps.comboScale);
			setVar("showRating", ps.showRating);
			setVar("showCombo", ps.showCombo);
			setVar("setHUDAlpha", function(a:Float) { ps.setHUDAlpha(a); });
			setVar("setHUDVisible", function(v:Bool) { ps.setHUDVisible(v); });
			setVar("reloadHUD", function() { ps.reloadHUD(); });
			setVar("updateColors", function(p1:Dynamic, p2:Dynamic) { ps.setHealthBarColors(p1, p2); });
			setVar("setHealthBarColors", function(p1:Dynamic, p2:Dynamic) { ps.setHealthBarColors(p1, p2); });
			setVar("changeHealthBar", function(?arg0:Dynamic, ?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic, ?arg6:Dynamic) {
				ps.changeHealthBar(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
			});

			// Modchart
			setVar("modManager", ps.modManager);
			setVar("queueEase", function(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
				if (ps.modManager != null) ps.modManager.queueEase(step, endStep, modName, target, style, player, startVal);
			});
			setVar("queueSet", function(step:Float, modName:String, target:Float, player:Int = -1) {
				if (ps.modManager != null) ps.modManager.queueSet(step, modName, target, player);
			});
			setVar("queueEaseP", function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) {
				if (ps.modManager != null) ps.modManager.queueEaseP(step, endStep, modName, percent, style, player, startVal);
			});
			setVar("queueSetP", function(step:Float, modName:String, percent:Float, player:Int = -1) {
				if (ps.modManager != null) ps.modManager.queueSetP(step, modName, percent, player);
			});
			setVar("queueFunc", function(step:Float, endStep:Float, callback:Dynamic) {
				if (ps.modManager != null) ps.modManager.queueFunc(step, endStep, callback);
			});
			setVar("queueFuncOnce", function(step:Float, callback:Dynamic) {
				if (ps.modManager != null) ps.modManager.queueFuncOnce(step, callback);
			});
			setVar("setValue", function(modName:String, val:Float, player:Int = -1) {
				if (ps.modManager != null) ps.modManager.setValue(modName, val, player);
			});
			setVar("setPercent", function(modName:String, val:Float, player:Int = -1) {
				if (ps.modManager != null) ps.modManager.setPercent(modName, val, player);
			});
			setVar("getValue", function(modName:String, player:Int = 0):Float {
				if (ps.modManager != null) return ps.modManager.getValue(modName, player);
				return 0.0;
			});
			setVar("getPercent", function(modName:String, player:Int = 0):Float {
				if (ps.modManager != null) return ps.modManager.getPercent(modName, player);
				return 0.0;
			});
		} else {
			setVar("downscroll", core.base.Init.trueSettings.get('Downscroll'));
			setVar("downScroll", core.base.Init.trueSettings.get('Downscroll'));
			setVar("changeHealthBar", function(?arg0:Dynamic, ?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic, ?arg6:Dynamic) {
				PlayState.changeHealthBarStatic(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
			});
		}
	}

	public function setVar(name:String, value:Dynamic) {
		interp.variables.set(name, value);
		if (functionCache.exists(name))
			functionCache.remove(name);
	}

	public function getVar(name:String):Dynamic {
		return interp.variables.get(name);
	}

	public function call(functionName:String, ?args:Array<Dynamic>):Dynamic {
		if (!active) return null;

		var targetFunc:Dynamic = null;
		if (functionCache.exists(functionName)) {
			targetFunc = functionCache.get(functionName);
			if (targetFunc == NO_FUNC) return null;
		} else {
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
			} else if (functionName == "endSong" || functionName == "onEndSong") {
				aliases = ["endSong", "onEndSong"];
			}

			var reservedFunctions:Array<String> = [
				"triggerEvent", "restartSong", "changeCharacter", "changeStage", "getRandomStage", "camPosTo", 
				"add", "remove", "insert", "addCameraZoom", "playCharacterAnim", "playVideo", "startVideo",
				"skipCutscene", "startCountdown", "skipCountdown", "playSong", "setReturnState", "getReturnState",
				"updateScoreText", "setHUDAlpha", "setHUDVisible", "reloadHUD", "updateColors", "setHealthBarColors",
				"changeHealthBar", "switchState", "endSong", "callDefaultSongEnd", "moveCamera", "moveCameraTo",
				"snapCamera", "setCameraTarget"
			];

			for (name in aliases) {
				if (reservedFunctions.contains(name)) continue;
				if (interp.variables.exists(name)) {
					var f:Dynamic = interp.variables.get(name);
					if (f != null && Reflect.isFunction(f)) {
						if (builtinVariables.exists(name) && f == builtinVariables.get(name)) {
							continue;
						}
						targetFunc = f;
						break;
					}
				}
			}

			functionCache.set(functionName, targetFunc != null ? targetFunc : NO_FUNC);
			if (targetFunc == null) return null;
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

	public function destroy():Void {
		active = false;
		stage = null;
		if (functionCache != null) functionCache.clear();
		if (builtinVariables != null) builtinVariables.clear();
		if (interp != null && interp.variables != null) interp.variables.clear();
		interp = null;
		parser = null;
	}
}

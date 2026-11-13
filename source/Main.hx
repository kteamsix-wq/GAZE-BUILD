package;

import editors.*;

import openfl.events.ErrorEvent;
import openfl.errors.Error;
import haxe.Json;
import sys.Http;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import haxe.CallStack.StackItem;
import haxe.CallStack;
import haxe.io.Path;
import lime.app.Application;
import core.input.PlayerSettings;
import core.system.Discord;
import core.system.FunkinTransition;
import core.base.FunkinState;
import editors.dev.Overlay;
import core.system.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
using StringTools;

typedef CrashContent = {
	var content:String;
}

class Main extends Sprite
{
	public static var gameWidth:Int = 1280;
	public static var gameHeight:Int = 720;
	public static var mainClassState:Class<FlxState> = PreloadState; // Uses the V-Slice PreloadState instead of Init directly
	public static var framerate:Int = 120;
	public static var gameVersion:String = '0.1-alpha2';
	public static var lastState:FlxState;

	var zoom:Float = -1;
	var skipSplash:Bool = true;
	var infoCounter:Overlay;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

		#if (html5 || neko)
		framerate = 60;
		#end

		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		FlxTransitionableState.skipNextTransIn = true;

		var gameCreate:FlxGame = new FlxGame(gameWidth, gameHeight, mainClassState, #if (flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash);
		addChild(gameCreate);

		core.system.FunkinMemory.init();
		core.utils.WindowUtil.init();
		core.system.Paths.initFlxAnimate();

		#if DISCORD_RPC
		Discord.initializeRPC();
		Discord.changePresence('');
		#end

		PlayerSettings.init();

		#if hxvlc
		try {
			hxvlc.util.Handle.init();
		} catch (e:Dynamic) {
			trace('Could not initialize hxvlc: ' + e);
		}
		#end

		infoCounter = new Overlay(0, 0);
		addChild(infoCounter);

		editors.dev.DevConsole.init();
		addChild(editors.dev.DevConsole.instance);
	}

	public static function switchState(curState:FlxState, target:FlxState)
	{
		var stateName:String = Type.getClassName(Type.getClass(target));
		var splitName = stateName.split('.');
		stateName = splitName[splitName.length - 1];
		
		// If it's not already a ModState, check if there's a custom script overriding this state
		if (stateName != "ModState" && stateName != "Init" && stateName != "PreloadState")
		{
			var modsList = core.scripting.Mods.getModDirectories();
			var foundScript = false;
			for (mod in modsList)
			{
				if (sys.FileSystem.exists('mods/' + mod + '/data/states/' + stateName + '.hx'))
				{
					foundScript = true;
					break;
				}
			}
			
			if (foundScript)
			{
				target = new core.scripting.ModState(stateName);
			}
		}

		mainClassState = Type.getClass(target);
		var stateMaker:Void->FlxState = function():FlxState
		{
			if (target != null && target.members != null)
			{
				var inst:FlxState = target;
				target = null;
				return inst;
			}
			if (mainClassState == core.scripting.ModState)
				return new core.scripting.ModState(stateName);
			return Type.createInstance(mainClassState, []);
		};

		var activeState:FlxState = (curState != null) ? curState : FlxG.state;
		if (!FlxTransitionableState.skipNextTransOut && activeState != null)
		{
			var transition = new FunkinTransition(0.35, false, function():Void
			{
				FlxG.switchState(stateMaker);
			});
			activeState.openSubState(transition);
			return;
		}
		FlxTransitionableState.skipNextTransOut = false;
		FlxG.switchState(stateMaker);
	}

	public static function updateFramerate(newFramerate:Int)
	{
		if (newFramerate > FlxG.updateFramerate)
		{
			FlxG.updateFramerate = newFramerate;
			FlxG.drawFramerate = newFramerate;
		}
		else
		{
			FlxG.drawFramerate = newFramerate;
			FlxG.updateFramerate = newFramerate;
		}

		if (FlxG.stage != null)
			FlxG.stage.frameRate = newFramerate;
	}

	function onCrash(e:UncaughtErrorEvent):Void
	{
		var msg:String = "Uncaught Error: " + e.error + "\n\nStack Trace:\n";
		var stacks:Array<StackItem> = CallStack.exceptionStack(true);

		for (stack in stacks)
		{
			switch (stack)
			{
				case FilePos(s, file, line, column):
					msg += file + " (Line " + Std.int(line) + ")\n";
				default:
					msg += "Unknown Stack Item\n";
			}
		}

		msg += "\n\nPlease report this error to the mod developers.";

		try
		{
			if (!FileSystem.exists("crashes"))
				FileSystem.createDirectory("crashes");

			var date = Date.now().toString().replace(" ", "_").replace(":", "-");
			File.saveContent("crashes/crash_" + date + ".txt", msg);
			msg += "\n\n(A crash log has been saved to the 'crashes' folder.)";
		}
		catch (e:Dynamic)
		{
			msg += "\n\n(Failed to save crash log.)";
		}

		Application.current.window.alert(msg, "Fatal Error!");
		Discord.shutdownRPC();
		Sys.exit(1);
	}
}

/**
 * Modern Loading / Preload State
 * Displays the runner and mic-stand loading bar in the bottom-right corner.
 */
class PreloadState extends FlxState
{
	var bg:FlxSprite;
	var runner:FlxSprite;
	var micStandBG:FlxSprite;
	var micStandFill:FlxSprite;
	var fillRect:flixel.math.FlxRect;
	var canTransition:Bool = false;

	override public function create():Void
	{
		super.create();

		core.system.CursorManager.init();
		FlxG.cameras.bgColor = FlxColor.BLACK;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var chosenChar:String = (FlxG.random != null && FlxG.random.bool(50)) ? 'gf' : 'bf';
		var atlas = core.system.Paths.getSparrowAtlas('menus/loading/assets/' + chosenChar);
		if (atlas == null)
			atlas = core.system.Paths.getSparrowAtlas('menus/loading/assets/bf');

		runner = new FlxSprite();
		if (atlas != null)
		{
			runner.frames = atlas;
			runner.animation.addByPrefix('run', 'run', 24, true);
			runner.animation.play('run');
			runner.antialiasing = true;
		}

		if (chosenChar == 'gf')
			runner.scale.set(0.28, 0.28);
		else
			runner.scale.set(0.35, 0.35);
		runner.updateHitbox();

		var barGraphic = core.system.Paths.image('menus/loading/mic-stand');
		var barScale:Float = 0.45;

		micStandBG = new FlxSprite();
		if (barGraphic != null)
		{
			micStandBG.loadGraphic(barGraphic);
			micStandBG.scale.set(barScale, barScale);
			micStandBG.updateHitbox();
			micStandBG.antialiasing = true;
			micStandBG.color = 0xFF222222;
			micStandBG.alpha = 0.4;
		}

		micStandFill = new FlxSprite();
		if (barGraphic != null)
		{
			micStandFill.loadGraphic(barGraphic);
			micStandFill.scale.set(barScale, barScale);
			micStandFill.updateHitbox();
			micStandFill.antialiasing = true;
			micStandFill.color = FlxColor.WHITE;
		}

		var padX:Float = 35;
		var padY:Float = 20;

		micStandBG.x = FlxG.width - micStandBG.width - padX;
		micStandBG.y = FlxG.height - micStandBG.height - padY;

		micStandFill.x = micStandBG.x;
		micStandFill.y = micStandBG.y;

		// Fixed/stationary in the middle of the mic-stand bar
		runner.x = micStandBG.x + (micStandBG.width - runner.width) / 2;
		runner.y = micStandBG.y - runner.height + 15;

		// Add components in proper layering order (no text)
		add(micStandBG);
		add(micStandFill);
		add(runner);

		fillRect = new flixel.math.FlxRect(0, 0, 0, (micStandFill.frameHeight > 0) ? micStandFill.frameHeight : 234);

		runner.alpha = 0;
		micStandBG.alpha = 0;
		micStandFill.alpha = 0;

		FlxTween.tween(runner, {alpha: 1}, 0.25);
		FlxTween.tween(micStandBG, {alpha: 0.4}, 0.25);
		FlxTween.tween(micStandFill, {alpha: 1}, 0.25);

		FlxTween.num(0.0, 1.0, 1.2, {
			ease: FlxEase.quadOut,
			startDelay: 0.1,
			onUpdate: function(t:FlxTween)
			{
				updateProgress(t.percent);
			},
			onComplete: function(t:FlxTween)
			{
				updateProgress(1.0);
				FlxTween.tween(runner, {alpha: 0}, 0.3);
				FlxTween.tween(micStandBG, {alpha: 0}, 0.3);
				FlxTween.tween(micStandFill, {alpha: 0}, 0.3, {
					onComplete: function(_)
					{
						canTransition = true;
					}
				});
			}
		});
	}

	function updateProgress(p:Float):Void
	{
		var cp = flixel.math.FlxMath.bound(p, 0.0, 1.0);
		if (micStandFill != null && micStandFill.graphic != null && fillRect != null)
		{
			var clipW = micStandFill.frameWidth * cp;
			fillRect.set(0, 0, clipW, micStandFill.frameHeight);
			micStandFill.clipRect = fillRect;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (canTransition)
		{
			canTransition = false;
			Main.switchState(this, new core.base.Init());
		}
	}

	override public function destroy():Void
	{
		if (fillRect != null)
		{
			fillRect.put();
			fillRect = null;
		}
		super.destroy();
	}
}

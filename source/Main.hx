package;

import backend.*;
import funkin.objects.*;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;

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
import backend.PlayerSettings;
import backend.Discord;
import funkin.objects.FunkinTransition;
import funkin.objects.FunkinState;
import funkin.objects.Overlay;
import Assets;
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
	public static var gameVersion:String = '0.1-alpha';
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

		#if DISCORD_RPC
		Discord.initializeRPC();
		Discord.changePresence('');
		#end

		PlayerSettings.init();

		infoCounter = new Overlay(0, 0);
		addChild(infoCounter);
	}

	public static function switchState(curState:FlxState, target:FlxState)
	{
		mainClassState = Type.getClass(target);
		if (!FlxTransitionableState.skipNextTransOut)
		{
			var transition = new FunkinTransition(0.35, false, function():Void
			{
				FlxG.switchState(target);
			});
			curState.openSubState(transition);
			return trace('changed state [' + Type.getClassName(Type.getClass(curState)) + ']');
		}
		FlxTransitionableState.skipNextTransOut = false;
		FlxG.switchState(target);
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
 * V-Slice style Preload State
 * Gives a sleek modern loading visual before initializing the game data.
 */
class PreloadState extends FlxState
{
	var loadingText:FlxText;
	var barBG:FlxSprite;
	var barFill:FlxSprite;
	var canTransition:Bool = false;

	override public function create():Void
	{
		super.create();

		FlxG.mouse.visible = false;
		FlxG.cameras.bgColor = FlxColor.BLACK;

		// Clean modern loading text
		loadingText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, "LOADING", 32);
		loadingText.setFormat(null, 32, FlxColor.WHITE, CENTER);
		loadingText.alpha = 0;
		add(loadingText);

		// Loading bar background
		barBG = new FlxSprite(0, FlxG.height / 2 + 20).makeGraphic(400, 6, FlxColor.GRAY);
		barBG.screenCenter(X);
		barBG.alpha = 0;
		add(barBG);

		// The fill (Pink/Magenta style)
		barFill = new FlxSprite(barBG.x, barBG.y).makeGraphic(1, 6, FlxColor.fromInt(0xFFFF0066)); 
		barFill.alpha = 0;
		add(barFill);

		// Fade in animations
		FlxTween.tween(loadingText, {alpha: 1, y: loadingText.y - 10}, 0.6, {ease: FlxEase.quartOut});
		FlxTween.tween(barBG, {alpha: 0.5}, 0.6, {ease: FlxEase.quartOut});
		FlxTween.tween(barFill, {alpha: 1}, 0.6, {ease: FlxEase.quartOut});

		// Simulate loading for the V-Slice "feel"
		FlxTween.tween(barFill.scale, {x: 400}, 1.5, {
			ease: FlxEase.expoOut,
			startDelay: 0.2,
			onUpdate: function(t:FlxTween) {
				barFill.updateHitbox();
			},
			onComplete: function(t:FlxTween) {
				FlxTween.tween(loadingText, {alpha: 0}, 0.3);
				FlxTween.tween(barBG, {alpha: 0}, 0.3);
				FlxTween.tween(barFill, {alpha: 0}, 0.3, {
					onComplete: function(_) {
						canTransition = true;
					}
				});
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (canTransition)
		{
			canTransition = false;
			Main.switchState(this, new Init());
		}
	}
}

package;
import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
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

// Here we actually import the states and metadata, and just the metadata.
// It's nice to have modularity so that we don't have ALL elements loaded at the same time.
// at least that's how I think it works. I could be stupid!
class Main extends Sprite
{
	// class action variables
	public static var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	public static var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).

	public static var mainClassState:Class<FlxState> = Init; // Determine the main class state of the game
	public static var framerate:Int = 120; // How many frames per second the game should run at.

	public static var gameVersion:String = '0.0.1';

	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var infoCounter:Overlay; // initialize the heads up display that shows information before creating it.

	// heres gameweeks set up!

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	// calls a function to set the game up
	public function new()
	{
		super();

		/**
			ok so, haxe html5 CANNOT do 120 fps. it just cannot.
			so here i just set the framerate to 60 if its complied in html5.
			reason why we dont just keep it because the game will act as if its 120 fps, and cause
			note studders and shit its weird.
		**/

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

		#if (html5 || neko)
		framerate = 60;
		#end

		// simply said, a state is like the 'surface' area of the window where everything is drawn.
		// if you've used gamemaker you'll probably understand the term surface better
		// this defines the surface bounds

		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
			// this just kind of sets up the camera zoom in accordance to the surface width and camera zoom.
			// if set to negative one, it is done so automatically, which is the default.
		}

		FlxTransitionableState.skipNextTransIn = true;

		// here we set up the base game
		var gameCreate:FlxGame;
		gameCreate = new FlxGame(gameWidth, gameHeight, mainClassState, #if (flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash);
		addChild(gameCreate); // and create it afterwards

		// default game FPS settings, I'll probably comment over them later.
		// addChild(new FPS(10, 3, 0xFFFFFF));

		// begin the discord rich presence
		#if DISCORD_RPC
		Discord.initializeRPC();
		Discord.changePresence('');
		#end

		// test initialising the player settings
		PlayerSettings.init();

		infoCounter = new Overlay(0, 0);
		addChild(infoCounter);
	}



	/*  This is used to switch "rooms," to put it basically. Imagine you are in the main menu, and press the freeplay button.
		That would change the game's main class to freeplay, as it is the active class at the moment.
	 */
	public static var lastState:FlxState;

	public static function switchState(curState:FlxState, target:FlxState)
	{
		// Custom made Trans out
		mainClassState = Type.getClass(target);
		if (!FlxTransitionableState.skipNextTransOut)
		{
			var transition = new FunkinTransition(0.35, false, function():Void
			{
				FlxG.switchState(target);
			});
			curState.openSubState(transition);
			return trace('changed state');
		}
		FlxTransitionableState.skipNextTransOut = false;
		// load the state
		FlxG.switchState(target);
	}

	public static function updateFramerate(newFramerate:Int)
	{
		// flixel will literally throw errors at me if I dont separate the orders
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






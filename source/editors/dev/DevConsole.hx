package editors.dev;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;
import openfl.text.TextFieldAutoSize;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.Lib;
import haxe.Timer;
import flixel.FlxG;
import flixel.FlxState;
import core.system.FunkinMemory;
import core.utils.CoolUtil;
import gameplay.Conductor;
import core.scripting.HScriptHandler.CustomInterp;
import hscript.Parser;
import core.system.Paths;
import Main;

/**
 * Log entry types for the Developer Console.
 */
enum LogType
{
	TRACE;
	INFO;
	WARN;
	ERROR;
	COMMAND;
	RESULT;
}

#if (cpp && windows)
@:cppFileCode('
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
')
#end
/**
 * Codename Engine-styled In-Game Developer Console Prompt.
 *
 * Features:
 * - Shortcut: [F2] toggles the console open / closed from any state or substate.
 * - Interactive Prompt: Full command interpreter + persistent HScript REPL session.
 * - Real-time Log Stream: Intercepts `haxe.Log.trace` and formats logs with color tags & timestamps.
 * - History Navigation: [UP] and [DOWN] arrows cycle through previously entered commands.
 * - Autocomplete: [TAB] key automatically completes command names.
 * - Draggable Window: Drag the title bar to move the console freely.
 * - Smooth Scrolling: Mouse wheel support + live visual scrollbar.
 * - Keyboard Safety: Disables Flixel game input (`FlxG.keys.enabled = false`) while typing.
 * - Native Terminal: [CMD] button / `cmd` command triggers `AllocConsole()` on Windows C++.
 */
class DevConsole extends Sprite
{
	public static var instance:DevConsole;
	public static var oldTrace:Dynamic = null;

	public var isOpen(default, null):Bool = false;

	// Dimensions and layout
	var windowWidth:Float = 820;
	var windowHeight:Float = 460;
	var titleBarHeight:Float = 28;
	var inputBarHeight:Float = 32;

	// Visual display elements
	var bgShape:Shape;
	var scrollBar:Shape;
	var titleField:TextField;
	var logTextField:TextField;
	var promptLabel:TextField;
	var inputField:TextField;

	// Title bar buttons & drag area
	var titleDragArea:Sprite;
	var clearBtn:Sprite;
	var closeBtn:Sprite;
	#if (cpp && windows)
	var cmdBtn:Sprite;
	#end

	// Dragging state
	var isDragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	// Input history
	var history:Array<String> = [];
	var historyIndex:Int = -1;
	var tempInput:String = "";

	// Log storage (buffer capped at 500 lines to preserve performance)
	static inline final MAX_LOG_LINES:Int = 500;
	static var logLines:Array<String> = [];

	// HScript REPL interpreter & parser
	var parser:Parser;
	var interp:CustomInterp;

	// Track mouse visibility prior to opening
	var wasMouseVisible:Bool = false;

	// Debounce toggle
	static var _lastToggle:Float = 0;

	// Known command list for autocompletion
	static var knownCommands:Array<String> = [
		"help", "clear", "cls", "state", "switch", "reload", "restart",
		"play", "chart", "char", "character", "cam", "camera", "botplay",
		"health", "hp", "score", "misses", "kill", "die", "speed",
		"fps", "vol", "volume", "mute", "unmute", "gc", "clean",
		"mem", "cmd", "allocconsole", "eval", "exit", "close"
	];

	public static function init():Void
	{
		if (instance == null)
		{
			instance = new DevConsole();
			hookTrace();
		}
	}

	public function new()
	{
		super();
		instance = this;
		visible = false;

		// Calculate initial position (centered)
		var stageW:Float = Lib.current.stage != null ? Lib.current.stage.stageWidth : 1280;
		var stageH:Float = Lib.current.stage != null ? Lib.current.stage.stageHeight : 720;

		windowWidth = Math.min(840, stageW - 40);
		windowHeight = Math.min(480, stageH - 60);

		this.x = Math.max(10, (stageW - windowWidth) / 2);
		this.y = Math.max(20, (stageH - windowHeight) / 2);

		// 1. Background & window graphics
		bgShape = new Shape();
		addChild(bgShape);

		// 2. Title bar text
		titleField = new TextField();
		titleField.autoSize = TextFieldAutoSize.LEFT;
		titleField.selectable = false;
		titleField.mouseEnabled = false;
		titleField.defaultTextFormat = new TextFormat("_sans", 12, 0x4FC3F7, true);
		titleField.text = "Codename Console [F2]";
		titleField.x = 10;
		titleField.y = 5;
		addChild(titleField);

		// 3. Title bar drag area
		titleDragArea = new Sprite();
		titleDragArea.buttonMode = true;
		titleDragArea.useHandCursor = true;
		addChild(titleDragArea);

		titleDragArea.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent)
		{
			isDragging = true;
			core.system.CursorManager.change('grabbing');
			var parentSpr:Sprite = (parent != null) ? cast parent : this;
			dragOffsetX = parentSpr.mouseX - this.x;
			dragOffsetY = parentSpr.mouseY - this.y;

			if (stage != null)
			{
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
				stage.addEventListener(MouseEvent.MOUSE_UP, onDragUp);
			}
		});

		// 4. Header buttons
		createHeaderButtons();

		// 5. Log area TextField
		logTextField = new TextField();
		logTextField.x = 10;
		logTextField.y = titleBarHeight + 6;
		logTextField.width = windowWidth - 26;
		logTextField.height = windowHeight - titleBarHeight - inputBarHeight - 12;
		logTextField.multiline = true;
		logTextField.wordWrap = true;
		logTextField.selectable = true;
		logTextField.mouseWheelEnabled = false;
		logTextField.defaultTextFormat = new TextFormat("_typewriter", 12, 0xFFFFFF);
		addChild(logTextField);

		// 6. Scrollbar graphic
		scrollBar = new Shape();
		addChild(scrollBar);

		// 7. Input bar prompt label
		promptLabel = new TextField();
		promptLabel.autoSize = TextFieldAutoSize.LEFT;
		promptLabel.selectable = false;
		promptLabel.mouseEnabled = false;
		promptLabel.defaultTextFormat = new TextFormat("_typewriter", 13, 0x69F0AE, true);
		promptLabel.text = ">";
		promptLabel.x = 10;
		promptLabel.y = windowHeight - inputBarHeight + 6;
		addChild(promptLabel);

		// 8. Input TextField
		inputField = new TextField();
		inputField.type = TextFieldType.INPUT;
		inputField.x = 26;
		inputField.y = windowHeight - inputBarHeight + 6;
		inputField.width = windowWidth - 36;
		inputField.height = 20;
		inputField.multiline = false;
		inputField.wordWrap = false;
		inputField.selectable = true;
		inputField.defaultTextFormat = new TextFormat("_typewriter", 13, 0xFFFFFF);
		inputField.textColor = 0xFFFFFF;
		addChild(inputField);

		inputField.addEventListener(KeyboardEvent.KEY_DOWN, onInputKeyDown);

		// Draw window frame
		drawWindow();

		// Initialize HScript REPL environment
		initHScript();

		// Stage listeners
		addEventListener(Event.ADDED_TO_STAGE, function(_)
		{
			if (stage != null)
			{
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onStageKeyDown);
				stage.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
			}
		});

		// Initial welcome logs
		log("Codename Engine Developer Console Prompt initialized.", INFO);
		log("Press [F2] or [ESC] to close. Type 'help' for a list of commands.", INFO);
	}

	function createHeaderButtons():Void
	{
		var btnX = windowWidth - 10;

		closeBtn = createButton("[X]", 0xEF5350, 0xFF8A80, function()
		{
			toggle();
		});
		closeBtn.x = btnX - closeBtn.width;
		closeBtn.y = 6;
		btnX = closeBtn.x - 10;
		addChild(closeBtn);

		clearBtn = createButton("[CLEAR]", 0x9090A6, 0xFFFFFF, function()
		{
			clearLogs();
		});
		clearBtn.x = btnX - clearBtn.width;
		clearBtn.y = 6;
		btnX = clearBtn.x - 10;
		addChild(clearBtn);

		#if (cpp && windows)
		cmdBtn = createButton("[CMD]", 0x9090A6, 0x4FC3F7, function()
		{
			allocConsole();
			log("Windows CMD Console Window opened via AllocConsole()!", INFO);
		});
		cmdBtn.x = btnX - cmdBtn.width;
		cmdBtn.y = 6;
		addChild(cmdBtn);
		#end

		// Update title drag area width to stop before the buttons
		titleDragArea.graphics.clear();
		titleDragArea.graphics.beginFill(0x000000, 0.0);
		titleDragArea.graphics.drawRect(0, 0, btnX - 10, titleBarHeight);
		titleDragArea.graphics.endFill();
	}

	function createButton(text:String, defaultColor:Int, hoverColor:Int, onClick:Void->Void):Sprite
	{
		var btn = new Sprite();
		var tf = new TextField();
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.defaultTextFormat = new TextFormat("_sans", 11, defaultColor, true);
		tf.text = text;
		btn.addChild(tf);

		btn.buttonMode = true;
		btn.useHandCursor = true;

		btn.addEventListener(MouseEvent.MOUSE_OVER, function(_)
		{
			tf.textColor = hoverColor;
			core.system.CursorManager.change('pointer');
		});
		btn.addEventListener(MouseEvent.MOUSE_OUT, function(_)
		{
			tf.textColor = defaultColor;
			core.system.CursorManager.change('default');
		});
		btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent)
		{
			e.stopImmediatePropagation();
			onClick();
		});

		return btn;
	}

	function drawWindow():Void
	{
		bgShape.graphics.clear();

		// Drop shadow
		bgShape.graphics.beginFill(0x000000, 0.5);
		bgShape.graphics.drawRoundRect(-3, -3, windowWidth + 6, windowHeight + 6, 8, 8);
		bgShape.graphics.endFill();

		// Outer border
		bgShape.graphics.beginFill(0x2D2D3D, 1.0);
		bgShape.graphics.drawRoundRect(0, 0, windowWidth, windowHeight, 6, 6);
		bgShape.graphics.endFill();

		// Main body background
		bgShape.graphics.beginFill(0x131318, 0.94);
		bgShape.graphics.drawRoundRect(1, 1, windowWidth - 2, windowHeight - 2, 6, 6);
		bgShape.graphics.endFill();

		// Title bar background
		bgShape.graphics.beginFill(0x1F1F2B, 1.0);
		bgShape.graphics.drawRoundRect(1, 1, windowWidth - 2, titleBarHeight, 6, 6);
		bgShape.graphics.drawRect(1, titleBarHeight - 4, windowWidth - 2, 4);
		bgShape.graphics.endFill();

		// Title bar separator
		bgShape.graphics.beginFill(0x2D2D3D, 1.0);
		bgShape.graphics.drawRect(1, titleBarHeight, windowWidth - 2, 1);
		bgShape.graphics.endFill();

		// Input bar background
		var inputY = windowHeight - inputBarHeight;
		bgShape.graphics.beginFill(0x191924, 1.0);
		bgShape.graphics.drawRect(1, inputY, windowWidth - 2, inputBarHeight - 1);
		bgShape.graphics.endFill();

		// Input bar separator line
		bgShape.graphics.beginFill(0x2D2D3D, 1.0);
		bgShape.graphics.drawRect(1, inputY, windowWidth - 2, 1);
		bgShape.graphics.endFill();

		// Input box inset
		bgShape.graphics.beginFill(0x0E0E14, 1.0);
		bgShape.graphics.drawRoundRect(22, inputY + 4, windowWidth - 32, inputBarHeight - 8, 4, 4);
		bgShape.graphics.endFill();
	}

	function onDragMove(e:MouseEvent):Void
	{
		if (!isDragging) return;
		var parentSpr:Sprite = (parent != null) ? cast parent : this;
		this.x = parentSpr.mouseX - dragOffsetX;
		this.y = parentSpr.mouseY - dragOffsetY;

		if (stage != null)
		{
			this.x = Math.max(0, Math.min(this.x, stage.stageWidth - windowWidth));
			this.y = Math.max(0, Math.min(this.y, stage.stageHeight - 40));
		}
	}

	function onDragUp(e:MouseEvent):Void
	{
		isDragging = false;
		core.system.CursorManager.change('default');
		if (stage != null)
		{
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onDragUp);
		}
	}

	function onMouseWheel(e:MouseEvent):Void
	{
		if (!visible || !isOpen) return;

		var mx = stage != null ? stage.mouseX : 0;
		var my = stage != null ? stage.mouseY : 0;

		if (hitTestPoint(mx, my))
		{
			logTextField.scrollV -= (e.delta > 0 ? 3 : -3);
			updateScrollbar();
		}
	}

	function updateScrollbar():Void
	{
		scrollBar.graphics.clear();
		if (logTextField.maxScrollV <= 1) return;

		var trackX = windowWidth - 10;
		var trackY = titleBarHeight + 6;
		var trackH = windowHeight - titleBarHeight - inputBarHeight - 12;

		scrollBar.graphics.beginFill(0x181822, 0.6);
		scrollBar.graphics.drawRoundRect(trackX, trackY, 5, trackH, 3, 3);
		scrollBar.graphics.endFill();

		var visibleRatio = 1.0 / (logTextField.maxScrollV + 1);
		var thumbH = Math.max(16, trackH * Math.min(1.0, visibleRatio * 10));
		var scrollRatio = (logTextField.scrollV - 1.0) / (logTextField.maxScrollV - 1.0);
		var thumbY = trackY + (trackH - thumbH) * scrollRatio;

		scrollBar.graphics.beginFill(0x4E4E66, 0.9);
		scrollBar.graphics.drawRoundRect(trackX, thumbY, 5, thumbH, 3, 3);
		scrollBar.graphics.endFill();
	}

	function onStageKeyDown(e:KeyboardEvent):Void
	{
		// F2 (113): Toggle Console
		if (e.keyCode == 113)
		{
			e.stopImmediatePropagation();
			toggle();
		}
		// ESC (27): Close if open
		else if (e.keyCode == 27 && isOpen)
		{
			e.stopImmediatePropagation();
			setOpen(false);
		}
	}

	function onInputKeyDown(e:KeyboardEvent):Void
	{
		if (e.keyCode == 13) // Enter
		{
			e.stopImmediatePropagation();
			var cmd = StringTools.trim(inputField.text);
			if (cmd.length > 0)
			{
				executeCommand(cmd);
			}
			inputField.text = "";
		}
		else if (e.keyCode == 38) // Up Arrow (History back)
		{
			e.stopImmediatePropagation();
			navigateHistory(-1);
		}
		else if (e.keyCode == 40) // Down Arrow (History forward)
		{
			e.stopImmediatePropagation();
			navigateHistory(1);
		}
		else if (e.keyCode == 9) // Tab (Autocomplete)
		{
			e.stopImmediatePropagation();
			e.preventDefault();
			autoComplete();
		}
		else if (e.keyCode == 27 || e.keyCode == 113) // Escape or F2
		{
			e.stopImmediatePropagation();
			toggle();
		}
	}

	function navigateHistory(direction:Int):Void
	{
		if (history.length == 0) return;

		if (historyIndex == -1)
		{
			tempInput = inputField.text;
			historyIndex = history.length;
		}

		historyIndex += direction;

		if (historyIndex < 0)
			historyIndex = 0;
		else if (historyIndex > history.length)
			historyIndex = history.length;

		if (historyIndex == history.length)
		{
			inputField.text = tempInput;
			inputField.setSelection(tempInput.length, tempInput.length);
		}
		else
		{
			var item = history[historyIndex];
			inputField.text = item;
			inputField.setSelection(item.length, item.length);
		}
	}

	function autoComplete():Void
	{
		var text = StringTools.trim(inputField.text);
		if (text.length == 0) return;

		var parts = text.split(" ");
		if (parts.length == 1)
		{
			var prefix = parts[0].toLowerCase();
			for (cmd in knownCommands)
			{
				if (StringTools.startsWith(cmd, prefix) && cmd != prefix)
				{
					inputField.text = cmd + " ";
					inputField.setSelection(inputField.text.length, inputField.text.length);
					return;
				}
			}
		}
	}

	public static function toggle():Void
	{
		var now:Float = Timer.stamp();
		if (now - _lastToggle < 0.15) return;
		_lastToggle = now;

		if (instance != null)
			instance.setOpen(!instance.isOpen);
	}

	public function setOpen(open:Bool):Void
	{
		isOpen = open;
		visible = open;

		if (isOpen)
		{
			if (parent != null)
				parent.setChildIndex(this, parent.numChildren - 1);

			wasMouseVisible = FlxG.mouse.visible;
			FlxG.mouse.visible = true;
			FlxG.keys.enabled = false;

			refreshLogs();

			if (stage != null)
				stage.focus = inputField;
		}
		else
		{
			FlxG.keys.enabled = true;
			FlxG.mouse.visible = wasMouseVisible;

			if (stage != null && stage.focus == inputField)
				stage.focus = null;
		}
	}

	function refreshLogs():Void
	{
		logTextField.htmlText = logLines.join("<br/>");
		logTextField.scrollV = logTextField.maxScrollV;
		updateScrollbar();
	}

	public static function clearLogs():Void
	{
		logLines = [];
		if (instance != null)
		{
			instance.logTextField.htmlText = "";
			instance.updateScrollbar();
		}
	}

	public static function log(text:String, type:LogType = TRACE, ?pos:String):Void
	{
		var date = Date.now();
		var timeStr = StringTools.lpad(Std.string(date.getHours()), "0", 2) + ":"
			+ StringTools.lpad(Std.string(date.getMinutes()), "0", 2) + ":"
			+ StringTools.lpad(Std.string(date.getSeconds()), "0", 2);

		var prefix = '<font color="#6E6E82">[' + timeStr + ']</font> ';
		if (pos != null && pos.length > 0)
			prefix += '<font color="#828296">[' + pos + ']</font> ';

		var escaped = StringTools.replace(text, "&", "&amp;");
		escaped = StringTools.replace(escaped, "<", "&lt;");
		escaped = StringTools.replace(escaped, ">", "&gt;");
		escaped = StringTools.replace(escaped, "\n", "<br/>");

		var lineHtml = switch (type)
		{
			case INFO: prefix + '<font color="#4FC3F7"><b>[INFO]</b> ' + escaped + '</font>';
			case WARN: prefix + '<font color="#FFD54F"><b>[WARN]</b> ' + escaped + '</font>';
			case ERROR: prefix + '<font color="#EF5350"><b>[ERROR]</b> ' + escaped + '</font>';
			case COMMAND: prefix + '<font color="#69F0AE"><b>&gt; </b>' + escaped + '</font>';
			case RESULT: prefix + '<font color="#CE93D8"><b>&lt;= </b>' + escaped + '</font>';
			case TRACE: prefix + '<font color="#D8D8E0">' + escaped + '</font>';
		};

		logLines.push(lineHtml);
		if (logLines.length > MAX_LOG_LINES)
			logLines.shift();

		if (instance != null && instance.isOpen)
		{
			var wasAtBottom = (instance.logTextField.scrollV >= instance.logTextField.maxScrollV - 1);
			instance.logTextField.htmlText = logLines.join("<br/>");
			if (wasAtBottom || type == COMMAND)
			{
				instance.logTextField.scrollV = instance.logTextField.maxScrollV;
			}
			instance.updateScrollbar();
		}
	}

	public static function hookTrace():Void
	{
		if (oldTrace == null)
		{
			oldTrace = haxe.Log.trace;
			haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos)
			{
				if (oldTrace != null)
					oldTrace(v, infos);

				var msg:String = Std.string(v);
				if (infos != null && infos.customParams != null)
				{
					for (p in infos.customParams)
						msg += ", " + Std.string(p);
				}

				var posStr:String = (infos != null) ? infos.fileName + ":" + infos.lineNumber : "";
				log(msg, TRACE, posStr);
			};
		}
	}

	function initHScript():Void
	{
		parser = new Parser();
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;

		interp = new CustomInterp();
		setupInterpGlobals();
	}

	function setupInterpGlobals():Void
	{
		interp.variables.set("FlxG", flixel.FlxG);
		interp.variables.set("PlayState", gameplay.PlayState);
		interp.variables.set("Conductor", gameplay.Conductor);
		interp.variables.set("conductor", gameplay.Conductor);
		interp.variables.set("Paths", Paths);
		interp.variables.set("CoolUtil", core.utils.CoolUtil);
		interp.variables.set("FunkinMemory", core.system.FunkinMemory);
		interp.variables.set("Main", Main);
		interp.variables.set("Math", Math);
		interp.variables.set("Std", Std);
		interp.variables.set("StringTools", StringTools);
		interp.variables.set("trace", function(v:Dynamic) { log(Std.string(v), TRACE); });
		interp.variables.set("print", function(v:Dynamic) { log(Std.string(v), INFO); });
		interp.variables.set("echo", function(v:Dynamic) { log(Std.string(v), INFO); });
		interp.variables.set("clear", clearLogs);
		interp.variables.set("cls", clearLogs);
	}

	function executeCommand(rawText:String):Void
	{
		log(rawText, COMMAND);

		if (history.length == 0 || history[history.length - 1] != rawText)
		{
			history.push(rawText);
			if (history.length > 100) history.shift();
		}
		historyIndex = -1;
		tempInput = "";

		var parts = splitArgs(rawText);
		if (parts.length == 0) return;

		var cmd = parts[0].toLowerCase();
		var args = parts.slice(1);

		switch (cmd)
		{
			case "help" | "?":
				log("=== CODENAME ENGINE PROMPT COMMANDS ===", INFO);
				log("• help, ?                  : Show this command list", INFO);
				log("• clear, cls               : Clear console output", INFO);
				log("• state <name>             : Switch state (e.g. state TitleState, state PlayState)", INFO);
				log("• reload, restart          : Restart current state", INFO);
				log("• play <song> [diff]       : Play a song (e.g. play dadbattle hard)", INFO);
				log("• chart                    : Open Chart Editor", INFO);
				log("• char [name]              : Open Character Editor", INFO);
				log("• cam                      : Open Camera Editor", INFO);
				log("• botplay [on|off]         : Toggle or set botplay in gameplay", INFO);
				log("• health, hp [0-2]         : Get or set player health", INFO);
				log("• score [val]              : Get or set player score", INFO);
				log("• misses [val]             : Get or set player misses", INFO);
				log("• kill, die                : Kill player (game over)", INFO);
				log("• speed [val]              : Set game speed / timeScale (e.g. speed 1.5)", INFO);
				log("• fps [val]                : Set framerate cap (e.g. fps 144)", INFO);
				log("• vol, volume [0-100]      : Set game volume percentage", INFO);
				log("• mute, unmute             : Toggle audio mute", INFO);
				log("• gc, clean, mem           : Run GC & compact memory", INFO);
				log("• cmd, allocconsole        : Open Windows CMD terminal window", INFO);
				log("• exit, close              : Close console prompt", INFO);
				log("• <hscript expression>     : Evaluate any HScript code directly! (e.g. FlxG.sound.music.volume = 0.5)", INFO);

			case "clear" | "cls":
				clearLogs();

			case "state" | "switch":
				if (args.length == 0)
				{
					log("Usage: state <StateName> (e.g. state MainMenuState, state PlayState, state FreeplayState, state TitleState)", WARN);
					return;
				}
				handleStateSwitch(args[0]);

			case "reload" | "restart":
				log("Restarting current state...", INFO);
				FlxG.resetState();

			case "play":
				if (args.length == 0)
				{
					log("Usage: play <songName> [difficulty] (e.g. play dadbattle hard, play fresh normal)", WARN);
					return;
				}
				var song = args[0].toLowerCase();
				var diffIdx = 1; // Default to Normal
				if (args.length > 1)
				{
					var diffArg = args[1].toUpperCase();
					var idx = CoolUtil.difficultyArray.indexOf(diffArg);
					if (idx != -1) diffIdx = idx;
				}
				log('Loading song "${song}" on difficulty ${diffIdx}...', INFO);
				try
				{
					gameplay.PlayState.playSong(song, null, diffIdx);
				}
				catch (e:Dynamic)
				{
					log('Error playing song: ' + e, ERROR);
				}

			case "chart":
				log("Opening Chart Editor...", INFO);
				Main.switchState(FlxG.state, new editors.ChartEditor());

			case "char" | "character":
				log("Opening Character Editor...", INFO);
				Main.switchState(FlxG.state, new editors.CharacterEditor());

			case "cam" | "camera":
				log("Opening Camera Editor...", INFO);
				Main.switchState(FlxG.state, new editors.CameraEditor());

			case "botplay":
				if (gameplay.PlayState.boyfriendStrums != null)
				{
					var enable = (args.length > 0) ? (args[0] == "1" || args[0] == "true" || args[0] == "on") : !gameplay.PlayState.boyfriendStrums.autoplay;
					gameplay.PlayState.boyfriendStrums.autoplay = enable;
					log('Botplay ' + (enable ? 'ENABLED' : 'DISABLED'), INFO);
				}
				else
				{
					log("Botplay is only available inside PlayState!", WARN);
				}

			case "health" | "hp":
				if (args.length == 0)
				{
					log('Current health: ' + gameplay.PlayState.health, INFO);
				}
				else
				{
					var val = Std.parseFloat(args[0]);
					if (Math.isNaN(val))
						log("Invalid health value! Use a number (0.0 to 2.0)", ERROR);
					else
					{
						gameplay.PlayState.health = Math.max(0, Math.min(val, 2.0));
						log('Health set to: ' + gameplay.PlayState.health, INFO);
					}
				}

			case "score":
				if (args.length == 0)
				{
					log('Current score: ' + gameplay.PlayState.songScore, INFO);
				}
				else
				{
					var sc = Std.parseInt(args[0]);
					if (sc == null) log("Invalid score integer!", ERROR);
					else
					{
						gameplay.PlayState.songScore = sc;
						log('Score set to: ' + sc, INFO);
					}
				}

			case "misses":
				if (args.length == 0)
				{
					log('Current misses: ' + gameplay.PlayState.misses, INFO);
				}
				else
				{
					var ms = Std.parseInt(args[0]);
					if (ms == null) log("Invalid misses integer!", ERROR);
					else
					{
						gameplay.PlayState.misses = ms;
						log('Misses set to: ' + ms, INFO);
					}
				}

			case "kill" | "die":
				if (gameplay.PlayState.instance != null)
				{
					gameplay.PlayState.health = 0;
					log("Player killed!", WARN);
				}
				else
				{
					log("Kill command is only available inside PlayState!", WARN);
				}

			case "speed":
				if (args.length == 0)
				{
					log('Current timeScale: ' + FlxG.timeScale, INFO);
				}
				else
				{
					var spd = Std.parseFloat(args[0]);
					if (Math.isNaN(spd) || spd <= 0)
						log("Speed must be a positive number!", ERROR);
					else
					{
						FlxG.timeScale = spd;
						log('Game speed set to: ' + spd, INFO);
					}
				}

			case "fps":
				if (args.length == 0)
				{
					log('Current draw FPS: ' + FlxG.drawFramerate, INFO);
				}
				else
				{
					var targetFps = Std.parseInt(args[0]);
					if (targetFps != null && targetFps >= 10 && targetFps <= 1000)
					{
						Main.updateFramerate(targetFps);
						log('Target framerate set to: ' + targetFps, INFO);
					}
					else
					{
						log("Invalid FPS! Must be between 10 and 1000", ERROR);
					}
				}

			case "vol" | "volume":
				if (args.length == 0)
				{
					log('Current volume: ' + Math.round(FlxG.sound.volume * 100) + '%', INFO);
				}
				else
				{
					var v = Std.parseFloat(args[0]);
					if (Math.isNaN(v)) log("Invalid volume percentage!", ERROR);
					else
					{
						FlxG.sound.volume = Math.max(0, Math.min(v / 100.0, 1.0));
						log('Volume set to: ' + Math.round(FlxG.sound.volume * 100) + '%', INFO);
					}
				}

			case "mute" | "unmute":
				FlxG.sound.muted = !FlxG.sound.muted;
				log('Audio ' + (FlxG.sound.muted ? 'MUTED' : 'UNMUTED'), INFO);

			case "gc" | "clean" | "mem":
				var before = FunkinMemory.currentMemUsage();
				FunkinMemory.clearMajor();
				var after = FunkinMemory.currentMemUsage();
				var freed = before - after;
				log('GC Complete! Current: ' + CoolUtil.getSizeString(after) + ' (Freed: ' + (freed > 0 ? CoolUtil.getSizeString(freed) : '0 B') + ')', INFO);

			case "cmd" | "allocconsole":
				#if (cpp && windows)
				allocConsole();
				log("Windows CMD Console Window opened via AllocConsole()!", INFO);
				#else
				log("AllocConsole is only available on Windows C++ desktop builds!", WARN);
				#end

			case "exit" | "close":
				toggle();

			default:
				var scriptCode = rawText;
				if (StringTools.startsWith(scriptCode, "eval "))
					scriptCode = scriptCode.substr(5);

				evalHScript(scriptCode);
		}
	}

	function handleStateSwitch(name:String):Void
	{
		var targetState:FlxState = null;
		var cleanName = name.toLowerCase();

		switch (cleanName)
		{
			case "playstate" | "play":
				targetState = new gameplay.PlayState();
			case "titlestate" | "title":
				targetState = new menus.TitleState();
			case "mainmenustate" | "mainmenu" | "menu":
				targetState = new menus.MainMenuState();
			case "freeplaystate" | "freeplay":
				targetState = new menus.FreeplayState();
			case "optionsmenustate" | "options":
				targetState = new menus.OptionsMenuState();
			case "creditsstate" | "credits":
				targetState = new menus.CreditsState();
			case "modsmenustate" | "mods":
				targetState = new menus.ModsMenuState();
			case "charteditor" | "chart":
				targetState = new editors.ChartEditor();
			case "charactereditor" | "chareditor" | "char":
				targetState = new editors.CharacterEditor();
			case "cameraeditor" | "cam":
				targetState = new editors.CameraEditor();
			default:
				var resolved = Type.resolveClass(name);
				if (resolved == null) resolved = Type.resolveClass("funkin.states." + name);
				if (resolved == null) resolved = Type.resolveClass("editors." + name);
				if (resolved != null)
				{
					try {
						targetState = Type.createInstance(resolved, []);
					} catch (e:Dynamic) {
						log('Failed to instantiate state "${name}": ' + e, ERROR);
					}
				}
		}

		if (targetState != null)
		{
			log('Switching state to: ' + Type.getClassName(Type.getClass(targetState)), INFO);
			Main.switchState(FlxG.state, targetState);
		}
		else
		{
			log('Unknown state: "${name}"', ERROR);
		}
	}

	function evalHScript(code:String):Void
	{
		try
		{
			interp.variables.set("game", FlxG.state);
			interp.variables.set("state", FlxG.state);
			interp.variables.set("instance", gameplay.PlayState.instance);
			interp.variables.set("playstate", gameplay.PlayState.instance);

			var expr = parser.parseString(code);
			var res:Dynamic = interp.execute(expr);
			if (res != null)
			{
				log(Std.string(res), RESULT);
			}
			else
			{
				log("OK (void)", INFO);
			}
		}
		catch (e:Dynamic)
		{
			log('HScript Error: ' + e, ERROR);
		}
	}

	public static function splitArgs(str:String):Array<String>
	{
		var args:Array<String> = [];
		var current:String = "";
		var inQuotes:Bool = false;
		var quoteChar:String = "";

		for (i in 0...str.length)
		{
			var char = str.charAt(i);
			if (inQuotes)
			{
				if (char == quoteChar)
					inQuotes = false;
				else
					current += char;
			}
			else
			{
				if (char == '"' || char == "'")
				{
					inQuotes = true;
					quoteChar = char;
				}
				else if (char == ' ' || char == '\t')
				{
					if (current.length > 0)
					{
						args.push(current);
						current = "";
					}
				}
				else
				{
					current += char;
				}
			}
		}
		if (current.length > 0)
			args.push(current);

		return args;
	}

	public static function allocConsole():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
			if (AllocConsole())
			{
				FILE* fDummy;
				freopen_s(&fDummy, "CONIN$", "r", stdin);
				freopen_s(&fDummy, "CONOUT$", "w", stdout);
				freopen_s(&fDummy, "CONOUT$", "w", stderr);
				SetConsoleTitleA("Codename / GAZE Console Prompt");
			}
		');
		#end
	}
}

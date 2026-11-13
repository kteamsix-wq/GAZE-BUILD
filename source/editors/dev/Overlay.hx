package editors.dev;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.system.System;
import haxe.Timer;
import flixel.FlxG;
import core.system.FunkinMemory;
import gameplay.Conductor;
import core.utils.CoolUtil;
import core.system.Paths;
import Main;

#if (cpp && windows)
@:cppFileCode('
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#pragma comment(lib, "psapi.lib")
')
#end

/**
 * Codename Engine-styled Framerate, MemoryCounter, BuildField & Debug Categories Overlay.
 *
 * Features:
 * - F2 shortcut: Opens Codename-styled Developer Console Prompt (interactive command line & HScript REPL)
 * - FramerateCounter: Large `fpsNum` (18pt) + smaller `FPS` label (12pt)
 * - MemoryCounter: `memoryText` (12pt) + `memoryPeakText` (12pt @ 0.5 alpha) using `FunkinMemory.currentMemUsage()`
 * - BuildField: Engine version & state indicator
 * - FramerateCategory panels (toggled via F3 or clicking):
 *   1. Conductor Info (BPM, Step, Beat, Measure, Song Position)
 *   2. Flixel Info (Current State, Active Objects, Cameras, Draw Calls, Sounds)
 *   3. FunkinCache & Memory Info (GC Used/Reserved, Process Working Set, GPU Textures, Layer 1/2 Cache Counts)
 * - F4 shortcut: Runs `FunkinMemory.clearMajor()` (Full GC + Heap Compact + Working Set Trim)
 */
class Overlay extends Sprite
{
	public static var instance:Overlay;

	// Display flags (controlled by game settings)
	public static var displayFps:Bool = true;
	public static var displayMemory:Bool = true;
	public static var displayExtra:Bool = false;

	// Interactive / Layout toggles
	public static var detailedMode:Bool = false;
	public static var showBackground:Bool = true;

	// Main Counter Background & Container (Codename Engine style)
	var bgSprite:Shape;
	var fpsNum:TextField;
	var fpsLabel:TextField;
	var memoryText:TextField;
	var memoryPeakText:TextField;
	var buildField:TextField;

	// Legacy compatibility TextField
	var textField:TextField;

	// Codename-style FramerateCategory panels (shown in detailedMode / F3)
	var categories:Array<FramerateCategoryPanel> = [];
	var catConductor:FramerateCategoryPanel;
	var catFlixel:FramerateCategoryPanel;
	var catCache:FramerateCategoryPanel;

	var fontName:String = "_sans";

	// Framerate & frame-time tracking (Fixed ring-buffer to prevent per-frame allocations)
	static inline final FPS_BUFFER_SIZE:Int = 1024;
	var fpsTimestamps:Array<Float> = [for (i in 0...FPS_BUFFER_SIZE) 0.0];
	var fpsHead:Int = 0;
	var fpsTail:Int = 0;
	var fpsCount:Int = 0;
	var currentFps:Int = 0;

	// Memory tracker (in bytes, like Codename Engine's MemoryCounter)
	public var memory:Float = 0;
	public var memoryPeak:Float = 0;

	// Periodic cache timers
	var lastPeriodicUpdate:Float = 0;
	var lastDisplayUpdate:Float = 0;

	// Cached statistics for debug categories
	var cachedProcessMem:Float = 0;
	var cachedPrivateMem:Float = 0;
	var cachedGcMem:Float = 0;
	var cachedReservedMem:Float = 0;
	var cachedTexBytes:Float = 0;
	var cachedTexCount:Int = 0;
	var cachedDrawCalls:Int = 0;
	var cachedObjectsCount:Int = 0;
	var cachedStateName:String = "";
	var lastBgW:Float = -1;
	var lastBgH:Float = -1;

	public function new(x:Float = 10, y:Float = 10)
	{
		super();

		instance = this;

		this.x = (x <= 0) ? 10 : x;
		this.y = (y <= 0) ? 10 : y;

		try
		{
			fontName = Paths.font("vcr.ttf");
		}
		catch (e:Dynamic)
		{
			fontName = "_sans";
		}

		// Main background box (Codename Engine style: black with 0.5 alpha)
		bgSprite = new Shape();
		addChild(bgSprite);

		// 1. FramerateCounter: Big FPS number + smaller "FPS" label
		fpsNum = createLabel(18, 0xFFFFFF, true);
		fpsNum.text = "0";
		addChild(fpsNum);

		fpsLabel = createLabel(12, 0xFFFFFF, false);
		fpsLabel.text = " FPS";
		addChild(fpsLabel);

		// 2. MemoryCounter: memoryText + memoryPeakText (alpha = 0.5)
		memoryText = createLabel(12, 0xFFFFFF, false);
		memoryText.text = "0 B";
		addChild(memoryText);

		memoryPeakText = createLabel(12, 0xFFFFFF, false);
		memoryPeakText.alpha = 0.5;
		memoryPeakText.text = " / 0 B";
		addChild(memoryPeakText);

		// 3. CodenameBuildField: Engine build version / extra info
		buildField = createLabel(12, 0xFFFFFF, false);
		buildField.alpha = 0.75;
		buildField.text = 'K-SLICE v${Main.gameVersion}';
		addChild(buildField);

		// Hidden compatibility TextField in case external scripts access `overlay.textField`
		textField = createLabel(12, 0xFFFFFF, false);
		textField.visible = false;

		// 4. Debug Categories (Codename Engine FramerateCategory panels)
		catConductor = new FramerateCategoryPanel("Conductor Info", fontName);
		catFlixel = new FramerateCategoryPanel("Flixel Info", fontName);
		catCache = new FramerateCategoryPanel("Memory & FunkinCache", fontName);

		categories = [catConductor, catFlixel, catCache];
		for (cat in categories)
		{
			cat.visible = false;
			addChild(cat);
		}

		// Interactivity: Click to toggle detailed categories mode
		buttonMode = true;
		useHandCursor = true;
		addEventListener(MouseEvent.MOUSE_OVER, function(_)
		{
			core.system.CursorManager.change('pointer');
		});
		addEventListener(MouseEvent.MOUSE_OUT, function(_)
		{
			core.system.CursorManager.change('default');
		});
		addEventListener(MouseEvent.CLICK, function(_)
		{
			detailedMode = !detailedMode;
			forceUpdate();
		});

		// Keyboard shortcuts:
		// F3 (114): Toggle Codename-style debug categories
		// F4 (115): Force Major GC + Memory Compact
		addEventListener(Event.ADDED_TO_STAGE, function(_)
		{
			if (stage != null)
			{
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			}
			if (FlxG.signals != null && FlxG.signals.postStateSwitch != null)
			{
				FlxG.signals.postStateSwitch.add(function()
				{
					memory = FunkinMemory.currentMemUsage();
					memoryPeak = memory;
					forceUpdate();
				});
			}
		});

		addEventListener(Event.ENTER_FRAME, onEnterFrame);

		forceUpdate();
	}

	function createLabel(size:Int, color:Int, bold:Bool = false):TextField
	{
		var tf = new TextField();
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.multiline = false;
		tf.wordWrap = false;
		tf.defaultTextFormat = new TextFormat(fontName, size, color, bold);
		return tf;
	}

	function onKeyDown(e:KeyboardEvent):Void
	{
		// F2: Toggle Codename-style Developer Console Prompt
		if (e.keyCode == 113)
		{
			editors.dev.DevConsole.toggle();
		}
		// F3: Toggle Debug Categories
		else if (e.keyCode == 114)
		{
			detailedMode = !detailedMode;
			forceUpdate();
		}
		// F4: Force Codename-style Major GC + Heap Compaction
		else if (e.keyCode == 115)
		{
			FunkinMemory.clearMajor();
			memory = FunkinMemory.currentMemUsage();
			memoryPeak = memory;
			forceUpdate();
		}
	}

	function onEnterFrame(_:Event):Void
	{
		var now:Float = Timer.stamp();

		// Update frame delta using fixed ring-buffer (O(1), zero allocations)
		fpsTimestamps[fpsHead] = now;
		fpsHead = (fpsHead + 1) % FPS_BUFFER_SIZE;
		fpsCount++;

		var cutoff:Float = now - 1.0;
		while (fpsCount > 0 && fpsTimestamps[fpsTail] < cutoff)
		{
			fpsTail = (fpsTail + 1) % FPS_BUFFER_SIZE;
			fpsCount--;
		}

		var targetFps:Int = Main.framerate;
		try
		{
			if (FlxG.drawFramerate > 0) targetFps = FlxG.drawFramerate;
		}
		catch (e:Dynamic) {}

		currentFps = fpsCount > targetFps ? targetFps : fpsCount;

		// Periodic memory & diagnostics update (every 200ms)
		if (now - lastPeriodicUpdate >= 0.20)
		{
			lastPeriodicUpdate = now;

			memory = FunkinMemory.currentMemUsage();
			if (memory > memoryPeak)
				memoryPeak = memory;

			if (detailedMode || displayExtra)
			{
				cachedGcMem = memory / (1024.0 * 1024.0);
				cachedReservedMem = FunkinMemory.reservedMemUsage() / (1024.0 * 1024.0);
				cachedProcessMem = getProcessMemory();
				cachedPrivateMem = getPrivateMemory();

				var tex = getTextureStats();
				cachedTexBytes = tex.bytes;
				cachedTexCount = tex.count;

				cachedDrawCalls = getDrawCalls();
				cachedObjectsCount = getActiveObjectsCount();
				cachedStateName = getCurrentStateName();
			}
		}

		// Update display every ~50ms (20fps UI refresh)
		if (now - lastDisplayUpdate >= 0.05)
		{
			lastDisplayUpdate = now;
			renderHUD(currentFps, targetFps);
		}
	}

	public function forceUpdate():Void
	{
		memory = FunkinMemory.currentMemUsage();
		if (memory > memoryPeak)
			memoryPeak = memory;

		cachedGcMem = memory / (1024.0 * 1024.0);
		cachedReservedMem = FunkinMemory.reservedMemUsage() / (1024.0 * 1024.0);
		cachedProcessMem = getProcessMemory();
		cachedPrivateMem = getPrivateMemory();

		var tex = getTextureStats();
		cachedTexBytes = tex.bytes;
		cachedTexCount = tex.count;

		cachedDrawCalls = getDrawCalls();
		cachedObjectsCount = getActiveObjectsCount();
		cachedStateName = getCurrentStateName();

		var targetFps:Int = Main.framerate;
		try
		{
			if (FlxG.drawFramerate > 0) targetFps = FlxG.drawFramerate;
		}
		catch (e:Dynamic) {}

		renderHUD(currentFps > 0 ? currentFps : targetFps, targetFps);
	}

	function renderHUD(fps:Int, targetFps:Int):Void
	{
		if (!visible) return;

		var padX:Float = 6;
		var curY:Float = 4;
		var maxWidth:Float = 0;

		// 1. FPS Line (Codename FramerateCounter layout)
		fpsNum.visible = displayFps;
		fpsLabel.visible = displayFps;

		if (displayFps)
		{
			var fpsStr = Std.string(fps);
			if (fpsNum.text != fpsStr) fpsNum.text = fpsStr;
			var fpsColor:Int = (fps < Std.int(targetFps * 0.5)) ? 0xFF5555 : 0xFFFFFF;
			if (fpsNum.textColor != fpsColor)
			{
				fpsNum.textColor = fpsColor;
				fpsLabel.textColor = fpsColor;
			}

			fpsNum.x = padX;
			fpsNum.y = curY;

			fpsLabel.x = fpsNum.x + fpsNum.width;
			fpsLabel.y = fpsNum.y + (fpsNum.height - fpsLabel.height) - 1;

			var lineW = (fpsLabel.x + fpsLabel.width) - padX;
			if (lineW > maxWidth) maxWidth = lineW;

			curY += fpsNum.height - 2;
		}

		// 2. Memory Line (Codename MemoryCounter layout: current + 0.5 alpha peak)
		memoryText.visible = displayMemory;
		memoryPeakText.visible = displayMemory;

		if (displayMemory)
		{
			var memStr = CoolUtil.getSizeString(memory);
			if (memoryText.text != memStr) memoryText.text = memStr;
			var peakStr = ' / ${CoolUtil.getSizeString(memoryPeak)}';
			if (memoryPeakText.text != peakStr) memoryPeakText.text = peakStr;

			memoryText.x = padX;
			memoryText.y = curY;

			memoryPeakText.x = memoryText.x + memoryText.width;
			memoryPeakText.y = curY;

			var lineW = (memoryPeakText.x + memoryPeakText.width) - padX;
			if (lineW > maxWidth) maxWidth = lineW;

			curY += memoryText.height - 1;
		}

		// 3. Build Field (CodenameBuildField layout)
		var showBuild:Bool = displayFps || displayMemory || displayExtra;
		buildField.visible = showBuild;

		if (showBuild)
		{
			var bText = (displayExtra && !detailedMode) ? 'GAZE v${Main.gameVersion} • ${cachedStateName} (${cachedDrawCalls} DC)' : 'GAZE ENGINE v${Main.gameVersion}';
			if (buildField.text != bText) buildField.text = bText;

			buildField.x = padX;
			buildField.y = curY;

			var lineW = buildField.width;
			if (lineW > maxWidth) maxWidth = lineW;

			curY += buildField.height + 2;
		}

		// Draw Codename-style semi-transparent black background behind the main counter
		var totalW = maxWidth + (padX * 2);
		var totalH = curY + 2;
		if (lastBgW != totalW || lastBgH != totalH)
		{
			lastBgW = totalW;
			lastBgH = totalH;
			bgSprite.graphics.clear();
			if (showBackground && (displayFps || displayMemory || displayExtra))
			{
				bgSprite.graphics.beginFill(0x000000, 0.5);
				bgSprite.graphics.drawRect(0, 0, totalW, totalH);
				bgSprite.graphics.endFill();
			}
		}

		// 4. Codename-style FramerateCategory panels below the main counter when detailedMode (F3) is active
		var catY:Float = curY + 8;

		for (cat in categories)
			cat.visible = detailedMode;

		if (detailedMode)
		{
			// Update Conductor Category
			var bpmStr:String = Std.string(Math.round(Conductor.bpm * 100) / 100);
			var stepStr:String = "0";
			var beatStr:String = "0";
			var measureStr:String = "0";
			try
			{
				if (FlxG.state != null && Std.isOfType(FlxG.state, core.base.MusicBeatState))
				{
					var mbs:core.base.MusicBeatState = cast FlxG.state;
					stepStr = Std.string(mbs.curStep);
					beatStr = Std.string(mbs.curBeat);
					measureStr = Std.string(Math.floor(mbs.curBeat / 4));
				}
			}
			catch (e:Dynamic) {}

			catConductor.updateContent(
				' - Current BPM: $bpmStr\n' +
				' - Current Step: $stepStr\n' +
				' - Current Beat: $beatStr\n' +
				' - Current Measure: $measureStr'
			);
			catConductor.x = 0;
			catConductor.y = catY;
			catY += catConductor.panelHeight + 6;

			// Update Flixel Category
			var camCount:Int = (FlxG.cameras != null && FlxG.cameras.list != null) ? FlxG.cameras.list.length : 0;
			var sndCount:Int = (FlxG.sound != null && FlxG.sound.list != null) ? FlxG.sound.list.length : 0;
			catFlixel.updateContent(
				' - Current State: $cachedStateName\n' +
				' - Active Objects: $cachedObjectsCount\n' +
				' - Cameras: $camCount | Sounds: $sndCount\n' +
				' - OpenGL Draw Calls: $cachedDrawCalls'
			);
			catFlixel.x = 0;
			catFlixel.y = catY;
			catY += catFlixel.panelHeight + 6;

			// Update FunkinCache & Memory Category
			var l1Graphs:Int = countMapKeys(Paths.currentTrackedAssets);
			var l2Graphs:Int = countMapKeys(Paths.previousTrackedAssets);
			var l1Atlases:Int = countMapKeys(Paths.currentTrackedAtlases);
			var l1Sounds:Int = countMapKeys(Paths.currentTrackedSounds);
			var permGraphs:Int = countMapKeys(FunkinMemory.permanentCachedTextures);

			var texMbStr:String = CoolUtil.getSizeString(cachedTexBytes);
			var procMbStr:String = CoolUtil.getSizeString(cachedProcessMem * 1024.0 * 1024.0);

			catCache.updateContent(
				' - GC Heap: ${CoolUtil.getSizeString(memory)} / ${CoolUtil.getSizeString(cachedReservedMem * 1024.0 * 1024.0)}\n' +
				' - Process RAM: $procMbStr | GPU: $texMbStr ($cachedTexCount tex)\n' +
				' - Cached Graphics: $l1Graphs (L2: $l2Graphs | Perm: $permGraphs)\n' +
				' - Cached Atlases: $l1Atlases | Sounds: $l1Sounds\n' +
				' - [F3] Hide Debug  [F4] Force GC'
			);
			catCache.x = 0;
			catCache.y = catY;
		}
	}

	static function countMapKeys<K, V>(map:Map<K, V>):Int
	{
		if (map == null) return 0;
		var count:Int = 0;
		for (_ in map.keys())
			count++;
		return count;
	}

	// -------------------------------------------------------------
	// SYSTEM & ENGINE DIAGNOSTIC METRICS
	// -------------------------------------------------------------

	/**
	 * Returns OS Process Working Set (Physical RAM used by the whole process) in MB.
	 */
	public static function getProcessMemory():Float
	{
		#if (cpp && windows)
		var memBytes:Float = 0;
		untyped __cpp__('
			PROCESS_MEMORY_COUNTERS pmc;
			if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
				memBytes = (double)pmc.WorkingSetSize;
			}
		');
		if (memBytes > 0)
			return memBytes / (1024.0 * 1024.0);
		#end
		return System.totalMemory / (1024.0 * 1024.0);
	}

	/**
	 * Returns OS Private Commit Charge (PagefileUsage) in MB on Windows.
	 */
	public static function getPrivateMemory():Float
	{
		#if (cpp && windows)
		var memBytes:Float = 0;
		untyped __cpp__('
			PROCESS_MEMORY_COUNTERS pmc;
			if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
				memBytes = (double)pmc.PagefileUsage;
			}
		');
		if (memBytes > 0)
			return memBytes / (1024.0 * 1024.0);
		#end
		return 0;
	}

	/**
	 * Returns Haxe / C++ Garbage Collector Heap Usage in MB.
	 */
	public static function getGCMemory():Float
	{
		return FunkinMemory.currentMemUsage() / (1024.0 * 1024.0);
	}

	/**
	 * Scans active Flixel bitmap cache to estimate uncompressed GPU/Bitmap texture footprint.
	 */
	public static function getTextureStats():{bytes:Float, count:Int}
	{
		var totalBytes:Float = 0;
		var count:Int = 0;
		try
		{
			if (FlxG.bitmap != null)
			{
				@:privateAccess
				var cached = FlxG.bitmap._cache;
				if (cached != null)
				{
					for (key in cached.keys())
					{
						var graph = cached.get(key);
						if (graph != null && graph.width > 0 && graph.height > 0)
						{
							totalBytes += (graph.width * 1.0) * (graph.height * 1.0) * 4.0;
							count++;
						}
					}
				}
			}
		}
		catch (e:Dynamic) {}
		return {bytes: totalBytes, count: count};
	}

	/**
	 * Retrieves OpenGL draw calls per frame if available.
	 */
	public static function getDrawCalls():Int
	{
		#if (!flash && flixel)
		try
		{
			return openfl.display._internal.stats.Context3DStats.totalDrawCalls();
		}
		catch (e:Dynamic) {}
		#end
		return 0;
	}

	/**
	 * Counts active members in the current FlxState & SubState.
	 */
	public static function getActiveObjectsCount():Int
	{
		var count:Int = 0;
		try
		{
			if (FlxG.state != null && FlxG.state.members != null)
			{
				count += countGroupMembers(FlxG.state.members);
				if (FlxG.state.subState != null && FlxG.state.subState.members != null)
				{
					count += countGroupMembers(FlxG.state.subState.members);
				}
			}
		}
		catch (e:Dynamic) {}
		return count;
	}

	static function countGroupMembers(members:Array<Dynamic>, depth:Int = 0):Int
	{
		if (members == null || depth > 3) return 0;
		var c:Int = 0;
		for (m in members)
		{
			if (m != null)
			{
				c++;
				try
				{
					var subMembers:Array<Dynamic> = Reflect.field(m, "members");
					if (subMembers != null && Std.isOfType(subMembers, Array))
					{
						c += countGroupMembers(subMembers, depth + 1);
					}
				}
				catch (e:Dynamic) {}
			}
		}
		return c;
	}

	/**
	 * Returns clean formatted name of the current game state.
	 */
	public static function getCurrentStateName():String
	{
		try
		{
			if (FlxG.state != null)
			{
				var cls = Type.getClass(FlxG.state);
				if (cls != null)
				{
					var full = Type.getClassName(cls);
					var parts = full.split(".");
					var name = parts[parts.length - 1];
					if (FlxG.state.subState != null)
					{
						var subCls = Type.getClass(FlxG.state.subState);
						if (subCls != null)
						{
							var subParts = Type.getClassName(subCls).split(".");
							name += ' [' + subParts[subParts.length - 1] + ']';
						}
					}
					return name;
				}
			}
			if (Main.mainClassState != null)
			{
				var parts = Type.getClassName(Main.mainClassState).split(".");
				return parts[parts.length - 1];
			}
		}
		catch (e:Dynamic) {}
		return "Unknown";
	}

	// -------------------------------------------------------------
	// PUBLIC API & COMPATIBILITY
	// -------------------------------------------------------------

	public static function updateDisplayInfo(shouldDisplayFps:Bool, shouldDisplayExtra:Bool, shouldDisplayMemory:Bool):Void
	{
		displayFps = shouldDisplayFps;
		displayExtra = shouldDisplayExtra;
		displayMemory = shouldDisplayMemory;

		if (instance != null)
		{
			instance.visible = (displayFps || displayMemory || displayExtra);
			instance.forceUpdate();
		}
	}

	// TextField compatibility wrappers
	public var text(get, set):String;
	function get_text():String return textField != null ? textField.text : "";
	function set_text(val:String):String
	{
		if (textField != null) textField.text = val;
		return val;
	}

	public var defaultTextFormat(get, set):TextFormat;
	function get_defaultTextFormat():TextFormat return textField != null ? textField.defaultTextFormat : null;
	function set_defaultTextFormat(val:TextFormat):TextFormat
	{
		if (textField != null) textField.defaultTextFormat = val;
		return val;
	}

	public var autoSize(get, set):TextFieldAutoSize;
	function get_autoSize():TextFieldAutoSize return textField != null ? textField.autoSize : TextFieldAutoSize.NONE;
	function set_autoSize(val:TextFieldAutoSize):TextFieldAutoSize
	{
		if (textField != null) textField.autoSize = val;
		return val;
	}

	public var selectable(get, set):Bool;
	function get_selectable():Bool return textField != null ? textField.selectable : false;
	function set_selectable(val:Bool):Bool
	{
		if (textField != null) textField.selectable = val;
		return val;
	}
}

/**
 * Codename Engine-styled `FramerateCategory` debug panel.
 * Renders a semi-transparent 0x000000 (0.5 alpha) box with a category title and body text.
 */
class FramerateCategoryPanel extends Sprite
{
	public var bg:Shape;
	public var titleField:TextField;
	public var bodyField:TextField;
	public var panelHeight(default, null):Float = 0;

	public function new(title:String, fontName:String)
	{
		super();

		bg = new Shape();
		addChild(bg);

		titleField = new TextField();
		titleField.x = 6;
		titleField.y = 4;
		titleField.autoSize = TextFieldAutoSize.LEFT;
		titleField.selectable = false;
		titleField.mouseEnabled = false;
		titleField.defaultTextFormat = new TextFormat(fontName, 14, 0xFFFFFF, true);
		titleField.text = title;
		addChild(titleField);

		bodyField = new TextField();
		bodyField.x = 6;
		bodyField.y = titleField.y + titleField.height;
		bodyField.autoSize = TextFieldAutoSize.LEFT;
		bodyField.selectable = false;
		bodyField.mouseEnabled = false;
		bodyField.multiline = true;
		bodyField.wordWrap = false;
		bodyField.alpha = 0.85;
		bodyField.defaultTextFormat = new TextFormat(fontName, 12, 0xFFFFFF, false);
		addChild(bodyField);
	}

	public function updateContent(content:String):Void
	{
		bodyField.text = content;
		bodyField.y = titleField.y + titleField.height - 2;

		var maxW:Float = Math.max(titleField.width, bodyField.width) + 12;
		panelHeight = bodyField.y + bodyField.height + 4;

		bg.graphics.clear();
		bg.graphics.beginFill(0x000000, 0.5);
		bg.graphics.drawRect(0, 0, maxW, panelHeight);
		bg.graphics.endFill();
	}
}

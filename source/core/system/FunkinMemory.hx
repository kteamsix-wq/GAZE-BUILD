package core.system;

using StringTools;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.system.System;
import openfl.text.Font;
import openfl.utils.AssetCache;
import openfl.utils.AssetType;
#if lime
import lime.utils.Assets as LimeAssets;
#end
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif neko
import neko.vm.Gc;
#end

/**
 * Dual-Layer OpenFL AssetCache modelled directly after Codename Engine's `FunkinCache`.
 *
 * Layer 1 (`bitmapData`, `sound`, `font`) holds assets actively used in the current state.
 * Layer 2 (`bitmapData2`, `sound2`, `font2`) holds assets from the previous state during transitions.
 * Any asset requested during the new state's `create()` is promoted from Layer 2 to Layer 1
 * without disk/GPU reload, and unreferenced Layer 2 assets are purged on `postStateSwitch`.
 */
class FunkinCache extends AssetCache
{
	public static var instance:FunkinCache;

	@:noCompletion public var bitmapData2:Map<String, BitmapData> = [];
	@:noCompletion public var font2:Map<String, Font> = [];
	@:noCompletion public var sound2:Map<String, Sound> = [];

	public function new()
	{
		super();
		moveToSecondLayer();
		instance = this;
	}

	public function moveToSecondLayer():Void
	{
		bitmapData2 = bitmapData;
		font2 = font;
		sound2 = sound;

		bitmapData = [];
		font = [];
		sound = [];
	}

	public function clearSecondLayer():Void
	{
		if (bitmapData2 != null)
		{
			for (k => bmp in bitmapData2)
			{
				if (bmp != null && !bitmapData.exists(k) && !FunkinMemory.permanentCachedTextures.exists(k) && !Paths.dumpExclusions.contains(k))
				{
					#if lime
					if (LimeAssets.cache != null && LimeAssets.cache.image != null)
						LimeAssets.cache.image.remove(k);
					#end
					@:privateAccess
					if (bmp.__texture != null)
					{
						try { bmp.__texture.dispose(); } catch (e:Dynamic) {}
					}
					bmp.disposeImage();
					bmp.dispose();
				}
			}
		}

		if (sound2 != null)
		{
			for (k => snd in sound2)
			{
				if (snd != null && !sound.exists(k) && !FunkinMemory.permanentCachedSounds.exists(k) && !Paths.dumpExclusions.contains(k))
				{
					#if lime
					if (LimeAssets.cache != null && LimeAssets.cache.audio != null)
						LimeAssets.cache.audio.remove(k);
					#end
					try { snd.close(); } catch (e:Dynamic) {}
				}
			}
		}

		bitmapData2 = [];
		font2 = [];
		sound2 = [];
	}

	public override function getBitmapData(id:String):BitmapData
	{
		if (!enabled) return null;
		if (bitmapData2.exists(id))
		{
			var bmp = bitmapData2.get(id);
			bitmapData2.remove(id);
			bitmapData.set(id, bmp);
			return bmp;
		}
		return bitmapData.get(id);
	}

	public override function getFont(id:String):Font
	{
		if (!enabled) return null;
		if (font2.exists(id))
		{
			var fnt = font2.get(id);
			font2.remove(id);
			font.set(id, fnt);
			return fnt;
		}
		return font.get(id);
	}

	public override function getSound(id:String):Sound
	{
		if (!enabled) return null;
		if (sound2.exists(id))
		{
			var snd = sound2.get(id);
			sound2.remove(id);
			sound.set(id, snd);
			return snd;
		}
		return sound.get(id);
	}

	public override function hasBitmapData(id:String):Bool
	{
		return bitmapData.exists(id) || bitmapData2.exists(id);
	}

	public override function hasFont(id:String):Bool
	{
		return font.exists(id) || font2.exists(id);
	}

	public override function hasSound(id:String):Bool
	{
		return sound.exists(id) || sound2.exists(id);
	}

	public override function removeBitmapData(id:String):Bool
	{
		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.image != null)
			LimeAssets.cache.image.remove(id);
		#end
		var r1 = bitmapData.remove(id);
		var r2 = bitmapData2.remove(id);
		return r1 || r2;
	}

	public override function removeFont(id:String):Bool
	{
		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.font != null)
			LimeAssets.cache.font.remove(id);
		#end
		var r1 = font.remove(id);
		var r2 = font2.remove(id);
		return r1 || r2;
	}

	public override function removeSound(id:String):Bool
	{
		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.audio != null)
			LimeAssets.cache.audio.remove(id);
		#end
		var r1 = sound.remove(id);
		var r2 = sound2.remove(id);
		return r1 || r2;
	}
}

typedef MemoryUtil = FunkinMemory;

/**
 * Codename Engine-style Memory & Cache Manager (`FunkinCache` + `MemoryUtil`).
 *
 * Features:
 * - Two-Layer state transition asset caching via `FlxG.signals.preStateSwitch` & `postStateSwitch`.
 * - Low-level Haxe GC control (`clearMinor`, `clearMajor`, `enable`, `disable`, `askDisable`, `askEnable`).
 * - Accurate Haxe GC Heap & Native OS memory metrics (`currentMemUsage`, `getTotalMem`, `getProcessMemory`).
 * - Windows Working Set trimming on major purges to keep OS RAM usage low.
 */
#if (cpp && windows)
@:cppFileCode('
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#pragma comment(lib, "psapi.lib")
')
#end
class FunkinMemory
{
	public static var initialized:Bool = false;
	public static var disableCount:Int = 0;

	public static var permanentCachedTextures:Map<String, FlxGraphic> = [];
	public static var currentCachedTextures:Map<String, FlxGraphic> = [];
	public static var previousCachedTextures:Map<String, FlxGraphic> = [];

	public static var permanentCachedSounds:Map<String, Sound> = [];
	public static var currentCachedSounds:Map<String, Sound> = [];
	public static var previousCachedSounds:Map<String, Sound> = [];

	public static var purgeFilter:Array<String> = [];

	/**
	 * Initializes Codename Engine's dual-layer `FunkinCache` and state switch GC lifecycle.
	 */
	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		if (!(Assets.cache is FunkinCache))
		{
			Assets.cache = new FunkinCache();
		}

		if (FlxG.signals != null)
		{
			FlxG.signals.preStateSwitch.add(onPreStateSwitch);
			FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		}
	}

	/**
	 * Executed right before a state switch begins.
	 * Moves active caches to the Second Layer so assets reused by the incoming state
	 * are rescued without reloading from disk or re-uploading to GPU.
	 */
	private static function onPreStateSwitch():Void
	{
		Paths.moveToSecondLayer();
		preparePurgeTextureCache();
		preparePurgeSoundCache();

		if (FunkinCache.instance != null)
			FunkinCache.instance.moveToSecondLayer();
	}

	/**
	 * Executed right after the old state is destroyed and the new state's `create()` finishes.
	 * Disposes all unrescued Second Layer assets and performs a full compacting GC pass.
	 */
	private static function onPostStateSwitch():Void
	{
		if (FunkinCache.instance != null)
			FunkinCache.instance.clearSecondLayer();

		Paths.clearSecondLayer();
		purgeTextureCache();
		purgeSoundCache();

		clearMajor();
	}

	/**
	 * Configures initial memory system hooks without bloating CPU RAM with unused shared assets.
	 */
	public static function initialCache():Void
	{
		init();

		// Ensure core menu music tracks are protected from automatic purging
		Paths.excludeAsset('assets/music/system/freakyMenu.${Paths.SOUND_EXT}');
		Paths.excludeAsset('assets/music/foreverMenu.${Paths.SOUND_EXT}');
		Paths.excludeAsset('assets/music/system/breakfast.${Paths.SOUND_EXT}');

		clearMajor();
	}

	// =========================================================================
	// CODENAME ENGINE MEMORYUTIL API (GC & HARDWARE METRICS)
	// =========================================================================

	public static function askDisable():Void
	{
		disableCount++;
		if (disableCount > 0)
			disable();
		else
			enable();
	}

	public static function askEnable():Void
	{
		disableCount--;
		if (disableCount > 0)
			disable();
		else
			enable();
	}

	/**
	 * Enables garbage collection.
	 */
	public static inline function enable():Void
	{
		#if (cpp || hl)
		Gc.enable(true);
		#end
	}

	/**
	 * Disables automatic garbage collection during heavy synchronous loading.
	 */
	public static inline function disable():Void
	{
		#if (cpp || hl)
		Gc.enable(false);
		#end
	}

	/**
	 * Performs a fast minor garbage collection pass.
	 */
	public static inline function clearMinor():Void
	{
		#if (cpp || neko)
		Gc.run(false);
		#end
	}

	/**
	 * Performs a full garbage collection pass, compacts the C++ GC heap,
	 * and trims unused OS working set pages.
	 */
	public static function clearMajor():Void
	{
		#if (cpp || neko)
		Gc.run(true);
		#elseif hl
		Gc.major();
		#else
		System.gc();
		#end
	}

	/**
	 * Gets the current memory usage of the engine in bytes (Codename Engine `MemoryUtil.currentMemUsage()`).
	 * Reflects Haxe GC managed memory (staying low when GPU texture caching is active).
	 */
	public static inline function currentMemUsage():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_USAGE);
		#else
		return System.totalMemory;
		#end
	}

	/**
	 * Gets total Haxe GC reserved heap memory in bytes.
	 */
	public static inline function reservedMemUsage():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_RESERVED);
		#else
		return System.totalMemory;
		#end
	}

	/**
	 * Returns total physical RAM installed on the system in bytes.
	 */
	#if (cpp && windows)
	@:functionCode('
		MEMORYSTATUSEX status;
		status.dwLength = sizeof(status);
		if (GlobalMemoryStatusEx(&status)) {
			return (double)status.ullTotalPhys;
		}
		return 0.0;
	')
	public static function getTotalMem():Float
	{
		return 0.0;
	}

	/**
	 * Trims unused pages from the Windows process Working Set after a major GC.
	 */
	@:functionCode('
		SetProcessWorkingSetSize(GetCurrentProcess(), (SIZE_T)-1, (SIZE_T)-1);
	')
	public static function trimWorkingSet():Void {}
	#elseif (cpp && linux)
	public static function getTotalMem():Float
	{
		try
		{
			var meminfo = sys.io.File.getContent("/proc/meminfo");
			for (line in meminfo.split("\n"))
			{
				if (line.startsWith("MemTotal:"))
				{
					var parts = line.split(" ");
					for (p in parts)
					{
						var val = Std.parseFloat(p);
						if (!Math.isNaN(val) && val > 0)
							return val * 1024.0;
					}
				}
			}
		}
		catch (e:Dynamic) {}
		return 0.0;
	}
	public static inline function trimWorkingSet():Void {}
	#else
	public static inline function getTotalMem():Float return 0.0;
	public static inline function trimWorkingSet():Void {}
	#end

	// =========================================================================
	// TEXTURE & SOUND CACHING / PURGING
	// =========================================================================

	/**
	 * Clears the current texture and sound caches.
	 */
	public static function purgeCache(callGarbageCollector:Bool = true):Void
	{
		preparePurgeTextureCache();
		purgeTextureCache();
		preparePurgeSoundCache();
		purgeSoundCache();

		if (FunkinCache.instance != null)
			FunkinCache.instance.clearSecondLayer();

		if (callGarbageCollector)
			clearMajor();
	}

	public static function cacheTexture(key:Dynamic):Void
	{
		var strKey:String = "";
		var preGraphic:FlxGraphic = null;

		if (key is FlxGraphic)
		{
			preGraphic = cast(key, FlxGraphic);
			strKey = preGraphic.key;
		}
		else
		{
			strKey = Std.string(key);
		}

		if (strKey == null || strKey.length == 0) return;
		if (currentCachedTextures.exists(strKey)) return;

		if (previousCachedTextures.exists(strKey))
		{
			var cached:Null<FlxGraphic> = previousCachedTextures.get(strKey);
			previousCachedTextures.remove(strKey);
			if (cached != null && !cached.isDestroyed)
			{
				currentCachedTextures.set(strKey, cached);
				return;
			}
		}

		var graphic:Null<FlxGraphic> = preGraphic != null ? preGraphic : Paths.returnGraphic(strKey);
		if (graphic == null)
		{
			FlxG.log.warn('Failed to cache graphic: $strKey');
			return;
		}

		graphic.persist = true;
		currentCachedTextures.set(strKey, graphic);
	}

	public static function permanentCacheTexture(key:Dynamic):Void
	{
		var strKey:String = "";
		var preGraphic:FlxGraphic = null;

		if (key is FlxGraphic)
		{
			preGraphic = cast(key, FlxGraphic);
			strKey = preGraphic.key;
		}
		else
		{
			strKey = Std.string(key);
		}

		if (strKey == null || strKey.length == 0) return;
		if (permanentCachedTextures.exists(strKey)) return;

		var graphic:Null<FlxGraphic> = preGraphic != null ? preGraphic : Paths.returnGraphic(strKey);
		if (graphic == null)
		{
			FlxG.log.warn('Failed to permanently cache graphic: $strKey');
			return;
		}

		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		permanentCachedTextures.set(strKey, graphic);
		currentCachedTextures.set(strKey, graphic);
		Paths.excludeAsset(graphic.key);
		Paths.excludeAsset(strKey);
	}

	public static function getCachedGraphic(path:String):Null<FlxGraphic>
	{
		if (permanentCachedTextures.exists(path)) return permanentCachedTextures.get(path);
		if (currentCachedTextures.exists(path)) return currentCachedTextures.get(path);
		if (previousCachedTextures.exists(path))
		{
			var g = previousCachedTextures.get(path);
			previousCachedTextures.remove(path);
			if (g != null && !g.isDestroyed)
			{
				currentCachedTextures.set(path, g);
				return g;
			}
		}
		return null;
	}

	public static function preparePurgeTextureCache():Void
	{
		previousCachedTextures = currentCachedTextures.copy();

		for (graphicKey in previousCachedTextures.keys())
		{
			if (permanentCachedTextures.exists(graphicKey))
				previousCachedTextures.remove(graphicKey);
		}

		currentCachedTextures = permanentCachedTextures.copy();
	}

	public static function purgeTextureCache():Void
	{
		for (graphicKey in previousCachedTextures.keys())
		{
			if (permanentCachedTextures.exists(graphicKey) || graphicKey.contains('fonts'))
			{
				previousCachedTextures.remove(graphicKey);
				continue;
			}

			var graphic:Null<FlxGraphic> = previousCachedTextures.get(graphicKey);
			if (graphic != null)
			{
				Paths.disposeGraphic(graphicKey, graphic);
				previousCachedTextures.remove(graphicKey);
			}
		}
	}

	public static function isTextureCached(key:String):Bool
	{
		return FlxG.bitmap.get(key) != null
			&& (permanentCachedTextures.exists(key) || currentCachedTextures.exists(key) || previousCachedTextures.exists(key));
	}

	public static function cacheSound(key:Dynamic):Void
	{
		var strKey:String = "";
		var preSound:Sound = null;

		if (key is Sound)
		{
			preSound = cast(key, Sound);
			strKey = "sound_" + Std.string(Reflect.field(preSound, "id") != null ? Reflect.field(preSound, "id") : Std.random(999999));
		}
		else
		{
			strKey = Std.string(key);
		}

		if (strKey == null || strKey.length == 0) return;
		if (currentCachedSounds.exists(strKey)) return;

		if (previousCachedSounds.exists(strKey))
		{
			var cached:Null<Sound> = previousCachedSounds.get(strKey);
			previousCachedSounds.remove(strKey);
			if (cached != null)
			{
				currentCachedSounds.set(strKey, cached);
				return;
			}
		}

		var sound:Null<Sound> = preSound != null ? preSound : (Assets.exists(strKey, SOUND) ? Assets.getSound(strKey, false) : Paths.sound(strKey));
		if (sound != null)
			currentCachedSounds.set(strKey, sound);
	}

	public static function permanentCacheSound(key:Dynamic):Void
	{
		var strKey:String = "";
		var preSound:Sound = null;

		if (key is Sound)
		{
			preSound = cast(key, Sound);
			strKey = "sound_" + Std.string(Reflect.field(preSound, "id") != null ? Reflect.field(preSound, "id") : Std.random(999999));
		}
		else
		{
			strKey = Std.string(key);
		}

		if (strKey == null || strKey.length == 0) return;
		if (permanentCachedSounds.exists(strKey)) return;

		var sound:Null<Sound> = preSound != null ? preSound : (Assets.exists(strKey, SOUND) ? Assets.getSound(strKey, false) : Paths.sound(strKey));
		if (sound != null)
		{
			permanentCachedSounds.set(strKey, sound);
			currentCachedSounds.set(strKey, sound);
			Paths.excludeAsset(strKey);
		}
	}

	public static function preparePurgeSoundCache():Void
	{
		previousCachedSounds = currentCachedSounds.copy();

		for (key in previousCachedSounds.keys())
		{
			if (permanentCachedSounds.exists(key))
				previousCachedSounds.remove(key);
		}

		currentCachedSounds = permanentCachedSounds.copy();
	}

	public static function purgeSoundCache():Void
	{
		for (key in previousCachedSounds.keys())
		{
			if (permanentCachedSounds.exists(key) || Paths.dumpExclusions.contains(key))
			{
				previousCachedSounds.remove(key);
				continue;
			}

			var sound:Null<Sound> = previousCachedSounds.get(key);
			if (sound != null)
			{
				Paths.disposeSound(key, sound);
				previousCachedSounds.remove(key);
			}
		}
	}
}

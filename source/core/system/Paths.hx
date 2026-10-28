package core.system;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
#if lime
import lime.utils.Assets as LimeAssets;
#end

import core.utils.CoolUtil;
import core.system.FunkinMemory;
import core.system.FunkinShader;

using StringTools;

/**
 * Codename Engine-inspired Asset & Memory Management System (`Paths` + `FunkinCache`).
 *
 * Features:
 * - Dual-layer state transition cache (`currentTracked*` + `previousTracked*`)
 *   that rescues shared textures, atlases, and sounds across state switches with zero disk/GPU reload.
 * - GPU-Only Texture Streaming (`gpuCaching` / `gpuOnlyBitmaps`): uploads textures directly to
 *   Stage3D VRAM and immediately disposes CPU `BitmapData` and Lime image buffers.
 * - Canonical key normalization (eliminates duplicate cache entries and premature texture disposal).
 * - Fast path resolution cache (`tempPathsCache`) cleared automatically on state switches.
 */
class Paths
{
	// =========================================================================
	// SECTION 1: CONSTANTS & EXTENSIONS
	// =========================================================================

	inline public static var SOUND_EXT:String = "ogg";
	inline public static var VIDEO_EXT:String = "mp4";

	// =========================================================================
	// SECTION 2: DUAL-LAYER ASSET TRACKING & CACHE REGISTRIES
	// =========================================================================

	// Layer 1: Active State Assets
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedTextures:Map<String, Texture> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static var currentTrackedAtlases:Map<String, FlxAtlasFrames> = [];
	public static var localTrackedAssets:Array<String> = [];

	// Layer 2: Previous State Assets (Rescued if requested during state transition, purged on postStateSwitch)
	public static var previousTrackedAssets:Map<String, FlxGraphic> = [];
	public static var previousTrackedTextures:Map<String, Texture> = [];
	public static var previousTrackedSounds:Map<String, Sound> = [];
	public static var previousTrackedAtlases:Map<String, FlxAtlasFrames> = [];

	// Temporary path lookup cache (Codename Engine `tempPathsCache`)
	public static var tempPathsCache:Map<String, String> = [];

	/**
	 * Determines whether GPU Caching (VRAM-only textures) is enabled according to user settings.
	 * Follows Codename Engine's `gpuOnlyBitmaps` logic.
	 */
	public static var gpuCaching(get, set):Bool;

	inline static function get_gpuCaching():Bool
	{
		#if (mac || web)
		return false; // Hardware texture issues on macOS / WebGL
		#else
		if (Init.trueSettings != null && Init.trueSettings.exists('GPU Caching'))
			return Init.trueSettings.get('GPU Caching') == true;
		return true;
		#end
	}

	inline static function set_gpuCaching(value:Bool):Bool
	{
		if (Init.trueSettings != null)
			Init.trueSettings.set('GPU Caching', value);
		return value;
	}

	/**
	 * List of assets excluded from memory purging (e.g. persistent menu tracks, common UI).
	 */
	public static var dumpExclusions:Array<String> = [
		'assets/music/system/freakyMenu.$SOUND_EXT',
		'assets/music/foreverMenu.$SOUND_EXT',
		'assets/music/system/breakfast.$SOUND_EXT'
	];

	// =========================================================================
	// SECTION 3: CODENAME ENGINE DUAL-LAYER MEMORY & CACHE MANAGEMENT
	// =========================================================================

	/**
	 * Adds an asset path or key to the dump exclusion list.
	 */
	public static function excludeAsset(key:String):Void
	{
		if (key != null && key.length > 0 && !dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	/**
	 * Identifies whether an asset belongs to core HaxeFlixel / framework internals or fonts.
	 */
	public static function isProtectedAsset(key:String):Bool
	{
		if (key == null) return true;
		if (dumpExclusions.contains(key) || FunkinMemory.permanentCachedTextures.exists(key) || FunkinMemory.permanentCachedSounds.exists(key))
			return true;
		var normalizedKey:String = key.toLowerCase();
		return normalizedKey.indexOf('flixel/') == 0
			|| normalizedKey.indexOf('/flixel/') != -1
			|| normalizedKey.indexOf('fonts/') != -1
			|| normalizedKey.indexOf('ui/notes/default/') != -1
			|| normalizedKey.endsWith('.ttf')
			|| normalizedKey.endsWith('.otf');
	}

	/**
	 * Moves all active Layer 1 caches into Layer 2 right before a state switch (`preStateSwitch`).
	 * Assets requested by the new state are promoted back to Layer 1 without reloading.
	 */
	public static function moveToSecondLayer():Void
	{
		for (k => v in currentTrackedAssets)
		{
			if (v != null && !v.isDestroyed)
				previousTrackedAssets.set(k, v);
		}
		for (k => v in currentTrackedTextures)
		{
			if (v != null)
				previousTrackedTextures.set(k, v);
		}
		for (k => v in currentTrackedAtlases)
		{
			if (v != null)
				previousTrackedAtlases.set(k, v);
		}
		for (k => v in currentTrackedSounds)
		{
			if (v != null)
				previousTrackedSounds.set(k, v);
		}

		currentTrackedAssets = [];
		currentTrackedTextures = [];
		currentTrackedAtlases = [];
		currentTrackedSounds = [];
		localTrackedAssets = [];
		tempPathsCache = [];
	}

	/**
	 * Purges all unrescued assets remaining in Layer 2 after the new state finishes `create()` (`postStateSwitch`).
	 */
	public static function clearSecondLayer():Void
	{
		// 1. Dispose unrescued atlas frames only if their parent graphic is also unrescued
		for (key in previousTrackedAtlases.keys())
		{
			var atlas:FlxAtlasFrames = previousTrackedAtlases.get(key);
			if (!currentTrackedAtlases.exists(key) && !currentTrackedAssets.exists(key) && !localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				if (atlas != null)
					atlas.destroy();
			}
			else if (atlas != null && atlas.frames != null && !currentTrackedAtlases.exists(key))
			{
				currentTrackedAtlases.set(key, atlas);
			}
			previousTrackedAtlases.remove(key);
		}

		// 2. Dispose unrescued graphics & hardware GPU textures
		for (key in previousTrackedAssets.keys())
		{
			var obj:FlxGraphic = previousTrackedAssets.get(key);
			if (!currentTrackedAssets.exists(key) && !localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				disposeGraphic(key, obj);
			}
			else if (obj != null && !obj.isDestroyed)
			{
				// Protected asset: keep in Layer 1
				currentTrackedAssets.set(key, obj);
				if (previousTrackedTextures.exists(key))
					currentTrackedTextures.set(key, previousTrackedTextures.get(key));
			}
			previousTrackedAssets.remove(key);
			previousTrackedTextures.remove(key);
		}

		// Dispose any orphaned GPU textures in Layer 2
		for (key in previousTrackedTextures.keys())
		{
			if (!currentTrackedTextures.exists(key) && !isProtectedAsset(key))
			{
				var tex:Texture = previousTrackedTextures.get(key);
				if (tex != null)
				{
					try { tex.dispose(); } catch (e:Dynamic) {}
				}
			}
			previousTrackedTextures.remove(key);
		}

		// 3. Dispose unrescued sounds
		for (key in previousTrackedSounds.keys())
		{
			var snd:Sound = previousTrackedSounds.get(key);
			if (!currentTrackedSounds.exists(key) && !localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				disposeSound(key, snd);
			}
			else if (snd != null)
			{
				currentTrackedSounds.set(key, snd);
			}
			previousTrackedSounds.remove(key);
		}

		// 4. Clean up any untracked FlxG.bitmap entries
		cleanUntrackedFlxBitmaps();
	}

	/**
	 * Safely disposes a `FlxGraphic`, its Stage3D GPU `Texture`, CPU `BitmapData`, and Lime/OpenFL cache entries.
	 */
	public static function disposeGraphic(key:String, obj:FlxGraphic):Void
	{
		if (currentTrackedTextures.exists(key))
		{
			var texture:Texture = currentTrackedTextures.get(key);
			if (texture != null)
			{
				try { texture.dispose(); } catch (e:Dynamic) {}
			}
			currentTrackedTextures.remove(key);
		}

		if (previousTrackedTextures.exists(key))
		{
			var texture2:Texture = previousTrackedTextures.get(key);
			if (texture2 != null)
			{
				try { texture2.dispose(); } catch (e:Dynamic) {}
			}
			previousTrackedTextures.remove(key);
		}

		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.image != null)
			LimeAssets.cache.image.remove(key);
		#end

		@:privateAccess
		if (OpenFlAssets.cache != null && OpenFlAssets.cache.hasBitmapData(key))
			OpenFlAssets.cache.removeBitmapData(key);

		if (obj != null)
		{
			if (obj.bitmap != null)
			{
				@:privateAccess
				if (obj.bitmap.__texture != null)
				{
					try { obj.bitmap.__texture.dispose(); } catch (e:Dynamic) {}
				}
				try
				{
					obj.bitmap.disposeImage();
					obj.bitmap.dispose();
				}
				catch (e:Dynamic) {}
			}

			if (FlxG.bitmap != null)
			{
				@:privateAccess
				if (FlxG.bitmap._cache != null)
					FlxG.bitmap._cache.remove(key);
			}

			obj.persist = false;
			obj.destroyOnNoUse = true;
			obj.destroy();
		}

		currentTrackedAssets.remove(key);
		previousTrackedAssets.remove(key);
	}

	/**
	 * Safely closes and removes a `Sound` buffer from OpenFL and Lime audio caches.
	 */
	public static function disposeSound(key:String, snd:Sound):Void
	{
		// Do not close the sound if it is actively playing as the main menu/song music
		if (FlxG.sound != null && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			@:privateAccess
			if (FlxG.sound.music._sound == snd)
				return;
		}

		if (snd != null)
		{
			try { snd.close(); } catch (e:Dynamic) {}
		}

		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.audio != null)
			LimeAssets.cache.audio.remove(key);
		#end

		@:privateAccess
		if (OpenFlAssets.cache != null && OpenFlAssets.cache.hasSound(key))
			OpenFlAssets.cache.removeSound(key);

		currentTrackedSounds.remove(key);
		previousTrackedSounds.remove(key);
	}

	/**
	 * Removes any untracked graphics sitting in `FlxG.bitmap._cache`.
	 */
	private static function cleanUntrackedFlxBitmaps():Void
	{
		if (FlxG.bitmap == null) return;

		@:privateAccess
		var cache = FlxG.bitmap._cache;
		if (cache == null) return;

		var keysToRemove:Array<String> = [];
		for (key in cache.keys())
		{
			var obj:FlxGraphic = cache.get(key);
			if (obj == null || obj.isDestroyed)
			{
				keysToRemove.push(key);
			}
			else if (!currentTrackedAssets.exists(key) && !localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				// Keep generated makeGraphic keys if they are still actively referenced by sprites (useCount > 0)
				if (obj.useCount <= 0)
					keysToRemove.push(key);
			}
		}

		for (key in keysToRemove)
		{
			var obj:FlxGraphic = cache.get(key);
			disposeGraphic(key, obj);
		}
	}

	/**
	 * Cleans up unreferenced graphics, GPU textures, atlases, and audio
	 * that are no longer present in `localTrackedAssets`.
	 */
	public static function clearUnusedMemory():Void
	{
		clearSecondLayer();

		for (key in currentTrackedAtlases.keys())
		{
			if (!localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				var atlas:FlxAtlasFrames = currentTrackedAtlases.get(key);
				if (atlas != null)
					atlas.destroy();
				currentTrackedAtlases.remove(key);
			}
		}

		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				var obj:FlxGraphic = currentTrackedAssets.get(key);
				disposeGraphic(key, obj);
			}
		}

		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !isProtectedAsset(key))
			{
				var snd:Sound = currentTrackedSounds.get(key);
				disposeSound(key, snd);
			}
		}

		FunkinMemory.clearMajor();
	}

	/**
	 * Thorough memory purge helper.
	 * Moves current assets to Layer 2 and cleans untracked FlxG bitmaps.
	 */
	public static function clearStoredMemory(?cleanUnused:Bool = false):Void
	{
		cleanUntrackedFlxBitmaps();
		tempPathsCache = [];

		if (cleanUnused)
			clearUnusedMemory();
		else
			FunkinMemory.clearMinor();
	}

	// =========================================================================
	// SECTION 4: PATH RESOLUTION & MOD SYSTEM
	// =========================================================================

	/**
	 * Resolves the file path for an asset, searching mod directories first,
	 * with per-state path caching (`tempPathsCache`) like Codename Engine.
	 */
	public static function getPath(file:String, type:AssetType, ?library:Null<String>):String
	{
		if (file == null) return "";

		var modDir:String = #if sys (core.scripting.Mods.currentModDirectory != null ? core.scripting.Mods.currentModDirectory : "") #else "" #end;
		var cacheKey:String = (library != null ? library : "") + "|" + modDir + "|" + file;

		if (tempPathsCache.exists(cacheKey))
			return tempPathsCache.get(cacheKey);

		if (library != null)
		{
			var libResolved:String = getLibraryPath(file, library);
			tempPathsCache.set(cacheKey, libResolved);
			return libResolved;
		}

		#if sys
		if (modDir.length > 0)
		{
			var modPath:String = 'mods/' + modDir + '/' + file;
			if (FileSystem.exists(modPath))
			{
				tempPathsCache.set(cacheKey, modPath);
				return modPath;
			}
		}

		var globalModPath:String = 'mods/' + file;
		if (FileSystem.exists(globalModPath))
		{
			tempPathsCache.set(cacheKey, globalModPath);
			return globalModPath;
		}
		#end

		var levelPath:String = getLibraryPathForce(file, "mods");
		if (OpenFlAssets.exists(levelPath, type))
		{
			tempPathsCache.set(cacheKey, levelPath);
			return levelPath;
		}

		var preloadResolved:String = getPreloadPath(file);
		tempPathsCache.set(cacheKey, preloadResolved);
		return preloadResolved;
	}

	public static function getLibraryPath(file:String, library:String = "preload"):String
	{
		return (library == "preload" || library == "default") ? getPreloadPath(file) : getLibraryPathForce(file, library);
	}

	public static function getLibraryPathForce(file:String, library:String):String
	{
		return '$library/$file';
	}

	public static function getPreloadPath(file:String):String
	{
		var returnPath:String = 'assets/$file';
		#if sys
		if (!FileSystem.exists(returnPath))
		{
			var swapped:String = CoolUtil.swapSpaceDash(returnPath);
			if (FileSystem.exists(swapped))
				returnPath = swapped;
		}
		#end
		return returnPath;
	}

	public static function formatToSongPath(path:String):String
	{
		return CoolUtil.swapSpaceDash(path.toLowerCase());
	}

	// =========================================================================
	// SECTION 5: IMAGE & GRAPHIC PIPELINE (CODENAME GPU-ONLY BITMAPS)
	// =========================================================================

	/**
	 * Loads a graphic with Codename Engine-style GPU texture streaming and memory offloading.
	 * Disposes CPU BitmapData RAM when GPU Caching is enabled.
	 */
	public static function image(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		return returnGraphic(key, library, textureCompression);
	}

	/**
	 * Core image loader. Handles two-layer caching, GPU texture uploads, and CPU RAM disposal.
	 */
	public static function returnGraphic(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		if (key == null || key.length == 0)
			return null;

		var useGpu:Bool = (textureCompression != null) ? textureCompression : gpuCaching;

		// Normalize clean key
		var cleanKey:String = key;
		if (cleanKey.endsWith('.png'))
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var path:String = getPath('images/$cleanKey.png', IMAGE, library);

		// 1. Layer 1 Cache Lookup (Current State)
		if (currentTrackedAssets.exists(path))
		{
			var tracked:FlxGraphic = currentTrackedAssets.get(path);
			if (tracked != null && !tracked.isDestroyed && tracked.bitmap != null)
			{
				// If caller explicitly needs CPU-readable pixels (e.g. healthBar bounds) but cached graphic is GPU-only
				if (textureCompression == false && tracked.bitmap.image == null)
				{
					disposeGraphic(path, tracked);
				}
				else
				{
					trackAsset(path);
					return tracked;
				}
			}
			else
			{
				currentTrackedAssets.remove(path);
			}
		}

		// 2. Layer 2 Cache Lookup & Rescue (Previous State -> Promoted to Current State)
		if (previousTrackedAssets.exists(path))
		{
			var prevGraphic:FlxGraphic = previousTrackedAssets.get(path);
			if (prevGraphic != null && !prevGraphic.isDestroyed && prevGraphic.bitmap != null)
			{
				if (textureCompression == false && prevGraphic.bitmap.image == null)
				{
					disposeGraphic(path, prevGraphic);
				}
				else
				{
					previousTrackedAssets.remove(path);
					currentTrackedAssets.set(path, prevGraphic);

					if (previousTrackedTextures.exists(path))
					{
						var prevTex:Texture = previousTrackedTextures.get(path);
						previousTrackedTextures.remove(path);
						if (prevTex != null)
							currentTrackedTextures.set(path, prevTex);
					}

					prevGraphic.persist = true;
					prevGraphic.destroyOnNoUse = false;

					if (FlxG.bitmap != null)
					{
						@:privateAccess
						FlxG.bitmap._cache.set(path, prevGraphic);
					}

					trackAsset(path);
					return prevGraphic;
				}
			}
			else
			{
				previousTrackedAssets.remove(path);
			}
		}

		// 3. Load BitmapData from disk or OpenFL assets
		var bitmap:BitmapData = null;
		#if sys
		if (FileSystem.exists(path))
		{
			try
			{
				bitmap = BitmapData.fromFile(path);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load bitmap from file: $path - $e');
			}
		}
		#end

		if (bitmap == null && OpenFlAssets.exists(path, IMAGE))
		{
			try
			{
				bitmap = OpenFlAssets.getBitmapData(path, false);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load bitmap from OpenFlAssets: $path - $e');
			}
		}

		if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0)
		{
			FlxG.log.warn('Image asset not found: $path (key: $key)');
			return null;
		}

		// 4. Upload directly to GPU VRAM and discard CPU RAM (Codename Engine `gpuOnlyBitmaps`)
		var newGraphic:FlxGraphic = null;
		if (useGpu && FlxG.stage != null && FlxG.stage.context3D != null)
		{
			try
			{
				var texture:Texture = FlxG.stage.context3D.createTexture(bitmap.width, bitmap.height, BGRA, true, 0);
				texture.uploadFromBitmapData(bitmap);

				// Immediately free heavy CPU pixel buffers from RAM and Lime/OpenFL caches
				bitmap.disposeImage();
				bitmap.dispose();

				#if lime
				if (LimeAssets.cache != null && LimeAssets.cache.image != null)
					LimeAssets.cache.image.remove(path);
				#end
				@:privateAccess
				if (OpenFlAssets.cache != null && OpenFlAssets.cache.hasBitmapData(path))
					OpenFlAssets.cache.removeBitmapData(path);

				var gpuBitmap:BitmapData = BitmapData.fromTexture(texture);
				newGraphic = FlxGraphic.fromBitmapData(gpuBitmap, false, path, false);
				currentTrackedTextures.set(path, texture);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('GPU texture creation failed for $path, falling back to CPU: $e');
				newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path, false);
			}
		}
		else
		{
			newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path, false);
		}

		// 5. Register under canonical `path`
		if (newGraphic != null)
		{
			newGraphic.persist = true;
			newGraphic.destroyOnNoUse = false;

			currentTrackedAssets.set(path, newGraphic);

			if (FlxG.bitmap != null)
			{
				@:privateAccess
				FlxG.bitmap._cache.set(path, newGraphic);
			}
		}

		trackAsset(path);
		return newGraphic;
	}

	inline private static function trackAsset(key:String):Void
	{
		if (key != null && key.length > 0 && !localTrackedAssets.contains(key))
			localTrackedAssets.push(key);
	}

	// =========================================================================
	// SECTION 6: ATLAS & SPRITESHEET PIPELINE (TWO-LAYER CACHE)
	// =========================================================================

	/**
	 * Loads a Sparrow XML atlas with GPU texture support and two-layer frame caching.
	 */
	public static function getSparrowAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		if (cleanKey.endsWith('.xml') || cleanKey.endsWith('.png'))
			cleanKey = cleanKey.substr(0, cleanKey.lastIndexOf('.'));
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getPath('images/$cleanKey.png', IMAGE, library);

		// 1. Layer 1 Atlas Cache Check
		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				// Ensure underlying FlxGraphic is also tracked/rescued
				returnGraphic(cleanKey, library, textureCompression);
				trackAsset(graphicPath);
				return cached;
			}
			else
			{
				currentTrackedAtlases.remove(graphicPath);
			}
		}

		// 2. Layer 2 Atlas Cache Check & Rescue
		if (previousTrackedAtlases.exists(graphicPath))
		{
			var prevAtlas:FlxAtlasFrames = previousTrackedAtlases.get(graphicPath);
			if (prevAtlas != null && prevAtlas.frames != null && prevAtlas.parent != null && !prevAtlas.parent.isDestroyed)
			{
				// Rescue both the parent FlxGraphic/Texture and the parsed FlxAtlasFrames
				returnGraphic(cleanKey, library, textureCompression);
				previousTrackedAtlases.remove(graphicPath);
				currentTrackedAtlases.set(graphicPath, prevAtlas);
				trackAsset(graphicPath);
				return prevAtlas;
			}
			else
			{
				previousTrackedAtlases.remove(graphicPath);
			}
		}

		var graphic:FlxGraphic = returnGraphic(cleanKey, library, textureCompression);
		if (graphic == null)
			return null;

		var xmlPath:String = getPath('images/$cleanKey.xml', TEXT, library);
		var xmlContent:String = null;

		#if sys
		if (FileSystem.exists(xmlPath))
		{
			xmlContent = File.getContent(xmlPath);
		}
		else
		{
			var altPath:String = file('images/$cleanKey.xml', library);
			if (FileSystem.exists(altPath))
				xmlContent = File.getContent(altPath);
		}
		#end

		if (xmlContent == null && OpenFlAssets.exists(xmlPath, TEXT))
			xmlContent = OpenFlAssets.getText(xmlPath);

		if (xmlContent == null)
		{
			FlxG.log.warn('Sparrow XML description not found: images/$cleanKey.xml');
			return null;
		}

		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(graphic, xmlContent);
		if (frames != null)
		{
			currentTrackedAtlases.set(graphicPath, frames);
			trackAsset(graphicPath);
		}

		return frames;
	}

	/**
	 * Loads a SpriteSheet Packer TXT atlas with GPU texture support and two-layer frame caching.
	 */
	public static function getPackerAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		if (cleanKey.endsWith('.txt') || cleanKey.endsWith('.png'))
			cleanKey = cleanKey.substr(0, cleanKey.lastIndexOf('.'));
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getPath('images/$cleanKey.png', IMAGE, library);

		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				returnGraphic(cleanKey, library, textureCompression);
				trackAsset(graphicPath);
				return cached;
			}
			else
			{
				currentTrackedAtlases.remove(graphicPath);
			}
		}

		if (previousTrackedAtlases.exists(graphicPath))
		{
			var prevAtlas:FlxAtlasFrames = previousTrackedAtlases.get(graphicPath);
			if (prevAtlas != null && prevAtlas.frames != null && prevAtlas.parent != null && !prevAtlas.parent.isDestroyed)
			{
				returnGraphic(cleanKey, library, textureCompression);
				previousTrackedAtlases.remove(graphicPath);
				currentTrackedAtlases.set(graphicPath, prevAtlas);
				trackAsset(graphicPath);
				return prevAtlas;
			}
			else
			{
				previousTrackedAtlases.remove(graphicPath);
			}
		}

		var graphic:FlxGraphic = returnGraphic(cleanKey, library, textureCompression);
		if (graphic == null)
			return null;

		var txtPath:String = getPath('images/$cleanKey.txt', TEXT, library);
		var txtContent:String = null;

		#if sys
		if (FileSystem.exists(txtPath))
		{
			txtContent = File.getContent(txtPath);
		}
		else
		{
			var altPath:String = file('images/$cleanKey.txt', library);
			if (FileSystem.exists(altPath))
				txtContent = File.getContent(altPath);
		}
		#end

		if (txtContent == null && OpenFlAssets.exists(txtPath, TEXT))
			txtContent = OpenFlAssets.getText(txtPath);

		if (txtContent == null)
		{
			FlxG.log.warn('Packer TXT description not found: images/$cleanKey.txt');
			return null;
		}

		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, txtContent);
		if (frames != null)
		{
			currentTrackedAtlases.set(graphicPath, frames);
			trackAsset(graphicPath);
		}

		return frames;
	}

	/**
	 * Loads an Aseprite / TexturePacker JSON atlas with GPU texture support and two-layer frame caching.
	 */
	public static function getAsepriteAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		if (cleanKey.endsWith('.json') || cleanKey.endsWith('.png'))
			cleanKey = cleanKey.substr(0, cleanKey.lastIndexOf('.'));
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getPath('images/$cleanKey.png', IMAGE, library);

		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				returnGraphic(cleanKey, library, textureCompression);
				trackAsset(graphicPath);
				return cached;
			}
			else
			{
				currentTrackedAtlases.remove(graphicPath);
			}
		}

		if (previousTrackedAtlases.exists(graphicPath))
		{
			var prevAtlas:FlxAtlasFrames = previousTrackedAtlases.get(graphicPath);
			if (prevAtlas != null && prevAtlas.frames != null && prevAtlas.parent != null && !prevAtlas.parent.isDestroyed)
			{
				returnGraphic(cleanKey, library, textureCompression);
				previousTrackedAtlases.remove(graphicPath);
				currentTrackedAtlases.set(graphicPath, prevAtlas);
				trackAsset(graphicPath);
				return prevAtlas;
			}
			else
			{
				previousTrackedAtlases.remove(graphicPath);
			}
		}

		var graphic:FlxGraphic = returnGraphic(cleanKey, library, textureCompression);
		if (graphic == null)
			return null;

		var jsonPath:String = getPath('images/$cleanKey.json', TEXT, library);
		var jsonContent:String = null;

		#if sys
		if (FileSystem.exists(jsonPath))
		{
			jsonContent = File.getContent(jsonPath);
		}
		else
		{
			var altPath:String = file('images/$cleanKey.json', library);
			if (FileSystem.exists(altPath))
				jsonContent = File.getContent(altPath);
		}
		#end

		if (jsonContent == null && OpenFlAssets.exists(jsonPath, TEXT))
			jsonContent = OpenFlAssets.getText(jsonPath);

		if (jsonContent == null)
		{
			FlxG.log.warn('Aseprite JSON description not found: images/$cleanKey.json');
			return null;
		}

		var frames:FlxAtlasFrames = FlxAtlasFrames.fromTexturePackerJson(graphic, jsonContent);
		if (frames != null)
		{
			currentTrackedAtlases.set(graphicPath, frames);
			trackAsset(graphicPath);
		}

		return frames;
	}

	// =========================================================================
	// SECTION 7: AUDIO PIPELINE (OPTIMIZED TWO-LAYER POOLING & STREAMING)
	// =========================================================================

	/**
	 * Loads a sound effect from the `sounds/` directory.
	 */
	public static function sound(key:String, ?library:String):Sound
	{
		return returnSound('sounds', key, library);
	}

	/**
	 * Loads a randomized sound effect from a numbered pool (e.g., sound + 1 to 5).
	 */
	public static function soundRandom(key:String, min:Int, max:Int, ?library:String):Sound
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	/**
	 * Loads a music track from the `music/` directory.
	 */
	public static function music(key:String, ?library:String):Sound
	{
		return returnSound('music', key, library);
	}

	/**
	 * Checks if a specific song audio file exists in mods or assets (direct or audio/ folder).
	 */
	public static function songAudioExists(song:String, fileName:String):Bool
	{
		var folder:String = formatToSongPath(song);
		var direct:String = 'songs/$folder/$fileName.$SOUND_EXT';
		var audio:String = 'songs/$folder/audio/$fileName.$SOUND_EXT';

		#if sys
		if (core.scripting.Mods.currentModDirectory != null && core.scripting.Mods.currentModDirectory.length > 0)
		{
			if (FileSystem.exists('mods/' + core.scripting.Mods.currentModDirectory + '/' + direct)
				|| FileSystem.exists('mods/' + core.scripting.Mods.currentModDirectory + '/' + audio))
				return true;
		}
		if (FileSystem.exists('mods/' + direct) || FileSystem.exists('mods/' + audio))
			return true;
		if (FileSystem.exists('assets/' + direct) || FileSystem.exists('assets/' + audio))
			return true;
		#end

		var levelDirect = getLibraryPathForce(direct, "mods");
		var levelAudio = getLibraryPathForce(audio, "mods");
		if (OpenFlAssets.exists(levelDirect, SOUND) || OpenFlAssets.exists(levelAudio, SOUND))
			return true;

		var preDirect = getPreloadPath(direct);
		var preAudio = getPreloadPath(audio);
		if (OpenFlAssets.exists(preDirect, SOUND) || OpenFlAssets.exists(preAudio, SOUND))
			return true;

		return false;
	}

	/**
	 * Loads a vocal audio track for a song, with suffix support (e.g. 'Voices-bf', 'Voices-dad', 'Voices-Player', 'Voices-Opponent').
	 */
	public static function voices(song:String, ?postfix:Null<String> = null, ?allowFallback:Bool = false):Sound
	{
		if (postfix != null && postfix.length > 0)
		{
			var postLow:String = postfix.toLowerCase();
			var candidates:Array<String> = [];

			if (postLow == 'bf' || postLow == 'player')
			{
				candidates.push('Voices-bf');
				candidates.push('Voices-Player');
				candidates.push('voices-bf');
				candidates.push('voices-player');
				candidates.push('Voices-$postfix');
				candidates.push('voices-$postfix');
			}
			else if (postLow == 'dad' || postLow == 'opponent')
			{
				candidates.push('Voices-dad');
				candidates.push('Voices-Opponent');
				candidates.push('voices-dad');
				candidates.push('voices-opponent');
				candidates.push('Voices-$postfix');
				candidates.push('voices-$postfix');
			}
			else
			{
				candidates.push('Voices-$postfix');
				candidates.push('voices-$postfix');
				candidates.push('Voices-' + postLow);
				candidates.push('voices-' + postLow);
			}

			for (c in candidates)
			{
				if (songAudioExists(song, c))
				{
					var voiceKey:String = songAudioKey(song, c);
					var snd:Sound = returnSound('songs', voiceKey);
					if (snd != null) return snd;
				}
			}

			if (allowFallback)
			{
				if (songAudioExists(song, 'Voices'))
					return returnSound('songs', songAudioKey(song, 'Voices'));
				if (songAudioExists(song, 'voices'))
					return returnSound('songs', songAudioKey(song, 'voices'));
			}

			return null;
		}

		// When postfix is null or empty:
		if (songAudioExists(song, 'Voices'))
			return returnSound('songs', songAudioKey(song, 'Voices'));
		if (songAudioExists(song, 'voices'))
			return returnSound('songs', songAudioKey(song, 'voices'));

		// Suffix fallback: if a song only has split vocals (like Voices-bf and Voices-dad)
		if (songAudioExists(song, 'Voices-bf'))
			return returnSound('songs', songAudioKey(song, 'Voices-bf'));
		if (songAudioExists(song, 'voices-bf'))
			return returnSound('songs', songAudioKey(song, 'voices-bf'));
		if (songAudioExists(song, 'Voices-Player'))
			return returnSound('songs', songAudioKey(song, 'Voices-Player'));
		if (songAudioExists(song, 'voices-player'))
			return returnSound('songs', songAudioKey(song, 'voices-player'));

		return null;
	}

	/**
	 * Loads the instrumental audio track for a song.
	 */
	public static function inst(song:String):Sound
	{
		return returnSound('songs', songAudioKey(song, 'Inst'));
	}

	/**
	 * Resolves song audio file placement across mods and asset folders (direct vs. audio/ subfolder).
	 */
	private static function songAudioKey(song:String, fileName:String):String
	{
		var folder:String = formatToSongPath(song);

		// 1. Direct song path: songs/$folder/$fileName.ogg
		var checkDirect:String = 'songs/$folder/$fileName.$SOUND_EXT';
		#if sys
		if (core.scripting.Mods.currentModDirectory != null && core.scripting.Mods.currentModDirectory.length > 0)
		{
			if (FileSystem.exists('mods/' + core.scripting.Mods.currentModDirectory + '/' + checkDirect))
				return '$folder/$fileName';
		}
		if (FileSystem.exists('mods/' + checkDirect))
			return '$folder/$fileName';
		if (FileSystem.exists('assets/' + checkDirect))
			return '$folder/$fileName';
		#end

		// 2. Subfolder path: songs/$folder/audio/$fileName.ogg
		var checkAudio:String = 'songs/$folder/audio/$fileName.$SOUND_EXT';
		#if sys
		if (core.scripting.Mods.currentModDirectory != null && core.scripting.Mods.currentModDirectory.length > 0)
		{
			if (FileSystem.exists('mods/' + core.scripting.Mods.currentModDirectory + '/' + checkAudio))
				return '$folder/audio/$fileName';
		}
		if (FileSystem.exists('mods/' + checkAudio))
			return '$folder/audio/$fileName';
		if (FileSystem.exists('assets/' + checkAudio))
			return '$folder/audio/$fileName';
		#end

		// Default fallback
		return '$folder/audio/$fileName';
	}

	/**
	 * Core audio loader. Handles two-layer caching, cross-platform path resolution,
	 * native audio buffering, and memory tracking.
	 */
	public static function returnSound(path:String, key:String, ?library:String):Sound
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		if (cleanKey.endsWith('.' + SOUND_EXT))
			cleanKey = cleanKey.substr(0, cleanKey.length - (SOUND_EXT.length + 1));

		var fileToFind:String = '$path/$cleanKey.$SOUND_EXT';
		var gottenPath:String = getPath(fileToFind, SOUND, library);

		// Sanitize Lime library prefix while preserving Windows drive letters (e.g. C:/)
		var colonIndex:Int = gottenPath.indexOf(':');
		#if sys
		if (colonIndex > 1 && !FileSystem.exists(gottenPath))
		{
			var stripped:String = gottenPath.substring(colonIndex + 1);
			if (FileSystem.exists(stripped))
				gottenPath = stripped;
		}
		#else
		if (colonIndex > 1)
		{
			gottenPath = gottenPath.substring(colonIndex + 1);
		}
		#end

		// 1. Layer 1 Cache Lookup (Current State)
		if (currentTrackedSounds.exists(gottenPath))
		{
			var cached:Sound = currentTrackedSounds.get(gottenPath);
			if (cached != null)
			{
				trackAsset(gottenPath);
				return cached;
			}
			else
			{
				currentTrackedSounds.remove(gottenPath);
			}
		}

		// 2. Layer 2 Cache Lookup & Rescue (Previous State)
		if (previousTrackedSounds.exists(gottenPath))
		{
			var prevSound:Sound = previousTrackedSounds.get(gottenPath);
			if (prevSound != null)
			{
				previousTrackedSounds.remove(gottenPath);
				currentTrackedSounds.set(gottenPath, prevSound);
				trackAsset(gottenPath);
				return prevSound;
			}
			else
			{
				previousTrackedSounds.remove(gottenPath);
			}
		}

		// 3. Load Sound from file or OpenFL asset registry
		var snd:Sound = null;
		#if sys
		if (FileSystem.exists(gottenPath))
		{
			try
			{
				snd = Sound.fromFile(gottenPath);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load sound from file: $gottenPath - $e');
			}
		}
		#end

		if (snd == null && OpenFlAssets.exists(gottenPath, SOUND))
		{
			try
			{
				snd = OpenFlAssets.getSound(gottenPath, false);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load sound from OpenFlAssets: $gottenPath - $e');
			}
		}

		if (snd != null)
		{
			currentTrackedSounds.set(gottenPath, snd);
			trackAsset(gottenPath);
		}
		else
		{
			FlxG.log.warn('Sound asset not found: $gottenPath (key: $key)');
		}

		return snd;
	}

	// =========================================================================
	// SECTION 8: DATA, FILE, SHADER & VIDEO UTILITIES
	// =========================================================================

	public static function file(file:String, type:AssetType = TEXT, ?library:String):String
	{
		return getPath(file, type, library);
	}

	public static function txt(key:String, ?library:String):String
	{
		return getPath('$key.txt', TEXT, library);
	}

	public static function xml(key:String, ?library:String):String
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	public static function offsetTxt(key:String, ?library:String):String
	{
		return getPath('images/characters/$key.txt', TEXT, library);
	}

	public static function json(key:String, ?library:String):String
	{
		return getPath('songs/$key.json', TEXT, library);
	}

	public static function songJson(song:String, secondSong:String, ?library:String):String
	{
		var s1:String = formatToSongPath(song);
		var s2:String = formatToSongPath(secondSong);

		var directPath:String = getPath('songs/$s1/$s2.json', TEXT, library);
		#if sys
		if (FileSystem.exists(directPath))
			return directPath;

		var chartPath:String = getPath('songs/$s1/chart/$s2.json', TEXT, library);
		if (FileSystem.exists(chartPath))
			return chartPath;
		#end

		return directPath;
	}

	public static function font(key:String):String
	{
		var path:String = getPath('data/fonts/$key', FONT);
		#if sys
		if (FileSystem.exists(path))
			return path;
		#end
		return 'assets/data/fonts/$key';
	}

	public static function video(key:String):String
	{
		if (key == null) return "";
		var cleanKey:String = key.trim();
		if (cleanKey.endsWith('.' + VIDEO_EXT))
			cleanKey = cleanKey.substr(0, cleanKey.length - (VIDEO_EXT.length + 1));
		if (cleanKey.startsWith('videos/'))
			cleanKey = cleanKey.substring(7);

		var gottenPath:String = getPath('videos/$cleanKey.$VIDEO_EXT', BINARY);
		var colonIndex:Int = gottenPath.indexOf(':');
		#if sys
		if (colonIndex > 1 && !FileSystem.exists(gottenPath))
		{
			var stripped:String = gottenPath.substring(colonIndex + 1);
			if (FileSystem.exists(stripped))
				gottenPath = stripped;
		}

		if (!FileSystem.exists(gottenPath))
		{
			for (mod in core.scripting.Mods.getModDirectories())
			{
				var candidate:String = 'mods/$mod/videos/$cleanKey.$VIDEO_EXT';
				if (FileSystem.exists(candidate))
					return candidate;
			}
			if (FileSystem.exists('videos/$cleanKey.$VIDEO_EXT'))
				return 'videos/$cleanKey.$VIDEO_EXT';
		}
		#end

		return gottenPath;
	}

	public static function shader(key:String):FunkinShader
	{
		return FunkinShader.fromFile(key);
	}
}

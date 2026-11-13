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
	public static final IMAGE_EXTS:Array<String> = ["png", "webp"];

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
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/system/freakyMenu.$SOUND_EXT',
		'assets/music/foreverMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'assets/music/system/breakfast.$SOUND_EXT',
		'assets/images/UI/cursor/cursor-default.png',
		'assets/images/UI/cursor/cursor-pointer.png',
		'assets/images/UI/cursor/cursor-grabbing.png',
		'assets/images/UI/cursor/cursor-cross.png',
		'assets/images/UI/cursor/cursor-scroll.png',
		'assets/images/UI/cursor/cursor-text.png',
		'assets/images/UI/cursor/cursor-eraser.png',
		'assets/images/UI/cursor/cursor-hourglass.png',
		'assets/images/menus/editors/cursor-default.png',
		'assets/images/menus/editors/cursor-pointer.png',
		'assets/images/menus/editors/cursor-grabbing.png',
		'assets/images/menus/editors/cursor-cross.png',
		'assets/images/menus/editors/cursor-scroll.png',
		'assets/images/menus/editors/cursor-text.png',
		'assets/images/menus/editors/cursor-eraser.png',
		'assets/images/menus/editors/cursor-hourglass.png'
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
		if (normalizedKey.endsWith('.webp'))
		{
			var pngEquivalent = normalizedKey.substr(0, normalizedKey.length - 5) + '.png';
			if (dumpExclusions.contains(pngEquivalent)) return true;
		}
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
		Utils.clearSkinAssetCache();
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
	 * Automatically falls back between .png and .webp for IMAGE assets.
	 */
	public static function getPath(file:String, type:AssetType, ?library:Null<String>):String
	{
		if (file == null) return "";

		var modDir:String = #if sys (core.scripting.Mods.currentModDirectory != null ? core.scripting.Mods.currentModDirectory : "") #else "" #end;
		var cacheKey:String = (library != null ? library : "") + "|" + modDir + "|" + file;

		if (tempPathsCache.exists(cacheKey))
			return tempPathsCache.get(cacheKey);

		var resolved:String = resolveSinglePath(file, type, library, modDir);
		#if sys
		var exists:Bool = (resolved != null && FileSystem.exists(resolved));
		#else
		var exists:Bool = (resolved != null && OpenFlAssets.exists(resolved, type));
		#end

		// If not found and this is an image, check alternate image extension (.png <-> .webp)
		if (!exists && type == IMAGE)
		{
			var altFile:String = null;
			if (file.endsWith('.png'))
				altFile = file.substr(0, file.length - 4) + '.webp';
			else if (file.endsWith('.webp'))
				altFile = file.substr(0, file.length - 5) + '.png';

			if (altFile != null)
			{
				var altResolved:String = resolveSinglePath(altFile, type, library, modDir);
				#if sys
				if (altResolved != null && FileSystem.exists(altResolved))
				{
					tempPathsCache.set(cacheKey, altResolved);
					return altResolved;
				}
				#else
				if (altResolved != null && OpenFlAssets.exists(altResolved, type))
				{
					tempPathsCache.set(cacheKey, altResolved);
					return altResolved;
				}
				#end
			}
		}

		tempPathsCache.set(cacheKey, resolved);
		return resolved;
	}

	private static function resolveSinglePath(file:String, type:AssetType, ?library:Null<String>, modDir:String = ""):String
	{
		if (library != null)
			return getLibraryPath(file, library);

		#if sys
		if (modDir.length > 0)
		{
			var modPath:String = 'mods/' + modDir + '/' + file;
			if (FileSystem.exists(modPath))
				return modPath;
		}

		var globalModPath:String = 'mods/' + file;
		if (FileSystem.exists(globalModPath))
			return globalModPath;

		for (m in core.scripting.Mods.getModDirectories())
		{
			if (m != modDir)
			{
				var otherModPath:String = 'mods/' + m + '/' + file;
				if (FileSystem.exists(otherModPath))
					return otherModPath;
			}
		}
		#end

		var levelPath:String = getLibraryPathForce(file, "mods");
		if (OpenFlAssets.exists(levelPath, type))
			return levelPath;

		return getPreloadPath(file);
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
		if (path == null) return "";
		var formatted:String = path.trim().toLowerCase();
		formatted = formatted.replace(' ', '-').replace('_', '-');
		while (formatted.indexOf('--') != -1)
			formatted = formatted.replace('--', '-');
		return formatted;
	}

	// =========================================================================
	// SECTION 5: IMAGE & GRAPHIC PIPELINE (CODENAME GPU-ONLY BITMAPS + WEBP)
	// =========================================================================

	/**
	 * Currently active stage name (defaults to 'stage'). Used by stageImage and sparrowImage when stage is omitted.
	 */
	public static var currentStage:String = "stage";

	/**
	 * Resolves an image path from a stage's images folder (e.g. `data/stages/<stage>/img/`),
	 * testing for .png and .webp variants across mod and asset directories.
	 */
	public static function getStageImagePath(cleanKey:String, ?stage:String, ?library:String, ?preferredExt:String):String
	{
		if (cleanKey == null || cleanKey.length == 0) return "";

		var stageName:String = (stage != null && stage.length > 0) ? stage : (currentStage != null && currentStage.length > 0 ? currentStage : "stage");

		var explicitExt:String = null;
		var key:String = cleanKey;
		if (key.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			key = key.substr(0, key.length - 5);
		}
		else if (key.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			key = key.substr(0, key.length - 4);
		}

		if (key.startsWith('img/'))
			key = key.substring(4);
		else if (key.startsWith('images/'))
			key = key.substring(7);

		var extensions:Array<String> = (explicitExt != null) 
			? [explicitExt] 
			: ((preferredExt != null && preferredExt.toLowerCase() == 'webp') ? ['webp', 'png'] : ['png', 'webp']);

		var candidatePrefixes:Array<String> = [
			'data/stages/$stageName/img/$key',
			'data/stages/$stageName/images/$key',
			'data/stages/$stageName/$key',
			'stages/$stageName/img/$key',
			'stages/$stageName/images/$key',
			'stages/$stageName/$key',
			'images/backgrounds/$stageName/$key',
			'images/backgrounds/$key',
			'images/$stageName/$key',
			'images/$key'
		];

		for (prefix in candidatePrefixes)
		{
			for (ext in extensions)
			{
				var candidate = getPath('$prefix.$ext', IMAGE, library);
				#if sys
				if (FileSystem.exists(candidate))
					return candidate;
				#end
				if (OpenFlAssets.exists(candidate, IMAGE) || OpenFlAssets.exists(candidate))
					return candidate;
			}
		}

		return getPath('data/stages/$stageName/img/$key.' + (explicitExt != null ? explicitExt : (preferredExt != null ? preferredExt : 'png')), IMAGE, library);
	}

	/**
	 * Checks whether a stage image asset exists (in either .png or .webp format).
	 */
	public static function stageImageExists(key:String, ?stage:String, ?library:String):Bool
	{
		if (key == null || key.length == 0) return false;
		var resolved = getStageImagePath(key, stage, library);
		#if sys
		if (FileSystem.exists(resolved)) return true;
		#end
		return OpenFlAssets.exists(resolved, IMAGE) || OpenFlAssets.exists(resolved);
	}

	/**
	 * Resolves an image path, testing for .png and .webp variants across mod and asset directories.
	 */
	public static function getImagePath(cleanKey:String, ?library:String, ?preferredExt:String):String
	{
		var extensions:Array<String> = (preferredExt != null && preferredExt.toLowerCase() == 'webp') ? ['webp', 'png'] : ['png', 'webp'];

		for (ext in extensions)
		{
			var candidate = getPath('images/$cleanKey.$ext', IMAGE, library);
			#if sys
			if (FileSystem.exists(candidate))
				return candidate;
			#end
			if (OpenFlAssets.exists(candidate, IMAGE) || OpenFlAssets.exists(candidate))
				return candidate;
		}

		return getPath('images/$cleanKey.' + (preferredExt != null ? preferredExt : 'png'), IMAGE, library);
	}

	/**
	 * Checks whether an image asset exists (in either .png or .webp format).
	 */
	public static function imageExists(key:String, ?library:String):Bool
	{
		if (key == null || key.length == 0) return false;
		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var resolved = getImagePath(cleanKey, library, explicitExt);
		#if sys
		if (FileSystem.exists(resolved)) return true;
		#end
		return OpenFlAssets.exists(resolved, IMAGE) || OpenFlAssets.exists(resolved);
	}

	/**
	 * Configures FlxAnimate asset hooks so texture atlases load .webp spritemaps and assets correctly.
	 */
	public static function initFlxAnimate():Void
	{
		try
		{
			animate.FlxAnimateAssets.getBitmapData = function(path:String):BitmapData
			{
				return loadBitmap(path);
			};
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Could not hook FlxAnimateAssets: ' + e);
		}
	}

	static function __init__():Void
	{
		initFlxAnimate();
	}

	/**
	 * Loads an OpenFL BitmapData from a file path or asset key, supporting both PNG and WebP formats.
	 */
	public static function loadBitmap(path:String):BitmapData
	{
		if (path == null || path.length == 0) return null;

		var targetPath:String = path;

		#if sys
		if (!FileSystem.exists(targetPath))
		{
			// Check if counterpart exists (.webp <-> .png)
			if (targetPath.toLowerCase().endsWith('.png'))
			{
				var alt = targetPath.substr(0, targetPath.length - 4) + '.webp';
				if (FileSystem.exists(alt)) targetPath = alt;
			}
			else if (targetPath.toLowerCase().endsWith('.webp'))
			{
				var alt = targetPath.substr(0, targetPath.length - 5) + '.png';
				if (FileSystem.exists(alt)) targetPath = alt;
			}
		}

		if (!FileSystem.exists(targetPath))
		{
			var cleanKey = path;
			if (cleanKey.toLowerCase().endsWith('.webp'))
				cleanKey = cleanKey.substr(0, cleanKey.length - 5);
			else if (cleanKey.toLowerCase().endsWith('.png'))
				cleanKey = cleanKey.substr(0, cleanKey.length - 4);
			if (cleanKey.startsWith('images/'))
				cleanKey = cleanKey.substring(7);
			var candidate = getImagePath(cleanKey);
			if (candidate != null && (FileSystem.exists(candidate) || OpenFlAssets.exists(candidate, IMAGE) || OpenFlAssets.exists(candidate)))
				targetPath = candidate;
		}
		#end

		if (WebPUtil.isWebP(targetPath))
			return WebPUtil.getBitmapData(targetPath);

		#if sys
		if (FileSystem.exists(targetPath))
		{
			try
			{
				return BitmapData.fromFile(targetPath);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load bitmap from file: $targetPath - $e');
			}
		}
		#end

		if (OpenFlAssets.exists(targetPath, IMAGE) || OpenFlAssets.exists(targetPath))
		{
			try
			{
				return OpenFlAssets.getBitmapData(targetPath, false);
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('Could not load bitmap from OpenFlAssets: $targetPath - $e');
			}
		}

		return null;
	}

	/**
	 * Loads a graphic with Codename Engine-style GPU texture streaming and memory offloading.
	 * Disposes CPU BitmapData RAM when GPU Caching is enabled.
	 */
	public static function image(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		return returnGraphic(key, library, textureCompression);
	}

	/**
	 * Loads a graphic from the stage's images folder (e.g. `data/stages/<stage>/img/`),
	 * with Codename Engine-style GPU texture streaming and memory offloading.
	 */
	public static function stageImage(key:String, ?stage:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		if (key == null || key.length == 0)
			return null;

		var stageName:String = (stage != null && stage.length > 0) ? stage : (currentStage != null && currentStage.length > 0 ? currentStage : "stage");
		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		if (cleanKey.startsWith('img/'))
			cleanKey = cleanKey.substring(4);
		else if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var path:String = getStageImagePath(cleanKey, stageName, library, explicitExt);
		return returnGraphicFromPath(path, textureCompression);
	}

	/**
	 * Core image loader. Handles two-layer caching, GPU texture uploads, and CPU RAM disposal.
	 * Seamlessly supports both .png and .webp graphics.
	 */
	public static function returnGraphic(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		if (key == null || key.length == 0)
			return null;

		// Normalize clean key & detect explicit extension
		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var path:String = getImagePath(cleanKey, library, explicitExt);
		return returnGraphicFromPath(path, textureCompression);
	}

	/**
	 * Core image loader from a resolved file path.
	 * Handles two-layer caching, Stage3D GPU texture uploads, CPU RAM disposal, and tracking.
	 */
	public static function returnGraphicFromPath(path:String, ?textureCompression:Null<Bool> = null):FlxGraphic
	{
		if (path == null || path.length == 0)
			return null;

		var useGpu:Bool = (textureCompression != null) ? textureCompression : gpuCaching;

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

		// 3. Load BitmapData from disk or OpenFL assets (PNG & WebP supported)
		var bitmap:BitmapData = loadBitmap(path);

		if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0)
		{
			FlxG.log.warn('Image asset not found: $path');
			return null;
		}

		// 4. Upload directly to GPU VRAM and discard CPU RAM (Codename Engine `gpuOnlyBitmaps`)
		var newGraphic:FlxGraphic = null;
		if (useGpu && FlxG.stage != null && FlxG.stage.context3D != null)
		{
			try
			{
				var texture:Texture = FlxG.stage.context3D.createTexture(bitmap.width, bitmap.height, BGRA, false, 0);
				texture.uploadFromBitmapData(bitmap);

				var gpuBitmap:BitmapData = BitmapData.fromTexture(texture);
				newGraphic = FlxGraphic.fromBitmapData(gpuBitmap, false, path, false);
				currentTrackedTextures.set(path, texture);

				// Immediately free heavy CPU pixel buffers from RAM and Lime/OpenFL caches
				@:privateAccess
				if (bitmap.image != null)
				{
					if (bitmap.image.buffer != null)
					{
						bitmap.image.buffer.data = null;
						bitmap.image.buffer = null;
					}
					bitmap.image = null;
				}
				bitmap.disposeImage();
				bitmap.dispose();

				#if lime
				if (LimeAssets.cache != null && LimeAssets.cache.image != null)
					LimeAssets.cache.image.remove(path);
				#end
				@:privateAccess
				if (OpenFlAssets.cache != null && OpenFlAssets.cache.hasBitmapData(path))
					OpenFlAssets.cache.removeBitmapData(path);
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
	 * Supports both PNG and WebP spritesheets.
	 */
	public static function getSparrowAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		else if (cleanKey.toLowerCase().endsWith('.xml'))
		{
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getImagePath(cleanKey, library, explicitExt);

		// 1. Layer 1 Atlas Cache Check
		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				// Ensure underlying FlxGraphic is also tracked/rescued
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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

		var graphic:FlxGraphic = returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
	 * Loads a Sparrow XML atlas from the stage's images folder (e.g. `data/stages/<stage>/img/`),
	 * with GPU texture support and two-layer frame caching.
	 * Exactly matches `getSparrowAtlas` functionality while pulling from the stage images directory.
	 */
	public static function sparrowImage(key:String, ?stage:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var stageName:String = (stage != null && stage.length > 0) ? stage : (currentStage != null && currentStage.length > 0 ? currentStage : "stage");

		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		else if (cleanKey.toLowerCase().endsWith('.xml'))
		{
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}

		if (cleanKey.startsWith('img/'))
			cleanKey = cleanKey.substring(4);
		else if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getStageImagePath(cleanKey, stageName, library, explicitExt);

		// 1. Layer 1 Atlas Cache Check
		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				returnGraphicFromPath(graphicPath, textureCompression);
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
				returnGraphicFromPath(graphicPath, textureCompression);
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

		var graphic:FlxGraphic = returnGraphicFromPath(graphicPath, textureCompression);
		if (graphic == null)
			return null;

		// 3. Find XML file in stage directory
		var xmlCandidates:Array<String> = [
			'data/stages/$stageName/img/$cleanKey.xml',
			'data/stages/$stageName/images/$cleanKey.xml',
			'data/stages/$stageName/$cleanKey.xml',
			'stages/$stageName/img/$cleanKey.xml',
			'stages/$stageName/images/$cleanKey.xml',
			'stages/$stageName/$cleanKey.xml',
			'images/backgrounds/$stageName/$cleanKey.xml',
			'images/backgrounds/$cleanKey.xml',
			'images/$stageName/$cleanKey.xml',
			'images/$cleanKey.xml'
		];

		var xmlContent:String = null;
		for (candidate in xmlCandidates)
		{
			var p = getPath(candidate, TEXT, library);
			#if sys
			if (FileSystem.exists(p))
			{
				xmlContent = File.getContent(p);
				break;
			}
			#end
			if (OpenFlAssets.exists(p, TEXT))
			{
				xmlContent = OpenFlAssets.getText(p);
				break;
			}
		}

		if (xmlContent == null)
		{
			FlxG.log.warn('Sparrow XML description not found for stage image: $cleanKey (stage: $stageName)');
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
	 * Supports both PNG and WebP spritesheets.
	 */
	public static function getPackerAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		else if (cleanKey.toLowerCase().endsWith('.txt'))
		{
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getImagePath(cleanKey, library, explicitExt);

		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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

		var graphic:FlxGraphic = returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
	 * Supports both PNG and WebP spritesheets.
	 */
	public static function getAsepriteAtlas(key:String, ?library:String, ?textureCompression:Null<Bool> = null):FlxAtlasFrames
	{
		if (key == null || key.length == 0)
			return null;

		var cleanKey:String = key;
		var explicitExt:String = null;
		if (cleanKey.toLowerCase().endsWith('.webp'))
		{
			explicitExt = 'webp';
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		else if (cleanKey.toLowerCase().endsWith('.png'))
		{
			explicitExt = 'png';
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);
		}
		else if (cleanKey.toLowerCase().endsWith('.json'))
		{
			cleanKey = cleanKey.substr(0, cleanKey.length - 5);
		}
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);

		var graphicPath:String = getImagePath(cleanKey, library, explicitExt);

		if (currentTrackedAtlases.exists(graphicPath))
		{
			var cached:FlxAtlasFrames = currentTrackedAtlases.get(graphicPath);
			if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed)
			{
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
				returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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

		var graphic:FlxGraphic = returnGraphic(cleanKey + (explicitExt != null ? '.$explicitExt' : ''), library, textureCompression);
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
	 * Resolves spaces, dashes, and underscores interchangeably for cross-engine compatibility.
	 */
	public static function songAudioExists(song:String, fileName:String):Bool
	{
		var folderVariants:Array<String> = CoolUtil.getSongNameVariants(song);
		if (folderVariants.length == 0)
			folderVariants.push(formatToSongPath(song));

		#if sys
		var curMod = core.scripting.Mods.currentModDirectory;
		var modDirs:Array<String> = [];
		if (curMod != null && curMod.length > 0)
			modDirs.push(curMod);

		for (m in core.scripting.Mods.getModDirectories())
		{
			if (!modDirs.contains(m))
				modDirs.push(m);
		}

		for (f in folderVariants)
		{
			var direct:String = 'songs/$f/$fileName.$SOUND_EXT';
			var audio:String = 'songs/$f/audio/$fileName.$SOUND_EXT';

			for (m in modDirs)
			{
				if (FileSystem.exists('mods/$m/$direct') || FileSystem.exists('mods/$m/$audio'))
					return true;
			}
			if (FileSystem.exists('mods/$direct') || FileSystem.exists('mods/$audio'))
				return true;
			if (FileSystem.exists('assets/$direct') || FileSystem.exists('assets/$audio'))
				return true;
		}
		#end

		for (f in folderVariants)
		{
			var direct:String = 'songs/$f/$fileName.$SOUND_EXT';
			var audio:String = 'songs/$f/audio/$fileName.$SOUND_EXT';

			var levelDirect = getLibraryPathForce(direct, "mods");
			var levelAudio = getLibraryPathForce(audio, "mods");
			if (OpenFlAssets.exists(levelDirect, SOUND) || OpenFlAssets.exists(levelAudio, SOUND))
				return true;

			var preDirect = getPreloadPath(direct);
			var preAudio = getPreloadPath(audio);
			if (OpenFlAssets.exists(preDirect, SOUND) || OpenFlAssets.exists(preAudio, SOUND))
				return true;
		}

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
	 * Resolves spaces, dashes, and underscores interchangeably for cross-engine compatibility.
	 */
	private static function songAudioKey(song:String, fileName:String):String
	{
		var folderVariants:Array<String> = CoolUtil.getSongNameVariants(song);
		if (folderVariants.length == 0)
			folderVariants.push(formatToSongPath(song));

		#if sys
		var curMod = core.scripting.Mods.currentModDirectory;
		var modDirs:Array<String> = [];
		if (curMod != null && curMod.length > 0)
			modDirs.push(curMod);

		for (m in core.scripting.Mods.getModDirectories())
		{
			if (!modDirs.contains(m))
				modDirs.push(m);
		}

		// 1. Direct song path: songs/$f/$fileName.ogg
		for (f in folderVariants)
		{
			var checkDirect:String = 'songs/$f/$fileName.$SOUND_EXT';
			for (m in modDirs)
			{
				if (FileSystem.exists('mods/$m/$checkDirect'))
				{
					if (core.scripting.Mods.currentModDirectory != m)
						core.scripting.Mods.currentModDirectory = m;
					return '$f/$fileName';
				}
			}
			if (FileSystem.exists('mods/$checkDirect'))
				return '$f/$fileName';
			if (FileSystem.exists('assets/$checkDirect'))
				return '$f/$fileName';
		}

		// 2. Subfolder path: songs/$f/audio/$fileName.ogg
		for (f in folderVariants)
		{
			var checkAudio:String = 'songs/$f/audio/$fileName.$SOUND_EXT';
			for (m in modDirs)
			{
				if (FileSystem.exists('mods/$m/$checkAudio'))
				{
					if (core.scripting.Mods.currentModDirectory != m)
						core.scripting.Mods.currentModDirectory = m;
					return '$f/audio/$fileName';
				}
			}
			if (FileSystem.exists('mods/$checkAudio'))
				return '$f/audio/$fileName';
			if (FileSystem.exists('assets/$checkAudio'))
				return '$f/audio/$fileName';
		}
		#end

		// Default fallback
		return '${folderVariants[0]}/audio/$fileName';
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

		var candidates:Array<String> = [];
		if (cleanKey.startsWith('system/'))
		{
			var withoutSystem = cleanKey.substring(7);
			candidates.push('$path/$withoutSystem.$SOUND_EXT');
			candidates.push('$path/$cleanKey.$SOUND_EXT');
		}
		else
		{
			candidates.push('$path/$cleanKey.$SOUND_EXT');
			candidates.push('$path/system/$cleanKey.$SOUND_EXT');
		}

		if (!cleanKey.contains('/'))
		{
			candidates.push('$path/gameover/$cleanKey.$SOUND_EXT');
			candidates.push('$path/system/gameover/$cleanKey.$SOUND_EXT');
			candidates.push('$path/countdown/default/$cleanKey.$SOUND_EXT');
			candidates.push('$path/system/countdown/default/$cleanKey.$SOUND_EXT');
		}

		var gottenPath:String = null;
		for (c in candidates)
		{
			var p = getPath(c, SOUND, library);
			var colonIndex:Int = p.indexOf(':');
			#if sys
			if (colonIndex > 1 && !FileSystem.exists(p))
			{
				var stripped:String = p.substring(colonIndex + 1);
				if (FileSystem.exists(stripped))
					p = stripped;
			}
			if (FileSystem.exists(p))
			{
				gottenPath = p;
				break;
			}
			#else
			if (colonIndex > 1)
				p = p.substring(colonIndex + 1);
			if (OpenFlAssets.exists(p, SOUND))
			{
				gottenPath = p;
				break;
			}
			#end
		}

		if (gottenPath == null)
		{
			gottenPath = getPath(candidates[0], SOUND, library);
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
				gottenPath = gottenPath.substring(colonIndex + 1);
			#end
		}

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

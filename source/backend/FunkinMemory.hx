package backend;

using StringTools;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.utils.AssetType;
import openfl.Assets;
import openfl.system.System;
import openfl.media.Sound;

/**
 * Handles caching of textures and sounds for the game.
 * Adapted from V-Slice (FunkinMemory) for GAZE BUILD Engine.
 */
class FunkinMemory
{
	public static var permanentCachedTextures:Map<String, FlxGraphic> = [];
	public static var currentCachedTextures:Map<String, FlxGraphic> = [];
	public static var previousCachedTextures:Map<String, FlxGraphic> = [];
	public static var permanentCachedSounds:Map<String, Sound> = [];
	public static var currentCachedSounds:Map<String, Sound> = [];
	public static var previousCachedSounds:Map<String, Sound> = [];
	public static var purgeFilter:Array<String> = [];

	/**
	 * Caches textures that are always required.
	 */
	public static function initialCache():Void
	{
		var allImages:Array<String> = Assets.list(AssetType.IMAGE);

		for (file in allImages)
		{
			if (file.contains('shared'))
			{
				permanentCacheTexture(file);
			}
		}

		var allSounds:Array<String> = Assets.list(AssetType.SOUND);

		for (file in allSounds)
		{
			if (file.contains('shared'))
			{
				permanentCacheSound(file);
			}
		}
	}

	/**
	 * Clears the current texture and sound caches.
	 */
	public static function purgeCache(callGarbageCollector:Bool = false):Void
	{
		trace('CLEARING CACHE: Disposing all cached textures, assets and sounds...');

		preparePurgeTextureCache();
		purgeTextureCache();
		preparePurgeSoundCache();
		purgeSoundCache();
		
		#if (cpp || neko || hl)
		if (callGarbageCollector) openfl.system.System.gc();
		#end
	}

	///// TEXTURES /////

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

		if (currentCachedTextures.exists(strKey)) return;

		if (previousCachedTextures.exists(strKey))
		{
			var graphic:Null<FlxGraphic> = previousCachedTextures.get(strKey);
			previousCachedTextures.remove(strKey);
			if (graphic != null) currentCachedTextures.set(strKey, graphic);
			return;
		}

		var graphic:Null<FlxGraphic> = preGraphic != null ? preGraphic : FlxGraphic.fromAssetKey(strKey, false, null, true);
		if (graphic == null)
		{
			FlxG.log.warn('Failed to cache graphic: $strKey');
			return;
		}

		trace('Cached asset $strKey');
		graphic.persist = true;
		currentCachedTextures.set(strKey, graphic);
		forceRender(graphic);
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

		if (permanentCachedTextures.exists(strKey)) return;

		var graphic:Null<FlxGraphic> = preGraphic != null ? preGraphic : FlxGraphic.fromAssetKey(strKey, false, null, true);
		if (graphic == null)
		{
			FlxG.log.warn('Failed to cache graphic: $strKey');
			return;
		}

		trace('Cached graphic $strKey');
		graphic.persist = true;
		permanentCachedTextures.set(strKey, graphic);
		forceRender(graphic);
		currentCachedTextures = permanentCachedTextures.copy();
	}

	public static function getCachedGraphic(path:String):Null<FlxGraphic>
	{
		if (permanentCachedTextures.exists(path)) return permanentCachedTextures.get(path);
		if (currentCachedTextures.exists(path)) return currentCachedTextures.get(path);
		if (previousCachedTextures.exists(path)) return previousCachedTextures.get(path);

		return null;
	}

	public static function preparePurgeTextureCache():Void
	{
		previousCachedTextures = currentCachedTextures.copy();

		for (graphicKey in previousCachedTextures.keys())
		{
			if (permanentCachedTextures.exists(graphicKey))
			{
				previousCachedTextures.remove(graphicKey);
			}
		}

		currentCachedTextures = permanentCachedTextures.copy();
	}

	public static function purgeTextureCache():Void
	{
		for (graphicKey in previousCachedTextures.keys())
		{
			if (permanentCachedTextures.exists(graphicKey))
			{
				previousCachedTextures.remove(graphicKey);
				continue;
			}

			if (graphicKey.contains('fonts')) continue;

			var graphic:Null<FlxGraphic> = previousCachedTextures.get(graphicKey);
			if (graphic != null)
			{
				FlxG.bitmap.remove(graphic);
				graphic.persist = false;
				graphic.destroy();
				previousCachedTextures.remove(graphicKey);
				Assets.cache.clear(graphicKey);
			}
		}
		
		@:privateAccess
		if (FlxG.bitmap._cache == null)
		{
			@:privateAccess
			FlxG.bitmap._cache = new Map();
		}

		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj:Null<FlxGraphic> = FlxG.bitmap.get(key);

			if (obj == null || (obj.persist && permanentCachedTextures.exists(key)) || key.contains('fonts'))
			{
				continue;
			}

			if (obj.useCount > 0)
			{
				for (purgeEntry in purgeFilter)
				{
					if (key.contains(purgeEntry))
					{
						FlxG.bitmap.removeKey(key);
						obj.persist = false;
						obj.destroy();
					}
				}
			}
		}
	}

	static function forceRender(graphic:FlxGraphic):Void
	{
		if (graphic == null) return;

		var bmp:Null<FlxGraphic> = FlxG.bitmap.get(graphic.key);
		if (bmp != null && bmp.bitmap != null) var _:Int = bmp.bitmap.width; // Trigger

		// Draws sprite and actually caches it.
		var sprite = new flixel.FlxSprite();
		sprite.loadGraphic(graphic);
		sprite.draw(); // Draw sprite and load it into game's memory.
		if (graphic.bitmap != null) graphic.bitmap.getTexture(FlxG.stage.context3D); // Just in case that didn't work...
		sprite.destroy();
	}

	public static function isTextureCached(key:String):Bool
	{
		return FlxG.bitmap.get(key) != null
			&& (permanentCachedTextures.exists(key) || currentCachedTextures.exists(key) || previousCachedTextures.exists(key));
	}

	///// SOUND //////

	public static function cacheSound(key:Dynamic):Void
	{
		var strKey:String = "";
		var preSound:Sound = null;

		if (key is Sound)
		{
			preSound = cast(key, Sound);
			// Since sound doesn't have a unique key, we can use an internal ID or just skip if we don't know the key.
			// Actually, if they pass a Sound, we can't reliably map it to a string key in currentCachedSounds easily.
			// Let's use an arbitrary name or just store the class name. For now, let's just generate a key if needed.
			strKey = "sound_" + Std.string(Reflect.field(preSound, "id") != null ? Reflect.field(preSound, "id") : Std.random(999999));
		}
		else
		{
			strKey = Std.string(key);
		}

		if (currentCachedSounds.exists(strKey)) return;

		if (previousCachedSounds.exists(strKey))
		{
			var sound:Null<Sound> = previousCachedSounds.get(strKey);
			previousCachedSounds.remove(strKey);
			if (sound != null) currentCachedSounds.set(strKey, sound);
			return;
		}

		var sound:Null<Sound> = preSound != null ? preSound : Assets.getSound(strKey, true);
		if (sound != null)
		{
			currentCachedSounds.set(strKey, sound);
		}
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

		if (permanentCachedSounds.exists(strKey)) return;

		var sound:Null<Sound> = preSound != null ? preSound : Assets.getSound(strKey, true);
		if (sound != null)
		{
			permanentCachedSounds.set(strKey, sound);
			currentCachedSounds.set(strKey, sound);
		}
	}

	public static function preparePurgeSoundCache():Void
	{
		previousCachedSounds = currentCachedSounds.copy();

		for (key in previousCachedSounds.keys())
		{
			if (permanentCachedSounds.exists(key))
			{
				previousCachedSounds.remove(key);
			}
		}

		currentCachedSounds = permanentCachedSounds.copy();
	}

	public static function purgeSoundCache():Void
	{
		for (key in previousCachedSounds.keys())
		{
			if (permanentCachedSounds.exists(key))
			{
				previousCachedSounds.remove(key);
				continue;
			}

			var sound:Null<Sound> = previousCachedSounds.get(key);
			if (sound != null)
			{
				Assets.cache.removeSound(key);
				previousCachedSounds.remove(key);
			}
		}
		Assets.cache.clear('songs');
		Assets.cache.clear('music');
	}

}

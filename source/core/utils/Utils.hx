package core.utils;

import flixel.FlxG;
import flixel.sound.FlxSound;
import sys.FileSystem;

/**
 * Utility functions used globally across the engine.
 */
class Utils
{
	/**
	 * Resets and plays the main menu music if it's not currently playing.
	 */
	public static function resetMenuMusic()
	{
		// Make sure the music is playing
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"));
	}

	public static var skinAssetCache:Map<String, String> = new Map<String, String>();

	public static inline function clearSkinAssetCache():Void
	{
		skinAssetCache.clear();
	}

	/**
	 * Resolves a skin asset path based on modifiers and libraries.
	 * Checks multiple path combinations and returns the first existing one.
	 * Results are cached in memory to eliminate synchronous disk I/O on note hits.
	 */
	public static function returnSkinAsset(asset:String, assetModifier:String = 'base', changeableSkin:String = 'default', baseLibrary:String,
			?defaultChangeableSkin:String = 'default', ?defaultBaseAsset:String = 'base'):String
	{
		var cacheKey:String = '$baseLibrary|$changeableSkin|$assetModifier|$asset|$defaultChangeableSkin|$defaultBaseAsset';
		if (skinAssetCache.exists(cacheKey))
			return skinAssetCache.get(cacheKey);

		var possiblePaths:Array<String> = [
			'$baseLibrary/$changeableSkin/$assetModifier/$asset',
			'$baseLibrary/$assetModifier/$asset',
			'$baseLibrary/$changeableSkin/$asset',
			'$baseLibrary/$defaultChangeableSkin/$assetModifier/$asset',
			'$baseLibrary/$defaultChangeableSkin/$asset',
			'$baseLibrary/$defaultBaseAsset/$asset',
			'$baseLibrary/$asset',
			asset
		];

		for (path in possiblePaths)
		{
			if (sys.FileSystem.exists(Paths.getPath('images/' + path + '.png', IMAGE)))
			{
				skinAssetCache.set(cacheKey, path);
				return path;
			}
		}

		// Fallback to the most specific path if none exist (might cause an error downstream if truly missing)
		var fallback:String = '$baseLibrary/$changeableSkin/$assetModifier/$asset';
		skinAssetCache.set(cacheKey, fallback);
		return fallback;
	}

	/**
	 * Stops and destroys an array of sound objects, safely freeing up memory.
	 */
	public static function killMusic(songsArray:Array<FlxSound>)
	{
		for (song in songsArray)
		{
			if (song != null)
			{
				if (FlxG.sound != null && FlxG.sound.list != null)
					FlxG.sound.list.remove(song, true);
				song.stop();
				song.destroy();
			}
		}
	}
}

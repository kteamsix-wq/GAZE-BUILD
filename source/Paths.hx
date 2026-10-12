package;

import haxe.Json;
import sys.Http;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import sys.FileSystem;
import sys.io.File;

import backend.CoolUtil;
import Main.CrashContent;
import backend.FunkinShader;

/**
 * Handles asset loading, path resolution, and memory management for the engine.
 */
class Paths
{
	inline public static var SOUND_EXT = "ogg";

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedTextures:Map<String, Texture> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static var currentTrackedAtlases:Map<String, FlxAtlasFrames> = [];
	public static var localTrackedAssets:Array<String> = [];

	public static var dumpExclusions:Array<String> = [
		'assets/music/system/freakyMenu.$SOUND_EXT',
		'assets/music/foreverMenu.$SOUND_EXT',
		'assets/music/system/breakfast.$SOUND_EXT'
	];

	static var pathError:Http = new Http("");
	static var msgJson:CrashContent;

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	private static function isFrameworkAsset(key:String):Bool
	{
		if (key == null) return true;
		var normalizedKey:String = key.toLowerCase();
		return normalizedKey.indexOf('flixel/') == 0 || normalizedKey.indexOf('/flixel/') != -1;
	}

	/**
	 * Clears memory occupied by assets that are no longer locally tracked.
	 */
	public static function clearUnusedMemory()
	{
		var counter:Int = 0;
		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && !isFrameworkAsset(key))
			{
				var obj = currentTrackedAssets.get(key);
				if (obj != null)
				{
					if (currentTrackedTextures.exists(key))
					{
						var texture = currentTrackedTextures.get(key);
						texture.dispose();
						currentTrackedTextures.remove(key);
					}
					
					@:privateAccess
					if (openfl.Assets.cache.hasBitmapData(key))
					{
						openfl.Assets.cache.removeBitmapData(key);
						FlxG.bitmap._cache.remove(key);
					}
					
					obj.destroy();
					currentTrackedAssets.remove(key);
					counter++;
				}
			}
		}
		for (key in currentTrackedAtlases.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && !isFrameworkAsset(key))
			{
				var atlas = currentTrackedAtlases.get(key);
				if (atlas != null)
				{
					atlas.destroy();
					currentTrackedAtlases.remove(key);
				}
			}
		}

		System.gc(); // Force garbage collection
	}

	/**
	 * Aggressively clears stored memory (e.g., between states).
	 */
	public static function clearStoredMemory(?cleanUnused:Bool = false)
	{
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key) && !isFrameworkAsset(key))
			{
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				OpenFlAssets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		for (key in currentTrackedAtlases.keys())
		{
			var atlas = currentTrackedAtlases.get(key);
			if (atlas != null) atlas.destroy();
			currentTrackedAtlases.remove(key);
		}
		
		localTrackedAssets = [];
	}

	public static function returnGraphic(key:String, ?library:String, ?textureCompression:Bool = false):FlxGraphic
	{
		var path = getPath('images/$key.png', IMAGE, library);
		if (FileSystem.exists(path))
		{
			var trackedGraphic:FlxGraphic = currentTrackedAssets.get(key);
			if (trackedGraphic == null || trackedGraphic.isDestroyed)
			{
				if (trackedGraphic != null)
					currentTrackedAssets.remove(key);

				var bitmap = BitmapData.fromFile(path);
				var newGraphic:FlxGraphic;
				
				if (textureCompression)
				{
					var texture = FlxG.stage.context3D.createTexture(bitmap.width, bitmap.height, BGRA, true, 0);
					texture.uploadFromBitmapData(bitmap);
					currentTrackedTextures.set(key, texture);
					
					bitmap.dispose();
					bitmap.disposeImage();
					
					newGraphic = FlxGraphic.fromBitmapData(BitmapData.fromTexture(texture), false, key, false);
				}
				else
				{
					newGraphic = FlxGraphic.fromBitmapData(bitmap, false, key, false);
				}
				
				currentTrackedAssets.set(key, newGraphic);
			}
			if (!localTrackedAssets.contains(key))
				localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return null;
	}

	public static function returnSound(path:String, key:String, ?library:String):Sound
	{
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		
		if (!currentTrackedSounds.exists(gottenPath))
			currentTrackedSounds.set(gottenPath, Sound.fromFile(gottenPath));
			
		if (!localTrackedAssets.contains(key))
			localTrackedAssets.push(key);
		return currentTrackedSounds.get(gottenPath);
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String>):String
	{
		if (library != null)
			return getLibraryPath(file, library);

		#if sys
		if (backend.Mods.currentModDirectory != null && backend.Mods.currentModDirectory.length > 0)
		{
			var modPath:String = 'mods/' + backend.Mods.currentModDirectory + '/' + file;
			if (FileSystem.exists(modPath))
				return modPath;
		}

		var globalModPath:String = 'mods/' + file;
		if (FileSystem.exists(globalModPath))
			return globalModPath;
		#end

		var levelPath = getLibraryPathForce(file, "mods");
		if (OpenFlAssets.exists(levelPath, type))
			return levelPath;

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload"):String
	{
		return (library == "preload" || library == "default") ? getPreloadPath(file) : getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String):String
	{
		return '$library/$file';
	}

	inline static function getPreloadPath(file:String):String
	{
		var returnPath:String = 'assets/$file';
		if (!FileSystem.exists(returnPath))
		{
			msgJson = { content: "```hx\nPATH NOT FOUND: " + returnPath + "\n```" };
			pathError.setHeader("Content-Type", "application/json");
			pathError.setPostData(Json.stringify(msgJson));
			pathError.request(true);
			returnPath = CoolUtil.swapSpaceDash(returnPath);
		}
		return returnPath;
	}

	static public function file(file:String, type:AssetType = TEXT, ?library:String):String
	{
		return getPath(file, type, library);
	}

	static public function txt(key:String, ?library:String):String
	{
		return getPath('$key.txt', TEXT, library);
	}

	static public function xml(key:String, ?library:String):String
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	static public function offsetTxt(key:String, ?library:String):String
	{
		return getPath('images/characters/$key.txt', TEXT, library);
	}

	static public function json(key:String, ?library:String):String
	{
		return getPath('songs/$key.json', TEXT, library);
	}

	static public function songJson(song:String, secondSong:String, ?library:String):String
	{
		return getPath('songs/${song.toLowerCase()}/${secondSong.toLowerCase()}.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String):Sound
	{
		return returnSound('sounds', key, library);
	}

	static public function soundRandom(key:String, min:Int, max:Int, ?library:String):Sound
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	static public function music(key:String, ?library:String):Sound
	{
		return returnSound('music', key, library);
	}

	static public function voices(song:String):Sound
	{
		return returnSound('songs', songAudioKey(song, 'Voices'));
	}

	static public function inst(song:String):Sound
	{
		return returnSound('songs', songAudioKey(song, 'Inst'));
	}

	private static function songAudioKey(song:String, fileName:String):String
	{
		var folder:String = CoolUtil.swapSpaceDash(song.toLowerCase());
		var directPath:String = 'assets/songs/$folder/$fileName.$SOUND_EXT';
		if (FileSystem.exists(directPath))
			return '$folder/$fileName';

		return '$folder/audio/$fileName';
	}

	static public function image(key:String, ?library:String, ?textureCompression:Bool = true):FlxGraphic
	{
		return returnGraphic(key, library, textureCompression);
	}

	static public function font(key:String):String
	{
		return 'assets/data/fonts/$key';
	}

	static public function getSparrowAtlas(key:String, ?library:String, ?textureCompression:Bool = true):FlxAtlasFrames
	{
		if (currentTrackedAtlases.exists(key) && currentTrackedAtlases.get(key) != null)
			return currentTrackedAtlases.get(key);

		var graphic:FlxGraphic = returnGraphic(key, library, textureCompression);
		if (graphic == null) return null;

		var xmlPath = file('images/$key.xml', library);
		if (!FileSystem.exists(xmlPath)) return null;

		var frames = FlxAtlasFrames.fromSparrow(graphic, File.getContent(xmlPath));
		if (frames != null)
			currentTrackedAtlases.set(key, frames);

		return frames;
	}

	static public function getPackerAtlas(key:String, ?library:String, ?textureCompression:Bool = true):FlxAtlasFrames
	{
		if (currentTrackedAtlases.exists(key) && currentTrackedAtlases.get(key) != null)
			return currentTrackedAtlases.get(key);

		var graphic:FlxGraphic = image(key, library, textureCompression);
		if (graphic == null) return null;

		var txtPath = file('images/$key.txt', library);
		if (!FileSystem.exists(txtPath)) return null;

		var frames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, File.getContent(txtPath));
		if (frames != null)
			currentTrackedAtlases.set(key, frames);

		return frames;
	}

	static public function shader(key:String):FunkinShader
	{
		return FunkinShader.fromFile(key);
	}
}

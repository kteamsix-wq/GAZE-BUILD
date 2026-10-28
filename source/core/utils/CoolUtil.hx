package core.utils;
import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;
import core.system.Assets;
import gameplay.PlayState;
import flixel.FlxSprite;
import flixel.math.FlxRect;

using StringTools;

#if sys
import sys.FileSystem;
#end

class CoolUtil
{
	public static var difficultyArray:Array<String> = ['EASY', "NORMAL", "HARD"];
	public static var difficultyLength = difficultyArray.length;

	public static function difficultyFromNumber(number:Int):String
	{
		return difficultyArray[number];
	}

	public static function dashToSpace(string:String):String
	{
		return string.replace("-", " ");
	}

	public static function spaceToDash(string:String):String
	{
		return string.replace(" ", "-");
	}

	public static function swapSpaceDash(string:String):String
	{
		return StringTools.contains(string, '-') ? dashToSpace(string) : spaceToDash(string);
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var daList:Array<String> = openfl.utils.Assets.getText(path).trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function getOffsetsFromTxt(path:String):Array<Array<String>>
	{
		var fullText:String = openfl.utils.Assets.getText(path);

		var firstArray:Array<String> = fullText.split('\n');
		var swagOffsets:Array<Array<String>> = [];

		for (i in firstArray)
			swagOffsets.push(i.split(' '));

		return swagOffsets;
	}

	public static function returnAssetsLibrary(library:String, ?subDir:String = 'assets/images'):Array<String>
	{
		var libraryArray:Array<String> = [];

		#if sys
		var targetPath = '$subDir/$library';
		var unfilteredLibrary = sys.FileSystem.exists(targetPath) ? sys.FileSystem.readDirectory(targetPath) : [];

		for (folder in unfilteredLibrary)
		{
			if (!folder.contains('.'))
				libraryArray.push(folder);
		}
		//trace(libraryArray);
		#end

		if (libraryArray.length == 0) libraryArray.push('default');
		return libraryArray;
	}

	public static function getAnimsFromTxt(path:String):Array<Array<String>>
	{
		var fullText:String = openfl.utils.Assets.getText(path);

		var firstArray:Array<String> = fullText.split('\n');
		var swagOffsets:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagOffsets.push(i.split('--'));
		}

		return swagOffsets;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	public static function getCharacterList():Array<String>
	{
		var charArray:Array<String> = [];
		var charMap:Map<String, Bool> = new Map();

		#if sys
		var directories:Array<String> = ['assets/data/char'];
		if (core.scripting.Mods.currentModDirectory != null) {
			directories.push('mods/' + core.scripting.Mods.currentModDirectory + '/data/char');
		}

		for (path in directories) {
			if (sys.FileSystem.exists(path)) {
				for (file in sys.FileSystem.readDirectory(path)) {
					if (file.endsWith('.json')) {
						var name = file.substring(0, file.length - 5);
						if (!charMap.exists(name)) {
							charMap.set(name, true);
							charArray.push(name);
						}
					}
				}
			}
		}
		#end
		
		if (charArray.length == 0) charArray = ['bf', 'dad', 'gf'];
		return charArray;
	}

	public static function getStageList():Array<String>
	{
		var stageArray:Array<String> = [];
		var stageMap:Map<String, Bool> = new Map();

		#if sys
		var directories:Array<String> = ['assets/data/stages'];
		if (core.scripting.Mods.currentModDirectory != null && core.scripting.Mods.currentModDirectory.length > 0) {
			directories.push('mods/' + core.scripting.Mods.currentModDirectory + '/data/stages');
		}

		for (path in directories) {
			if (sys.FileSystem.exists(path)) {
				for (file in sys.FileSystem.readDirectory(path)) {
					if (file.endsWith('.json') || file.endsWith('.hx')) {
						var dotIdx = file.lastIndexOf('.');
						var name = file.substring(0, dotIdx);
						if (!stageMap.exists(name)) {
							stageMap.set(name, true);
							stageArray.push(name);
						}
					}
				}
			}
		}
		#end

		if (stageArray.length == 0) stageArray = ['stage'];
		return stageArray;
	}

	public static function getEaseFromString(ease:Null<String>):flixel.tweens.FlxEase.EaseFunction
	{
		if (ease == null) return flixel.tweens.FlxEase.linear;
		return switch (ease.toLowerCase().trim())
		{
			case 'backin': flixel.tweens.FlxEase.backIn;
			case 'backinout': flixel.tweens.FlxEase.backInOut;
			case 'backout': flixel.tweens.FlxEase.backOut;
			case 'bouncein': flixel.tweens.FlxEase.bounceIn;
			case 'bounceinout': flixel.tweens.FlxEase.bounceInOut;
			case 'bounceout': flixel.tweens.FlxEase.bounceOut;
			case 'circin': flixel.tweens.FlxEase.circIn;
			case 'circinout': flixel.tweens.FlxEase.circInOut;
			case 'circout': flixel.tweens.FlxEase.circOut;
			case 'cubein': flixel.tweens.FlxEase.cubeIn;
			case 'cubeinout': flixel.tweens.FlxEase.cubeInOut;
			case 'cubeout': flixel.tweens.FlxEase.cubeOut;
			case 'elasticin': flixel.tweens.FlxEase.elasticIn;
			case 'elasticinout': flixel.tweens.FlxEase.elasticInOut;
			case 'elasticout': flixel.tweens.FlxEase.elasticOut;
			case 'expoin': flixel.tweens.FlxEase.expoIn;
			case 'expoinout': flixel.tweens.FlxEase.expoInOut;
			case 'expoout': flixel.tweens.FlxEase.expoOut;
			case 'quadin': flixel.tweens.FlxEase.quadIn;
			case 'quadinout': flixel.tweens.FlxEase.quadInOut;
			case 'quadout': flixel.tweens.FlxEase.quadOut;
			case 'quartin': flixel.tweens.FlxEase.quartIn;
			case 'quartinout': flixel.tweens.FlxEase.quartInOut;
			case 'quartout': flixel.tweens.FlxEase.quartOut;
			case 'quintin': flixel.tweens.FlxEase.quintIn;
			case 'quintinout': flixel.tweens.FlxEase.quintInOut;
			case 'quintout': flixel.tweens.FlxEase.quintOut;
			case 'sinein': flixel.tweens.FlxEase.sineIn;
			case 'sineinout': flixel.tweens.FlxEase.sineInOut;
			case 'sineout': flixel.tweens.FlxEase.sineOut;
			case 'smoothstepin': flixel.tweens.FlxEase.smoothStepIn;
			case 'smoothstepinout': flixel.tweens.FlxEase.smoothStepInOut;
			case 'smoothstepout': flixel.tweens.FlxEase.smoothStepOut;
			case 'smootherstepin': flixel.tweens.FlxEase.smootherStepIn;
			case 'smootherstepinout': flixel.tweens.FlxEase.smootherStepInOut;
			case 'smootherstepout': flixel.tweens.FlxEase.smootherStepOut;
			default: flixel.tweens.FlxEase.linear;
		}
	}

	/**
	 * Detects the inner transparent area ("campo invisível" / cutout slot) inside a health bar frame sprite.
	 * Returns an FlxRect with (x, y, width, height) relative to the sprite, or null if no inner hole is found.
	 */
	public static function detectHealthBarBounds(sprite:FlxSprite, alphaThreshold:Int = 50):FlxRect
	{
		if (sprite == null || sprite.graphic == null)
			return null;

		var bmp:openfl.display.BitmapData = null;
		var tempBmp:openfl.display.BitmapData = null;

		var rawBmp = sprite.graphic.bitmap;
		var hasCpuPixels:Bool = false;

		// Check if the current BitmapData has readable CPU pixels
		if (rawBmp != null && rawBmp.readable && rawBmp.image != null && rawBmp.image.data != null)
		{
			for (testY in 0...Std.int(Math.min(20, rawBmp.height)))
			{
				for (testX in 0...Std.int(Math.min(rawBmp.width, 40)))
				{
					if (((rawBmp.getPixel32(testX, testY) >>> 24) & 0xFF) > 0)
					{
						hasCpuPixels = true;
						break;
					}
				}
				if (hasCpuPixels) break;
			}
		}

		if (hasCpuPixels)
		{
			bmp = rawBmp;
		}
		else
		{
			// When GPU texture streaming is active, CPU bitmap was disposed.
			// Load an uncompressed copy directly from file or OpenFL assets to inspect the pixels.
			var path:String = sprite.graphic.assetsKey;
			if (path == null || path.length == 0)
				path = sprite.graphic.key;

			#if sys
			if (path != null && sys.FileSystem.exists(path))
			{
				try {
					tempBmp = openfl.display.BitmapData.fromFile(path);
					bmp = tempBmp;
				} catch (e:Dynamic) {}
			}
			#end

			if (bmp == null && path != null && openfl.utils.Assets.exists(path, IMAGE))
			{
				try {
					tempBmp = openfl.utils.Assets.getBitmapData(path, false);
					bmp = tempBmp;
				} catch (e:Dynamic) {}
			}
		}

		if (bmp == null || bmp.width <= 0 || bmp.height <= 0)
			return null;

		var w:Int = bmp.width;
		var h:Int = bmp.height;

		// 0: unvisited (candidate transparent), 1: solid/opaque, 2: exterior transparent
		var grid = haxe.io.Bytes.alloc(w * h);

		for (y in 0...h)
		{
			for (x in 0...w)
			{
				var pixel:Int = bmp.getPixel32(x, y);
				var alpha:Int = (pixel >>> 24) & 0xFF;
				if (alpha > alphaThreshold)
					grid.set(y * w + x, 1);
			}
		}

		// Flood fill from all 4 boundaries to mark outside transparent pixels
		var q:Array<Int> = [];
		for (x in 0...w)
		{
			if (grid.get(0 * w + x) == 0) { grid.set(0 * w + x, 2); q.push(0 * w + x); }
			if (grid.get((h - 1) * w + x) == 0) { grid.set((h - 1) * w + x, 2); q.push((h - 1) * w + x); }
		}
		for (y in 0...h)
		{
			if (grid.get(y * w + 0) == 0) { grid.set(y * w + 0, 2); q.push(y * w + 0); }
			if (grid.get(y * w + (w - 1)) == 0) { grid.set(y * w + (w - 1), 2); q.push(y * w + (w - 1)); }
		}

		var head:Int = 0;
		while (head < q.length)
		{
			var idx:Int = q[head++];
			var cx:Int = idx % w;
			var cy:Int = Std.int(idx / w);

			if (cx > 0)
			{
				var nidx = cy * w + (cx - 1);
				if (grid.get(nidx) == 0) { grid.set(nidx, 2); q.push(nidx); }
			}
			if (cx < w - 1)
			{
				var nidx = cy * w + (cx + 1);
				if (grid.get(nidx) == 0) { grid.set(nidx, 2); q.push(nidx); }
			}
			if (cy > 0)
			{
				var nidx = (cy - 1) * w + cx;
				if (grid.get(nidx) == 0) { grid.set(nidx, 2); q.push(nidx); }
			}
			if (cy < h - 1)
			{
				var nidx = (cy + 1) * w + cx;
				if (grid.get(nidx) == 0) { grid.set(nidx, 2); q.push(nidx); }
			}
		}

		// Calculate bounding box of remaining enclosed transparent pixels (grid == 0)
		var minX:Int = 99999;
		var maxX:Int = -1;
		var minY:Int = 99999;
		var maxY:Int = -1;
		var count:Int = 0;

		for (y in 0...h)
		{
			for (x in 0...w)
			{
				if (grid.get(y * w + x) == 0)
				{
					count++;
					if (x < minX) minX = x;
					if (x > maxX) maxX = x;
					if (y < minY) minY = y;
					if (y > maxY) maxY = y;
				}
			}
		}

		var result:FlxRect = null;
		// Require reasonable dimensions for an inner slot
		if (count >= 20 && maxX > minX && maxY > minY)
		{
			result = new FlxRect(minX, minY, (maxX - minX + 1), (maxY - minY + 1));
		}

		if (tempBmp != null)
		{
			tempBmp.dispose();
			tempBmp.disposeImage();
		}

		return result;
	}

	public static var sizeLabels:Array<String> = ["B", "KB", "MB", "GB", "TB"];

	public static inline function addZeros(str:String, num:Int):String
	{
		while (str.length < num)
			str = '0${str}';
		return str;
	}

	/**
	 * Formats a byte size into a human-readable string (B, KB, MB, GB, TB), matching Codename Engine's `CoolUtil.getSizeString`.
	 */
	public static function getSizeString(size:Float):String
	{
		var rSize:Float = size < 0 ? 0 : size;
		var label:Int = 0;
		while (rSize >= 1024 && label < sizeLabels.length - 1)
		{
			label++;
			rSize /= 1024;
		}
		return '${Std.int(rSize) + "." + addZeros(Std.string(Std.int((rSize % 1) * 100)), 2)} ${sizeLabels[label]}';
	}
}
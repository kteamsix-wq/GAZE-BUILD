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
		return string.replace("-", " ").replace("_", " ");
	}

	public static function spaceToDash(string:String):String
	{
		return string.replace(" ", "-").replace("_", "-");
	}

	public static function swapSpaceDash(string:String):String
	{
		return StringTools.contains(string, '-') ? dashToSpace(string) : spaceToDash(string);
	}

	/**
	 * Returns normalized song name variants (dashes, spaces, underscores, raw, lowercase, squished)
	 * to ensure seamless cross-engine compatibility with any naming convention (Psych, Kade, Codename, Vanilla, etc.).
	 *
	 * Examples:
	 *   "Minha Musica" -> ["minha-musica", "minha musica", "minha_musica", "minhamusica", "Minha Musica"]
	 *   "Minha-Musica" -> ["minha-musica", "minha musica", "minha_musica", "minhamusica", "Minha-Musica"]
	 *   "Minha_Musica" -> ["minha-musica", "minha musica", "minha_musica", "minhamusica", "Minha_Musica"]
	 */
	public static function getSongNameVariants(song:String):Array<String>
	{
		if (song == null) return [];
		var raw:String = song.trim();
		if (raw.length == 0) return [];

		var variants:Array<String> = [];

		inline function addVariant(v:String)
		{
			if (v != null && v.length > 0 && !variants.contains(v))
				variants.push(v);
		}

		var lower:String = raw.toLowerCase();

		// 1. Dash-separated (FNF / Psych standard): "minha-musica"
		var dashed:String = lower.replace('_', '-').replace(' ', '-');
		while (dashed.indexOf('--') != -1) dashed = dashed.replace('--', '-');
		addVariant(dashed);

		// 2. Space-separated: "minha musica"
		var spaced:String = lower.replace('_', ' ').replace('-', ' ');
		while (spaced.indexOf('  ') != -1) spaced = spaced.replace('  ', ' ');
		addVariant(spaced);

		// 3. Underscore-separated: "minha_musica"
		var underscored:String = lower.replace('-', '_').replace(' ', '_');
		while (underscored.indexOf('__') != -1) underscored = underscored.replace('__', '_');
		addVariant(underscored);

		// 4. Exact lowercase & raw
		addVariant(lower);
		addVariant(raw);

		// 5. Without separators: "minhamusica"
		var squished:String = lower.replace('-', '').replace(' ', '').replace('_', '');
		addVariant(squished);

		return variants;
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

	public static function getStageList(?modOnly:Bool = false, ?specificMod:String = null):Array<String>
	{
		var stageArray:Array<String> = [];
		var stageMap:Map<String, Bool> = new Map();

		#if sys
		var directories:Array<String> = [];

		var curMod:String = specificMod;
		if (curMod == null || curMod.trim() == '')
			curMod = core.scripting.Mods.currentModDirectory;

		// 1. Mod-specific stages folders (supports both 'stages' and 'data/stages')
		if (curMod != null && curMod.trim() != '' && curMod.trim().toLowerCase() != 'none')
		{
			var cleanMod:String = curMod.trim();
			var modStages:String = 'mods/' + cleanMod + '/stages';
			var modDataStages:String = 'mods/' + cleanMod + '/data/stages';
			if (!directories.contains(modStages)) directories.push(modStages);
			if (!directories.contains(modDataStages)) directories.push(modDataStages);
		}

		// 2. Global mod stages folders
		if (!directories.contains('mods/stages')) directories.push('mods/stages');
		if (!directories.contains('mods/data/stages')) directories.push('mods/data/stages');

		// 3. Other mod directories if not locked to a specific mod
		if (specificMod == null || specificMod.trim() == '')
		{
			for (modFolder in core.scripting.Mods.getModDirectories())
			{
				var mStages:String = 'mods/' + modFolder + '/stages';
				var mDataStages:String = 'mods/' + modFolder + '/data/stages';
				if (!directories.contains(mStages)) directories.push(mStages);
				if (!directories.contains(mDataStages)) directories.push(mDataStages);
			}
		}

		// 4. Base game assets (ONLY when modOnly is false)
		if (!modOnly)
		{
			if (!directories.contains('assets/stages')) directories.push('assets/stages');
			if (!directories.contains('assets/data/stages')) directories.push('assets/data/stages');
		}

		// Scan directories
		for (path in directories)
		{
			if (sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path))
			{
				for (file in sys.FileSystem.readDirectory(path))
				{
					var subPath:String = path + '/' + file;
					if (sys.FileSystem.isDirectory(subPath))
					{
						if (file != '.' && file != '..' && !file.startsWith('.') && !stageMap.exists(file))
						{
							stageMap.set(file, true);
							stageArray.push(file);
						}
					}
					else if (file.endsWith('.json') || file.endsWith('.hx') || file.endsWith('.hxc') || file.endsWith('.hscript') || file.endsWith('.lua'))
					{
						var dotIdx:Int = file.lastIndexOf('.');
						var name:String = file.substring(0, dotIdx);
						if (name != null && name.trim() != '' && !stageMap.exists(name))
						{
							stageMap.set(name, true);
							stageArray.push(name);
						}
					}
				}
			}
		}

		// If modOnly was requested but mod had zero stages, fallback to base stages to avoid crash
		if (modOnly && stageArray.length == 0)
		{
			var fallbackDirs:Array<String> = ['assets/stages', 'assets/data/stages'];
			for (path in fallbackDirs)
			{
				if (sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path))
				{
					for (file in sys.FileSystem.readDirectory(path))
					{
						var subPath:String = path + '/' + file;
						if (sys.FileSystem.isDirectory(subPath))
						{
							if (file != '.' && file != '..' && !file.startsWith('.') && !stageMap.exists(file))
							{
								stageMap.set(file, true);
								stageArray.push(file);
							}
						}
						else if (file.endsWith('.json') || file.endsWith('.hx') || file.endsWith('.hxc'))
						{
							var dotIdx:Int = file.lastIndexOf('.');
							var name:String = file.substring(0, dotIdx);
							if (name != null && name.trim() != '' && !stageMap.exists(name))
							{
								stageMap.set(name, true);
								stageArray.push(name);
							}
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
	 * Detects the inner transparent area ("campo invis�vel" / cutout slot) inside a health bar frame sprite.
	 * Returns an FlxRect with (x, y, width, height) relative to the sprite, or null if no inner hole is found.
	 */
	public static function detectHealthBarBounds(sprite:FlxSprite, alphaThreshold:Int = 220):FlxRect
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

		// Encontra a maior região contígua de pixels transparentes fechados (o slot real da barra de vida,
		// ignorando pequenos furos decorativos como elos de corrente, rachaduras ou parafusos)
		var bestCount:Int = 0;
		var bestMinX:Int = 99999;
		var bestMaxX:Int = -1;
		var bestMinY:Int = 99999;
		var bestMaxY:Int = -1;

		var compQueue:Array<Int> = [];
		for (y in 0...h)
		{
			for (x in 0...w)
			{
				var startIdx = y * w + x;
				if (grid.get(startIdx) == 0)
				{
					grid.set(startIdx, 3);
					compQueue = [startIdx];
					var compHead = 0;

					var cMinX = x;
					var cMaxX = x;
					var cMinY = y;
					var cMaxY = y;
					var cCount = 0;

					while (compHead < compQueue.length)
					{
						var cur = compQueue[compHead++];
						cCount++;
						var px = cur % w;
						var py = Std.int(cur / w);

						if (px < cMinX) cMinX = px;
						if (px > cMaxX) cMaxX = px;
						if (py < cMinY) cMinY = py;
						if (py > cMaxY) cMaxY = py;

						if (px > 0)
						{
							var n = py * w + (px - 1);
							if (grid.get(n) == 0) { grid.set(n, 3); compQueue.push(n); }
						}
						if (px < w - 1)
						{
							var n = py * w + (px + 1);
							if (grid.get(n) == 0) { grid.set(n, 3); compQueue.push(n); }
						}
						if (py > 0)
						{
							var n = (py - 1) * w + px;
							if (grid.get(n) == 0) { grid.set(n, 3); compQueue.push(n); }
						}
						if (py < h - 1)
						{
							var n = (py + 1) * w + px;
							if (grid.get(n) == 0) { grid.set(n, 3); compQueue.push(n); }
						}
					}

					if (cCount > bestCount)
					{
						bestCount = cCount;
						bestMinX = cMinX;
						bestMaxX = cMaxX;
						bestMinY = cMinY;
						bestMaxY = cMaxY;
					}
				}
			}
		}

		var result:FlxRect = null;
		// Require reasonable dimensions for an inner slot
		if (bestCount >= 20 && bestMaxX > bestMinX && bestMaxY > bestMinY)
		{
			result = new FlxRect(bestMinX, bestMinY, (bestMaxX - bestMinX + 1), (bestMaxY - bestMinY + 1));
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
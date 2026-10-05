package backend;
import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;
import Paths;
import Utils;
import Init;

import Assets;
import funkin.states.PlayState;

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
		trace(libraryArray);
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
		if (backend.Mods.currentModDirectory != null) {
			directories.push('mods/' + backend.Mods.currentModDirectory + '/data/char');
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
}
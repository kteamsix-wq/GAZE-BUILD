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

	public static function getStageList():Array<String>
	{
		var stageArray:Array<String> = [];
		var stageMap:Map<String, Bool> = new Map();

		#if sys
		var directories:Array<String> = ['assets/data/stages'];
		if (backend.Mods.currentModDirectory != null && backend.Mods.currentModDirectory.length > 0) {
			directories.push('mods/' + backend.Mods.currentModDirectory + '/data/stages');
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
}
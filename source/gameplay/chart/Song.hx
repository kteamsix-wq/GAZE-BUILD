package gameplay.chart;

import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;

import flixel.FlxG;
import haxe.Json;
import haxe.format.JsonParser;
import core.system.Assets;
import gameplay.chart.Section.SwagSection;
import gameplay.chart.ChartConverter;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var ?defaultSpeed:Float;

	var player1:String;
	var player2:String;
	var ?player3:String;
	var ?gfVersion:String;
	var stage:String;
	var noteSkin:String;
	var assetModifier:String;
	var validScore:Bool;
	var ?format:String;
	var ?chartPath:String;
	var ?eventGroups:Array<Dynamic>;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var player3:String = 'gf';
	public var gfVersion:String = 'gf';

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var songFolder:String = folder;
		if (songFolder == null && jsonInput != null)
		{
			songFolder = jsonInput;
			var lower = jsonInput.toLowerCase();
			for (diff in ['easy', 'normal', 'hard'])
			{
				for (sep in ['-', '_', ' '])
				{
					if (lower.endsWith(sep + diff))
					{
						songFolder = jsonInput.substring(0, jsonInput.length - (sep + diff).length);
						break;
					}
				}
			}
		}
		if (songFolder == null) songFolder = "unknown";

		var resolvedChartPath:String = null;

		#if sys
		if (jsonInput != null && FileSystem.exists(jsonInput) && !FileSystem.isDirectory(jsonInput))
		{
			resolvedChartPath = jsonInput;
			var normalized:String = resolvedChartPath.replace('\\', '/');
			if (normalized.startsWith('mods/'))
			{
				var parts:Array<String> = normalized.split('/');
				if (parts.length > 2 && parts[1] != 'songs' && parts[1] != 'data')
				{
					if (core.scripting.Mods.currentModDirectory != parts[1])
						core.scripting.Mods.currentModDirectory = parts[1];
				}
			}
			if (folder == null)
			{
				var parentDir:String = haxe.io.Path.directory(normalized);
				var dirName:String = haxe.io.Path.withoutDirectory(parentDir).toLowerCase();
				if (dirName == 'charts' || dirName == 'chart' || dirName == 'data')
					songFolder = haxe.io.Path.withoutDirectory(haxe.io.Path.directory(parentDir));
				else
					songFolder = dirName;
			}
		}
		else
		{
			resolvedChartPath = ChartConverter.findChartPath(songFolder, jsonInput);
		}

		if (resolvedChartPath == null || !FileSystem.exists(resolvedChartPath))
		{
			for (f in CoolUtil.getSongNameVariants(songFolder))
			{
				for (c in CoolUtil.getSongNameVariants(jsonInput))
				{
					var p = 'assets/songs/$f/$c.json';
					if (FileSystem.exists(p))
					{
						resolvedChartPath = p;
						break;
					}
				}
				if (resolvedChartPath != null) break;
			}
			if (resolvedChartPath == null)
			{
				var chartPath:String = 'assets/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json';
				if (!FileSystem.exists(chartPath))
					chartPath = 'assets/songs/${songFolder.toLowerCase()}/chart/chart.json';
				resolvedChartPath = chartPath;
			}
		}

		if (resolvedChartPath != null)
		{
			var normalized:String = resolvedChartPath.replace('\\', '/');
			if (normalized.startsWith('mods/'))
			{
				var parts:Array<String> = normalized.split('/');
				if (parts.length > 2 && parts[1] != 'songs' && parts[1] != 'data')
				{
					if (core.scripting.Mods.currentModDirectory != parts[1])
						core.scripting.Mods.currentModDirectory = parts[1];
				}
			}
		}

		if (!FileSystem.exists(resolvedChartPath))
		{
			FlxG.log.warn('Song.loadFromJson: Could not find chart for "$songFolder" / "$jsonInput"');
			return ChartConverter.createFallbackSong(songFolder);
		}

		var rawJson:String = File.getContent(resolvedChartPath).trim();

		// Determine target difficulty from input or path (supports -, _, spaces)
		var targetDiff:String = "normal";
		var lowerInput:String = jsonInput != null ? jsonInput.toLowerCase() : "";
		var lowerPath:String = resolvedChartPath.toLowerCase().replace('\\', '/');
		if (lowerInput.endsWith("-easy") || lowerInput.endsWith("_easy") || lowerInput.endsWith(" easy") || lowerInput == "easy"
			|| lowerPath.endsWith("-easy.json") || lowerPath.endsWith("_easy.json") || lowerPath.endsWith("/easy.json"))
			targetDiff = "easy";
		else if (lowerInput.endsWith("-hard") || lowerInput.endsWith("_hard") || lowerInput.endsWith(" hard") || lowerInput == "hard"
			|| lowerPath.endsWith("-hard.json") || lowerPath.endsWith("_hard.json") || lowerPath.endsWith("/hard.json"))
			targetDiff = "hard";

		var parsedSong:SwagSong = ChartConverter.convert(rawJson, songFolder, resolvedChartPath, targetDiff);
		if (parsedSong.song == 'unknown')
			parsedSong.song = songFolder;
		parsedSong.chartPath = resolvedChartPath;
		return parsedSong;
		#else
		return ChartConverter.createFallbackSong(songFolder);
		#end
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		return ChartConverter.convert(rawJson);
	}

	public static function findFirstBPM(notes:Array<SwagSection>):Float
	{
		if (notes != null)
		{
			for (section in notes)
				if (section != null && section.bpm > 0)
					return section.bpm;
		}

		return 100;
	}
}

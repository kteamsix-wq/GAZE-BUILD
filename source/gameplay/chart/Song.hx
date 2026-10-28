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
		var songFolder:String = (folder == null) ? jsonInput : folder;
		var resolvedChartPath:String = ChartConverter.findChartPath(songFolder, jsonInput);

		#if sys
		if (resolvedChartPath == null || !FileSystem.exists(resolvedChartPath))
		{
			var chartPath:String = 'assets/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json';
			if (!FileSystem.exists(chartPath))
				chartPath = 'assets/songs/${songFolder.toLowerCase()}/chart/chart.json';
			resolvedChartPath = chartPath;
		}

		if (!FileSystem.exists(resolvedChartPath))
		{
			FlxG.log.warn('Song.loadFromJson: Could not find chart for "$songFolder" / "$jsonInput"');
			return ChartConverter.createFallbackSong(songFolder);
		}

		var rawJson:String = File.getContent(resolvedChartPath).trim();

		// Determine target difficulty from input
		var targetDiff:String = "normal";
		var lowerInput:String = jsonInput.toLowerCase();
		if (lowerInput.endsWith("-easy") || lowerInput == "easy")
			targetDiff = "easy";
		else if (lowerInput.endsWith("-hard") || lowerInput == "hard")
			targetDiff = "hard";

		var parsedSong:SwagSong = ChartConverter.convert(rawJson, songFolder, resolvedChartPath, targetDiff);
		if (parsedSong.song == 'unknown')
			parsedSong.song = songFolder;
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

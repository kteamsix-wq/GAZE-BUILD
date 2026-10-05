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

import haxe.Json;
import haxe.format.JsonParser;
import Assets;
import backend.Section.SwagSection;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var stage:String;
	var noteSkin:String;
	var assetModifier:String;
	var validScore:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = 'bf';
	public var player2:String = 'dad';

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var songFolder:String = (folder == null) ? jsonInput : folder;
		
		var chartPath:String = 'assets/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json';

		#if sys
		var modChartPath:String = 'mods/' + Mods.currentModDirectory + '/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json';
		if (Mods.currentModDirectory != null && FileSystem.exists(modChartPath))
			chartPath = modChartPath;
		else if (FileSystem.exists('mods/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json'))
			chartPath = 'mods/songs/${songFolder.toLowerCase()}/${jsonInput.toLowerCase()}.json';
		#end

		if (!FileSystem.exists(chartPath))
			chartPath = 'assets/songs/${songFolder.toLowerCase()}/chart/chart.json';

		#if sys
		var modChartPath2:String = 'mods/' + Mods.currentModDirectory + '/songs/${songFolder.toLowerCase()}/chart/chart.json';
		if (!FileSystem.exists(chartPath)) {
			if (Mods.currentModDirectory != null && FileSystem.exists(modChartPath2))
				chartPath = modChartPath2;
			else if (FileSystem.exists('mods/songs/${songFolder.toLowerCase()}/chart/chart.json'))
				chartPath = 'mods/songs/${songFolder.toLowerCase()}/chart/chart.json';
		}
		#end

		var rawJson = File.getContent(chartPath).trim();

		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		var parsedSong:SwagSong = parseJSONshit(rawJson);
		if (parsedSong.song == 'unknown')
			parsedSong.song = songFolder;
		return parsedSong;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var rawSong:Dynamic = Json.parse(rawJson).song;
		var swagShit:SwagSong = cast rawSong;
		if (swagShit.song == null)
			swagShit.song = 'unknown';
		var bpm:Dynamic = Reflect.field(rawSong, 'bpm');
		if (bpm == null || bpm <= 0)
			swagShit.bpm = findFirstBPM(swagShit.notes);
		if (Reflect.field(rawSong, 'needsVoices') == null)
			swagShit.needsVoices = true;
		var speed:Dynamic = Reflect.field(rawSong, 'speed');
		if (speed == null || speed <= 0)
			swagShit.speed = 1;
		if (swagShit.player1 == null)
			swagShit.player1 = 'bf';
		if (swagShit.player2 == null)
			swagShit.player2 = 'dad';
		if (swagShit.stage == null)
			swagShit.stage = '';
		swagShit.validScore = true;
		return swagShit;
	}

	private static function findFirstBPM(notes:Array<SwagSection>):Float
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





package backend;

import flixel.util.FlxColor;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef WeekSongData =
{
	var name:String;
	var character:String;
	var color:FlxColor;
}

class WeekData
{
	public var id:String;
	public var title:String;
	public var songs:Array<WeekSongData>;
	public var freeplayColor:FlxColor;
	public var weekIndex:Int;
	public var startUnlocked:Bool;
	public var hideStoryMode:Bool;

	public function new(id:String, weekIndex:Int)
	{
		this.id = id;
		this.title = id;
		this.weekIndex = weekIndex;
		this.songs = [];
		this.freeplayColor = FlxColor.WHITE;
		this.startUnlocked = true;
		this.hideStoryMode = false;
	}

	public static function loadWeeks():Array<WeekData>
	{
		var weeks:Array<WeekData> = [];
		var weekFiles:Map<String, String> = new Map();

		#if sys
		var directories:Array<String> = ['assets/data/weeks'];
		if (backend.Mods.currentModDirectory != null) {
			directories.push('mods/' + backend.Mods.currentModDirectory + '/data/weeks');
		}

		for (directory in directories) {
			if (!FileSystem.exists(directory)) continue;

			var files:Array<String> = FileSystem.readDirectory(directory);
			files = files.filter(function(file:String):Bool return file.toLowerCase().endsWith('.json'));

			for (fileName in files) {
				if (!weekFiles.exists(fileName)) {
					weekFiles.set(fileName, directory);
				}
			}
		}

		var sortedFiles:Array<String> = [];
		for (key in weekFiles.keys()) {
			sortedFiles.push(key);
		}
		sortedFiles.sort(function(a:String, b:String):Int return Reflect.compare(a, b));

		for (fileName in sortedFiles)
		{
			try
			{
				var directory = weekFiles.get(fileName);
				var fileId:String = fileName.substr(0, fileName.length - 5);
				var json:Dynamic = Json.parse(File.getContent('$directory/$fileName'));
				var week:WeekData = fromJson(fileId, weeks.length + 1, json);
				if (week.songs.length > 0)
					weeks.push(week);
			}
			catch (error:Dynamic)
			{
				trace('Unable to load week $fileName: $error');
			}
		}
		#end

		return weeks;
	}

	public static function fromJson(id:String, weekIndex:Int, json:Dynamic):WeekData
	{
		var week:WeekData = new WeekData(id, weekIndex);
		var jsonId:Dynamic = Reflect.field(json, 'id');
		if (jsonId != null)
			week.id = Std.string(jsonId);

		var title:Dynamic = Reflect.field(json, 'title');
		if (title == null)
			title = Reflect.field(json, 'storyName');
		if (title == null)
			title = Reflect.field(json, 'name');
		if (title != null)
			week.title = Std.string(title);

		week.freeplayColor = readColor(Reflect.field(json, 'freeplayColor'), FlxColor.WHITE);
		week.startUnlocked = readBool(Reflect.field(json, 'startUnlocked'), true);
		week.hideStoryMode = readBool(Reflect.field(json, 'hideStoryMode'), false);

		var jsonSongs:Dynamic = Reflect.field(json, 'songs');
		if (jsonSongs == null || !Std.isOfType(jsonSongs, Array))
			return week;

		for (entry in (cast jsonSongs:Array<Dynamic>))
		{
			var song:WeekSongData = parseSong(entry, week.freeplayColor);
			if (song != null)
				week.songs.push(song);
		}

		return week;
	}

	private static function parseSong(entry:Dynamic, fallbackColor:FlxColor):Null<WeekSongData>
	{
		if (entry == null)
			return null;

		var name:String = null;
		var character:String = 'gf';
		var color:FlxColor = fallbackColor;

		if (Std.isOfType(entry, Array))
		{
			var values:Array<Dynamic> = cast entry;
			if (values.length > 0 && values[0] != null)
				name = Std.string(values[0]);
			if (values.length > 1 && values[1] != null)
				character = Std.string(values[1]);
			if (values.length > 2)
				color = readColor(values[2], fallbackColor);
		}
		else
		{
			var jsonName:Dynamic = Reflect.field(entry, 'name');
			if (jsonName == null)
				jsonName = Reflect.field(entry, 'song');
			if (jsonName != null)
				name = Std.string(jsonName);
			if (Reflect.field(entry, 'character') != null)
				character = Std.string(Reflect.field(entry, 'character'));
			color = readColor(Reflect.field(entry, 'color'), fallbackColor);
		}

		if (name == null || name.length == 0 || name == 'null')
			return null;

		return {
			name: name,
			character: character,
			color: color
		};
	}

	private static function readColor(value:Dynamic, fallback:FlxColor):FlxColor
	{
		if (value == null || !Std.isOfType(value, Array))
			return fallback;

		var rgb:Array<Dynamic> = cast value;
		if (rgb.length < 3)
			return fallback;

		return FlxColor.fromRGB(Std.int(rgb[0]), Std.int(rgb[1]), Std.int(rgb[2]));
	}

	private static function readBool(value:Dynamic, fallback:Bool):Bool
	{
		return value == null ? fallback : (value == true || value == 'true');
	}
}

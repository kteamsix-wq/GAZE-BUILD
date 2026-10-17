package backend;

import flixel.FlxG;
import backend.CoolUtil;

using StringTools;

class Highscore
{
	#if (haxe >= "4.0.0")
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();
	public static var songCombo:Map<String, String> = new Map();
	#else
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	public static var songCombo:Map<String, String> = new Map<String, String>();
	#end

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1, ?combo:String = ''):Void
	{
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if (rating >= 0) setRating(daSong, rating);
				if (combo != null && combo != '') setCombo(daSong, combo);
			}
			else
			{
				if (rating >= 0 && (!songRating.exists(daSong) || rating > songRating.get(daSong)))
					setRating(daSong, rating);
				if (combo != null && combo != '' && (!songCombo.exists(daSong) || isBetterCombo(combo, songCombo.get(daSong))))
					setCombo(daSong, combo);
			}
		}
		else
		{
			setScore(daSong, score);
			if (rating >= 0) setRating(daSong, rating);
			if (combo != null && combo != '') setCombo(daSong, combo);
		}
	}

	public static function saveWeekScore(week:Int = 1, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong('week' + week, diff);

		if (songScores.exists(daWeek))
		{
			if (songScores.get(daWeek) < score)
				setScore(daWeek, score);
		}
		else
			setScore(daWeek, score);
	}

	static function setScore(song:String, score:Int):Void
	{
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	static function setCombo(song:String, combo:String):Void
	{
		songCombo.set(song, combo);
		FlxG.save.data.songCombo = songCombo;
		FlxG.save.flush();
	}

	static function comboWeight(combo:String):Int
	{
		if (combo == null) return -1;
		var upper = combo.toUpperCase().trim();
		switch (upper)
		{
			case 'SFC': return 5;
			case 'GFC': return 4;
			case 'FC': return 3;
			case 'SDCB': return 2;
			case 'CLEAR': return 1;
			default:
				if (upper.indexOf('CLEAR') != -1) return 1;
				return 0;
		}
	}

	public static function isBetterCombo(newCombo:String, oldCombo:String):Bool
	{
		return comboWeight(newCombo) > comboWeight(oldCombo);
	}

	public static function formatSong(song:String, diff:Int):String
	{
		var daSong:String = song.toLowerCase();

		var difficulty:String = '-' + CoolUtil.difficultyFromNumber(diff).toLowerCase();
		difficulty = difficulty.replace('-normal', '');

		daSong += difficulty;

		return daSong;
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		if (!songRating.exists(daSong))
			return 0.0;

		return songRating.get(daSong);
	}

	public static function getCombo(song:String, diff:Int):String
	{
		var daSong:String = formatSong(song, diff);
		if (!songCombo.exists(daSong))
			return "";

		return songCombo.get(daSong);
	}

	public static function getWeekScore(week:Int, diff:Int):Int
	{
		if (!songScores.exists(formatSong('week' + week, diff)))
			setScore(formatSong('week' + week, diff), 0);

		return songScores.get(formatSong('week' + week, diff));
	}

	public static function load():Void
	{
		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;

		if (FlxG.save.data.songCombo != null)
			songCombo = FlxG.save.data.songCombo;
	}
}

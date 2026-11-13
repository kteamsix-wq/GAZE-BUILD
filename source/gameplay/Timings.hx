package gameplay;

import gameplay.PlayState;

using StringTools;

class Timings
{
	public static var accuracy:Float = 0;
	public static var trueAccuracy:Float = 0;
	public static var judgementRates:Array<Float> = [];

	// from left to right
	// order, max milliseconds, score from it, health/accuracy weight, fc label
	public static var judgementsMap:Map<String, Array<Dynamic>> = [
		"sick" => [0, 45.0, 350, 100, 'SFC'],
		"good" => [1, 90.0, 200, 75, 'GFC'],
		"bad"  => [2, 135.0, 100, 50, 'FC'],
		"shit" => [3, 166.0, 50, 25, 'CLEAR'],
		"miss" => [4, 166.0, -10, -175, null],
	];

	public static var msThreshold:Float = 0;
	public static var sickThreshold:Float = 45.0;
	public static var goodThreshold:Float = 90.0;
	public static var badThreshold:Float = 135.0;
	public static var shitThreshold:Float = 166.0;

	public static inline function diffToJudgement(noteDiff:Float):String
	{
		if (noteDiff <= sickThreshold) return 'sick';
		if (noteDiff <= goodThreshold) return 'good';
		if (noteDiff <= badThreshold) return 'bad';
		return 'shit';
	}

	// set the score judgements for later use
	public static var scoreRating:Map<String, Int> = [
		"S+" => 100,
		"S"  => 95,
		"A"  => 90,
		"b"  => 85,
		"c"  => 80,
		"d"  => 75,
		"e"  => 70,
		"f"  => 65,
	];

	public static var ratingFinal:String = "N/A";
	public static var notesHit:Int = 0;
	public static var segmentsHit:Int = 0;
	public static var comboDisplay:String = 'FC';

	public static var gottenJudgements:Map<String, Int> = [];
	public static var smallestRating:String = 'sick';

	public static function callAccuracy():Void
	{
		accuracy = 0;
		trueAccuracy = 0;
		judgementRates = [];

		var biggestThreshold:Float = 0;
		for (key in ['sick', 'good', 'bad', 'shit'])
		{
			gottenJudgements.set(key, 0);
			if (judgementsMap.exists(key))
			{
				var arr = judgementsMap.get(key);
				var th:Float = arr[1];
				if (th > biggestThreshold) biggestThreshold = th;
			}
		}
		gottenJudgements.set('miss', 0);
		if (judgementsMap.exists('sick')) sickThreshold = judgementsMap.get('sick')[1];
		if (judgementsMap.exists('good')) goodThreshold = judgementsMap.get('good')[1];
		if (judgementsMap.exists('bad'))  badThreshold  = judgementsMap.get('bad')[1];
		if (judgementsMap.exists('shit')) shitThreshold = judgementsMap.get('shit')[1];
		msThreshold = biggestThreshold > 0 ? biggestThreshold : 166.0;
		
		smallestRating = 'sick';
		notesHit = 0;
		segmentsHit = 0;
		ratingFinal = "N/A";
		comboDisplay = 'FC';
	}

	public static function updateAccuracy(judgementWeight:Float, ?isSustain:Bool = false, ?segmentCount:Int = 1):Void
	{
		var w = Math.max(0, judgementWeight);
		
		if (!isSustain)
		{
			notesHit++;
			accuracy += w;
		}
		else
		{
			if (segmentCount > 0)
				accuracy += (w / segmentCount);
		}
		
		if (notesHit > 0)
			trueAccuracy = Math.min(100, Math.max(0, accuracy / notesHit));
		else
			trueAccuracy = 0;

		updateScoreRating();
		updateFCDisplay();
	}

	public static function updateFCDisplay():Void
	{
		if (PlayState.misses == 0)
		{
			if (notesHit == 0)
			{
				comboDisplay = 'FC';
			}
			else
			{
				var arr = judgementsMap.get(smallestRating);
				if (arr != null && arr.length > 4 && arr[4] != null)
					comboDisplay = Std.string(arr[4]);
				else
					comboDisplay = 'FC';
			}
		}
		else if (PlayState.misses < 10)
		{
			comboDisplay = 'SDCB';
		}
		else
		{
			comboDisplay = 'CLEAR';
		}

		if (PlayState.instance != null)
			PlayState.instance.updateScoreText();
	}

	public static function getComboColor(combo:String):flixel.util.FlxColor
	{
		if (combo == null) return flixel.util.FlxColor.WHITE;
		var upper = combo.toUpperCase().trim();
		switch (upper)
		{
			case 'SFC':
				return 0xFFFFD700; // Dourado
			case 'GFC':
				return 0xFF00FF66; // Verde
			case 'FC':
				return 0xFF35A7FF; // Azul
			case 'SDCB':
				return flixel.util.FlxColor.WHITE; // Branco (padrão)
			case 'CLEAR':
				return 0xFFFF3333; // Vermelho
			case '---', 'N/A', '':
				return 0xFF888888;
			default:
				if (upper.indexOf('CLEAR') != -1)
					return 0xFFFF3333;
				return flixel.util.FlxColor.WHITE;
		}
	}

	public static inline function getAccuracy():Float
	{
		return trueAccuracy;
	}

	public static function updateScoreRating():Void
	{
		var biggest:Int = 0;
		for (score in scoreRating.keys())
		{
			var ratingValue = scoreRating.get(score);
			if (trueAccuracy >= ratingValue && ratingValue >= biggest)
			{
				biggest = ratingValue;
				ratingFinal = score;
			}
		}
	}

	public static inline function returnScoreRating():String
	{
		return ratingFinal;
	}
}

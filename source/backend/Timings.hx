package backend;

import funkin.states.PlayState;

class Timings
{
	public static var accuracy:Float = 0;
	public static var trueAccuracy:Float = 0;
	public static var judgementRates:Array<Float> = [];

	// from left to right
	// order, max milliseconds, score from it, health/accuracy weight, fc label
	public static var judgementsMap:Map<String, Array<Dynamic>> = [
		"sick" => [0, 45, 350, 100, 'SFC'],
		"good" => [1, 90, 150, 75, 'GFC'],
		"bad"  => [2, 135, 0, 25, 'FC'],
		"shit" => [3, 157.5, -50, -150],
		"miss" => [4, 180, -100, -175],
	];

	public static var msThreshold:Float = 0;

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
	public static var comboDisplay:String = '';

	public static var gottenJudgements:Map<String, Int> = [];
	public static var smallestRating:String = 'sick';

	public static function callAccuracy():Void
	{
		accuracy = 0.001;
		trueAccuracy = 0;
		judgementRates = [];

		var biggestThreshold:Float = 0;
		for (key in judgementsMap.keys())
		{
			gottenJudgements.set(key, 0);
			var arr = judgementsMap.get(key);
			var th:Float = arr[1];
			if (th > biggestThreshold) biggestThreshold = th;
		}
		msThreshold = biggestThreshold;
		
		smallestRating = 'sick';
		notesHit = 0;
		segmentsHit = 0;
		ratingFinal = "N/A";
		comboDisplay = '';
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
			trueAccuracy = (accuracy / notesHit);
		else
			trueAccuracy = 0;

		updateScoreRating();
		updateFCDisplay();
	}

	public static function updateFCDisplay():Void
	{
		comboDisplay = '';
		
		var arr = judgementsMap.get(smallestRating);
		if (arr != null && arr.length > 4 && arr[4] != null)
		{
			comboDisplay = Std.string(arr[4]);
		}
		else
		{
			if (PlayState.misses < 10)
				comboDisplay = 'SDCB';
		}

		if (PlayState.uiHUD != null)
			PlayState.uiHUD.updateScoreText();
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

package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.utils.MathUtil;
import funkin.states.PlayState;

class BeatModifier extends NoteModifier
{
	override function getName():String return 'beat';

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (getValue(player) == 0) return pos;
		var accelTime:Float = 0.3;
		var totalTime:Float = 0.7;

		var curBeatVal:Float = PlayState.instance != null ? PlayState.instance.curDecBeat : beat;
		var calcBeat:Float = curBeatVal + accelTime;
		var evenBeat = Std.int(calcBeat) % 2 != 0;

		if (calcBeat < 0) return pos;

		calcBeat -= Math.floor(calcBeat);
		calcBeat += 1;
		calcBeat -= Math.floor(calcBeat);
		if (calcBeat >= totalTime) return pos;

		var amount:Float = 0;
		if (calcBeat < accelTime)
		{
			amount = MathUtil.scale(calcBeat, 0, accelTime, 0, 1);
			amount *= amount;
		}
		else
		{
			amount = MathUtil.scale(calcBeat, accelTime, totalTime, 1, 0);
			amount = 1 - (1 - amount) * (1 - amount);
		}
		if (evenBeat) amount *= -1;

		var shift = 40 * amount * Math.sin((visualDiff / 30) + Math.PI / 2);
		pos.x += getValue(player) * shift;
		return pos;
	}
}

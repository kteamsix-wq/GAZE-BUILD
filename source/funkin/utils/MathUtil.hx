package funkin.utils;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;

class MathUtil
{
	public static function logBase(base:Float, value:Float):Float
	{
		return Math.log(value) / Math.log(base);
	}

	inline public static function scale(x:Float, l1:Float, h1:Float, l2:Float, h2:Float):Float
	{
		return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);
	}

	inline public static function clamp(n:Float, l:Float, h:Float):Float
	{
		if (n > h) n = h;
		if (n < l) n = l;
		return n;
	}

	public static function rotate(x:Float, y:Float, angle:Float, ?point:FlxPoint):FlxPoint
	{
		final p = point != null ? point : FlxPoint.weak();
		p.set((x * Math.cos(angle)) - (y * Math.sin(angle)), (x * Math.sin(angle)) + (y * Math.cos(angle)));
		return p;
	}

	public static inline function quantizeAlpha(f:Float, interval:Float):Float
	{
		return Std.int((f + interval / 2) / interval) * interval;
	}

	public static inline function quantize(f:Float, interval:Float):Float
	{
		return Std.int((f + interval / 2) / interval) * interval;
	}

	public static inline function fpsLerp(v1:Float, v2:Float, ratio:Float):Float
	{
		return FlxMath.lerp(v1, v2, FlxMath.getElapsedLerp(ratio, FlxG.elapsed));
	}

	public static function decayLerp(a:Float, b:Float, decay:Float, elapsed:Float):Float
	{
		return b + (a - b) * Math.exp(-decay * elapsed);
	}

	public static inline function wrap(n:Float, min:Float, max:Float):Float
	{
		return (euclideanMod(n - min, max - min + 1) + min);
	}

	public static inline function euclideanMod(n:Float, div:Float):Float
	{
		var mod:Float = (n % div);
		return (mod < 0 ? mod + Math.abs(div) : mod);
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);

		var tempMult:Float = 1;
		for (i in 0...decimals)
			tempMult *= 10;

		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	public static inline function numberArray(?min:Int, max:Int):Array<Int>
	{
		if (min == null) min = 0;
		return [for (i in min...max) i];
	}

	public static inline function fastTan(rad:Float):Float
	{
		return (FlxMath.fastSin(rad) / FlxMath.fastCos(rad));
	}
}

package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.utils.MathUtil;

class AccelModifier extends NoteModifier
{
	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	override function getName():String return 'boost';

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		var wave = getSubmodValue("wave", player);
		var brake = getSubmodValue("brake", player);
		var boost = getValue(player);
		var effectHeight = 500;

		var yAdjust:Float = 0;
		var reverse:Dynamic = modMgr.register.get("reverse");
		var reversePercent:Float = (reverse != null) ? reverse.getReverseValue(data, player) : 0.0;
		var mult = MathUtil.scale(reversePercent, 0, 1, 1, -1);

		if (brake != 0)
		{
			var scale = MathUtil.scale(visualDiff, 0, effectHeight, 0, 1);
			var off = visualDiff * scale;
			yAdjust += MathUtil.clamp(brake * (off - visualDiff), -400, 400);
		}

		if (boost != 0)
		{
			var denom = (visualDiff + effectHeight / 1.2) / effectHeight;
			if (denom != 0)
			{
				var off = visualDiff * 1.5 / denom;
				yAdjust += MathUtil.clamp(boost * (off - visualDiff), -400, 400);
			}
		}

		yAdjust += wave * 20 * Math.sin(visualDiff / 38);

		pos.y += yAdjust * mult;
		return pos;
	}

	override function getSubmods():Array<String>
	{
		return ["brake", "wave"];
	}
}

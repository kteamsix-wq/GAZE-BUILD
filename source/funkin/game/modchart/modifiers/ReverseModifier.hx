package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.game.modchart.ClientPrefs;
import funkin.utils.MathUtil;
import funkin.objects.FunkinArrows.Note;

class ReverseModifier extends NoteModifier
{
	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	override function getOrder():Int return REVERSE;

	override function getName():String return 'reverse';

	public inline function getReverseValue(dir:Int, player:Int, scrolling:Bool = false):Float
	{
		final suffix:String = (scrolling ? 'Scroll' : '');

		final keys:Int = (modMgr.receptors != null && modMgr.receptors.length > player && modMgr.receptors[player] != null) ? modMgr.receptors[player].length : modMgr.keys;
		var val:Float = 0;

		if (dir >= keys / 2) val += getSubmodValue("split" + suffix, player);
		if (dir % 2 == 1) val += getSubmodValue("alternate" + suffix, player);
		if (dir >= keys / 4 && dir <= keys * 3 / 4 - 1) val += getSubmodValue("cross" + suffix, player);

		if (!scrolling) val += getValue(player) + getSubmodValue("reverse" + Std.string(dir), player);
		else val += getSubmodValue("reverse" + suffix, player);

		if (getSubmodValue("unboundedReverse", player) == 0)
		{
			val %= 2;
			if (val > 1) val = 2 - val;
		}

		if (ClientPrefs.downScroll) val = 1 - val;

		return val;
	}

	public function getScrollReversePerc(dir:Int, player:Int):Float return getReverseValue(dir, player) * 100;

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		final swag:Float = (Note.swagWidth * .5);

		final perc:Float = getReverseValue(data, player);
		var shift:Float = MathUtil.scale(perc, 0, 1, 50 + swag, FlxG.height - 50 - swag);
		shift = MathUtil.scale(getSubmodValue("centered", player), 0, 1, shift, FlxG.height / 2);

		final mult:Float = MathUtil.scale(perc, 0, 1, 1, -1);
		pos.y = (shift + (visualDiff * mult));

		return pos;
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = [
			"cross",
			"split",
			"alternate",
			"reverseScroll",
			"crossScroll",
			"splitScroll",
			"alternateScroll",
			"centered",
			"unboundedReverse"
		];

		for (i in 0...modMgr.keys)
		{
			subMods.push('reverse${i}');
		}
		return subMods;
	}
}

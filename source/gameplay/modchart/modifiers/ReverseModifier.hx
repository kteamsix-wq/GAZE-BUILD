package gameplay.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import core.utils.Vector3;
import gameplay.modchart.NoteModifier;
import core.save.ClientPrefs;
import core.utils.MathUtil;
import gameplay.objects.FunkinArrows.Note;

class ReverseModifier extends NoteModifier
{
	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	var modCross:Modifier;
	var modSplit:Modifier;
	var modAlternate:Modifier;
	var modReverseScroll:Modifier;
	var modCrossScroll:Modifier;
	var modSplitScroll:Modifier;
	var modAlternateScroll:Modifier;
	var modCentered:Modifier;
	var modUnboundedReverse:Modifier;
	var dirReverseMods:Array<Modifier> = [];
	var cachedSubmods:Bool = false;

	function initSubmodCache():Void
	{
		if (cachedSubmods) return;
		modCross = submods.get("cross");
		modSplit = submods.get("split");
		modAlternate = submods.get("alternate");
		modReverseScroll = submods.get("reverseScroll");
		modCrossScroll = submods.get("crossScroll");
		modSplitScroll = submods.get("splitScroll");
		modAlternateScroll = submods.get("alternateScroll");
		modCentered = submods.get("centered");
		modUnboundedReverse = submods.get("unboundedReverse");
		dirReverseMods = [];
		for (i in 0...modMgr.keys)
		{
			dirReverseMods.push(submods.get('reverse$i'));
		}
		cachedSubmods = true;
	}

	override function getOrder():Int return REVERSE;

	override function getName():String return 'reverse';

	public inline function getReverseValue(dir:Int, player:Int, scrolling:Bool = false):Float
	{
		if (!cachedSubmods) initSubmodCache();

		final keys:Int = (modMgr.receptors != null && modMgr.receptors.length > player && modMgr.receptors[player] != null) ? modMgr.receptors[player].length : modMgr.keys;
		var val:Float = 0;

		var split = scrolling ? modSplitScroll : modSplit;
		if (split != null && dir >= keys / 2) val += split.getValue(player);

		var alt = scrolling ? modAlternateScroll : modAlternate;
		if (alt != null && dir % 2 == 1) val += alt.getValue(player);

		var cross = scrolling ? modCrossScroll : modCross;
		if (cross != null && dir >= keys / 4 && dir <= keys * 3 / 4 - 1) val += cross.getValue(player);

		if (!scrolling)
		{
			val += getValue(player);
			if (dir >= 0 && dir < dirReverseMods.length && dirReverseMods[dir] != null)
				val += dirReverseMods[dir].getValue(player);
		}
		else if (modReverseScroll != null)
		{
			val += modReverseScroll.getValue(player);
		}

		if (modUnboundedReverse == null || modUnboundedReverse.getValue(player) == 0)
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
		if (!cachedSubmods) initSubmodCache();
		final swag:Float = (Note.swagWidth * .5);

		final perc:Float = getReverseValue(data, player);
		var shift:Float = MathUtil.scale(perc, 0, 1, 50 + swag, FlxG.height - 50 - swag);
		if (modCentered != null)
		{
			var c = modCentered.getValue(player);
			if (c != 0) shift = MathUtil.scale(c, 0, 1, shift, FlxG.height / 2);
		}

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

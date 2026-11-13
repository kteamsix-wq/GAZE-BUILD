package gameplay.modchart.modifiers;

import flixel.FlxSprite;
import core.utils.Vector3;
import gameplay.modchart.NoteModifier;
import core.utils.MathUtil;

class OpponentModifier extends NoteModifier
{
	override function getName():String return 'opponentSwap';

	var modMiddlescroll:Modifier;
	var cachedSubmods:Bool = false;

	override function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (!cachedSubmods)
		{
			modMiddlescroll = submods.get('middlescroll');
			cachedSubmods = true;
		}
		var val = getValue(player);
		if (modMiddlescroll != null)
			val += modMiddlescroll.getValue(player) * 0.5;
		if (val == 0) return pos;
		var nPlayer = Std.int(MathUtil.scale(player, 0, 1, 1, 0));

		var oppX = modMgr.getBaseX(data, nPlayer);
		var plrX = modMgr.getBaseX(data, player);

		var distX = oppX - plrX;

		pos.x = pos.x + distX * val;

		return pos;
	}

	override function getSubmods():Array<String>
	{
		return ['middlescroll'];
	}
}

package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.utils.MathUtil;

class OpponentModifier extends NoteModifier
{
	override function getName():String return 'opponentSwap';

	override function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		var val = getValue(player) + (getSubmodValue('middlescroll', player) * 0.5);
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

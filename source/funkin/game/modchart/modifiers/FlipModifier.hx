package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.objects.FunkinArrows.Note;

class FlipModifier extends NoteModifier
{
	override function getName():String return 'flip';

	override function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (getValue(player) == 0) return pos;

		var distance = (Note.swagWidth * (modMgr.keys * .5 - .5 - data) * 2);
		pos.x += distance * getValue(player);
		return pos;
	}
}

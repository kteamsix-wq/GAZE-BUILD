package gameplay.modchart.modifiers;

import flixel.FlxSprite;
import core.utils.Vector3;
import gameplay.modchart.NoteModifier;
import gameplay.objects.FunkinArrows.Note;

class InvertModifier extends NoteModifier
{
	override function getName():String return 'invert';

	override function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (getValue(player) == 0) return pos;

		var distance = Note.swagWidth * ((data % 2 == 0) ? 1 : -1);
		pos.x += distance * getValue(player);
		return pos;
	}
}

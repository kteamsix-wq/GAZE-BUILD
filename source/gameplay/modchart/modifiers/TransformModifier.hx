package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;

class TransformModifier extends NoteModifier
{
	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	override function getName():String return 'transformX';

	override function getOrder():Int return Modifier.ModifierOrder.LAST;

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		pos.x += getValue(player) + getSubmodValue("transformX-a", player);
		pos.y += getSubmodValue("transformY", player) + getSubmodValue("transformY-a", player);
		pos.z += getSubmodValue('transformZ', player) + getSubmodValue("transformZ-a", player);

		pos.x += getSubmodValue('transform${data}X', player) + getSubmodValue('transform${data}X-a', player);
		pos.y += getSubmodValue('transform${data}Y', player) + getSubmodValue('transform${data}Y-a', player);
		pos.z += getSubmodValue('transform${data}Z', player) + getSubmodValue('transform${data}Z-a', player);

		return pos;
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = ["transformY", "transformZ", "transformX-a", "transformY-a", "transformZ-a"];

		for (i in 0...modMgr.keys)
		{
			subMods.push('transform${i}X');
			subMods.push('transform${i}Y');
			subMods.push('transform${i}Z');
			subMods.push('transform${i}X-a');
			subMods.push('transform${i}Y-a');
			subMods.push('transform${i}Z-a');
		}
		return subMods;
	}
}

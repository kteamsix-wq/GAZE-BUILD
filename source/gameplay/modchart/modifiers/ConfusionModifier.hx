package gameplay.modchart.modifiers;

import core.utils.Vector3;
import gameplay.modchart.NoteModifier;

class ConfusionModifier extends NoteModifier
{
	override function getName():String return 'confusion';

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int):Void
	{
		if (note != null && !note.isSustainNote)
		{
			note.angle = (getValue(player) + getSubmodValue('confusion${note.noteData}', player) + getSubmodValue("noteAngle", player)
				+ getSubmodValue('note${note.noteData}Angle', player));
		}
	}

	override function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int):Void
	{
		if (receptor != null)
		{
			receptor.angle = (getValue(player) + getSubmodValue('confusion${receptor.noteData}', player) + getSubmodValue("receptorAngle", player)
				+ getSubmodValue('receptor${receptor.noteData}Angle', player));
		}
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = ["noteAngle", "receptorAngle"];

		for (i in 0...modMgr.keys)
		{
			subMods.push('note${i}Angle');
			subMods.push('receptor${i}Angle');
			subMods.push('confusion${i}');
		}

		return subMods;
	}
}

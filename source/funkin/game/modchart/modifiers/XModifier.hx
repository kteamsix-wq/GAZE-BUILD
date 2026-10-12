package funkin.game.modchart.modifiers;

import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;

class XModifier extends NoteModifier
{
	override function getName():String return 'xmod';

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function updateNote(beat:Float, daNote:Dynamic, pos:Vector3, player:Int):Void
	{
		if (daNote != null && Reflect.hasField(daNote, "multSpeed"))
		{
			var noteData:Int = Reflect.hasField(daNote, "noteData") ? daNote.noteData : 0;
			var noteMult = getSubmodValue('xmod' + noteData, player);
			if (noteMult == 0) noteMult = 1.0;
			daNote.multSpeed = getValue(player) * noteMult;
		}
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = [];
		for (i in 0...modMgr.keys)
			subMods.push('xmod$i');

		return subMods;
	}
}

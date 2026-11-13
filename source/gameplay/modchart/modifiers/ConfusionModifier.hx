package gameplay.modchart.modifiers;

import core.utils.Vector3;
import gameplay.modchart.NoteModifier;

class ConfusionModifier extends NoteModifier
{
	var modNoteAngle:Modifier;
	var modReceptorAngle:Modifier;
	var dirConfusionMods:Array<Modifier> = [];
	var dirNoteAngleMods:Array<Modifier> = [];
	var dirReceptorAngleMods:Array<Modifier> = [];
	var cachedSubmods:Bool = false;

	function initSubmodCache():Void
	{
		if (cachedSubmods) return;
		modNoteAngle = submods.get("noteAngle");
		modReceptorAngle = submods.get("receptorAngle");
		dirConfusionMods = [];
		dirNoteAngleMods = [];
		dirReceptorAngleMods = [];
		for (i in 0...modMgr.keys)
		{
			dirConfusionMods.push(submods.get('confusion$i'));
			dirNoteAngleMods.push(submods.get('note${i}Angle'));
			dirReceptorAngleMods.push(submods.get('receptor${i}Angle'));
		}
		cachedSubmods = true;
	}

	override function getName():String return 'confusion';

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int):Void
	{
		if (note == null || note.isSustainNote) return;
		if (!cachedSubmods) initSubmodCache();

		var base = getValue(player);
		var data:Int = note.noteData;
		var cDir = (data >= 0 && data < dirConfusionMods.length && dirConfusionMods[data] != null) ? dirConfusionMods[data].getValue(player) : 0.0;
		var nAngle = (modNoteAngle != null) ? modNoteAngle.getValue(player) : 0.0;
		var nDir = (data >= 0 && data < dirNoteAngleMods.length && dirNoteAngleMods[data] != null) ? dirNoteAngleMods[data].getValue(player) : 0.0;

		var total = base + cDir + nAngle + nDir;
		if (total != 0 || note.angle != 0)
			note.angle = total;
	}

	override function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int):Void
	{
		if (receptor == null) return;
		if (!cachedSubmods) initSubmodCache();

		var base = getValue(player);
		var data:Int = receptor.noteData;
		var cDir = (data >= 0 && data < dirConfusionMods.length && dirConfusionMods[data] != null) ? dirConfusionMods[data].getValue(player) : 0.0;
		var rAngle = (modReceptorAngle != null) ? modReceptorAngle.getValue(player) : 0.0;
		var rDir = (data >= 0 && data < dirReceptorAngleMods.length && dirReceptorAngleMods[data] != null) ? dirReceptorAngleMods[data].getValue(player) : 0.0;

		var total = base + cDir + rAngle + rDir;
		if (total != 0 || receptor.angle != 0)
			receptor.angle = total;
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

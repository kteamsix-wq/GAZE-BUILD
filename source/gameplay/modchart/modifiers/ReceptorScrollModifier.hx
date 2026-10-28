package gameplay.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import core.utils.Vector3;
import gameplay.modchart.NoteModifier;
import gameplay.objects.FunkinArrows.Note;
import gameplay.PlayState;
import gameplay.Conductor;

class ReceptorScrollModifier extends NoteModifier
{
	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	var moveSpeed:Float = Conductor.crochet * 3;

	override function getName():String return 'receptorScroll';

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		var diff = timeDiff;
		var sPos = Conductor.songPosition;
		var vDiff = -(-diff - sPos) / moveSpeed;
		var reversed = Math.floor(vDiff) % 2 == 0;

		var startY = pos.y;
		var revPerc = reversed ? 1 - vDiff % 1 : vDiff % 1;
		var upscrollOffset = 50;
		var downscrollOffset = FlxG.height - 50 - Note.swagWidth;

		var endY = upscrollOffset + ((downscrollOffset - Note.swagWidth / 2) * revPerc);

		pos.y = (lerp(startY, endY, getValue(player)) + Note.swagWidth * .5);

		return pos;
	}

	override function updateNote(beat:Float, daNote:Dynamic, pos:Vector3, player:Int):Void
	{
		if (getValue(player) == 0 || daNote == null) return;
		var multSpeed:Float = (Reflect.hasField(daNote, "multSpeed")) ? daNote.multSpeed : 1.0;
		var songSpeed:Float = (PlayState.SONG != null) ? PlayState.SONG.speed : 1.0;
		var speed = songSpeed * multSpeed;

		var timeDiff = (daNote.strumTime - Conductor.songPosition);
		var diff = timeDiff;
		var sPos = Conductor.songPosition;

		var songPos = sPos / moveSpeed;
		var notePos = -(-diff - sPos) / moveSpeed;

		if (Math.floor(songPos) != Math.floor(notePos))
		{
			daNote.alphaMod *= .5;
		}
	}
}

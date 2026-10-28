package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.game.modchart.Modifier.ModifierOrder;
import funkin.utils.MathUtil;

class PerspectiveModifier extends NoteModifier
{
	override function getName():String return 'perspectiveDONTUSE';

	override function getOrder():Int return ModifierOrder.LAST + 100;

	override function shouldExecute(player:Int, val:Float):Bool return true;

	var halfOffset:Vector3 = Vector3.get(FlxG.width / 2, FlxG.height / 2);

	final fov:Float = (Math.PI / 2);
	final near:Float = 0;
	final far:Float = 2;

	public inline function getVector(curZ:Float, pos:Vector3):Vector3
	{
		if (Math.abs(curZ) < FlxMath.EPSILON)
		{
			return pos;
		}
		else
		{
			pos.subtract(halfOffset, pos);

			var oX = pos.x;
			var oY = pos.y;

			pos.put();

			var aspect = 1.0;

			var shit = curZ - 1;
			if (shit > 0) shit = 0;

			var ta = MathUtil.fastTan(fov / 2);
			var x = oX * aspect / ta;
			var y = oY / ta;
			var a = (near + far) / (near - far);
			var b = 2 * near * far / (near - far);
			var z = (a * shit + b);

			var returnedVector = Vector3.get(x / z, y / z, z);
			returnedVector.add(halfOffset, returnedVector);

			return returnedVector;
		}
	}

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		return getVector(pos.z, pos);
	}

	override function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int):Void
	{
		if (receptor != null && Math.abs(pos.z) > FlxMath.EPSILON)
		{
			var s = 1.0 / pos.z;
			receptor.scale.set(receptor.scale.x * s, receptor.scale.y * s);
		}
	}

	override function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int):Void
	{
		if (note != null && Math.abs(pos.z) > FlxMath.EPSILON)
		{
			var s = 1.0 / pos.z;
			note.scale.set(note.scale.x * s, note.scale.y * s);
		}
	}

	override function updateNoteSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash != null && Math.abs(pos.z) > FlxMath.EPSILON)
		{
			var s = 1.0 / pos.z;
			splash.scale.set(splash.scale.x * s, splash.scale.y * s);
		}
	}

	override function updateSustainSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash != null && Math.abs(pos.z) > FlxMath.EPSILON)
		{
			var s = 1.0 / pos.z;
			splash.scale.set(splash.scale.x * s, splash.scale.y * s);
		}
	}
}

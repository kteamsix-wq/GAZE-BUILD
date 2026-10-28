package gameplay.modchart.modifiers;

import flixel.math.FlxPoint;
import core.utils.Vector3;
import gameplay.modchart.NoteModifier;

class ScaleModifier extends NoteModifier
{
	override function getName():String return 'mini';

	override function getOrder():Int return PRE_REVERSE;

	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	inline function getScale(prefix:String, sprite:Dynamic, scale:FlxPoint, data:Int, player:Int):FlxPoint
	{
		var isSus:Bool = false;
		if (sprite != null && Reflect.hasField(sprite, "isSustainNote"))
		{
			isSus = (sprite.isSustainNote && (Reflect.hasField(sprite, "isSustainEnd") ? !sprite.isSustainEnd : false));
		}

		final squish = lerp(1, 2, getSubmodValue("squish", player) + getSubmodValue('squish${data}', player));
		final stretch = lerp(1, .5, getSubmodValue("stretch", player) + getSubmodValue('stretch${data}', player));

		var baseScaleY:Float = (sprite != null && Reflect.hasField(sprite, "baseScale") && sprite.baseScale != null) ? sprite.baseScale.y : 1.0;
		if (isSus)
		{
			scale.y = baseScaleY;
		}
		else
		{
			scale.y *= (1 - getValue(player));
			scale.y *= (1 - getSubmodValue('miniY', player));
			scale.y *= (1 - getSubmodValue('mini${data}Y', player));
			scale.y *= (1 - getSubmodValue('$prefix${data}ScaleY', player));

			scale.y /= squish;
			scale.y /= stretch;
		}

		scale.x *= (1 - getValue(player));
		scale.x *= (1 - getSubmodValue('miniX', player));
		scale.x *= (1 - getSubmodValue('mini${data}X', player));
		scale.x *= (1 - getSubmodValue('$prefix${data}ScaleX', player));

		scale.x *= squish;
		scale.x *= stretch;

		return scale;
	}

	function getObjectScale(obj:Dynamic, prefix:String, player:Int):FlxPoint
	{
		var baseSX:Float = 0.7;
		var baseSY:Float = 0.7;
		if (obj != null && Reflect.hasField(obj, "baseScale") && obj.baseScale != null)
		{
			if (obj.baseScale.x > 0) baseSX = obj.baseScale.x;
			if (obj.baseScale.y > 0) baseSY = obj.baseScale.y;
		}

		var noteData:Int = (obj != null && Reflect.hasField(obj, "noteData")) ? obj.noteData : 0;

		if (getSubmodValue('${prefix}ScaleX', player) > 0 || getSubmodValue('${prefix}ScaleY', player) > 0)
		{
			var scaleX = getSubmodValue('${prefix}ScaleX', player);
			var scaleY = getSubmodValue('${prefix}ScaleY', player);
			if (scaleX == 0) scaleX = baseSX;
			if (scaleY == 0) scaleY = baseSY;

			return getScale(prefix, obj, FlxPoint.weak(scaleX, scaleY), noteData, player);
		}

		return getScale(prefix, obj, FlxPoint.weak(baseSX, baseSY), noteData, player);
	}

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int):Void
	{
		if (note != null && note.scale != null)
		{
			var targetScale = getObjectScale(note, 'note', player);
			note.scale.set(targetScale.x, targetScale.y);
		}
	}

	override function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int):Void
	{
		if (receptor != null && receptor.scale != null)
		{
			var targetScale = getObjectScale(receptor, 'receptor', player);
			receptor.scale.set(targetScale.x, targetScale.y);
		}
	}

	override function updateNoteSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash != null && splash.scale != null)
		{
			var targetScale = getObjectScale(splash, 'noteSplash', player);
			splash.scale.set(targetScale.x, targetScale.y);
		}
	}

	override function updateSustainSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash != null && splash.scale != null)
		{
			var targetScale = getObjectScale(splash, 'sustainSplash', player);
			splash.scale.set(targetScale.x, targetScale.y);
		}
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = [
			"squish",
			"stretch",
			"miniX",
			"miniY",
			"receptorScaleX",
			"receptorScaleY",
			"noteScaleX",
			"noteScaleY",
			"noteSplashScaleX",
			"noteSplashScaleY",
			"sustainSplashScaleX",
			"sustainSplashScaleY"
		];

		for (i in 0...modMgr.keys)
		{
			subMods.push('mini${i}X');
			subMods.push('mini${i}Y');
			subMods.push('squish${i}');
			subMods.push('stretch${i}');
			subMods.push('receptor${i}ScaleX');
			subMods.push('receptor${i}ScaleY');
			subMods.push('note${i}ScaleX');
			subMods.push('note${i}ScaleY');
			subMods.push('noteSplash${i}ScaleX');
			subMods.push('noteSplash${i}ScaleY');
			subMods.push('sustainSplash${i}ScaleX');
			subMods.push('sustainSplash${i}ScaleY');
		}
		return subMods;
	}
}

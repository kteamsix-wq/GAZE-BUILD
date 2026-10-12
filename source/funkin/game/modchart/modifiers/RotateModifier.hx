package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.game.modchart.Modifier;
import funkin.utils.MathUtil;

class RotateModifier extends NoteModifier
{
	override function getName():String return '${prefix}rotateX';

	override function getOrder():Int return Modifier.ModifierOrder.LAST + 2;

	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	public var daOrigin:Vector3;

	var prefix:String;

	public function new(modMgr:ModManager, ?prefix:String = '', ?origin:Vector3, ?parent:Modifier)
	{
		this.prefix = prefix;
		this.daOrigin = origin;
		super(modMgr, parent);
	}

	function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float):Vector3
	{
		var rotateZ = MathUtil.rotate(vec.x, vec.y, zA);
		var offZ = Vector3.get(rotateZ.x, rotateZ.y, vec.z);

		var rotateX = MathUtil.rotate(offZ.z, offZ.y, xA);
		var offX = Vector3.get(offZ.x, rotateX.y, rotateX.x);

		var rotateY = MathUtil.rotate(offX.x, offX.z, yA);
		var offY = Vector3.get(rotateY.x, offX.y, rotateY.y);

		offZ.put();
		offX.put();

		rotateZ.putWeak();
		rotateX.putWeak();
		rotateY.putWeak();

		return offY;
	}

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		var origin:Vector3 = Vector3.get(modMgr.getBaseX(data, player), FlxG.height * 0.5);
		if (daOrigin != null) origin = daOrigin;

		var diff = pos.subtract(origin);
		var scale = FlxG.height;
		diff.z *= scale;
		var out = rotateV3(diff, getValue(player), getSubmodValue('${prefix}rotateY', player), getSubmodValue('${prefix}rotateZ', player));
		out.z /= scale;

		origin.add(out, pos);
		out.put();

		return pos;
	}

	override function getSubmods():Array<String>
	{
		var list = ['${prefix}rotateY', '${prefix}rotateZ'];
		for (i in 0...modMgr.keys)
		{
			list.push('${prefix}rotate${i}X');
			list.push('${prefix}rotate${i}Y');
			list.push('${prefix}rotate${i}Z');
		}

		return list;
	}
}

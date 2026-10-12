package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.game.modchart.Modifier;
import funkin.utils.MathUtil;
import funkin.objects.FunkinArrows.Note;

class LocalRotateModifier extends NoteModifier
{
	override function getName():String return '${prefix}rotateX';

	override function getOrder():Int return Modifier.ModifierOrder.POST_REVERSE;

	inline function lerp(a:Float, b:Float, c:Float):Float
	{
		return a + (b - a) * c;
	}

	var prefix:String;

	public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier)
	{
		this.prefix = prefix;
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
		var x:Float = (FlxG.width * 0.5);
		switch (player)
		{
			case 0:
				x += FlxG.width * 0.5 - Note.swagWidth * (modMgr.keys / 2) - 100;
			case 1:
				x -= FlxG.width * 0.5 - Note.swagWidth * (modMgr.keys / 2) - 100;
		}

		var origin:Vector3 = Vector3.get(x, FlxG.height * 0.5);

		var diff = pos.subtract(origin);
		var scale = FlxG.height;
		diff.z *= scale;

		final vals = Vector3.get(getValue(player), getSubmodValue('${prefix}rotateY', player), getSubmodValue('${prefix}rotateZ', player));

		vals.x += getSubmodValue('${prefix}rotate${data}X', player);
		vals.y += getSubmodValue('${prefix}rotate${data}Y', player);
		vals.z += getSubmodValue('${prefix}rotate${data}Z', player);

		var out = rotateV3(diff, vals.x, vals.y, vals.z);
		out.z /= scale;

		origin.add(out, pos);
		out.put();
		vals.put();

		return pos;
	}

	override function getSubmods():Array<String>
	{
		var returns = ['${prefix}rotateY', '${prefix}rotateZ'];

		for (i in 0...modMgr.keys)
		{
			returns.push('${prefix}rotate${i}X');
			returns.push('${prefix}rotate${i}Y');
			returns.push('${prefix}rotate${i}Z');
		}

		return returns;
	}
}

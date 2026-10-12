package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.Modifier;

class InfinitePathModifier extends PathModifier
{
	public function new(modMgr:ModManager, prefix:String = 'infinite', ?parent:Modifier)
	{
		super(modMgr, prefix, parent);
	}

	override function getMoveSpeed():Float
	{
		return 1850;
	}

	override function getPath():Array<Array<Vector3>>
	{
		var infPath:Array<Vector3> = [];

		final step:Int = 5;

		var r = 0;
		while (r < 360)
		{
			var rad = r * Math.PI / 180;
			infPath.push(Vector3.get(FlxG.width * 0.5 + FlxMath.fastSin(rad) * 600, FlxG.height * 0.5 + FlxMath.fastSin(rad) * FlxMath.fastCos(rad) * 600, 0));

			r += step;
		}

		return [infPath];
	}
}

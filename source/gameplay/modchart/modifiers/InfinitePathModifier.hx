package gameplay.modchart.modifiers;

import flixel.FlxG;
import flixel.math.FlxMath;
import core.utils.Vector3;
import gameplay.modchart.Modifier;

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
			infPath.push(Vector3.get(FlxG.width * 0.5 + Math.sin(rad) * 600, FlxG.height * 0.5 + Math.sin(rad) * Math.cos(rad) * 600, 0));

			r += step;
		}

		return [infPath];
	}
}

package gameplay.objects;
import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.system.Assets;
import core.base.Init;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;

using StringTools;

class Boyfriend extends Character
{
	public var stunned:Bool = false;

	public function new()
		super(true);

	override function update(elapsed:Float)
	{
		if (!debugMode)
		{
			if (getAnimName().startsWith('sing'))
			{
				holdTimer += elapsed;
			}
			else
				holdTimer = 0;

			if (getAnimName().endsWith('miss') && isAnimFinished() && !debugMode)
			{
				playAnim('idle', true, false, 10);
			}

			if (getAnimName() == 'firstDeath' && isAnimFinished())
			{
				playAnim('deathLoop');
			}
		}

		super.update(elapsed);
	}
}


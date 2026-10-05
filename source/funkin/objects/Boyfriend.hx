package funkin.objects;
import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;
import Paths;
import Utils;
import Assets;
import Init;

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


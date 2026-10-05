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

import funkin.objects.FunkinSprites;

using StringTools;

class Checkmark extends FunkinSprites
{
	public function new(x:Float, y:Float)
	{
		super(x, y);
		animOffsets = new Map<String, Array<Dynamic>>();
	}

	override public function update(elapsed:Float)
	{
		if (animation != null)
		{
			if ((animation.finished) && (animation.curAnim.name == 'true'))
				playAnim('true finished');
			if ((animation.finished) && (animation.curAnim.name == 'false'))
				playAnim('false finished');
		}

		super.update(elapsed);
	}
}






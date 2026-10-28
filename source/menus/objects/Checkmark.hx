package menus.objects;
import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.system.Assets;
import core.base.Init;

import core.system.FunkinSprites;

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






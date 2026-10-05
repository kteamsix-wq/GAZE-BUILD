package funkin.objects;

import backend.*;
import funkin.objects.FunkinTransition;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;

class FunkinState extends FlxUIState
{
	override function create()
	{
		super.create();
		
		if (!FlxTransitionableState.skipNextTransIn)
		{
			openSubState(new FunkinTransition(0.5, true));
		}
		FlxTransitionableState.skipNextTransIn = false;
	}
}

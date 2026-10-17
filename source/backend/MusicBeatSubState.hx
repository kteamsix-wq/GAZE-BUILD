package backend;
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
import flixel.FlxSubState;
import backend.Conductor.BPMChangeEvent;

class MusicBeatSubState extends FlxSubState
{
	public function new()
	{
		super();
	}

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		updateCurStep();
		curDecBeat = curDecStep / 4.0;
		curBeat = Math.floor(curDecBeat);

		if (curStep > oldStep && curStep > 0)
		{
			var stepsToCatchUp:Int = curStep - oldStep;
			if (stepsToCatchUp > 12)
			{
				oldStep = curStep - 1;
			}

			for (i in (oldStep + 1)...(curStep + 1))
			{
				curStep = i;
				curDecBeat = curStep / 4.0;
				curBeat = Math.floor(curDecBeat);
				stepHit();
			}
		}

		super.update(elapsed);
	}

	private function updateCurStep():Void
	{
		curDecStep = Conductor.calculateDecStep(Conductor.songPosition);
		curStep = Math.floor(curDecStep);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		// do literally nothing dumbass
	}
}

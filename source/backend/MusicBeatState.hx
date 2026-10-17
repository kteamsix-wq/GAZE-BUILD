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
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import backend.Conductor.BPMChangeEvent;
import funkin.objects.FunkinState;

class MusicBeatState extends FunkinState
{
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	public var curStep:Int = 0;
	public var curBeat:Int = 0;
	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;

	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function create()
	{
		backend.FunkinMemory.init();

		if (transIn != null)
			trace('reg ' + transIn.region);

		super.create();

		FlxG.watch.add(Conductor, "songPosition");
		FlxG.watch.add(this, "curBeat");
		FlxG.watch.add(this, "curStep");
	}

	override function update(elapsed:Float)
	{
		if (!Std.isOfType(this, funkin.states.PlayState) && !Std.isOfType(this, funkin.editors.ChartEditor))
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				Conductor.update(elapsed, FlxG.sound.music);
		}

		super.update(elapsed);
		updateContents();
	}

	public function updateContents()
	{
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (curStep > oldStep)
		{
			var stepsToCatchUp:Int = curStep - oldStep;
			// Prevent freeze / stutter cascade on large lag spike
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
	}

	public function updateBeat():Void
	{
		curDecBeat = curDecStep / 4.0;
		curBeat = Math.floor(curDecBeat);
	}

	public function updateCurStep():Void
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
		// used for updates when beats are hit in classes that extend this one
	}
}

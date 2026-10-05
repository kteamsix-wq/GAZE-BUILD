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

	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function create()
	{
		if ((!Std.isOfType(this, funkin.states.PlayState)) && (!Std.isOfType(this, funkin.editors.ChartEditor)))
		{
			Paths.clearStoredMemory();
			Paths.clearUnusedMemory();
			backend.FunkinMemory.purgeCache(true);
		}

		if (transIn != null)
			trace('reg ' + transIn.region);

		super.create();

		FlxG.watch.add(Conductor, "songPosition");
		FlxG.watch.add(this, "curBeat");
		FlxG.watch.add(this, "curStep");
	}

	override function update(elapsed:Float)
	{
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
			if (curStep > oldStep + 1)
			{
				for (i in (oldStep + 1)...(curStep + 1))
				{
					curStep = i;
					stepHit();
				}
			}
			else
				stepHit();
		}
		else if (curStep < oldStep)
		{
			stepHit();
		}
	}

	public function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
	}

	public function updateCurStep():Void
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (Conductor.songPosition >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
			else
				break;
		}

		curStep = lastChange.stepTime + Math.floor((Conductor.songPosition - lastChange.songTime) / Conductor.stepCrochet);
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

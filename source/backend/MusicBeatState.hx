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
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
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

		var stepC = Conductor.stepCrochet; 
		if (lastChange.bpm > 0) stepC = ((60 / lastChange.bpm) * 1000) / 4; 
		curDecStep = lastChange.stepTime + ((Conductor.songPosition - lastChange.songTime) / stepC);
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

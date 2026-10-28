package core.base;
import gameplay.objects.FunkinArrows;
import editors.*;
import core.system.Paths;
import core.utils.Utils;
import core.system.Assets;
import core.base.Init;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import gameplay.Conductor.BPMChangeEvent;
import core.base.FunkinState;

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
		core.system.FunkinMemory.init();

		if (transIn != null)
			trace('reg ' + transIn.region);

		super.create();

		FlxG.watch.add(Conductor, "songPosition");
		FlxG.watch.add(this, "curBeat");
		FlxG.watch.add(this, "curStep");
	}

	override function update(elapsed:Float)
	{
		if (!Std.isOfType(this, gameplay.PlayState) && !Std.isOfType(this, editors.ChartEditor) && !Std.isOfType(this, editors.CameraEditor))
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

	public static function playSong(nameSong:Dynamic, ?songList:Dynamic, ?difficulty:Null<Int>, ?customReturnState:Dynamic):Void
	{
		gameplay.PlayState.playSong(nameSong, songList, difficulty, customReturnState);
	}

	public static function setReturnState(target:Dynamic):Void
	{
		gameplay.PlayState.setReturnState(target);
	}

	public static function getReturnState():flixel.FlxState
	{
		return gameplay.PlayState.getReturnState();
	}
}

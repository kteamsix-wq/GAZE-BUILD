package gameplay;

import gameplay.chart.Song.SwagSong;
import flixel.sound.FlxSound;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var lastSongPos:Float = 0;
	public static var offset:Float = 0;
	public static var rate:Float = 1.0;
	
	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = (safeFrames / 60) * 1000;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	// Cached state for O(1) BPM change lookup without allocating objects every frame
	public static var currentBPMChangeIndex:Int = 0;
	private static var defaultBPMChange:BPMChangeEvent = {
		stepTime: 0,
		songTime: 0,
		bpm: 100,
		stepCrochet: 150
	};

	// Thresholds for smooth audio synchronization (prevents stutter / jitter)
	public static var maxDesyncThreshold:Float = 150.0; // Snap immediately if desync is larger than this (ms)
	public static var minDesyncThreshold:Float = 15.0; // Smooth drift correction threshold (ms)
	public static var smoothFactor:Float = 4.0; // Speed of gentle drift correction

	/**
	 * Smoothly updates songPosition based on elapsed time and optionally tracks an active audio track.
	 * Applies exponential smoothing to correct audio clock drift without abrupt visual hitches.
	 */
	public static function update(elapsed:Float, ?sound:FlxSound):Void
	{
		var safeElapsed:Float = Math.max(0.0, Math.min(elapsed, 0.1));
		var deltaMs:Float = safeElapsed * 1000.0 * rate;

		if (sound != null && sound.playing && sound.time > 0)
		{
			var targetTime:Float = sound.time + offset;
			songPosition += deltaMs;

			var desync:Float = targetTime - songPosition;
			var absDesync:Float = Math.abs(desync);

			if (absDesync > maxDesyncThreshold)
			{
				// Hard snap on large desync (unpausing, seeking, or extreme lag spike)
				songPosition = targetTime;
			}
			else if (absDesync > minDesyncThreshold)
			{
				// Gentle proportional correction without instant teleportation
				var correction:Float = desync * Math.min(1.0, safeElapsed * smoothFactor);
				songPosition += correction;
			}
		}
		else
		{
			songPosition += deltaMs;
		}

		lastSongPos = songPosition;
	}

	/**
	 * Instantly snaps songPosition to target time and resets smoothing tracking.
	 */
	public static function syncTo(targetTime:Float):Void
	{
		songPosition = targetTime + offset;
		lastSongPos = songPosition;
		resetIndex();
	}

	/**
	 * Resets cached BPM change index.
	 */
	public static inline function resetIndex():Void
	{
		currentBPMChangeIndex = 0;
	}

	public static function mapBPMChanges(song:SwagSong):Void
	{
		bpmChangeMap = [];

		var curBPM:Float = (song != null && song.bpm > 0) ? song.bpm : bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;

		var initSC:Float = ((60 / curBPM) * 1000) / 4;
		defaultBPMChange.bpm = curBPM;
		defaultBPMChange.stepCrochet = initSC;
		defaultBPMChange.stepTime = 0;
		defaultBPMChange.songTime = 0;

		bpmChangeMap.push({
			stepTime: 0,
			songTime: 0,
			bpm: curBPM,
			stepCrochet: initSC
		});

		if (song == null || song.notes == null)
		{
			currentBPMChangeIndex = 0;
			return;
		}

		for (i in 0...song.notes.length)
		{
			if (song.notes[i] == null) continue;

			if (song.notes[i].changeBPM && song.notes[i].bpm > 0 && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var sc:Float = ((60 / curBPM) * 1000) / 4;
				if (totalSteps == 0 && bpmChangeMap.length > 0)
				{
					bpmChangeMap[0].bpm = curBPM;
					bpmChangeMap[0].stepCrochet = sc;
					defaultBPMChange.bpm = curBPM;
					defaultBPMChange.stepCrochet = sc;
				}
				else
				{
					bpmChangeMap.push({
						stepTime: totalSteps,
						songTime: totalPos,
						bpm: curBPM,
						stepCrochet: sc
					});
				}
			}

			var deltaSteps:Int = (song.notes[i].lengthInSteps > 0) ? song.notes[i].lengthInSteps : 16;
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}

		currentBPMChangeIndex = 0;
	}

	public static inline function changeBPM(newBpm:Float, measure:Float = 1.0):Void
	{
		if (newBpm > 0)
		{
			bpm = newBpm;
			crochet = ((60 / bpm) * 1000);
			stepCrochet = (crochet / 4) * measure;
			if (bpmChangeMap == null || bpmChangeMap.length == 0)
			{
				defaultBPMChange.bpm = bpm;
				defaultBPMChange.stepCrochet = stepCrochet;
			}
		}
	}

	/**
	 * Optimized O(1) BPM change lookup without heap allocations.
	 */
	public static function getBPMChangeEvent(time:Float):BPMChangeEvent
	{
		if (bpmChangeMap == null || bpmChangeMap.length == 0)
		{
			defaultBPMChange.bpm = bpm;
			defaultBPMChange.stepCrochet = stepCrochet;
			defaultBPMChange.stepTime = 0;
			defaultBPMChange.songTime = 0;
			currentBPMChangeIndex = 0;
			return defaultBPMChange;
		}

		if (time <= bpmChangeMap[0].songTime)
		{
			currentBPMChangeIndex = 0;
			return bpmChangeMap[0];
		}

		if (currentBPMChangeIndex >= bpmChangeMap.length)
			currentBPMChangeIndex = bpmChangeMap.length - 1;
		if (currentBPMChangeIndex < 0)
			currentBPMChangeIndex = 0;

		// Fast forward if time has moved past current change
		while (currentBPMChangeIndex + 1 < bpmChangeMap.length && time >= bpmChangeMap[currentBPMChangeIndex + 1].songTime)
		{
			currentBPMChangeIndex++;
		}

		// Rewind if time has moved backwards (e.g. seeking / rewinding)
		while (currentBPMChangeIndex > 0 && time < bpmChangeMap[currentBPMChangeIndex].songTime)
		{
			currentBPMChangeIndex--;
		}

		return bpmChangeMap[currentBPMChangeIndex];
	}

	/**
	 * Calculates continuous decimal step from time without allocating objects.
	 */
	public static function calculateDecStep(time:Float):Float
	{
		var change:BPMChangeEvent = getBPMChangeEvent(time);
		var stepC:Float = (change.stepCrochet != null && change.stepCrochet > 0) ? change.stepCrochet : stepCrochet;
		if (stepC <= 0) stepC = stepCrochet;
		return change.stepTime + ((time - change.songTime) / stepC);
	}

	/**
	 * Calculates integer step from time.
	 */
	public static inline function calculateStep(time:Float):Int
	{
		return Math.floor(calculateDecStep(time));
	}

	/**
	 * Calculates continuous decimal beat from decimal step.
	 */
	public static inline function calculateDecBeat(decStep:Float):Float
	{
		return decStep / 4.0;
	}

	/**
	 * Calculates integer beat from decimal step.
	 */
	public static inline function calculateBeat(decStep:Float):Int
	{
		return Math.floor(decStep / 4.0);
	}
}

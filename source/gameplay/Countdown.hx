package gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import core.system.Paths;
import gameplay.Conductor;
import core.base.Init;
import gameplay.PlayState;
import sys.FileSystem;

using StringTools;

/**
 * The countdown step enum, based on Friday Night Funkin' (V-Slice).
 */
enum CountdownStep
{
	BEFORE;
	THREE;
	TWO;
	ONE;
	GO;
	AFTER;
}

/**
 * Modern countdown implementation replicating the official Friday Night Funkin' (V-Slice) system.
 * Handles timing, visual sprites, audio playback, callbacks, and script events.
 */
class Countdown
{
	/**
	 * The current step of the countdown.
	 */
	public static var countdownStep(default, null):CountdownStep = BEFORE;

	/**
	 * Which alternate sound on countdown to use (e.g., 'pixel').
	 */
	public static var soundSuffix:String = '';

	/**
	 * Which alternate graphic on countdown to use (e.g., '-pixel').
	 */
	public static var graphicSuffix:String = '';

	/**
	 * Volume at which to play the countdown audio. Defaults to V-Slice standard 0.6.
	 */
	public static var countdownVolume:Float = 0.6;

	/**
	 * The currently running countdown timer.
	 */
	public static var countdownTimer:FlxTimer = null;

	/**
	 * Custom offset for countdown sprites [x, y].
	 */
	public static var customOffsets:Array<Float> = [0.0, 0.0];

	/**
	 * Tracks the last executed countdown step to prevent duplicate executions.
	 */
	private static var lastExecutedStep:CountdownStep = null;

	/**
	 * Performs the countdown.
	 * Sets the conductor position to -5 beats, plays the countdown graphics and sounds,
	 * dispatches script events, and starts the song on completion.
	 *
	 * @return `false` if the countdown was cancelled by a script, `true` otherwise.
	 */
	public static function performCountdown():Bool
	{
		// Cancel any existing countdown timer without marking countdown as ended
		if (countdownTimer != null)
		{
			countdownTimer.cancel();
			countdownTimer.destroy();
			countdownTimer = null;
		}

		lastExecutedStep = null;
		countdownStep = BEFORE;
		PlayState.swagCounter = -1;

		var cancelled:Bool = propagateCountdownEvent(countdownStep);
		if (cancelled)
		{
			return false;
		}

		if (PlayState.instance != null)
		{
			PlayState.instance.isInCountdown = true;
			PlayState.instance.startedCountdown = true;
			PlayState.instance.startingSong = true;
			PlayState.instance.canPause = true;

			// Position conductor 5 beats before song start
			Conductor.songPosition = -(Conductor.crochet * 5);

			// Initial character dance beat
			PlayState.instance.charactersDance(PlayState.instance.curBeat);
		}

		var stepDuration:Float = (Conductor.crochet > 50 && !Math.isNaN(Conductor.crochet)) ? (Conductor.crochet / 1000) : 0.5;

		// Countdown timer runs 5 times (1 tick per beat)
		countdownTimer = new FlxTimer();
		countdownTimer.start(stepDuration, function(tmr:FlxTimer)
		{
			if (PlayState.instance == null)
			{
				tmr.cancel();
				return;
			}

			countdownStep = decrement(countdownStep);
			PlayState.swagCounter = stepToInt(countdownStep);

			// Prevent duplicate re-triggering of the same step
			if (lastExecutedStep != countdownStep)
			{
				lastExecutedStep = countdownStep;

				// Countdown graphic
				showCountdownGraphic(countdownStep);

				// Countdown sound
				playCountdownSound(countdownStep);

				// Script event propagation
				var isStepCancelled:Bool = propagateCountdownEvent(countdownStep);
				if (isStepCancelled)
				{
					pauseCountdown();
				}
			}

			if (countdownStep == AFTER)
			{
				stopCountdown();
			}
		}, 5);

		return true;
	}

	/**
	 * Advances the countdown to the next step.
	 */
	public static function decrement(step:CountdownStep):CountdownStep
	{
		switch (step)
		{
			case BEFORE:
				return THREE;
			case THREE:
				return TWO;
			case TWO:
				return ONE;
			case ONE:
				return GO;
			case GO:
				return AFTER;
			default:
				return AFTER;
		}
	}

	/**
	 * Maps CountdownStep enum to legacy integer index.
	 */
	public static function stepToInt(step:CountdownStep):Int
	{
		switch (step)
		{
			case BEFORE:
				return -1;
			case THREE:
				return 0;
			case TWO:
				return 1;
			case ONE:
				return 2;
			case GO:
				return 3;
			case AFTER:
				return 4;
		}
	}

	/**
	 * Dispatches countdown script events.
	 *
	 * @return `true` if cancelled by script, `false` otherwise.
	 */
	public static function propagateCountdownEvent(index:CountdownStep):Bool
	{
		if (PlayState.instance == null) return false;

		var stepIndex:Int = stepToInt(index);

		// Trigger general step callback
		PlayState.instance.callOnScripts('onCountdownStep', [index]);
		PlayState.instance.callOnScripts('onCountdownTick', [index, stepIndex]);

		switch (index)
		{
			case BEFORE:
				var ret:Dynamic = PlayState.instance.callOnScripts('onCountdownStart', []);
				if (ret == false) return true;
			case THREE | TWO | ONE | GO:
				var ret:Dynamic = PlayState.instance.callOnScripts('onCountdownStep', [index]);
				if (ret == false) return true;
			case AFTER:
				PlayState.instance.callOnScripts('onCountdownEnd', []);
			default:
				return false;
		}

		return false;
	}

	/**
	 * Pauses the running countdown timer.
	 */
	public static function pauseCountdown():Void
	{
		if (countdownTimer != null && !countdownTimer.finished)
		{
			countdownTimer.active = false;
		}
	}

	/**
	 * Resumes the paused countdown timer.
	 */
	public static function resumeCountdown():Void
	{
		if (countdownTimer != null && !countdownTimer.finished)
		{
			countdownTimer.active = true;
		}
	}

	/**
	 * Cancels and destroys the countdown timer.
	 */
	public static function stopCountdown():Void
	{
		if (countdownTimer != null)
		{
			countdownTimer.cancel();
			countdownTimer.destroy();
			countdownTimer = null;
		}
		countdownStep = AFTER;
		lastExecutedStep = AFTER;
		PlayState.swagCounter = 4;
		if (PlayState.instance != null)
		{
			PlayState.instance.isInCountdown = false;
		}
	}

	/**
	 * Immediately stops the countdown and starts the song.
	 */
	public static function skipCountdown():Void
	{
		stopCountdown();
		countdownStep = AFTER;
		lastExecutedStep = AFTER;
		Conductor.songPosition = 0;
		if (PlayState.instance != null)
		{
			PlayState.instance.isInCountdown = false;
			PlayState.instance.startedCountdown = true;
			PlayState.instance.canPause = true;
			PlayState.instance.startSong();
		}
	}

	/**
	 * Resets the timer if active.
	 */
	public static function resetCountdown():Void
	{
		if (countdownTimer != null)
		{
			countdownTimer.reset();
		}
	}

	/**
	 * Resets countdown state and suffixes to defaults.
	 */
	public static function reset():Void
	{
		countdownStep = BEFORE;
		lastExecutedStep = null;
		soundSuffix = '';
		graphicSuffix = '';
		customOffsets = [0.0, 0.0];
	}

	/**
	 * Resolves and returns the image asset path for the given countdown step.
	 */
	public static function getCountdownGraphicPath(step:CountdownStep):Null<String>
	{
		var graphicName:Null<String> = switch (step)
		{
			case TWO: 'ready';
			case ONE: 'set';
			case GO: 'go';
			default: null;
		};

		if (graphicName == null) return null;

		var style:String = 'default';
		if (graphicSuffix != null && graphicSuffix.length > 0)
			style = graphicSuffix.replace('-', '');
		else if (PlayState.assetModifier == 'pixel')
			style = 'pixel';

		var candidates:Array<String> = [
			'UI/count/' + style + '/' + graphicName,
			'UI/count/' + (style == 'default' ? 'dafault' : style) + '/' + graphicName,
			'UI/countdown/' + style + '/' + graphicName,
			'UI/countdown/' + graphicName,
			'countdown/' + style + '/' + graphicName,
			'countdown/' + graphicName,
			graphicName + (isCountdownSpritePixel(step) ? '-pixel' : '')
		];

		for (cand in candidates)
		{
			var fullPath = Paths.getPath('images/' + cand + '.png', IMAGE);
			if (FileSystem.exists(fullPath))
				return cand;
		}

		return 'UI/count/' + style + '/' + graphicName;
	}

	/**
	 * Resolves and returns the sound asset path for the given countdown step.
	 */
	public static function getCountdownSoundPath(step:CountdownStep):Null<String>
	{
		var soundName:Null<String> = switch (step)
		{
			case THREE: 'introTHREE';
			case TWO: 'introTWO';
			case ONE: 'introONE';
			case GO: 'introGO';
			default: null;
		};

		if (soundName == null) return null;

		var style:String = 'default';
		if (soundSuffix != null && soundSuffix.length > 0)
			style = soundSuffix.replace('-', '');
		else if (PlayState.assetModifier == 'pixel')
			style = 'pixel';

		var candidates:Array<String> = [
			'countdown/' + style + '/' + soundName,
			'countdown/' + soundName,
			'system/countdown/' + style + '/' + soundName,
			'system/countdown/' + soundName,
			soundName + (style == 'pixel' ? '-pixel' : '')
		];

		for (cand in candidates)
		{
			var fullPath = Paths.getPath('sounds/' + cand + '.' + Paths.SOUND_EXT, SOUND);
			if (FileSystem.exists(fullPath))
				return cand;
		}

		return 'countdown/' + style + '/' + soundName;
	}

	/**
	 * Checks whether the current step uses pixel graphics and styling.
	 */
	public static function isCountdownSpritePixel(step:CountdownStep):Bool
	{
		if (graphicSuffix.contains('pixel') || soundSuffix.contains('pixel'))
			return true;
		if (PlayState.assetModifier == 'pixel')
			return true;
		return false;
	}

	/**
	 * Retrieves offsets for the countdown sprite.
	 */
	public static function getCountdownSpriteOffsets(step:CountdownStep):Array<Float>
	{
		return [customOffsets[0], customOffsets[1]];
	}

	/**
	 * Displays the countdown sprite for the current step with V-Slice styling & easing.
	 */
	public static function showCountdownGraphic(index:CountdownStep):Void
	{
		if (index == null || index == THREE || index == BEFORE || index == AFTER) return;
		if (PlayState.instance == null) return;
		if (countdownStep == AFTER) return;

		var assetKey:Null<String> = getCountdownGraphicPath(index);
		if (assetKey == null) return;

		var graphic = Paths.image(assetKey);
		if (graphic == null) return;

		var countdownSprite:FlxSprite = new FlxSprite();
		countdownSprite.loadGraphic(graphic);

		var isPixel:Bool = isCountdownSpritePixel(index);
		if (isPixel)
		{
			countdownSprite.scale.set(6, 6);
			countdownSprite.antialiasing = false;
		}
		else
		{
			countdownSprite.scale.set(1, 1);
			countdownSprite.antialiasing = !Init.trueSettings.get('Disable Antialiasing');
		}

		countdownSprite.updateHitbox();
		countdownSprite.scrollFactor.set(0, 0);
		countdownSprite.cameras = [PlayState.camHUD];
		countdownSprite.screenCenter();

		var offsets = getCountdownSpriteOffsets(index);
		countdownSprite.x += offsets[0];
		countdownSprite.y += offsets[1];

		// V-Slice stepped ease for retro/pixel, cubeInOut for default
		var fadeEase:Float->Float = FlxEase.cubeInOut;
		if (isPixel)
		{
			fadeEase = function(t:Float):Float
			{
				return Math.floor(t * 8) / 8;
			};
		}

		FlxTween.tween(countdownSprite, {alpha: 0}, Conductor.crochet / 1000, {
			ease: fadeEase,
			onComplete: function(twn:FlxTween)
			{
				countdownSprite.destroy();
			}
		});

		PlayState.instance.add(countdownSprite);
	}

	/**
	 * Plays the sound file corresponding to the countdown step.
	 */
	public static function playCountdownSound(step:CountdownStep):Null<FlxSound>
	{
		if (step == null || step == BEFORE || step == AFTER) return null;
		if (countdownStep == AFTER) return null;

		var soundKey:Null<String> = getCountdownSoundPath(step);
		if (soundKey == null) return null;

		var soundAsset = Paths.sound(soundKey);
		if (soundAsset == null) return null;

		return FlxG.sound.play(soundAsset, countdownVolume);
	}
}

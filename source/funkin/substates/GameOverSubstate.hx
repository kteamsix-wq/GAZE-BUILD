package funkin.substates;

import backend.*;
import backend.MusicBeatSubState;
import backend.Conductor;
import funkin.objects.Boyfriend;
import funkin.objects.Character;
import funkin.states.PlayState;
import funkin.states.FreeplayState;
import funkin.states.MainMenuState;
import Paths;
import Utils;
import Init;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;

class GameOverSubstate extends MusicBeatSubState
{
	public static var instance:GameOverSubstate;

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var deathDelay:Float = 0;

	public var boyfriend:Boyfriend;
	var camFollow:FlxObject;
	var isEnding:Bool = false;

	public static function resetVariables()
	{
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		deathDelay = 0;

		var _song:Dynamic = PlayState.SONG;
		if (_song != null)
		{
			if (_song.gameOverChar != null && Std.string(_song.gameOverChar).trim().length > 0)
				characterName = _song.gameOverChar;
			if (_song.gameOverSound != null && Std.string(_song.gameOverSound).trim().length > 0)
				deathSoundName = _song.gameOverSound;
			if (_song.gameOverLoop != null && Std.string(_song.gameOverLoop).trim().length > 0)
				loopSoundName = _song.gameOverLoop;
			if (_song.gameOverEnd != null && Std.string(_song.gameOverEnd).trim().length > 0)
				endSoundName = _song.gameOverEnd;
		}

		if (PlayState.boyfriend != null)
		{
			var pBf = PlayState.boyfriend;
			if (pBf.gameOverChar != null && pBf.gameOverChar.trim().length > 0)
				characterName = pBf.gameOverChar;
			if (pBf.firstDeathSound != null && pBf.firstDeathSound.trim().length > 0)
				deathSoundName = pBf.firstDeathSound;
			if (pBf.loopDeathMusic != null && pBf.loopDeathMusic.trim().length > 0)
				loopSoundName = pBf.loopDeathMusic;
			if (pBf.confirmDeathSound != null && pBf.confirmDeathSound.trim().length > 0)
				endSoundName = pBf.confirmDeathSound;
		}
	}

	public function new(?playStateBoyfriend:Boyfriend = null)
	{
		super();
		this.boyfriend = playStateBoyfriend;
	}

	override function create()
	{
		instance = this;

		Conductor.songPosition = 0;

		if (FlxG.camera != null)
			FlxG.camera.active = true;
		if (PlayState.camGame != null)
			PlayState.camGame.active = true;

		var charToLoad:String = characterName;
		if (charToLoad == null || charToLoad.trim().length == 0)
			charToLoad = 'bf-dead';

		var pBf:Boyfriend = PlayState.boyfriend;

		boyfriend = new Boyfriend();
		boyfriend.adjustPos = false;
		boyfriend.setCharacter(0, 0, charToLoad);

		if (pBf != null)
		{
			var screenPos = pBf.getScreenPosition();
			boyfriend.setPosition(screenPos.x, screenPos.y);
			boyfriend.x += boyfriend.positionArray[0] - pBf.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - pBf.positionArray[1];
		}

		boyfriend.skipDance = true;
		add(boyfriend);

		if (deathSoundName != null && deathSoundName.trim().length > 0)
			FlxG.sound.play(Paths.sound(deathSoundName));

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		FlxG.camera.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			if (boyfriend.animation.curAnim.name == 'firstDeath' && boyfriend.animation.curAnim.finished)
			{
				boyfriend.playAnim('deathLoop');
				coolStartDeath();
			}
		}

		if (controls.ACCEPT)
		{
			if (!isEnding)
			{
				endBullshit();
			}
			else
			{
				// Quick-skip: if player presses enter again while fading, restart immediately
				restartGame();
			}
		}
		else if (controls.BACK && !isEnding)
		{
			FlxG.camera.visible = false;
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();

			PlayState.deaths = 0;
			Utils.resetMenuMusic();

			Main.switchState(this, PlayState.isStoryMode ? new MainMenuState() : new FreeplayState());
		}

		if (!isEnding && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			Conductor.update(elapsed, FlxG.sound.music);
		}
	}

	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.playMusic(Paths.music(loopSoundName), volume);
	}

	var isRestarting:Bool = false;
	var deathTimer:FlxTimer = null;

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			if (boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else
				boyfriend.playAnim('deathLoop', true);

			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();

			FlxG.sound.play(Paths.music(endSoundName));
			deathTimer = new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				deathTimer = null;
				if (!isRestarting && FlxG.camera != null)
				{
					FlxG.camera.fade(FlxColor.BLACK, 1.5, false, function()
					{
						restartGame();
					});
				}
			});
		}
	}

	function restartGame():Void
	{
		if (isRestarting)
			return;
		isRestarting = true;

		if (deathTimer != null)
		{
			deathTimer.cancel();
			deathTimer = null;
		}
		if (FlxG.camera != null)
			FlxG.camera.stopFX();

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		FlxG.resetState();
	}

	override function destroy()
	{
		if (deathTimer != null)
		{
			deathTimer.cancel();
			deathTimer = null;
		}
		instance = null;
		super.destroy();
	}
}

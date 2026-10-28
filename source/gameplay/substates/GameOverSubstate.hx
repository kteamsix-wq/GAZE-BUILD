package gameplay.substates;

import core.base.MusicBeatSubState;
import gameplay.Conductor;
import gameplay.objects.Boyfriend;
import gameplay.objects.Character;
import gameplay.PlayState;
import menus.FreeplayState;
import menus.MainMenuState;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;

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
	public static var deathSoundName:String = 'system/gameover/fnf_loss_sfx';
	public static var loopSoundName:String = 'system/gameover/gameOver';
	public static var endSoundName:String = 'system/gameover/gameOverEnd';
	public static var deathDelay:Float = 0;

	public var boyfriend:Boyfriend;
	var camFollow:FlxObject;
	var isEnding:Bool = false;
	var startedDeathLoop:Bool = false;

	public static function resetVariables()
	{
		characterName = 'bf-dead';
		deathSoundName = 'system/gameover/fnf_loss_sfx';
		loopSoundName = 'system/gameover/gameOver';
		endSoundName = 'system/gameover/gameOverEnd';
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

	private static function resolveGameOverSound(key:String):openfl.media.Sound
	{
		if (key == null || key.trim().length == 0)
			return null;
		var snd = Paths.sound(key);
		if (snd == null && !key.startsWith('system/gameover/'))
			snd = Paths.sound('system/gameover/' + key);
		if (snd == null)
			snd = Paths.music(key);
		if (snd == null && !key.startsWith('system/gameover/'))
			snd = Paths.music('system/gameover/' + key);
		return snd;
	}

	private static function resolveGameOverMusic(key:String):openfl.media.Sound
	{
		if (key == null || key.trim().length == 0)
			return null;
		var mus = Paths.music(key);
		if (mus == null && !key.startsWith('system/gameover/'))
			mus = Paths.music('system/gameover/' + key);
		if (mus == null)
			mus = Paths.sound(key);
		if (mus == null && !key.startsWith('system/gameover/'))
			mus = Paths.sound('system/gameover/' + key);
		return mus;
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

		var deathSnd = resolveGameOverSound(deathSoundName);
		if (deathSnd != null)
			FlxG.sound.play(deathSnd);

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

		if (!isEnding && !startedDeathLoop && boyfriend != null)
		{
			if (boyfriend.getAnimName() == 'deathLoop' || (boyfriend.getAnimName() == 'firstDeath' && boyfriend.isAnimFinished()))
			{
				startedDeathLoop = true;
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
		var loopMus = resolveGameOverMusic(loopSoundName);
		if (loopMus != null)
			FlxG.sound.playMusic(loopMus, volume);
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

			var endSnd = resolveGameOverSound(endSoundName);
			if (endSnd != null)
				FlxG.sound.play(endSnd);
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

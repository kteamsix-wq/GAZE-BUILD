package funkin.substates;

import backend.*;
import funkin.objects.*;
import funkin.states.*;
import Paths;
import Init;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import backend.MusicBeatSubState;
import funkin.objects.Alphabet;

class PauseSubState extends MusicBeatSubState
{
	var pauseMusic:FlxSound;

	var grpMenuShit:FlxTypedGroup<Alphabet>;
	var menuItems:Array<String> = ['Resume', 'Restart Song', 'Exit to menu'];
	var curSelected:Int = 0;

	var levelInfo:FlxText;
	var levelDifficulty:FlxText;
	var blueballedTxt:FlxText;

	public function new(x:Float, y:Float)
	{
		super();

		pauseMusic = new FlxSound().load(Paths.music("system/breakfast"));
		pauseMusic.looped = true;
		pauseMusic.autoDestroy = true;
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		levelInfo = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		levelDifficulty = new FlxText(20, 15 + 32, 0, CoolUtil.difficultyFromNumber(PlayState.storyDifficulty), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font("vcr.ttf"), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		blueballedTxt = new FlxText(20, 15 + 64, 0, "Blueballed: " + PlayState.deaths, 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font("vcr.ttf"), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		levelInfo.alpha = 0;
		levelDifficulty.alpha = 0;
		blueballedTxt.alpha = 0;

		levelInfo.x = FlxG.width + 20;
		levelDifficulty.x = FlxG.width + 20;
		blueballedTxt.x = FlxG.width + 20;

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, x: FlxG.width - (levelInfo.width + 20)}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, x: FlxG.width - (levelDifficulty.width + 20)}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, x: FlxG.width - (blueballedTxt.width + 20)}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, menuItems[i], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpMenuShit.add(songText);
		}

		changeSelection();

		camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP) changeSelection(-1);
		if (downP) changeSelection(1);

		if (accepted)
		{
			pauseMusic.stop();
			FlxG.sound.list.remove(pauseMusic);
			pauseMusic.destroy();

			var daSelected:String = menuItems[curSelected];

			switch (daSelected)
			{
				case "Resume":
					close();
				case "Restart Song":
					Main.switchState(this, new PlayState());
				case "Exit to menu":
					PlayState.deaths = 0;
					Main.switchState(this, new FreeplayState());
			}
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		if (change != 0)
			FlxG.sound.play(Paths.sound('system/scroll'));

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}

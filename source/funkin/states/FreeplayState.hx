package funkin.states;

import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.ColorTween;
import flixel.util.FlxColor;
import openfl.media.Sound;
import sys.FileSystem;
import sys.thread.Mutex;
import sys.thread.Thread;

import backend.HealthIcon;
import backend.MusicBeatState;
import backend.Song;
import backend.Highscore;
import backend.WeekData;
import backend.CoolUtil;
import backend.ChartConverter;
import backend.Timings;
import funkin.objects.Alphabet;
#if desktop
import backend.Discord;
#end

using StringTools;

/**
 * Freeplay state allowing players to pick any unlocked song to play.
 */
class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	public static var curSelected:Int = 0;
	var curSongPlaying:Int = -1;
	public static var curDifficulty:Int = 1;

	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	var songThread:Thread;
	var threadActive:Bool = true;
	var mutex:Mutex;
	var songToPlay:Sound = null;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	private var mainColor = FlxColor.WHITE;
	private var colorTween:FlxTween;
	private var transitioning:Bool = false;
	private var bg:FlxSprite;
	private var scoreBG:FlxSprite;

	private var existingSongs:Array<String> = [];
	private var existingDifficulties:Array<Array<String>> = [];

	override function create()
	{
		super.create();

		mutex = new Mutex();

		var weeks:Array<WeekData> = WeekData.loadWeeks();
		if (weeks.length > 0)
		{
			for (week in weeks)
				for (weekSong in week.songs)
					addSong(weekSong.name, week.weekIndex, weekSong.character, weekSong.color);
		}
		else
		{
			// Keep support for standalone song folders when no week JSON exists.
			for (songFolder in CoolUtil.returnAssetsLibrary('songs', 'assets'))
			{
				if (!hasChart(songFolder, songFolder))
					continue;

				var castSong:backend.Song.SwagSong = Song.loadFromJson(songFolder, songFolder);
				var icon:String = (castSong != null && castSong.player2 != null) ? castSong.player2 : 'gf';
				addSong(songFolder, 1, icon, FlxColor.WHITE);
			}
		}

		#if desktop
		Discord.changePresence('FREEPLAY MENU', 'Main Menu');
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menus/menuDesat'));
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		if (curSelected < 0 || curSelected >= songs.length)
			curSelected = 0;

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			iconArray.push(icon);
			add(icon);
		}

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 30);
		scoreText.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(0, scoreText.y + 36, 0, "", 20);
		diffText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
		add(diffText);

		add(scoreText);

		if (songs.length > 0)
			changeSelection(0, false);
		else
		{
			scoreText.text = 'NO SONGS FOUND';
			diffText.text = 'ADD A JSON TO assets/data/weeks';
		}

		selector = new FlxText();
		selector.size = 40;
		selector.text = ">";
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, songColor:FlxColor)
	{
		if (songName == null || songName.length == 0 || existingSongs.contains(songName.toLowerCase()))
			return;

		var coolDifficultyArray:Array<String> = [];
		for (i in CoolUtil.difficultyArray)
		{
			if (hasChart(songName, songName + '-' + i) || (hasChart(songName, songName) && i == "NORMAL") || hasChart(songName, i))
				coolDifficultyArray.push(i);
		}

		if (coolDifficultyArray.length > 0)
		{
			songs.push(new SongMetadata(songName, weekNum, songCharacter, songColor));
			existingDifficulties.push(coolDifficultyArray);
			existingSongs.push(songName.toLowerCase());
		}
	}

	private function hasChart(songFolder:String, chartName:String):Bool
	{
		if (songFolder == null || chartName == null)
			return false;

		return ChartConverter.findChartPath(songFolder, chartName) != null;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var lerpVal = 1 - Math.exp(-elapsed * 6.0);
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, lerpVal));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		if (!transitioning)
		{
			if (controls.UI_UP_P)
				changeSelection(-1);
			else if (controls.UI_DOWN_P)
				changeSelection(1);

			if (controls.UI_LEFT_P)
				changeDiff(-1);
			if (controls.UI_RIGHT_P)
				changeDiff(1);

			if (controls.BACK)
			{
				transitioning = true;
				threadActive = false;
				if (colorTween != null)
				{
					colorTween.cancel();
					colorTween = null;
				}
				Main.switchState(this, new MainMenuState());
				return;
			}

			if (controls.ACCEPT)
			{
				if (songs.length == 0) return;

				transitioning = true;
				threadActive = false;
				if (colorTween != null)
				{
					colorTween.cancel();
					colorTween = null;
				}

				var formattedSong:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(),
					CoolUtil.difficultyArray.indexOf(existingDifficulties[curSelected][curDifficulty]));

				PlayState.SONG = Song.loadFromJson(formattedSong, songs[curSelected].songName.toLowerCase());
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = CoolUtil.difficultyArray.indexOf(existingDifficulties[curSelected][curDifficulty]);
				PlayState.storyWeek = songs[curSelected].week;

				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();

				Main.switchState(this, new PlayState());
				return;
			}
		}

		scoreText.text = "PERSONAL BEST: " + lerpScore;
		var maxW:Float = Math.max(scoreText.width, diffText.width) + 20;
		scoreBG.setGraphicSize(Std.int(maxW), 70);
		scoreBG.updateHitbox();
		scoreBG.x = FlxG.width - scoreBG.width;
		scoreText.x = FlxG.width - scoreText.width - 10;
		diffText.x = scoreBG.x + (scoreBG.width / 2) - (diffText.width / 2);

		mutex.acquire();
		if (songToPlay != null)
		{
			FlxG.sound.playMusic(songToPlay);
			if (FlxG.sound.music.fadeTween != null)
				FlxG.sound.music.fadeTween.cancel();

			FlxG.sound.music.volume = 0.0;
			FlxG.sound.music.fadeIn(1.0, 0.0, 1.0);
			songToPlay = null;
		}
		mutex.release();
	}

	var lastDifficulty:String;

	function changeDiff(change:Int = 0)
	{
		if (songs.length == 0 || curSelected < 0 || curSelected >= existingDifficulties.length || existingDifficulties[curSelected] == null || existingDifficulties[curSelected].length == 0) return;

		curDifficulty += change;
		if (lastDifficulty != null && change != 0)
			while (existingDifficulties[curSelected][curDifficulty] == lastDifficulty)
				curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = existingDifficulties[curSelected].length - 1;
		if (curDifficulty > existingDifficulties[curSelected].length - 1)
			curDifficulty = 0;

		var songName:String = songs[curSelected].songName;
		var diffName:String = existingDifficulties[curSelected][curDifficulty];
		var diffIdx:Int = CoolUtil.difficultyArray.indexOf(diffName);

		intendedScore = Highscore.getScore(songName, diffIdx);
		var savedRating:Float = Highscore.getRating(songName, diffIdx);
		var savedCombo:String = Highscore.getCombo(songName, diffIdx);

		if (savedCombo == null || savedCombo.trim() == "")
		{
			if (intendedScore > 0)
				savedCombo = "CLEAR";
			else
				savedCombo = "---";
		}
		savedCombo = savedCombo.toUpperCase().trim();

		var accText:String = (intendedScore > 0) ? ('<' + FlxMath.roundDecimal(savedRating, 2) + '%>') : '<0.00%>';
		var fullDiffString:String = '< ' + diffName.toUpperCase() + ' >  [' + savedCombo + ']  ' + accText;

		diffText.clearFormats();
		diffText.text = fullDiffString;

		var comboColor:flixel.util.FlxColor = Timings.getComboColor(savedCombo);
		var comboMarker:String = "[" + savedCombo + "]";
		var comboIdx:Int = fullDiffString.indexOf(comboMarker);
		if (comboIdx != -1)
		{
			diffText.addFormat(new flixel.text.FlxText.FlxTextFormat(comboColor), comboIdx, comboIdx + comboMarker.length);
		}

		lastDifficulty = diffName;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (songs.length == 0) return;

		if (playSound && change != 0)
			FlxG.sound.play(Paths.sound('system/scroll'));

		curSelected += change;
		if (curSelected < 0) curSelected = songs.length - 1;
		if (curSelected >= songs.length) curSelected = 0;

		var newColor:FlxColor = songs[curSelected].songColor;
		if (newColor != mainColor)
		{
			if (colorTween != null)
				colorTween.cancel();
			mainColor = newColor;
			if (bg != null)
			{
				colorTween = FlxTween.color(bg, 0.35, bg.color, mainColor, {
					onComplete: function(twn:FlxTween) {
						colorTween = null;
					}
				});
			}
		}

		for (i in 0...iconArray.length) iconArray[i].alpha = 0.6;
		if (iconArray[curSelected] != null)
			iconArray[curSelected].alpha = 1;

		var itemIndex:Int = 0;
		for (item in grpSongs.members)
		{
			item.targetY = itemIndex - curSelected;
			itemIndex++;
			item.alpha = (item.targetY == 0) ? 1 : 0.6;
		}

		changeDiff();
		changeSongPlaying();
	}

	function changeSongPlaying()
	{
		if (songThread == null)
		{
			songThread = Thread.create(function()
			{
				while (true)
				{
					if (!threadActive) return;

					var index:Null<Int> = Thread.readMessage(false);
					if (index != null)
					{
						var curSongs = songs;
						if (index == curSelected && index != curSongPlaying && curSongs != null && index >= 0 && index < curSongs.length && curSongs[index] != null)
						{
							var songName:String = curSongs[index].songName;
							var inst:Sound = Paths.inst(songName);
							if (index == curSelected && threadActive)
							{
								mutex.acquire();
								songToPlay = inst;
								mutex.release();
								curSongPlaying = curSelected;
							}
						}
					}
					else
					{
						Sys.sleep(0.01);
					}
				}
			});
		}
		songThread.sendMessage(curSelected);
	}

	override function destroy()
	{
		threadActive = false;
		if (colorTween != null)
		{
			colorTween.cancel();
			colorTween = null;
		}
		songToPlay = null;
		songThread = null;
		iconArray = [];
		super.destroy();
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var songColor:FlxColor = FlxColor.WHITE;

	public function new(song:String, week:Int, songCharacter:String, songColor:FlxColor)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.songColor = songColor;
	}
}

package funkin.states;

import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.ColorTween;
import flixel.util.FlxColor;
import backend.HealthIcon;
import lime.utils.Assets;
import backend.MusicBeatState;
import backend.*;
import backend.Song.SwagSong;
import backend.Discord;
import funkin.objects.Alphabet;
import openfl.media.Sound;
import sys.FileSystem;
import sys.thread.Mutex;
import sys.thread.Thread;

using StringTools;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	var curSelected:Int = 0;
	var curSongPlaying:Int = -1;
	var curDifficulty:Int = 1;

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

				var castSong:SwagSong = Song.loadFromJson(songFolder, songFolder);
				var icon:String = (castSong != null && castSong.player2 != null) ? castSong.player2 : 'gf';
				addSong(songFolder, 1, icon, FlxColor.WHITE);
			}
		}

		#if !html5
		Discord.changePresence('FREEPLAY MENU', 'Main Menu');
		#end

		// LOAD CHARACTERS
		bg = new FlxSprite().loadGraphic(Paths.image('menus/menuDesat'));
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);
		}

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - scoreText.width, 0).makeGraphic(Std.int(FlxG.width * 0.35), 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.alignment = CENTER;
		diffText.font = scoreText.font;
		diffText.x = scoreBG.getGraphicMidpoint().x;
		add(diffText);

		add(scoreText);

		if (songs.length > 0)
			changeSelection();
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
			if (hasChart(songName, songName + '-' + i)
				|| (hasChart(songName, songName) && i == "NORMAL"))
				coolDifficultyArray.push(i);

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

		var folder:String = songFolder.toLowerCase();
		var chart:String = chartName.toLowerCase();

		#if sys
		if (backend.Mods.currentModDirectory != null) {
			if (FileSystem.exists('mods/' + backend.Mods.currentModDirectory + '/songs/$folder/$chart.json') ||
				FileSystem.exists('mods/' + backend.Mods.currentModDirectory + '/songs/$folder/chart/chart.json'))
				return true;
		}
		#end

		return FileSystem.exists('assets/songs/$folder/$chart.json')
			|| FileSystem.exists('mods/songs/$folder/$chart.json')
			|| FileSystem.exists('assets/songs/$folder/chart/chart.json')
			|| FileSystem.exists('mods/songs/$folder/chart/chart.json');
	}

	public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>, ?songColor:Array<FlxColor>)
	{
		if (songCharacters == null)
			songCharacters = ['bf'];
		if (songColor == null)
			songColor = [FlxColor.WHITE];

		var num:Array<Int> = [0, 0];
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num[0]], songColor[num[1]]);

			if (songCharacters.length != 1)
				num[0]++;
			if (songColor.length != 1)
				num[1]++;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		FlxTween.color(bg, 0.35, bg.color, mainColor);

		var lerpVal = 1 - Math.exp(-elapsed * 6.0);
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, lerpVal));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP)
			changeSelection(-1);
		else if (downP)
			changeSelection(1);

		if (controls.UI_LEFT_P)
			changeDiff(-1);
		if (controls.UI_RIGHT_P)
			changeDiff(1);

		if (controls.BACK)
		{
			threadActive = false;
			Main.switchState(this, new MainMenuState());
		}

		if (accepted)
		{
			if (songs.length == 0)
				return;

			var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(),
				CoolUtil.difficultyArray.indexOf(existingDifficulties[curSelected][curDifficulty]));

			PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;

			PlayState.storyWeek = songs[curSelected].week;
			//trace('CUR WEEK' + PlayState.storyWeek);

			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();

			threadActive = false;

			Main.switchState(this, new PlayState());
		}

		// Adhere the position of all the things (I'm sorry it was just so ugly before I had to fix it Shubs)
		scoreText.text = "PERSONAL BEST:" + lerpScore;
		scoreText.x = FlxG.width - scoreText.width - 5;
		scoreBG.width = scoreText.width + 8;
		scoreBG.x = FlxG.width - scoreBG.width;
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
		if (songs.length == 0)
			return;

		curDifficulty += change;
		if (lastDifficulty != null && change != 0)
			while (existingDifficulties[curSelected][curDifficulty] == lastDifficulty)
				curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = existingDifficulties[curSelected].length - 1;
		if (curDifficulty > existingDifficulties[curSelected].length - 1)
			curDifficulty = 0;

		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);

		diffText.text = '< ' + existingDifficulties[curSelected][curDifficulty] + ' >';
		lastDifficulty = existingDifficulties[curSelected][curDifficulty];
	}

	function changeSelection(change:Int = 0)
	{
		if (songs.length == 0)
			return;

		FlxG.sound.play(Paths.sound('system/scroll'));

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		// set up color stuffs
		mainColor = songs[curSelected].songColor;

		// song switching stuffs

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
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
					if (!threadActive)
					{
						return;
					}

					var index:Null<Int> = Thread.readMessage(false);
					if (index != null)
					{
						if (index == curSelected && index != curSongPlaying)
						{
							var inst:Sound = Paths.inst(songs[curSelected].songName);

							if (index == curSelected && threadActive)
							{
								mutex.acquire();
								songToPlay = inst;
								mutex.release();

								curSongPlaying = curSelected;
							}
							else trace("Nevermind, skipping " + index);
						}
					}
				}
			});
		}
		songThread.sendMessage(curSelected);
	}
	var playingSongs:Array<FlxSound> = [];
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

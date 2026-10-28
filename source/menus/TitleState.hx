package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;

import backend.MusicBeatState;
import backend.Conductor;
import Paths;
import Utils;
import funkin.objects.Alphabet;
import openfl.Assets;

#if desktop
import backend.Discord;
#end

/**
 * The initial state when launching the game. Handles the introductory 
 * splash screen, logo bumping, and GF dancing before proceeding to MainMenuState.
 */
class TitleState extends MusicBeatState
{
	static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var curWacky:Array<String> = [];

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var titleText:FlxSprite;
	var danceLeft:Bool = false;
	
	var transitioning:Bool = false;
	var skippedIntro:Bool = false;

	override public function create():Void
	{
		super.create();
		controls.setKeyboardScheme(None, false);
		curWacky = FlxG.random.getObject(getIntroTextShit());

		startIntro();
	}

	function startIntro()
	{
		if (!initialized)
		{
			#if desktop
			Discord.changePresence('TITLE SCREEN', 'Main Menu');
			#end
			
			Utils.resetMenuMusic();
		}

		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		logoBl = new FlxSprite(-150, -100);
		logoBl.frames = Paths.getSparrowAtlas('menus/title/logo');
		logoBl.antialiasing = true;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
		gfDance.frames = Paths.getSparrowAtlas('menus/title/gf');
		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.antialiasing = true;
		add(gfDance);
		add(logoBl);

		titleText = new FlxSprite(100, FlxG.height * 0.8);
		titleText.frames = Paths.getSparrowAtlas('menus/title/titleEnter');
		titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		titleText.antialiasing = true;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('menus/title/newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = true;

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var swagGoodArray:Array<Array<String>> = [];
		if (Assets.exists(Paths.txt('introText')))
		{
			var fullText:String = Assets.getText(Paths.txt('introText'));
			var firstArray:Array<String> = fullText.split('\n');

			for (i in firstArray)
				swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transTimer:FlxTimer = null;

	override function update(elapsed:Float)
	{
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
				pressedEnter = true;
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
		if (gamepad != null)
		{
			if (gamepad.justPressed.START || gamepad.justPressed.A) pressedEnter = true;
			#if switch
			if (gamepad.justPressed.B) pressedEnter = true;
			#end
		}

		if (controls.ACCEPT)
			pressedEnter = true;

		// Codename Engine style skip: if already transitioning, pressing enter/space again instantly skips to MainMenuState!
		if (pressedEnter && transitioning && skippedIntro)
		{
			FlxG.camera.stopFX();
			if (transTimer != null)
			{
				transTimer.cancel();
				transTimer.destroy();
				transTimer = null;
			}
			Main.switchState(this, new MainMenuState());
		}

		if (pressedEnter && !transitioning && skippedIntro)
		{
			titleText.animation.play('press');
			FlxG.camera.flash(FlxColor.WHITE, 1);
			FlxG.sound.play(Paths.sound('system/confirm'));

			transitioning = true;

			transTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
			{
				Main.switchState(this, new MainMenuState());
			});
		}

		if ((pressedEnter || FlxG.keys.justPressed.ESCAPE || controls.BACK) && !skippedIntro)
			skipIntro();

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200;
			credGroup.add(money);
			textGroup.add(money);
		}
	}

	function addMoreText(text:String)
	{
		var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
		coolText.screenCenter(X);
		coolText.y += (textGroup.length * 60) + 200;
		credGroup.add(coolText);
		textGroup.add(coolText);
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	override function beatHit()
	{
		super.beatHit();

		logoBl.animation.play('bump');
		danceLeft = !danceLeft;

		if (danceLeft)
			gfDance.animation.play('danceRight');
		else
			gfDance.animation.play('danceLeft');

		switch (curBeat)
		{
			case 1:
				createCoolText(['Asta']);
			case 3:
				addMoreText('present');
			case 4:
				deleteCoolText();
			case 5:
				createCoolText(['Gaze Slice']);
			case 7:
				addMoreText('newgrounds');
				ngSpr.visible = true;
			case 8:
				deleteCoolText();
				ngSpr.visible = false;
			case 9:
				createCoolText([curWacky[0]]);
			case 11:
				addMoreText(curWacky[1]);
			case 12:
				deleteCoolText();
			case 13:
				addMoreText('Friday');
			case 14:
				addMoreText('Night');
			case 15:
				addMoreText('Funkin');
			case 16:
				skipIntro();
		}
	}

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(ngSpr);
			FlxG.camera.flash(FlxColor.WHITE, 2);
			remove(credGroup);
			deleteCoolText();
			skippedIntro = true;
		}
	}
}

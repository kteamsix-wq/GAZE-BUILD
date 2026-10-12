package funkin.states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import backend.MusicBeatState;
import backend.Discord;

/**
 * The main menu screen, handling navigation to different game modes and options.
 */
class MainMenuState extends MusicBeatState
{
	var menuItems:FlxTypedGroup<FlxSprite>;
	var curSelected:Int = 0;
	var lastCurSelected:Int = 0;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var optionShit:Array<String> = ['freeplay', 'options', 'credits'];
	var selectedSomethin:Bool = false;

	override function create()
	{
		super.create();

		Utils.resetMenuMusic();

		#if !html5
		Discord.changePresence('MENU SCREEN', 'Main Menu');
		#end

		persistentUpdate = persistentDraw = true;

		bg = new FlxSprite(-85);
		bg.loadGraphic(Paths.image('menus/menuBG'));
		bg.scrollFactor.set(0, 0.18);
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		magenta = new FlxSprite(-85).loadGraphic(Paths.image('menus/menuDesat'));
		magenta.scrollFactor.set(0, 0.18);
		magenta.setGraphicSize(Std.int(magenta.width * 1.1));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = true;
		magenta.color = 0xFFfd719b;
		add(magenta);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);
		
		for (i in 0...optionShit.length)
		{
			var imgPath = 'menus/main/' + optionShit[i];
			var menuItem:FlxSprite = new FlxSprite(0, 80 + (i * 200));
			menuItem.frames = Paths.getSparrowAtlas(imgPath);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItem.antialiasing = true;
			menuItems.add(menuItem);
		}

		var camLerp = 0.10;
		FlxG.camera.follow(camFollow, null, camLerp);

		updateSelection();



		var versionText:FlxText = new FlxText(5, FlxG.height - 18, 0, "K-Slice v" + Main.gameVersion, 12);
		versionText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.scrollFactor.set();
		add(versionText);
	}

	override function update(elapsed:Float)
	{
		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				curSelected--;
				FlxG.sound.play(Paths.sound('system/scroll'));
			}
			else if (controls.UI_DOWN_P)
			{
				curSelected++;
				FlxG.sound.play(Paths.sound('system/scroll'));
			}

			if (flixel.FlxG.keys.justPressed.TAB)
			{
				Main.switchState(this, new ModsMenuState());
			}

			// Wrap around logic
			if (curSelected < 0)
				curSelected = optionShit.length - 1;
			else if (curSelected >= optionShit.length)
				curSelected = 0;

			if (controls.ACCEPT)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('system/confirm'));

				FlxFlicker.flicker(magenta, 0.8, 0.1, false);

				menuItems.forEach(function(spr:FlxSprite)
				{
					if (curSelected != spr.ID)
					{
						FlxTween.tween(spr, {alpha: 0, x: FlxG.width * 2}, 0.4, {
							ease: FlxEase.quadOut,
							onComplete: function(twn:FlxTween) { spr.kill(); }
						});
					}
					else
					{
						FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
						{
							switch (optionShit[curSelected])
							{
								case 'freeplay':
									Main.switchState(this, new FreeplayState());
								case 'options':
									Main.switchState(this, new OptionsMenuState());
								case 'credits':
									Main.switchState(this, new CreditsState());
							}
						});
					}
				});
			}
		}

		if (curSelected != lastCurSelected)
			updateSelection();

		super.update(elapsed);
	}

	/**
	 * Updates the visually selected item in the menu and camera focus.
	 */
	private function updateSelection():Void
	{
		menuItems.forEach(function(spr:FlxSprite):Void {
			spr.animation.play('idle');
			spr.updateHitbox();
		});

		var curItem:FlxSprite = menuItems.members[curSelected];
		curItem.animation.play('selected');
		curItem.centerOffsets();

		camFollow.setPosition(curItem.getGraphicMidpoint().x, curItem.getGraphicMidpoint().y);

		lastCurSelected = curSelected;
	}
}

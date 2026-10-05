package funkin.states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import backend.MusicBeatState;
import backend.Discord;

using StringTools;

class MainMenuState extends MusicBeatState
{
	var menuItems:FlxTypedGroup<FlxSprite>;
	var curSelected:Int = 0;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var optionShit:Array<String> = ['freeplay', 'options', 'credits'];

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
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		magenta = new FlxSprite(-85).loadGraphic(Paths.image('menus/menuDesat'));
		magenta.scrollFactor.x = 0;
		magenta.scrollFactor.y = 0.18;
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

		menuItems.forEach(function(menuItem:FlxSprite)
		{
			var targetX = menuItem.x;
			if (menuItem.ID % 2 == 0)
				menuItem.x += 1000;
			else
				menuItem.x -= 1000;
			
			FlxTween.tween(menuItem, {x: targetX}, 0.15 + (menuItem.ID * 0.25), {ease: FlxEase.expoInOut});
		});

		var versionShit:FlxText = new FlxText(5, FlxG.height - 18, 0, "K Engine v" + Main.gameVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
	}

	var selectedSomethin:Bool = false;
	override function update(elapsed:Float)
	{
		var up_p = controls.UI_UP_P;
		var down_p = controls.UI_DOWN_P;

		if (!selectedSomethin)
		{
			if (up_p)
			{
				curSelected--;
				FlxG.sound.play(Paths.sound('system/scroll'));
			}
			else if (down_p)
			{
				curSelected++;
				FlxG.sound.play(Paths.sound('system/scroll'));
			}

			if (curSelected < 0)
				curSelected = optionShit.length - 1;
			else if (curSelected >= optionShit.length)
				curSelected = 0;
		}

		if ((controls.ACCEPT) && (!selectedSomethin))
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
						onComplete: function(twn:FlxTween)
						{
							spr.kill();
						}
					});
				}
				else
				{
					FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
					{
						var daChoice:String = optionShit[curSelected];

						switch (daChoice)
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

		if (curSelected != lastCurSelected)
			updateSelection();

		super.update(elapsed);

	}

	var lastCurSelected:Int = 0;

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

package funkin.states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class CreditsState extends MusicBeatState
{
	override function create():Void
	{
		super.create();

		var background = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(background);

		var credits = new FlxText(0, 0, FlxG.width,
			'GAZE\n\nK Engine\n\nThanks for playing', 32);
		credits.setFormat('VCR OSD Mono', 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		credits.screenCenter();
		add(credits);

		var backText = new FlxText(0, FlxG.height - 45, FlxG.width, 'Press BACK to return', 20);
		backText.setFormat('VCR OSD Mono', 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(backText);
	}

	override function update(elapsed:Float):Void
	{
		if (controls.BACK)
			Main.switchState(this, new MainMenuState());

		super.update(elapsed);
	}
}

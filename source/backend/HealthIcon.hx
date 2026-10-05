package backend;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import sys.FileSystem;
import Paths;
import Init;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var initialWidth:Float = 0;
	public var initialHeight:Float = 0;

	private var isPlayer:Bool = false;
	private var char:String = '';

	public var isPixelIcon:Bool = false;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	public function changeIcon(char:String)
	{
		if (this.char == char) return;

		this.char = char;
		var iconPath:String = char;
		var trimmedCharacter:String = char;
		
		if (trimmedCharacter.contains('-'))
			trimmedCharacter = trimmedCharacter.substring(0, trimmedCharacter.indexOf('-'));

		// 1. Try exact character icon
		// 2. Try trimmed character icon (e.g., 'bf-car' -> 'bf')
		// 3. Fallback to 'face'
		if (!FileSystem.exists(Paths.getPath('images/icons/icon-' + iconPath + '.png', IMAGE)))
		{
			iconPath = trimmedCharacter;
			if (!FileSystem.exists(Paths.getPath('images/icons/icon-' + iconPath + '.png', IMAGE)))
			{
				iconPath = 'face';
				trace('Icon for "$char" not found, falling back to "$iconPath"');
			}
		}

		var iconGraphic:FlxGraphic = Paths.image('icons/icon-' + iconPath);
		
		// Auto-calculate frame count based on graphic proportions
		var frameCount:Int = Math.round(iconGraphic.width / iconGraphic.height);
		if (frameCount < 1) frameCount = 1;

		loadGraphic(iconGraphic, true, Std.int(iconGraphic.width / frameCount), iconGraphic.height);

		// Support for 1, 2, or 3 frames (Neutral, Losing, Winning)
		var animationFrames:Array<Int> = [];
		for(i in 0...frameCount) animationFrames.push(i);
		
		animation.add(char, animationFrames, 0, false, isPlayer);
		animation.play(char);

		// Disable antialiasing for pixel characters and respect global setting
		isPixelIcon = char.endsWith('-pixel') || char.startsWith('senpai') || char.startsWith('spirit');
		var disableGlobalAA:Bool = Init.trueSettings.get('Disable Antialiasing') == true;
		antialiasing = !isPixelIcon && !disableGlobalAA;

		initialWidth = width;
		initialHeight = height;

		updateHitbox();
	}

	public dynamic function updateAnim(health:Float)
	{
		if (animation.curAnim == null) return;
		
		var frames:Int = animation.curAnim.frames.length;
		
		if (health < 20)
		{
			if (frames > 1) animation.curAnim.curFrame = 1; // Losing
		}
		else if (health > 80 && frames > 2)
		{
			animation.curAnim.curFrame = 2; // Winning
		}
		else
		{
			animation.curAnim.curFrame = 0; // Neutral
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}
}

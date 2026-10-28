package core.system;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import menus.objects.Checkmark;
import gameplay.PlayState;

/**
 * Assets class manages different asset types and specific sprite generations.
 * It provides static functions to instantiate and configure common game objects.
 */
class Assets
{
	/**
	 * Generates a combo number sprite with appropriate scaling and physics.
	 */
	public static function generateCombo(asset:String, number:String, allSicks:Bool, assetModifier:String = 'base', changeableSkin:String = 'default',
			baseLibrary:String, negative:Bool, createdColor:FlxColor, scoreInt:Int):FlxSprite
	{
		var newSprite:FlxSprite = new FlxSprite().loadGraphic(Paths.image(Utils.returnSkinAsset('num' + number, assetModifier, changeableSkin, baseLibrary)));
		
		newSprite.alpha = 1;
		newSprite.screenCenter();
		newSprite.x = (FlxG.width * 0.55) + (43 * scoreInt) - 90;
		newSprite.y += 120;
		newSprite.color = negative ? createdColor : FlxColor.WHITE;

		if (assetModifier == 'pixel')
		{
			newSprite.setGraphicSize(Std.int(newSprite.width * PlayState.daPixelZoom));
		}
		else
		{
			newSprite.antialiasing = true;
			newSprite.setGraphicSize(Std.int(newSprite.width * 0.5));
		}
		
		newSprite.updateHitbox();
		newSprite.acceleration.y = FlxG.random.int(200, 300);
		newSprite.velocity.y = -FlxG.random.int(140, 160);
		newSprite.velocity.x = FlxG.random.float(-5, 5);

		return newSprite;
	}

	/**
	 * Generates a rating sprite (Sick, Good, Bad, Shit) with physics.
	 */
	public static function generateRating(asset:String, perfectSick:Bool, timing:String, assetModifier:String = 'base', changeableSkin:String = 'default',
			baseLibrary:String):FlxSprite
	{
		var rating:FlxSprite = new FlxSprite().loadGraphic(Paths.image(Utils.returnSkinAsset(asset, assetModifier, changeableSkin, baseLibrary)));
		
		rating.alpha = 1;
		rating.screenCenter();
		rating.x = (FlxG.width * 0.55) - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y = -FlxG.random.int(140, 175);
		rating.velocity.x = -FlxG.random.int(0, 10);

		if (assetModifier == 'pixel')
		{
			rating.setGraphicSize(Std.int(rating.width * PlayState.daPixelZoom * 0.7));
		}
		else
		{
			rating.antialiasing = true;
			rating.setGraphicSize(Std.int(rating.width * 0.7));
		}

		return rating;
	}

	/**
	 * Generates an animated checkmark sprite, typically used in menus.
	 */
	public static function generateCheckmark(x:Float, y:Float, asset:String, assetModifier:String = 'base', changeableSkin:String = 'default',
			baseLibrary:String):Checkmark
	{
		var newCheckmark:Checkmark = new Checkmark(x, y);
		
		newCheckmark.frames = Paths.getSparrowAtlas(Utils.returnSkinAsset(asset, assetModifier, changeableSkin, baseLibrary));
		newCheckmark.antialiasing = true;

		newCheckmark.animation.addByPrefix('false finished', 'uncheckFinished');
		newCheckmark.animation.addByPrefix('false', 'uncheck', 12, false);
		newCheckmark.animation.addByPrefix('true finished', 'checkFinished');
		newCheckmark.animation.addByPrefix('true', 'check', 12, false);
		
		newCheckmark.setGraphicSize(Std.int(newCheckmark.width * 0.7));
		newCheckmark.updateHitbox();

		var offsetByX = 45;
		var offsetByY = 5;
		newCheckmark.addOffset('false', offsetByX, offsetByY);
		newCheckmark.addOffset('true', offsetByX, offsetByY);
		newCheckmark.addOffset('true finished', offsetByX, offsetByY);
		newCheckmark.addOffset('false finished', offsetByX, offsetByY);

		return newCheckmark;
	}
}

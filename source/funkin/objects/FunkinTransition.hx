package funkin.objects;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;

class FunkinTransition extends FlxSubState
{
	private var isTransIn:Bool;
	private var transBlack:FlxSprite;
	private var transGradient:FlxSprite;
	private var transitionTween:FlxTween;
	private var finishCallback:Void->Void;
	private var completed:Bool = false;

	public function new(duration:Float, isTransIn:Bool, ?finishCallback:Void->Void)
	{
		super();

		this.isTransIn = isTransIn;
		this.finishCallback = finishCallback;

		var width:Int = Std.int(FlxG.width * 1.2);
		var height:Int = Std.int(FlxG.height * 1.2);
		var tweenDuration:Float = Math.max(duration, 0.01);

		transGradient = FlxGradient.createGradientFlxSprite(width, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scrollFactor.set();
		transGradient.screenCenter(X);
		transGradient.y = -height;
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(width, height + 600, FlxColor.BLACK);
		transBlack.scrollFactor.set();
		transBlack.screenCenter(X);
		add(transBlack);

		updateBlackPosition();

		var targetY:Float = height + 50;

		transitionTween = FlxTween.tween(transGradient, {y: targetY}, tweenDuration, {
			ease: FlxEase.linear,
			onComplete: function(_:FlxTween):Void
			{
				completeTransition();
			}
		});
	}

	private inline function updateBlackPosition():Void
	{
		if (isTransIn)
			transBlack.y = transGradient.y + transGradient.height - 2;
		else
			transBlack.y = transGradient.y - transBlack.height + 2;
	}

	private function completeTransition():Void
	{
		if (completed)
			return;

		completed = true;

		if (transitionTween != null)
		{
			transitionTween.cancel();
			transitionTween = null;
		}

		if (finishCallback != null)
		{
			var callback = finishCallback;
			finishCallback = null;
			callback();
		}
		
		if (isTransIn)
			close();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!completed)
			updateBlackPosition();
	}

	override function destroy():Void
	{
		if (transitionTween != null)
			transitionTween.cancel();

		transitionTween = null;
		finishCallback = null;
		
		super.destroy();
	}
}

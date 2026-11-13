package core.system;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class FunkinTransition extends FlxSubState
{
	private var isTransIn:Bool;
	private var finishCallback:Void->Void;
	private var completed:Bool = false;
	private var transCamera:FlxCamera;

	// Visual elements
	private var bg:FlxSprite;
	private var runner:FlxSprite;
	private var micStandBG:FlxSprite;
	private var micStandFill:FlxSprite;

	// Animation & positioning
	private var currentProgress:Float = 0.0;
	private var fillRect:FlxRect;
	private var progressTween:FlxTween;
	#if sys
	private var customScript:core.scripting.HScriptHandler;
	#end

	public function new(duration:Float, isTransIn:Bool, ?finishCallback:Void->Void)
	{
		super();

		this.isTransIn = isTransIn;
		this.finishCallback = finishCallback;

		// Dedicated overlay camera so it renders above all game elements
		transCamera = new FlxCamera();
		transCamera.bgColor.alpha = 0;
		FlxG.cameras.add(transCamera, false);
		this.cameras = [transCamera];

		// Solid dark backdrop
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		add(bg);

		// Pick random character between bf and gf
		var chosenChar:String = (FlxG.random != null && FlxG.random.bool(50)) ? 'gf' : 'bf';
		var atlas = Paths.getSparrowAtlas('menus/loading/assets/' + chosenChar);
		if (atlas == null)
			atlas = Paths.getSparrowAtlas('menus/loading/assets/bf');

		// Character running animation
		runner = new FlxSprite();
		if (atlas != null)
		{
			runner.frames = atlas;
			runner.animation.addByPrefix('run', 'run', 24, true);
			runner.animation.play('run');
			runner.antialiasing = true;
		}

		if (chosenChar == 'gf')
			runner.scale.set(0.28, 0.28);
		else
			runner.scale.set(0.35, 0.35);
		runner.updateHitbox();
		runner.scrollFactor.set();

		// Loading bar: mic-stand
		var barGraphic = Paths.image('menus/loading/mic-stand');
		var barScale:Float = 0.45;

		// Mic-stand empty/background track
		micStandBG = new FlxSprite();
		if (barGraphic != null)
		{
			micStandBG.loadGraphic(barGraphic);
			micStandBG.scale.set(barScale, barScale);
			micStandBG.updateHitbox();
			micStandBG.antialiasing = true;
			micStandBG.color = 0xFF222222;
			micStandBG.alpha = 0.4;
		}
		micStandBG.scrollFactor.set();

		// Mic-stand filled/progress track
		micStandFill = new FlxSprite();
		if (barGraphic != null)
		{
			micStandFill.loadGraphic(barGraphic);
			micStandFill.scale.set(barScale, barScale);
			micStandFill.updateHitbox();
			micStandFill.antialiasing = true;
			micStandFill.color = FlxColor.WHITE;
		}
		micStandFill.scrollFactor.set();

		// Position elements in bottom-right corner ("parte direita em baixo")
		var padX:Float = 35;
		var padY:Float = 20;

		micStandBG.x = FlxG.width - micStandBG.width - padX;
		micStandBG.y = FlxG.height - micStandBG.height - padY;

		micStandFill.x = micStandBG.x;
		micStandFill.y = micStandBG.y;

		// Fixed/stationary in the middle of the mic-stand bar
		runner.x = micStandBG.x + (micStandBG.width - runner.width) / 2;
		runner.y = micStandBG.y - runner.height + 15;

		// Add components in proper layering order (no text)
		add(micStandBG);
		add(micStandFill);
		add(runner);

		fillRect = new FlxRect(0, 0, 0, (micStandFill.frameHeight > 0) ? micStandFill.frameHeight : 234);

		#if sys
		loadCustomLoadingScript();
		#end

		if (!isTransIn)
		{
			// TRANSITION OUT: Fade in loading screen and fill progress bar
			bg.alpha = 0;
			runner.alpha = 0;
			micStandBG.alpha = 0;
			micStandFill.alpha = 0;

			FlxTween.tween(bg, {alpha: 1}, 0.2, {ease: FlxEase.quartOut});
			FlxTween.tween(runner, {alpha: 1}, 0.2, {ease: FlxEase.quartOut});
			FlxTween.tween(micStandBG, {alpha: 0.4}, 0.2, {ease: FlxEase.quartOut});
			FlxTween.tween(micStandFill, {alpha: 1}, 0.2, {ease: FlxEase.quartOut});

			var tweenDuration:Float = Math.max(duration, 0.65);
			progressTween = FlxTween.num(0.0, 1.0, tweenDuration, {
				ease: FlxEase.quadOut,
				onUpdate: function(t:FlxTween)
				{
					updateProgress(t.percent);
				},
				onComplete: function(_)
				{
					updateProgress(1.0);
					completeTransition();
				}
			});
		}
		else
		{
			// TRANSITION IN: Already at target state, full progress, smoothly fade out
			updateProgress(1.0);
			bg.alpha = 1;
			runner.alpha = 1;
			micStandBG.alpha = 0.4;
			micStandFill.alpha = 1;

			var fadeTime:Float = Math.max(duration * 0.7, 0.35);
			FlxTween.tween(bg, {alpha: 0}, fadeTime, {ease: FlxEase.cubeOut});
			FlxTween.tween(runner, {alpha: 0}, fadeTime, {ease: FlxEase.cubeOut});
			FlxTween.tween(micStandBG, {alpha: 0}, fadeTime, {ease: FlxEase.cubeOut});
			FlxTween.tween(micStandFill, {alpha: 0}, fadeTime, {
				ease: FlxEase.cubeOut,
				onComplete: function(_)
				{
					completeTransition();
				}
			});
		}
	}

	#if sys
	private function loadCustomLoadingScript():Void
	{
		var scriptCandidates:Array<String> = [
			'data/scripts/loading.hxc',
			'data/scripts/loading.hx',
			'scripts/loading.hxc',
			'scripts/loading.hx'
		];

		var foundPath:String = null;
		for (candidate in scriptCandidates)
		{
			var p = Paths.getPath(candidate, TEXT);
			if (sys.FileSystem.exists(p))
			{
				foundPath = p;
				break;
			}
		}

		if (foundPath != null && sys.FileSystem.exists(foundPath))
		{
			try
			{
				customScript = new core.scripting.HScriptHandler(foundPath);
				customScript.setVar("transition", this);
				customScript.setVar("isTransIn", isTransIn);
				customScript.setVar("runner", runner);
				customScript.setVar("micStandBG", micStandBG);
				customScript.setVar("micStandFill", micStandFill);
				customScript.setVar("bg", bg);
				customScript.call("create", []);
				customScript.call("onCreate", []);
			}
			catch (e:Dynamic)
			{
				trace("Error initializing loading script: " + e);
			}
		}
	}
	#end

	public function updateProgress(p:Float):Void
	{
		currentProgress = FlxMath.bound(p, 0.0, 1.0);

		if (micStandFill != null && micStandFill.graphic != null && fillRect != null)
		{
			var clipW:Float = micStandFill.frameWidth * currentProgress;
			fillRect.set(0, 0, clipW, micStandFill.frameHeight);
			micStandFill.clipRect = fillRect;
		}

		#if sys
		if (customScript != null && customScript.active)
		{
			customScript.call("onProgress", [currentProgress]);
		}
		#end
	}

	private function completeTransition():Void
	{
		if (completed)
			return;

		completed = true;

		if (progressTween != null)
		{
			progressTween.cancel();
			progressTween = null;
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

		#if sys
		if (customScript != null && customScript.active)
		{
			customScript.call("update", [elapsed]);
			customScript.call("onUpdate", [elapsed]);
		}
		#end
	}

	override function destroy():Void
	{
		if (progressTween != null)
		{
			progressTween.cancel();
			progressTween = null;
		}

		#if sys
		if (customScript != null)
		{
			try { customScript.call("onDestroy", []); } catch(e:Dynamic) {}
			customScript.destroy();
			customScript = null;
		}
		#end

		finishCallback = null;

		if (fillRect != null)
		{
			fillRect.put();
			fillRect = null;
		}

		if (transCamera != null)
		{
			FlxG.cameras.remove(transCamera);
			transCamera.destroy();
			transCamera = null;
		}

		super.destroy();
	}
}

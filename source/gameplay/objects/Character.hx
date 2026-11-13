package gameplay.objects;
import core.system.Paths;
import core.utils.Utils;
import core.system.Assets;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import core.system.FunkinSprites;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

typedef CharacterAnim = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Float>;
}

typedef CharacterFile = {
	var animations:Array<CharacterAnim>;
	var image:String;
	@:optional var scale:Null<Float>;
	@:optional var sing_duration:Null<Float>;
	@:optional var healthicon:String;
	@:optional var icon_offsets:Array<Float>;
	@:optional var icon_suffix:String;
	@:optional var icon_animations:Array<CharacterAnim>;
	@:optional var icon_scale:Null<Float>;
	
	@:optional var position:Array<Float>;
	@:optional var camera_position:Array<Float>;
	
	@:optional var flip_x:Null<Bool>;
	@:optional var no_antialiasing:Null<Bool>;
	@:optional var healthbar_colors:Array<Int>;
	
	@:optional var quickDancer:Null<Bool>;

	@:optional var gameOverChar:String;
	@:optional var firstDeath:String;
	@:optional var loopDeath:String;
	@:optional var confirmDeath:String;
	@:optional var firstDeathSound:String;
	@:optional var loopDeathMusic:String;
	@:optional var confirmDeathSound:String;

	@:optional var vocals_file:String;
	@:optional var vocalsFile:String;
}

typedef CharacterData =
{
	var offsetX:Float;
	var offsetY:Float;
	var camOffsetX:Float;
	var camOffsetY:Float;
	var quickDancer:Bool;
}

class Character extends FunkinSprites
{
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;
	public var singDuration:Float = 4;
	
	public var healthIcon:String = 'face';
	public var iconOffsets:Array<Float> = [0, 0];
	public var iconSuffix:String = '';
	public var iconAnimations:Array<CharacterAnim> = null;
	public var iconScale:Float = 1.0;
	public var healthColorArray:Array<Int> = [161, 161, 161];
	
	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var gameOverChar:String = 'bf-dead';
	public var firstDeathAnim:String = 'firstDeath';
	public var loopDeathAnim:String = 'deathLoop';
	public var confirmDeathAnim:String = 'deathConfirm';
	public var firstDeathSound:String = 'gameover/fnf_loss_sfx';
	public var loopDeathMusic:String = 'gameover/gameOver';
	public var confirmDeathSound:String = 'gameover/gameOverEnd';

	public var characterData:CharacterData;
	public var adjustPos:Bool = true;
	public var skipDance:Bool = false;
	public var vocalsFile:String = null;
	public var specialAnim:Bool = false;
	public var animLocked:Bool = false;
	public var ignoreArrows:Bool = false;

	public function new(?isPlayer:Bool = false)
	{
		super(x, y);
		this.isPlayer = isPlayer;
	}

	public function setCharacter(x:Float, y:Float, character:String):Character
	{
		curCharacter = character;
		antialiasing = true;
		scale.set(1, 1);
		updateHitbox();
		animOffsets = new Map<String, Array<Dynamic>>();

		characterData = {
			offsetY: 0,
			offsetX: 0,
			camOffsetY: 0,
			camOffsetX: 0,
			quickDancer: false
		};

		var jsonPath = Paths.getPath('data/char/' + curCharacter + '.json', TEXT);
		
		//trace('Checking jsonPath: ' + jsonPath);
		if (sys.FileSystem.exists(jsonPath))
		{
			var rawJson = sys.io.File.getContent(jsonPath);
			var json:CharacterFile = haxe.Json.parse(rawJson);
			return loadCharacterFile(json, x, y);
		}
		else
		{
			// Fallback to legacy TXT parser or hardcoded if JSON doesn't exist
			var fileNew = curCharacter + 'Anims';
			if (sys.FileSystem.exists(Paths.offsetTxt(fileNew)))
			{
				var characterAnims:Array<String> = CoolUtil.coolTextFile(Paths.offsetTxt(fileNew));
				var characterName:String = characterAnims[0].trim();
				loadOptimizedSparrow('characters/$characterName');
				for (i in 1...characterAnims.length)
				{
					var getterArray:Array<Array<String>> = CoolUtil.getAnimsFromTxt(Paths.offsetTxt(fileNew));
					animation.addByPrefix(getterArray[i][0], getterArray[i][1].trim(), 24, false);
				}
			}
			else
			{
				// Hardcoded BF & GF fallback if absolutely no file is found
				if (curCharacter == 'gf')
				{
					loadOptimizedSparrow('characters/GF_assets');
					animation.addByPrefix('singLEFT', 'GF left note', 24, false);
					animation.addByPrefix('singRIGHT', 'GF Right Note', 24, false);
					animation.addByPrefix('singUP', 'GF Up Note', 24, false);
					animation.addByPrefix('singDOWN', 'GF Down Note', 24, false);
					animation.addByIndices('sad', 'gf sad', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "", 24, false);
					animation.addByIndices('danceLeft', 'GF Dancing Beat', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
					animation.addByIndices('danceRight', 'GF Dancing Beat', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
					animation.addByIndices('hairBlow', "GF Dancing Beat Hair blowing", [0, 1, 2, 3], "", 24);
					animation.addByIndices('hairFall', "GF Dancing Beat Hair Landing", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], "", 24, false);
					animation.addByPrefix('scared', 'GF FEAR', 24);
				}
				else
				{
					trace("Could not find character JSON! Falling back to bf...");
					if (curCharacter != 'bf')
						return setCharacter(x, y, 'bf');
					else
						return this;
				}
			}
			
			// Legacy offsets
			if (sys.FileSystem.exists(Paths.offsetTxt(curCharacter + 'Offsets')))
			{
				var getterArray:Array<Array<String>> = CoolUtil.getOffsetsFromTxt(Paths.offsetTxt(curCharacter + 'Offsets'));
				for (i in 0...getterArray.length)
				{
					addOffset(getterArray[i][0], Std.parseInt(getterArray[i][1]), Std.parseInt(getterArray[i][2]));
				}
			}
		}

		if (isPlayer)
		{
			flipX = !flipX;
			if (!curCharacter.startsWith('bf'))
				flipLeftRight();
		}
		else if (curCharacter.startsWith('bf'))
			flipLeftRight();

		if (adjustPos)
		{
			this.x = x + characterData.offsetX;
			this.y = y + (characterData.offsetY - (frameHeight * scale.y));
		}
		else
		{
			this.x = x + characterData.offsetX;
			this.y = y + characterData.offsetY;
		}

		dance();
		updateHitbox();

		if (adjustPos)
		{
			this.x = x + characterData.offsetX;
			this.y = y + (characterData.offsetY - (frameHeight * scale.y));
		}
		else
		{
			this.x = x + characterData.offsetX;
			this.y = y + characterData.offsetY;
		}

		return this;
	}

	public function loadCharacterFile(json:CharacterFile, x:Float, y:Float):Character
	{
		animOffsets = new Map<String, Array<Dynamic>>();
		if (animation != null)
			animation.destroyAnimations();
		antialiasing = true;

		characterData = {
			offsetY: 0,
			offsetX: 0,
			camOffsetY: 0,
			camOffsetX: 0,
			quickDancer: false
		};

		var animJson = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		if (sys.FileSystem.exists(animJson)) {
			Paths.initFlxAnimate();
			try {
				var animPath = Paths.getPath('images/' + json.image, TEXT);
				this.frames = animate.FlxAnimateFrames.fromAnimate(animPath);
				if (this.frames == null) {
					FlxG.log.warn('FlxAnimateFrames returned null for ' + animPath + ', falling back to Sparrow');
					loadOptimizedSparrow(json.image);
				} else {
					try {
						this.anim.addBySymbol('idle', 'BF idle dance', 24, false);
					} catch(e:Dynamic) {}
				}
			} catch(e:Dynamic) {
				FlxG.log.error('Failed to load Animate character atlas for "' + json.image + '": ' + e);
				loadOptimizedSparrow(json.image);
			}
		} else {
			loadOptimizedSparrow(json.image);
		}
		
		var newScale:Float = (json.scale != null) ? json.scale : 1.0;
		scale.set(newScale, newScale);
		updateHitbox();
		
		if (json.position != null)
		{
			characterData.offsetX = json.position[0];
			characterData.offsetY = json.position[1];
			positionArray = json.position;
		}
		if (json.camera_position != null)
		{
			characterData.camOffsetX = json.camera_position[0];
			characterData.camOffsetY = json.camera_position[1];
			cameraPosition = json.camera_position;
		}
		
		if (json.flip_x == true)
			flipX = true;
		else
			flipX = false;

		if (json.no_antialiasing == true)
			antialiasing = false;
		else
			antialiasing = true;
			
		if (json.healthicon != null && json.healthicon.length > 0)
			healthIcon = json.healthicon;
		if (json.icon_offsets != null && json.icon_offsets.length >= 2)
			iconOffsets = [json.icon_offsets[0], json.icon_offsets[1]];
		else
			iconOffsets = [0, 0];
		if (json.icon_suffix != null)
			iconSuffix = json.icon_suffix;
		else
			iconSuffix = '';
		if (json.icon_animations != null)
			iconAnimations = json.icon_animations;
		else
			iconAnimations = null;
		if (json.icon_scale != null && json.icon_scale > 0)
			iconScale = json.icon_scale;
		else
			iconScale = 1.0;
		if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;
			
		if (json.sing_duration != null && json.sing_duration > 0)
			singDuration = json.sing_duration;
			
		if (json.quickDancer == true)
			characterData.quickDancer = true;

		if (json.gameOverChar != null)
			gameOverChar = json.gameOverChar;
		if (json.firstDeath != null)
			firstDeathAnim = json.firstDeath;
		if (json.loopDeath != null)
			loopDeathAnim = json.loopDeath;
		if (json.confirmDeath != null)
			confirmDeathAnim = json.confirmDeath;
		if (json.firstDeathSound != null)
			firstDeathSound = json.firstDeathSound;
		if (json.loopDeathMusic != null)
			loopDeathMusic = json.loopDeathMusic;
		if (json.confirmDeathSound != null)
			confirmDeathSound = json.confirmDeathSound;
			
		if (json.vocals_file != null && json.vocals_file.length > 0)
			vocalsFile = json.vocals_file;
		else if (json.vocalsFile != null && json.vocalsFile.length > 0)
			vocalsFile = json.vocalsFile;
		else
			vocalsFile = null;
			
		if (json.animations != null && json.animations.length > 0)
		{
			for (anim in json.animations)
			{
				addAnimationFromData(anim);
			}
		}

		if (isPlayer)
		{
			flipX = !flipX;
			if (!curCharacter.startsWith('bf'))
				flipLeftRight();
		}
		else if (curCharacter.startsWith('bf'))
			flipLeftRight();

		if (adjustPos)
		{
			this.x = x + characterData.offsetX;
			this.y = y + (characterData.offsetY - (frameHeight * scale.y));
		}
		else
		{
			this.x = x + characterData.offsetX;
			this.y = y + characterData.offsetY;
		}

		dance();
		updateHitbox();

		if (adjustPos)
		{
			this.x = x + characterData.offsetX;
			this.y = y + (characterData.offsetY - (frameHeight * scale.y));
		}
		else
		{
			this.x = x + characterData.offsetX;
			this.y = y + characterData.offsetY;
		}

		return this;
	}

	public function addAnimationFromData(anim:CharacterAnim)
	{
		var animAnim:String = anim.anim;
		var animName:String = anim.name;
		var animFps:Int = anim.fps;
		var animLoop:Bool = anim.loop;
		var animIndices:Array<Int> = anim.indices;
		
		if (animIndices != null && animIndices.length > 0)
		{
			if (this.frames != null && (this.frames is animate.FlxAnimateFrames))
			{
				var cleanName:String = animName;
				while(cleanName.length > 0 && StringTools.isSpace(cleanName, cleanName.length - 1) == false && (cleanName.charCodeAt(cleanName.length - 1) >= 48 && cleanName.charCodeAt(cleanName.length - 1) <= 57))
				{
					cleanName = cleanName.substring(0, cleanName.length - 1);
				}
				
				if (this.anim.findFrameLabelIndices(cleanName).length > 0) {
					this.anim.addByFrameLabelIndices(animAnim, cleanName, animIndices, animFps, animLoop);
				} else {
					this.anim.addBySymbolIndices(animAnim, cleanName, animIndices, animFps, animLoop);
				}
			}
			else
				animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
		}
		else
		{
			if (this.frames != null && (this.frames is animate.FlxAnimateFrames))
			{
				var cleanName:String = animName;
				while(cleanName.length > 0 && StringTools.isSpace(cleanName, cleanName.length - 1) == false && (cleanName.charCodeAt(cleanName.length - 1) >= 48 && cleanName.charCodeAt(cleanName.length - 1) <= 57))
				{
					cleanName = cleanName.substring(0, cleanName.length - 1);
				}
				if (this.anim.findFrameLabelIndices(cleanName).length > 0) {
					this.anim.addByFrameLabel(animAnim, cleanName, animFps, animLoop);
				} else {
					this.anim.addBySymbol(animAnim, cleanName, animFps, animLoop);
				}
			}
			else
				animation.addByPrefix(animAnim, animName, animFps, animLoop);
		}
		
		if (anim.offsets != null && anim.offsets.length > 1)
			addOffset(animAnim, anim.offsets[0], anim.offsets[1]);
		else
			addOffset(animAnim, 0, 0);
	}

	override function update(elapsed:Float)
	{
		if (!debugMode)
		{
			if (getAnimName().startsWith('sing'))
			{
				holdTimer += elapsed;
			}

			var dadVar:Float = singDuration;
			if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001 && !isPlayer && !animLocked)
			{
				dance();
				holdTimer = 0;
			}
		}

		var curCharSimplified:String = simplifyCharacter();
		switch (curCharSimplified)
		{
			case 'gf':
				if (!animLocked)
				{
					if (getAnimName() == 'hairFall' && isAnimFinished())
						playAnim('danceRight');
					if (getAnimName().startsWith('sad') && isAnimFinished())
						playAnim('danceLeft');
				}
		}

		if (isAnimFinished() && getAnimName() == 'idle')
		{
			if (hasAnimation('idlePost'))
				playAnim('idlePost', true, false, 0);
		}

		if (ignoreArrows && isAnimFinished())
		{
			ignoreArrows = false;
		}

		if (specialAnim && !animLocked && isAnimFinished())
		{
			specialAnim = false;
			dance(true);
		}

		super.update(elapsed);
	}

	private var danced:Bool = false;

	public function dance(?forced:Bool = false)
	{
		if (forced)
		{
			specialAnim = false;
			animLocked = false;
			ignoreArrows = false;
		}

		if (!debugMode && !skipDance && (!specialAnim || forced) && (!animLocked || forced) && (!ignoreArrows || forced))
		{
			var curCharSimplified:String = simplifyCharacter();
			switch (curCharSimplified)
			{
				case 'gf':
					if (getAnimName() == '' || ((!getAnimName().startsWith('hair')) && (!getAnimName().startsWith('sad'))))
					{
						danced = !danced;

						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
				default:
					if (hasAnimation('danceLeft') && hasAnimation('danceRight'))
					{
						danced = !danced;
						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
					else
						playAnim('idle', forced);
			}
		}
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (ignoreArrows && !isAnimFinished() && (AnimName.startsWith('sing') || AnimName.startsWith('miss')))
			return;

		if (ignoreArrows && isAnimFinished())
			ignoreArrows = false;

		if (hasAnimation(AnimName))
			super.playAnim(AnimName, Force, Reversed, Frame);

		if (AnimName.startsWith('sing') || AnimName.startsWith('miss'))
			holdTimer = 0;

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function simplifyCharacter():String
	{
		var base = curCharacter;

		if (base.contains('-'))
			base = base.substring(0, base.indexOf('-'));
		return base;
	}

	function flipLeftRight():Void
	{
		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null)
		{
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames = oldRight;
		}

		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames = oldMiss;
		}
		
		if (animOffsets.exists('singLEFT') && animOffsets.exists('singRIGHT'))
		{
			var temp = animOffsets.get('singLEFT');
			animOffsets.set('singLEFT', animOffsets.get('singRIGHT'));
			animOffsets.set('singRIGHT', temp);
		}
		if (animOffsets.exists('singLEFTmiss') && animOffsets.exists('singRIGHTmiss'))
		{
			var temp = animOffsets.get('singLEFTmiss');
			animOffsets.set('singLEFTmiss', animOffsets.get('singRIGHTmiss'));
			animOffsets.set('singRIGHTmiss', temp);
		}
	}
}

























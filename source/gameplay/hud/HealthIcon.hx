package gameplay.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.util.FlxColor;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import core.system.Paths;
import core.base.Init;
import gameplay.objects.Character;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

typedef IconAnimData = {
	var anim:String;
	var name:String;
	@:optional var fps:Null<Int>;
	@:optional var loop:Null<Bool>;
	@:optional var indices:Array<Int>;
	@:optional var offsets:Array<Float>;
}

typedef IconFileData = {
	@:optional var suffix:String;
	@:optional var offsets:Array<Float>;
	@:optional var scale:Null<Float>;
	@:optional var no_antialiasing:Null<Bool>;
	@:optional var flip_x:Null<Bool>;
	@:optional var animations:Array<IconAnimData>;
}

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var initialWidth:Float = 0;
	public var initialHeight:Float = 0;

	public var isPlayer(default, set):Bool = false;

	function set_isPlayer(val:Bool):Bool
	{
		isPlayer = val;
		fairFlipX = isPlayer;
		flipX = fairFlipX;
		return val;
	}
	public var char:String = '';

	public var isPixelIcon:Bool = false;
	public var isAnimated:Bool = false;

	// Health bar offsets: [offsetX, offsetY]
	public var iconOffsets:Array<Float> = [0, 0];
	public var iconSuffix:String = '';
	public var iconScale:Float = 1.0;
	public var fairFlipX:Bool = false;

	// Per-animation offsets (like Character animOffsets)
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public var curAnimName:String = '';

	public var hasNeutral:Bool = false;
	public var hasLosing:Bool = false;
	public var hasWinning:Bool = false;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char != null ? char : 'bf');
		scrollFactor.set();
	}

	public static function checkXmlExists(cleanKey:String):Bool
	{
		if (cleanKey == null || cleanKey.length == 0) return false;
		if (cleanKey.startsWith('images/'))
			cleanKey = cleanKey.substring(7);
		if (cleanKey.toLowerCase().endsWith('.xml'))
			cleanKey = cleanKey.substr(0, cleanKey.length - 4);

		var xmlPath:String = Paths.getPath('images/$cleanKey.xml', TEXT);
		#if sys
		if (xmlPath != null && FileSystem.exists(xmlPath))
			return true;
		var altPath:String = Paths.file('images/$cleanKey.xml');
		if (altPath != null && FileSystem.exists(altPath))
			return true;
		#else
		if (xmlPath != null && OpenFlAssets.exists(xmlPath, TEXT))
			return true;
		#end
		return false;
	}

	public static function findAtlasKey(candidate:String):String
	{
		if (candidate == null || candidate.trim().length == 0) return null;
		var searchKeys:Array<String> = [
			'UI/icons/' + candidate,
			'icons/' + candidate,
			candidate
		];
		for (key in searchKeys)
		{
			if (checkXmlExists(key) && Paths.imageExists(key))
				return key;
		}
		return null;
	}

	public static function findIconJsonPath(candidate:String):String
	{
		if (candidate == null || candidate.trim().length == 0) return null;
		var searchPaths:Array<String> = [
			'images/UI/icons/' + candidate + '.json',
			'images/icons/' + candidate + '.json',
			'data/icons/' + candidate + '.json',
			'images/' + candidate + '.json'
		];
		for (p in searchPaths)
		{
			var resolved = Paths.getPath(p, TEXT);
			#if sys
			if (resolved != null && FileSystem.exists(resolved))
				return resolved;
			#else
			if (resolved != null && OpenFlAssets.exists(resolved, TEXT))
				return resolved;
			#end
		}
		return null;
	}

	public function changeIcon(char:String, ?characterRef:Character)
	{
		if (char == null || char.trim().length == 0)
			char = 'bf';

		this.char = char;
		animOffsets = new Map<String, Array<Float>>();
		curAnimName = '';
		hasNeutral = false;
		hasLosing = false;
		hasWinning = false;
		isAnimated = false;
		iconScale = 1.0;
		iconOffsets = [0, 0];
		iconSuffix = '';

		fairFlipX = isPlayer;
		flipX = fairFlipX;

		var trimmedCharacter:String = char;
		var dashIndex:Int = trimmedCharacter.indexOf('-');
		var underIndex:Int = trimmedCharacter.indexOf('_');
		if (dashIndex != -1 && underIndex != -1)
			trimmedCharacter = trimmedCharacter.substring(0, Std.int(Math.min(dashIndex, underIndex)));
		else if (dashIndex != -1)
			trimmedCharacter = trimmedCharacter.substring(0, dashIndex);
		else if (underIndex != -1)
			trimmedCharacter = trimmedCharacter.substring(0, underIndex);

		var candidateNames:Array<String> = [
			char,
			'icon-' + char,
			trimmedCharacter,
			'icon-' + trimmedCharacter
		];

		var loadedCharJson:CharacterFile = null;
		var loadedFileConfig:IconFileData = null;

		if (characterRef != null)
		{
			if (characterRef.iconOffsets != null && characterRef.iconOffsets.length >= 2)
				iconOffsets = [characterRef.iconOffsets[0], characterRef.iconOffsets[1]];
			if (characterRef.iconSuffix != null && characterRef.iconSuffix.length > 0)
				iconSuffix = characterRef.iconSuffix;
			if (characterRef.iconScale > 0)
				iconScale = characterRef.iconScale;
		}
		else
		{
			var charJsonPath = Paths.getPath('data/char/' + char + '.json', TEXT);
			#if sys
			if (FileSystem.exists(charJsonPath))
			{
				try {
					var raw = File.getContent(charJsonPath);
					loadedCharJson = haxe.Json.parse(raw);
				} catch(e:Dynamic) {}
			}
			#end
			if (loadedCharJson != null)
			{
				if (loadedCharJson.icon_offsets != null && loadedCharJson.icon_offsets.length >= 2)
					iconOffsets = [loadedCharJson.icon_offsets[0], loadedCharJson.icon_offsets[1]];
				if (loadedCharJson.icon_suffix != null)
					iconSuffix = loadedCharJson.icon_suffix;
				if (loadedCharJson.icon_scale != null && loadedCharJson.icon_scale > 0)
					iconScale = loadedCharJson.icon_scale;
			}
		}

		for (cand in candidateNames)
		{
			var jsonPath = findIconJsonPath(cand);
			if (jsonPath != null)
			{
				try {
					#if sys
					var raw = File.getContent(jsonPath);
					#else
					var raw = OpenFlAssets.getText(jsonPath);
					#end
					loadedFileConfig = haxe.Json.parse(raw);
					if (loadedFileConfig != null)
					{
						if (loadedFileConfig.offsets != null && loadedFileConfig.offsets.length >= 2)
							iconOffsets = [loadedFileConfig.offsets[0], loadedFileConfig.offsets[1]];
						if (loadedFileConfig.suffix != null)
							iconSuffix = loadedFileConfig.suffix;
						if (loadedFileConfig.scale != null && loadedFileConfig.scale > 0)
							iconScale = loadedFileConfig.scale;
						if (loadedFileConfig.flip_x != null)
							flipX = loadedFileConfig.flip_x;
						break;
					}
				} catch(e:Dynamic) {}
			}
		}

		// Check for Sparrow Atlas XML
		var atlasKey:String = null;
		for (cand in candidateNames)
		{
			var found = findAtlasKey(cand);
			if (found != null)
			{
				atlasKey = found;
				isAnimated = true;
				break;
			}
		}

		if (isAnimated && atlasKey != null)
		{
			frames = Paths.getSparrowAtlas(atlasKey);
			if (frames == null || frames.frames == null || frames.frames.length == 0)
			{
				isAnimated = false;
			}
			else
			{
				var explicitAnims:Array<Dynamic> = null;
				if (loadedFileConfig != null && loadedFileConfig.animations != null && loadedFileConfig.animations.length > 0)
					explicitAnims = loadedFileConfig.animations;
				else if (characterRef != null && characterRef.iconAnimations != null && characterRef.iconAnimations.length > 0)
					explicitAnims = characterRef.iconAnimations;
				else if (loadedCharJson != null && loadedCharJson.icon_animations != null && loadedCharJson.icon_animations.length > 0)
					explicitAnims = loadedCharJson.icon_animations;

				if (explicitAnims != null && explicitAnims.length > 0)
					applyIconAnimations(explicitAnims);
				else
					autoSetupAnimations(iconSuffix);

				isPixelIcon = char.endsWith('-pixel') || char.startsWith('senpai') || char.startsWith('spirit');
				if (loadedFileConfig != null && loadedFileConfig.no_antialiasing == true)
					isPixelIcon = true;
				var disableGlobalAA:Bool = Init.trueSettings.get('Disable Antialiasing') == true;
				antialiasing = !isPixelIcon && !disableGlobalAA;

				scale.set(iconScale, iconScale);
				updateHitbox();
				initialWidth = width;
				initialHeight = height;
				return;
			}
		}

		// Fallback to static icon graphic
		var staticCandidates:Array<String> = [
			char,
			'icon-' + char,
			trimmedCharacter,
			'icon-' + trimmedCharacter,
			'bf',
			'icon-bf',
			'face',
			'icon-face'
		];

		var iconGraphic:FlxGraphic = null;
		for (candidate in staticCandidates)
		{
			if (candidate == null || candidate.trim().length == 0) continue;
			if (Paths.imageExists('UI/icons/' + candidate))
			{
				iconGraphic = Paths.image('UI/icons/' + candidate);
				if (iconGraphic != null)
					break;
			}
			else if (Paths.imageExists('icons/' + candidate))
			{
				iconGraphic = Paths.image('icons/' + candidate);
				if (iconGraphic != null)
					break;
			}
		}

		if (iconGraphic == null)
		{
			iconGraphic = Paths.image('UI/icons/bf');
			if (iconGraphic == null)
				iconGraphic = Paths.image('UI/icons/face');
		}

		if (iconGraphic == null)
		{
			FlxG.log.warn('Could not find health icon for "$char", creating fallback graphic');
			iconGraphic = FlxG.bitmap.create(150, 150, FlxColor.GRAY, false, 'icon-fallback');
		}

		var frameCount:Int = 1;
		if (iconGraphic != null && iconGraphic.height > 0)
		{
			frameCount = Math.round(iconGraphic.width / iconGraphic.height);
			if (frameCount < 1) frameCount = 1;
		}

		var frameWidth:Int = (iconGraphic != null) ? Std.int(iconGraphic.width / frameCount) : 150;
		var frameHeight:Int = (iconGraphic != null) ? iconGraphic.height : 150;

		loadGraphic(iconGraphic, true, frameWidth, frameHeight);

		var animationFrames:Array<Int> = [];
		for (i in 0...frameCount) animationFrames.push(i);

		animation.add(char, animationFrames, 0, false, false);
		animation.play(char);

		isPixelIcon = char.endsWith('-pixel') || char.startsWith('senpai') || char.startsWith('spirit');
		var disableGlobalAA:Bool = Init.trueSettings.get('Disable Antialiasing') == true;
		antialiasing = !isPixelIcon && !disableGlobalAA;

		scale.set(iconScale, iconScale);
		initialWidth = width;
		initialHeight = height;

		updateHitbox();
	}

	public function autoSetupAnimations(suffix:String = ''):Void
	{
		if (frames == null || frames.frames == null) return;

		var uniquePrefixes:Array<String> = [];
		for (f in frames.frames)
		{
			if (f == null || f.name == null) continue;
			var prefix = stripFrameNumbers(f.name);
			if (prefix.length > 0 && !uniquePrefixes.contains(prefix))
				uniquePrefixes.push(prefix);
		}

		if (uniquePrefixes.length == 0) return;

		var cleanSuffix:String = (suffix != null) ? suffix.trim() : '';
		if (cleanSuffix.length > 0)
			this.iconSuffix = cleanSuffix;

		var neutralMatch:String = findBestMatch(uniquePrefixes, ["neutral", "idle", "normal"], cleanSuffix);
		var losingMatch:String = findBestMatch(uniquePrefixes, ["losing", "lose", "defeat", "danger", "dead"], cleanSuffix);
		var winningMatch:String = findBestMatch(uniquePrefixes, ["winning", "win", "victory"], cleanSuffix);

		if (neutralMatch != null)
		{
			animation.addByPrefix('neutral', neutralMatch, 24, true);
			hasNeutral = true;
		}
		if (losingMatch != null)
		{
			animation.addByPrefix('losing', losingMatch, 24, true);
			hasLosing = true;
		}
		if (winningMatch != null)
		{
			animation.addByPrefix('winning', winningMatch, 24, true);
			hasWinning = true;
		}

		// Fallback: if no neutral matched, use the first available prefix
		if (!hasNeutral && uniquePrefixes.length > 0)
		{
			var first = uniquePrefixes[0];
			animation.addByPrefix('neutral', first, 24, true);
			hasNeutral = true;
		}

		playAnim(hasNeutral ? 'neutral' : uniquePrefixes[0], true);
	}

	public static function stripFrameNumbers(name:String):String
	{
		if (name == null) return '';
		var i:Int = name.length - 1;
		while (i >= 0 && name.charCodeAt(i) >= 48 && name.charCodeAt(i) <= 57)
		{
			i--;
		}
		return name.substring(0, i + 1);
	}

	public static function findBestMatch(prefixes:Array<String>, patterns:Array<String>, suffix:String):String
	{
		var s:String = (suffix != null) ? suffix.trim().toLowerCase() : '';

		// 1. Direct patterns with suffix
		if (s.length > 0)
		{
			for (p in patterns)
			{
				var candidates:Array<String> = [
					p + s,
					p + "-" + s,
					p + "_" + s,
					p + " " + s,
					s + p,
					s + "-" + p,
					s + "_" + p,
					s + " " + p
				];
				for (c in candidates)
				{
					for (prefix in prefixes)
					{
						if (prefix.toLowerCase() == c)
							return prefix;
					}
				}
			}

			// Contains pattern AND suffix
			for (p in patterns)
			{
				for (prefix in prefixes)
				{
					var lower = prefix.toLowerCase();
					if (lower.indexOf(p) != -1 && lower.indexOf(s) != -1)
						return prefix;
				}
			}
		}

		// 2. Starts with pattern
		for (p in patterns)
		{
			for (prefix in prefixes)
			{
				var lower = prefix.toLowerCase();
				if (lower.startsWith(p))
					return prefix;
			}
		}

		// 3. Contains pattern
		for (p in patterns)
		{
			for (prefix in prefixes)
			{
				var lower = prefix.toLowerCase();
				if (lower.indexOf(p) != -1)
					return prefix;
			}
		}

		return null;
	}

	public function applyIconAnimations(anims:Array<Dynamic>):Void
	{
		if (anims == null || frames == null) return;
		for (a in anims)
		{
			if (a == null || a.anim == null || a.name == null) continue;
			var animName:String = a.anim;
			var prefixName:String = a.name;
			var fps:Int = (a.fps != null && a.fps > 0) ? a.fps : 24;
			var loop:Bool = (a.loop != null) ? a.loop : true;

			if (a.indices != null && Std.isOfType(a.indices, Array) && (cast a.indices : Array<Dynamic>).length > 0)
			{
				var ind:Array<Int> = cast a.indices;
				animation.addByIndices(animName, prefixName, ind, "", fps, loop);
			}
			else
			{
				animation.addByPrefix(animName, prefixName, fps, loop);
			}

			if (a.offsets != null && Std.isOfType(a.offsets, Array) && (cast a.offsets : Array<Dynamic>).length >= 2)
			{
				var off:Array<Dynamic> = cast a.offsets;
				addOffset(animName, off[0], off[1]);
			}
			else
			{
				addOffset(animName, 0, 0);
			}

			if (animName == 'neutral' || animName == 'idle') hasNeutral = true;
			if (animName == 'losing' || animName == 'lose') hasLosing = true;
			if (animName == 'winning' || animName == 'win') hasWinning = true;
		}

		if (hasNeutral)
			playAnim('neutral');
		else if (animation.getNameList() != null && animation.getNameList().length > 0)
			playAnim(animation.getNameList()[0]);
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets.set(name, [x, y]);
	}

	public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if (animation.getByName(animName) == null)
			return;

		curAnimName = animName;
		if (animation.curAnim == null || animation.curAnim.name != animName || force)
		{
			animation.play(animName, force, reversed, frame);
		}
		updateHitbox();
	}

	override public function updateHitbox():Void
	{
		super.updateHitbox();
		if (curAnimName != null && animOffsets.exists(curAnimName))
		{
			var daOffset = animOffsets.get(curAnimName);
			if (daOffset != null && daOffset.length >= 2)
			{
				offset.x += daOffset[0];
				offset.y += daOffset[1];
			}
		}
	}

	public function getAnimList():Array<String>
	{
		var list:Array<String> = [];
		if (animation != null && animation.getNameList() != null)
		{
			for (name in animation.getNameList())
				list.push(name);
		}
		return list;
	}

	public function hasAnimation(name:String):Bool
	{
		return animation != null && animation.getByName(name) != null;
	}

	public function copyFromCharacter(character:Character):Void
	{
		if (character == null) return;
		this.isPlayer = character.isPlayer;
		if (character.iconOffsets != null && character.iconOffsets.length >= 2)
		{
			iconOffsets[0] = character.iconOffsets[0];
			iconOffsets[1] = character.iconOffsets[1];
		}
		if (character.iconSuffix != null && character.iconSuffix.length > 0)
		{
			iconSuffix = character.iconSuffix;
		}
		if (character.iconScale > 0)
		{
			iconScale = character.iconScale;
			scale.set(iconScale, iconScale);
			updateHitbox();
		}
		if (isAnimated && character.iconAnimations != null && character.iconAnimations.length > 0)
		{
			applyIconAnimations(character.iconAnimations);
		}
	}

	public dynamic function updateAnim(health:Float)
	{
		if (!isAnimated)
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
			return;
		}

		if (health < 20 && hasLosing)
		{
			playAnim('losing');
		}
		else if (health > 80 && hasWinning)
		{
			playAnim('winning');
		}
		else if (hasNeutral)
		{
			playAnim('neutral');
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10 + iconOffsets[0], sprTracker.y - 30 + iconOffsets[1]);
	}
}

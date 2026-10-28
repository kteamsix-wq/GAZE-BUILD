package funkin.objects;
import Assets;
import backend.*;
import backend.Conductor;
import backend.Section.SwagSection;
import backend.Timings;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import funkin.editors.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.objects.FunkinSprites;
import funkin.objects.FunkinArrows.UIStaticArrow;
import funkin.objects.FunkinArrows.Strumline;
import funkin.states.*;
import funkin.states.PlayState;
import funkin.substates.*;
import Init;
import Paths;
import Utils;

using StringTools;

class FunkinArrows
{
	public static var availableNoteSkins:Array<String> = null;

	public static function getAvailableNoteSkins(forceRefresh:Bool = false):Array<String>
	{
		if (availableNoteSkins != null && !forceRefresh)
			return availableNoteSkins;

		var skins:Array<String> = [];
		var map:Map<String, Bool> = new Map();

		#if sys
		var searchDirs:Array<String> = ['assets/images/UI/notes'];
		if (backend.Mods.currentModDirectory != null && backend.Mods.currentModDirectory.length > 0)
			searchDirs.push('mods/' + backend.Mods.currentModDirectory + '/images/UI/notes');

		for (dir in searchDirs)
		{
			if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
			{
				for (file in sys.FileSystem.readDirectory(dir))
				{
					var full = dir + '/' + file;
					if (sys.FileSystem.isDirectory(full))
					{
						if (!map.exists(file))
						{
							map.set(file, true);
							skins.push(file);
						}
					}
				}
			}
		}
		#end

		if (!map.exists('default'))
			skins.unshift('default');
		else
		{
			skins.remove('default');
			skins.unshift('default');
		}

		availableNoteSkins = skins;
		return skins;
	}

	public static function getSkinFromType(type:Dynamic):String
	{
		if (type == null) return 'default';
		if (Std.isOfType(type, String))
		{
			var s:String = cast(type, String).trim();
			if (s == '' || s == '0' || s == 'default') return 'default';
			return s;
		}
		if (Std.isOfType(type, Int) || Std.isOfType(type, Float))
		{
			var i:Int = Std.int(type);
			var skins = getAvailableNoteSkins();
			if (i > 0 && i < skins.length) return skins[i];
			return 'default';
		}
		return 'default';
	}

	public static var receptorSkinCache:Map<String, Bool> = new Map();

	public static function skinHasReceptors(skin:String):Bool
	{
		if (skin == 'pixel' || skin == 'default') return true;
		if (receptorSkinCache.exists(skin)) return receptorSkinCache.get(skin);

		#if sys
		var xmlPath = Paths.getPath('images/UI/notes/' + skin + '/note.xml', TEXT);
		if (sys.FileSystem.exists(xmlPath))
		{
			try
			{
				var content = sys.io.File.getContent(xmlPath);
				var has = (content.indexOf('arrowUP') != -1 || content.indexOf('arrowDOWN') != -1 || content.indexOf('arrowLEFT') != -1 || content.indexOf('arrowRIGHT') != -1);
				receptorSkinCache.set(skin, has);
				return has;
			}
			catch (e) {}
		}
		#end
		receptorSkinCache.set(skin, false);
		return false;
	}

	public static function getNoteAtlas(skin:String):FlxAtlasFrames
	{
		var path = 'UI/notes/' + skin + '/note';
		#if sys
		var filePath = Paths.getPath('images/' + path + '.png', IMAGE);
		if (!sys.FileSystem.exists(filePath))
		{
			path = 'UI/notes/default/note';
		}
		#end

		var atlas = Paths.getSparrowAtlas(path);
		if ((atlas == null || atlas.frames == null || atlas.frames.length == 0) && path != 'UI/notes/default/note')
		{
			atlas = Paths.getSparrowAtlas('UI/notes/default/note');
		}
		return atlas;
	}

	public static function getSplashAtlas(skinAsset:String):FlxAtlasFrames
	{
		#if sys
		var filePath = Paths.getPath('images/' + skinAsset + '.png', IMAGE);
		if (!sys.FileSystem.exists(filePath))
		{
			skinAsset = 'UI/notes/default/splash';
		}
		#end

		var atlas = Paths.getSparrowAtlas(skinAsset);
		if ((atlas == null || atlas.frames == null || atlas.frames.length == 0) && skinAsset != 'UI/notes/default/splash')
		{
			atlas = Paths.getSparrowAtlas('UI/notes/default/splash');
		}
		return atlas;
	}

	public static function preloadSkins():Void
	{
		var skins = getAvailableNoteSkins();
		for (s in skins)
		{
			if (s != 'pixel')
				getNoteAtlas(s);
		}
	}

	public static var globalOffsets:Map<String, Dynamic> = new Map();

	public static function loadOffsets(skin:String) {
		if (globalOffsets.exists(skin)) return;
		var path = Paths.getPath('images/UI/notes/' + skin + '/offsets.json', TEXT);
		if (sys.FileSystem.exists(path)) {
			try {
				globalOffsets.set(skin, haxe.Json.parse(sys.io.File.getContent(path)));
			} catch(e) {}
		} else {
			globalOffsets.set(skin, null);
		}
	}

	public static function getOffset(skin:String, type:String, lane:Int = 0):Array<Float> {
		if (!globalOffsets.exists(skin)) loadOffsets(skin);
		var data = globalOffsets.get(skin);
		if (data != null && Reflect.hasField(data, type)) {
			var field:Array<Dynamic> = Reflect.field(data, type);
			if (field != null && field.length > 0) {
				if (Std.isOfType(field[0], Array)) {
					var laneArr:Array<Dynamic> = field[lane % 4];
					if (laneArr != null && laneArr.length >= 2)
						return [Std.parseFloat(Std.string(laneArr[0])), Std.parseFloat(Std.string(laneArr[1]))];
				} else if (field.length >= 2) {
					return [Std.parseFloat(Std.string(field[0])), Std.parseFloat(Std.string(field[1]))];
				}
			}
		}
		return [0, 0];
	}

	public static function generateUIArrows(x:Float, y:Float, ?staticArrowType:Int = 0, assetModifier:String, skin:String = 'default'):UIStaticArrow
	{
		var newStaticArrow:UIStaticArrow = new UIStaticArrow(x, y, staticArrowType);
		newStaticArrow.loadSkin(skin, assetModifier);
		return newStaticArrow;
	}

	/**
		Notes!
	**/
	public static function generateArrow(assetModifier:String, strumTime:Float, noteData:Int, noteType:Dynamic, noteAlt:Float, ?isSustainNote:Bool = false, ?prevNote:Note = null):Note
	{
		var newNote:Note;
		var changeableSkin:String = Init.trueSettings.get("Note Skin");
		var skin:String = FunkinArrows.getSkinFromType(noteType);
		if (skin == 'default' && changeableSkin != null && changeableSkin != 'default' && !changeableSkin.startsWith('quant'))
			skin = changeableSkin;

		if (changeableSkin != null && changeableSkin.startsWith('quant'))
			newNote = Note.returnQuantNote(assetModifier, strumTime, noteData, noteType, noteAlt, isSustainNote, prevNote);
		else
			newNote = Note.returnDefaultNote(assetModifier, strumTime, noteData, noteType, noteAlt, isSustainNote, prevNote, skin);

		// hold note shit
		if (isSustainNote && prevNote != null)
		{
			// set note offset
			if (prevNote.isSustainNote)
				newNote.noteVisualOffset = prevNote.noteVisualOffset;
			else // calculate a new visual offset based on that note's width and newnote's width
				newNote.noteVisualOffset = ((prevNote.width / 2) - (newNote.width / 2));
		}

		if (newNote.animation.curAnim != null) {
			var off = [0.0, 0.0];
			if (isSustainNote) {
				if (newNote.animation.curAnim.name.endsWith('end'))
					off = getOffset(skin, 'holdEnd', noteData);
				else
					off = getOffset(skin, 'holdPiece', noteData);
			} else {
				off = getOffset(skin, 'note', noteData);
			}
			
			if (off[0] != 0 || off[1] != 0) {
				newNote.addOffset(newNote.animation.curAnim.name, off[0], off[1]);
				newNote.playAnim(newNote.animation.curAnim.name);
			}
		}

		return newNote;
	}

}

class Note extends FunkinSprites
{
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var playfield:Int = 0;
	public var noteAlt:Float = 0;
	public var noteType:Dynamic = 0;
	public var noteSkin:String = "default";
	public var noteString:String = "";

	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var prevNote:Note;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;

	// only useful for charting stuffs
	public var chartSustain:FlxSprite = null;
	public var rawNoteData:Int;

	// not set initially
	public var noteQuant:Int = -1;
	public var noteVisualOffset:Float = 0;
	public var noteSpeed:Float = 0;
	public var noteDirection:Float = 0;

	public var parentNote:Note;
	public var childrenNotes:Array<Note> = [];

	public static var swagWidth:Float = 160 * 0.7;

	// modchart fields
	public var multSpeed:Float = 1.0;
	public var alphaMod:Float = 1.0;
	public var lane:Int = 0;
	public var isSustainEnd:Bool = false;
	public var baseScale:flixel.math.FlxPoint = new flixel.math.FlxPoint(0.7, 0.7);
	public var rgbGraphics:Dynamic = {flash: 0.0, alpha: 1.0};

	// it has come to this.
	public var endHoldOffset:Float = Math.NEGATIVE_INFINITY;

	public function new(strumTime:Float, noteData:Int, noteAlt:Float, ?prevNote:Note, ?sustainNote:Bool = false)
	{
		super(x, y);

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;

		// oh okay I know why this exists now
		y -= 2000;

		this.strumTime = strumTime;
		this.noteData = noteData;
		this.noteAlt = noteAlt;

		// determine parent note
		if (isSustainNote && prevNote != null)
		{
			parentNote = prevNote;
			while (parentNote.parentNote != null)
				parentNote = parentNote.parentNote;
			parentNote.childrenNotes.push(this);
		}
		else if (!isSustainNote)
			parentNote = null;
	}

	public var noteClipRect:flixel.math.FlxRect = null;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			if (strumTime > Conductor.songPosition - (Timings.msThreshold) && strumTime < Conductor.songPosition + (Timings.msThreshold))
				canBeHit = true;
			else
				canBeHit = false;
		}
		else // make sure the note can't be hit if it's the dad's I guess
			canBeHit = false;

		if (tooLate || (parentNote != null && parentNote.tooLate))
			alpha = 0.3;
	}

	override function updateAnimation(elapsed:Float):Void
	{
		if (frames != null && frames.frames != null && animation.curAnim != null)
			super.updateAnimation(elapsed);
	}

	public function playNoteAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if (animation.getByName(animName) != null && animation.getByName(animName).frames.length > 0)
			animation.play(animName, force, reversed, frame);
	}

	override public function destroy():Void
	{
		if (baseScale != null)
		{
			baseScale.put();
			baseScale = null;
		}
		if (noteClipRect != null)
		{
			noteClipRect.put();
			noteClipRect = null;
		}
		super.destroy();
	}

	public function loadSkin(skin:String, assetModifier:String = 'base'):Void
	{
		this.noteSkin = skin;

		if (skin == 'pixel' || assetModifier == 'pixel')
		{
			if (isSustainNote)
			{
				loadGraphic(Paths.image('UI/notes/pixel/arrowEnds'), true, 7, 6);
				animation.add('purpleholdend', [4]);
				animation.add('greenholdend', [6]);
				animation.add('redholdend', [7]);
				animation.add('blueholdend', [5]);
				animation.add('purplehold', [0]);
				animation.add('greenhold', [2]);
				animation.add('redhold', [3]);
				animation.add('bluehold', [1]);
			}
			else
			{
				loadGraphic(Paths.image('UI/notes/pixel/arrows-pixels'), true, 17, 17);
				animation.add('greenScroll', [6]);
				animation.add('redScroll', [7]);
				animation.add('blueScroll', [5]);
				animation.add('purpleScroll', [4]);
			}
			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			updateHitbox();
		}
		else
		{
			var atlas = FunkinArrows.getNoteAtlas(skin);
			if (atlas == null || atlas.frames == null || atlas.frames.length == 0)
				atlas = FunkinArrows.getNoteAtlas('default');
			frames = atlas;
			animation.addByPrefix('greenScroll', 'green0');
			animation.addByPrefix('redScroll', 'red0');
			animation.addByPrefix('blueScroll', 'blue0');
			animation.addByPrefix('purpleScroll', 'purple0');

			if (animation.getByName('greenScroll') == null) animation.addByPrefix('greenScroll', 'green');
			if (animation.getByName('redScroll') == null) animation.addByPrefix('redScroll', 'red');
			if (animation.getByName('blueScroll') == null) animation.addByPrefix('blueScroll', 'blue');
			if (animation.getByName('purpleScroll') == null) animation.addByPrefix('purpleScroll', 'purple');

			animation.addByPrefix('purpleholdend', 'pruple end hold');
			if (animation.getByName('purpleholdend') == null || animation.getByName('purpleholdend').frames.length == 0)
				animation.addByPrefix('purpleholdend', 'purple hold end');
			if (animation.getByName('purpleholdend') == null || animation.getByName('purpleholdend').frames.length == 0)
				animation.addByPrefix('purpleholdend', 'purple end hold');

			animation.addByPrefix('greenholdend', 'green hold end');
			if (animation.getByName('greenholdend') == null || animation.getByName('greenholdend').frames.length == 0)
				animation.addByPrefix('greenholdend', 'green end hold');

			animation.addByPrefix('redholdend', 'red hold end');
			if (animation.getByName('redholdend') == null || animation.getByName('redholdend').frames.length == 0)
				animation.addByPrefix('redholdend', 'red end hold');

			animation.addByPrefix('blueholdend', 'blue hold end');
			if (animation.getByName('blueholdend') == null || animation.getByName('blueholdend').frames.length == 0)
				animation.addByPrefix('blueholdend', 'blue end hold');

			animation.addByPrefix('purplehold', 'purple hold piece');
			animation.addByPrefix('greenhold', 'green hold piece');
			animation.addByPrefix('redhold', 'red hold piece');
			animation.addByPrefix('bluehold', 'blue hold piece');

			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
			antialiasing = true;
		}

		if (!isSustainNote)
			playNoteAnim(UIStaticArrow.getColorFromNumber(noteData) + 'Scroll');
		else
		{
			if (isSustainEnd)
				playNoteAnim(UIStaticArrow.getColorFromNumber(noteData) + 'holdend');
			else
				playNoteAnim(UIStaticArrow.getColorFromNumber(noteData) + 'hold');
		}

		baseScale.set(scale.x, scale.y);
	}

	/**
		Note creation scripts

		these are for all your custom note needs
	**/
	public static function returnDefaultNote(assetModifier:String, strumTime:Float, noteData:Int, noteType:Dynamic, noteAlt:Float, ?isSustainNote:Bool = false, ?prevNote:Note = null, ?skin:String = 'default'):Note
	{
		var newNote:Note = new Note(strumTime, noteData, noteAlt, prevNote, isSustainNote);
		newNote.noteType = noteType;
		newNote.loadSkin(skin, assetModifier);

		if (!isSustainNote)
			newNote.playNoteAnim(UIStaticArrow.getColorFromNumber(noteData) + 'Scroll');

		if (isSustainNote && prevNote != null)
		{
			newNote.isSustainEnd = true;
			if (prevNote.isSustainNote) prevNote.isSustainEnd = false;
			newNote.noteSpeed = prevNote.noteSpeed;
			newNote.alpha = (Init.trueSettings.get('Alpha Holds')) ? 1 : 0.6;
			newNote.playNoteAnim(UIStaticArrow.getColorFromNumber(noteData) + 'holdend');
			newNote.updateHitbox();
			if (prevNote.isSustainNote)
			{
				prevNote.playNoteAnim(UIStaticArrow.getColorFromNumber(prevNote.noteData) + 'hold');
				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05 * prevNote.noteSpeed;
				prevNote.updateHitbox();
				prevNote.baseScale.set(prevNote.scale.x, prevNote.scale.y);
			}
		}
		newNote.baseScale.set(newNote.scale.x, newNote.scale.y);
		return newNote;
	}

	public static function returnQuantNote(assetModifier, strumTime, noteData, noteType, noteAlt, ?isSustainNote:Bool = false, ?prevNote:Note = null):Note
	{
		var newNote:Note = new Note(strumTime, noteData, noteAlt, prevNote, isSustainNote);

		// actually determine the quant of the note
		if (newNote.noteQuant == -1)
		{
			final quantArray:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 192]; // different quants

			var curBPM:Float = Conductor.bpm;
			var newTime = strumTime;
			for (i in 0...Conductor.bpmChangeMap.length)
			{
				if (strumTime > Conductor.bpmChangeMap[i].songTime)
				{
					curBPM = Conductor.bpmChangeMap[i].bpm;
					newTime = strumTime - Conductor.bpmChangeMap[i].songTime;
				}
			}

			final beatTimeSeconds:Float = (60 / curBPM); // beat in seconds
			final beatTime:Float = beatTimeSeconds * 1000; // beat in milliseconds
			// assumed 4 beats per measure?
			final measureTime:Float = beatTime * 4;

			final smallestDeviation:Float = measureTime / quantArray[quantArray.length - 1];

			for (quant in 0...quantArray.length)
			{
				// please generate this ahead of time and put into array :)
				// I dont think I will im scared of those
				final quantTime = (measureTime / quantArray[quant]);
				if ((newTime #if !neko + Init.trueSettings['Offset'] #end + smallestDeviation) % quantTime < smallestDeviation * 2)
				{
					// here it is, the quant, finally!
					newNote.noteQuant = quant;
					break;
				}
			}
		}

		// note quants
		switch (assetModifier)
		{
			default:
				// inherit last quant if hold note
				if (isSustainNote && prevNote != null)
					newNote.noteQuant = prevNote.noteQuant;
				// base quant notes
				if (!isSustainNote)
				{
					// in case you're unfamiliar with these, they're ternary operators, I just dont wanna check for pixel notes using a separate statement
					var newNoteSize:Int = (assetModifier == 'pixel') ? 17 : 157;
					newNote.loadGraphic(Paths.image('UI/notes/default/note'),
						true, newNoteSize, newNoteSize);

					newNote.animation.add('leftScroll', [0 + (newNote.noteQuant * 4)]);
					// LOL downscroll thats so funny to me
					newNote.animation.add('downScroll', [1 + (newNote.noteQuant * 4)]);
					newNote.animation.add('upScroll', [2 + (newNote.noteQuant * 4)]);
					newNote.animation.add('rightScroll', [3 + (newNote.noteQuant * 4)]);
				}
				else
				{
					// quant holds
					newNote.loadGraphic(Paths.image('UI/notes/default/note'),
						true, (assetModifier == 'pixel') ? 17 : 109, (assetModifier == 'pixel') ? 6 : 52);
					newNote.animation.add('hold', [0 + (newNote.noteQuant * 4)]);
					newNote.animation.add('holdend', [1 + (newNote.noteQuant * 4)]);
					newNote.animation.add('rollhold', [2 + (newNote.noteQuant * 4)]);
					newNote.animation.add('rollend', [3 + (newNote.noteQuant * 4)]);
				}

				if (assetModifier == 'pixel')
				{
					newNote.antialiasing = false;
					newNote.setGraphicSize(Std.int(newNote.width * PlayState.daPixelZoom));
					newNote.updateHitbox();
				}
				else
				{
					newNote.setGraphicSize(Std.int(newNote.width * 0.7));
					newNote.updateHitbox();
					newNote.antialiasing = true;
				}
		}

		if (!isSustainNote)
			newNote.animation.play(UIStaticArrow.getArrowFromNumber(noteData) + 'Scroll');

		if (isSustainNote && prevNote != null)
		{
			newNote.isSustainEnd = true;
			if (prevNote.isSustainNote) prevNote.isSustainEnd = false;
			newNote.noteSpeed = prevNote.noteSpeed;
			newNote.alpha = (Init.trueSettings.get('Alpha Holds')) ? 1 : 0.6;
			newNote.animation.play('holdend');
			newNote.updateHitbox();

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play('hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * (43 / 52) * 1.05 * prevNote.noteSpeed;
				prevNote.updateHitbox();
				prevNote.baseScale.set(prevNote.scale.x, prevNote.scale.y);
			}
		}
		newNote.baseScale.set(newNote.scale.x, newNote.scale.y);

		return newNote;
	}
}

class UIStaticArrow extends FlxSprite
{
	/*  Oh hey, just gonna port this code from the previous Skater engine 
		(depending on the release of this you might not have it cus I might rewrite skater to use this engine instead)
		It's basically just code from the game itself but
		it's in a separate class and I also added the ability to set offsets for the arrows.

		uh hey you're cute ;)
	 */
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var babyArrowType:Int = 0;
	public var canFinishAnimation:Bool = true;
	public var skin:String = 'default';

	public var initialX:Int;
	public var initialY:Int;

	public var xTo:Float;
	public var yTo:Float;
	public var angleTo:Float;

	public var setAlpha:Float = (Init.trueSettings.get('Alpha Arrows')) ? 1 : 0.8;

	// modchart fields
	public var noteData(get, set):Int;
	inline function get_noteData():Int return babyArrowType;
	inline function set_noteData(val:Int):Int return babyArrowType = val;

	public var lane:Int = 0;
	public var alphaMod:Float = 1.0;
	public var baseScale:flixel.math.FlxPoint = new flixel.math.FlxPoint(0.7, 0.7);
	public var rgbGraphics:Dynamic = {flash: 0.0, alpha: 1.0};

	public function new(x:Float, y:Float, ?babyArrowType:Int = 0)
	{
		// this extension is just going to rely a lot on preexisting code as I wanna try to write an extension before I do options and stuff
		super(x, y);
		animOffsets = new Map<String, Array<Dynamic>>();

		this.babyArrowType = babyArrowType;

		updateHitbox();
		baseScale.set(0.7, 0.7);
		scrollFactor.set();
	}

	public function loadSkin(newSkin:String, assetModifier:String = 'base'):Void
	{
		skin = newSkin;
		animOffsets.clear();

		if (assetModifier == 'chart editor')
		{
			loadGraphic(Paths.image('UI/forever/base/chart editor/note_array'), true, 157, 156);
			animation.add('static', [babyArrowType]);
			animation.add('pressed', [16 + babyArrowType], 12, false);
			animation.add('confirm', [4 + babyArrowType, 8 + babyArrowType, 16 + babyArrowType], 24, false);

			addOffset('static');
			addOffset('pressed');
			addOffset('confirm');
			antialiasing = true;
			updateHitbox();
		}
		else if (newSkin == 'pixel' || assetModifier == 'pixel')
		{
			loadGraphic(Paths.image('UI/notes/pixel/arrows-pixels'), true, 17, 17);
			animation.add('static', [babyArrowType]);
			animation.add('pressed', [4 + babyArrowType, 8 + babyArrowType], 12, false);
			animation.add('confirm', [12 + babyArrowType, 16 + babyArrowType], 24, false);

			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			updateHitbox();
			antialiasing = false;

			addOffset('static', FunkinArrows.getOffset('pixel', 'staticNote', babyArrowType)[0], FunkinArrows.getOffset('pixel', 'staticNote', babyArrowType)[1]);
			addOffset('pressed', FunkinArrows.getOffset('pixel', 'pressed', babyArrowType)[0], FunkinArrows.getOffset('pixel', 'pressed', babyArrowType)[1]);
			addOffset('confirm', FunkinArrows.getOffset('pixel', 'confirm', babyArrowType)[0], FunkinArrows.getOffset('pixel', 'confirm', babyArrowType)[1]);
		}
		else
		{
			var receptorSkin = FunkinArrows.skinHasReceptors(newSkin) ? newSkin : 'default';
			var stringSect:String = UIStaticArrow.getArrowFromNumber(babyArrowType);

			var atlas = FunkinArrows.getNoteAtlas(receptorSkin);
			if (atlas == null || atlas.frames == null || atlas.frames.length == 0)
				atlas = FunkinArrows.getNoteAtlas('default');
			frames = atlas;

			animation.addByPrefix('static', 'arrow' + stringSect.toUpperCase());
			animation.addByPrefix('pressed', stringSect + ' press', 24, false);
			animation.addByPrefix('confirm', stringSect + ' confirm', 24, false);

			antialiasing = true;
			setGraphicSize(Std.int(width * 0.7));

			addOffset('static', FunkinArrows.getOffset(receptorSkin, 'staticNote', babyArrowType)[0], FunkinArrows.getOffset(receptorSkin, 'staticNote', babyArrowType)[1]);
			addOffset('pressed', FunkinArrows.getOffset(receptorSkin, 'pressed', babyArrowType)[0], FunkinArrows.getOffset(receptorSkin, 'pressed', babyArrowType)[1]);
			addOffset('confirm', FunkinArrows.getOffset(receptorSkin, 'confirm', babyArrowType)[0], FunkinArrows.getOffset(receptorSkin, 'confirm', babyArrowType)[1]);
		}

		if (animation.getByName('static') != null && animation.getByName('static').frames.length > 0)
			playAnim('static');
		updateHitbox();
		baseScale.copyFrom(scale);
	}

	override function updateAnimation(elapsed:Float):Void
	{
		if (frames != null && frames.frames != null && animation.curAnim != null)
			super.updateAnimation(elapsed);
	}

	// literally just character code
	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (AnimName == 'confirm')
			alpha = 1;
		else
			alpha = setAlpha;

		if (animation.getByName(AnimName) != null && animation.getByName(AnimName).frames.length > 0)
			animation.play(AnimName, Force, Reversed, Frame);
		
		centerOffsets();
		centerOrigin();

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.x += daOffset[0];
			offset.y += daOffset[1];
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
		animOffsets[name] = [x, y];

	public function updateOffsets():Void
	{
		centerOffsets();
		centerOrigin();
		if (animation.curAnim != null)
		{
			var daOffset = animOffsets.get(animation.curAnim.name);
			if (daOffset != null)
			{
				offset.x += daOffset[0];
				offset.y += daOffset[1];
			}
		}
	}

	public static final directions:Array<String> = ['left', 'down', 'up', 'right'];
	public static function getArrowFromNumber(numb:Int) { return directions[numb % directions.length]; }

	// that last function was so useful I gave it a sequel
	public static final colors:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static function getColorFromNumber(numb:Int) { return colors[numb % colors.length]; }
}

class Strumline extends FlxTypedGroup<FlxBasic>
{
	public var receptors:FlxTypedGroup<UIStaticArrow>;
	public var splashNotes:FlxTypedGroup<NoteSplash>;
	public var notesGroup:FlxTypedGroup<Note>;
	public var holdsGroup:FlxTypedGroup<Note>;
	public var allNotes:FlxTypedGroup<Note>;

	public var autoplay:Bool = true;
	public var character:Character;
	public var playState:PlayState;
	public var displayJudgements:Bool = false;
	public var player:Int = 0;
	public var noteSkin:String = 'default';

	public function new(x:Float = 0, playState:PlayState, ?character:Character, ?displayJudgements:Bool = true, ?autoplay:Bool = true,
			?noteSplashes:Bool = false, ?keyAmount:Int = 4, ?downscroll:Bool = false, ?parent:Strumline)
	{
		super();

		receptors = new FlxTypedGroup<UIStaticArrow>();
		splashNotes = new FlxTypedGroup<NoteSplash>();
		notesGroup = new FlxTypedGroup<Note>();
		holdsGroup = new FlxTypedGroup<Note>();
		allNotes = new FlxTypedGroup<Note>();

		this.autoplay = autoplay;
		this.character = character;
		this.playState = playState;
		this.displayJudgements = displayJudgements;
		this.player = (autoplay ? 1 : 0);

		for (i in 0...keyAmount)
		{
			var staticArrow:UIStaticArrow = FunkinArrows.generateUIArrows(-25 + x, 25 + (downscroll ? FlxG.height - 200 : 0), i, PlayState.assetModifier, noteSkin);
			staticArrow.ID = i;
			staticArrow.lane = this.player;

			staticArrow.x -= ((keyAmount / 2) * Note.swagWidth);
			staticArrow.x += (Note.swagWidth * i);
			receptors.add(staticArrow);

			staticArrow.initialX = Math.floor(staticArrow.x);
			staticArrow.initialY = Math.floor(staticArrow.y);
			staticArrow.angleTo = 0;
			staticArrow.y -= 10;
			staticArrow.playAnim('static');

			staticArrow.alpha = 0;
			FlxTween.tween(staticArrow, {y: staticArrow.initialY, alpha: staticArrow.setAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
		}

		var clipStyle:String = Std.string(Init.trueSettings.get('Clip Style')).toLowerCase();
		if (clipStyle == 'back')
		{
			add(holdsGroup);
			add(receptors);
		}
		else
		{
			add(receptors);
			add(holdsGroup);
		}
		add(notesGroup);
		if (noteSplashes)
			add(splashNotes);
	}

	public function changeSkin(newSkin:String):Void
	{
		noteSkin = newSkin;
		for (receptor in receptors.members)
		{
			if (receptor != null)
				receptor.loadSkin(newSkin, PlayState.assetModifier);
		}
		for (note in allNotes.members)
		{
			if (note != null && note.alive)
			{
				if (note.noteType == null || note.noteType == 0 || note.noteSkin == 'default' || note.noteSkin == null)
					note.loadSkin(newSkin, PlayState.assetModifier);
			}
		}
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function createSplash(coolNote:Note)
	{
		if (Init.trueSettings.get('Disable Note Splashes')) return;
		
		var splash:NoteSplash = splashNotes.recycle(NoteSplash);
		var splashSkin:String = (coolNote != null && coolNote.noteSkin != null && coolNote.noteSkin != 'default') ? coolNote.noteSkin : noteSkin;
		splash.playSplash(coolNote.noteData, PlayState.assetModifier, splashSkin);
		var receptor = receptors.members[coolNote.noteData];
		splash.setPosition(receptor.x - (splash.width / 4) - 30, receptor.y - (splash.height / 4) - 20);
	}

	public function push(newNote:Note)
	{
		newNote.lane = this.player;
		var chosenGroup = (newNote.isSustainNote ? holdsGroup : notesGroup);
		chosenGroup.add(newNote);
		allNotes.add(newNote);

		var isDownscroll:Bool = (playState != null) ? playState.downscroll : Init.trueSettings.get('Downscroll');
		var order = (!isDownscroll) ? FlxSort.DESCENDING : FlxSort.ASCENDING;
		var members = chosenGroup.members;
		var len = members.length;
		if (len > 1)
		{
			var prev = members[len - 2];
			if (prev != null)
			{
				var needsSort = (order == FlxSort.DESCENDING) ? (prev.strumTime < newNote.strumTime) : (prev.strumTime > newNote.strumTime);
				if (needsSort)
					chosenGroup.sort(sortByStrumTime, order);
			}
		}
	}

	public function resetStrumline(skipTween:Bool = false):Void
	{
		for (n in allNotes.members)
		{
			if (n != null)
			{
				n.kill();
				n.destroy();
			}
		}
		allNotes.clear();
		notesGroup.clear();
		holdsGroup.clear();

		var isDownscroll:Bool = Init.trueSettings.get('Downscroll');
		for (i in 0...receptors.members.length)
		{
			var staticArrow:UIStaticArrow = receptors.members[i];
			if (staticArrow == null) continue;

			staticArrow.playAnim('static');
			staticArrow.x = staticArrow.initialX;
			staticArrow.angle = staticArrow.angleTo;

			FlxTween.cancelTweensOf(staticArrow);

			if (!skipTween)
			{
				// V-Slice style rewind / bounce animation:
				// Arrows start with an offset and tween into place with circOut
				var offset:Float = isDownscroll ? 45 : -45;
				staticArrow.y = staticArrow.initialY + offset;
				staticArrow.alpha = 0;
				FlxTween.tween(staticArrow, {y: staticArrow.initialY, alpha: staticArrow.setAlpha}, 0.65, {
					ease: FlxEase.circOut,
					startDelay: 0.04 * i
				});
			}
			else
			{
				staticArrow.y = staticArrow.initialY;
				staticArrow.alpha = staticArrow.setAlpha;
			}
		}
	}

	static inline function sortByStrumTime(Order:Int, Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(Order, Obj1.strumTime, Obj2.strumTime);
	}
}

class NoteSplash extends FunkinSprites
{
	public var noteData:Int = 0;
	public var loadedSkin:String = '';
	public var loadedModifier:String = '';

	public function new()
	{
		super(0, 0);
		visible = false;
		alpha = 1;
	}

	public function setupNoteSplash(noteData:Int, assetModifier:String = 'base', changeableSkin:String = 'default')
	{
		this.noteData = noteData;
		var skinAsset = Utils.returnSkinAsset('splash', assetModifier, changeableSkin, 'UI/notes');

		if (loadedSkin != skinAsset || loadedModifier != assetModifier)
		{
			var atlas = FunkinArrows.getSplashAtlas(skinAsset);
			if (atlas == null || atlas.frames == null || atlas.frames.length == 0)
				atlas = FunkinArrows.getSplashAtlas('UI/notes/default/splash');
			frames = atlas;
			loadedSkin = skinAsset;
			loadedModifier = assetModifier;

			var colors:Array<String> = ['purple', 'blue', 'green', 'red'];
			for (i in 0...colors.length)
			{
				var color:String = colors[i];
				switch (assetModifier)
				{
					case 'pixel':
						animation.addByPrefix('anim1_' + i, 'splash ' + color + ' 1', 24, false);
						animation.addByPrefix('anim2_' + i, 'splash ' + color + ' 2', 24, false);
						var off1 = FunkinArrows.getOffset(assetModifier, 'splash', i);
						addOffset('anim1_' + i, -120 + off1[0], -90 + off1[1]);
						addOffset('anim2_' + i, -120 + off1[0], -90 + off1[1]);

					default:
						animation.addByPrefix('anim1_' + i, 'note impact 1 ' + color, 24, false);
						animation.addByPrefix('anim2_' + i, 'note impact 2 ' + color, 24, false);
						var off2 = FunkinArrows.getOffset(assetModifier, 'splash', i);
						addOffset('anim1_' + i, -20 + off2[0], -10 + off2[1]);
						addOffset('anim2_' + i, -20 + off2[0], -10 + off2[1]);
				}
			}

			if (assetModifier == 'pixel')
			{
				setGraphicSize(Std.int(width * PlayState.daPixelZoom));
				antialiasing = false;
			}
			else
			{
				antialiasing = true;
			}
			updateHitbox();
		}
	}

	public function playSplash(noteData:Int, assetModifier:String = 'base', changeableSkin:String = 'default')
	{
		setupNoteSplash(noteData, assetModifier, changeableSkin);
		var rand:Int = FlxG.random.int(1, 2);
		playAnim('anim' + rand + '_' + (noteData % 4), true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (animation.finished) kill();
	}

	override function updateAnimation(elapsed:Float):Void
	{
		if (frames != null && frames.frames != null && animation.curAnim != null)
			super.updateAnimation(elapsed);
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0) {
		if (AnimName == 'anim1' || AnimName == 'anim2')
			AnimName = AnimName + '_' + (noteData % 4);

		if (!Init.trueSettings.get('Disable Note Splashes')) visible = true;
		super.playAnim(AnimName, Force, Reversed, Frame);
	}
}
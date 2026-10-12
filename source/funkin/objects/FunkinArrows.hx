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

	

	public static function generateUIArrows(x:Float, y:Float, ?staticArrowType:Int = 0, assetModifier:String):UIStaticArrow
	{
		var newStaticArrow:UIStaticArrow = new UIStaticArrow(x, y, staticArrowType);
		switch (assetModifier)
		{
			case 'pixel':
				newStaticArrow.loadGraphic(Paths.image('UI/notes/pixel/arrows-pixels'), true, 17, 17);
				newStaticArrow.animation.add('static', [staticArrowType]);
				newStaticArrow.animation.add('pressed', [4 + staticArrowType, 8 + staticArrowType], 12, false);
				newStaticArrow.animation.add('confirm', [12 + staticArrowType, 16 + staticArrowType], 24, false);

				newStaticArrow.setGraphicSize(Std.int(newStaticArrow.width * PlayState.daPixelZoom));
				newStaticArrow.updateHitbox();
				newStaticArrow.antialiasing = false;

				newStaticArrow.addOffset('static', getOffset(assetModifier, 'staticNote', staticArrowType)[0], getOffset(assetModifier, 'staticNote', staticArrowType)[1]);
				newStaticArrow.addOffset('pressed', getOffset(assetModifier, 'pressed', staticArrowType)[0], getOffset(assetModifier, 'pressed', staticArrowType)[1]);
				newStaticArrow.addOffset('confirm', getOffset(assetModifier, 'confirm', staticArrowType)[0], getOffset(assetModifier, 'confirm', staticArrowType)[1]);

			case 'chart editor':
				newStaticArrow.loadGraphic(Paths.image('UI/forever/base/chart editor/note_array'), true, 157, 156);
				newStaticArrow.animation.add('static', [staticArrowType]);
				newStaticArrow.animation.add('pressed', [16 + staticArrowType], 12, false);
				newStaticArrow.animation.add('confirm', [4 + staticArrowType, 8 + staticArrowType, 16 + staticArrowType], 24, false);

				newStaticArrow.addOffset('static');
				newStaticArrow.addOffset('pressed');
				newStaticArrow.addOffset('confirm');

			default:
				// probably gonna revise this and make it possible to add other arrow types but for now it's just pixel and normal
				var stringSect:String = '';
				// call arrow type I think
				stringSect = UIStaticArrow.getArrowFromNumber(staticArrowType);

				newStaticArrow.frames = Paths.getSparrowAtlas('UI/notes/default/note');

				newStaticArrow.animation.addByPrefix('static', 'arrow' + stringSect.toUpperCase());
				newStaticArrow.animation.addByPrefix('pressed', stringSect + ' press', 24, false);
				newStaticArrow.animation.addByPrefix('confirm', stringSect + ' confirm', 24, false);

				newStaticArrow.antialiasing = true;
				newStaticArrow.setGraphicSize(Std.int(newStaticArrow.width * 0.7));

				// set little offsets per note!
				// so these had a little problem honestly and they make me wanna off(set) myself so the middle notes basically
				// have slightly different offsets than the side notes (which have the same offset)

				newStaticArrow.addOffset('static', getOffset(assetModifier, 'staticNote', staticArrowType)[0], getOffset(assetModifier, 'staticNote', staticArrowType)[1]);
				newStaticArrow.addOffset('pressed', getOffset(assetModifier, 'pressed', staticArrowType)[0], getOffset(assetModifier, 'pressed', staticArrowType)[1]);
				newStaticArrow.addOffset('confirm', getOffset(assetModifier, 'confirm', staticArrowType)[0], getOffset(assetModifier, 'confirm', staticArrowType)[1]);
		}

		newStaticArrow.playAnim('static');
		newStaticArrow.updateHitbox();
		newStaticArrow.baseScale.copyFrom(newStaticArrow.scale);

		return newStaticArrow;
	}

	/**
		Notes!
	**/
	public static function generateArrow(assetModifier, strumTime, noteData, noteType, noteAlt, ?isSustainNote:Bool = false, ?prevNote:Note = null):Note
	{
		var newNote:Note;
		var changeableSkin:String = Init.trueSettings.get("Note Skin");
		// gonna improve the system eventually
		if (changeableSkin.startsWith('quant'))
			newNote = Note.returnQuantNote(assetModifier, strumTime, noteData, noteType, noteAlt, isSustainNote, prevNote);
		else
			newNote = Note.returnDefaultNote(assetModifier, strumTime, noteData, noteType, noteAlt, isSustainNote, prevNote);

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
					off = getOffset(assetModifier, 'holdEnd', noteData);
				else
					off = getOffset(assetModifier, 'holdPiece', noteData);
			} else {
				off = getOffset(assetModifier, 'note', noteData);
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
	public var noteType:Float = 0;
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

	/**
		Note creation scripts

		these are for all your custom note needs
	**/
	public static function returnDefaultNote(assetModifier, strumTime, noteData, noteType, noteAlt, ?isSustainNote:Bool = false, ?prevNote:Note = null):Note
	{
		var newNote:Note = new Note(strumTime, noteData, noteAlt, prevNote, isSustainNote);

		// frames originally go here
		switch (assetModifier)
		{
			case 'pixel': // pixel arrows default
				if (isSustainNote)
				{
					newNote.loadGraphic(Paths.image('UI/notes/pixel/arrowEnds'), true, 7, 6);
					newNote.animation.add('purpleholdend', [4]);
					newNote.animation.add('greenholdend', [6]);
					newNote.animation.add('redholdend', [7]);
					newNote.animation.add('blueholdend', [5]);
					newNote.animation.add('purplehold', [0]);
					newNote.animation.add('greenhold', [2]);
					newNote.animation.add('redhold', [3]);
					newNote.animation.add('bluehold', [1]);
				}
				else
				{
					newNote.loadGraphic(Paths.image('UI/notes/pixel/arrows-pixels'), true, 17, 17);
					newNote.animation.add('greenScroll', [6]);
					newNote.animation.add('redScroll', [7]);
					newNote.animation.add('blueScroll', [5]);
					newNote.animation.add('purpleScroll', [4]);
				}
				newNote.antialiasing = false;
				newNote.setGraphicSize(Std.int(newNote.width * PlayState.daPixelZoom));
				newNote.updateHitbox();
			default: // base game arrows for no reason whatsoever
				newNote.frames = Paths.getSparrowAtlas('UI/notes/default/note');
				newNote.animation.addByPrefix('greenScroll', 'green0');
				newNote.animation.addByPrefix('redScroll', 'red0');
				newNote.animation.addByPrefix('blueScroll', 'blue0');
				newNote.animation.addByPrefix('purpleScroll', 'purple0');
				newNote.animation.addByPrefix('purpleholdend', 'pruple end hold');
				newNote.animation.addByPrefix('greenholdend', 'green hold end');
				newNote.animation.addByPrefix('redholdend', 'red hold end');
				newNote.animation.addByPrefix('blueholdend', 'blue hold end');
				newNote.animation.addByPrefix('purplehold', 'purple hold piece');
				newNote.animation.addByPrefix('greenhold', 'green hold piece');
				newNote.animation.addByPrefix('redhold', 'red hold piece');
				newNote.animation.addByPrefix('bluehold', 'blue hold piece');
				newNote.setGraphicSize(Std.int(newNote.width * 0.7));
				newNote.updateHitbox();
				newNote.antialiasing = true;
		}

		if (!isSustainNote)
			newNote.animation.play(UIStaticArrow.getColorFromNumber(noteData) + 'Scroll');

		if (isSustainNote && prevNote != null)
		{
			newNote.isSustainEnd = true;
			if (prevNote.isSustainNote) prevNote.isSustainEnd = false;
			newNote.noteSpeed = prevNote.noteSpeed;
			newNote.alpha = (Init.trueSettings.get('Alpha Holds')) ? 1 : 0.6;
			newNote.animation.play(UIStaticArrow.getColorFromNumber(noteData) + 'holdend');
			newNote.updateHitbox();
			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(UIStaticArrow.getColorFromNumber(prevNote.noteData) + 'hold');
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

	// literally just character code
	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (AnimName == 'confirm')
			alpha = 1;
		else
			alpha = setAlpha;

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
		if (animation.curAnim != null && animOffsets.exists(animation.curAnim.name))
		{
			var daOffset = animOffsets.get(animation.curAnim.name);
			offset.x += daOffset[0];
			offset.y += daOffset[1];
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
			var staticArrow:UIStaticArrow = FunkinArrows.generateUIArrows(-25 + x, 25 + (downscroll ? FlxG.height - 200 : 0), i, PlayState.assetModifier);
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

		add(receptors);
		add(holdsGroup);
		add(notesGroup);
		if (noteSplashes)
			add(splashNotes);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function createSplash(coolNote:Note)
	{
		if (Init.trueSettings.get('Disable Note Splashes')) return;
		
		var splash:NoteSplash = splashNotes.recycle(NoteSplash);
		splash.playSplash(coolNote.noteData, PlayState.assetModifier, PlayState.changeableSkin);
		var receptor = receptors.members[coolNote.noteData];
		splash.setPosition(receptor.x - (splash.width / 4), receptor.y - (splash.height / 4));
	}

	public function push(newNote:Note)
	{
		newNote.lane = this.player;
		var chosenGroup = (newNote.isSustainNote ? holdsGroup : notesGroup);
		chosenGroup.add(newNote);
		allNotes.add(newNote);
		chosenGroup.sort(sortByStrumTime, (!Init.trueSettings.get('Downscroll')) ? FlxSort.DESCENDING : FlxSort.ASCENDING);
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
		alpha = 0.6;
	}

	public function setupNoteSplash(noteData:Int, assetModifier:String = 'base', changeableSkin:String = 'default')
	{
		this.noteData = noteData;
		var skinAsset = Utils.returnSkinAsset('splash', assetModifier, changeableSkin, 'UI/notes');

		if (loadedSkin != skinAsset || loadedModifier != assetModifier)
		{
			frames = Paths.getSparrowAtlas(skinAsset);
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

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0) {
		if (AnimName == 'anim1' || AnimName == 'anim2')
			AnimName = AnimName + '_' + (noteData % 4);

		if (!Init.trueSettings.get('Disable Note Splashes')) visible = true;
		super.playAnim(AnimName, Force, Reversed, Frame);
	}
}
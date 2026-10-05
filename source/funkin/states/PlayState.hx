package funkin.states;
import Paths;
import Utils;
import Assets;
import Init;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.objects.FunkinArrows.UIStaticArrow;
import funkin.objects.FunkinArrows.Strumline;
import backend.*;
import funkin.substates.*;
import funkin.editors.*;
import backend.MusicBeatState;
import backend.Song.SwagSong;
import openfl.events.KeyboardEvent;

using StringTools;

#if desktop
import backend.Discord;
#end

enum Focus
{
	BF;
	DAD;
	CENTER;
	NONE;
}

class PlayState extends MusicBeatState
{
	public static var instance:PlayState;

	public static var curStage:String = '';
	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 2;

	public static var songMusic:FlxSound;
	public static var vocals:FlxSound;

	public static var campaignScore:Int = 0;

	public static var dadOpponent:Character;
	public static var gf:Character;
	public static var boyfriend:Boyfriend;

	public static var assetModifier:String = 'base';
	public static var changeableSkin:String = 'default';

	private var unspawnNotes:Array<Note> = [];
	private var unspawnNotesIndex:Int = 0;

	// if you ever wanna add more keys
	private var numberOfKeys:Int = 4;

	public var camFollow:FlxObject;
	public var camFollowPos:FlxObject;

	// Discord RPC variables
	public static var songDetails:String = "";
	public static var detailsSub:String = "";
	public static var detailsPausedText:String = "";

	private static var prevCamFollow:FlxObject;

	private var curSong:String = "";
	private var gfSpeed:Int = 1;

	public static var health:Float = 1; // mario
	public static var combo:Int = 0;

	public static var misses:Int = 0;

	public static var deaths:Int = 0;

	public var generatedMusic:Bool = false;

	private var startingSong:Bool = false;
	public var paused:Bool = false;
	var startedCountdown:Bool = false;
	var inCutscene:Bool = false;

	var canPause:Bool = true;

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	public static var camHUD:FlxCamera;
	public static var camGame:FlxCamera;
	public static var camText:FlxCamera;
	public static var dialogueHUD:FlxCamera;

	public var camDisplaceX:Float = 0;
	public var camDisplaceY:Float = 0; // might not use depending on result

	public static var defaultCamZoom:Float = 1.05;

	public static var forceZoom:Array<Float>;

	public static var songScore:Int = 0;

	public static var iconRPC:String = "";

	public static var songLength:Float = 0;

	public var stageBuild:Stage;

	public static var uiHUD:ClassHUD;

	public static var daPixelZoom:Float = 6;
	public static var determinedChartType:String = "";

	// strumlines
	public static var dadStrums:Strumline;
	public static var boyfriendStrums:Strumline;

	public static var strumLines:FlxTypedGroup<Strumline>;
	public static var strumHUD:Array<FlxCamera> = [];

	public var allUIs:Array<FlxCamera> = [];

	// stores the last judgement object
	public var grpRatings:FlxTypedGroup<FlxSprite>;
	// stores the last combo objects in an array
	public var grpCombos:FlxTypedGroup<FlxSprite>;

	//county funkin
	public static var lockCamPos:Bool = false;
	public static var lockFocus:Bool = false;
	public static var timerManager:FlxTimerManager = new FlxTimerManager();

	public var camDisplaceExtend:Float = 12;

	public static var focus:Focus = DAD;

	function resetStatics()
	{
		instance = this;
		focus = DAD;
		timerManager.active = true;
		lockCamPos = false;
		lockFocus = false;

		// reset any values and variables that are static
		songScore = 0;
		combo = 0;
		health = 1;
		misses = 0;

		// sets up the combo object array
		grpRatings = new FlxTypedGroup<FlxSprite>(); add(grpRatings); 
		grpCombos = new FlxTypedGroup<FlxSprite>(); add(grpCombos);

		defaultCamZoom = 1.05;
		forceZoom = [0, 0, 0, 0];

		assetModifier = 'base';
		changeableSkin = 'default';

		PlayState.SONG.validScore = true;
	}

	// at the beginning of the playstate
	override public function create()
	{
		super.create();
		
		resetStatics();

		Timings.callAccuracy();

		// stop any existing music tracks playing
		resetMusic();
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// create the game camera
		camGame = new FlxCamera();

		// create the hud camera (separate so the hud stays on screen)
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		allUIs.push(camHUD);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// default song
		if (SONG == null)
			SONG = Song.loadFromJson('test', 'test');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		/// here we determine the chart type!
		// determine the chart type here
		determinedChartType = "FNF";

		// set up a class for the stage type in here afterwards
		curStage = "";
		// call the song's stage if it exists
		if (SONG.stage != null)
			curStage = SONG.stage;

		// cache shit
		displayRating('sick', 'early', true);
		popUpCombo(true);
		
		for (i in 1...4)
			Paths.sound('system/miss/missnote' + i);
			
		Paths.image('UI/combo/default/good');
		Paths.image('UI/combo/default/bad');
		Paths.image('UI/combo/default/shit');
		Paths.image('UI/notes/default/splash');
		//

		stageBuild = new Stage(curStage);
		add(stageBuild.background);

		// set up characters here too
		gf = new Character();
		gf.adjustPos = false;
		gf.setCharacter(300, 100, stageBuild.returnGFtype(curStage));
		gf.scrollFactor.set(0.95, 0.95);

		dadOpponent = new Character().setCharacter(50, 850, SONG.player2);
		boyfriend = new Boyfriend();
		boyfriend.setCharacter(750, 850, SONG.player1);
		// if you want to change characters later use setCharacter() instead of new or it will break

		var camPos:FlxPoint = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);

		stageBuild.repositionPlayers(curStage, boyfriend, dadOpponent, gf);
		stageBuild.dadPosition(curStage, boyfriend, dadOpponent, gf, camPos);

		if (SONG.assetModifier != null && SONG.assetModifier.length > 1)
			assetModifier = SONG.assetModifier;

		changeableSkin = Init.trueSettings.get("UI Skin");

		// add characters
		add(gf);

		add(dadOpponent);
		add(boyfriend);

		add(stageBuild.foreground);

		// force them to dance
		dadOpponent.dance();
		gf.dance();
		boyfriend.dance();

		// set song position before beginning
		Conductor.songPosition = -(Conductor.crochet * 4);

		// strum setup
		strumLines = new FlxTypedGroup<Strumline>();

		// generate the song
		generateSong(SONG.song);

		// set the camera position to the center of the stage
		camPos.set(gf.x + (gf.frameWidth / 2), gf.y + (gf.frameHeight / 2));

		// create the game camera
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(camPos.x, camPos.y);
		// check if the camera was following someone previously
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);
		add(camFollowPos);

		// actually set the camera up
		FlxG.camera.follow(camFollowPos, LOCKON);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		// initialize ui elements
		startingSong = true;
		startedCountdown = true;

		var placement = (FlxG.width / 2);
		var valThing = (FlxG.width / 4);

		dadStrums = new Strumline(placement - valThing, this, dadOpponent, false, true, false, 4, Init.trueSettings.get('Downscroll'));
		dadStrums.visible = !Init.trueSettings.get('Centered Notefield');
		boyfriendStrums = new Strumline(placement + (!Init.trueSettings.get('Centered Notefield') ? valThing : 0), this, boyfriend, true, false, true,
			4, Init.trueSettings.get('Downscroll'));

		strumLines.add(dadStrums);
		strumLines.add(boyfriendStrums);

		// strumline camera setup
		strumHUD = [];
		for (i in 0...strumLines.length)
		{
			// generate a new strum camera
			strumHUD[i] = new FlxCamera();
			strumHUD[i].bgColor.alpha = 0;

			allUIs.push(strumHUD[i]);
			FlxG.cameras.add(strumHUD[i], false);
			// set this strumline's camera to the designated camera
			strumLines.members[i].cameras = [strumHUD[i]];
		}
		add(strumLines);

		camText = new FlxCamera();
		camText.bgColor.alpha = 0;
		allUIs.push(camText);
		FlxG.cameras.add(camText, false);

		uiHUD = new ClassHUD();
		add(uiHUD);
		uiHUD.cameras = [camHUD];
		//

		// create a hud over the hud camera for dialogue
		dialogueHUD = new FlxCamera();
		dialogueHUD.bgColor.alpha = 0;
		FlxG.cameras.add(dialogueHUD, false);

		//
		keysArray = [
			copyKey(Init.gameControls.get('LEFT')[0]),
			copyKey(Init.gameControls.get('DOWN')[0]),
			copyKey(Init.gameControls.get('UP')[0]),
			copyKey(Init.gameControls.get('RIGHT')[0])
		];

		if (!Init.trueSettings.get('Controller Mode'))
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		updateCamFollow();
		
		startCountdown();
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey>
	{
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len)
		{
			if (copiedArray[i] == NONE)
			{
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}

	var keysArray:Array<Dynamic>;

	private var keysPressed:Map<Int, Bool> = new Map<Int, Bool>();

	public function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (key >= 0 && !boyfriendStrums.autoplay && (FlxG.keys.enabled && !paused && (FlxG.state.active || FlxG.state.persistentUpdate)))
		{
			// Prevent OS auto-repeat spam for key holds
			if (keysPressed.exists(key) && keysPressed.get(key) == true) return;
			keysPressed.set(key, true);

			if (generatedMusic)
			{
				var previousTime:Float = Conductor.songPosition;
				Conductor.songPosition = songMusic.time;
				// improved this a little bit, maybe its a lil
				var possibleNoteList:Array<Note> = [];
				var pressedNotes:Array<Note> = [];

				boyfriendStrums.allNotes.forEachAlive(function(daNote:Note)
				{
					if ((daNote.noteData == key) && daNote.canBeHit && !daNote.isSustainNote && !daNote.tooLate && !daNote.wasGoodHit)
						possibleNoteList.push(daNote);
				});
				possibleNoteList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				// if there is a list of notes that exists for that control
				if (possibleNoteList.length > 0)
				{
					var eligable = true;
					var firstNote = true;
					// loop through the possible notes
					for (coolNote in possibleNoteList)
					{
						for (noteDouble in pressedNotes)
						{
							if (Math.abs(noteDouble.strumTime - coolNote.strumTime) < 10)
								firstNote = false;
							else
								eligable = false;
						}

						if (eligable)
						{
							goodNoteHit(coolNote, boyfriend, boyfriendStrums, firstNote); // then hit the note
							pressedNotes.push(coolNote);
						}
						// end of this little check
					}
					//
				}
				else // else just call bad notes
					if (!Init.trueSettings.get('Ghost Tapping'))
						missNoteCheck(true, key, boyfriend, true);
				Conductor.songPosition = previousTime;
			}

			if (boyfriendStrums.receptors.members[key] != null
				&& boyfriendStrums.receptors.members[key].animation.curAnim.name != 'confirm')
				boyfriendStrums.receptors.members[key].playAnim('pressed');
		}
	}

	public function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (key >= 0)
		{
			keysPressed.set(key, false);
		}

		if (FlxG.keys.enabled && !paused && (FlxG.state.active || FlxG.state.persistentUpdate))
		{
			// receptor reset
			if (key >= 0 && boyfriendStrums.receptors.members[key] != null)
				boyfriendStrums.receptors.members[key].playAnim('static');
		}
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if (key == keysArray[i][j])
						return i;
				}
			}
		}
		return -1;
	}

	override public function destroy()
	{
		if (!Init.trueSettings.get('Controller Mode'))
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		super.destroy();
	}

	var lastSection:Int = 0;

	function updateCamFollow()
	{
		switch (focus)
		{
			case DAD:
				var char = dadOpponent;

				var mid = char.getMidpoint();
				camFollow.setPosition(mid.x + camDisplaceX + char.characterData.camOffsetX, mid.y + camDisplaceY + char.characterData.camOffsetY);
				mid.put();
			case BF:
				var char = boyfriend;

				var mid = char.getMidpoint();
				camFollow.setPosition(mid.x + camDisplaceX - char.characterData.camOffsetX, mid.y + camDisplaceY + char.characterData.camOffsetY);
				mid.put();
			case CENTER:
				var bfMid = boyfriend.getMidpoint();
				var dadMid = dadOpponent.getMidpoint();

				var centerX = (dadMid.x + bfMid.x) / 2;
				var centerY = (dadMid.y + bfMid.y) / 2;
				camFollow.setPosition(centerX, centerY);

				bfMid.put();
				dadMid.put();
			default:
		}
	}

	override public function update(elapsed:Float)
	{
		stageBuild.stageUpdateConstant(elapsed, boyfriend, gf, dadOpponent);

		super.update(elapsed);
		timerManager.update(elapsed);

		if (health > 2)
			health = 2;

		if (!inCutscene)
		{
			// pause the game if the game is allowed to pause and enter is pressed
			if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
			{
				pauseGame();
			}

			// make sure you're not cheating lol
			if (!isStoryMode)
			{
				if ((FlxG.keys.justPressed.SEVEN) && (!startingSong))
				{
					resetMusic();
					Main.switchState(this, new ChartEditor());
				}

				if ((FlxG.keys.justPressed.EIGHT) && (!startingSong))
				{
					resetMusic();
					Main.switchState(this, new funkin.editors.CharacterEditor());
				}

				if ((FlxG.keys.justPressed.SIX))
				{
					boyfriendStrums.autoplay = !boyfriendStrums.autoplay;
					uiHUD.autoplayMark.visible = boyfriendStrums.autoplay;
					PlayState.SONG.validScore = false;
				}
			}

			if (startingSong)
			{
				if (startedCountdown)
				{
					Conductor.songPosition += elapsed * 1000;
					if (Conductor.songPosition >= 0)
						startSong();
				}
			}
			else
			{
				Conductor.songPosition += elapsed * 1000;
				if (Conductor.songPosition > songMusic.length)
					Conductor.songPosition = songMusic.length;

				if (!paused)
				{
					songTime += FlxG.game.ticks - previousFrameTime;
					previousFrameTime = FlxG.game.ticks;

					// Interpolation type beat
					if (Conductor.lastSongPos != Conductor.songPosition)
					{
						songTime = (songTime + Conductor.songPosition) / 2;
						Conductor.lastSongPos = Conductor.songPosition;
					}
				}
			}

			var curSection = Std.int(curStep / 16);
			if (generatedMusic && PlayState.SONG.notes[curSection] != null)
			{
				if (curSection != lastSection)
				{
					// section reset stuff
					var lastMustHit:Bool = PlayState.SONG.notes[lastSection].mustHitSection;
					if (PlayState.SONG.notes[curSection].mustHitSection != lastMustHit)
					{
						camDisplaceX = 0;
						camDisplaceY = 0;
					}
					lastSection = curSection;
				}

				if (!lockFocus)
				{
					if (!PlayState.SONG.notes[curSection].mustHitSection)
						focus = DAD;
					else
						focus = BF;
				}
			}
			
			var camLerp = Math.exp(-elapsed * 12.0);
			camFollowPos.x = FlxMath.lerp(camFollow.x, camFollowPos.x, camLerp);
			camFollowPos.y = FlxMath.lerp(camFollow.y, camFollowPos.y, camLerp);

			var easeLerp = Math.exp(-elapsed * 3.0);
			// camera stuffs
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom + forceZoom[0], FlxG.camera.zoom, easeLerp);
			for (hud in allUIs)
				hud.zoom = FlxMath.lerp(1 + forceZoom[1], hud.zoom, easeLerp);

			// Controls

			// RESET = Quick Game Over Screen
			if (controls.RESET && !startingSong && !isStoryMode)
			{
				health = 0;
			}

			if (health <= 0 && startedCountdown)
			{
				paused = true;
				persistentUpdate = false;
				persistentDraw = true;

				resetMusic();

				deaths += 1;
				for (hud in PlayState.instance.allUIs)
					hud.visible = false;
				openSubState(new GameOverSubstate());

				#if DISCORD_RPC
				Discord.changePresence("Game Over - " + songDetails, detailsSub, iconRPC);
				#end
			}

			// spawn in the notes from the array
			var spawnTime:Float = 2000;
			if (PlayState.SONG.speed > 0)
				spawnTime /= PlayState.SONG.speed;

			while (unspawnNotesIndex < unspawnNotes.length && unspawnNotes[unspawnNotesIndex] != null && ((unspawnNotes[unspawnNotesIndex].strumTime - Conductor.songPosition) < spawnTime))
			{
				var dunceNote:Note = unspawnNotes[unspawnNotesIndex];
				// push note to its correct strumline
				strumLines.members[Math.floor((dunceNote.noteData + (dunceNote.mustPress ? 4 : 0)) / numberOfKeys)].push(dunceNote);
				unspawnNotesIndex++;
			}

			noteCalls();

			if (Init.trueSettings.get('Controller Mode'))
				controllerInput();
			if (!lockCamPos) updateCamFollow();
		}
	}

	// maybe theres a better place to put this, idk -saw
	function controllerInput()
	{
		var justPressArray:Array<Bool> = [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P];

		var justReleaseArray:Array<Bool> = [controls.LEFT_R, controls.DOWN_R, controls.UP_R, controls.RIGHT_R];

		if (justPressArray.contains(true))
		{
			for (i in 0...justPressArray.length)
			{
				if (justPressArray[i])
					onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
			}
		}

		if (justReleaseArray.contains(true))
		{
			for (i in 0...justReleaseArray.length)
			{
				if (justReleaseArray[i])
					onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
			}
		}
	}

	function noteCalls()
	{
		// reset strums
		for (strumline in strumLines)
		{
			// handle strumline stuffs
			for (uiNote in strumline.receptors)
			{
				if (strumline.autoplay)
					strumCallsAuto(uiNote);
			}


		}

		// if the song is generated
		if (generatedMusic && startedCountdown)
		{
			var isDownscroll = Init.trueSettings.get('Downscroll');
			var isGhostTapping = Init.trueSettings.get('Ghost Tapping') ? true : false;
			for (strumline in strumLines)
			{
				// set the notes x and y
				var downscrollMultiplier = isDownscroll ? -1 : 1;
				if (isDownscroll)
					downscrollMultiplier = -1;

				strumline.allNotes.forEachAlive(function(daNote:Note)
				{
					var roundedSpeed = FlxMath.roundDecimal(daNote.noteSpeed, 2);
					var receptorPosY:Float = strumline.receptors.members[Math.floor(daNote.noteData)].y + Note.swagWidth / 6;
					var psuedoY:Float = (downscrollMultiplier * -((Conductor.songPosition - daNote.strumTime) * (0.45 * roundedSpeed)));
					var psuedoX = 25 + daNote.noteVisualOffset;

					var radians = flixel.math.FlxAngle.asRadians(daNote.noteDirection);
					var cosDir = Math.cos(radians);
					var sinDir = Math.sin(radians);

					daNote.y = receptorPosY
						+ (cosDir * psuedoY)
						+ (sinDir * psuedoX);
					// painful math equation
					daNote.x = strumline.receptors.members[Math.floor(daNote.noteData)].x
						+ (cosDir * psuedoX)
						+ (sinDir * psuedoY);

					// also set note rotation
					if (!daNote.isSustainNote)
						daNote.angle = -daNote.noteDirection;

					// Cleaned up sustain alignment logic
					var center:Float = receptorPosY + Note.swagWidth / 2;
					if (daNote.isSustainNote)
					{
						daNote.y -= ((daNote.height / 2) * downscrollMultiplier);
						if ((daNote.animation.curAnim.name.endsWith('holdend')) && (daNote.prevNote != null && daNote.prevNote.active))
						{
							if (daNote.prevNote.isSustainNote)
							{
								if (isDownscroll)
								{
									daNote.y = daNote.prevNote.y - daNote.height;
								}
								else
								{
									daNote.y = daNote.prevNote.y + daNote.prevNote.height;
								}
							}
							else
							{
								daNote.y -= ((daNote.prevNote.height / 2) * downscrollMultiplier);
								if (isDownscroll)
									daNote.y -= ((daNote.height / 2) * downscrollMultiplier);
								else
									daNote.y += ((daNote.height / 2) * downscrollMultiplier);
							}
						}

						if (isDownscroll)
						{
							daNote.flipY = true;
							if ((daNote.parentNote != null && daNote.parentNote.wasGoodHit)
								&& daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center
								&& (strumline.autoplay || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
							{
								var swagRect = daNote.clipRect;
								if (swagRect == null) swagRect = new flixel.math.FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
								var clipHeight = (center - daNote.y) / daNote.scale.y;
								swagRect.height = Math.min(Math.max(clipHeight, 0), daNote.frameHeight);
								swagRect.y = daNote.frameHeight - swagRect.height;
								daNote.clipRect = swagRect;
							}
						}
						else
						{
							if ((daNote.parentNote != null && daNote.parentNote.wasGoodHit)
								&& daNote.y + daNote.offset.y * daNote.scale.y <= center
								&& (strumline.autoplay || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
							{
								var swagRect = daNote.clipRect;
								if (swagRect == null) swagRect = new flixel.math.FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
								var clipY = (center - daNote.y) / daNote.scale.y;
								swagRect.y = Math.max(0, clipY);
								swagRect.height = Math.max(0, daNote.frameHeight - swagRect.y);
								daNote.clipRect = swagRect;
							}
						}
					}
					// hell breaks loose here, we're using nested scripts!
					mainControls(daNote, strumline.character, strumline, strumline.autoplay);

					// check where the note is and make sure it is either active or inactive
					var isOutOfScreen:Bool = false;
					if (isDownscroll)
						isOutOfScreen = (daNote.y - daNote.height > FlxG.height);
					else
						isOutOfScreen = (daNote.y + daNote.height < 0);

					if (isOutOfScreen)
					{
						daNote.active = false;
						daNote.visible = false;
					}
					else
					{
						daNote.visible = true;
						daNote.active = true;
					}

					if (!daNote.tooLate && daNote.strumTime < Conductor.songPosition - (Timings.msThreshold) && !daNote.wasGoodHit)
					{
						if ((!daNote.tooLate) && (daNote.mustPress))
						{
							if (!daNote.isSustainNote)
							{
								daNote.tooLate = true;
								for (note in daNote.childrenNotes)
									note.tooLate = true;

								vocals.volume = 0;
								missNoteCheck((Init.trueSettings.get('Ghost Tapping')) ? true : false, daNote.noteData, boyfriend, true);
								// ambiguous name
								Timings.updateAccuracy(0);
							}
							else if (daNote.isSustainNote)
							{
								if (daNote.parentNote != null)
								{
									var parentNote = daNote.parentNote;
									if (!parentNote.tooLate)
									{
										var breakFromLate:Bool = false;
										for (note in parentNote.childrenNotes)
										{
											trace('hold amount ${parentNote.childrenNotes.length}, note is late?' + note.tooLate + ', ' + breakFromLate);
											if (note.tooLate && !note.wasGoodHit)
												breakFromLate = true;
										}
										if (!breakFromLate)
										{
											missNoteCheck((Init.trueSettings.get('Ghost Tapping')) ? true : false, daNote.noteData, boyfriend, true);
											for (note in parentNote.childrenNotes)
												note.tooLate = true;
										}
										//
									}
								}
							}
						}
					}

					// if the note is off screen (above)
					if ((((!isDownscroll) && (daNote.y < -daNote.height))
						|| ((isDownscroll) && (daNote.y > (FlxG.height + daNote.height))))
						&& (daNote.tooLate || daNote.wasGoodHit))
						destroyNote(strumline, daNote);
				});

				// unoptimised asf camera control based on strums
				strumCameraRoll(strumline.receptors, (strumline == boyfriendStrums));
			}
		}

		// reset bf's animation
		var holdControls:Array<Bool> = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		if ((boyfriend != null && boyfriend.animation != null)
			&& (boyfriend.holdTimer > Conductor.stepCrochet * (4 / 1000) && (!holdControls.contains(true) || boyfriendStrums.autoplay)))
		{
			if (boyfriend.getAnimName().startsWith('sing') && !boyfriend.getAnimName().endsWith('miss'))
				boyfriend.dance();
		}
	}

	function destroyNote(strumline:Strumline, daNote:Note)
	{
		daNote.active = false;
		daNote.exists = false;

		var chosenGroup = (daNote.isSustainNote ? strumline.holdsGroup : strumline.notesGroup);
		// note damage here I guess
		daNote.kill();
		if (strumline.allNotes.members.contains(daNote))
			strumline.allNotes.remove(daNote, true);
		if (chosenGroup.members.contains(daNote))
			chosenGroup.remove(daNote, true);
		daNote.destroy();
	}

	function goodNoteHit(coolNote:Note, character:Character, characterStrums:Strumline, ?canDisplayJudgement:Bool = true)
	{
		if (!coolNote.wasGoodHit)
		{
			// eventHandler.onNoteHit(character == dadOpponent);
			coolNote.wasGoodHit = true;
			vocals.volume = 1;

			characterPlayAnimation(coolNote, character);
			if (characterStrums.receptors.members[coolNote.noteData] != null)
			{
				characterStrums.receptors.members[coolNote.noteData].playAnim('confirm', true);
				if (coolNote.isSustainNote)
				{
					characterStrums.receptors.members[coolNote.noteData].holdCoverTimer = Conductor.stepCrochet * 0.0015;
				}
			}

			// special thanks to sam, they gave me the original system which kinda inspired my idea for this new one
			if (canDisplayJudgement)
			{
				// get the note ms timing
				var noteDiff:Float = Math.abs(coolNote.strumTime - Conductor.songPosition);
				// get the timing
				var ratingTiming:String = "early";
				if (coolNote.strumTime < Conductor.songPosition)
					ratingTiming = "late";

				// loop through all avaliable judgements
				var foundRating:String = 'miss';
				var lowestThreshold:Float = Math.POSITIVE_INFINITY;
				for (myRating in Timings.judgementsMap.keys())
				{
					var myThreshold:Float = Timings.judgementsMap.get(myRating)[1];
					if (noteDiff <= myThreshold && (myThreshold < lowestThreshold))
					{
						foundRating = myRating;
						lowestThreshold = myThreshold;
					}
				}

				if (!coolNote.isSustainNote)
				{
					increaseCombo(foundRating, coolNote.noteData, character);
					popUpScore(foundRating, ratingTiming, characterStrums, coolNote);
					if (coolNote.childrenNotes.length > 0)
						Timings.notesHit++;
					healthCall(Timings.judgementsMap.get(foundRating)[3]);
				}
				else if (coolNote.isSustainNote)
				{
					// call updated accuracy stuffs
					if (coolNote.parentNote != null)
					{
						Timings.updateAccuracy(100, true, coolNote.parentNote.childrenNotes.length);
						healthCall(100 / coolNote.parentNote.childrenNotes.length);
					}
				}
			}

			if (!coolNote.isSustainNote)
				destroyNote(characterStrums, coolNote);
		}
	}

	function missNoteCheck(?includeAnimation:Bool = false, direction:Int = 0, character:Character, popMiss:Bool = false, lockMiss:Bool = false)
	{
		if (includeAnimation)
		{
			var stringDirection:String = UIStaticArrow.getArrowFromNumber(direction);

			FlxG.sound.play(Paths.soundRandom('system/miss/missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			character.playAnim('sing' + stringDirection.toUpperCase() + 'miss', lockMiss);
		}
		decreaseCombo(popMiss);

		//
	}

	function characterPlayAnimation(coolNote:Note, character:Character)
	{
		// alright so we determine which animation needs to play
		// get alt strings and stuffs
		var stringArrow:String = '';
		var altString:String = '';

		var baseString = 'sing' + UIStaticArrow.getArrowFromNumber(coolNote.noteData).toUpperCase();

		// I tried doing xor and it didnt work lollll
		if (coolNote.noteAlt > 0)
			altString = '-alt';
		if (((SONG.notes[Math.floor(curStep / 16)] != null) && (SONG.notes[Math.floor(curStep / 16)].altAnim))
			&& (character.animOffsets.exists(baseString + '-alt')))
		{
			if (altString != '-alt')
				altString = '-alt';
			else
				altString = '';
		}

		stringArrow = baseString + altString;
		// if (coolNote.foreverMods.get('string')[0] != "")
		//	stringArrow = coolNote.noteString;

		character.playAnim(stringArrow, true);
		character.holdTimer = 0;
	}

	private function strumCallsAuto(cStrum:UIStaticArrow, ?callType:Int = 1, ?daNote:Note):Void
	{
		switch (callType)
		{
			case 1:
				// end the animation if the calltype is 1 and it is done
				if ((cStrum.animation.finished) && (cStrum.canFinishAnimation))
					cStrum.playAnim('static');
			default:
				// check if it is the correct strum
				if (daNote.noteData == cStrum.ID)
				{
					// if (cStrum.animation.curAnim.name != 'confirm')
					cStrum.playAnim('confirm'); // play the correct strum's confirmation animation (haha rhymes)

					// stuff for sustain notes
					if ((daNote.isSustainNote) && (!daNote.animation.curAnim.name.endsWith('holdend')))
					{
						cStrum.canFinishAnimation = false; // basically, make it so the animation can't be finished if there's a sustain note below
						cStrum.holdCoverTimer = Conductor.stepCrochet * 0.0015;
					}
					else
					{
						cStrum.canFinishAnimation = true;
					}
				}
		}
	}

	private function mainControls(daNote:Note, char:Character, strumline:Strumline, autoplay:Bool):Void
	{
		var notesPressedAutoplay = [];

		// here I'll set up the autoplay functions
		if (autoplay)
		{
			// check if the note was a good hit
			if (daNote.strumTime <= Conductor.songPosition)
			{
				// kill the note, then remove it from the array
				var canDisplayJudgement = false;
				if (strumline.displayJudgements)
				{
					canDisplayJudgement = true;
					for (noteDouble in notesPressedAutoplay)
					{
						if (noteDouble.noteData == daNote.noteData)
						{
							// if (Math.abs(noteDouble.strumTime - daNote.strumTime) < 10)
							canDisplayJudgement = false;
							// removing the fucking check apparently fixes it
							// god damn it that stupid glitch with the double judgements is annoying
						}
					}
					notesPressedAutoplay.push(daNote);
				}
				goodNoteHit(daNote, char, strumline, canDisplayJudgement);
			}
		}

		var holdControls:Array<Bool> = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		if (!autoplay)
		{
			// check if anything is held
			if (holdControls.contains(true))
			{
				// check notes that are alive
				strumline.allNotes.forEachAlive(function(coolNote:Note)
				{
					if ((coolNote.parentNote != null && coolNote.parentNote.wasGoodHit)
						&& coolNote.canBeHit
						&& coolNote.mustPress
						&& !coolNote.tooLate
						&& coolNote.isSustainNote
						&& holdControls[coolNote.noteData])
						goodNoteHit(coolNote, char, strumline);
				});
			}
		}
	}

	private function strumCameraRoll(cStrum:FlxTypedGroup<UIStaticArrow>, mustHit:Bool)
	{
		if (cStrum == null || cStrum.members == null || cStrum.members.length < 4)
			return;

		if (!Init.trueSettings.get('No Camera Note Movement'))
		{
			var curSection = Std.int(curStep / 16);
			if (PlayState.SONG.notes[curSection] != null)
			{
				var charTurn:Focus;
				if (!mustHit)
					charTurn = DAD;
				else 
					charTurn = BF;

				if (charTurn != focus) return;

				camDisplaceX = 0;
				if (isConfirmedReceptor(cStrum.members[0]))
					camDisplaceX -= camDisplaceExtend;
				if (isConfirmedReceptor(cStrum.members[3]))
					camDisplaceX += camDisplaceExtend;

				camDisplaceY = 0;
				if (isConfirmedReceptor(cStrum.members[1]))
					camDisplaceY += camDisplaceExtend;
				if (isConfirmedReceptor(cStrum.members[2]))
					camDisplaceY -= camDisplaceExtend;
				
			}
		}
	}

	private function isConfirmedReceptor(receptor:UIStaticArrow):Bool
	{
		return receptor != null && receptor.animation != null && receptor.animation.curAnim != null
			&& receptor.animation.curAnim.name == 'confirm';
	}

	public function pauseGame()
	{
		// pause discord rpc
		updateRPC(true);

		// pause game
		paused = true;
		// eventHandler.onPause();

		// update drawing stuffs
		persistentUpdate = false;
		persistentDraw = true;

		// stop all tweens and timers
		FlxTimer.globalManager.forEach(function(tmr:FlxTimer)
		{
			if (!tmr.finished)
				tmr.active = false;
		});

		FlxTween.globalManager.forEach(function(twn:FlxTween)
		{
			if (!twn.finished)
				twn.active = false;
		});

		// open pause substate
		openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
	}

	override public function onFocus():Void
	{
		if (!paused)
			updateRPC(false);
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		if (canPause && !paused && !Init.trueSettings.get('Auto Pause'))
			pauseGame();
		super.onFocusLost();
	}

	public static function updateRPC(pausedRPC:Bool)
	{
		#if DISCORD_RPC
		var displayRPC:String = (pausedRPC) ? detailsPausedText : songDetails;

		if (health > 0)
		{
			if (Conductor.songPosition > 0 && !pausedRPC)
				Discord.changePresence(displayRPC, detailsSub, iconRPC, true, songLength - Conductor.songPosition);
			else
				Discord.changePresence(displayRPC, detailsSub, iconRPC);
		}
		#end
	}

	function popUpScore(baseRating:String, timing:String, strumline:Strumline, coolNote:Note)
	{
		// set up the rating
		var score:Int = 50;

		// notesplashes
		if (baseRating == "sick")
			// create the note splash if you hit a sick
			createSplash(coolNote, strumline);

		displayRating(baseRating, timing);
		Timings.updateAccuracy(Timings.judgementsMap.get(baseRating)[3]);
		score = Std.int(Timings.judgementsMap.get(baseRating)[2]);

		songScore += score;

		popUpCombo();
	}

	public function createSplash(coolNote:Note, strumline:Strumline)
	{
		if (strumline.splashNotes != null)
			strumline.createSplash(coolNote);
	}

	function popUpCombo(?cache:Bool = false)
	{
		if (!cache)
		{
			grpCombos.forEachAlive(function(numScore:FlxSprite)
			{
				FlxTween.cancelTweensOf(numScore);
				FlxTween.cancelTweensOf(numScore.scale);
				numScore.kill();
			});
		}

		var comboString:String = Std.string(combo);
		var negative = false;
		if ((comboString.startsWith('-')) || (combo == 0))
			negative = true;
		var stringArray:Array<String> = comboString.split("");


		for (scoreInt in 0...stringArray.length)
		{
			var numScore:FlxSprite = grpCombos.recycle(FlxSprite);
			var skinAsset = Utils.returnSkinAsset('num' + stringArray[scoreInt], assetModifier, changeableSkin, 'UI/combo');
			numScore.loadGraphic(Paths.image(skinAsset));

			numScore.alpha = 1;
			numScore.color = FlxColor.WHITE;
			
			if (assetModifier == 'pixel')
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
				numScore.antialiasing = false;
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * 0.3));
				numScore.antialiasing = true;
			}
			numScore.updateHitbox();

			numScore.screenCenter();
			numScore.x = (30 * scoreInt) + 550;
			numScore.y = 150 - (numScore.height / 2);

			var numScaleX:Float = numScore.scale.x;
			var numScaleY:Float = numScore.scale.y;
			numScore.scale.set(numScaleX * 1.15, numScaleY * 1.15);
			FlxTween.tween(numScore.scale, {x: numScaleX, y: numScaleY}, 0.2, {ease: FlxEase.cubeOut});

			if (!cache)
				numScore.cameras = [camHUD];

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.kill();
				},
				startDelay: Conductor.crochet * 0.002
			});
		}
	}

	function decreaseCombo(?popMiss:Bool = false)
	{
		// painful if statement
		if (((combo > 5) || (combo < 0)) && (gf.animOffsets.exists('sad')))
			gf.playAnim('sad');

		if (combo > 0)
			combo = 0; // bitch lmao
		else
			combo--;

		// misses
		songScore -= 10;
		misses++;

		// display negative combo
		if (popMiss)
		{
			// doesnt matter miss ratings dont have timings
			Timings.gottenJudgements.set("miss", Timings.gottenJudgements.get("miss") + 1);
			healthCall(Timings.judgementsMap.get("miss")[3]);
		}
		popUpCombo();

		// gotta do it manually here lol
		Timings.updateFCDisplay();
	}

	function increaseCombo(?baseRating:String, ?direction = 0, ?character:Character)
	{
		// trolled this can actually decrease your combo if you get a bad/shit/miss
		if (baseRating != null)
		{
			if (Timings.judgementsMap.get(baseRating)[3] > 0)
			{
				if (combo < 0)
					combo = 0;
				combo += 1;
			}
			else
				missNoteCheck(true, direction, character, false, true);
		}
	}

	public function displayRating(daRating:String, timing:String, ?cache:Bool = false)
	{
		if (!cache)
		{
			grpRatings.forEachAlive(function(rating:FlxSprite)
			{
				FlxTween.cancelTweensOf(rating);
				FlxTween.cancelTweensOf(rating.scale);
				rating.kill();
			});
		}

		var rating:FlxSprite = grpRatings.recycle(FlxSprite);
		var skinAsset = Utils.returnSkinAsset(daRating, assetModifier, changeableSkin, 'UI/combo');
		rating.loadGraphic(Paths.image(skinAsset));

		var width = 500;
		var height = 163;
		if (assetModifier == 'pixel')
		{
			width = 72;
			height = 32;
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom));
			rating.antialiasing = false;
		}
		else 
		{
			rating.setGraphicSize(Std.int(rating.width * 0.5));
			rating.antialiasing = true;
		}
		rating.updateHitbox();

		rating.alpha = 1;
		rating.screenCenter();
		rating.x = 550;
		rating.y = 60;
		
		var ratScaleX:Float = rating.scale.x;
		var ratScaleY:Float = rating.scale.y;
		rating.scale.set(ratScaleX * 1.15, ratScaleY * 1.15);
		FlxTween.tween(rating.scale, {x: ratScaleX, y: ratScaleY}, 0.2, {ease: FlxEase.cubeOut});
		
		rating.cameras = [camHUD];

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				rating.kill();
			},
			startDelay: Conductor.crochet * 0.00125
		});

		if (!cache)
		{
			Timings.gottenJudgements.set(daRating, Timings.gottenJudgements.get(daRating) + 1);
			if (Timings.smallestRating != daRating)
			{
				if (Timings.judgementsMap.get(Timings.smallestRating)[0] < Timings.judgementsMap.get(daRating)[0])
					Timings.smallestRating = daRating;
			}
		} 
	}

	function healthCall(?ratingMultiplier:Float = 0)
	{
		var healthBase:Float = 0.06;
		health += (healthBase * (ratingMultiplier / 100));
	}

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (!paused)
		{
			songMusic.play();
			vocals.play();

			resyncVocals();

			#if desktop
			// Song duration in a float, useful for the time left feature
			songLength = songMusic.length;

			// Updating Discord Rich Presence (with Time Left)
			updateRPC(false);
			#end
		}
	}

	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		songDetails = CoolUtil.dashToSpace(SONG.song);

		// String for when the game is paused
		detailsPausedText = "Paused - " + songDetails;

		// set details for song stuffs
		detailsSub = "";

		// Updating Discord Rich Presence.
		updateRPC(false);

		curSong = songData.song;
		songMusic = new FlxSound().loadEmbedded(Paths.inst(SONG.song), false, true);
		songMusic.onComplete = endSong;

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(SONG.song), false, true);
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(songMusic);
		FlxG.sound.list.add(vocals);

		// generate the chart
		unspawnNotes = ChartLoader.generateChartType(SONG, determinedChartType);
		// sometime my brain farts dont ask me why these functions were separated before

		// sort through them
		unspawnNotes.sort(sortByShit);
		// give the game the heads up to be able to start
		generatedMusic = true;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function resyncVocals():Void
	{
		if (songMusic == null) return;

		if (!songMusic.playing)
		{
			songMusic.play();
		}

		if (vocals != null)
		{
			var desync = Math.abs(songMusic.time - vocals.time);
			if (desync > 20 || !vocals.playing)
			{
				vocals.pause();
				vocals.time = songMusic.time;
				vocals.play();
			}
		}

		Conductor.songPosition = songMusic.time;
	}

	override function stepHit()
	{
		super.stepHit();

		if (stageBuild != null)
			stageBuild.stageStep(curStep);

		if (songMusic.time >= Conductor.songPosition + 20 || songMusic.time <= Conductor.songPosition - 20)
			resyncVocals();
	}

	private function charactersDance(curBeat:Int)
	{
		if ((curBeat % gfSpeed == 0) && (gf.getAnimName().startsWith("idle") || gf.getAnimName().startsWith("dance")))
			gf.dance();

		if ((boyfriend.getAnimName().startsWith("idle") || boyfriend.getAnimName().startsWith("dance"))
			&& (curBeat % 2 == 0 || boyfriend.characterData.quickDancer))
			boyfriend.dance();

		// added this for opponent cus it wasn't here before and skater would just freeze
		if ((dadOpponent.getAnimName().startsWith("idle") || dadOpponent.getAnimName().startsWith("dance"))
			&& (curBeat % 2 == 0 || dadOpponent.characterData.quickDancer))
			dadOpponent.dance();
	}

	override function beatHit()
	{
		super.beatHit();

		if (uiHUD != null)
			uiHUD.beatHit(curBeat);
			
		updateRPC(false);

		if ((FlxG.camera.zoom < defaultCamZoom + 0.35 && curBeat % 4 == 0) && (!Init.trueSettings.get('Reduced Movements')))
		{
			FlxG.camera.zoom += 0.015;
			for (hud in allUIs)
				hud.zoom += 0.03;
		}

		if (SONG.notes[Math.floor(curStep / 16)] != null)
		{
			if (SONG.notes[Math.floor(curStep / 16)].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[Math.floor(curStep / 16)].bpm);
			}
		}

		charactersDance(curBeat);

		// stage stuffs
		stageBuild.stageUpdate(curBeat, boyfriend, gf, dadOpponent);
	}

	public static function resetMusic()
	{
		// simply stated, resets the playstate's music for other states and substates
		if (songMusic != null)
			songMusic.stop();

		if (vocals != null)
			vocals.stop();
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (songMusic != null)
			{
				songMusic.pause();
				vocals.pause();
			}
			camGame.active = false;
			camHUD.active = false;
			camText.active = false;
			timerManager.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (songMusic != null && !startingSong)
				resyncVocals();

			// resume all tweens and timers
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer)
			{
				if (!tmr.finished)
					tmr.active = true;
			});

			FlxTween.globalManager.forEach(function(twn:FlxTween)
			{
				if (!twn.finished)
					twn.active = true;
			});

			paused = false;

			updateRPC(false);

			timerManager.active = true;
			camGame.active = true;
			camHUD.active = true;
			camText.active = true;
		}

		super.closeSubState();
	}
	function endSong():Void
	{
		canPause = false;
		Utils.killMusic([songMusic, vocals]);
		if (SONG.validScore)
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);

		deaths = 0;

		// play menu music
		Utils.resetMenuMusic();

		// set up transitions
		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		// change to the menu state
		Main.switchState(this, new MainMenuState());
		// save the week's score if the score is valid
		if (SONG.validScore)
			Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);

		// flush the save
		FlxG.save.flush();
	}

	private function callDefaultSongEnd()
	{
		var difficulty:String = '-' + CoolUtil.difficultyFromNumber(storyDifficulty).toLowerCase();
		difficulty = difficulty.replace('-normal', '');

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + difficulty, PlayState.storyPlaylist[0]);
		Utils.killMusic([songMusic, vocals]);

		// deliberately did not use the main.switchstate as to not unload the assets
		FlxG.switchState(new PlayState());
	}

	public static var swagCounter:Int = 0;

	private function startCountdown():Void
	{
		inCutscene = false;
		startedCountdown = true;
		charactersDance(curBeat);
		Conductor.songPosition = -(Conductor.crochet * 1);
		swagCounter = 0;
	}

	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}
}

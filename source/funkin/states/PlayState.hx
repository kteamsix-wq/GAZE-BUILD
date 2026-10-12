package funkin.states;

import Paths;
import Utils;
import Assets;
import Init;
import openfl.events.KeyboardEvent;

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
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.util.FlxTimer.FlxTimerManager;

import backend.MusicBeatState;
import backend.Song;
import backend.Song.SwagSong;
import backend.Conductor;
import backend.Highscore;
import backend.Timings;
import backend.HScriptHandler;
import backend.CoolUtil;
import backend.HealthIcon;

import funkin.objects.FunkinArrows;
import funkin.objects.FunkinArrows.UIStaticArrow;
import funkin.objects.FunkinArrows.Strumline;
import funkin.objects.FunkinArrows.Note;
import funkin.objects.FunkinArrows.NoteSplash;
import funkin.objects.Character;
import funkin.objects.Boyfriend;
import funkin.objects.Stage;
import funkin.substates.PauseSubState;
import funkin.substates.GameOverSubstate;
import funkin.editors.ChartEditor;
import funkin.game.modchart.ModManager;
import funkin.backend.math.Vector3;

#if desktop
import backend.Discord;
#end

using StringTools;

/**
 * Represents the current camera focus target in PlayState.
 */
enum Focus
{
	BF;
	DAD;
	CENTER;
	NONE;
}

/**
 * The core gameplay state. Handles chart loading, note spawning, audio playback,
 * characters, HUD rendering, cameras, scoring, and input.
 */
class PlayState extends MusicBeatState
{
	// =========================================================================
	// SECTION 1: STATIC VARIABLES & STATE
	// =========================================================================

	// Instance references
	public static var instance:PlayState;
	public static var uiHUD:PlayState;

	// Story & Week configuration
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 2;
	public static var campaignScore:Int = 0;

	// Song & Stage data
	public static var SONG:SwagSong;
	public static var curStage:String = '';
	public static var defaultSongSpeed:Float = 1.0;
	public static var songLength:Float = 0;
	public static var assetModifier:String = 'base';
	public static var changeableSkin:String = 'default';
	public static var determinedChartType:String = "";
	public static var daPixelZoom:Float = 6;

	// Audio
	public static var songMusic:FlxSound;
	public static var vocals:FlxSound;

	// Characters
	public static var boyfriend:Boyfriend;
	public static var dadOpponent:Character;
	public static var gf:Character;

	// Gameplay stats
	public static var health:Float = 1;
	public static var combo:Int = 0;
	public static var songScore:Int = 0;
	public static var misses:Int = 0;
	public static var deaths:Int = 0;

	// Cameras (camGame, camHUD, camAlt)
	public static var camGame:FlxCamera;
	public static var camHUD:FlxCamera;
	public static var camAlt:FlxCamera;

	// Camera state
	public static var defaultCamZoom:Float = 1.05;
	public static var forceZoom:Array<Float>;
	public static var focus:Focus = DAD;
	public static var lockCamPos:Bool = false;
	public static var lockFocus:Bool = false;

	// Strumline static references
	public static var dadStrums:Strumline;
	public static var boyfriendStrums:Strumline;
	public static var strumLines:FlxTypedGroup<Strumline>;

	// Discord Rich Presence
	public static var songDetails:String = "";
	public static var detailsSub:String = "";
	public static var detailsPausedText:String = "";
	public static var iconRPC:String = "";

	// Management & Timers
	public static var timerManager:FlxTimerManager = new FlxTimerManager();
	public static var swagCounter:Int = 0;
	private static var prevCamFollow:FlxObject;

	// Vector cache for modcharts
	public static var _modchartVector:Vector3 = Vector3.get();

	// =========================================================================
	// SECTION 2: INSTANCE VARIABLES
	// =========================================================================

	// Stage & Scripts
	public var stageBuild:Stage;
	public var hscriptArray:Array<HScriptHandler> = [];

	// Modchart Manager
	public var modManager:ModManager;

	// Camera Tracking
	public var camFollow:FlxObject;
	public var camFollowPos:FlxObject;
	public var camPos:FlxPoint;
	public var camDisplaceX:Float = 0;
	public var camDisplaceY:Float = 0;
	public var targetCamDisplaceX:Float = 0;
	public var targetCamDisplaceY:Float = 0;
	public var camDisplaceExtend:Float = 12;

	// HUD Elements (Moved from ClassHUD)
	public var scoreBar:FlxText;
	public var centerMark:FlxText;
	public var autoplayMark:FlxText;
	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var currentColorP1:FlxColor;
	public var currentColorP2:FlxColor;
	public var displayedScore:Float = 0;
	private var autoplaySine:Float = 0;
	private final divider:String = " • ";

	// Judgement & Combo Sprite Groups
	public var grpRatings:FlxTypedGroup<FlxSprite>;
	public var grpCombos:FlxTypedGroup<FlxSprite>;

	// Note queues & chart generation
	private var unspawnNotes:Array<Note> = [];
	private var unspawnNotesIndex:Int = 0;
	private var eventNotes:Array<Dynamic> = [];
	private var numberOfKeys:Int = 4;

	// Gameplay flags & timing
	public var generatedMusic:Bool = false;
	public var paused:Bool = false;
	private var startingSong:Bool = false;
	private var startedCountdown:Bool = false;
	private var inCutscene:Bool = false;
	private var canPause:Bool = true;
	private var curSong:String = "";
	private var gfSpeed:Int = 1;
	private var previousFrameTime:Int = 0;
	private var lastReportedPlayheadPosition:Int = 0;
	private var songTime:Float = 0;
	private var lastSection:Int = 0;

	// Input handling
	private var keysArray:Array<Dynamic>;
	private var keysPressed:Map<Int, Bool> = new Map<Int, Bool>();

	// Event Tweens & Timers
	private var scrollTween:FlxTween;
	private var scrollTimer:FlxTimer;

	// =========================================================================
	// SECTION 3: LIFECYCLE (resetStatics, create, destroy)
	// =========================================================================

	private function resetStatics():Void
	{
		instance = this;
		uiHUD = this;
		focus = DAD;
		timerManager.active = true;
		lockCamPos = false;
		lockFocus = false;

		songScore = 0;
		combo = 0;
		health = 1;
		misses = 0;

		defaultCamZoom = 1.05;
		forceZoom = [0, 0, 0, 0];

		assetModifier = 'base';
		changeableSkin = 'default';

		if (PlayState.SONG != null)
			PlayState.SONG.validScore = true;
	}

	override public function create():Void
	{
		super.create();

		resetStatics();
		Timings.callAccuracy();

		// Stop existing music
		resetMusic();
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Setup cameras: only camGame, camHUD, and camAlt
		camGame = new FlxCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		camAlt = new FlxCamera();
		camAlt.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camAlt, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// Groups for judgements and combo counters (placed on camHUD)
		grpRatings = new FlxTypedGroup<FlxSprite>();
		grpRatings.cameras = [camHUD];
		add(grpRatings);

		grpCombos = new FlxTypedGroup<FlxSprite>();
		grpCombos.cameras = [camHUD];
		add(grpCombos);

		// Song & BPM setup
		if (SONG == null)
			SONG = Song.loadFromJson('test', 'test');

		if (SONG.defaultSpeed != null)
		{
			defaultSongSpeed = SONG.defaultSpeed;
			SONG.speed = defaultSongSpeed;
		}
		else
		{
			defaultSongSpeed = SONG.speed;
			SONG.defaultSpeed = SONG.speed;
		}

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);
		GameOverSubstate.resetVariables();

		determinedChartType = "FNF";
		curStage = (SONG.stage != null) ? SONG.stage : "";

		initScripts();
		callOnScripts('onCreate');

		// Pre-cache judgement assets & sounds
		displayRating('sick', 'early', true);
		popUpCombo(true);
		for (i in 1...4)
			Paths.sound('system/miss/missnote' + i);
		Paths.image('UI/combo/default/good');
		Paths.image('UI/combo/default/bad');
		Paths.image('UI/combo/default/shit');
		Paths.getSparrowAtlas(Utils.returnSkinAsset('splash', assetModifier, changeableSkin, 'UI/notes'));

		// Initialize ModManager
		modManager = new ModManager(this);
		modManager.lanes = 2;
		modManager.keys = 4;
		modManager.registerEssentialModifiers();
		modManager.registerDefaultModifiers();
		modManager.registerScriptedModifiers();

		// Initialize Stage & Characters
		stageBuild = new Stage(curStage);
		add(stageBuild.background);

		gf = new Character();
		gf.adjustPos = false;
		var daGF:String = (SONG.gfVersion != null && SONG.gfVersion.length > 0) ? SONG.gfVersion : ((SONG.player3 != null && SONG.player3.length > 0) ? SONG.player3 : stageBuild.returnGFtype(curStage));
		gf.setCharacter(300, 100, daGF);
		gf.scrollFactor.set(0.95, 0.95);

		dadOpponent = new Character().setCharacter(50, 850, SONG.player2);
		boyfriend = new Boyfriend();
		boyfriend.setCharacter(750, 850, SONG.player1);

		camPos = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
		stageBuild.repositionPlayers(curStage, boyfriend, dadOpponent, gf);
		stageBuild.dadPosition(curStage, boyfriend, dadOpponent, gf, camPos);

		if (SONG.assetModifier != null && SONG.assetModifier.length > 1)
			assetModifier = SONG.assetModifier;

		changeableSkin = Init.trueSettings.get("UI Skin");

		add(gf);
		add(dadOpponent);
		add(boyfriend);
		add(stageBuild.foreground);

		#if sys
		if (stageBuild != null && stageBuild.interp != null) {
			stageBuild.interp.variables.set("boyfriend", boyfriend);
			stageBuild.interp.variables.set("dad", dadOpponent);
			stageBuild.interp.variables.set("dadOpponent", dadOpponent);
			stageBuild.interp.variables.set("gf", gf);
			stageBuild.interp.variables.set("camGame", camGame);
			stageBuild.interp.variables.set("camHUD", camHUD);
			stageBuild.interp.variables.set("camAlt", camAlt);
		}
		#end

		dadOpponent.dance();
		gf.dance();
		boyfriend.dance();

		Conductor.songPosition = -(Conductor.crochet * 4);

		// Setup camera follow targets
		camPos.set(gf.x + (gf.frameWidth / 2), gf.y + (gf.frameHeight / 2));
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		// Generate song chart & notes
		generateSong(SONG.song);

		// Setup strumlines (placed entirely on camHUD)
		startingSong = true;
		startedCountdown = true;

		var placement = (FlxG.width / 2);
		var valThing = (FlxG.width / 4);

		strumLines = new FlxTypedGroup<Strumline>();
		strumLines.cameras = [camHUD];

		dadStrums = new Strumline(placement - valThing, this, dadOpponent, false, true, false, 4, Init.trueSettings.get('Downscroll'));
		dadStrums.visible = !Init.trueSettings.get('Centered Notefield');
		dadStrums.player = 1;
		dadStrums.cameras = [camHUD];

		boyfriendStrums = new Strumline(placement + (!Init.trueSettings.get('Centered Notefield') ? valThing : 0), this, boyfriend, true, false, true, 4, Init.trueSettings.get('Downscroll'));
		boyfriendStrums.player = 0;
		boyfriendStrums.cameras = [camHUD];

		strumLines.add(dadStrums);
		strumLines.add(boyfriendStrums);
		add(strumLines);

		modManager.receptors = [boyfriendStrums.receptors.members, dadStrums.receptors.members];

		for (script in hscriptArray) {
			script.setVar("modManager", modManager);
		}
		#if sys
		if (stageBuild != null && stageBuild.interp != null) {
			stageBuild.interp.variables.set("modManager", modManager);
		}
		#end

		// Setup HUD Elements (health bar, icons, score and botplay marks on camHUD)
		setupHUD();

		// Keyboard controls mapping
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

		// Expose variables to scripts
		for (script in hscriptArray) {
			script.setVar("boyfriend", boyfriend);
			script.setVar("dad", dadOpponent);
			script.setVar("dadOpponent", dadOpponent);
			script.setVar("gf", gf);
			script.setVar("modManager", modManager);
			script.setVar("camGame", camGame);
			script.setVar("camHUD", camHUD);
			script.setVar("camAlt", camAlt);
			script.setVar("iconP1", iconP1);
			script.setVar("iconP2", iconP2);
			script.setVar("healthBar", healthBar);
			script.setVar("healthBarBG", healthBarBG);
			script.setVar("scoreBar", scoreBar);
		}
		#if sys
		if (stageBuild != null && stageBuild.interp != null) {
			stageBuild.interp.variables.set("boyfriend", boyfriend);
			stageBuild.interp.variables.set("dad", dadOpponent);
			stageBuild.interp.variables.set("dadOpponent", dadOpponent);
			stageBuild.interp.variables.set("gf", gf);
			stageBuild.interp.variables.set("modManager", modManager);
			stageBuild.interp.variables.set("camGame", camGame);
			stageBuild.interp.variables.set("camHUD", camHUD);
			stageBuild.interp.variables.set("camAlt", camAlt);
		}
		#end

		callOnScripts('onCreatePost');
	}

	override public function destroy():Void
	{
		if (scrollTween != null)
		{
			scrollTween.cancel();
			scrollTween = null;
		}
		if (scrollTimer != null)
		{
			scrollTimer.cancel();
			scrollTimer = null;
		}
		if (SONG != null)
		{
			if (SONG.defaultSpeed != null)
				SONG.speed = SONG.defaultSpeed;
			else
				SONG.speed = defaultSongSpeed;
		}

		if (!Init.trueSettings.get('Controller Mode'))
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		if (modManager != null)
		{
			modManager = flixel.util.FlxDestroyUtil.destroy(modManager);
		}

		super.destroy();
	}

	// =========================================================================
	// SECTION 4: UPDATE & BEAT / STEP HIT LOOP
	// =========================================================================

	override public function update(elapsed:Float):Void
	{
		stageBuild.stageUpdateConstant(elapsed);

		super.update(elapsed);
		callOnScripts('onUpdate', [elapsed]);
		timerManager.update(elapsed);

		// ModManager updates
		if (modManager != null)
		{
			modManager.updateTimeline(curDecStep);
			modManager.update(elapsed);

			for (strumline in strumLines)
			{
				var pID:Int = (strumline == boyfriendStrums ? 0 : 1);
				for (receptor in strumline.receptors)
				{
					if (receptor != null && receptor.alive)
					{
						var pos = modManager.getPos(0, 0, 0, curDecBeat, receptor.babyArrowType, pID, receptor, _modchartVector);
						modManager.updateObject(curDecBeat, receptor, pos, pID);
						receptor.updateOffsets();
						receptor.alpha = receptor.setAlpha * receptor.alphaMod;
					}
				}
			}
		}

		if (health > 2)
			health = 2;

		if (!inCutscene)
		{
			// Pause check
			if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
			{
				pauseGame();
			}

			// Debug shortcut keys
			if (!isStoryMode)
			{
				if (FlxG.keys.justPressed.SEVEN && !startingSong)
				{
					resetMusic();
					Main.switchState(this, new ChartEditor());
				}

				if (FlxG.keys.justPressed.EIGHT && !startingSong)
				{
					resetMusic();
					Main.switchState(this, new funkin.editors.CharacterEditor());
				}

				if (FlxG.keys.justPressed.SIX)
				{
					boyfriendStrums.autoplay = !boyfriendStrums.autoplay;
					if (autoplayMark != null)
						autoplayMark.visible = boyfriendStrums.autoplay;
					PlayState.SONG.validScore = false;
				}
			}

			// Song position progression
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
				if (songMusic != null && songMusic.length > 0 && Conductor.songPosition > songMusic.length)
					Conductor.songPosition = songMusic.length;

				if (!paused)
				{
					songTime += FlxG.game.ticks - previousFrameTime;
					previousFrameTime = FlxG.game.ticks;

					if (Conductor.lastSongPos != Conductor.songPosition)
					{
						songTime = (songTime + Conductor.songPosition) / 2;
						Conductor.lastSongPos = Conductor.songPosition;
					}
				}
			}

			// Focus camera based on current section
			var curSection = Std.int(curStep / 16);
			if (generatedMusic && PlayState.SONG.notes[curSection] != null)
			{
				if (curSection != lastSection)
				{
					var lastMustHit:Bool = PlayState.SONG.notes[lastSection].mustHitSection;
					if (PlayState.SONG.notes[curSection].mustHitSection != lastMustHit)
					{
						targetCamDisplaceX = 0;
						targetCamDisplaceY = 0;
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

			// Smooth camera displacement & position lerping
			var displaceLerp = Math.exp(-elapsed * 10.0);
			camDisplaceX = FlxMath.lerp(targetCamDisplaceX, camDisplaceX, displaceLerp);
			camDisplaceY = FlxMath.lerp(targetCamDisplaceY, camDisplaceY, displaceLerp);

			var camLerp = Math.exp(-elapsed * 6.0);
			camFollowPos.x = FlxMath.lerp(camFollow.x, camFollowPos.x, camLerp);
			camFollowPos.y = FlxMath.lerp(camFollow.y, camFollowPos.y, camLerp);

			// Camera zoom lerping for camGame, camHUD, camAlt
			var easeLerp = Math.exp(-elapsed * 3.0);
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom + forceZoom[0], FlxG.camera.zoom, easeLerp);
			camHUD.zoom = FlxMath.lerp(1 + forceZoom[1], camHUD.zoom, easeLerp);
			camAlt.zoom = FlxMath.lerp(1 + forceZoom[1], camAlt.zoom, easeLerp);

			// RESET shortcut
			if (controls.RESET && !startingSong && !isStoryMode)
			{
				health = 0;
			}

			// Game Over check
			if (health <= 0 && startedCountdown)
			{
				paused = true;
				persistentUpdate = false;
				persistentDraw = false;

				resetMusic();
				deaths += 1;

				camHUD.visible = false;
				camAlt.visible = false;
				openSubState(new GameOverSubstate(boyfriend));

				#if DISCORD_RPC
				Discord.changePresence("Game Over - " + songDetails, detailsSub, iconRPC);
				#end
			}

			// Process event notes
			while (eventNotes.length > 0)
			{
				var leEvent:Dynamic = eventNotes[0];
				if (Conductor.songPosition < leEvent[0]) break;

				triggerEvent(leEvent[1], leEvent[2], leEvent[3]);
				eventNotes.shift();
			}

			// Note spawning from unspawn queue
			var spawnTime:Float = 2000;
			if (PlayState.SONG.speed > 0)
				spawnTime /= PlayState.SONG.speed;

			while (unspawnNotesIndex < unspawnNotes.length && unspawnNotes[unspawnNotesIndex] != null && ((unspawnNotes[unspawnNotesIndex].strumTime - Conductor.songPosition) < spawnTime))
			{
				var dunceNote:Note = unspawnNotes[unspawnNotesIndex];
				strumLines.members[dunceNote.playfield].push(dunceNote);
				unspawnNotesIndex++;
			}

			noteCalls();

			if (Init.trueSettings.get('Controller Mode'))
				controllerInput();

			if (!lockCamPos)
				updateCamFollow();
		}

		// Update HUD (health bar, score lerp, autoplay mark)
		updateHUD(elapsed);
	}

	override function stepHit():Void
	{
		super.stepHit();

		if (stageBuild != null)
			stageBuild.stageStep(curStep);

		callOnScripts('onStepHit', [curStep]);

		if (!startingSong && songMusic != null && songMusic.playing && (songMusic.time >= Conductor.songPosition + 20 || songMusic.time <= Conductor.songPosition - 20))
			resyncVocals();
	}

	override function beatHit():Void
	{
		super.beatHit();

		hudBeatHit(curBeat);

		callOnScripts('onBeatHit', [curBeat]);
		updateRPC(false);

		if (!startingSong && (FlxG.camera.zoom < defaultCamZoom + 0.35 && curBeat % 4 == 0) && (!Init.trueSettings.get('Reduced Movements')))
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
			camAlt.zoom += 0.03;
		}

		if (SONG.notes[Math.floor(curStep / 16)] != null)
		{
			if (SONG.notes[Math.floor(curStep / 16)].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[Math.floor(curStep / 16)].bpm);
			}
		}

		charactersDance(curBeat);
		stageBuild.stageUpdate(curBeat);
	}

	private function charactersDance(curBeat:Int):Void
	{
		if ((curBeat % gfSpeed == 0) && (gf.getAnimName().startsWith("idle") || gf.getAnimName().startsWith("dance")))
			gf.dance();

		if ((boyfriend.getAnimName().startsWith("idle") || boyfriend.getAnimName().startsWith("dance"))
			&& (curBeat % 2 == 0 || boyfriend.characterData.quickDancer))
			boyfriend.dance();

		if ((dadOpponent.getAnimName().startsWith("idle") || dadOpponent.getAnimName().startsWith("dance"))
			&& (curBeat % 2 == 0 || dadOpponent.characterData.quickDancer))
			dadOpponent.dance();
	}

	public function resyncVocals():Void
	{
		if (songMusic == null || startingSong) return;

		if (!songMusic.playing)
			songMusic.play();

		if (vocals != null && vocals.exists)
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

	// =========================================================================
	// SECTION 5: CAMERA SYSTEM
	// =========================================================================

	private function updateCamFollow():Void
	{
		switch(focus)
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

	private function strumCameraRoll(cStrum:FlxTypedGroup<UIStaticArrow>, mustHit:Bool):Void
	{
		if (cStrum == null || cStrum.members == null || cStrum.members.length < 4)
			return;

		if (!Init.trueSettings.get('No Camera Note Movement'))
		{
			var curSection = Std.int(curStep / 16);
			if (PlayState.SONG.notes[curSection] != null)
			{
				var charTurn:Focus = (!mustHit) ? DAD : BF;
				if (charTurn != focus) return;

				targetCamDisplaceX = 0;
				if (isConfirmedReceptor(cStrum.members[0]))
					targetCamDisplaceX -= camDisplaceExtend;
				if (isConfirmedReceptor(cStrum.members[3]))
					targetCamDisplaceX += camDisplaceExtend;

				targetCamDisplaceY = 0;
				if (isConfirmedReceptor(cStrum.members[1]))
					targetCamDisplaceY += camDisplaceExtend;
				if (isConfirmedReceptor(cStrum.members[2]))
					targetCamDisplaceY -= camDisplaceExtend;
			}
		}
	}

	private function isConfirmedReceptor(receptor:UIStaticArrow):Bool
	{
		return receptor != null && receptor.animation != null && receptor.animation.curAnim != null
			&& receptor.animation.curAnim.name == 'confirm';
	}

	// =========================================================================
	// SECTION 6: HUD & UI SYSTEM (Moved from ClassHUD)
	// =========================================================================

	public function setupHUD():Void
	{
		setupHealthBar();
		setupIcons();
		setupTextElements();
		updateScoreText();
	}

	private function setupHealthBar():Void
	{
		var isDownscroll:Bool = Init.trueSettings.get('Downscroll');

		healthBarBG = new FlxSprite(0, isDownscroll ? FlxG.height * 0.11 : FlxG.height * 0.89);
		healthBarBG.loadGraphic(Paths.image('UI/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.cameras = [camHUD];
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8));
		healthBar.scrollFactor.set();
		healthBar.setRange(0, 2);
		healthBar.value = health;
		healthBar.cameras = [camHUD];

		var dadColors = dadOpponent.healthColorArray;
		var bfColors = boyfriend.healthColorArray;

		currentColorP2 = FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]);
		currentColorP1 = FlxColor.fromRGB(bfColors[0], bfColors[1], bfColors[2]);

		healthBar.createFilledBar(currentColorP2, currentColorP1);
		add(healthBar);
	}

	private function setupIcons():Void
	{
		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		iconP1.cameras = [camHUD];
		add(iconP1);

		iconP2 = new HealthIcon(dadOpponent.healthIcon, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		iconP2.cameras = [camHUD];
		add(iconP2);
	}

	private function setupTextElements():Void
	{
		var isDownscroll:Bool = Init.trueSettings.get('Downscroll');
		var font:String = Paths.font('vcr.ttf');

		scoreBar = new FlxText(490, isDownscroll ? 29 : 680, 0, "");
		scoreBar.setFormat(font, 18, FlxColor.WHITE);
		scoreBar.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		scoreBar.antialiasing = true;
		scoreBar.cameras = [camHUD];
		add(scoreBar);

		var infoDisplay:String = CoolUtil.dashToSpace(SONG.song);
		centerMark = new FlxText(0, isDownscroll ? FlxG.height - 40 : 10, 0, 'K-Slice 0.1-alpha | ' + [infoDisplay]);
		centerMark.setFormat(font, 24, FlxColor.WHITE);
		centerMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		centerMark.screenCenter(X);
		centerMark.antialiasing = true;
		centerMark.cameras = [camHUD];
		add(centerMark);

		autoplayMark = new FlxText(-5, centerMark.y + (isDownscroll ? -60 : 60), FlxG.width - 800, '[BOTPLAY]\n', 32);
		autoplayMark.setFormat(font, 32, FlxColor.WHITE, CENTER);
		autoplayMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		autoplayMark.screenCenter(X);
		autoplayMark.visible = boyfriendStrums.autoplay;
		autoplayMark.cameras = [camHUD];

		if (Init.trueSettings.get('Centered Notefield'))
			autoplayMark.y += isDownscroll ? -125 : 125;

		add(autoplayMark);
	}

	public function updateColors(colorP1:FlxColor, colorP2:FlxColor):Void
	{
		currentColorP1 = colorP1;
		currentColorP2 = colorP2;
		if (healthBar != null)
		{
			healthBar.createFilledBar(currentColorP2, currentColorP1);
			healthBar.updateBar();
		}
	}

	public function updateHUD(elapsed:Float):Void
	{
		updateHealthBar(elapsed);
		updateScoreLerp(elapsed);

		if (autoplayMark != null && autoplayMark.visible)
		{
			autoplaySine += 180 * (elapsed / 4);
			autoplayMark.alpha = 1 - Math.sin((Math.PI * autoplaySine) / 80);
		}
	}

	private function updateHealthBar(elapsed:Float):Void
	{
		if (healthBar == null) return;

		healthBar.value = FlxMath.lerp(healthBar.value, health, Math.exp(-elapsed * 15));
		healthBar.updateBar();

		var iconP1Health = FlxMath.remapToRange(healthBar.value, 0, 2, 0, 100);
		if (iconP1 != null)
		{
			iconP1.updateAnim(iconP1Health);
			var mult1:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9));
			iconP1.scale.set(mult1, mult1);
			iconP1.updateHitbox();
		}

		if (iconP2 != null)
		{
			iconP2.updateAnim(100 - iconP1Health);
			var mult2:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9));
			iconP2.scale.set(mult2, mult2);
			iconP2.updateHitbox();
		}

		var iconOffset:Int = 26;
		var percentMath:Float = FlxMath.remapToRange(healthBar.value, 0, 2, 100, 0) * 0.01;
		var iconPos:Float = healthBar.x + (healthBar.width * percentMath);

		if (iconP1 != null)
		{
			iconP1.x = iconPos - iconOffset;
			iconP1.y = healthBar.y - (iconP1.height / 2);
		}

		if (iconP2 != null)
		{
			iconP2.x = iconPos - (iconP2.width - iconOffset);
			iconP2.y = healthBar.y - (iconP2.height / 2);
		}
	}

	private function updateScoreLerp(elapsed:Float):Void
	{
		if (Math.abs(displayedScore - songScore) > 0.1)
		{
			displayedScore = FlxMath.lerp(displayedScore, songScore, elapsed * 15);
			if (Math.abs(displayedScore - songScore) < 0.1)
				displayedScore = songScore;

			updateScoreText();
		}
	}

	public function hudBeatHit(beat:Int):Void
	{
		if (iconP1 != null)
		{
			iconP1.scale.set(1.2, 1.2);
			iconP1.updateHitbox();
		}
		if (iconP2 != null)
		{
			iconP2.scale.set(1.2, 1.2);
			iconP2.updateHitbox();
		}
	}

	private function formatScore(score:Int):String
	{
		var str = Std.string(score);
		var formatted = "";
		var count = 0;
		for (i in 0...str.length)
		{
			var idx = str.length - 1 - i;
			formatted = str.charAt(idx) + formatted;
			count++;
			if (count == 3 && idx > 0 && str.charAt(idx - 1) != "-")
			{
				formatted = "," + formatted;
				count = 0;
			}
		}
		return formatted;
	}

	public function updateScoreText():Void
	{
		if (scoreBar == null) return;

		var rankDisplay = Timings.returnScoreRating().toUpperCase();
		if (rankDisplay == "" || rankDisplay == "?" || rankDisplay == null)
			rankDisplay = "N/A";

		scoreBar.text = 'Score: ${formatScore(Math.round(displayedScore))}$divider Misses: $misses$divider Rank: $rankDisplay';
		scoreBar.screenCenter(X);

		detailsSub = scoreBar.text;
	}

	// =========================================================================
	// SECTION 7: INPUT HANDLING
	// =========================================================================

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
				if (songMusic != null && songMusic.playing)
					Conductor.songPosition = songMusic.time;

				var possibleNoteList:Array<Note> = [];
				var pressedNotes:Array<Note> = [];

				for (daNote in boyfriendStrums.allNotes.members)
				{
					if (daNote != null && daNote.alive && (daNote.noteData == key) && daNote.canBeHit && !daNote.isSustainNote && !daNote.tooLate && !daNote.wasGoodHit)
						possibleNoteList.push(daNote);
				}
				possibleNoteList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (possibleNoteList.length > 0)
				{
					var eligable = true;
					var firstNote = true;
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
							goodNoteHit(coolNote, boyfriend, boyfriendStrums, firstNote);
							pressedNotes.push(coolNote);
						}
					}
				}
				else
				{
					if (!Init.trueSettings.get('Ghost Tapping'))
						missNoteCheck(true, key, boyfriend, true);
				}
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

	private function controllerInput():Void
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

	// =========================================================================
	// SECTION 8: CHART & NOTE SYSTEM
	// =========================================================================

	private function generateSong(dataPath:String):Void
	{
		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		songDetails = CoolUtil.dashToSpace(SONG.song);
		detailsPausedText = "Paused - " + songDetails;
		detailsSub = "";

		updateRPC(false);

		curSong = songData.song;
		songMusic = new FlxSound().load(Paths.inst(SONG.song));
		songMusic.autoDestroy = false;
		songMusic.onComplete = endSong;

		if (SONG.needsVoices)
		{
			vocals = new FlxSound().load(Paths.voices(SONG.song));
			vocals.autoDestroy = false;
		}
		else
		{
			vocals = new FlxSound();
			vocals.autoDestroy = false;
		}

		FlxG.sound.list.add(songMusic);
		FlxG.sound.list.add(vocals);

		generateChart();
	}

	public function generateChart():Void
	{
		unspawnNotes = [];
		eventNotes = [];
		unspawnNotesIndex = 0;

		if (SONG.events != null)
		{
			for (e in SONG.events)
			{
				if (e != null && e.length >= 2)
				{
					var strumTime:Float = e[0];
					var eventList:Array<Dynamic> = e[1];
					if (eventList != null)
					{
						for (ev in eventList)
						{
							if (ev != null)
							{
								eventNotes.push([strumTime, ev[0], ev[1], ev[2]]);
								if (ev[0] == 'Change Character' || ev[0] == 'changeChar')
								{
									var targetChar:String = ev[2];
									if (targetChar == null || targetChar.trim() == '')
									{
										var spl = Std.string(ev[1]).split(',');
										if (spl.length > 1) targetChar = spl[1];
										else targetChar = spl[0];
									}
									if (targetChar != null && targetChar.trim() != '')
										precacheCharacter(targetChar.trim());
								}
							}
						}
					}
				}
			}
			eventNotes.sort(function(a:Dynamic, b:Dynamic):Int
			{
				var v1:Float = a[0];
				var v2:Float = b[0];
				if (v1 < v2) return -1;
				if (v1 > v2) return 1;
				return 0;
			});
		}

		var offset:Float = 0;
		#if !neko
		if (Init.trueSettings.exists('Offset'))
			offset = Init.trueSettings.get('Offset');
		#end

		var noteData = SONG.notes;
		for (section in noteData)
		{
			if (section == null || section.sectionNotes == null) continue;

			if (section.changeBPM)
			{
				Conductor.changeBPM(section.bpm);
			}

			for (songNotes in section.sectionNotes)
			{
				if (songNotes == null || songNotes.length < 2) continue;

				var rawStrumTime:Float = songNotes[0];
				var daStrumTime:Float = rawStrumTime - offset;

				var rawNoteData:Int = Std.int(songNotes[1]);
				var daNoteData:Int = rawNoteData % numberOfKeys;

				var playfield:Int = Std.int(rawNoteData / numberOfKeys);
				if (playfield < 0 || playfield >= 2) continue;

				var daNoteAlt:Float = 0;
				if (songNotes.length > 3 && songNotes[3] != null) daNoteAlt = songNotes[3];

				var gottaHitNote:Bool = (playfield == 1);

				// Anti-stack check
				var isStacked = false;
				var checkAmount = Std.int(Math.min(unspawnNotes.length, 15));
				for (i in 0...checkAmount)
				{
					var checkNote = unspawnNotes[unspawnNotes.length - 1 - i];
					if (checkNote == null || checkNote.isSustainNote) continue;
					if (Math.abs(checkNote.strumTime - daStrumTime) < 2 && checkNote.noteData == daNoteData && checkNote.playfield == playfield)
					{
						isStacked = true;
						break;
					}
				}
				if (isStacked) continue;

				var oldNote:Note = unspawnNotes.length > 0 ? unspawnNotes[unspawnNotes.length - 1] : null;

				var swagNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, daStrumTime, daNoteData, 0, daNoteAlt);
				swagNote.noteSpeed = SONG.speed;
				swagNote.mustPress = gottaHitNote;
				swagNote.playfield = playfield;
				swagNote.scrollFactor.set(0, 0);

				var susLength:Float = 0;
				if (songNotes.length > 2 && songNotes[2] != null)
					susLength = songNotes[2];

				swagNote.sustainLength = susLength;
				unspawnNotes.push(swagNote);

				var stepSusLength:Int = Math.round(susLength / Conductor.stepCrochet);

				if (stepSusLength > 0)
				{
					for (susNote in 0...stepSusLength)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];

						var sustainTime:Float = daStrumTime + (Conductor.stepCrochet * susNote);
						var sustainNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, sustainTime, daNoteData, 0, daNoteAlt, true, oldNote);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.playfield = playfield;
						sustainNote.scrollFactor.set(0, 0);
						sustainNote.sustainLength = Conductor.stepCrochet;
						sustainNote.isSustainEnd = (susNote == stepSusLength - 1);
						sustainNote.parentNote = swagNote;

						unspawnNotes.push(sustainNote);
					}
				}
			}
		}

		Conductor.changeBPM(SONG.bpm);
		unspawnNotes.sort(sortByShit);
		generatedMusic = true;
	}

	private function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	private function noteCalls():Void
	{
		for (strumline in strumLines)
		{
			for (uiNote in strumline.receptors)
			{
				if (strumline.autoplay)
					strumCallsAuto(uiNote);
			}
		}

		if (generatedMusic && startedCountdown)
		{
			var isDownscroll = Init.trueSettings.get('Downscroll');
			var isGhostTapping = Init.trueSettings.get('Ghost Tapping') ? true : false;

			for (strumline in strumLines)
			{
				var downscrollMultiplier = isDownscroll ? -1 : 1;

				for (daNote in strumline.allNotes.members)
				{
					var currentReceptor = strumline.receptors.members[Math.floor(daNote.noteData)];
					var receptorPosY:Float = (currentReceptor != null ? currentReceptor.y : 50) + Note.swagWidth / 6;

					if (modManager != null)
					{
						var pID:Int = daNote.lane;
						var speed = daNote.noteSpeed * daNote.multSpeed;
						var visPos = modManager.getVisPos(Conductor.songPosition, daNote.strumTime, speed);
						var diff = (daNote.strumTime - Conductor.songPosition);

						var pos = modManager.getPos(daNote.strumTime, visPos, diff, curDecBeat, daNote.noteData, pID, daNote, _modchartVector);
						modManager.updateObject(curDecBeat, daNote, pos, pID);

						daNote.alpha = (daNote.isSustainNote ? (Init.trueSettings.get('Alpha Holds') ? 1 : 0.6) : 1) * daNote.alphaMod;

						if (daNote.isSustainNote)
						{
							daNote.flipY = false;

							var futureSongPos = Conductor.songPosition + daNote.sustainLength;
							var futureBeat = futureSongPos / (Conductor.stepCrochet * 4);
							var nextVisPos = modManager.getVisPos(Conductor.songPosition, daNote.strumTime + daNote.sustainLength, speed);
							var nextDiff = (daNote.strumTime + daNote.sustainLength - Conductor.songPosition);
							var nextPos = modManager.getPos(daNote.strumTime + daNote.sustainLength, nextVisPos, nextDiff, futureBeat, daNote.noteData, pID, daNote);

							var rad = Math.atan2(nextPos.y - pos.y, nextPos.x - pos.x);
							var deg = (rad * 180 / Math.PI);
							daNote.angle = (deg - 90);

							if (!daNote.isSustainEnd)
							{
								var dist:Float = Math.sqrt(Math.pow(pos.y - nextPos.y, 2) + Math.pow(pos.x - nextPos.x, 2));
								daNote.scale.y = daNote.baseScale.y = (dist / (daNote.frameHeight - (daNote.antialiasing ? 1 : 0)));
							}

							if (currentReceptor != null && (daNote.wasGoodHit || (daNote.prevNote != null && daNote.prevNote.wasGoodHit)) && Conductor.songPosition >= daNote.strumTime)
							{
								var clipX:Float = (daNote.x - currentReceptor.x - (currentReceptor.width - daNote.width) * 0.5);
								var clipY:Float = (daNote.y - currentReceptor.y - currentReceptor.height * 0.5);
								var mag:Float = Math.sqrt(clipX * clipX + clipY * clipY);

								var swagRect = daNote.clipRect;
								if (swagRect == null) swagRect = new flixel.math.FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
								swagRect.x = 0;
								swagRect.width = daNote.frameWidth;
								swagRect.y = (mag / daNote.scale.y);
								swagRect.height = Math.max(0, daNote.frameHeight - swagRect.y);
								daNote.clipRect = swagRect;
							}
							else
							{
								daNote.clipRect = null;
							}

							nextPos.put();
						}
					}
					else
					{
						var roundedSpeed = FlxMath.roundDecimal(daNote.noteSpeed, 2);
						var psuedoY:Float = (downscrollMultiplier * -((Conductor.songPosition - daNote.strumTime) * (0.45 * roundedSpeed)));
						var psuedoX = 25 + daNote.noteVisualOffset;

						var radians = flixel.math.FlxAngle.asRadians(daNote.noteDirection);
						var cosDir = Math.cos(radians);
						var sinDir = Math.sin(radians);

						daNote.y = receptorPosY + (cosDir * psuedoY) + (sinDir * psuedoX);
						daNote.x = (currentReceptor != null ? currentReceptor.x : 0) + (cosDir * psuedoX) + (sinDir * psuedoY);

						if (!daNote.isSustainNote)
							daNote.angle = -daNote.noteDirection;

						var center:Float = receptorPosY + Note.swagWidth / 2;
						if (daNote.isSustainNote)
						{
							daNote.y -= ((daNote.height / 2) * downscrollMultiplier);
							if ((daNote.animation.curAnim.name.endsWith('holdend')) && (daNote.prevNote != null && daNote.prevNote.active))
							{
								if (daNote.prevNote.isSustainNote)
								{
									if (isDownscroll)
										daNote.y = daNote.prevNote.y - daNote.height;
									else
										daNote.y = daNote.prevNote.y + daNote.prevNote.height;
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
					}

					mainControls(daNote, strumline.character, strumline, strumline.autoplay);

					if (modManager == null)
					{
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
					}
					else
					{
						daNote.visible = true;
						daNote.active = true;
					}

					// Late note checking
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
											if (note.tooLate && !note.wasGoodHit)
												breakFromLate = true;
										}
										if (!breakFromLate)
										{
											missNoteCheck((Init.trueSettings.get('Ghost Tapping')) ? true : false, daNote.noteData, boyfriend, true);
											for (note in parentNote.childrenNotes)
												note.tooLate = true;
										}
									}
								}
							}
						}
					}

					// Destroy notes that went off-screen
					if ((((!isDownscroll) && (daNote.y < -daNote.height))
						|| ((isDownscroll) && (daNote.y > (FlxG.height + daNote.height))))
						&& (daNote.tooLate || daNote.wasGoodHit))
						destroyNote(strumline, daNote);
				}

				strumCameraRoll(strumline.receptors, (strumline == boyfriendStrums));
			}
		}

		// Reset boyfriend idle animation
		var holdControls:Array<Bool> = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		if ((boyfriend != null && boyfriend.animation != null)
			&& (boyfriend.holdTimer > Conductor.stepCrochet * (boyfriend.singDuration * 0.001) && (!holdControls.contains(true) || boyfriendStrums.autoplay)))
		{
			if (boyfriend.getAnimName().startsWith('sing') && !boyfriend.getAnimName().endsWith('miss'))
				boyfriend.dance();
		}
	}

	private function mainControls(daNote:Note, char:Character, strumline:Strumline, autoplay:Bool):Void
	{
		var notesPressedAutoplay = [];

		if (autoplay)
		{
			if (daNote.strumTime <= Conductor.songPosition)
			{
				var canDisplayJudgement = false;
				if (strumline.displayJudgements)
				{
					canDisplayJudgement = true;
					for (noteDouble in notesPressedAutoplay)
					{
						if (noteDouble.noteData == daNote.noteData)
							canDisplayJudgement = false;
					}
					notesPressedAutoplay.push(daNote);
				}
				goodNoteHit(daNote, char, strumline, canDisplayJudgement);
			}
		}

		var holdControls:Array<Bool> = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		if (!autoplay)
		{
			if (holdControls.contains(true))
			{
				for (coolNote in strumline.allNotes.members)
				{
					if (coolNote != null && coolNote.alive)
					{
						if ((coolNote.parentNote != null && coolNote.parentNote.wasGoodHit)
							&& coolNote.canBeHit
							&& coolNote.mustPress
							&& !coolNote.tooLate
							&& coolNote.isSustainNote
							&& holdControls[coolNote.noteData])
							goodNoteHit(coolNote, char, strumline);
					}
				}
			}
		}
	}

	private function strumCallsAuto(cStrum:UIStaticArrow, ?callType:Int = 1, ?daNote:Note):Void
	{
		switch (callType)
		{
			case 1:
				if ((cStrum.animation.finished) && (cStrum.canFinishAnimation))
					cStrum.playAnim('static');
			default:
				if (daNote.noteData == cStrum.ID)
				{
					cStrum.playAnim('confirm');
					if ((daNote.isSustainNote) && (!daNote.animation.curAnim.name.endsWith('holdend')))
						cStrum.canFinishAnimation = false;
					else
						cStrum.canFinishAnimation = true;
				}
		}
	}

	private function destroyNote(strumline:Strumline, daNote:Note):Void
	{
		daNote.active = false;
		daNote.exists = false;

		var chosenGroup = (daNote.isSustainNote ? strumline.holdsGroup : strumline.notesGroup);
		daNote.kill();
		if (strumline.allNotes.members.contains(daNote))
			strumline.allNotes.remove(daNote, true);
		if (chosenGroup.members.contains(daNote))
			chosenGroup.remove(daNote, true);
		daNote.destroy();
	}

	public function updateAllNotesSpeed():Void
	{
		for (strum in strumLines.members)
		{
			for (note in strum.allNotes.members)
			{
				if (note != null && note.alive)
				{
					note.noteSpeed = PlayState.SONG.speed;
				}
			}
		}
		for (note in unspawnNotes)
		{
			if (note != null) note.noteSpeed = PlayState.SONG.speed;
		}
	}

	// =========================================================================
	// SECTION 9: JUDGEMENTS, SCORING & COMBOS
	// =========================================================================

	private function goodNoteHit(coolNote:Note, character:Character, characterStrums:Strumline, ?canDisplayJudgement:Bool = true):Void
	{
		if (!coolNote.wasGoodHit)
		{
			coolNote.wasGoodHit = true;
			vocals.volume = 1;

			characterPlayAnimation(coolNote, character);
			if (characterStrums.receptors.members[coolNote.noteData] != null)
			{
				characterStrums.receptors.members[coolNote.noteData].playAnim('confirm', true);
			}

			if (canDisplayJudgement)
			{
				var noteDiff:Float = Math.abs(coolNote.strumTime - Conductor.songPosition);
				var ratingTiming:String = (coolNote.strumTime < Conductor.songPosition) ? "late" : "early";

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

	private function missNoteCheck(?includeAnimation:Bool = false, direction:Int = 0, character:Character, popMiss:Bool = false, lockMiss:Bool = false):Void
	{
		if (includeAnimation)
		{
			var stringDirection:String = UIStaticArrow.getArrowFromNumber(direction);
			FlxG.sound.play(Paths.soundRandom('system/miss/missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			character.playAnim('sing' + stringDirection.toUpperCase() + 'miss', lockMiss);
		}
		decreaseCombo(popMiss);
	}

	private function characterPlayAnimation(coolNote:Note, character:Character):Void
	{
		var stringArrow:String = '';
		var altString:String = '';

		var baseString = 'sing' + UIStaticArrow.getArrowFromNumber(coolNote.noteData).toUpperCase();

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
		character.playAnim(stringArrow, true);
		character.holdTimer = 0;
	}

	private function popUpScore(baseRating:String, timing:String, strumline:Strumline, coolNote:Note):Void
	{
		var score:Int = 50;

		if (baseRating == "sick")
			createSplash(coolNote, strumline);

		displayRating(baseRating, timing);
		Timings.updateAccuracy(Timings.judgementsMap.get(baseRating)[3]);
		score = Std.int(Timings.judgementsMap.get(baseRating)[2]);

		songScore += score;
		popUpCombo();
	}

	public function createSplash(coolNote:Note, strumline:Strumline):Void
	{
		if (strumline.splashNotes != null)
			strumline.createSplash(coolNote);
	}

	private function popUpCombo(?cache:Bool = false):Void
	{
		if (grpCombos == null) return;

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

	private function decreaseCombo(?popMiss:Bool = false):Void
	{
		if (((combo > 5) || (combo < 0)) && (gf.animOffsets.exists('sad')))
			gf.playAnim('sad');

		if (combo > 0)
			combo = 0;
		else
			combo--;

		songScore -= 10;
		misses++;

		if (popMiss)
		{
			Timings.gottenJudgements.set("miss", Timings.gottenJudgements.get("miss") + 1);
			healthCall(Timings.judgementsMap.get("miss")[3]);
		}
		popUpCombo();
		Timings.updateFCDisplay();
	}

	private function increaseCombo(?baseRating:String, ?direction = 0, ?character:Character):Void
	{
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

	public function displayRating(daRating:String, timing:String, ?cache:Bool = false):Void
	{
		if (grpRatings == null) return;

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

		if (assetModifier == 'pixel')
		{
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

	private function healthCall(?ratingMultiplier:Float = 0):Void
	{
		var healthBase:Float = 0.06;
		health += (healthBase * (ratingMultiplier / 100));
	}

	// =========================================================================
	// SECTION 10: SCRIPTING & SONG EVENTS
	// =========================================================================

	public function initScripts():Void
	{
		#if sys
		var songName = SONG.song.toLowerCase();
		var songScriptPath = Paths.getPath('songs/$songName/script.hx', TEXT);
		if (sys.FileSystem.exists(songScriptPath))
		{
			hscriptArray.push(new HScriptHandler(songScriptPath));
		}
		#end
	}

	public function callOnScripts(funcName:String, ?args:Array<Dynamic>):Void
	{
		for (script in hscriptArray)
		{
			if (script.active) script.call(funcName, args);
		}
		#if sys
		if (stageBuild != null && funcName != 'onUpdate' && funcName != 'update' && funcName != 'onStepHit' && funcName != 'stepHit' && funcName != 'onBeatHit' && funcName != 'beatHit')
		{
			stageBuild.callScript(funcName, args != null ? args : []);
		}
		#end
	}

	public function triggerEvent(eventName:String, value1:String, value2:String):Void
	{
		switch (eventName)
		{
			case 'changeScroll' | 'Change Scroll Speed':
				if (scrollTween != null)
				{
					scrollTween.cancel();
					scrollTween = null;
				}
				if (scrollTimer != null)
				{
					scrollTimer.cancel();
					scrollTimer = null;
				}

				var rawVal1:String = (value1 != null) ? value1.trim() : "";
				var val1:Float = Std.parseFloat(rawVal1);

				var shouldReset:Bool = (rawVal1 == "" || rawVal1 == "1" || rawVal1.toLowerCase() == "default" || rawVal1.toLowerCase() == "reset" || Math.isNaN(val1) || val1 <= 0);

				var targetSpeed:Float = defaultSongSpeed;
				if (!shouldReset)
				{
					if (val1 <= 2.0 && defaultSongSpeed > 2.0)
						targetSpeed = defaultSongSpeed * val1;
					else
						targetSpeed = val1;
				}

				var timeSteps:Float = Std.parseFloat(value2);
				if (Math.isNaN(timeSteps)) timeSteps = 0;

				if (timeSteps <= 0)
				{
					PlayState.SONG.speed = targetSpeed;
					updateAllNotesSpeed();
				}
				else
				{
					var durationSec:Float = (timeSteps * Conductor.stepCrochet) / 1000;
					scrollTween = flixel.tweens.FlxTween.num(PlayState.SONG.speed, targetSpeed, durationSec, {ease: flixel.tweens.FlxEase.linear}, function(v:Float)
					{
						PlayState.SONG.speed = v;
						updateAllNotesSpeed();
					});
				}

			case 'changeChar' | 'Change Character':
				var charType:String = value1.toLowerCase().trim();
				var newChar:String = value2.trim();

				if (newChar == null || newChar == '')
				{
					var args = value1.split(',');
					if (args.length > 1)
					{
						charType = args[0].trim().toLowerCase();
						newChar = args[1].trim();
					}
					else
					{
						newChar = args[0].trim();
					}
				}

				var targetIndex:Int = 1;
				if (charType == '0' || charType == 'bf' || charType == 'boyfriend' || charType == 'player')
					targetIndex = 0;
				else if (charType == '2' || charType == 'gf' || charType == 'girlfriend')
					targetIndex = 2;

				changeCharacter(targetIndex, newChar);
		}
	}

	public function changeCharacter(type:Int, newCharacter:String):Void
	{
		if (newCharacter == null || newCharacter.trim() == '') return;
		newCharacter = newCharacter.trim();

		switch (type)
		{
			case 0: // Boyfriend
				if (boyfriend.curCharacter == newCharacter) return;
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[0] : 770;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[1] : 100;
				boyfriend.setCharacter(baseX, baseY, newCharacter);
				boyfriend.dance();
				if (iconP1 != null)
					iconP1.changeIcon(boyfriend.healthIcon);
				var bfColor = FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]);
				updateColors(bfColor, currentColorP2);

			case 1: // Dad / Opponent
				if (dadOpponent.curCharacter == newCharacter) return;
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[0] : 100;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[1] : 100;
				dadOpponent.setCharacter(baseX, baseY, newCharacter);
				dadOpponent.dance();
				if (iconP2 != null)
					iconP2.changeIcon(dadOpponent.healthIcon);
				var dadColor = FlxColor.fromRGB(dadOpponent.healthColorArray[0], dadOpponent.healthColorArray[1], dadOpponent.healthColorArray[2]);
				updateColors(currentColorP1, dadColor);

			case 2: // GF
				if (gf.curCharacter == newCharacter) return;
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[0] : 400;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[1] : 130;
				gf.setCharacter(baseX, baseY, newCharacter);
				gf.dance();
		}
	}

	public static function precacheCharacter(charName:String):Void
	{
		if (charName == null || charName.trim() == '') return;
		charName = charName.trim();
		var jsonPath = Paths.getPath('data/char/' + charName + '.json', TEXT);
		#if sys
		if (sys.FileSystem.exists(jsonPath))
		{
			try
			{
				var rawJson = sys.io.File.getContent(jsonPath);
				var json:funkin.objects.Character.CharacterFile = haxe.Json.parse(rawJson);
				if (json != null && json.image != null)
				{
					Paths.returnGraphic(json.image, null, true);
				}
				if (json != null && json.healthicon != null)
				{
					Paths.image('icons/icon-' + json.healthicon);
				}
			}
			catch (e:Dynamic)
			{
				trace('Could not precache character: ' + charName + ' - ' + e);
			}
		}
		#end
	}

	// =========================================================================
	// SECTION 11: SONG FLOW & SUBSTATES
	// =========================================================================

	private function startCountdown():Void
	{
		inCutscene = false;
		startedCountdown = true;
		charactersDance(curBeat);
		Conductor.songPosition = -(Conductor.crochet * 1);
		swagCounter = 0;
	}

	private function startSong():Void
	{
		startingSong = false;
		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (!paused)
		{
			if (songMusic != null && songMusic.exists)
				songMusic.play(true);

			if (vocals != null && vocals.exists)
				vocals.play(true);

			resyncVocals();

			#if desktop
			if (songMusic != null && songMusic.exists)
				songLength = songMusic.length;

			updateRPC(false);
			#end
		}
	}

	public function pauseGame():Void
	{
		updateRPC(true);
		paused = true;

		persistentUpdate = false;
		persistentDraw = true;

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

		openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
	}

	override function openSubState(SubState:FlxSubState):Void
	{
		if (paused && (SubState is PauseSubState))
		{
			if (songMusic != null)
			{
				songMusic.pause();
				if (vocals != null)
					vocals.pause();
			}
			camGame.active = false;
			camHUD.active = false;
			camAlt.active = false;
			timerManager.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState():Void
	{
		if (paused)
		{
			if (songMusic != null && !startingSong)
			{
				songMusic.play();
				if (vocals != null && vocals.exists)
				{
					vocals.time = songMusic.time;
					vocals.play();
				}
				Conductor.songPosition = songMusic.time;
			}

			previousFrameTime = FlxG.game.ticks;

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
			camAlt.active = true;
		}

		super.closeSubState();
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

	public function restartSong():Void
	{
		paused = false;

		// 1. Cancel ongoing scroll tweens and timers
		if (scrollTween != null)
		{
			scrollTween.cancel();
			scrollTween = null;
		}
		if (scrollTimer != null)
		{
			scrollTimer.cancel();
			scrollTimer = null;
		}

		// Clear active global managers
		FlxTween.globalManager.clear();
		FlxTimer.globalManager.clear();

		// Stop camera effects and reset active/visibility
		camGame.stopFX();
		camHUD.stopFX();
		camAlt.stopFX();

		camGame.active = true;
		camGame.visible = true;
		camHUD.active = true;
		camHUD.visible = true;
		camAlt.active = true;
		camAlt.visible = true;

		timerManager.active = true;

		// 2. Restore song speed to JSON default
		if (SONG != null)
		{
			if (SONG.defaultSpeed != null)
				SONG.speed = SONG.defaultSpeed;
			else
				SONG.speed = defaultSongSpeed;
		}

		// 3. Audio reset
		if (songMusic != null && songMusic.exists)
		{
			songMusic.pause();
			songMusic.time = 0;
		}
		else
		{
			songMusic = new FlxSound().load(Paths.inst(SONG.song));
			songMusic.autoDestroy = false;
			songMusic.onComplete = endSong;
			FlxG.sound.list.add(songMusic);
		}

		if (vocals != null && vocals.exists)
		{
			vocals.pause();
			vocals.time = 0;
		}
		else if (SONG.needsVoices)
		{
			vocals = new FlxSound().load(Paths.voices(SONG.song));
			vocals.autoDestroy = false;
			FlxG.sound.list.add(vocals);
		}

		// 4. Reset Conductor & Timing variables
		Conductor.changeBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);
		Conductor.songPosition = -(Conductor.crochet * 1);
		Conductor.lastSongPos = Conductor.songPosition;
		songTime = 0;
		previousFrameTime = FlxG.game.ticks;

		// 5. Reset statistics
		songScore = 0;
		combo = 0;
		health = 1;
		misses = 0;
		curStep = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
		curBeat = Math.floor(curStep / 4);
		focus = DAD;
		lockCamPos = false;
		lockFocus = false;
		Timings.callAccuracy();

		if (grpRatings != null) grpRatings.clear();
		if (grpCombos != null) grpCombos.clear();

		// 6. Reset cameras
		if (stageBuild != null && stageBuild.stageData != null)
			defaultCamZoom = stageBuild.stageData.zoom;
		else
			defaultCamZoom = 1.05;

		camGame.zoom = defaultCamZoom;
		camHUD.zoom = 1;
		camAlt.zoom = 1;
		forceZoom = [0, 0, 0, 0];

		if (camFollow != null && camPos != null)
			camFollow.setPosition(camPos.x, camPos.y);
		if (camFollowPos != null && camPos != null)
			camFollowPos.setPosition(camPos.x, camPos.y);

		FlxG.camera.focusOn(camFollow.getPosition());

		// 7. Reset characters
		if (boyfriend != null) boyfriend.shader = null;
		if (dadOpponent != null) dadOpponent.shader = null;
		if (gf != null) gf.shader = null;

		if (dadOpponent != null && dadOpponent.curCharacter != SONG.player2)
			changeCharacter(1, SONG.player2);
		if (boyfriend != null && boyfriend.curCharacter != SONG.player1)
			changeCharacter(0, SONG.player1);

		if (stageBuild != null)
		{
			stageBuild.dadPosition(curStage, boyfriend, dadOpponent, gf, camPos);
			stageBuild.repositionPlayers(curStage, boyfriend, dadOpponent, gf);
		}
		if (boyfriend != null) boyfriend.dance();
		if (dadOpponent != null) dadOpponent.dance();
		if (gf != null) gf.dance();

		// 8. Reset UI HUD
		displayedScore = 0;
		if (healthBar != null)
		{
			healthBar.value = health;
			healthBar.updateBar();
		}
		updateScoreText();
		if (boyfriend != null && iconP1 != null) iconP1.changeIcon(boyfriend.healthIcon);
		if (dadOpponent != null && iconP2 != null) iconP2.changeIcon(dadOpponent.healthIcon);
		var bfColor = (boyfriend != null) ? FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]) : FlxColor.WHITE;
		var dadColor = (dadOpponent != null) ? FlxColor.fromRGB(dadOpponent.healthColorArray[0], dadOpponent.healthColorArray[1], dadOpponent.healthColorArray[2]) : FlxColor.WHITE;
		updateColors(bfColor, dadColor);

		// 9. Reset strumlines
		if (strumLines != null)
		{
			for (strum in strumLines)
			{
				strum.resetStrumline(false);
			}
		}

		// 10. Re-generate notes & events
		generateChart();
		updateAllNotesSpeed();

		// 11. Script callbacks
		if (stageBuild != null)
		{
			stageBuild.callScript('onRestart', []);
			stageBuild.callScript('restart', []);
		}
		callOnScripts('onRestart');
		callOnScripts('onSongRetry');

		// 12. Countdown
		canPause = true;
		startingSong = true;
		startedCountdown = true;
		inCutscene = false;
		startCountdown();
	}

	private function endSong():Void
	{
		canPause = false;
		Utils.killMusic([songMusic, vocals]);
		if (SONG.validScore)
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);

		deaths = 0;
		Utils.resetMenuMusic();

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		Main.switchState(this, new MainMenuState());
		if (SONG.validScore)
			Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);

		FlxG.save.flush();
	}

	private function callDefaultSongEnd():Void
	{
		var difficulty:String = '-' + CoolUtil.difficultyFromNumber(storyDifficulty).toLowerCase();
		difficulty = difficulty.replace('-normal', '');

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + difficulty, PlayState.storyPlaylist[0]);
		Utils.killMusic([songMusic, vocals]);

		FlxG.switchState(() -> new PlayState());
	}

	public static function resetMusic():Void
	{
		if (songMusic != null)
			songMusic.stop();

		if (vocals != null)
			vocals.stop();
	}

	public static function updateRPC(pausedRPC:Bool):Void
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

	// =========================================================================
	// SECTION 12: OVERRIDES & UTILITIES
	// =========================================================================

	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}
}

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
import funkin.play.Countdown;
import funkin.play.Countdown.CountdownStep;

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
	GF;
	CENTER;
	CUSTOM;
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
	public static var opponentVocals:FlxSound;
	public static var playerVocals(get, set):FlxSound;
	static function get_playerVocals():FlxSound return vocals;
	static function set_playerVocals(val:FlxSound):FlxSound return vocals = val;

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

	// Cameras (camGame2, camGame, camHUD, camAlt)
	public static var camGame2:FlxCamera;
	public static var camGame:FlxCamera;
	public static var camHUD:FlxCamera;
	public static var camAlt:FlxCamera;

	// Camera state & Modern Settings
	public static var defaultCamZoom:Float = 1.05;
	public static var forceZoom:Array<Float>;
	public static var focus:Focus = DAD;
	public static var lockCamPos:Bool = false;
	public static var lockFocus:Bool = false;
	public static var cameraSpeed:Float = 1.0;
	public static var camZooming:Bool = true;
	public static var camZoomingMult:Float = 1.0;
	public static var camZoomingFrequency:Int = 4;

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
	public static var _nextModchartVector:Vector3 = Vector3.get();

	// =========================================================================
	// SECTION 2: INSTANCE VARIABLES
	// =========================================================================

	// Stage & Scripts
	public var stageBuild:Stage;
	public var hscriptArray:Array<HScriptHandler> = [];

	// Modchart Manager
	public var modManager:ModManager;

	// Camera Tracking, Offsets & Control
	public var camFollow:FlxObject;
	public var camFollowPos:FlxObject;
	public var camPos:FlxPoint;
	public var camDisplaceX:Float = 0;
	public var camDisplaceY:Float = 0;
	public var targetCamDisplaceX:Float = 0;
	public var targetCamDisplaceY:Float = 0;
	public var camDisplaceExtend:Float = 12;
	public var camDisplaceSpeed:Float = 10.0;
	public var camZoomSpeed:Float = 1.0;
	public var camNoteDisplaceEnabled:Bool = true;
	public var camGameZoomBump:Float = 0.015;
	public var camHUDZoomBump:Float = 0.03;

	// Modder-friendly Camera Offsets
	public var bfCamOffset:FlxPoint = FlxPoint.get(0, 0);
	public var dadCamOffset:FlxPoint = FlxPoint.get(0, 0);
	public var gfCamOffset:FlxPoint = FlxPoint.get(0, 0);
	public var camFollowOffset:FlxPoint = FlxPoint.get(0, 0);
	public var customCamPos:FlxPoint = null;

	// Modder-friendly HUD Customization Variables
	public var showHealthBar:Bool = true;
	public var healthBarPosition:FlxPoint = FlxPoint.get(0, 0);
	public var healthBarOffset:FlxPoint = FlxPoint.get(0, 0);
	public var healthBarScale:FlxPoint = FlxPoint.get(1, 1);
	public var healthBarAlpha:Float = 1.0;
	public var healthBarLerpSpeed:Float = 15.0;
	public var healthBarWidth:Int = 0;
	public var healthBarHeight:Int = 0;
	public var healthBarInnerOffset:FlxPoint = FlxPoint.get(4, 4);

	public var showIcons:Bool = true;
	public var iconOffset:Float = 26.0;
	public var iconBopScale:Float = 1.2;
	public var iconLerpSpeed:Float = 9.0;
	public var iconP1Offset:FlxPoint = FlxPoint.get(0, 0);
	public var iconP2Offset:FlxPoint = FlxPoint.get(0, 0);

	public var showScoreBar:Bool = true;
	public var scoreBarFont:String = 'vcr.ttf';
	public var scoreBarSize:Int = 18;
	public var scoreBarColor:FlxColor = FlxColor.WHITE;
	public var scoreBarBorderColor:FlxColor = FlxColor.BLACK;
	public var scoreBarBorderSize:Float = 1.5;
	public var scoreBarOffset:FlxPoint = FlxPoint.get(0, 0);
	public var scoreLerpSpeed:Float = 15.0;
	public var scoreTemplate:String = "Score: {score} • Combo Breaks: {comboBreaks} • Accuracy: {accuracy} • {comboDisplay}";
	public var customScoreText:String = null;

	public var showRating:Bool = true;
	public var showCombo:Bool = true;
	public var ratingOffset:FlxPoint = FlxPoint.get(0, 0);
	public var comboOffset:FlxPoint = FlxPoint.get(0, 0);
	public var ratingScale:Float = 0.5;
	public var comboScale:Float = 0.3;
	public var ratingAlpha:Float = 1.0;
	public var comboAlpha:Float = 1.0;
	public var ratingCamera:FlxCamera = null;
	public var comboCamera:FlxCamera = null;

	public var showCenterMark:Bool = true;
	public var centerMarkOffset:FlxPoint = FlxPoint.get(0, 0);
	public var showBotplayMark:Bool = true;
	public var botplayMarkOffset:FlxPoint = FlxPoint.get(0, 0);

	public var hudAlpha(get, set):Float;
	inline function get_hudAlpha():Float return (camHUD != null) ? camHUD.alpha : 1.0;
	inline function set_hudAlpha(val:Float):Float {
		if (camHUD != null) camHUD.alpha = val;
		return val;
	}

	public var hudVisible(get, set):Bool;
	inline function get_hudVisible():Bool return (camHUD != null) ? camHUD.visible : true;
	inline function set_hudVisible(val:Bool):Bool {
		if (camHUD != null) camHUD.visible = val;
		return val;
	}

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
	public var startingSong:Bool = false;
	public var startedCountdown:Bool = false;
	public var isInCountdown:Bool = false;
	public var inCutscene:Bool = false;
	public var canPause:Bool = true;
	private var curSong:String = "";
	private var gfSpeed:Int = 1;
	private var previousFrameTime:Int = 0;
	private var lastReportedPlayheadPosition:Int = 0;
	private var songTime:Float = 0;
	private var lastSection:Int = 0;

	// Input handling
	private var keysArray:Array<Dynamic>;
	private var keysPressed:Map<Int, Bool> = new Map<Int, Bool>();

	// Cached Settings (Avoids hash lookups on every frame/note)
	public var downscroll:Bool = false;
	public var ghostTapping:Bool = false;
	public var alphaHolds:Bool = true;
	public var controllerMode:Bool = false;
	public var disableNoteSplashes:Bool = false;
	public var reducedMovements:Bool = false;
	public var noCameraNoteMovement:Bool = false;
	public var centeredNotefield:Bool = false;
	public var autoPause:Bool = true;

	// Cached allocations & timers
	private var rpcTimer:Float = 0;
	private var lastRenderedScore:Int = -1;
	private var defaultHudCamArray:Array<FlxCamera> = [];
	private var comboFormatsMap:Map<Int, flixel.text.FlxText.FlxTextFormat> = new Map();

	// Event Tweens & Timers
	private var scrollTween:FlxTween;
	private var scrollTimer:FlxTimer;
	private var camPosTween:FlxTween;

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
		cameraSpeed = 1.0;
		camZooming = true;
		camZoomingMult = 1.0;
		camZoomingFrequency = 4;

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

		// Setup cameras: camGame2 (behind camGame), camGame, camHUD, and camAlt
		camGame2 = new FlxCamera();
		camGame2.bgColor = FlxColor.TRANSPARENT;

		camGame = new FlxCamera();
		camGame.bgColor = FlxColor.TRANSPARENT;

		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;

		camAlt = new FlxCamera();
		camAlt.bgColor = FlxColor.TRANSPARENT;

		FlxG.cameras.reset(camGame2);
		FlxG.cameras.add(camGame, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camAlt, false);
		FlxG.cameras.setDefaultDrawTarget(camGame2, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		FlxG.camera = camGame;

		// Groups for judgements and combo counters (placed on camHUD)
		grpRatings = new FlxTypedGroup<FlxSprite>();
		grpRatings.cameras = [camHUD];
		add(grpRatings);

		grpCombos = new FlxTypedGroup<FlxSprite>();
		grpCombos.cameras = [camHUD];
		add(grpCombos);

		// Cache engine settings & pre-allocate structures
		defaultHudCamArray = [camHUD];
		downscroll = Init.trueSettings.get('Downscroll');
		ghostTapping = Init.trueSettings.get('Ghost Tapping') ? true : false;
		alphaHolds = Init.trueSettings.get('Alpha Holds');
		controllerMode = Init.trueSettings.get('Controller Mode');
		disableNoteSplashes = Init.trueSettings.get('Disable Note Splashes');
		reducedMovements = Init.trueSettings.get('Reduced Movements');
		noCameraNoteMovement = Init.trueSettings.get('No Camera Note Movement');
		centeredNotefield = Init.trueSettings.get('Centered Notefield');
		autoPause = Init.trueSettings.get('Auto Pause');

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
			stageBuild.interp.variables.set("camGame2", camGame2);
			stageBuild.interp.variables.set("camGame", camGame);
			stageBuild.interp.variables.set("camHUD", camHUD);
			stageBuild.interp.variables.set("camAlt", camAlt);
		}
		#end

		dadOpponent.dance();
		gf.dance();
		boyfriend.dance();

		Conductor.songPosition = -(Conductor.crochet * 5);

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

		camGame.follow(camFollowPos, LOCKON);
		camGame.zoom = defaultCamZoom;
		camGame.focusOn(camFollow.getPosition());

		if (camGame2 != null)
		{
			camGame2.follow(camFollowPos, LOCKON);
			camGame2.zoom = defaultCamZoom;
			camGame2.focusOn(camFollow.getPosition());
		}
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

		dadStrums = new Strumline(placement - valThing, this, dadOpponent, false, true, false, 4, downscroll);
		dadStrums.visible = !centeredNotefield;
		dadStrums.player = 1;
		dadStrums.cameras = defaultHudCamArray;

		boyfriendStrums = new Strumline(placement + (!centeredNotefield ? valThing : 0), this, boyfriend, true, false, true, 4, downscroll);
		boyfriendStrums.player = 0;
		boyfriendStrums.cameras = defaultHudCamArray;

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

		if (!controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		updateCamFollow();
		startCountdown();

		// Expose variables to scripts
		for (script in hscriptArray) {
			script.setVar("Countdown", Countdown);
			script.setVar("CountdownStep", {
				BEFORE: CountdownStep.BEFORE,
				THREE: CountdownStep.THREE,
				TWO: CountdownStep.TWO,
				ONE: CountdownStep.ONE,
				GO: CountdownStep.GO,
				AFTER: CountdownStep.AFTER
			});
			script.setVar("startCountdown", startCountdown);
			script.setVar("skipCountdown", Countdown.skipCountdown);
			script.setVar("triggerEvent", triggerEvent);
			script.setVar("playCharacterAnim", playCharacterAnim);
			script.setVar("addCameraZoom", addCameraZoom);
			script.setVar("boyfriend", boyfriend);
			script.setVar("dad", dadOpponent);
			script.setVar("dadOpponent", dadOpponent);
			script.setVar("gf", gf);
			script.setVar("songMusic", songMusic);
			script.setVar("inst", songMusic);
			script.setVar("vocals", vocals);
			script.setVar("playerVocals", vocals);
			script.setVar("opponentVocals", opponentVocals);
			script.setVar("modManager", modManager);
			script.setVar("camGame2", camGame2);
			script.setVar("camGame", camGame);
			script.setVar("camHUD", camHUD);
			script.setVar("camAlt", camAlt);
			script.setVar("iconP1", iconP1);
			script.setVar("iconP2", iconP2);
			script.setVar("healthBar", healthBar);
			script.setVar("healthBarBG", healthBarBG);
			script.setVar("scoreBar", scoreBar);
			script.setVar("centerMark", centerMark);
			script.setVar("autoplayMark", autoplayMark);

			// Modern camera methods & variables
			script.setVar("cameraSpeed", cameraSpeed);
			script.setVar("camZoomSpeed", camZoomSpeed);
			script.setVar("camZooming", camZooming);
			script.setVar("camZoomingMult", camZoomingMult);
			script.setVar("camZoomingFrequency", camZoomingFrequency);
			script.setVar("defaultCamZoom", defaultCamZoom);
			script.setVar("camFollow", camFollow);
			script.setVar("camFollowPos", camFollowPos);
			script.setVar("moveCamera", moveCamera);
			script.setVar("moveCameraTo", moveCameraTo);
			script.setVar("snapCamera", snapCamera);
			script.setVar("setCameraTarget", setCameraTarget);
			script.setVar("bfCamOffset", bfCamOffset);
			script.setVar("dadCamOffset", dadCamOffset);
			script.setVar("gfCamOffset", gfCamOffset);
			script.setVar("camFollowOffset", camFollowOffset);

			// Modder HUD customization variables & methods
			script.setVar("healthBarPosition", healthBarPosition);
			script.setVar("healthBarOffset", healthBarOffset);
			script.setVar("healthBarInnerOffset", healthBarInnerOffset);
			script.setVar("healthBarScale", healthBarScale);
			script.setVar("healthBarAlpha", healthBarAlpha);
			script.setVar("showHealthBar", showHealthBar);
			script.setVar("showIcons", showIcons);
			script.setVar("iconOffset", iconOffset);
			script.setVar("iconBopScale", iconBopScale);
			script.setVar("iconP1Offset", iconP1Offset);
			script.setVar("iconP2Offset", iconP2Offset);
			script.setVar("scoreBarOffset", scoreBarOffset);
			script.setVar("showScoreBar", showScoreBar);
			script.setVar("scoreTemplate", scoreTemplate);
			script.setVar("customScoreText", customScoreText);
			script.setVar("updateScoreText", updateScoreText);
			script.setVar("ratingOffset", ratingOffset);
			script.setVar("comboOffset", comboOffset);
			script.setVar("ratingScale", ratingScale);
			script.setVar("comboScale", comboScale);
			script.setVar("showRating", showRating);
			script.setVar("showCombo", showCombo);
			script.setVar("setHUDAlpha", setHUDAlpha);
			script.setVar("setHUDVisible", setHUDVisible);
			script.setVar("reloadHUD", reloadHUD);
		}
		#if sys
		if (stageBuild != null && stageBuild.interp != null) {
			stageBuild.interp.variables.set("Countdown", Countdown);
			stageBuild.interp.variables.set("CountdownStep", {
				BEFORE: CountdownStep.BEFORE,
				THREE: CountdownStep.THREE,
				TWO: CountdownStep.TWO,
				ONE: CountdownStep.ONE,
				GO: CountdownStep.GO,
				AFTER: CountdownStep.AFTER
			});
			stageBuild.interp.variables.set("startCountdown", startCountdown);
			stageBuild.interp.variables.set("skipCountdown", Countdown.skipCountdown);
			stageBuild.interp.variables.set("triggerEvent", triggerEvent);
			stageBuild.interp.variables.set("playCharacterAnim", playCharacterAnim);
			stageBuild.interp.variables.set("addCameraZoom", addCameraZoom);
			stageBuild.interp.variables.set("boyfriend", boyfriend);
			stageBuild.interp.variables.set("dad", dadOpponent);
			stageBuild.interp.variables.set("dadOpponent", dadOpponent);
			stageBuild.interp.variables.set("gf", gf);
			stageBuild.interp.variables.set("songMusic", songMusic);
			stageBuild.interp.variables.set("inst", songMusic);
			stageBuild.interp.variables.set("vocals", vocals);
			stageBuild.interp.variables.set("playerVocals", vocals);
			stageBuild.interp.variables.set("opponentVocals", opponentVocals);
			stageBuild.interp.variables.set("modManager", modManager);
			stageBuild.interp.variables.set("camGame2", camGame2);
			stageBuild.interp.variables.set("camGame", camGame);
			stageBuild.interp.variables.set("camHUD", camHUD);
			stageBuild.interp.variables.set("camAlt", camAlt);
			stageBuild.interp.variables.set("snapCamera", snapCamera);
			stageBuild.interp.variables.set("setCameraTarget", setCameraTarget);
			stageBuild.interp.variables.set("setHUDAlpha", setHUDAlpha);
			stageBuild.interp.variables.set("setHUDVisible", setHUDVisible);
			stageBuild.interp.variables.set("reloadHUD", reloadHUD);
		}
		#end

		callOnScripts('onCreatePost');
	}

	override public function destroy():Void
	{
		callOnScripts('onDestroy');

		Countdown.stopCountdown();
		Countdown.reset();

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
		if (camPosTween != null)
		{
			camPosTween.cancel();
			camPosTween = null;
		}
		if (SONG != null)
		{
			if (SONG.defaultSpeed != null)
				SONG.speed = SONG.defaultSpeed;
			else
				SONG.speed = defaultSongSpeed;
		}

		if (!controllerMode && FlxG.stage != null)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		if (unspawnNotes != null)
		{
			for (i in unspawnNotesIndex...unspawnNotes.length)
			{
				var note:Note = unspawnNotes[i];
				if (note != null)
					note.destroy();
			}
			unspawnNotes = [];
		}
		eventNotes = [];

		if (songMusic != null)
		{
			songMusic.stop();
			FlxG.sound.list.remove(songMusic, true);
			songMusic.destroy();
			songMusic = null;
		}
		if (vocals != null)
		{
			vocals.stop();
			FlxG.sound.list.remove(vocals, true);
			vocals.destroy();
			vocals = null;
		}
		if (opponentVocals != null)
		{
			opponentVocals.stop();
			FlxG.sound.list.remove(opponentVocals, true);
			opponentVocals.destroy();
			opponentVocals = null;
		}

		#if HSCRIPT_ALLOWED
		if (hscriptArray != null)
		{
			for (script in hscriptArray)
			{
				if (script != null && script.interp != null && script.interp.variables != null)
					script.interp.variables.clear();
			}
			hscriptArray = [];
		}
		if (stageBuild != null && stageBuild.interp != null && stageBuild.interp.variables != null)
		{
			stageBuild.interp.variables.clear();
		}
		#end

		if (timerManager != null)
			timerManager.clear();

		comboFormatsMap.clear();
		defaultHudCamArray = [];

		if (modManager != null)
		{
			modManager = flixel.util.FlxDestroyUtil.destroy(modManager);
		}

		super.destroy();

		stageBuild = null;
		boyfriend = null;
		dadOpponent = null;
		gf = null;
		dadStrums = null;
		boyfriendStrums = null;
		strumLines = null;
		camGame2 = null;
		camGame = null;
		camHUD = null;
		camAlt = null;
		prevCamFollow = null;

		if (instance == this)
			instance = null;
		if (uiHUD == this)
			uiHUD = null;
	}

	// =========================================================================
	// SECTION 4: UPDATE & BEAT / STEP HIT LOOP
	// =========================================================================

	override public function update(elapsed:Float):Void
	{
		stageBuild.stageUpdateConstant(elapsed);

		// Song position progression (updated FIRST before super.update and modcharts/notes)
		if (!inCutscene)
		{
			if (startingSong)
			{
				if (startedCountdown || isInCountdown)
				{
					Conductor.songPosition += elapsed * 1000;
					if (Conductor.songPosition >= 0)
					{
						startingSong = false;
						startSong();
					}
				}
			}
			else if (!paused)
			{
				if (songMusic != null && songMusic.playing)
				{
					Conductor.update(elapsed, songMusic);
					if (songMusic.length > 0 && Conductor.songPosition > songMusic.length)
						Conductor.songPosition = songMusic.length;
				}
				else
				{
					Conductor.update(elapsed);
				}
				previousFrameTime = FlxG.game.ticks;
			}
		}

		super.update(elapsed);
		if (hscriptArray.length > 0)
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
			if (FlxG.keys.justPressed.ENTER && (startedCountdown || isInCountdown) && canPause)
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

			// Section tracking & camera focus switching
			var curSection = Std.int(curStep / 16);
			if (generatedMusic && PlayState.SONG != null && PlayState.SONG.notes[curSection] != null)
			{
				if (curSection != lastSection)
				{
					var sec = PlayState.SONG.notes[curSection];
					var lastSec = (lastSection >= 0 && lastSection < PlayState.SONG.notes.length) ? PlayState.SONG.notes[lastSection] : null;
					var lastMustHit:Bool = (lastSec != null) ? lastSec.mustHitSection : !sec.mustHitSection;
					if (sec.mustHitSection != lastMustHit)
					{
						targetCamDisplaceX = 0;
						targetCamDisplaceY = 0;
						camDisplaceX = 0;
						camDisplaceY = 0;
					}
					lastSection = curSection;
					sectionHit(curSection);

					if (!lockFocus)
					{
						var isGfSection:Bool = Reflect.field(sec, "gfSection") == true;
						if (isGfSection)
							moveCamera(GF);
						else if (!sec.mustHitSection)
							moveCamera(DAD);
						else
							moveCamera(BF);
					}
				}
			}

			// Smooth camera displacement & position lerping
			var displaceLerp = Math.exp(-elapsed * camDisplaceSpeed);
			camDisplaceX = FlxMath.lerp(targetCamDisplaceX, camDisplaceX, displaceLerp);
			camDisplaceY = FlxMath.lerp(targetCamDisplaceY, camDisplaceY, displaceLerp);

			var camLerp = Math.exp(-elapsed * 6.0 * cameraSpeed);
			camFollowPos.x = FlxMath.lerp(camFollow.x, camFollowPos.x, camLerp);
			camFollowPos.y = FlxMath.lerp(camFollow.y, camFollowPos.y, camLerp);

			// Camera zoom lerping for camGame2, camGame, camHUD, camAlt
			var easeLerp = Math.exp(-elapsed * 3.0 * camZoomSpeed);
			camGame.zoom = FlxMath.lerp(defaultCamZoom + forceZoom[0], camGame.zoom, easeLerp);
			if (camGame2 != null)
				camGame2.zoom = camGame.zoom;
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

				Countdown.stopCountdown();
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
				callNoteScript(dunceNote.noteSkin, "onSpawnNote", [dunceNote]);
			}

			noteCalls();
			callNoteScripts("onUpdate", [elapsed]);

			if (controllerMode)
				controllerInput();

			if (!lockCamPos)
				updateCamFollow();
		}

		#if DISCORD_RPC
		if (!paused && !startingSong)
		{
			rpcTimer += elapsed;
			if (rpcTimer >= 15.0)
			{
				rpcTimer = 0;
				updateRPC(false);
			}
		}
		#end

		// Update HUD (health bar, score lerp, autoplay mark)
		updateHUD(elapsed);
	}

	override function stepHit():Void
	{
		super.stepHit();

		if (stageBuild != null)
			stageBuild.stageStep(curStep);

		if (hscriptArray.length > 0)
			callOnScripts('onStepHit', [curStep]);

		if (!startingSong && songMusic != null && songMusic.playing && songMusic.time > 0)
		{
			var needResync:Bool = false;
			if (vocals != null && vocals.exists && vocals.length > 0)
			{
				var vocalDesync:Float = Math.abs(songMusic.time - vocals.time);
				if (vocalDesync > 40 || !vocals.playing)
					needResync = true;
			}
			if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
			{
				var oppDesync:Float = Math.abs(songMusic.time - opponentVocals.time);
				if (oppDesync > 40 || !opponentVocals.playing)
					needResync = true;
			}
			if (needResync)
				resyncVocals();
		}
	}

	override function beatHit():Void
	{
		super.beatHit();

		hudBeatHit(curBeat);

		if (hscriptArray.length > 0)
			callOnScripts('onBeatHit', [curBeat]);

		if (camZooming && !startingSong && !reducedMovements)
		{
			if (curBeat % camZoomingFrequency == 0 && camGame.zoom < (defaultCamZoom + 0.35))
			{
				camGame.zoom += camGameZoomBump * camZoomingMult;
				if (camGame2 != null)
					camGame2.zoom = camGame.zoom;
				camHUD.zoom += camHUDZoomBump * camZoomingMult;
				camAlt.zoom += camHUDZoomBump * camZoomingMult;
			}
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

	public function charactersDance(curBeat:Int):Void
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
		if (songMusic == null || startingSong || !songMusic.playing || songMusic.time <= 0) return;

		if (!songMusic.playing)
			songMusic.play();

		if (vocals != null && vocals.exists && vocals.length > 0)
		{
			var desync = Math.abs(songMusic.time - vocals.time);
			if (desync > 40 || !vocals.playing)
			{
				vocals.pause();
				vocals.time = songMusic.time;
				vocals.play();
			}
		}

		if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
		{
			var oppDesync = Math.abs(songMusic.time - opponentVocals.time);
			if (oppDesync > 40 || !opponentVocals.playing)
			{
				opponentVocals.pause();
				opponentVocals.time = songMusic.time;
				opponentVocals.play();
			}
		}

		if (Math.abs(songMusic.time - Conductor.songPosition) > Conductor.maxDesyncThreshold)
		{
			Conductor.syncTo(songMusic.time);
		}
	}

	// =========================================================================
	// SECTION 5: CAMERA SYSTEM
	// =========================================================================

	/**
	 * Switches the active camera target focus with smooth tracking.
	 */
	/**
	 * Switches the active camera target focus with smooth tracking.
	 */
	public function moveCamera(target:Dynamic, ?forced:Bool = false):Void
	{
		if (lockFocus && !forced) return;

		var focusTarget:Focus = DAD;
		if (Std.isOfType(target, Focus))
		{
			focusTarget = cast target;
		}
		else if (Std.isOfType(target, String))
		{
			var str:String = cast(target, String).toLowerCase().trim();
			switch (str)
			{
				case "bf" | "boyfriend" | "player": focusTarget = BF;
				case "dad" | "opponent" | "enemy": focusTarget = DAD;
				case "gf" | "girlfriend": focusTarget = GF;
				case "center" | "middle": focusTarget = CENTER;
				case "custom": focusTarget = CUSTOM;
				default: focusTarget = DAD;
			}
		}

		focus = focusTarget;

		var targetStr:String = switch(focus)
		{
			case BF: "bf";
			case DAD: "dad";
			case GF: "gf";
			case CENTER: "center";
			case CUSTOM: "custom";
			default: "none";
		};

		callOnScripts('onCameraMove', [targetStr]);

		updateCamFollow();
	}

	/**
	 * String-based helper to change camera focus (convenient for scripts and events).
	 */
	public function moveCameraTo(targetName:String, ?forced:Bool = false):Void
	{
		if (targetName == null) return;
		switch(targetName.toLowerCase().trim())
		{
			case "bf" | "boyfriend" | "player":
				moveCamera(BF, forced);
			case "dad" | "opponent" | "enemy":
				moveCamera(DAD, forced);
			case "gf" | "girlfriend":
				moveCamera(GF, forced);
			case "center" | "middle":
				moveCamera(CENTER, forced);
			case "custom":
				moveCamera(CUSTOM, forced);
			default:
				moveCamera(NONE, forced);
		}
	}

	/**
	 * Instantly snaps the camera to a target or recalculates follow position without lerp.
	 */
	public function snapCamera(?pos:FlxPoint = null):Void
	{
		if (pos != null)
		{
			camFollow.setPosition(pos.x, pos.y);
		}
		else
		{
			updateCamFollow();
		}
		camFollowPos.setPosition(camFollow.x, camFollow.y);
		camGame.focusOn(camFollowPos.getPosition());
		if (camGame2 != null)
			camGame2.focusOn(camFollowPos.getPosition());
	}

	/**
	 * Sets a custom coordinate for the camera to follow.
	 */
	public function setCameraTarget(x:Float, y:Float, ?snap:Bool = false):Void
	{
		if (customCamPos == null)
			customCamPos = FlxPoint.get(x, y);
		else
			customCamPos.set(x, y);

		moveCamera(CUSTOM, true);
		if (snap) snapCamera();
	}

	/**
	 * Returns the normal character focus (BF, DAD, GF) for the current song section.
	 */
	public function getNormalSectionFocus():Focus
	{
		var curSec = Std.int(curStep / 16);
		if (PlayState.SONG != null && PlayState.SONG.notes[curSec] != null)
		{
			var sec = PlayState.SONG.notes[curSec];
			if (Reflect.field(sec, "gfSection") == true)
				return GF;
			else if (sec.mustHitSection)
				return BF;
			else
				return DAD;
		}
		return DAD;
	}

	/**
	 * Calculates the target camera coordinate for the character who currently has focus.
	 */
	public function getNormalCameraTarget():FlxPoint
	{
		var normalFocus = getNormalSectionFocus();
		var targetPt:FlxPoint = FlxPoint.get(camFollow != null ? camFollow.x : 0, camFollow != null ? camFollow.y : 0);
		switch (normalFocus)
		{
			case BF:
				if (boyfriend != null)
				{
					var mid = boyfriend.getMidpoint();
					var offX:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetX : 0;
					var offY:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetY : 0;
					targetPt.set(mid.x + camDisplaceX - offX + bfCamOffset.x + camFollowOffset.x, mid.y + camDisplaceY + offY + bfCamOffset.y + camFollowOffset.y);
					mid.put();
				}
			case GF:
				var targetChar:Character = (gf != null) ? gf : dadOpponent;
				if (targetChar != null)
				{
					var mid = targetChar.getMidpoint();
					var offX:Float = (targetChar.characterData != null) ? targetChar.characterData.camOffsetX : 0;
					var offY:Float = (targetChar.characterData != null) ? targetChar.characterData.camOffsetY : 0;
					targetPt.set(mid.x + camDisplaceX + offX + gfCamOffset.x + camFollowOffset.x, mid.y + camDisplaceY + offY + gfCamOffset.y + camFollowOffset.y);
					mid.put();
				}
			default:
				if (dadOpponent != null)
				{
					var mid = dadOpponent.getMidpoint();
					var offX:Float = (dadOpponent.characterData != null) ? dadOpponent.characterData.camOffsetX : 0;
					var offY:Float = (dadOpponent.characterData != null) ? dadOpponent.characterData.camOffsetY : 0;
					targetPt.set(mid.x + camDisplaceX + offX + dadCamOffset.x + camFollowOffset.x, mid.y + camDisplaceY + offY + dadCamOffset.y + camFollowOffset.y);
					mid.put();
				}
		}
		return targetPt;
	}

	/**
	 * Tweens or moves the camera to a custom (x, y) target or returns it smoothly to normal gameplay tracking.
	 */
	public function camPosTo(?targetX:Null<Float>, ?targetY:Null<Float>, ?timeSteps:Float = 0, ?easeName:String = 'linear'):Void
	{
		if (camPosTween != null)
		{
			camPosTween.cancel();
			camPosTween = null;
		}

		var isReset:Bool = (targetX == null || targetY == null);
		var durationSec:Float = 0;
		if (timeSteps > 0 && Conductor.stepCrochet > 0)
			durationSec = (timeSteps * Conductor.stepCrochet) / 1000;

		var easeFunc = CoolUtil.getEaseFromString(easeName);

		if (isReset)
		{
			if (durationSec <= 0)
			{
				lockFocus = false;
				customCamPos = null;
				var normalFocus = getNormalSectionFocus();
				moveCamera(normalFocus, true);
			}
			else
			{
				var startX:Float = camFollowPos != null ? camFollowPos.x : (camFollow != null ? camFollow.x : 0);
				var startY:Float = camFollowPos != null ? camFollowPos.y : (camFollow != null ? camFollow.y : 0);
				var normalTarget:FlxPoint = getNormalCameraTarget();
				var destX:Float = normalTarget.x;
				var destY:Float = normalTarget.y;
				normalTarget.put();

				lockFocus = true;
				focus = CUSTOM;
				if (customCamPos == null)
					customCamPos = FlxPoint.get(startX, startY);
				else
					customCamPos.set(startX, startY);

				camPosTween = FlxTween.num(0.0, 1.0, durationSec, {ease: easeFunc}, function(progress:Float)
				{
					var curX = FlxMath.lerp(startX, destX, progress);
					var curY = FlxMath.lerp(startY, destY, progress);
					if (customCamPos != null)
						customCamPos.set(curX, curY);
					if (camFollow != null)
						camFollow.setPosition(curX, curY);
					if (camFollowPos != null)
						camFollowPos.setPosition(curX, curY);
				});
				camPosTween.onComplete = function(_)
				{
					camPosTween = null;
					lockFocus = false;
					customCamPos = null;
					var normalFocus = getNormalSectionFocus();
					moveCamera(normalFocus, true);
				};
			}
		}
		else
		{
			if (durationSec <= 0)
			{
				setCameraTarget(targetX, targetY);
				lockFocus = true;
			}
			else
			{
				var startX:Float = camFollowPos != null ? camFollowPos.x : (camFollow != null ? camFollow.x : 0);
				var startY:Float = camFollowPos != null ? camFollowPos.y : (camFollow != null ? camFollow.y : 0);

				lockFocus = true;
				focus = CUSTOM;
				if (customCamPos == null)
					customCamPos = FlxPoint.get(startX, startY);
				else
					customCamPos.set(startX, startY);

				camPosTween = FlxTween.num(0.0, 1.0, durationSec, {ease: easeFunc}, function(progress:Float)
				{
					var curX = FlxMath.lerp(startX, targetX, progress);
					var curY = FlxMath.lerp(startY, targetY, progress);
					if (customCamPos != null)
						customCamPos.set(curX, curY);
					if (camFollow != null)
						camFollow.setPosition(curX + camDisplaceX + camFollowOffset.x, curY + camDisplaceY + camFollowOffset.y);
					if (camFollowPos != null)
						camFollowPos.setPosition(curX + camDisplaceX + camFollowOffset.x, curY + camDisplaceY + camFollowOffset.y);
				});
				camPosTween.onComplete = function(_)
				{
					camPosTween = null;
					if (customCamPos != null)
						customCamPos.set(targetX, targetY);
					if (camFollow != null)
						camFollow.setPosition(targetX + camDisplaceX + camFollowOffset.x, targetY + camDisplaceY + camFollowOffset.y);
				};
			}
		}
	}

	/**
	 * Callback triggered on song section changes.
	 */
	public function sectionHit(section:Int):Void
	{
		callOnScripts('onSectionHit', [section]);
		#if sys
		if (stageBuild != null && stageBuild.interp != null)
		{
			try {
				if (stageBuild.interp.variables.exists("onSectionHit"))
					Reflect.callMethod(null, stageBuild.interp.variables.get("onSectionHit"), [section]);
			} catch(e:Dynamic) {}
		}
		#end
	}

	/**
	 * Updates the follow target based on active focus and character camera offsets.
	 */
	public function updateCamFollow():Void
	{
		if (lockCamPos) return;
		if (focus == null) focus = DAD;

		switch(focus)
		{
			case DAD:
				if (dadOpponent != null)
				{
					var mid = dadOpponent.getMidpoint();
					var offX:Float = (dadOpponent.characterData != null) ? dadOpponent.characterData.camOffsetX : 0;
					var offY:Float = (dadOpponent.characterData != null) ? dadOpponent.characterData.camOffsetY : 0;
					var targetX = mid.x + camDisplaceX + offX + dadCamOffset.x + camFollowOffset.x;
					var targetY = mid.y + camDisplaceY + offY + dadCamOffset.y + camFollowOffset.y;
					camFollow.setPosition(targetX, targetY);
					mid.put();
				}
			case BF:
				if (boyfriend != null)
				{
					var mid = boyfriend.getMidpoint();
					var offX:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetX : 0;
					var offY:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetY : 0;
					var targetX = mid.x + camDisplaceX - offX + bfCamOffset.x + camFollowOffset.x;
					var targetY = mid.y + camDisplaceY + offY + bfCamOffset.y + camFollowOffset.y;
					camFollow.setPosition(targetX, targetY);
					mid.put();
				}
			case GF:
				var targetChar:Character = (gf != null) ? gf : dadOpponent;
				if (targetChar != null)
				{
					var mid = targetChar.getMidpoint();
					var offX:Float = (targetChar.characterData != null) ? targetChar.characterData.camOffsetX : 0;
					var offY:Float = (targetChar.characterData != null) ? targetChar.characterData.camOffsetY : 0;
					var targetX = mid.x + camDisplaceX + offX + gfCamOffset.x + camFollowOffset.x;
					var targetY = mid.y + camDisplaceY + offY + gfCamOffset.y + camFollowOffset.y;
					camFollow.setPosition(targetX, targetY);
					mid.put();
				}
			case CENTER:
				if (boyfriend != null && dadOpponent != null)
				{
					var bfMid = boyfriend.getMidpoint();
					var dadMid = dadOpponent.getMidpoint();
					var centerX = (dadMid.x + bfMid.x) / 2 + camDisplaceX + camFollowOffset.x;
					var centerY = (dadMid.y + bfMid.y) / 2 + camDisplaceY + camFollowOffset.y;
					camFollow.setPosition(centerX, centerY);
					bfMid.put();
					dadMid.put();
				}
			case CUSTOM:
				if (customCamPos != null)
				{
					camFollow.setPosition(customCamPos.x + camDisplaceX + camFollowOffset.x, customCamPos.y + camDisplaceY + camFollowOffset.y);
				}
			default:
		}
	}

	private function strumCameraRoll(cStrum:FlxTypedGroup<UIStaticArrow>, mustHit:Bool):Void
	{
		if (!camNoteDisplaceEnabled) return;
		if (cStrum == null || cStrum.members == null || cStrum.members.length < 4)
			return;

		if (!Init.trueSettings.get('No Camera Note Movement'))
		{
			var curSection = Std.int(curStep / 16);
			if (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null)
			{
				var charTurn:Focus = (!mustHit) ? DAD : BF;
				if (focus != GF && charTurn != focus) return;

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
		var defaultY = isDownscroll ? FlxG.height * 0.11 : FlxG.height * 0.89;

		healthBarBG = new FlxSprite(0, (healthBarPosition.y != 0) ? healthBarPosition.y : defaultY + healthBarOffset.y);
		healthBarBG.loadGraphic(Paths.image('UI/healthBar', null, false));
		healthBarBG.screenCenter(X);
		if (healthBarPosition.x != 0)
			healthBarBG.x = healthBarPosition.x;
		else
			healthBarBG.x += healthBarOffset.x;

		healthBarBG.scrollFactor.set();
		healthBarBG.scale.set(healthBarScale.x, healthBarScale.y);
		healthBarBG.alpha = healthBarAlpha;
		healthBarBG.visible = showHealthBar;
		healthBarBG.cameras = [camHUD];

		var detectedBounds:FlxRect = CoolUtil.detectHealthBarBounds(healthBarBG);
		var defaultOffsetX:Float = 4;
		var defaultOffsetY:Float = 4;
		var defaultW:Int = Std.int(healthBarBG.width - 8);
		var defaultH:Int = Std.int(healthBarBG.height - 8);

		if (detectedBounds != null)
		{
			defaultOffsetX = detectedBounds.x;
			defaultOffsetY = detectedBounds.y;
			defaultW = Std.int(detectedBounds.width);
			defaultH = Std.int(detectedBounds.height);
		}

		healthBarInnerOffset.set(defaultOffsetX, defaultOffsetY);

		var barW = (healthBarWidth > 0) ? healthBarWidth : defaultW;
		var barH = (healthBarHeight > 0) ? healthBarHeight : defaultH;

		healthBar = new FlxBar(healthBarBG.x + healthBarInnerOffset.x, healthBarBG.y + healthBarInnerOffset.y, RIGHT_TO_LEFT, barW, barH);
		healthBar.scrollFactor.set();
		healthBar.setRange(0, 2);
		healthBar.value = health;
		healthBar.scale.set(healthBarScale.x, healthBarScale.y);
		healthBar.alpha = healthBarAlpha;
		healthBar.visible = showHealthBar;
		healthBar.cameras = [camHUD];

		var dadColors = (dadOpponent != null) ? dadOpponent.healthColorArray : [175, 102, 206];
		var bfColors = (boyfriend != null) ? boyfriend.healthColorArray : [49, 176, 209];

		currentColorP2 = FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]);
		currentColorP1 = FlxColor.fromRGB(bfColors[0], bfColors[1], bfColors[2]);

		healthBar.createFilledBar(currentColorP2, currentColorP1);
		add(healthBar);
		add(healthBarBG);
	}

	private function setupIcons():Void
	{
		var bfIcon:String = (boyfriend != null) ? boyfriend.healthIcon : 'bf';
		var dadIcon:String = (dadOpponent != null) ? dadOpponent.healthIcon : 'dad';

		iconP1 = new HealthIcon(bfIcon, true);
		iconP1.y = healthBar.y - (iconP1.height / 2) + iconP1Offset.y;
		iconP1.visible = showIcons;
		iconP1.cameras = [camHUD];
		add(iconP1);

		iconP2 = new HealthIcon(dadIcon, false);
		iconP2.y = healthBar.y - (iconP2.height / 2) + iconP2Offset.y;
		iconP2.visible = showIcons;
		iconP2.cameras = [camHUD];
		add(iconP2);
	}

	private function setupTextElements():Void
	{
		var isDownscroll:Bool = Init.trueSettings.get('Downscroll');
		var font:String = Paths.font(scoreBarFont);

		scoreBar = new FlxText(490, (isDownscroll ? 29 : 680) + scoreBarOffset.y, 0, "");
		scoreBar.setFormat(font, scoreBarSize, scoreBarColor);
		scoreBar.setBorderStyle(OUTLINE, scoreBarBorderColor, scoreBarBorderSize);
		scoreBar.antialiasing = true;
		scoreBar.visible = showScoreBar;
		scoreBar.cameras = [camHUD];
		add(scoreBar);

		var infoDisplay:String = CoolUtil.dashToSpace(SONG.song);
		centerMark = new FlxText(0, (isDownscroll ? FlxG.height - 40 : 10) + centerMarkOffset.y, 0, 'K-Slice 0.1-alpha1 | ' + [infoDisplay]);
		centerMark.setFormat(font, 24, FlxColor.WHITE);
		centerMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		centerMark.screenCenter(X);
		centerMark.x += centerMarkOffset.x;
		centerMark.antialiasing = true;
		centerMark.visible = showCenterMark;
		centerMark.cameras = [camHUD];
		add(centerMark);

		autoplayMark = new FlxText(-5, centerMark.y + (isDownscroll ? -60 : 60) + botplayMarkOffset.y, FlxG.width - 800, '[BOTPLAY]\n', 32);
		autoplayMark.setFormat(font, 32, FlxColor.WHITE, CENTER);
		autoplayMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		autoplayMark.screenCenter(X);
		autoplayMark.x += botplayMarkOffset.x;
		autoplayMark.visible = showBotplayMark && boyfriendStrums.autoplay;
		autoplayMark.cameras = [camHUD];

		if (Init.trueSettings.get('Centered Notefield'))
			autoplayMark.y += isDownscroll ? -125 : 125;

		add(autoplayMark);
	}

	/**
	 * Allows modders and scripts to re-align and re-apply HUD custom offsets dynamically.
	 */
	public function reloadHUD():Void
	{
		var isDownscroll:Bool = Init.trueSettings.get('Downscroll');

		if (healthBarBG != null)
		{
			var defaultY = isDownscroll ? FlxG.height * 0.11 : FlxG.height * 0.89;
			healthBarBG.x = (healthBarPosition.x != 0) ? healthBarPosition.x : (FlxG.width - healthBarBG.width) / 2 + healthBarOffset.x;
			healthBarBG.y = (healthBarPosition.y != 0) ? healthBarPosition.y : defaultY + healthBarOffset.y;
			healthBarBG.scale.set(healthBarScale.x, healthBarScale.y);
			healthBarBG.visible = showHealthBar;
			healthBarBG.alpha = healthBarAlpha;
		}

		if (healthBar != null && healthBarBG != null)
		{
			healthBar.x = healthBarBG.x + healthBarInnerOffset.x;
			healthBar.y = healthBarBG.y + healthBarInnerOffset.y;
			healthBar.scale.set(healthBarScale.x, healthBarScale.y);
			healthBar.visible = showHealthBar;
			healthBar.alpha = healthBarAlpha;
		}

		if (scoreBar != null)
		{
			scoreBar.y = (isDownscroll ? 29 : 680) + scoreBarOffset.y;
			scoreBar.visible = showScoreBar;
			updateScoreText();
		}

		if (centerMark != null)
		{
			centerMark.y = (isDownscroll ? FlxG.height - 40 : 10) + centerMarkOffset.y;
			centerMark.visible = showCenterMark;
			centerMark.screenCenter(X);
			centerMark.x += centerMarkOffset.x;
		}

		if (autoplayMark != null && centerMark != null)
		{
			autoplayMark.y = centerMark.y + (isDownscroll ? -60 : 60) + botplayMarkOffset.y;
			if (Init.trueSettings.get('Centered Notefield'))
				autoplayMark.y += isDownscroll ? -125 : 125;
			autoplayMark.screenCenter(X);
			autoplayMark.x += botplayMarkOffset.x;
			autoplayMark.visible = showBotplayMark && boyfriendStrums.autoplay;
		}
	}

	public function setHUDAlpha(val:Float):Void
	{
		hudAlpha = val;
	}

	public function setHUDVisible(val:Bool):Void
	{
		hudVisible = val;
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

		var prevHealthValue:Float = healthBar.value;
		healthBar.value = FlxMath.lerp(healthBar.value, health, Math.exp(-elapsed * healthBarLerpSpeed));
		if (Math.abs(healthBar.value - prevHealthValue) > 0.0005)
			healthBar.updateBar();

		var iconP1Health = FlxMath.remapToRange(healthBar.value, 0, 2, 0, 100);
		if (iconP1 != null)
		{
			iconP1.visible = showIcons;
			iconP1.updateAnim(iconP1Health);
			var mult1:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * iconLerpSpeed));
			if (Math.abs(mult1 - 1.0) < 0.001) mult1 = 1.0;
			if (iconP1.scale.x != mult1)
			{
				iconP1.scale.set(mult1, mult1);
				iconP1.updateHitbox();
			}
		}

		if (iconP2 != null)
		{
			iconP2.visible = showIcons;
			iconP2.updateAnim(100 - iconP1Health);
			var mult2:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * iconLerpSpeed));
			if (Math.abs(mult2 - 1.0) < 0.001) mult2 = 1.0;
			if (iconP2.scale.x != mult2)
			{
				iconP2.scale.set(mult2, mult2);
				iconP2.updateHitbox();
			}
		}

		var percentMath:Float = FlxMath.remapToRange(healthBar.value, 0, 2, 100, 0) * 0.01;
		var iconPos:Float = healthBar.x + (healthBar.width * percentMath);

		if (iconP1 != null)
		{
			iconP1.x = iconPos - iconOffset + iconP1Offset.x;
			iconP1.y = healthBar.y - (iconP1.height / 2) + iconP1Offset.y;
		}

		if (iconP2 != null)
		{
			iconP2.x = iconPos - (iconP2.width - iconOffset) + iconP2Offset.x;
			iconP2.y = healthBar.y - (iconP2.height / 2) + iconP2Offset.y;
		}
	}

	private function updateScoreLerp(elapsed:Float):Void
	{
		if (Math.abs(displayedScore - songScore) > 0.1)
		{
			displayedScore = FlxMath.lerp(displayedScore, songScore, elapsed * scoreLerpSpeed);
			if (Math.abs(displayedScore - songScore) < 0.1)
				displayedScore = songScore;

			var rounded:Int = Math.round(displayedScore);
			if (rounded != lastRenderedScore)
			{
				updateScoreText();
			}
		}
	}

	public function hudBeatHit(beat:Int):Void
	{
		if (iconP1 != null)
		{
			iconP1.scale.set(iconBopScale, iconBopScale);
			iconP1.updateHitbox();
		}
		if (iconP2 != null)
		{
			iconP2.scale.set(iconBopScale, iconBopScale);
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
		scoreBar.visible = showScoreBar;

		lastRenderedScore = Math.round(displayedScore);

		if (customScoreText != null)
		{
			scoreBar.text = customScoreText;
		}
		else
		{
			var accDisplay:String = (Timings.notesHit == 0) ? "N/A" : (FlxMath.roundDecimal(Timings.getAccuracy(), 2) + "%");
			var fcDisplay:String = (Timings.comboDisplay == null || Timings.comboDisplay == "") ? "FC" : Timings.comboDisplay;
			var formattedFC:String = "[" + fcDisplay + "]";

			var txt:String = scoreTemplate;
			txt = txt.replace("{score}", formatScore(lastRenderedScore));
			txt = txt.replace("{misses}", Std.string(misses));
			txt = txt.replace("{comboBreaks}", Std.string(misses));
			txt = txt.replace("{accuracy}", accDisplay);
			txt = txt.replace("{combo}", Std.string(combo));

			if (txt.indexOf("[{comboDisplay}]") != -1)
				txt = txt.replace("[{comboDisplay}]", formattedFC);
			else
				txt = txt.replace("{comboDisplay}", formattedFC);

			if (txt.indexOf("[{fc}]") != -1)
				txt = txt.replace("[{fc}]", formattedFC);
			else
				txt = txt.replace("{fc}", formattedFC);

			scoreBar.clearFormats();
			scoreBar.text = txt;

			var fcColor:flixel.util.FlxColor = Timings.getComboColor(fcDisplay);
			var format = comboFormatsMap.get(fcColor);
			if (format == null)
			{
				format = new flixel.text.FlxText.FlxTextFormat(fcColor);
				comboFormatsMap.set(fcColor, format);
			}

			var fcIndex:Int = txt.indexOf(formattedFC);
			if (fcIndex != -1)
			{
				scoreBar.addFormat(format, fcIndex, fcIndex + formattedFC.length);
			}
			else
			{
				var singleIdx:Int = txt.indexOf(fcDisplay);
				if (singleIdx != -1)
					scoreBar.addFormat(format, singleIdx, singleIdx + fcDisplay.length);
			}
		}

		scoreBar.screenCenter(X);
		scoreBar.x += scoreBarOffset.x;
		scoreBar.y = (downscroll ? 29 : 680) + scoreBarOffset.y;

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

	public inline function isKeyHeld(noteData:Int):Bool
	{
		return switch (noteData % 4)
		{
			case 0: controls.LEFT;
			case 1: controls.DOWN;
			case 2: controls.UP;
			case 3: controls.RIGHT;
			default: false;
		}
	}

	public inline function anyKeyHeld():Bool
	{
		return controls.LEFT || controls.DOWN || controls.UP || controls.RIGHT;
	}

	private function controllerInput():Void
	{
		if (controls.LEFT_P) onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[0][0]));
		if (controls.DOWN_P) onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[1][0]));
		if (controls.UP_P) onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[2][0]));
		if (controls.RIGHT_P) onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[3][0]));

		if (controls.LEFT_R) onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[0][0]));
		if (controls.DOWN_R) onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[1][0]));
		if (controls.UP_R) onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[2][0]));
		if (controls.RIGHT_R) onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[3][0]));
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
		FlxG.sound.list.add(songMusic);

		loadSongVocals();

		generateChart();
	}

	public function loadSongVocals():Void
	{
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
			vocals = null;
		}
		if (opponentVocals != null)
		{
			opponentVocals.stop();
			opponentVocals.destroy();
			opponentVocals = null;
		}

		vocals = new FlxSound();
		vocals.autoDestroy = false;

		opponentVocals = new FlxSound();
		opponentVocals.autoDestroy = false;

		if (SONG.needsVoices)
		{
			var p1Suffix:String = 'bf';
			if (boyfriend != null && boyfriend.vocalsFile != null && boyfriend.vocalsFile.trim().length > 0)
				p1Suffix = boyfriend.vocalsFile.trim();

			var p2Suffix:String = 'dad';
			if (dadOpponent != null && dadOpponent.vocalsFile != null && dadOpponent.vocalsFile.trim().length > 0)
				p2Suffix = dadOpponent.vocalsFile.trim();

			var playerSound:openfl.media.Sound = Paths.voices(SONG.song, p1Suffix);
			if (playerSound == null && boyfriend != null && boyfriend.curCharacter != null && boyfriend.curCharacter != 'bf')
				playerSound = Paths.voices(SONG.song, boyfriend.curCharacter);
			if (playerSound == null && p1Suffix != 'bf')
				playerSound = Paths.voices(SONG.song, 'bf');

			var oppSound:openfl.media.Sound = Paths.voices(SONG.song, p2Suffix);
			if (oppSound == null && dadOpponent != null && dadOpponent.curCharacter != null && dadOpponent.curCharacter != 'dad')
				oppSound = Paths.voices(SONG.song, dadOpponent.curCharacter);
			if (oppSound == null && p2Suffix != 'dad')
				oppSound = Paths.voices(SONG.song, 'dad');

			if (playerSound != null)
				vocals.load(playerSound);

			if (oppSound != null)
				opponentVocals.load(oppSound);

			if (playerSound == null && oppSound == null)
			{
				var defaultVoice:openfl.media.Sound = Paths.voices(SONG.song);
				if (defaultVoice != null)
					vocals.load(defaultVoice);
			}
			else if (playerSound == null)
			{
				var defaultVoice:openfl.media.Sound = Paths.voices(SONG.song);
				if (defaultVoice != null)
					vocals.load(defaultVoice);
			}
		}

		if (vocals != null)
			FlxG.sound.list.add(vocals);
		if (opponentVocals != null)
			FlxG.sound.list.add(opponentVocals);
	}

	public function generateChart():Void
	{
		if (unspawnNotes != null && unspawnNotes.length > 0)
		{
			for (i in unspawnNotesIndex...unspawnNotes.length)
			{
				if (unspawnNotes[i] != null)
					unspawnNotes[i].destroy();
			}
		}
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
									var targetChar:String = (ev[2] != null) ? Std.string(ev[2]).trim() : '';
									if (targetChar == '' && ev[1] != null)
									{
										var spl = Std.string(ev[1]).split(',');
										for (part in spl)
										{
											var tr = part.trim();
											if (tr != '' && Math.isNaN(Std.parseFloat(tr)) && tr != '0' && tr != '1' && tr != '2' && tr.toLowerCase() != 'bf' && tr.toLowerCase() != 'boyfriend' && tr.toLowerCase() != 'dad' && tr.toLowerCase() != 'opponent' && tr.toLowerCase() != 'gf')
											{
												targetChar = tr;
												break;
											}
										}
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
				var daNoteType:Dynamic = 0;
				if (songNotes.length > 3 && songNotes[3] != null)
				{
					daNoteType = songNotes[3];
					if (Std.isOfType(songNotes[3], Float) || Std.isOfType(songNotes[3], Int))
						daNoteAlt = songNotes[3];
				}

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

				var swagNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, daStrumTime, daNoteData, daNoteType, daNoteAlt);
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
						var sustainNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, sustainTime, daNoteData, daNoteType, daNoteAlt, true, oldNote);
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
		FunkinArrows.preloadSkins();
		for (n in unspawnNotes)
		{
			if (n != null && n.noteSkin != null)
				getNoteScript(n.noteSkin);
		}
		for (ev in eventNotes)
		{
			if (ev != null && (ev[1] == 'Change Note Skins' || ev[1] == 'change note skins'))
			{
				var s:String = (ev[3] != null) ? Std.string(ev[3]).trim() : 'default';
				if (s != '')
				{
					FunkinArrows.getNoteAtlas(s);
					getNoteScript(s);
				}
			}
		}
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
			var isDownscroll:Bool = downscroll;
			var isGhostTapping:Bool = ghostTapping;
			var isAlphaHolds:Bool = alphaHolds;

			for (strumline in strumLines)
			{
				var downscrollMultiplier = isDownscroll ? -1 : 1;
				var members = strumline.allNotes.members;
				var i:Int = members.length - 1;

				while (i >= 0)
				{
					var daNote:Note = members[i];
					if (daNote == null || !daNote.alive)
					{
						i--;
						continue;
					}

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

						daNote.alpha = (daNote.isSustainNote ? (isAlphaHolds ? 1 : 0.6) : 1) * daNote.alphaMod;

						if (daNote.isSustainNote)
						{
							daNote.flipY = false;

							var futureSongPos = Conductor.songPosition + daNote.sustainLength;
							var futureBeat = futureSongPos / (Conductor.stepCrochet * 4);
							var nextVisPos = modManager.getVisPos(Conductor.songPosition, daNote.strumTime + daNote.sustainLength, speed);
							var nextDiff = (daNote.strumTime + daNote.sustainLength - Conductor.songPosition);
							var nextPos = modManager.getPos(daNote.strumTime + daNote.sustainLength, nextVisPos, nextDiff, futureBeat, daNote.noteData, pID, daNote, _nextModchartVector);

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

								var swagRect = daNote.noteClipRect;
								if (swagRect == null)
								{
									swagRect = flixel.math.FlxRect.get(0, 0, daNote.frameWidth, daNote.frameHeight);
									daNote.noteClipRect = swagRect;
								}
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
									var swagRect = daNote.noteClipRect;
									if (swagRect == null)
									{
										swagRect = flixel.math.FlxRect.get(0, 0, daNote.frameWidth, daNote.frameHeight);
										daNote.noteClipRect = swagRect;
									}
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
									var swagRect = daNote.noteClipRect;
									if (swagRect == null)
									{
										swagRect = flixel.math.FlxRect.get(0, 0, daNote.frameWidth, daNote.frameHeight);
										daNote.noteClipRect = swagRect;
									}
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
							var cancelMiss:Dynamic = callNoteScript(daNote.noteSkin, "noteMiss", [daNote, boyfriend]);
							if (cancelMiss != false)
							{
								if (!daNote.isSustainNote)
								{
									daNote.tooLate = true;
									for (note in daNote.childrenNotes)
										note.tooLate = true;

									vocals.volume = 0;
									missNoteCheck(isGhostTapping, daNote.noteData, boyfriend, true);
								}
								else if (daNote.isSustainNote)
								{
									daNote.tooLate = true;
									if (daNote.parentNote != null)
									{
										var parentNote = daNote.parentNote;
										if (!parentNote.tooLate)
										{
											var breakFromLate:Bool = false;
											for (note in parentNote.childrenNotes)
											{
												if (note != daNote && note.tooLate && !note.wasGoodHit)
													breakFromLate = true;
											}
											parentNote.tooLate = true;
											for (note in parentNote.childrenNotes)
												note.tooLate = true;
											if (!breakFromLate)
												missNoteCheck(isGhostTapping, daNote.noteData, boyfriend, true);
										}
									}
								}
							}
							else
							{
								daNote.tooLate = true;
								for (note in daNote.childrenNotes)
									note.tooLate = true;
							}
						}
					}

					// Destroy notes that went off-screen
					if ((((!isDownscroll) && (daNote.y < -daNote.height))
						|| ((isDownscroll) && (daNote.y > (FlxG.height + daNote.height))))
						&& (daNote.tooLate || daNote.wasGoodHit))
					{
						destroyNote(strumline, daNote);
					}

					i--;
				}

				strumCameraRoll(strumline.receptors, (strumline == boyfriendStrums));
			}
		}

		// Reset boyfriend idle animation
		if ((boyfriend != null && boyfriend.animation != null)
			&& (boyfriend.holdTimer > Conductor.stepCrochet * (boyfriend.singDuration * 0.001) && (!anyKeyHeld() || boyfriendStrums.autoplay)))
		{
			if (boyfriend.getAnimName().startsWith('sing') && !boyfriend.getAnimName().endsWith('miss') && !boyfriend.animLocked)
				boyfriend.dance();
		}
	}

	private function mainControls(daNote:Note, char:Character, strumline:Strumline, autoplay:Bool):Void
	{
		if (autoplay)
		{
			if (daNote.strumTime <= Conductor.songPosition)
			{
				goodNoteHit(daNote, char, strumline, strumline.displayJudgements);
			}
		}
		else
		{
			if (daNote.isSustainNote
				&& daNote.mustPress
				&& daNote.canBeHit
				&& !daNote.tooLate
				&& daNote.parentNote != null
				&& daNote.parentNote.wasGoodHit
				&& isKeyHeld(daNote.noteData))
			{
				goodNoteHit(daNote, char, strumline);
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
		strumline.allNotes.remove(daNote, true);
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
			if (coolNote.mustPress || character == boyfriend)
			{
				if (vocals != null && vocals.exists)
					vocals.volume = 1;
			}
			else
			{
				if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
					opponentVocals.volume = 1;
			}

			characterPlayAnimation(coolNote, character);
			if (characterStrums.receptors.members[coolNote.noteData] != null)
			{
				characterStrums.receptors.members[coolNote.noteData].playAnim('confirm', true);
			}

			var scriptRet:Dynamic = null;
			if (coolNote.mustPress || character == boyfriend)
				scriptRet = callNoteScript(coolNote.noteSkin, "goodNoteHit", [coolNote, character, characterStrums]);
			else
				scriptRet = callNoteScript(coolNote.noteSkin, "opponentNoteHit", [coolNote, character, characterStrums]);

			if (scriptRet == false)
				canDisplayJudgement = false;

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
					if (Timings.judgementsMap.get(foundRating)[3] > 0)
					{
						increaseCombo(foundRating, coolNote.noteData, character);
						popUpScore(foundRating, ratingTiming, characterStrums, coolNote);
						healthCall(Timings.judgementsMap.get(foundRating)[3]);
					}
					else
					{
						missNoteCheck(true, coolNote.noteData, character, true, true);
					}
				}
				else if (coolNote.isSustainNote)
				{
					if (coolNote.parentNote != null && coolNote.parentNote.childrenNotes != null && coolNote.parentNote.childrenNotes.length > 0)
					{
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
			if (character != null)
			{
				character.specialAnim = false;
				character.animLocked = false;
				character.playAnim('sing' + stringDirection.toUpperCase() + 'miss', lockMiss);
			}
		}
		if (character == boyfriend && vocals != null && vocals.exists)
			vocals.volume = 0;
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
		if (character != null)
		{
			character.specialAnim = false;
			character.animLocked = false;
			character.playAnim(stringArrow, true);
			character.holdTimer = 0;
		}
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
		if (!showCombo && !cache) return;
		if (combo <= 0 && !cache) return;

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

			numScore.alpha = comboAlpha;
			numScore.color = FlxColor.WHITE;

			if (assetModifier == 'pixel')
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
				numScore.antialiasing = false;
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * comboScale));
				numScore.antialiasing = true;
			}
			numScore.updateHitbox();

			numScore.screenCenter();
			numScore.x = (30 * scoreInt) + 550 + comboOffset.x;
			numScore.y = 150 - (numScore.height / 2) + comboOffset.y;

			var numScaleX:Float = numScore.scale.x;
			var numScaleY:Float = numScore.scale.y;
			numScore.scale.set(numScaleX * 1.15, numScaleY * 1.15);
			FlxTween.tween(numScore.scale, {x: numScaleX, y: numScaleY}, 0.2, {ease: FlxEase.cubeOut});

			numScore.cameras = (comboCamera != null) ? [comboCamera] : defaultHudCamArray;

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

		if (grpRatings != null)
		{
			grpRatings.forEachAlive(function(rating:FlxSprite)
			{
				FlxTween.cancelTweensOf(rating);
				FlxTween.cancelTweensOf(rating.scale);
				rating.kill();
			});
		}

		if (grpCombos != null)
		{
			grpCombos.forEachAlive(function(numScore:FlxSprite)
			{
				FlxTween.cancelTweensOf(numScore);
				FlxTween.cancelTweensOf(numScore.scale);
				numScore.kill();
			});
		}

		Timings.updateAccuracy(0);
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
		if (!showRating && !cache) return;
		if (!cache && (daRating == "miss" || daRating == "shit" || (Timings.judgementsMap.exists(daRating) && Timings.judgementsMap.get(daRating)[3] <= 0))) return;

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
			rating.setGraphicSize(Std.int(rating.width * ratingScale));
			rating.antialiasing = true;
		}
		rating.updateHitbox();

		rating.alpha = ratingAlpha;
		rating.screenCenter();
		rating.x = 550 + ratingOffset.x;
		rating.y = 60 + ratingOffset.y;

		var ratScaleX:Float = rating.scale.x;
		var ratScaleY:Float = rating.scale.y;
		rating.scale.set(ratScaleX * 1.15, ratScaleY * 1.15);
		FlxTween.tween(rating.scale, {x: ratScaleX, y: ratScaleY}, 0.2, {ease: FlxEase.cubeOut});

		rating.cameras = (ratingCamera != null) ? [ratingCamera] : defaultHudCamArray;

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

	public function callOnScripts(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		var result:Dynamic = null;
		for (script in hscriptArray)
		{
			if (script.active)
			{
				var ret = script.call(funcName, args);
				if (ret != null) result = ret;
			}
		}
		#if sys
		if (stageBuild != null && funcName != 'onUpdate' && funcName != 'update' && funcName != 'onStepHit' && funcName != 'stepHit' && funcName != 'onBeatHit' && funcName != 'beatHit')
		{
			var ret = stageBuild.callScript(funcName, args != null ? args : []);
			if (ret != null) result = ret;
		}
		#end
		return result;
	}

	public var noteScripts:Map<String, HScriptHandler> = new Map();

	public function getNoteScript(skin:String):HScriptHandler
	{
		if (skin == null || skin == '') skin = 'default';
		if (noteScripts.exists(skin))
			return noteScripts.get(skin);

		#if sys
		var scriptPath = Paths.getPath('data/notes/' + skin + '.hx', TEXT);
		if (sys.FileSystem.exists(scriptPath))
		{
			var handler = new HScriptHandler(scriptPath);
			noteScripts.set(skin, handler);
			return handler;
		}

		// Fallback to default.hx
		if (skin != 'default')
		{
			var defaultScriptPath = Paths.getPath('data/notes/default.hx', TEXT);
			if (sys.FileSystem.exists(defaultScriptPath))
			{
				var handler = new HScriptHandler(defaultScriptPath);
				noteScripts.set(skin, handler);
				return handler;
			}
		}
		#end

		noteScripts.set(skin, null);
		return null;
	}

	public function callNoteScript(skin:String, funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		var handler = getNoteScript(skin);
		if (handler != null && handler.active)
		{
			return handler.call(funcName, args);
		}
		return null;
	}

	public function callNoteScripts(funcName:String, ?args:Array<Dynamic>):Void
	{
		for (script in noteScripts)
		{
			if (script != null && script.active)
			{
				script.call(funcName, args);
			}
		}
	}

	public function changeNoteSkins(target:Int, newSkin:String):Void
	{
		// 1. Preload atlas in case it wasn't preloaded
		if (newSkin != 'pixel')
			FunkinArrows.getNoteAtlas(newSkin);

		// 2. Change Strumlines
		if (target == 0 || target == 2)
		{
			if (boyfriendStrums != null)
				boyfriendStrums.changeSkin(newSkin);
		}
		if (target == 1 || target == 2)
		{
			if (dadStrums != null)
				dadStrums.changeSkin(newSkin);
		}

		// 3. Change unspawnNotes
		if (unspawnNotes != null && unspawnNotes.length > 0)
		{
			for (i in unspawnNotesIndex...unspawnNotes.length)
			{
				var note:Note = unspawnNotes[i];
				if (note != null)
				{
					var isBf:Bool = note.mustPress;
					if ((target == 0 && isBf) || (target == 1 && !isBf) || target == 2)
					{
						if (note.noteType == null || note.noteType == 0 || note.noteSkin == 'default' || note.noteSkin == null)
						{
							note.loadSkin(newSkin, PlayState.assetModifier);
						}
					}
				}
			}
		}
	}

	private var eventRecursionDepth:Int = 0;

	public function triggerEvent(eventName:String, value1:String, value2:String):Void
	{
		if (eventRecursionDepth > 8)
		{
			FlxG.log.warn('triggerEvent recursion limit reached for: ' + eventName);
			return;
		}

		eventRecursionDepth++;
		try
		{
			switch (eventName)
			{
			case 'Change Note Skins' | 'change note skins' | 'Change Note Skin':
				var rawVal1:String = (value1 != null) ? value1.trim().toLowerCase() : "0";
				var target:Int = 0; // 0 = bf, 1 = dad, 2 = ambos
				if (rawVal1 == '1' || rawVal1 == 'dad' || rawVal1 == 'opponent')
					target = 1;
				else if (rawVal1 == '2' || rawVal1 == 'ambos' || rawVal1 == 'both' || rawVal1 == 'all')
					target = 2;
				else
					target = 0;

				var newSkin:String = (value2 != null) ? value2.trim() : "default";
				if (newSkin == "") newSkin = "default";

				changeNoteSkins(target, newSkin);

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
				var targetSpeed:Float = defaultSongSpeed;

				if (rawVal1 != "" && rawVal1.toLowerCase() != "default" && rawVal1.toLowerCase() != "reset")
				{
					if (rawVal1.startsWith("*") || rawVal1.startsWith("x") || rawVal1.startsWith("X"))
					{
						var mult:Float = Std.parseFloat(rawVal1.substr(1).trim());
						if (!Math.isNaN(mult) && mult > 0)
							targetSpeed = defaultSongSpeed * mult;
					}
					else
					{
						var parsedSpeed:Float = Std.parseFloat(rawVal1);
						if (!Math.isNaN(parsedSpeed) && parsedSpeed > 0)
							targetSpeed = parsedSpeed;
					}
				}

				var rawVal2:String = (value2 != null) ? value2.trim() : "";
				var timeSteps:Float = 0;
				var easeName:String = "linear";

				if (rawVal2 != "")
				{
					var normV2:String = rawVal2;
					normV2 = StringTools.replace(normV2, ' and ', ',');
					normV2 = StringTools.replace(normV2, ' AND ', ',');

					var parts2:Array<String> = normV2.split(',');
					if (parts2.length == 1)
					{
						var sp2:Array<String> = [];
						for (p in normV2.split(' '))
						{
							var tr = p.trim();
							if (tr != '') sp2.push(tr);
						}
						if (sp2.length >= 2)
							parts2 = sp2;
					}

					if (parts2.length >= 1)
					{
						var parsedSteps = Std.parseFloat(parts2[0].trim());
						if (!Math.isNaN(parsedSteps))
						{
							timeSteps = parsedSteps;
							if (parts2.length >= 2 && parts2[1].trim() != '')
								easeName = parts2[1].trim();
						}
						else
						{
							easeName = parts2[0].trim();
						}
					}
				}

				if (timeSteps <= 0)
				{
					PlayState.SONG.speed = targetSpeed;
					updateAllNotesSpeed();
				}
				else
				{
					var durationSec:Float = (timeSteps * Conductor.stepCrochet) / 1000;
					var easeFunc = CoolUtil.getEaseFromString(easeName);
					scrollTween = flixel.tweens.FlxTween.num(PlayState.SONG.speed, targetSpeed, durationSec, {ease: easeFunc}, function(v:Float)
					{
						PlayState.SONG.speed = v;
						updateAllNotesSpeed();
					});
					scrollTween.onComplete = function(_)
					{
						scrollTween = null;
					};
				}

			case 'changeChar' | 'Change Character':
				var rawVal1:String = (value1 != null) ? value1.trim() : "";
				var newChar:String = (value2 != null) ? value2.trim() : "";
				var charType:String = "1";
				var customX:Null<Float> = null;
				var customY:Null<Float> = null;

				// Normaliza separadores como ' and ', '&' para vírgula
				var normalizedVal1:String = rawVal1;
				normalizedVal1 = StringTools.replace(normalizedVal1, ' and ', ',');
				normalizedVal1 = StringTools.replace(normalizedVal1, ' AND ', ',');
				normalizedVal1 = StringTools.replace(normalizedVal1, '&', ',');

				var parts:Array<String> = normalizedVal1.split(',');
				if (parts.length == 1)
				{
					var spaceParts:Array<String> = [];
					for (p in normalizedVal1.split(' '))
					{
						var tr = p.trim();
						if (tr != '') spaceParts.push(tr);
					}
					if (spaceParts.length > 1)
						parts = spaceParts;
				}

				if (parts.length > 0 && parts[0].trim() != '')
					charType = parts[0].trim().toLowerCase();

				// Fallback legado se value2 estiver vazio e value1 contiver o nome do personagem (ex: "1, duke_p2")
				if (newChar == '' && parts.length > 1 && Math.isNaN(Std.parseFloat(parts[1].trim())))
				{
					newChar = parts[1].trim();
					if (parts.length > 2 && !Math.isNaN(Std.parseFloat(parts[2].trim())))
						customX = Std.parseFloat(parts[2].trim());
					if (parts.length > 3 && !Math.isNaN(Std.parseFloat(parts[3].trim())))
						customY = Std.parseFloat(parts[3].trim());
				}
				else
				{
					if (parts.length > 1)
					{
						var px:Float = Std.parseFloat(parts[1].trim());
						if (!Math.isNaN(px))
							customX = px;
					}
					if (parts.length > 2)
					{
						var py:Float = Std.parseFloat(parts[2].trim());
						if (!Math.isNaN(py))
							customY = py;
					}
				}

				var targetIndex:Int = 1;
				if (charType == '0' || charType == 'bf' || charType == 'boyfriend' || charType == 'player')
					targetIndex = 0;
				else if (charType == '2' || charType == 'gf' || charType == 'girlfriend')
					targetIndex = 2;

				changeCharacter(targetIndex, newChar, customX, customY);

			case 'camPosTo' | 'Cam Pos To' | 'cam pos to' | 'Camera Pos To' | 'Cam Pos':
				var rawVal1:String = (value1 != null) ? value1.trim() : "";
				var isReset:Bool = (rawVal1 == "" || rawVal1.toLowerCase() == "reset" || rawVal1.toLowerCase() == "normal" || rawVal1.toLowerCase() == "default");

				var customX:Null<Float> = null;
				var customY:Null<Float> = null;

				if (!isReset)
				{
					var normV1:String = rawVal1;
					normV1 = StringTools.replace(normV1, ' and ', ',');
					normV1 = StringTools.replace(normV1, ' AND ', ',');
					normV1 = StringTools.replace(normV1, '&', ',');

					var parts1:Array<String> = normV1.split(',');
					if (parts1.length == 1)
					{
						var sp:Array<String> = [];
						for (p in normV1.split(' '))
						{
							var tr = p.trim();
							if (tr != '') sp.push(tr);
						}
						if (sp.length >= 2)
							parts1 = sp;
					}

					if (parts1.length >= 2)
					{
						var px = Std.parseFloat(parts1[0].trim());
						var py = Std.parseFloat(parts1[1].trim());
						if (!Math.isNaN(px) && !Math.isNaN(py))
						{
							customX = px;
							customY = py;
						}
					}
				}

				var rawVal2:String = (value2 != null) ? value2.trim() : "";
				var timeSteps:Float = 0;
				var easeName:String = "linear";

				if (rawVal2 != "")
				{
					var normV2:String = rawVal2;
					normV2 = StringTools.replace(normV2, ' and ', ',');
					normV2 = StringTools.replace(normV2, ' AND ', ',');

					var parts2:Array<String> = normV2.split(',');
					if (parts2.length == 1)
					{
						var sp2:Array<String> = [];
						for (p in normV2.split(' '))
						{
							var tr = p.trim();
							if (tr != '') sp2.push(tr);
						}
						if (sp2.length >= 2)
							parts2 = sp2;
					}

					if (parts2.length >= 1)
					{
						var parsedSteps = Std.parseFloat(parts2[0].trim());
						if (!Math.isNaN(parsedSteps))
						{
							timeSteps = parsedSteps;
							if (parts2.length >= 2 && parts2[1].trim() != '')
								easeName = parts2[1].trim();
						}
						else
						{
							easeName = parts2[0].trim();
						}
					}
				}

				camPosTo(customX, customY, timeSteps, easeName);

			case 'Play Anim' | 'play anim' | 'Play Animation' | 'play animation' | 'playAnim':
				var rawVal1:String = (value1 != null) ? Std.string(value1).trim().toLowerCase() : "0";
				var targetChars:Array<Character> = [];
				if (rawVal1 == '1' || rawVal1 == 'dad' || rawVal1 == 'opponent')
				{
					if (dadOpponent != null) targetChars.push(dadOpponent);
				}
				else if (rawVal1 == '2' || rawVal1 == 'gf' || rawVal1 == 'girlfriend')
				{
					if (gf != null) targetChars.push(gf);
				}
				else if (rawVal1 == 'both' || rawVal1 == 'all' || rawVal1 == 'ambos' || rawVal1 == 'todos')
				{
					if (boyfriend != null) targetChars.push(boyfriend);
					if (dadOpponent != null) targetChars.push(dadOpponent);
				}
				else
				{
					if (boyfriend != null) targetChars.push(boyfriend);
				}

				if (targetChars.length == 0) return;

				var animToPlay:String = "";
				var isLocked:Bool = false;

				if (value2 != null)
				{
					var rawV2:String = Std.string(value2).trim();
					if (rawV2.contains(','))
					{
						var parts:Array<String> = rawV2.split(',');
						animToPlay = parts[0].trim();
						if (parts.length > 1)
						{
							var flag:String = parts[1].trim().toLowerCase();
							if (flag == 'lock' || flag == 'locked' || flag == 'true' || flag == '1' || flag == 'yes' || flag == 'sim')
								isLocked = true;
						}
					}
					else
					{
						var lowV2:String = rawV2.toLowerCase();
						if (lowV2.endsWith(' lock'))
						{
							isLocked = true;
							animToPlay = rawV2.substr(0, rawV2.length - 5).trim();
						}
						else if (lowV2.endsWith(' locked'))
						{
							isLocked = true;
							animToPlay = rawV2.substr(0, rawV2.length - 7).trim();
						}
						else
						{
							animToPlay = rawV2;
						}
					}
				}

				if (animToPlay.startsWith('"') && animToPlay.endsWith('"'))
					animToPlay = animToPlay.substring(1, animToPlay.length - 1).trim();
				if (animToPlay.startsWith("'") && animToPlay.endsWith("'"))
					animToPlay = animToPlay.substring(1, animToPlay.length - 1).trim();

				if (animToPlay != "")
				{
					for (c in targetChars)
					{
						playCharacterAnim(c, animToPlay, isLocked);
					}
				}

			case 'Add Cam Zoom' | 'add cam zoom' | 'Add Camera Zoom' | 'add camera zoom' | 'addCamZoom' | 'addCameraZoom':
				var rawV1:String = (value1 != null) ? Std.string(value1).trim() : '';
				var rawV2:String = (value2 != null) ? Std.string(value2).trim() : '';

				if (rawV1.contains(',') && rawV2 == '')
				{
					var parts = rawV1.split(',');
					rawV1 = parts[0].trim();
					if (parts.length > 1) rawV2 = parts[1].trim();
				}

				var camZoom:Float = (rawV1 != '') ? Std.parseFloat(rawV1) : 0.015;
				if (Math.isNaN(camZoom)) camZoom = 0.015;

				var hudZoom:Float = (rawV2 != '') ? Std.parseFloat(rawV2) : 0.03;
				if (Math.isNaN(hudZoom)) hudZoom = 0.03;

				addCameraZoom(camZoom, hudZoom);
		}

		callOnScripts('onEvent', [eventName, value1, value2]);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Error executing event ' + eventName + ': ' + e);
		}
		eventRecursionDepth--;
	}

	public function addCameraZoom(?camZoom:Float = 0.015, ?hudZoom:Float = 0.03):Void
	{
		if (reducedMovements) return;

		if (camGame != null && (camGame.zoom < (defaultCamZoom + 0.35) || camZoom < 0))
		{
			camGame.zoom += camZoom;
			if (camGame2 != null)
				camGame2.zoom = camGame.zoom;
		}

		if (camHUD != null)
		{
			camHUD.zoom += hudZoom;
			if (camAlt != null)
				camAlt.zoom = camHUD.zoom;
		}
	}

	public function playCharacterAnim(char:Character, animName:String, isLocked:Bool = false):Void
	{
		if (char == null || animName == null || animName.trim() == "") return;
		animName = animName.trim();

		// If user wants to return to idle without lock
		if (!isLocked && (animName.toLowerCase() == 'idle' || animName.toLowerCase() == 'dance'))
		{
			char.specialAnim = false;
			char.animLocked = false;
			char.dance(true);
			return;
		}

		// Find matching animation name (exact or case-insensitive)
		var resolvedAnim:String = animName;
		if (!char.hasAnimation(resolvedAnim))
		{
			for (a in char.getAnimList())
			{
				if (a.toLowerCase() == animName.toLowerCase())
				{
					resolvedAnim = a;
					break;
				}
			}
		}

		if (char.hasAnimation(resolvedAnim))
		{
			char.playAnim(resolvedAnim, true);
			char.specialAnim = true;
			char.animLocked = isLocked;

			if (!isLocked && char.animation != null && char.animation.curAnim != null && char.animation.curAnim.looped)
			{
				char.animation.curAnim.looped = false;
			}
		}
		else
		{
			FlxG.log.warn('Play Anim: Animation "$animName" not found on character ${char.curCharacter}');
		}
	}

	public function changeCharacter(type:Int, newCharacter:String, ?customX:Null<Float>, ?customY:Null<Float>):Void
	{
		if (newCharacter == null || newCharacter.trim() == '') return;
		newCharacter = newCharacter.trim();

		switch (type)
		{
			case 0: // Boyfriend
				if (boyfriend.curCharacter == newCharacter)
				{
					if (customX != null || customY != null)
					{
						var targetBaseX:Float = customX != null ? customX : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[0] : 770);
						var targetBaseY:Float = customY != null ? customY : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[1] : 100);
						boyfriend.x = targetBaseX + boyfriend.characterData.offsetX;
						boyfriend.y = boyfriend.adjustPos ? (targetBaseY + (boyfriend.characterData.offsetY - (boyfriend.frameHeight * boyfriend.scale.y))) : (targetBaseY + boyfriend.characterData.offsetY);
						if (stageBuild != null && stageBuild.stageData != null)
							stageBuild.stageData.BF_POS = [targetBaseX, targetBaseY];
					}
					return;
				}
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[0] : 770;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.BF_POS[1] : 100;
				if (customX != null) baseX = customX;
				if (customY != null) baseY = customY;
				if (stageBuild != null && stageBuild.stageData != null && (customX != null || customY != null))
					stageBuild.stageData.BF_POS = [baseX, baseY];

				boyfriend.setCharacter(baseX, baseY, newCharacter);
				boyfriend.dance();
				if (iconP1 != null)
					iconP1.changeIcon(boyfriend.healthIcon);
				var bfColor = FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]);
				updateColors(bfColor, currentColorP2);

			case 1: // Dad / Opponent
				if (dadOpponent.curCharacter == newCharacter)
				{
					if (customX != null || customY != null)
					{
						var targetBaseX:Float = customX != null ? customX : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[0] : 100);
						var targetBaseY:Float = customY != null ? customY : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[1] : 100);
						dadOpponent.x = targetBaseX + dadOpponent.characterData.offsetX;
						dadOpponent.y = dadOpponent.adjustPos ? (targetBaseY + (dadOpponent.characterData.offsetY - (dadOpponent.frameHeight * dadOpponent.scale.y))) : (targetBaseY + dadOpponent.characterData.offsetY);
						if (stageBuild != null && stageBuild.stageData != null)
							stageBuild.stageData.DAD_POS = [targetBaseX, targetBaseY];
					}
					return;
				}
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[0] : 100;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.DAD_POS[1] : 100;
				if (customX != null) baseX = customX;
				if (customY != null) baseY = customY;
				if (stageBuild != null && stageBuild.stageData != null && (customX != null || customY != null))
					stageBuild.stageData.DAD_POS = [baseX, baseY];

				dadOpponent.setCharacter(baseX, baseY, newCharacter);
				dadOpponent.dance();
				if (iconP2 != null)
					iconP2.changeIcon(dadOpponent.healthIcon);
				var dadColor = FlxColor.fromRGB(dadOpponent.healthColorArray[0], dadOpponent.healthColorArray[1], dadOpponent.healthColorArray[2]);
				updateColors(currentColorP1, dadColor);

			case 2: // GF
				if (gf.curCharacter == newCharacter)
				{
					if (customX != null || customY != null)
					{
						var targetBaseX:Float = customX != null ? customX : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[0] : 400);
						var targetBaseY:Float = customY != null ? customY : (stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[1] : 130);
						gf.x = targetBaseX + gf.characterData.offsetX;
						gf.y = gf.adjustPos ? (targetBaseY + (gf.characterData.offsetY - (gf.frameHeight * gf.scale.y))) : (targetBaseY + gf.characterData.offsetY);
						if (stageBuild != null && stageBuild.stageData != null)
							stageBuild.stageData.GF_POS = [targetBaseX, targetBaseY];
					}
					return;
				}
				var baseX:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[0] : 400;
				var baseY:Float = stageBuild != null && stageBuild.stageData != null ? stageBuild.stageData.GF_POS[1] : 130;
				if (customX != null) baseX = customX;
				if (customY != null) baseY = customY;
				if (stageBuild != null && stageBuild.stageData != null && (customX != null || customY != null))
					stageBuild.stageData.GF_POS = [baseX, baseY];

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

	public function startCountdown():Void
	{
		inCutscene = false;
		startedCountdown = true;
		canPause = true;
		startingSong = true;
		Countdown.performCountdown();
	}

	public function startSong():Void
	{
		startingSong = false;
		isInCountdown = false;
		Countdown.stopCountdown();
		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (!paused)
		{
			if (songMusic != null && songMusic.exists)
				songMusic.play(true);

			if (vocals != null && vocals.exists && vocals.length > 0)
				vocals.play(true);

			if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
				opponentVocals.play(true);

			Conductor.syncTo(0);

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

		if (isInCountdown)
			Countdown.pauseCountdown();

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
				if (opponentVocals != null)
					opponentVocals.pause();
			}
			if (camGame2 != null) camGame2.active = false;
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
				if (vocals != null && vocals.exists && vocals.length > 0)
				{
					vocals.time = songMusic.time;
					vocals.play();
				}
				if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
				{
					opponentVocals.time = songMusic.time;
					opponentVocals.play();
				}
				Conductor.syncTo(songMusic.time);
			}

			if (isInCountdown)
				Countdown.resumeCountdown();

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
			if (camGame2 != null) camGame2.active = true;
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
		if (camPosTween != null)
		{
			camPosTween.cancel();
			camPosTween = null;
		}

		// Clear active global managers
		FlxTween.globalManager.clear();
		FlxTimer.globalManager.clear();

		// Stop camera effects and reset active/visibility
		if (camGame2 != null)
		{
			camGame2.stopFX();
			camGame2.active = true;
			camGame2.visible = true;
		}
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

		if (vocals != null && vocals.exists && vocals.length > 0)
		{
			vocals.pause();
			vocals.time = 0;
		}
		if (opponentVocals != null && opponentVocals.exists && opponentVocals.length > 0)
		{
			opponentVocals.pause();
			opponentVocals.time = 0;
		}

		if (SONG.needsVoices && (vocals == null || opponentVocals == null))
		{
			loadSongVocals();
		}

		// 4. Reset Conductor & Timing variables
		Conductor.changeBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);
		Conductor.songPosition = -(Conductor.crochet * 5);
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
		if (camGame2 != null)
			camGame2.zoom = defaultCamZoom;
		camHUD.zoom = 1;
		camAlt.zoom = 1;
		forceZoom = [0, 0, 0, 0];

		if (camFollow != null && camPos != null)
			camFollow.setPosition(camPos.x, camPos.y);
		if (camFollowPos != null && camPos != null)
			camFollowPos.setPosition(camPos.x, camPos.y);

		camGame.focusOn(camFollow.getPosition());
		if (camGame2 != null)
			camGame2.focusOn(camFollow.getPosition());

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
		Utils.killMusic([songMusic, vocals, opponentVocals]);
		if (SONG.validScore)
			Highscore.saveScore(SONG.song, songScore, storyDifficulty, Timings.getAccuracy(), Timings.comboDisplay);

		deaths = 0;
		Utils.resetMenuMusic();

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		if (isStoryMode)
			Main.switchState(this, new MainMenuState());
		else
			Main.switchState(this, new FreeplayState());

		if (SONG.validScore && isStoryMode)
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
		Utils.killMusic([songMusic, vocals, opponentVocals]);

		FlxG.switchState(() -> new PlayState());
	}

	public static function resetMusic():Void
	{
		if (songMusic != null)
			songMusic.stop();

		if (vocals != null)
			vocals.stop();

		if (opponentVocals != null)
			opponentVocals.stop();
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

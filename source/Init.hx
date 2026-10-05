import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;
import funkin.states.MainMenuState;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import backend.CoolUtil;
import funkin.objects.Overlay;
import backend.Highscore;
import backend.Discord;

using StringTools;

/** 
	Enumerator for settingtypes
**/
enum SettingTypes
{
	Checkmark;
	Selector;
}

/**
	This is the initialisation class. if you ever want to set anything before the game starts or call anything then this is probably your best bet.
	A lot of this code is just going to be similar to the flixel templates' colorblind filters because I wanted to add support for those as I'll
	most likely need them for skater, and I think it'd be neat if more mods were more accessible.
**/
class Init extends FlxState
{
	/*
		Okay so here we'll set custom settings. As opposed to the previous options menu, everything will be handled in here with no hassle.
		This will read what the second value of the key's array is, and then it will categorise it, telling the game which option to set it to.

		0 - boolean, true or false checkmark
		1 - choose string
		2 - choose number (for fps so its low capped at 30)
		3 - offsets, this is unused but it'd bug me if it were set to 0
		might redo offset code since I didnt make it and it bugs me that it's hardcoded the the last part of the controls menu
	 */
	public static var FORCED = 'forced';
	public static var NOT_FORCED = 'not forced';

	public static var gameSettings:Map<String, Dynamic> = [
		'Downscroll' => [
			false,
			Checkmark,
			'Whether to have the strumline vertically flipped in gameplay.',
			NOT_FORCED
		],
		'Controller Mode' => [
			false,
			Checkmark,
			'Whether to use a controller instead of the keyboard to play.',
			NOT_FORCED
		],
		'Auto Pause' => [
			true,
			Checkmark,
			'Whether to pause the game automatically if the window is unfocused.',
			NOT_FORCED
		],
		'FPS Counter' => [true, Checkmark, 'Whether to display the FPS counter.', NOT_FORCED],
		'Memory Counter' => [
			true,
			Checkmark,
			'Whether to display approximately how much memory is being used.',
			NOT_FORCED
		],
		'Debug Info' => [
			false,
			Checkmark,
			'Whether to display information like your game state.',
			NOT_FORCED
		],

		'Display Accuracy' => [true, Checkmark, 'Whether to display your accuracy on screen.', NOT_FORCED],
		'Disable Antialiasing' => [
			false,
			Checkmark,
			'Whether to disable Anti-aliasing. Helps improve performance in FPS.',
			NOT_FORCED
		],
		'No Camera Note Movement' => [
			false,
			Checkmark,
			'When enabled, left and right notes no longer move the camera.',
			NOT_FORCED
		],
		'Disable Note Splashes' => [
			false,
			Checkmark,
			'Whether to disable note splashes in gameplay. Useful if you find them distracting.',
			NOT_FORCED
		],
		// custom ones lol
		'Offset' => [Checkmark, 3],
		"Clip Style" => [
			'stepmania',
			Selector,
			"Chooses a style for hold note clippings; StepMania: Holds under Receptors; FNF: Holds over receptors",
			NOT_FORCED,
			['StepMania', 'FNF']
		],
		"Framerate Cap" => [120, Selector, 'Define your maximum FPS.', NOT_FORCED, ['']],
		"Alpha Arrows" => [true, Checkmark, "Makes the arrows at the top of the screen have 100% alpha.", NOT_FORCED],
		"Alpha Holds" => [true, Checkmark, "Makes the sustain trails have 100% alpha.", NOT_FORCED],
		'Ghost Tapping' => [
			false,
			Checkmark,
			"Enables Ghost Tapping, allowing you to press inputs without missing.",
			NOT_FORCED
		],
		'Centered Notefield' => [false, Checkmark, "Center the notes, disables the enemy's notes."],
		"Custom Titlescreen" => [
			false,
			Checkmark,
			"Enables the custom Forever Engine titlescreen! (only effective with a restart)",
			FORCED
		],


	];

	public static var trueSettings:Map<String, Dynamic> = [];
	public static var settingsDescriptions:Map<String, String> = [];

	public static var gameControls:Map<String, Dynamic> = [
		'UP' => [[FlxKey.UP, W], 2],
		'DOWN' => [[FlxKey.DOWN, S], 1],
		'LEFT' => [[FlxKey.LEFT, A], 0],
		'RIGHT' => [[FlxKey.RIGHT, D], 3],
		'ACCEPT' => [[FlxKey.SPACE, Z, FlxKey.ENTER], 4],
		'BACK' => [[FlxKey.BACKSPACE, X, FlxKey.ESCAPE], 5],
		'PAUSE' => [[FlxKey.ENTER, P], 6],
		'RESET' => [[FlxKey.R, FlxKey.R], 13],
		'UI_UP' => [[FlxKey.UP, W], 8],
		'UI_DOWN' => [[FlxKey.DOWN, S], 9],
		'UI_LEFT' => [[FlxKey.LEFT, A], 10],
		'UI_RIGHT' => [[FlxKey.RIGHT, D], 11],
	];

	override public function create():Void
	{
		FlxG.save.bind('County-Funkin');
		Highscore.load();

		loadSettings();
		loadControls();

		#if !html5
		Main.updateFramerate(trueSettings.get("Framerate Cap"));
		#end

		// Some additional changes to default HaxeFlixel settings, both for ease of debugging and usability.
		FlxG.fixedTimestep = false; // This ensures that the game is not tied to the FPS
		FlxG.mouse.useSystemCursor = true; // Use system cursor because it's prettier
		FlxG.mouse.visible = false; // Hide mouse on start
		FlxGraphic.defaultPersist = true; // make sure we control all of the memory

		backend.FunkinMemory.initialCache();
		Main.switchState(this, new TitleState());
	}

	public static function loadSettings():Void
	{
		// set the true settings array
		// only the first variable will be saved! the rest are for the menu stuffs

		// IF YOU WANT TO SAVE MORE THAN ONE VALUE MAKE YOUR VALUE AN ARRAY INSTEAD
		for (setting in gameSettings.keys())
			trueSettings.set(setting, gameSettings.get(setting)[0]);

		// NEW SYSTEM, INSTEAD OF REPLACING THE WHOLE THING I REPLACE EXISTING KEYS
		// THAT WAY IT DOESNT HAVE TO BE DELETED IF THERE ARE SETTINGS CHANGES
		if (FlxG.save.data.settings != null)
		{
			var settingsMap:Map<String, Dynamic> = FlxG.save.data.settings;
			for (singularSetting in settingsMap.keys())
				if (gameSettings.get(singularSetting) != null && gameSettings.get(singularSetting)[3] != FORCED)
					trueSettings.set(singularSetting, FlxG.save.data.settings.get(singularSetting));
		}

		// lemme fix that for you
		if (!Std.isOfType(trueSettings.get("Framerate Cap"), Int)
			|| trueSettings.get("Framerate Cap") < 30
			|| trueSettings.get("Framerate Cap") > 360)
			trueSettings.set("Framerate Cap", 30);

		saveSettings();

		updateAll();

		if (FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;
	}

	public static function loadControls():Void
	{
		if ((FlxG.save.data.gameControls != null) && (Lambda.count(FlxG.save.data.gameControls) == Lambda.count(gameControls)))
			gameControls = FlxG.save.data.gameControls;

		saveControls();
	}

	public static function saveSettings():Void
	{
		// ez save lol
		FlxG.save.data.settings = trueSettings;
		FlxG.save.flush();

		updateAll();
	}

	public static function saveControls():Void
	{
		FlxG.save.data.gameControls = gameControls;
		FlxG.save.flush();
	}

	public static function updateAll()
	{
		FlxG.autoPause = trueSettings.get('Auto Pause');

		Overlay.updateDisplayInfo(trueSettings.get('FPS Counter'), trueSettings.get('Debug Info'), trueSettings.get('Memory Counter'));

		#if !html5
		Main.updateFramerate(trueSettings.get("Framerate Cap"));
		#end
	}
}








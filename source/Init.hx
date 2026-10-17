import backend.Highscore;
import funkin.objects.Overlay;
import funkin.states.TitleState;
import flixel.FlxG;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

/** 
 * Enumerator for setting types.
 */
enum SettingTypes
{
	Checkmark;
	Selector;
}

/**
 * Initialization class. Handles setting up saved preferences, controls, and 
 * fundamental engine configurations before the game actually starts.
 */
class Init extends FlxState
{
	public static var FORCED = 'forced';
	public static var NOT_FORCED = 'not forced';

	// Stores default values and metadata for all available game settings
	public static var gameSettings:Map<String, Dynamic> = [
		'Downscroll' => [false, Checkmark, 'Whether to have the strumline vertically flipped in gameplay.', NOT_FORCED],
		'Controller Mode' => [false, Checkmark, 'Whether to use a controller instead of the keyboard to play.', NOT_FORCED],
		'Auto Pause' => [true, Checkmark, 'Whether to pause the game automatically if the window is unfocused.', NOT_FORCED],
		'FPS Counter' => [true, Checkmark, 'Whether to display the FPS counter.', NOT_FORCED],
		'Memory Counter' => [true, Checkmark, 'Whether to display approximately how much memory is being used.', NOT_FORCED],
		'Debug Info' => [false, Checkmark, 'Whether to display information like your game state.', NOT_FORCED],
		'Disable Antialiasing' => [false, Checkmark, 'Whether to disable Anti-aliasing. Helps improve performance in FPS.', NOT_FORCED],
		'GPU Caching' => [true, Checkmark, 'Whether to store textures in GPU VRAM and discard CPU RAM (like Codename VRAM-Only). Greatly reduces memory usage.', NOT_FORCED],
		'No Camera Note Movement' => [false, Checkmark, 'When enabled, left and right notes no longer move the camera.', NOT_FORCED],
		'Disable Note Splashes' => [false, Checkmark, 'Whether to disable note splashes in gameplay. Useful if you find them distracting.', NOT_FORCED],
		'Offset' => [0.0, Selector, 'Audio offset in milliseconds. Adjusts note timing to sync with your audio display.', NOT_FORCED],
		"Clip Style" => ['StepMania', Selector, "Chooses a style for hold note clippings; StepMania: Holds under Receptors; FNF: Holds over receptors", NOT_FORCED, ['StepMania', 'FNF']],
		"Framerate Cap" => [120, Selector, 'Define your maximum FPS.', NOT_FORCED, ['']],
		"Alpha Arrows" => [true, Checkmark, "Makes the arrows at the top of the screen have 100% alpha.", NOT_FORCED],
		"Alpha Holds" => [true, Checkmark, "Makes the sustain trails have 100% alpha.", NOT_FORCED],
		'Ghost Tapping' => [false, Checkmark, "Enables Ghost Tapping, allowing you to press inputs without missing.", NOT_FORCED],
		'Centered Notefield' => [false, Checkmark, "Center the notes, disables the enemy's notes."]
	];

	public static var trueSettings:Map<String, Dynamic> = [];
	public static var settingsDescriptions:Map<String, String> = [];

	// Defines default keybinds
	public static var defaultControls:Map<String, Dynamic> = [
		'LEFT' => [[FlxKey.A, FlxKey.LEFT], 0],
		'DOWN' => [[FlxKey.S, FlxKey.DOWN], 1],
		'UP' => [[FlxKey.W, FlxKey.UP], 2],
		'RIGHT' => [[FlxKey.D, FlxKey.RIGHT], 3],
		'RESET' => [[FlxKey.R, FlxKey.NONE], 4],
		'UI_LEFT' => [[FlxKey.A, FlxKey.LEFT], 5],
		'UI_DOWN' => [[FlxKey.S, FlxKey.DOWN], 6],
		'UI_UP' => [[FlxKey.W, FlxKey.UP], 7],
		'UI_RIGHT' => [[FlxKey.D, FlxKey.RIGHT], 8],
		'ACCEPT' => [[FlxKey.SPACE, FlxKey.ENTER], 9],
		'BACK' => [[FlxKey.ESCAPE, FlxKey.BACKSPACE], 10],
		'PAUSE' => [[FlxKey.ENTER, FlxKey.P], 11],
	];

	public static var gameControls:Map<String, Dynamic> = [
		'LEFT' => [[FlxKey.A, FlxKey.LEFT], 0],
		'DOWN' => [[FlxKey.S, FlxKey.DOWN], 1],
		'UP' => [[FlxKey.W, FlxKey.UP], 2],
		'RIGHT' => [[FlxKey.D, FlxKey.RIGHT], 3],
		'RESET' => [[FlxKey.R, FlxKey.NONE], 4],
		'UI_LEFT' => [[FlxKey.A, FlxKey.LEFT], 5],
		'UI_DOWN' => [[FlxKey.S, FlxKey.DOWN], 6],
		'UI_UP' => [[FlxKey.W, FlxKey.UP], 7],
		'UI_RIGHT' => [[FlxKey.D, FlxKey.RIGHT], 8],
		'ACCEPT' => [[FlxKey.SPACE, FlxKey.ENTER], 9],
		'BACK' => [[FlxKey.ESCAPE, FlxKey.BACKSPACE], 10],
		'PAUSE' => [[FlxKey.ENTER, FlxKey.P], 11],
	];

	override public function create():Void
	{
		FlxG.save.bind('funkin', 'ninjamuffin99');
		backend.Mods.loadModDirectory();
		Highscore.load();

		loadSettings();
		loadControls();

		#if !html5
		Main.updateFramerate(trueSettings.get("Framerate Cap"));
		#end

		// Additional configuration for default HaxeFlixel settings
		FlxG.fixedTimestep = false; // Decouples game logic from FPS
		FlxG.mouse.visible = false; // Hide mouse on startup
		FlxGraphic.defaultPersist = true; // Manually handle memory for graphics

		backend.FunkinMemory.initialCache();
		Main.switchState(this, new TitleState());
	}

	/**
	 * Loads settings from the save file or initializes defaults.
	 */
	public static function loadSettings():Void
	{
		// Populate trueSettings with default values
		for (setting in gameSettings.keys())
			trueSettings.set(setting, gameSettings.get(setting)[0]);

		// Override defaults with saved settings if they exist and are not forced
		if (FlxG.save.data.settings != null)
		{
			var settingsMap:Map<String, Dynamic> = FlxG.save.data.settings;
			for (singularSetting in settingsMap.keys())
			{
				if (gameSettings.exists(singularSetting) && gameSettings.get(singularSetting)[3] != FORCED)
					trueSettings.set(singularSetting, settingsMap.get(singularSetting));
			}
		}

		// Ensure framerate cap is valid
		var framerateCap:Dynamic = trueSettings.get("Framerate Cap");
		var capInt:Int = 120;
		if (framerateCap != null)
			capInt = Std.int(framerateCap);

		if (capInt < 30 || capInt > 360)
			capInt = 120;
		
		trueSettings.set("Framerate Cap", capInt);

		saveSettings();
		updateAll();

		if (FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;
	}

	/**
	 * Loads custom controls if they exist.
	 */
	public static function loadControls():Void
	{
		if (FlxG.save.data.gameControls != null)
		{
			try
			{
				var saved:Map<String, Dynamic> = FlxG.save.data.gameControls;
				for (key in gameControls.keys())
				{
					if (saved.exists(key) && saved.get(key) != null && saved.get(key)[0] != null)
					{
						var savedArr:Array<Dynamic> = saved.get(key)[0];
						if (savedArr.length > 0)
						{
							var newArr:Array<FlxKey> = [];
							for (item in savedArr)
							{
								if (item != null)
									newArr.push(cast item);
							}
							if (newArr.length > 0)
								gameControls.get(key)[0] = newArr;
						}
					}
				}
			}
			catch (e:Dynamic)
			{
				trace('Error loading controls: $e');
			}
		}

		saveControls();
	}

	public static function resetControls():Void
	{
		for (key in defaultControls.keys())
		{
			var defArr:Array<Dynamic> = defaultControls.get(key)[0];
			gameControls.set(key, [[defArr[0], defArr[1]], defaultControls.get(key)[1]]);
		}
		saveControls();
	}

	/**
	 * Saves the current settings to disk.
	 */
	public static function saveSettings():Void
	{
		FlxG.save.data.settings = trueSettings;
		FlxG.save.flush();
		updateAll();
	}

	/**
	 * Saves the current control scheme to disk.
	 */
	public static function saveControls():Void
	{
		FlxG.save.data.gameControls = gameControls;
		FlxG.save.flush();
	}

	/**
	 * Applies updated settings across the engine.
	 */
	public static function updateAll()
	{
		FlxG.autoPause = trueSettings.get('Auto Pause');
		Overlay.updateDisplayInfo(trueSettings.get('FPS Counter'), trueSettings.get('Debug Info'), trueSettings.get('Memory Counter'));

		#if !html5
		Main.updateFramerate(trueSettings.get("Framerate Cap"));
		#end
	}
}

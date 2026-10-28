package menus;
import core.system.Paths;
import core.utils.Utils;
import core.base.Init;
import menus.OptionsSubstate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

enum OptionType
{
	CHECKMARK;
	SELECTOR(options:Array<String>);
	NUMBER(min:Float, max:Float, step:Float, suffix:String);
	CATEGORY;
	ACTION;
}

typedef OptionEntry =
{
	var id:String;
	var name:String;
	var description:String;
	var type:OptionType;
	@:optional var action:Void->Void;
}

/**
 * Modernized OptionsMenuState built completely from scratch.
 * Features a strictly straight-column layout, smooth vertical scrolling,
 * hold-to-scroll support, organized categories, and instant live settings updates.
 */
class OptionsMenuState extends MusicBeatState
{
	public static var instance:OptionsMenuState;

	var bg:FlxSprite;
	var headerBar:FlxSprite;
	var titleText:FlxText;
	var breadcrumbText:FlxText;

	var bottomBar:FlxSprite;
	var descText:FlxText;
	var helpText:FlxText;

	public static var categorySelections:Map<String, Int> = new Map<String, Int>();
	public static var lastCategory:String = "main";

	var currentCategory:String = "main";
	var categoryHistory:Array<String> = [];

	var categories:Map<String, Array<OptionEntry>> = [];
	var currentOptions:Array<OptionEntry> = [];
	var curSelection:Int = 0;

	var grpOptionTexts:FlxTypedGroup<FlxText>;
	var grpValueTexts:FlxTypedGroup<FlxText>;
	var selectorCursor:FlxText;

	// Hold-to-scroll timers
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var holdLeftTime:Float = 0;
	var holdRightTime:Float = 0;

	// Framerate cap presets
	static final FPS_PRESETS:Array<Int> = [30, 60, 75, 90, 120, 144, 165, 180, 240, 300, 360];

	override public function create():Void
	{
		super.create();

		instance = this;

		#if desktop
		Discord.changePresence('OPTIONS MENU', 'Main Menu');
		#end

		// Background with subtle navy tint
		bg = new FlxSprite().loadGraphic(Paths.image('menus/menuDesat'));
		bg.color = 0xFF0D1B36;
		bg.setGraphicSize(Std.int(FlxG.width * 1.1), Std.int(FlxG.height * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		var darkOverlay:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		darkOverlay.scrollFactor.set();
		add(darkOverlay);

		// Groups for straight column elements
		grpOptionTexts = new FlxTypedGroup<FlxText>();
		grpValueTexts = new FlxTypedGroup<FlxText>();

		add(grpOptionTexts);
		add(grpValueTexts);

		// Selector cursor
		selectorCursor = new FlxText(80, 0, 0, ">", 26);
		selectorCursor.setFormat(Paths.font("vcr.ttf"), 26, 0xFFFFD700, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectorCursor.borderSize = 2;
		add(selectorCursor);

		// Top Header
		headerBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 70, 0xEE080D1A);
		headerBar.scrollFactor.set();
		add(headerBar);

		titleText = new FlxText(40, 12, 0, "OPTIONS", 28);
		titleText.setFormat(Paths.font("vcr.ttf"), 28, 0xFF35A7FF, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.scrollFactor.set();
		add(titleText);

		breadcrumbText = new FlxText(200, 18, 0, "", 20);
		breadcrumbText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFAAAAAA, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		breadcrumbText.borderSize = 2;
		breadcrumbText.scrollFactor.set();
		add(breadcrumbText);

		// Bottom Description & Help Bar
		bottomBar = new FlxSprite(0, FlxG.height - 65).makeGraphic(FlxG.width, 65, 0xEE080D1A);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		descText = new FlxText(40, FlxG.height - 58, FlxG.width - 80, "", 18);
		descText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.borderSize = 1.5;
		descText.scrollFactor.set();
		add(descText);

		helpText = new FlxText(40, FlxG.height - 30, FlxG.width - 80, "[UP/DOWN] Navigate   •   [ENTER/LEFT/RIGHT] Change   •   [ESC] Back", 15);
		helpText.setFormat(Paths.font("vcr.ttf"), 15, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		helpText.borderSize = 1.5;
		helpText.scrollFactor.set();
		add(helpText);

		initOptionsData();
		loadCategory("main");
	}

	function initOptionsData():Void
	{
		categories = new Map<String, Array<OptionEntry>>();

		// Main categories list
		categories.set("main", [
			{id: "gameplay", name: "GAMEPLAY", description: "Configure gameplay mechanics, downscroll, offsets, and input preferences.", type: CATEGORY},
			{id: "appearance", name: "APPEARANCE", description: "Customize visuals, hold trail clipping, and receptor arrow opacity.", type: CATEGORY},
			{id: "graphics", name: "GRAPHICS & DISPLAY", description: "Adjust performance, framerate limits, antialiasing, and GPU memory caching.", type: CATEGORY},
			{id: "preferences", name: "PREFERENCES", description: "System options such as automatic pausing when unfocused.", type: CATEGORY},
			{id: "controls", name: "CONTROLS", description: "Customize and rebind your keyboard keys and shortcuts.", type: ACTION, action: openControlsMenu},
			{id: "exit", name: "EXIT TO MAIN MENU", description: "Save all settings and return to the main menu.", type: ACTION, action: exitMenu}
		]);

		// Gameplay settings
		categories.set("gameplay", [
			{id: "Downscroll", name: "DOWNSCROLL", description: "Flips the strumline vertically so notes scroll downwards instead of upwards.", type: CHECKMARK},
			{id: "Centered Notefield", name: "CENTERED NOTEFIELD", description: "Centers your notes in the middle of the screen and hides opponent arrows.", type: CHECKMARK},
			{id: "Ghost Tapping", name: "GHOST TAPPING", description: "Allows pressing keys when no notes are on screen without receiving miss penalties.", type: CHECKMARK},
			{id: "Controller Mode", name: "CONTROLLER MODE", description: "Enables gamepad controller button inputs for playing charts.", type: CHECKMARK},
			{id: "Disable Note Splashes", name: "DISABLE NOTE SPLASHES", description: "Hides particle splash effects when hitting Sick! ratings.", type: CHECKMARK},
			{id: "No Camera Note Movement", name: "STATIC CAMERA", description: "Disables camera bumping towards note hit directions during gameplay.", type: CHECKMARK},
			{id: "Offset", name: "AUDIO OFFSET", description: "Song audio offset in milliseconds. Adjusts timing to sync with your audio display.", type: NUMBER(-500, 500, 1, "ms")}
		]);

		// Appearance settings
		categories.set("appearance", [
			{id: "Alpha Arrows", name: "RECEPTOR ARROWS ALPHA", description: "Ensures the receptor arrows at the top/bottom are at 100% full opacity.", type: CHECKMARK},
			{id: "Alpha Holds", name: "HOLD TRAILS ALPHA", description: "Ensures sustain trails are rendered at 100% full opacity.", type: CHECKMARK},
			{id: "Clip Style", name: "HOLD CLIP STYLE", description: "Chooses hold note clipping style: above (in front of receptors) or back (behind receptors).", type: SELECTOR(["above", "back"])}
		]);

		// Graphics & Display settings
		categories.set("graphics", [
			{id: "GPU Caching", name: "GPU TEXTURE CACHING", description: "Uploads textures directly to GPU VRAM and discards CPU RAM copies, greatly reducing memory usage.", type: CHECKMARK},
			{id: "Disable Antialiasing", name: "DISABLE ANTIALIASING", description: "Disables texture smoothing for a crisp retro pixel aesthetic and higher FPS.", type: CHECKMARK},
			{id: "FPS Counter", name: "FPS COUNTER", description: "Displays real-time frame rate in the top-left corner.", type: CHECKMARK},
			{id: "Memory Counter", name: "MEMORY COUNTER", description: "Displays approximately how much RAM is being used by the game.", type: CHECKMARK},
			{id: "Debug Info", name: "DEBUG OVERLAY", description: "Shows active state name, conductor position, and engine debug information.", type: CHECKMARK},
			{id: "Framerate Cap", name: "FRAMERATE CAP", description: "Defines the maximum framerate cap for the game renderer.", type: SELECTOR(FPS_PRESETS.map(Std.string))}
		]);

		// System / Preferences
		categories.set("preferences", [
			{id: "Auto Pause", name: "AUTO PAUSE", description: "Automatically pauses the game when the window loses focus.", type: CHECKMARK}
		]);
	}

	function loadCategory(catId:String, fromBack:Bool = false):Void
	{
		if (!categories.exists(catId)) return;

		if (!fromBack && currentCategory != catId)
			categoryHistory.push(currentCategory);

		currentCategory = catId;
		lastCategory = catId;
		currentOptions = categories.get(catId);

		// Restore remembered selection for this category, or default to 0
		if (categorySelections.exists(catId))
		{
			curSelection = categorySelections.get(catId);
			if (curSelection < 0 || curSelection >= currentOptions.length)
				curSelection = 0;
		}
		else
		{
			curSelection = 0;
		}

		// Update Breadcrumbs
		if (catId == "main")
		{
			titleText.text = "OPTIONS";
			breadcrumbText.text = "";
		}
		else
		{
			titleText.text = "OPTIONS";
			var catTitle = catId.toUpperCase();
			for (item in categories.get("main"))
			{
				if (item.id == catId)
				{
					catTitle = item.name;
					break;
				}
			}
			breadcrumbText.text = " >  " + catTitle;
		}

		rebuildOptionDisplays();
		updateSelection(0, false);
	}

	function rebuildOptionDisplays():Void
	{
		// Clean up existing elements
		while (grpOptionTexts.members.length > 0)
			grpOptionTexts.remove(grpOptionTexts.members[0], true).destroy();

		while (grpValueTexts.members.length > 0)
			grpValueTexts.remove(grpValueTexts.members[0], true).destroy();

		for (i in 0...currentOptions.length)
		{
			var opt = currentOptions[i];
			var initialY = (FlxG.height * 0.46) + ((i - curSelection) * 58.0);

			// Option Name Text (Strictly straight column at fixed X = 120)
			var optTxt:FlxText = new FlxText(120, initialY, 680, opt.name, 24);
			optTxt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			optTxt.borderSize = 2;
			grpOptionTexts.add(optTxt);

			// Value Text (Straight column at fixed X = 860)
			var valTxt:FlxText = new FlxText(860, initialY, 360, "", 24);
			valTxt.setFormat(Paths.font("vcr.ttf"), 24, 0xFF35A7FF, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			valTxt.borderSize = 2;
			grpValueTexts.add(valTxt);
		}

		refreshOptionValues();
	}

	function refreshOptionValues():Void
	{
		for (i in 0...currentOptions.length)
		{
			var opt = currentOptions[i];
			var valTxt = grpValueTexts.members[i];

			switch (opt.type)
			{
				case CHECKMARK:
					var isChecked:Bool = Init.trueSettings.get(opt.id) == true;
					valTxt.text = isChecked ? "[ X ]" : "[   ]";
					valTxt.color = isChecked ? 0xFF00FF66 : 0xFF777777;

				case SELECTOR(options):
					var currentVal = Std.string(Init.trueSettings.get(opt.id));
					valTxt.text = "<  " + currentVal + "  >";
					valTxt.color = 0xFFFFD700;

				case NUMBER(min, max, step, suffix):
					var currentNum:Float = Std.parseFloat(Std.string(Init.trueSettings.get(opt.id)));
					if (Math.isNaN(currentNum)) currentNum = 0.0;
					valTxt.text = "<  " + (Math.round(currentNum * 10) / 10) + " " + suffix + "  >";
					valTxt.color = 0xFFFFD700;

				case CATEGORY:
					valTxt.text = ">";
					valTxt.color = 0xFF35A7FF;

				case ACTION:
					valTxt.text = "[ ENTER ]";
					valTxt.color = 0xFF888888;
			}
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Vertical Navigation with Hold Repeat
		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var up = controls.UI_UP;
		var down = controls.UI_DOWN;

		if (upP)
		{
			updateSelection(-1);
			holdUpTime = 0;
		}
		else if (up)
		{
			holdUpTime += elapsed;
			if (holdUpTime > 0.35)
			{
				updateSelection(-1);
				holdUpTime = 0.28;
			}
		}
		else
		{
			holdUpTime = 0;
		}

		if (downP)
		{
			updateSelection(1);
			holdDownTime = 0;
		}
		else if (down)
		{
			holdDownTime += elapsed;
			if (holdDownTime > 0.35)
			{
				updateSelection(1);
				holdDownTime = 0.28;
			}
		}
		else
		{
			holdDownTime = 0;
		}

		// Horizontal Adjustment for Selectors & Numbers
		var leftP = controls.UI_LEFT_P;
		var rightP = controls.UI_RIGHT_P;
		var left = controls.UI_LEFT;
		var right = controls.UI_RIGHT;

		if (leftP)
		{
			adjustValue(-1);
			holdLeftTime = 0;
		}
		else if (left)
		{
			holdLeftTime += elapsed;
			if (holdLeftTime > 0.35)
			{
				var mult = (holdLeftTime > 1.5) ? 5 : 1;
				adjustValue(-1 * mult);
				holdLeftTime = 0.28;
			}
		}
		else
		{
			holdLeftTime = 0;
		}

		if (rightP)
		{
			adjustValue(1);
			holdRightTime = 0;
		}
		else if (right)
		{
			holdRightTime += elapsed;
			if (holdRightTime > 0.35)
			{
				var mult = (holdRightTime > 1.5) ? 5 : 1;
				adjustValue(1 * mult);
				holdRightTime = 0.28;
			}
		}
		else
		{
			holdRightTime = 0;
		}

		// Accept / Action Trigger
		if (controls.ACCEPT)
		{
			handleAccept();
		}
		else if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
		{
			handleBack();
		}

		// Smooth vertical scrolling keeping X perfectly straight
		updatePositions(elapsed);
	}

	function updateSelection(change:Int = 0, playSound:Bool = true):Void
	{
		if (change != 0 && playSound)
			FlxG.sound.play(Paths.sound('system/scroll'));

		curSelection += change;

		if (curSelection < 0)
			curSelection = currentOptions.length - 1;
		else if (curSelection >= currentOptions.length)
			curSelection = 0;

		categorySelections.set(currentCategory, curSelection);

		// Update description bar
		if (curSelection >= 0 && curSelection < currentOptions.length)
			descText.text = currentOptions[curSelection].description;
		else
			descText.text = "";

		// Update alphas & colors
		for (i in 0...currentOptions.length)
		{
			var isCurrent = (i == curSelection);
			var targetAlpha = isCurrent ? 1.0 : 0.45;

			grpOptionTexts.members[i].alpha = targetAlpha;
			grpValueTexts.members[i].alpha = targetAlpha;

			grpOptionTexts.members[i].color = isCurrent ? 0xFF35A7FF : FlxColor.WHITE;
		}
	}

	function updatePositions(elapsed:Float):Void
	{
		var centerY = FlxG.height * 0.46;
		var spacing = 58.0;

		for (i in 0...currentOptions.length)
		{
			var targetY = centerY + ((i - curSelection) * spacing);

			var optTxt = grpOptionTexts.members[i];
			var valTxt = grpValueTexts.members[i];

			// Smooth Y lerp
			optTxt.y = FlxMath.lerp(optTxt.y, targetY, Math.min(1.0, elapsed * 14));
			valTxt.y = optTxt.y;

			// Strictly straight column at fixed X
			optTxt.x = 120;
			valTxt.x = 860;

			if (i == curSelection)
			{
				selectorCursor.y = optTxt.y - 2;
				selectorCursor.x = 80;
			}
		}
	}

	function handleAccept():Void
	{
		if (curSelection < 0 || curSelection >= currentOptions.length) return;

		var opt = currentOptions[curSelection];

		switch (opt.type)
		{
			case CHECKMARK:
				var currentVal:Bool = Init.trueSettings.get(opt.id) == true;
				var newVal:Bool = !currentVal;
				Init.trueSettings.set(opt.id, newVal);
				Init.saveSettings();
				Init.updateAll();

				refreshOptionValues();
				FlxG.sound.play(Paths.sound('system/confirm'));

			case CATEGORY:
				FlxG.sound.play(Paths.sound('system/confirm'));
				loadCategory(opt.id);

			case ACTION:
				if (opt.action != null)
					opt.action();

			case SELECTOR(_), NUMBER(_, _, _, _):
				adjustValue(1);
		}
	}

	function adjustValue(change:Int):Void
	{
		if (curSelection < 0 || curSelection >= currentOptions.length) return;

		var opt = currentOptions[curSelection];

		switch (opt.type)
		{
			case CHECKMARK:
				handleAccept();

			case SELECTOR(options):
				if (options.length == 0) return;

				var currentVal = Std.string(Init.trueSettings.get(opt.id));
				var currentIdx = options.indexOf(currentVal);
				if (currentIdx == -1) currentIdx = 0;

				var newIdx = currentIdx + change;
				if (newIdx < 0) newIdx = options.length - 1;
				else if (newIdx >= options.length) newIdx = 0;

				var chosenString = options[newIdx];

				if (opt.id == "Framerate Cap")
				{
					var parsedInt = Std.parseInt(chosenString);
					Init.trueSettings.set(opt.id, parsedInt != null ? parsedInt : 120);
					#if !html5
					Main.updateFramerate(Init.trueSettings.get("Framerate Cap"));
					#end
				}
				else
				{
					Init.trueSettings.set(opt.id, chosenString);
				}

				Init.saveSettings();
				Init.updateAll();
				refreshOptionValues();
				FlxG.sound.play(Paths.sound('system/scroll'));

			case NUMBER(min, max, step, _):
				var currentNum:Float = Std.parseFloat(Std.string(Init.trueSettings.get(opt.id)));
				if (Math.isNaN(currentNum)) currentNum = 0.0;

				currentNum += change * step;
				if (currentNum < min) currentNum = min;
				if (currentNum > max) currentNum = max;

				Init.trueSettings.set(opt.id, currentNum);
				Init.saveSettings();
				Init.updateAll();
				refreshOptionValues();
				FlxG.sound.play(Paths.sound('system/scroll'));

			default:
				// No adjustment
		}
	}

	function handleBack():Void
	{
		FlxG.sound.play(Paths.sound('system/cancel'));

		if (currentCategory != "main")
		{
			var prev = (categoryHistory.length > 0) ? categoryHistory.pop() : "main";
			loadCategory(prev != null ? prev : "main", true);
		}
		else
		{
			exitMenu();
		}
	}

	function openControlsMenu():Void
	{
		FlxG.sound.play(Paths.sound('system/confirm'));
		openSubState(new OptionsSubstate());
	}

	function exitMenu():Void
	{
		Init.saveSettings();
		Main.switchState(this, new MainMenuState());
	}
}

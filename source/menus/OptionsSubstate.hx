package menus;
import core.system.Paths;
import core.base.Init;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import core.base.MusicBeatSubState;

using StringTools;

typedef ControlItem =
{
	var id:String;
	var name:String;
	var isHeader:Bool;
	var isAction:Bool;
}

/**
 * Modernized Controls remapping substate.
 * Features clean vertical straight-column layout, primary and secondary slots,
 * duplicate handling, clear/unbind support, and restore defaults.
 */
class OptionsSubstate extends MusicBeatSubState
{
	var bg:FlxSprite;
	var headerBar:FlxSprite;
	var titleText:FlxText;
	var colHeaderAction:FlxText;
	var colHeaderKey1:FlxText;
	var colHeaderKey2:FlxText;

	var items:Array<ControlItem> = [];
	public static var curSelection:Int = 1;
	public static var curSlot:Int = 0; // 0 = Primary, 1 = Secondary

	var grpActionTexts:FlxTypedGroup<FlxText>;
	var grpKey1Texts:FlxTypedGroup<FlxText>;
	var grpKey2Texts:FlxTypedGroup<FlxText>;
	var selectorBox:FlxSprite;

	var bottomBar:FlxSprite;
	var infoText:FlxText;

	// Rebinding state
	var isRebinding:Bool = false;
	var rebindOverlay:FlxSprite;
	var rebindBox:FlxSprite;
	var rebindTitle:FlxText;
	var rebindSlot:FlxText;
	var rebindPrompt:FlxText;
	var rebindHelp:FlxText;

	// Repeat scroll timers
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;

	override public function create():Void
	{
		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD0060912);
		bg.scrollFactor.set();
		add(bg);

		// Top Header
		headerBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 70, 0xEE0B0E17);
		headerBar.scrollFactor.set();
		add(headerBar);

		titleText = new FlxText(40, 14, 0, "CONTROLS REBINDING", 28);
		titleText.setFormat(Paths.font("vcr.ttf"), 28, 0xFF35A7FF, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.scrollFactor.set();
		add(titleText);

		// Column headers
		colHeaderAction = new FlxText(120, 78, 0, "ACTION", 18);
		colHeaderAction.setFormat(Paths.font("vcr.ttf"), 18, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		colHeaderAction.scrollFactor.set();
		add(colHeaderAction);

		colHeaderKey1 = new FlxText(580, 78, 0, "PRIMARY KEY", 18);
		colHeaderKey1.setFormat(Paths.font("vcr.ttf"), 18, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		colHeaderKey1.scrollFactor.set();
		add(colHeaderKey1);

		colHeaderKey2 = new FlxText(880, 78, 0, "SECONDARY KEY", 18);
		colHeaderKey2.setFormat(Paths.font("vcr.ttf"), 18, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		colHeaderKey2.scrollFactor.set();
		add(colHeaderKey2);

		// Selection cursor box
		selectorBox = new FlxSprite(0, 0).makeGraphic(240, 42, 0x3335A7FF);
		selectorBox.visible = false;
		add(selectorBox);

		// Groups for straight column elements
		grpActionTexts = new FlxTypedGroup<FlxText>();
		grpKey1Texts = new FlxTypedGroup<FlxText>();
		grpKey2Texts = new FlxTypedGroup<FlxText>();

		add(grpActionTexts);
		add(grpKey1Texts);
		add(grpKey2Texts);

		// Populate control items
		initControlList();
		createItemDisplays();

		// Bottom info bar
		bottomBar = new FlxSprite(0, FlxG.height - 40).makeGraphic(FlxG.width, 40, 0xEE0B0E17);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		infoText = new FlxText(0, FlxG.height - 32, FlxG.width, "[ARROWS] Navigate  •  [ENTER] Rebind  •  [BACKSPACE] Clear Key  •  [ESC] Exit & Save", 16);
		infoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.scrollFactor.set();
		add(infoText);

		// Rebinding overlay
		createRebindOverlay();

		// Initial selection (first non-header item)
		if (curSelection < 0 || curSelection >= items.length)
			curSelection = 1;

		while (items[curSelection] != null && items[curSelection].isHeader)
		{
			curSelection++;
			if (curSelection >= items.length)
				curSelection = 1;
		}

		updateSelection(0, false);
	}

	function initControlList():Void
	{
		items = [];

		// Gameplay notes section
		items.push({id: "hdr_gameplay", name: "--- GAMEPLAY NOTES ---", isHeader: true, isAction: false});
		items.push({id: "LEFT", name: "NOTE LEFT", isHeader: false, isAction: false});
		items.push({id: "DOWN", name: "NOTE DOWN", isHeader: false, isAction: false});
		items.push({id: "UP", name: "NOTE UP", isHeader: false, isAction: false});
		items.push({id: "RIGHT", name: "NOTE RIGHT", isHeader: false, isAction: false});
		items.push({id: "RESET", name: "QUICK RESET", isHeader: false, isAction: false});

		// UI / Menu section
		items.push({id: "hdr_ui", name: "--- MENU NAVIGATION ---", isHeader: true, isAction: false});
		items.push({id: "UI_LEFT", name: "UI LEFT", isHeader: false, isAction: false});
		items.push({id: "UI_DOWN", name: "UI DOWN", isHeader: false, isAction: false});
		items.push({id: "UI_UP", name: "UI UP", isHeader: false, isAction: false});
		items.push({id: "UI_RIGHT", name: "UI RIGHT", isHeader: false, isAction: false});
		items.push({id: "ACCEPT", name: "ACCEPT / SELECT", isHeader: false, isAction: false});
		items.push({id: "BACK", name: "BACK / CANCEL", isHeader: false, isAction: false});
		items.push({id: "PAUSE", name: "PAUSE GAME", isHeader: false, isAction: false});

		// Reset action
		items.push({id: "hdr_actions", name: "--- PRESETS ---", isHeader: true, isAction: false});
		items.push({id: "RESET_DEFAULTS", name: "RESTORE DEFAULT CONTROLS", isHeader: false, isAction: true});
	}

	function createItemDisplays():Void
	{
		for (i in 0...items.length)
		{
			var item = items[i];

			// Action column (x = 120)
			var actionTxt:FlxText = new FlxText(120, 0, 420, item.name, item.isHeader ? 20 : 22);
			actionTxt.setFormat(Paths.font("vcr.ttf"), item.isHeader ? 20 : 22, item.isHeader ? 0xFFFFD700 : FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			actionTxt.borderSize = 2;
			grpActionTexts.add(actionTxt);

			// Key 1 column (x = 580)
			var k1Txt:FlxText = new FlxText(580, 0, 260, "", 22);
			k1Txt.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			k1Txt.borderSize = 2;
			grpKey1Texts.add(k1Txt);

			// Key 2 column (x = 880)
			var k2Txt:FlxText = new FlxText(880, 0, 260, "", 22);
			k2Txt.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			k2Txt.borderSize = 2;
			grpKey2Texts.add(k2Txt);
		}

		refreshKeyLabels();
	}

	function refreshKeyLabels():Void
	{
		for (i in 0...items.length)
		{
			var item = items[i];
			var k1Txt = grpKey1Texts.members[i];
			var k2Txt = grpKey2Texts.members[i];

			if (item.isHeader)
			{
				k1Txt.text = "";
				k2Txt.text = "";
			}
			else if (item.isAction)
			{
				k1Txt.text = "[ PRESS ENTER ]";
				k2Txt.text = "";
			}
			else
			{
				if (Init.gameControls.exists(item.id))
				{
					var keysArr:Array<Dynamic> = Init.gameControls.get(item.id)[0];
					var key1:FlxKey = (keysArr != null && keysArr.length > 0 && keysArr[0] != null) ? keysArr[0] : FlxKey.NONE;
					var key2:FlxKey = (keysArr != null && keysArr.length > 1 && keysArr[1] != null) ? keysArr[1] : FlxKey.NONE;

					k1Txt.text = "[ " + formatKey(key1) + " ]";
					k2Txt.text = "[ " + formatKey(key2) + " ]";
				}
				else
				{
					k1Txt.text = "[ --- ]";
					k2Txt.text = "[ --- ]";
				}
			}
		}
	}

	function formatKey(key:FlxKey):String
	{
		if (key == FlxKey.NONE || (cast key : Int) == -1)
			return "---";

		var str:String = key.toString();
		switch (str.toUpperCase())
		{
			case "ESCAPE": return "ESC";
			case "BACKSPACE": return "BKSP";
			case "CONTROL": return "CTRL";
			case "DELETE": return "DEL";
			case "ZERO": return "0";
			case "ONE": return "1";
			case "TWO": return "2";
			case "THREE": return "3";
			case "FOUR": return "4";
			case "FIVE": return "5";
			case "SIX": return "6";
			case "SEVEN": return "7";
			case "EIGHT": return "8";
			case "NINE": return "9";
			case "PAGEUP": return "PGUP";
			case "PAGEDOWN": return "PGDN";
			default: return str.toUpperCase();
		}
	}

	function createRebindOverlay():Void
	{
		rebindOverlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xCC000000);
		rebindOverlay.scrollFactor.set();
		rebindOverlay.visible = false;
		add(rebindOverlay);

		rebindBox = new FlxSprite(0, 0).makeGraphic(680, 260, 0xEE121824);
		rebindBox.screenCenter();
		rebindBox.scrollFactor.set();
		rebindBox.visible = false;
		add(rebindBox);

		rebindTitle = new FlxText(0, rebindBox.y + 25, FlxG.width, "REBINDING ACTION", 26);
		rebindTitle.setFormat(Paths.font("vcr.ttf"), 26, 0xFFFFD700, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rebindTitle.borderSize = 2;
		rebindTitle.scrollFactor.set();
		rebindTitle.visible = false;
		add(rebindTitle);

		rebindSlot = new FlxText(0, rebindBox.y + 70, FlxG.width, "SLOT: PRIMARY", 20);
		rebindSlot.setFormat(Paths.font("vcr.ttf"), 20, 0xFF35A7FF, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rebindSlot.borderSize = 2;
		rebindSlot.scrollFactor.set();
		rebindSlot.visible = false;
		add(rebindSlot);

		rebindPrompt = new FlxText(0, rebindBox.y + 120, FlxG.width, "Press any key to bind...", 24);
		rebindPrompt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rebindPrompt.borderSize = 2;
		rebindPrompt.scrollFactor.set();
		rebindPrompt.visible = false;
		add(rebindPrompt);

		rebindHelp = new FlxText(0, rebindBox.y + 185, FlxG.width, "[BACKSPACE] Clear Slot   •   [ESCAPE] Cancel", 18);
		rebindHelp.setFormat(Paths.font("vcr.ttf"), 18, 0xFFAAAAAA, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rebindHelp.borderSize = 2;
		rebindHelp.scrollFactor.set();
		rebindHelp.visible = false;
		add(rebindHelp);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isRebinding)
		{
			updateRebinding();
			return;
		}

		// Vertical navigation with hold repeat
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

		// Horizontal navigation between Key 1 and Key 2 slots
		if (controls.UI_LEFT_P && curSlot > 0 && !items[curSelection].isAction)
		{
			curSlot = 0;
			FlxG.sound.play(Paths.sound('system/scroll'));
			updateSlotHighlight();
		}
		else if (controls.UI_RIGHT_P && curSlot < 1 && !items[curSelection].isAction)
		{
			curSlot = 1;
			FlxG.sound.play(Paths.sound('system/scroll'));
			updateSlotHighlight();
		}

		// Direct clearing via Backspace in menu
		if (FlxG.keys.justPressed.BACKSPACE && !items[curSelection].isAction && !items[curSelection].isHeader)
		{
			var item = items[curSelection];
			if (Init.gameControls.exists(item.id))
			{
				Init.gameControls.get(item.id)[0][curSlot] = FlxKey.NONE;
				Init.saveControls();
				controls.setKeyboardScheme(None, false);
				refreshKeyLabels();
				FlxG.sound.play(Paths.sound('system/cancel'));
			}
		}

		// Action trigger (Rebind or Reset Defaults)
		if (controls.ACCEPT)
		{
			var item = items[curSelection];
			if (item.isAction)
			{
				if (item.id == "RESET_DEFAULTS")
				{
					Init.resetControls();
					controls.setKeyboardScheme(None, false);
					refreshKeyLabels();
					FlxG.sound.play(Paths.sound('system/confirm'));
					FlxG.camera.flash(FlxColor.WHITE, 0.2);
				}
			}
			else if (!item.isHeader)
			{
				startRebinding();
			}
		}
		else if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('system/cancel'));
			close();
		}

		// Smooth straight vertical scrolling
		updatePositions(elapsed);
	}

	function updateSelection(change:Int = 0, playSound:Bool = true):Void
	{
		if (change != 0 && playSound)
			FlxG.sound.play(Paths.sound('system/scroll'));

		curSelection += change;

		// Wrap around
		if (curSelection < 0)
			curSelection = items.length - 1;
		else if (curSelection >= items.length)
			curSelection = 0;

		// Skip header rows
		while (items[curSelection] != null && items[curSelection].isHeader)
		{
			curSelection += (change >= 0 ? 1 : -1);
			if (curSelection < 0)
				curSelection = items.length - 1;
			else if (curSelection >= items.length)
				curSelection = 0;
		}

		updateSlotHighlight();
	}

	function updateSlotHighlight():Void
	{
		var item = items[curSelection];
		if (item == null || item.isHeader) return;

		for (i in 0...items.length)
		{
			var isCurrent = (i == curSelection);
			var targetAlpha = isCurrent ? 1.0 : (items[i].isHeader ? 0.75 : 0.45);

			grpActionTexts.members[i].alpha = targetAlpha;
			grpKey1Texts.members[i].alpha = targetAlpha;
			grpKey2Texts.members[i].alpha = targetAlpha;

			if (isCurrent && !items[i].isHeader)
			{
				grpActionTexts.members[i].color = 0xFF35A7FF;
				if (!item.isAction)
				{
					grpKey1Texts.members[i].color = (curSlot == 0) ? 0xFFFFD700 : FlxColor.WHITE;
					grpKey2Texts.members[i].color = (curSlot == 1) ? 0xFFFFD700 : FlxColor.WHITE;
				}
				else
				{
					grpKey1Texts.members[i].color = 0xFFFFD700;
				}
			}
			else
			{
				grpActionTexts.members[i].color = items[i].isHeader ? 0xFFFFD700 : FlxColor.WHITE;
				grpKey1Texts.members[i].color = FlxColor.WHITE;
				grpKey2Texts.members[i].color = FlxColor.WHITE;
			}
		}

		// Update selector box position
		if (!item.isAction)
		{
			selectorBox.visible = true;
			selectorBox.x = (curSlot == 0 ? 570 : 870);
		}
		else
		{
			selectorBox.visible = true;
			selectorBox.x = 570;
		}
	}

	function updatePositions(elapsed:Float):Void
	{
		var centerY = FlxG.height * 0.46;
		var spacing = 50.0;

		for (i in 0...items.length)
		{
			var targetY = centerY + ((i - curSelection) * spacing);

			// Lerp Y smoothly; keep X strictly straight
			var aTxt = grpActionTexts.members[i];
			var k1Txt = grpKey1Texts.members[i];
			var k2Txt = grpKey2Texts.members[i];

			aTxt.y = FlxMath.lerp(aTxt.y, targetY, Math.min(1.0, elapsed * 14));
			k1Txt.y = aTxt.y;
			k2Txt.y = aTxt.y;

			// Maintain fixed straight X column positions
			aTxt.x = 120;
			k1Txt.x = 580;
			k2Txt.x = 880;

			if (i == curSelection)
			{
				selectorBox.y = aTxt.y - 6;
			}
		}
	}

	function startRebinding():Void
	{
		var item = items[curSelection];
		if (item == null || item.isHeader || item.isAction) return;

		isRebinding = true;
		rebindOverlay.visible = true;
		rebindBox.visible = true;
		rebindTitle.text = "REBINDING: " + item.name;
		rebindTitle.visible = true;
		rebindSlot.text = "SLOT: " + (curSlot == 0 ? "PRIMARY" : "SECONDARY");
		rebindSlot.visible = true;
		rebindPrompt.visible = true;
		rebindHelp.visible = true;

		FlxG.sound.play(Paths.sound('system/scroll'));
	}

	function stopRebinding():Void
	{
		isRebinding = false;
		rebindOverlay.visible = false;
		rebindBox.visible = false;
		rebindTitle.visible = false;
		rebindSlot.visible = false;
		rebindPrompt.visible = false;
		rebindHelp.visible = false;
	}

	function updateRebinding():Void
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('system/cancel'));
			stopRebinding();
			return;
		}

		if (FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.DELETE)
		{
			var item = items[curSelection];
			if (Init.gameControls.exists(item.id))
			{
				Init.gameControls.get(item.id)[0][curSlot] = FlxKey.NONE;
				Init.saveControls();
				controls.setKeyboardScheme(None, false);
				refreshKeyLabels();
				updateSlotHighlight();
				FlxG.sound.play(Paths.sound('system/confirm'));
			}
			stopRebinding();
			return;
		}

		var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
		if (keyPressed != FlxKey.NONE && (cast keyPressed : Int) != -1)
		{
			var item = items[curSelection];
			if (Init.gameControls.exists(item.id))
			{
				// Clear duplicate key if already bound anywhere in the same controls map
				for (otherKey in Init.gameControls.keys())
				{
					var slots:Array<Dynamic> = Init.gameControls.get(otherKey)[0];
					if (slots != null)
					{
						for (s in 0...slots.length)
						{
							if (slots[s] == keyPressed)
								slots[s] = FlxKey.NONE;
						}
					}
				}

				// Assign newly pressed key
				Init.gameControls.get(item.id)[0][curSlot] = keyPressed;
				Init.saveControls();
				controls.setKeyboardScheme(None, false);
				refreshKeyLabels();
				updateSlotHighlight();
				FlxG.sound.play(Paths.sound('system/confirm'));
			}
			stopRebinding();
		}
	}

	override public function close():Void
	{
		Init.saveControls();
		Init.saveSettings();
		super.close();
	}
}

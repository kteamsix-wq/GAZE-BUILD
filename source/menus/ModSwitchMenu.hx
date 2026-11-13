package menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import core.base.MusicBeatSubState;
import core.scripting.Mods;
import core.system.Paths;
import Main;

using StringTools;

typedef ModMetadata =
{
	var folder:String;
	var name:String;
	var description:String;
	var author:String;
	var version:String;
	var api_version:String;
	var color:FlxColor;
	var iconPath:Null<String>;
	var iconBmp:Null<BitmapData>;
	var active:Bool;
}

class ModCard
{
	public var index:Int;
	public var meta:ModMetadata;
	public var bg:FlxSprite;
	public var outline:FlxSprite;
	public var icon:FlxSprite;
	public var iconBorder:FlxSprite;
	public var titleText:FlxText;
	public var subText:FlxText;
	public var badgeBg:FlxSprite;
	public var badgeText:FlxText;

	public var targetX:Float = 40;
	public var targetY:Float = 0;
	public var currentX:Float = 40;
	public var currentY:Float = 0;

	public function new(index:Int, meta:ModMetadata)
	{
		this.index = index;
		this.meta = meta;
	}

	public function setPosition(x:Float, y:Float):Void
	{
		currentX = x;
		currentY = y;

		bg.setPosition(x, y);
		outline.setPosition(x, y);
		icon.setPosition(x + 10, y + 10);
		iconBorder.setPosition(x + 9, y + 9);
		titleText.setPosition(x + 82, y + 12);
		subText.setPosition(x + 82, y + 42);

		if (badgeBg != null)
			badgeBg.setPosition(x + bg.width - badgeBg.width - 15, y + (bg.height - badgeBg.height) / 2);
		if (badgeText != null && badgeBg != null)
			badgeText.setPosition(badgeBg.x, badgeBg.y + 4);
	}

	public function setAlpha(a:Float):Void
	{
		bg.alpha = a;
		outline.alpha = a;
		icon.alpha = a;
		iconBorder.alpha = a;
		titleText.alpha = a;
		subText.alpha = a;
		if (badgeBg != null) badgeBg.alpha = a;
		if (badgeText != null) badgeText.alpha = a;
	}

	public function destroy():Void
	{
		if (bg != null) bg.destroy();
		if (outline != null) outline.destroy();
		if (icon != null) icon.destroy();
		if (iconBorder != null) iconBorder.destroy();
		if (titleText != null) titleText.destroy();
		if (subText != null) subText.destroy();
		if (badgeBg != null) badgeBg.destroy();
		if (badgeText != null) badgeText.destroy();
	}
}

/**
 * Codename Engine styled Mod Switch Menu.
 * Allows browsing, inspecting, and switching installed mods seamlessly
 * via substate overlay or standalone state.
 */
class ModSwitchMenu extends MusicBeatSubState
{
	var isStandalone:Bool = false;
	var prevMouseVisible:Bool = true;

	var modsData:Array<ModMetadata> = [];
	var modCards:Array<ModCard> = [];
	var curSelected:Int = 0;

	// Background and Navigation Bars
	var bgOverlay:FlxSprite;
	var headerBar:FlxSprite;
	var headerLine:FlxSprite;
	var headerTitle:FlxText;
	var headerTag:FlxText;
	var headerModCount:FlxText;

	var bottomBar:FlxSprite;
	var bottomLine:FlxSprite;
	var bottomHelpText:FlxText;

	// Mod Cards Group
	var cardsGroup:FlxTypedGroup<FlxSprite>;
	var cardsTextGroup:FlxTypedGroup<FlxText>;

	// Right Details Panel
	var detailsPanel:FlxSprite;
	var detailsPanelBorder:FlxSprite;
	var detailIcon:FlxSprite;
	var detailIconBorder:FlxSprite;
	var detailTitle:FlxText;
	var detailAuthor:FlxText;
	var detailVersion:FlxText;
	var detailFolder:FlxText;
	var detailDivider:FlxSprite;
	var detailDescHeader:FlxText;
	var detailDesc:FlxText;

	var actionBtnBg:FlxSprite;
	var actionBtnBorder:FlxSprite;
	var actionBtnText:FlxText;

	// Empty State Elements (if 0 mods)
	var emptyGroup:FlxTypedGroup<FlxSprite>;
	var emptyTextTitle:FlxText;
	var emptyTextDesc:FlxText;
	var emptyTextHelp:FlxText;

	public function new(isStandalone:Bool = false)
	{
		super();
		this.isStandalone = isStandalone;
	}

	override function create()
	{
		super.create();

		prevMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;

		// 1. Dark Backdrop Overlay
		bgOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xDD090A12);
		bgOverlay.scrollFactor.set();
		add(bgOverlay);

		cardsGroup = new FlxTypedGroup<FlxSprite>();
		add(cardsGroup);

		cardsTextGroup = new FlxTypedGroup<FlxText>();
		add(cardsTextGroup);

		// 2. Right Detail Panel
		createDetailsPanel();

		// 3. Top Header Bar
		createHeaderBar();

		// 4. Bottom Information Bar
		createBottomBar();

		// 5. Empty State Group
		emptyGroup = new FlxTypedGroup<FlxSprite>();
		add(emptyGroup);

		emptyTextTitle = new FlxText(0, FlxG.height * 0.35, FlxG.width, "NO MODS FOUND", 32);
		emptyTextTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		emptyTextTitle.scrollFactor.set();
		emptyGroup.add(emptyTextTitle);

		emptyTextDesc = new FlxText(0, emptyTextTitle.y + 45, FlxG.width, "Place your mod folders inside the 'mods/' directory.", 18);
		emptyTextDesc.setFormat(Paths.font("vcr.ttf"), 18, 0xFFA0A5BF, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		emptyTextDesc.scrollFactor.set();
		emptyGroup.add(emptyTextDesc);

		emptyTextHelp = new FlxText(0, emptyTextDesc.y + 35, FlxG.width, "Press [O] to open the mods folder now, or [R] to reload.", 16);
		emptyTextHelp.setFormat(Paths.font("vcr.ttf"), 16, 0xFF33CCFF, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		emptyTextHelp.scrollFactor.set();
		emptyGroup.add(emptyTextHelp);

		emptyGroup.visible = false;

		// 6. Scan & Load Mods
		scanMods();

		// Select current mod by default
		if (modsData.length > 0)
		{
			var activeIdx = 0;
			for (i in 0...modsData.length)
			{
				if (modsData[i].active)
				{
					activeIdx = i;
					break;
				}
			}
			curSelected = activeIdx;
			updateSelection(false);
		}
	}

	function createHeaderBar():Void
	{
		headerBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 56, 0xF20F101A);
		headerBar.scrollFactor.set();
		add(headerBar);

		headerLine = new FlxSprite(0, 54).makeGraphic(FlxG.width, 2, 0xFF33CCFF);
		headerLine.scrollFactor.set();
		add(headerLine);

		headerTitle = new FlxText(30, 12, 0, "MOD SWITCHER", 24);
		headerTitle.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		headerTitle.scrollFactor.set();
		add(headerTitle);

		headerTag = new FlxText(headerTitle.x + 200, 18, 0, "[ CODENAME STYLE ]", 14);
		headerTag.setFormat(Paths.font("vcr.ttf"), 14, 0xFF33CCFF, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		headerTag.scrollFactor.set();
		add(headerTag);

		headerModCount = new FlxText(FlxG.width - 450, 18, 420, "", 14);
		headerModCount.setFormat(Paths.font("vcr.ttf"), 14, 0xFFA0A5BF, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		headerModCount.scrollFactor.set();
		add(headerModCount);
	}

	function createBottomBar():Void
	{
		bottomBar = new FlxSprite(0, FlxG.height - 36).makeGraphic(FlxG.width, 36, 0xF20F101A);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		bottomLine = new FlxSprite(0, FlxG.height - 36).makeGraphic(FlxG.width, 1, 0x4433CCFF);
		bottomLine.scrollFactor.set();
		add(bottomLine);

		bottomHelpText = new FlxText(0, FlxG.height - 27, FlxG.width, 
			"[ENTER / CLICK] Load Mod  •  [UP/DOWN/SCROLL] Select  •  [O] Open Folder  •  [R] Reload  •  [ESC/TAB] Close", 13);
		bottomHelpText.setFormat(Paths.font("vcr.ttf"), 13, 0xFFC8CCDF, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		bottomHelpText.scrollFactor.set();
		add(bottomHelpText);
	}

	function createDetailsPanel():Void
	{
		var panelX = 550;
		var panelY = 74;
		var panelW = 695;
		var panelH = 585;

		detailsPanel = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, 0xEE11121C);
		detailsPanel.scrollFactor.set();
		add(detailsPanel);

		detailsPanelBorder = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, FlxColor.TRANSPARENT);
		detailsPanelBorder.scrollFactor.set();
		drawBorder(detailsPanelBorder, 0xFF282C40, 2);
		add(detailsPanelBorder);

		// Big Icon
		detailIcon = new FlxSprite(panelX + 25, panelY + 25).makeGraphic(110, 110, 0xFF1C1E2B);
		detailIcon.scrollFactor.set();
		add(detailIcon);

		detailIconBorder = new FlxSprite(panelX + 23, panelY + 23).makeGraphic(114, 114, FlxColor.TRANSPARENT);
		detailIconBorder.scrollFactor.set();
		drawBorder(detailIconBorder, FlxColor.WHITE, 2);
		add(detailIconBorder);

		// Header Details
		detailTitle = new FlxText(panelX + 155, panelY + 24, panelW - 170, "", 24);
		detailTitle.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailTitle.scrollFactor.set();
		add(detailTitle);

		detailAuthor = new FlxText(panelX + 155, panelY + 58, panelW - 170, "", 16);
		detailAuthor.setFormat(Paths.font("vcr.ttf"), 16, 0xFF9EABB8, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailAuthor.scrollFactor.set();
		add(detailAuthor);

		detailVersion = new FlxText(panelX + 155, panelY + 84, panelW - 170, "", 14);
		detailVersion.setFormat(Paths.font("vcr.ttf"), 14, 0xFF707E96, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailVersion.scrollFactor.set();
		add(detailVersion);

		detailFolder = new FlxText(panelX + 155, panelY + 106, panelW - 170, "", 13);
		detailFolder.setFormat(Paths.font("vcr.ttf"), 13, 0xFF4A566E, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailFolder.scrollFactor.set();
		add(detailFolder);

		// Divider
		detailDivider = new FlxSprite(panelX + 25, panelY + 150).makeGraphic(panelW - 50, 2, 0xFF33CCFF);
		detailDivider.scrollFactor.set();
		add(detailDivider);

		// Description
		detailDescHeader = new FlxText(panelX + 25, panelY + 165, panelW - 50, "ABOUT THIS MOD", 14);
		detailDescHeader.setFormat(Paths.font("vcr.ttf"), 14, 0xFF33CCFF, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailDescHeader.scrollFactor.set();
		add(detailDescHeader);

		detailDesc = new FlxText(panelX + 25, panelY + 192, panelW - 50, "", 16);
		detailDesc.setFormat(Paths.font("vcr.ttf"), 16, 0xFFE0E4F0, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		detailDesc.scrollFactor.set();
		add(detailDesc);

		// Action Button at Bottom
		var btnW = panelW - 50;
		var btnH = 54;
		var btnY = panelY + panelH - btnH - 20;

		actionBtnBg = new FlxSprite(panelX + 25, btnY).makeGraphic(btnW, btnH, 0x3333CCFF);
		actionBtnBg.scrollFactor.set();
		add(actionBtnBg);

		actionBtnBorder = new FlxSprite(panelX + 25, btnY).makeGraphic(btnW, btnH, FlxColor.TRANSPARENT);
		actionBtnBorder.scrollFactor.set();
		drawBorder(actionBtnBorder, FlxColor.WHITE, 2);
		add(actionBtnBorder);

		actionBtnText = new FlxText(panelX + 25, btnY + 16, btnW, "", 18);
		actionBtnText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		actionBtnText.scrollFactor.set();
		add(actionBtnText);
	}

	function scanMods():Void
	{
		// Clean existing cards
		for (card in modCards)
		{
			card.destroy();
		}
		modCards = [];
		modsData = [];
		cardsGroup.clear();
		cardsTextGroup.clear();

		var dirList = Mods.getModDirectories();
		for (folder in dirList)
		{
			var meta = parseModMetadata(folder);
			modsData.push(meta);
		}

		if (modsData.length == 0)
		{
			emptyGroup.visible = true;
			detailsPanel.visible = false;
			detailsPanelBorder.visible = false;
			detailIcon.visible = false;
			detailIconBorder.visible = false;
			detailTitle.visible = false;
			detailAuthor.visible = false;
			detailVersion.visible = false;
			detailFolder.visible = false;
			detailDivider.visible = false;
			detailDescHeader.visible = false;
			detailDesc.visible = false;
			actionBtnBg.visible = false;
			actionBtnBorder.visible = false;
			actionBtnText.visible = false;
			headerModCount.text = "0 MODS INSTALLED";
			return;
		}

		emptyGroup.visible = false;
		detailsPanel.visible = true;
		detailsPanelBorder.visible = true;
		detailIcon.visible = true;
		detailIconBorder.visible = true;
		detailTitle.visible = true;
		detailAuthor.visible = true;
		detailVersion.visible = true;
		detailFolder.visible = true;
		detailDivider.visible = true;
		detailDescHeader.visible = true;
		detailDesc.visible = true;
		actionBtnBg.visible = true;
		actionBtnBorder.visible = true;
		actionBtnText.visible = true;

		var curModName = (Mods.currentModDirectory != null && Mods.currentModDirectory != '') ? Mods.currentModDirectory : 'None';
		headerModCount.text = '${modsData.length} MODS FOUND  •  ACTIVE: $curModName';

		// Create Card Sprites
		for (i in 0...modsData.length)
		{
			var meta = modsData[i];
			var card = new ModCard(i, meta);

			// Background
			card.bg = new FlxSprite().makeGraphic(480, 80, 0xCC131522);
			card.bg.scrollFactor.set();
			cardsGroup.add(card.bg);

			// Outline
			card.outline = new FlxSprite().makeGraphic(480, 80, FlxColor.TRANSPARENT);
			card.outline.scrollFactor.set();
			drawBorder(card.outline, FlxColor.WHITE, 2);
			cardsGroup.add(card.outline);

			// Icon
			card.icon = new FlxSprite().makeGraphic(60, 60, 0xFF1C1E2B);
			card.icon.scrollFactor.set();
			if (meta.iconBmp != null)
			{
				card.icon.loadGraphic(FlxGraphic.fromBitmapData(meta.iconBmp));
				card.icon.setGraphicSize(60, 60);
				card.icon.updateHitbox();
			}
			else
			{
				applyPlaceholderGraphic(card.icon, 60, meta.name, meta.color);
			}
			cardsGroup.add(card.icon);

			// Icon border
			card.iconBorder = new FlxSprite().makeGraphic(62, 62, FlxColor.TRANSPARENT);
			card.iconBorder.scrollFactor.set();
			drawBorder(card.iconBorder, FlxColor.WHITE, 1);
			cardsGroup.add(card.iconBorder);

			// Title
			var displayTitle = meta.name;
			if (displayTitle.length > 24)
				displayTitle = displayTitle.substr(0, 22) + "...";
			card.titleText = new FlxText(0, 0, 310, displayTitle, 19);
			card.titleText.setFormat(Paths.font("vcr.ttf"), 19, 0xFFA5AEC4, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			card.titleText.scrollFactor.set();
			cardsTextGroup.add(card.titleText);

			// Subtitle (Version & Author)
			var sub = 'v${meta.version} • by ${meta.author}';
			if (sub.length > 34)
				sub = sub.substr(0, 32) + "...";
			card.subText = new FlxText(0, 0, 310, sub, 13);
			card.subText.setFormat(Paths.font("vcr.ttf"), 13, 0xFF657088, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			card.subText.scrollFactor.set();
			cardsTextGroup.add(card.subText);

			// Active Badge
			if (meta.active)
			{
				card.badgeBg = new FlxSprite().makeGraphic(76, 26, 0x3300E676);
				card.badgeBg.scrollFactor.set();
				drawBorder(card.badgeBg, 0xFF00E676, 2);
				cardsGroup.add(card.badgeBg);

				card.badgeText = new FlxText(0, 0, 76, "ACTIVE", 12);
				card.badgeText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF00E676, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				card.badgeText.scrollFactor.set();
				cardsTextGroup.add(card.badgeText);
			}

			// Initial position
			card.setPosition(40, (FlxG.height / 2 - 40) + (i * 90));
			modCards.push(card);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (modsData.length > 0)
		{
			// Keyboard inputs
			if (controls.UI_UP_P || FlxG.keys.justPressed.W)
				changeSelection(-1);
			else if (controls.UI_DOWN_P || FlxG.keys.justPressed.S)
				changeSelection(1);

			// Mouse Wheel
			if (FlxG.mouse.wheel != 0)
				changeSelection(-FlxG.mouse.wheel);

			// Mouse Overlap on Cards
			var hoveredIndex:Int = -1;
			for (i in 0...modCards.length)
			{
				var card = modCards[i];
				if (FlxG.mouse.x >= card.bg.x && FlxG.mouse.x <= card.bg.x + card.bg.width
					&& FlxG.mouse.y >= card.bg.y && FlxG.mouse.y <= card.bg.y + card.bg.height)
				{
					hoveredIndex = i;
					break;
				}
			}

			var hoveringActionBtn:Bool = (actionBtnBg != null && FlxG.mouse.x >= actionBtnBg.x && FlxG.mouse.x <= actionBtnBg.x + actionBtnBg.width
				&& FlxG.mouse.y >= actionBtnBg.y && FlxG.mouse.y <= actionBtnBg.y + actionBtnBg.height);

			CursorManager.change((hoveredIndex != -1 || hoveringActionBtn) ? 'pointer' : 'default');

			if (hoveredIndex != -1 && FlxG.mouse.justMoved && hoveredIndex != curSelected)
			{
				curSelected = hoveredIndex;
				updateSelection(true);
			}

			// Mouse Click on Card or Action Button
			if (FlxG.mouse.justPressed)
			{
				if (hoveredIndex == curSelected)
				{
					selectMod();
				}
				else if (hoveredIndex != -1)
				{
					curSelected = hoveredIndex;
					updateSelection(true);
				}
				else if (FlxG.mouse.x >= actionBtnBg.x && FlxG.mouse.x <= actionBtnBg.x + actionBtnBg.width
					&& FlxG.mouse.y >= actionBtnBg.y && FlxG.mouse.y <= actionBtnBg.y + actionBtnBg.height)
				{
					selectMod();
				}
			}

			// Accept Key
			if (controls.ACCEPT || FlxG.keys.justPressed.SPACE)
			{
				selectMod();
			}
		}

		// Open Mods Folder
		if (FlxG.keys.justPressed.O)
		{
			openModsFolder();
		}

		// Reload Mods List
		if (FlxG.keys.justPressed.R)
		{
			FlxG.sound.play(Paths.sound('scroll'));
			scanMods();
			if (modsData.length > 0)
			{
				if (curSelected >= modsData.length) curSelected = modsData.length - 1;
				updateSelection(false);
			}
		}

		// Close / Back
		if (controls.BACK || FlxG.keys.justPressed.TAB || FlxG.keys.justPressed.ESCAPE)
		{
			closeMenu();
		}

		// Smooth Lerp Animation for Cards
		for (i in 0...modCards.length)
		{
			var card = modCards[i];
			var targetY = (FlxG.height / 2 - 40) + ((i - curSelected) * 92);
			var targetX = (i == curSelected) ? 58.0 : 40.0;

			var lerpFactor = 1.0 - Math.exp(-elapsed * 14);
			card.currentX = FlxMath.lerp(card.currentX, targetX, lerpFactor);
			card.currentY = FlxMath.lerp(card.currentY, targetY, lerpFactor);

			card.setPosition(card.currentX, card.currentY);
		}
	}

	function changeSelection(change:Int):Void
	{
		if (modsData.length <= 1) return;

		curSelected += change;
		if (curSelected < 0) curSelected = modsData.length - 1;
		if (curSelected >= modsData.length) curSelected = 0;

		updateSelection(true);
	}

	function updateSelection(playSound:Bool):Void
	{
		if (playSound)
			FlxG.sound.play(Paths.sound('scroll'));

		var meta = modsData[curSelected];

		// Dynamic Header and Detail Lines Accent Color
		headerLine.color = meta.color;
		detailDivider.color = meta.color;
		detailDescHeader.color = meta.color;

		// Update Cards Appearance
		for (i in 0...modCards.length)
		{
			var card = modCards[i];
			var isSelected = (i == curSelected);

			if (isSelected)
			{
				card.setAlpha(1.0);
				card.bg.color = 0xFF22263A;
				card.titleText.color = FlxColor.WHITE;
				card.outline.color = meta.color;
				card.outline.alpha = 1.0;
				card.iconBorder.color = meta.color;
				card.iconBorder.alpha = 1.0;
			}
			else
			{
				card.setAlpha(0.68);
				card.bg.color = 0xFF131522;
				card.titleText.color = 0xFFA5AEC4;
				card.outline.color = 0xFF303650;
				card.outline.alpha = 0.45;
				card.iconBorder.color = 0xFF384060;
				card.iconBorder.alpha = 0.45;
			}
		}

		// Update Detail Panel Information
		detailTitle.text = meta.name;
		detailAuthor.text = 'Created by: ${meta.author}';
		detailVersion.text = 'Version: ${meta.version}' + (meta.api_version != "" ? ' • API: ${meta.api_version}' : '');
		detailFolder.text = 'Directory: mods/${meta.folder}';
		detailDesc.text = (meta.description != null && meta.description != "") ? meta.description : "No description provided.";

		// Big Icon Graphic
		if (meta.iconBmp != null)
		{
			detailIcon.loadGraphic(FlxGraphic.fromBitmapData(meta.iconBmp));
			detailIcon.setGraphicSize(110, 110);
			detailIcon.updateHitbox();
		}
		else
		{
			applyPlaceholderGraphic(detailIcon, 110, meta.name, meta.color);
		}
		detailIconBorder.color = meta.color;

		// Action Button Appearance
		if (meta.active)
		{
			actionBtnBg.color = 0xFF00E676;
			actionBtnBg.alpha = 0.25;
			actionBtnBorder.color = 0xFF00E676;
			actionBtnText.text = "✓ CURRENTLY ACTIVE MOD";
			actionBtnText.color = 0xFF00E676;
		}
		else
		{
			actionBtnBg.color = meta.color;
			actionBtnBg.alpha = 0.25;
			actionBtnBorder.color = meta.color;
			actionBtnText.text = "▶ PRESS ENTER OR CLICK TO LOAD THIS MOD";
			actionBtnText.color = FlxColor.WHITE;
		}
	}

	function selectMod():Void
	{
		if (modsData.length == 0) return;

		var selected = modsData[curSelected];
		if (selected.active)
		{
			// Already active
			FlxG.sound.play(Paths.sound('confirm'));
			return;
		}

		// Switch mod directory
		Mods.currentModDirectory = selected.folder;
		Paths.clearStoredMemory(true);

		FlxG.sound.play(Paths.sound('confirm'));

		// Reload state so new mod assets take effect cleanly
		CursorManager.change('default');
		FlxG.mouse.visible = prevMouseVisible;

		if (isStandalone)
		{
			Main.switchState(this, new MainMenuState());
		}
		else
		{
			close();
			Main.switchState(FlxG.state, new MainMenuState());
		}
	}

	function openModsFolder():Void
	{
		#if sys
		var path:String = FileSystem.absolutePath("mods");
		if (!FileSystem.exists(path))
		{
			FileSystem.createDirectory(path);
		}

		#if windows
		Sys.command('explorer "$path"');
		#elseif mac
		Sys.command('open "$path"');
		#else
		Sys.command('xdg-open "$path"');
		#end
		#end
	}

	function closeMenu():Void
	{
		FlxG.sound.play(Paths.sound('cancel'));
		CursorManager.change('default');
		FlxG.mouse.visible = prevMouseVisible;

		if (isStandalone)
		{
			Main.switchState(this, new MainMenuState());
		}
		else
		{
			close();
		}
	}

	// -------------------------------------------------------------
	// Helper Utilities for Drawing, Borders, and Metadata Parsing
	// -------------------------------------------------------------

	public static function drawBorder(spr:FlxSprite, borderColor:FlxColor, borderWidth:Int = 2):Void
	{
		var w = Std.int(spr.width);
		var h = Std.int(spr.height);
		if (w <= 0 || h <= 0) return;

		var bmp = new BitmapData(w, h, true, FlxColor.TRANSPARENT);

		// Top & Bottom lines
		for (x in 0...w)
		{
			for (b in 0...borderWidth)
			{
				bmp.setPixel32(x, b, borderColor);
				bmp.setPixel32(x, h - 1 - b, borderColor);
			}
		}

		// Left & Right lines
		for (y in 0...h)
		{
			for (b in 0...borderWidth)
			{
				bmp.setPixel32(b, y, borderColor);
				bmp.setPixel32(w - 1 - b, y, borderColor);
			}
		}

		spr.loadGraphic(FlxGraphic.fromBitmapData(bmp));
	}

	public static function applyPlaceholderGraphic(spr:FlxSprite, size:Int, title:String, accentColor:FlxColor):Void
	{
		var bmp = new BitmapData(size, size, true, 0xFF1A1C29);
		for (x in 0...size)
		{
			bmp.setPixel32(x, 0, accentColor);
			bmp.setPixel32(x, size - 1, accentColor);
		}
		for (y in 0...size)
		{
			bmp.setPixel32(0, y, accentColor);
			bmp.setPixel32(size - 1, y, accentColor);
		}
		spr.loadGraphic(FlxGraphic.fromBitmapData(bmp));
		spr.setGraphicSize(size, size);
		spr.updateHitbox();
	}

	public static function parseModMetadata(modFolder:String):ModMetadata
	{
		var meta:ModMetadata = {
			folder: modFolder,
			name: formatFolderName(modFolder),
			description: "No description provided.",
			author: "Unknown Creator",
			version: "1.0.0",
			api_version: "Codename",
			color: FlxColor.fromRGB(51, 204, 255),
			iconPath: null,
			iconBmp: null,
			active: (Mods.currentModDirectory == modFolder)
		};

		var jsonFiles = [
			'_polymod_meta.json',
			'mod.json',
			'meta.json',
			'metadata.json'
		];

		#if sys
		for (file in jsonFiles)
		{
			var fullPath = 'mods/' + modFolder + '/' + file;
			if (FileSystem.exists(fullPath))
			{
				try
				{
					var raw = File.getContent(fullPath);
					var data = Json.parse(raw);
					if (data != null)
					{
						// Title / Name
						if (Reflect.hasField(data, "title") && Reflect.field(data, "title") != null)
							meta.name = Std.string(Reflect.field(data, "title"));
						else if (Reflect.hasField(data, "name") && Reflect.field(data, "name") != null)
							meta.name = Std.string(Reflect.field(data, "name"));
						else if (Reflect.hasField(data, "nome") && Reflect.field(data, "nome") != null)
							meta.name = Std.string(Reflect.field(data, "nome"));

						// Description
						if (Reflect.hasField(data, "description") && Reflect.field(data, "description") != null)
							meta.description = Std.string(Reflect.field(data, "description"));
						else if (Reflect.hasField(data, "desc") && Reflect.field(data, "desc") != null)
							meta.description = Std.string(Reflect.field(data, "desc"));
						else if (Reflect.hasField(data, "descricao") && Reflect.field(data, "descricao") != null)
							meta.description = Std.string(Reflect.field(data, "descricao"));
						else if (Reflect.hasField(data, "descrição") && Reflect.field(data, "descrição") != null)
							meta.description = Std.string(Reflect.field(data, "descrição"));

						// Author
						if (Reflect.hasField(data, "author") && Reflect.field(data, "author") != null)
							meta.author = parseAuthor(Reflect.field(data, "author"));
						else if (Reflect.hasField(data, "creator") && Reflect.field(data, "creator") != null)
							meta.author = parseAuthor(Reflect.field(data, "creator"));
						else if (Reflect.hasField(data, "authors") && Reflect.field(data, "authors") != null)
							meta.author = parseAuthor(Reflect.field(data, "authors"));
						else if (Reflect.hasField(data, "autor") && Reflect.field(data, "autor") != null)
							meta.author = parseAuthor(Reflect.field(data, "autor"));

						// Version
						if (Reflect.hasField(data, "version") && Reflect.field(data, "version") != null)
							meta.version = Std.string(Reflect.field(data, "version"));
						else if (Reflect.hasField(data, "mod_version") && Reflect.field(data, "mod_version") != null)
							meta.version = Std.string(Reflect.field(data, "mod_version"));
						else if (Reflect.hasField(data, "versao") && Reflect.field(data, "versao") != null)
							meta.version = Std.string(Reflect.field(data, "versao"));

						// API version
						if (Reflect.hasField(data, "api_version") && Reflect.field(data, "api_version") != null)
							meta.api_version = Std.string(Reflect.field(data, "api_version"));

						// Color
						if (Reflect.hasField(data, "color") && Reflect.field(data, "color") != null)
							meta.color = parseColor(Reflect.field(data, "color"));
						else if (Reflect.hasField(data, "barColor") && Reflect.field(data, "barColor") != null)
							meta.color = parseColor(Reflect.field(data, "barColor"));

						// Custom icon
						if (Reflect.hasField(data, "icon") && Reflect.field(data, "icon") != null)
						{
							var customIcon = Std.string(Reflect.field(data, "icon")).trim();
							var testP = 'mods/' + modFolder + '/' + customIcon;
							if (FileSystem.exists(testP))
								meta.iconPath = testP;
							else if (!customIcon.endsWith(".png") && !customIcon.endsWith(".webp"))
							{
								if (FileSystem.exists(testP + ".png"))
									meta.iconPath = testP + ".png";
								else if (FileSystem.exists(testP + ".webp"))
									meta.iconPath = testP + ".webp";
							}
						}
						break;
					}
				}
				catch (e:Dynamic) {}
			}
		}

		// Icon Search Candidates
		if (meta.iconPath == null)
		{
			var candidates = [
				'mods/' + modFolder + '/_polymod_icon.png',
				'mods/' + modFolder + '/_polymod_icon.webp',
				'mods/' + modFolder + '/icon.png',
				'mods/' + modFolder + '/icon.webp',
				'mods/' + modFolder + '/images/icon.png',
				'mods/' + modFolder + '/images/icon.webp',
				'mods/' + modFolder + '/meta/icon.png',
				'mods/' + modFolder + '/meta/icon.webp',
				'mods/' + modFolder + '/logo.png',
				'mods/' + modFolder + '/logo.webp'
			];
			for (cand in candidates)
			{
				if (FileSystem.exists(cand))
				{
					meta.iconPath = cand;
					break;
				}
			}
		}

		if (meta.iconPath != null && FileSystem.exists(meta.iconPath))
		{
			try
			{
				meta.iconBmp = Paths.loadBitmap(meta.iconPath);
			}
			catch (e:Dynamic)
			{
				meta.iconBmp = null;
			}
		}
		#end

		return meta;
	}

	static function formatFolderName(folder:String):String
	{
		var clean = folder.replace('-', ' ').replace('_', ' ').trim();
		var words = clean.split(' ');
		var formatted = [for (w in words) (w.length > 0 ? w.charAt(0).toUpperCase() + w.substr(1) : "")];
		return formatted.join(' ');
	}

	static function parseAuthor(field:Dynamic):String
	{
		if (field == null) return "Unknown Creator";
		if (Std.isOfType(field, Array))
		{
			var arr:Array<Dynamic> = cast field;
			return arr.join(', ');
		}
		return Std.string(field);
	}

	static function parseColor(field:Dynamic):FlxColor
	{
		if (field == null) return FlxColor.fromRGB(51, 204, 255);
		if (Std.isOfType(field, String))
		{
			var str:String = cast field;
			if (!str.startsWith("#") && !str.startsWith("0x"))
				str = "#" + str;
			return FlxColor.fromString(str);
		}
		if (Std.isOfType(field, Int))
		{
			var c:Int = cast field;
			if ((c & 0xFF000000) == 0) c |= 0xFF000000;
			return new FlxColor(c);
		}
		if (Std.isOfType(field, Array))
		{
			var arr:Array<Dynamic> = cast field;
			if (arr.length >= 3)
				return FlxColor.fromRGB(Std.int(arr[0]), Std.int(arr[1]), Std.int(arr[2]));
		}
		return FlxColor.fromRGB(51, 204, 255);
	}
}

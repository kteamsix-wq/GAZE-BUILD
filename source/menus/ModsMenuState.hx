package menus;

import flixel.FlxG;
import core.base.MusicBeatState;
import menus.ModSwitchMenu;

/**
 * Standalone state wrapper for Codename Engine Mod Switch Menu.
 * Ensures compatibility with legacy state transitions and scripting calls.
 */
class ModsMenuState extends MusicBeatState
{
	override function create()
	{
		super.create();
		openSubState(new ModSwitchMenu(true));
	}
}

package core.scripting;

import core.base.MusicBeatState;
import core.scripting.HScriptHandler;
import core.scripting.Mods;
import core.system.Paths;
import flixel.FlxG;
import flixel.FlxState;

class ModState extends MusicBeatState
{
	public var script:HScriptHandler;
	public var stateName:String;

	public function new(name:String)
	{
		super();
		this.stateName = name;
	}

	override function create()
	{
		super.create();

		var scriptPath = "";
		// Search in all mod directories
		var modsList = Mods.getModDirectories();
		for (mod in modsList)
		{
			var path = 'mods/' + mod + '/data/states/' + stateName + '.hx';
			if (sys.FileSystem.exists(path))
			{
				scriptPath = path;
				core.scripting.Mods.currentModDirectory = mod;
				break;
			}
		}

		if (scriptPath == "")
		{
			var fallback = 'assets/data/states/' + stateName + '.hx';
			if (sys.FileSystem.exists(fallback)) scriptPath = fallback;
		}

		if (scriptPath != "" && sys.FileSystem.exists(scriptPath))
		{
			script = new HScriptHandler(scriptPath);
			script.setVar('this', this);
			script.setVar('controls', controls);
			
			// Inject additional state-switching capabilities for ModState scripts
			script.setVar('ModState', core.scripting.ModState);
			script.setVar('MainMenuState', menus.MainMenuState);
			script.setVar('TitleState', menus.TitleState);
			script.setVar('FreeplayState', menus.FreeplayState);
			script.setVar('OptionsMenuState', menus.OptionsMenuState);
			script.setVar('OptionsState', menus.OptionsMenuState);
			script.setVar('CreditsState', menus.CreditsState);
			script.setVar('ModsMenuState', menus.ModsMenuState);
			script.setVar('StoryMenuState', menus.ModsMenuState);
			script.setVar('CollectionRoomState', menus.ModsMenuState);
            
			script.setVar('add', function(obj:flixel.FlxBasic) { this.add(obj); });
			script.setVar('insert', function(pos:Int, obj:flixel.FlxBasic) { this.insert(pos, obj); });
			script.setVar('remove', function(obj:flixel.FlxBasic, splice:Bool = false) { this.remove(obj, splice); });
			
			// Also add the function to easily switch states
			script.setVar('switchState', function(target:FlxState) {
				Main.switchState(this, target);
			});
			script.setVar('playSong', function(nameSong:Dynamic, ?songList:Dynamic, ?difficulty:Null<Int>, ?customReturnState:Dynamic) {
				var retTarget:Dynamic = customReturnState != null ? customReturnState : this.stateName;
				gameplay.PlayState.playSong(nameSong, songList, difficulty, retTarget);
			});
			script.setVar('setReturnState', function(target:Dynamic) {
				gameplay.PlayState.setReturnState(target);
			});
			script.setVar('getReturnState', function() {
				return gameplay.PlayState.getReturnState();
			});
			
			script.call('create');
		}
		else
		{
			trace('Could not find custom state: ' + stateName);
			// Fallback?
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (script != null)
		{
			script.call('update', [elapsed]);
		}
	}

	override function destroy()
	{
		if (script != null)
		{
			script.call('destroy');
		}
		super.destroy();
	}

	override function stepHit()
	{
		super.stepHit();
		if (script != null)
		{
			script.call('stepHit');
		}
	}

	override function beatHit()
	{
		super.beatHit();
		if (script != null)
		{
			script.call('beatHit');
		}
	}
}

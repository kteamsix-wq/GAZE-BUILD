package funkin.game.modchart;

import flixel.FlxSprite;
import funkin.backend.math.Vector3;
import funkin.game.modchart.Modifier.ModifierOrder;
import funkin.game.modchart.Modifier.ModifierType;
import backend.HScriptHandler;
import sys.FileSystem;

class ScriptedModifier extends Modifier
{
	var name:String;
	var prefix:String;
	var modName:String;
	var modUpdate:Bool = false;
	var modOrder:Int = ModifierOrder.DEFAULT;
	var modType:ModifierType = MISC_MOD;

	var script:Null<HScriptHandler> = null;

	public function new(modMgr:ModManager, name:String = '', prefix:String = '', ?parent:Modifier)
	{
		this.prefix = prefix;
		modName = (this.name = name).toLowerCase();

		var searchPaths:Array<String> = [
			Paths.getPath('scripts/modifiers/$name.hx', TEXT),
			'assets/scripts/modifiers/$name.hx'
		];

		if (backend.Mods.currentModDirectory != null && backend.Mods.currentModDirectory != '')
		{
			searchPaths.unshift('mods/' + backend.Mods.currentModDirectory + '/scripts/modifiers/$name.hx');
		}

		var scriptPath:String = null;
		for (p in searchPaths)
		{
			if (FileSystem.exists(p))
			{
				scriptPath = p;
				break;
			}
		}

		if (scriptPath != null)
		{
			try
			{
				script = new HScriptHandler(scriptPath);
				script.setVar('NOTE_MOD', NOTE_MOD);
				script.setVar('MISC_MOD', MISC_MOD);
				script.setVar('FIRST', FIRST);
				script.setVar('PRE_REVERSE', PRE_REVERSE);
				script.setVar('REVERSE', REVERSE);
				script.setVar('POST_REVERSE', POST_REVERSE);
				script.setVar('DEFAULT', DEFAULT);
				script.setVar('LAST', LAST);
				script.setVar('Vector3', Vector3);
				script.setVar('MathUtil', funkin.utils.MathUtil);
				script.setVar('modMgr', modMgr);
				script.setVar('parent', parent);

				var scriptNameRes:Dynamic = script.call('getName');
				if (scriptNameRes != null) modName = Std.string(scriptNameRes);

				var scriptTypeRes:Dynamic = script.call('getModType');
				if (scriptTypeRes != null) modType = cast scriptTypeRes;

				var scriptOrderRes:Dynamic = script.call('getOrder');
				if (scriptOrderRes != null) modOrder = Std.int(scriptOrderRes);

				var scriptUpdateRes:Dynamic = script.call('doesUpdate');
				if (scriptUpdateRes != null) modUpdate = (scriptUpdateRes == true);
				else modUpdate = (modType == MISC_MOD);

				script.call('onLoad', [modMgr, name, prefix, parent]);
			}
			catch (e:Dynamic)
			{
				trace('Error initializing ScriptedModifier "$name": ' + e);
				script = null;
			}
		}

		super(modMgr, parent);
	}

	public override function getOrder():Int return modOrder;

	public override function getName():String return modName;

	public override function doesUpdate():Bool return modUpdate;

	public override function getModType():ModifierType return modType;

	public override function getSubmods():Array<String>
	{
		if (script != null)
		{
			var res:Dynamic = script.call('getSubmods');
			if (res != null && Std.isOfType(res, Array))
				return cast res;
		}
		return [];
	}

	public override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (script != null)
		{
			var res:Dynamic = script.call('getPos', [time, visualDiff, timeDiff, beat, pos, data, player, obj]);
			if (res != null && Std.isOfType(res, Vector3))
				return cast res;
		}
		return pos;
	}

	public override function update(elapsed:Float):Void
	{
		if (script != null) script.call('onUpdate', [elapsed]);
	}

	public override function updateNote(beat:Float, obj:Dynamic, pos:Vector3, player:Int):Void
	{
		if (script != null) script.call('updateNote', [beat, obj, pos, player]);
	}

	public override function updateReceptor(beat:Float, obj:Dynamic, pos:Vector3, player:Int):Void
	{
		if (script != null) script.call('updateReceptor', [beat, obj, pos, player]);
	}

	public override function updateNoteSplash(beat:Float, obj:Dynamic, pos:Vector3, player:Int):Void
	{
		if (script != null) script.call('updateNoteSplash', [beat, obj, pos, player]);
	}

	public override function updateSustainSplash(beat:Float, obj:Dynamic, pos:Vector3, player:Int):Void
	{
		if (script != null) script.call('updateSustainSplash', [beat, obj, pos, player]);
	}

	public override function destroy():Void
	{
		if (script != null)
		{
			script.call('destroy');
			script = null;
		}
		super.destroy();
	}
}

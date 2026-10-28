package gameplay.modchart;

import flixel.FlxSprite;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import core.utils.Vector3;

enum abstract ModifierType(String)
{
	var NOTE_MOD; // used when the mod moves notes
	var MISC_MOD; // used for anything else
}

enum abstract ModifierOrder(Int) to Int
{
	var FIRST = -1000;
	var PRE_REVERSE = -3;
	var REVERSE = -2;
	var POST_REVERSE = -1;
	var DEFAULT = 0;
	var LAST = 1000;
}

class Modifier implements IFlxDestroyable
{
	public var modMgr:ModManager;
	public var percents:Array<Float> = [0, 0];
	public var submods:Map<String, Modifier> = [];
	public var parent:Modifier; // for submods
	public var active:Bool = false; // used for performance reasons

	public function getModType():ModifierType return MISC_MOD;

	public function doesUpdate():Bool return getModType() == MISC_MOD;

	public function shouldExecute(player:Int, value:Float):Bool
	{
		return value != 0;
	}

	public function getOrder():Int return DEFAULT;

	public function getName():String
	{
		throw new haxe.exceptions.NotImplementedException();
		return '';
	}

	public function getValue(player:Int):Float 
	{
		if (player < 0 || player >= percents.length) return 0;
		return percents[player];
	}

	public function getPercent(player:Int):Float return getValue(player) * 100;

	public function setValue(value:Float, player:Int = -1)
	{
		if (player == -1)
		{
			for (idx in 0...percents.length)
				percents[idx] = value;
		}
		else
		{
			while (percents.length <= player)
				percents.push(0);
			percents[player] = value;
		}
	}

	public function setPercent(percent:Float, player:Int = -1) setValue(percent * 0.01, player);

	public function getSubmods():Array<String> return [];

	public function getSubmodPercent(modName:String, player:Int):Float
	{
		if (submods.exists(modName)) return submods.get(modName).getPercent(player);
		else return 0;
	}

	public function getSubmodValue(modName:String, player:Int):Float
	{
		if (submods.exists(modName)) return submods.get(modName).getValue(player);
		else return 0;
	}

	public function setSubmodPercent(modName:String, endPercent:Float, player:Int) return submods.get(modName).setPercent(endPercent, player);

	public function setSubmodValue(modName:String, endValue:Float, player:Int) return submods.get(modName).setValue(endValue, player);

	public function new(modMgr:ModManager, ?parent:Modifier)
	{
		this.modMgr = modMgr;
		this.parent = parent;
		for (submod in getSubmods())
			submods.set(submod, new SubModifier(submod, modMgr, this));
	}

	public function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int) {}

	public function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int) {}

	public function updateNoteSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int) {}

	public function updateSustainSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int) {}

	public function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3 return pos;

	public function update(elapsed:Float) {}

	public function destroy():Void {}
}

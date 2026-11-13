// NightmareVision modchart system implementation for GAZE BUILD / K-Slice Engine
package gameplay.modchart;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;

import core.utils.Vector3;
import gameplay.modchart.modifiers.*;
import gameplay.modchart.events.*;
import gameplay.objects.FunkinArrows.Note;
import gameplay.objects.FunkinArrows.UIStaticArrow;
import gameplay.PlayState;
import core.utils.CoolUtil;
import sys.FileSystem;
using StringTools;

class ModManager implements IFlxDestroyable
{
	public function registerEssentialModifiers()
	{
		quickRegister(new ReverseModifier(this));
		quickRegister(new ConfusionModifier(this));
		quickRegister(new PerspectiveModifier(this));
		quickRegister(new OpponentModifier(this));
	}

	public function registerDefaultModifiers()
	{
		final quickRegs:Array<Class<NoteModifier>> = [
			FlipModifier,
			InvertModifier,
			DrunkModifier,
			BeatModifier,
			AlphaModifier,
			ReceptorScrollModifier,
			ScaleModifier,
			TransformModifier,
			InfinitePathModifier,
			AccelModifier,
			XModifier
		];

		for (mod in quickRegs)
			quickRegister(Type.createInstance(mod, [this]));

		quickRegister(new RotateModifier(this));
		quickRegister(new RotateModifier(this, 'center', Vector3.get(FlxG.width * 0.5, FlxG.height * 0.5)));
		quickRegister(new LocalRotateModifier(this, 'local'));
		quickRegister(new SubModifier("noteSpawnTime", this));
		setValue("noteSpawnTime", 2000);
		setValue("xmod", 1);
		for (i in 0...keys)
			setValue('xmod$i', 1);
	}

	public function registerScriptedModifiers()
	{
		var dirs:Array<String> = ['assets/scripts/modifiers'];
		if (core.scripting.Mods.currentModDirectory != null && core.scripting.Mods.currentModDirectory != '')
		{
			dirs.unshift('mods/' + core.scripting.Mods.currentModDirectory + '/scripts/modifiers');
		}

		for (dir in dirs)
		{
			if (FileSystem.exists(dir))
			{
				for (file in FileSystem.readDirectory(dir))
				{
					if (file.endsWith('.hx'))
					{
						var name = file.substr(0, file.length - 3);
						quickRegister(new ScriptedModifier(this, name));
						Logger.log('Registered scripted modifier: $name');
					}
				}
			}
		}
	}

	private var state:PlayState;

	public var lanes:Int = 2;
	public var keys:Int = 4;
	public var receptors:Array<Array<UIStaticArrow>> = [];
	public var timeline:EventTimeline = new EventTimeline();

	public var notemodRegister:Map<String, Modifier> = [];
	public var miscmodRegister:Map<String, Modifier> = [];
	public var register:Map<String, Modifier> = [];
	public var modArray:Array<Modifier> = [];

	public var activeMods:Array<Array<String>> = [[], []];
	public var activeNoteMods:Array<Array<Modifier>> = [[], []];

	public function rebuildActiveNoteMods(player:Int):Void
	{
		while (activeNoteMods.length <= player) activeNoteMods.push([]);
		var list:Array<Modifier> = [];
		if (player < activeMods.length && activeMods[player] != null)
		{
			for (name in activeMods[player])
			{
				var mod = notemodRegister.get(name);
				if (mod != null && !list.contains(mod))
					list.push(mod);
			}
		}
		activeNoteMods[player] = list;
	}

	inline public function quickRegister(mod:Modifier) registerMod(mod.getName(), mod);

	public function registerMod(modName:String, mod:Modifier, registerSubmods:Bool = true)
	{
		final isNoteMod:Bool = (mod.getModType() == NOTE_MOD);
		final modRegister:Map<String, Modifier> = (isNoteMod ? notemodRegister : miscmodRegister);

		if (modRegister.exists(modName)) return Logger.log('Modifier "$modName" is already registered', WARN);

		modRegister.set(modName, mod);
		register.set(modName, mod);
		timeline.addMod(modName);
		modArray.push(mod);

		if (registerSubmods)
		{
			for (name in mod.submods.keys())
			{
				var submod = mod.submods.get(name);
				quickRegister(submod);
			}
		}

		setValue(modName, 0);
		modArray.sort((a, b) -> Std.int(a.getOrder() - b.getOrder()));
	}

	inline public function get(modName:String) return register.get(modName);

	inline public function getPercent(modName:String, player:Int):Float return register.exists(modName) ? register.get(modName).getPercent(player) : 0.0;

	inline public function getValue(modName:String, player:Int):Float return register.exists(modName) ? register.get(modName).getValue(player) : 0.0;

	inline public function setPercent(modName:String, val:Float, player:Int = -1) setValue(modName, val / 100, player);

	public function setValue(modName:String, val:Float, player:Int = -1)
	{
		if (player == -1)
		{
			for (pN in 0...lanes)
				setValue(modName, val, pN);
		}
		else
		{
			var daMod = register.get(modName);
			if (daMod == null)
			{
				FlxG.log.error('mod [$modName] is not real or was not registered');
				return;
			}

			var mod = daMod.parent == null ? daMod : daMod.parent;
			var name = mod.getName();

			while (activeMods.length <= player) activeMods.push([]);
			if (activeMods[player] == null) activeMods[player] = [];

			register.get(modName).setValue(val, player);

			if (!activeMods[player].contains(name) && mod.shouldExecute(player, val))
			{
				if (daMod.getName() != name) activeMods[player].push(daMod.getName());
				activeMods[player].push(name);
			}
			else if (!mod.shouldExecute(player, val))
			{
				var modParent = daMod.parent;
				if (modParent == null)
				{
					for (name => mod in daMod.submods)
					{
						modParent = daMod;
						break;
					}
				}
				if (daMod != modParent) activeMods[player].remove(daMod.getName());
				if (modParent != null)
				{
					if (modParent.shouldExecute(player, modParent.getValue(player)))
					{
						activeMods[player].sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
						rebuildActiveNoteMods(player);
						return;
					}
					for (subname => submod in modParent.submods)
					{
						if (submod.shouldExecute(player, submod.getValue(player)))
						{
							activeMods[player].sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
							rebuildActiveNoteMods(player);
							return;
						}
					}
					activeMods[player].remove(modParent.getName());
				}
				else activeMods[player].remove(daMod.getName());
			}

			activeMods[player].sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
			rebuildActiveNoteMods(player);
		}
	}

	public function new(state:PlayState)
	{
		this.state = state;
	}

	public function update(elapsed:Float)
	{
		for (mod in modArray)
		{
			if (mod.active && mod.doesUpdate()) mod.update(elapsed);
		}
	}

	public function updateTimeline(curStep:Float) timeline.update(curStep);

	public inline function getBaseX(direction:Int, player:Int):Float
	{
		return (getCenterX(player, keys) + getStrumX(direction, keys));
	}

	public static inline function getCenterX(player:Int, keys:Int):Float
	{
		if (Init.trueSettings.get('Centered Notefield') && player == 0)
		{
			return (FlxG.width * 0.5 - 3);
		}
		return switch (player)
		{
			case 0:
				(FlxG.width - Note.swagWidth * (keys / 2) - 100 - 3);
			case 1:
				(Note.swagWidth * (keys / 2) + 100 - 3);
			default:
				(FlxG.width * 0.5 - 3);
		}
	}

	public static inline function getStrumX(direction:Int, keys:Int):Float
	{
		return (Note.swagWidth * (direction - (keys / 2) + .5));
	}

	public static inline function getBaseY():Float
	{
		return (Note.swagWidth * .5 + 50);
	}

	public function updateObject(beat:Float, obj:FlxSprite, pos:Vector3, player:Int)
	{
		final isNote:Bool = (obj is Note);
		final note:Note = isNote ? cast obj : null;

		obj.x = (pos.x - obj.width * .5);

		if (note != null && note.isSustainNote)
		{
			note.y = pos.y;
		}
		else
		{
			obj.y = (pos.y - obj.height * .5);
		}

		if (player < activeNoteMods.length && activeNoteMods[player] != null)
		{
			for (mod in activeNoteMods[player])
			{
				if (!obj.active) break;
				if (isNote) mod.updateNote(beat, note, pos, player);
				else if (obj is UIStaticArrow) mod.updateReceptor(beat, cast obj, pos, player);
				else mod.updateNoteSplash(beat, obj, pos, player);
			}
		}

		obj.centerOrigin();
		obj.centerOffsets();

		if (note != null)
		{
			if (note.isSustainNote)
			{
				note.origin.y = 0;
				note.offset.y = 0;
			}
		}
	}

	public inline function getBaseVisPosD(diff:Float, songSpeed:Float = 1.0):Float
	{
		return (0.45 * (diff) * songSpeed);
	}

	public inline function getVisPos(songPos:Float = 0, strumTime:Float = 0, songSpeed:Float = 1.0):Float
	{
		return -getBaseVisPosD(songPos - strumTime, songSpeed);
	}

	public function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, data:Int, player:Int, obj:FlxSprite, ?exclusions:Array<String>, ?pos:Vector3):Vector3
	{
		if (pos == null) pos = Vector3.get();

		if (!obj.active) return pos;

		pos.setTo(getBaseX(data, player), getBaseY() + diff, 0);

		if (player < activeNoteMods.length && activeNoteMods[player] != null)
		{
			for (mod in activeNoteMods[player])
			{
				if (!obj.active) break;
				if (exclusions != null && exclusions.contains(mod.getName())) continue;
				pos = mod.getPos(time, diff, tDiff, beat, pos, data, player, obj);
			}
		}

		return pos;
	}

	public function queueEaseP(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
	{
		queueEase(step, endStep, modName, percent * 0.01, style, player, startVal != null ? startVal * 0.01 : null);
	}

	public function queueSetP(step:Float, modName:String, percent:Float, player:Int = -1)
	{
		queueSet(step, modName, percent * 0.01, player);
	}

	public function queueEase(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
	{
		if (player == -1)
		{
			for (p in 0...lanes)
			{
				queueEase(step, endStep, modName, target, style, p, startVal);
			}
		}
		else
		{
			final easeFunc = CoolUtil.getEaseFromString(style);
			timeline.addEvent(new EaseEvent(step, endStep, modName, target, easeFunc, player, this, startVal));
		}
	}

	public function queueSet(step:Float, modName:String, target:Float, player:Int = -1)
	{
		if (player == -1)
		{
			for (p in 0...lanes)
			{
				queueSet(step, modName, target, p);
			}
		}
		else
		{
			timeline.addEvent(new SetEvent(step, modName, target, player, this));
		}
	}

	public function queueFunc(step:Float, endStep:Float, callback:(CallbackEvent, Float) -> Void)
	{
		timeline.addEvent(new StepCallbackEvent(step, endStep, callback, this));
	}

	public function queueFuncOnce(step:Float, callback:(CallbackEvent, Float) -> Void)
	{
		timeline.addEvent(new CallbackEvent(step, callback, this));
	}

	public function destroy():Void
	{
		modArray = FlxDestroyUtil.destroyArray(modArray);
	}
}

package funkin.game.modchart.modifiers;

import flixel.FlxG;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.utils.MathUtil;
import funkin.states.PlayState;
import backend.Conductor;

class AlphaModifier extends NoteModifier
{
	override function getName():String return 'stealth';

	public static var fadeDistY:Float = 120;

	public function getHiddenSudden(player:Int = -1):Float
	{
		return getSubmodValue("hidden", player) * getSubmodValue("sudden", player);
	}

	public function getHiddenEnd(player:Int = -1):Float
	{
		return (FlxG.height * 0.5)
			+ fadeDistY * MathUtil.scale(getHiddenSudden(player), 0, 1, -1, -1.25)
			+ (FlxG.height * 0.5) * getSubmodValue("hiddenOffset", player);
	}

	public function getHiddenStart(player:Int = -1):Float
	{
		return (FlxG.height * 0.5)
			+ fadeDistY * MathUtil.scale(getHiddenSudden(player), 0, 1, 0, -0.25)
			+ (FlxG.height * 0.5) * getSubmodValue("hiddenOffset", player);
	}

	public function getSuddenEnd(player:Int = -1):Float
	{
		return (FlxG.height * 0.5)
			+ fadeDistY * MathUtil.scale(getHiddenSudden(player), 0, 1, 1, 1.25)
			+ (FlxG.height * 0.5) * getSubmodValue("suddenOffset", player);
	}

	public function getSuddenStart(player:Int = -1):Float
	{
		return (FlxG.height * 0.5)
			+ fadeDistY * MathUtil.scale(getHiddenSudden(player), 0, 1, 0, 0.25)
			+ (FlxG.height * 0.5) * getSubmodValue("suddenOffset", player);
	}

	function getVisibility(yPos:Float, player:Int, note:Dynamic):Float
	{
		var distFromCenter = yPos;
		var alpha:Float = 0;

		if (yPos < 0 && getSubmodValue("stealthPastReceptors", player) == 0) return 1.0;

		var time = Conductor.songPosition / 1000;

		if (getSubmodValue("hidden", player) != 0)
		{
			var hiddenAdjust = MathUtil.clamp(MathUtil.scale(yPos, getHiddenStart(player), getHiddenEnd(player), 0, -1), -1, 0);
			alpha += getSubmodValue("hidden", player) * hiddenAdjust;
		}

		if (getSubmodValue("sudden", player) != 0)
		{
			var suddenAdjust = MathUtil.clamp(MathUtil.scale(yPos, getSuddenStart(player), getSuddenEnd(player), 0, -1), -1, 0);
			alpha += getSubmodValue("sudden", player) * suddenAdjust;
		}

		if (getValue(player) != 0) alpha -= getValue(player);

		if (getSubmodValue("blink", player) != 0)
		{
			var f = MathUtil.quantizeAlpha(Math.sin(time * 10), 0.3333);
			alpha += MathUtil.scale(f, 0, 1, -1, 0);
		}

		if (getSubmodValue("randomVanish", player) != 0)
		{
			var realFadeDist:Float = 240;
			alpha += MathUtil.scale(Math.abs(distFromCenter), realFadeDist, 2 * realFadeDist, -1, 0) * getSubmodValue("randomVanish", player);
		}

		return MathUtil.clamp(alpha + 1, 0, 1);
	}

	function getGlow(visible:Float):Float
	{
		var glow = MathUtil.scale(visible, 1, 0.5, 0, 1.3);
		return MathUtil.clamp(glow, 0, 1);
	}

	function getAlpha(visible:Float):Float
	{
		var alpha = MathUtil.scale(visible, 0.5, 0, 1, 0);
		return MathUtil.clamp(alpha, 0, 1);
	}

	override function shouldExecute(player:Int, val:Float):Bool return true;

	override function updateNote(beat:Float, note:Dynamic, pos:Vector3, player:Int):Void
	{
		if (note == null) return;
		var notePlayer = (note.mustPress ? 0 : 1);
		var noteSpeed:Float = (PlayState.SONG != null) ? PlayState.SONG.speed : 1.0;
		if (Reflect.hasField(note, "noteSpeed") && note.noteSpeed != 0) noteSpeed = note.noteSpeed;
		if (Reflect.hasField(note, "multSpeed")) noteSpeed *= note.multSpeed;

		var yPos:Float = modMgr.getVisPos(Conductor.songPosition, note.strumTime, noteSpeed) + 50;

		var alphaMod = (1 - getSubmodValue("alpha", notePlayer)) 
			* (1 - getSubmodValue('alpha${note.noteData}', notePlayer)) 
			* (1 - getSubmodValue("noteAlpha", notePlayer)) 
			* (1 - getSubmodValue('noteAlpha${note.noteData}', notePlayer));
		
		var alpha = getVisibility(yPos, notePlayer, note);

		if (getSubmodValue("dontUseStealthGlow", notePlayer) == 0)
		{
			note.alphaMod = getAlpha(alpha);
		}
		else
		{
			note.alphaMod = alpha;
		}

		note.alphaMod *= alphaMod;
	}

	override function updateReceptor(beat:Float, receptor:Dynamic, pos:Vector3, player:Int):Void
	{
		if (receptor == null) return;
		var alpha = (1 - getSubmodValue("alpha", player)) * (1 - getSubmodValue('alpha${receptor.noteData}', player));
		if (getSubmodValue("dark", player) != 0 || getSubmodValue('dark${receptor.noteData}', player) != 0)
		{
			alpha = alpha * (1 - getSubmodValue("dark", player)) * (1 - getSubmodValue('dark${receptor.noteData}', player));
		}
		receptor.alphaMod = alpha;
	}

	override function updateNoteSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash == null) return;
		var alpha = (1 - getSubmodValue('alpha', player)) * (1 - getSubmodValue('alpha${splash.noteData}', player));
		alpha *= (1 - getSubmodValue('noteSplashAlpha', player)) * (1 - getSubmodValue('noteSplash${splash.noteData}Alpha', player));

		splash.alpha = alpha;
	}

	override function updateSustainSplash(beat:Float, splash:Dynamic, pos:Vector3, player:Int):Void
	{
		if (splash == null) return;
		var alpha = (1 - getSubmodValue('alpha', player)) * (1 - getSubmodValue('alpha${splash.noteData}', player));
		alpha *= (1 - getSubmodValue('sustainSplashAlpha', player)) * (1 - getSubmodValue('sustainSplash${splash.noteData}Alpha', player));

		splash.alpha = alpha;
	}

	override function getSubmods():Array<String>
	{
		var subMods:Array<String> = [
			"sustainSplashAlpha",
			"noteSplashAlpha",
			"noteAlpha",
			"alpha",
			"hidden",
			"hiddenOffset",
			"sudden",
			"suddenOffset",
			"blink",
			"randomVanish",
			"dark",
			"useStealthGlow",
			"stealthPastReceptors"
		];
		for (i in 0...modMgr.keys)
		{
			subMods.push('sustainSplashAlpha$i');
			subMods.push('noteSplashAlpha$i');
			subMods.push('noteAlpha$i');
			subMods.push('alpha$i');
			subMods.push('dark$i');
		}
		return subMods;
	}
}

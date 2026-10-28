package funkin.game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import funkin.backend.math.Vector3;
import funkin.game.modchart.NoteModifier;
import funkin.game.modchart.Modifier;

@:structInit
class PathInfo
{
	public var position:Vector3;
	public var dist:Float;
	public var start:Float;
	public var end:Float;
}

class PathModifier extends NoteModifier
{
	var prefix:String;

	var moveSpeed:Float;
	var pathData:Array<Array<PathInfo>> = [];
	var totalDists:Array<Float> = [];

	override function getName():String return prefix;

	public function getMoveSpeed():Float
	{
		return 5000;
	}

	public function getPath():Array<Array<Vector3>>
	{
		return [];
	}

	public function tracePath(path:Array<Array<Vector3>>):Void
	{
		pathData.resize(0);
		totalDists.resize(0);

		for (dir in 0...path.length)
		{
			totalDists[dir] = 0;
			pathData[dir] = [];

			for (idx in 0...path[dir].length)
			{
				final pos = path[dir][idx];

				if (idx > 0)
				{
					final last = pathData[dir][idx - 1];
					final totalDist = (totalDists[dir] += Vector3.distance(last.position, pos));

					last.end = totalDist;
					last.dist = last.start - totalDist;
				}

				pathData[dir].push({
					position: pos,
					start: totalDists[dir],
					end: totalDists[dir],
					dist: 0
				});
			}
		}
	}

	public function new(modMgr:ModManager, prefix:String = 'basePath', ?parent:Modifier)
	{
		this.prefix = prefix;

		super(modMgr, parent);

		moveSpeed = getMoveSpeed();

		tracePath(getPath());
	}

	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (getValue(player) == 0 || pathData.length == 0) return pos;

		final daPath = pathData[data % pathData.length];
		final totalDist = totalDists[data % totalDists.length];

		final prefixName:String = getName();

		final curMoveSpeed:Float = (moveSpeed * (1 - getSubmodValue('${prefixName}speed', player)));
		if (curMoveSpeed == 0) return pos;

		final progress = ((getSubmodValue('${prefixName}visual', player) > 0 ? visualDiff : timeDiff) / curMoveSpeed * totalDist);
		final clampProgress = FlxMath.bound(progress, 0, totalDist);

		for (idx in 0...daPath.length - 1)
		{
			final cData = daPath[idx];
			final nData = daPath[idx + 1];

			if (clampProgress >= cData.start && clampProgress <= cData.end)
			{
				final alpha = (cData.dist != 0) ? ((cData.start - progress) / cData.dist) : 0.0;
				final interpPos:Vector3 = cData.position.lerp(nData.position, alpha);

				return pos.lerp(interpPos, getValue(player));
			}
		}

		if (daPath.length == 0) return pos;

		return pos.lerp(daPath[0].position, getValue(player));
	}

	override function getSubmods():Array<String>
	{
		final prefixName:String = getName();
		return ['${prefixName}visual', '${prefixName}speed'];
	}
}

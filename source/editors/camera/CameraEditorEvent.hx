package editors.camera;

import haxe.Json;

using StringTools;

/**
 * Data representation of a Camera Event for the Camera Editor.
 * Supports both V-Slice and Psych / Gaze serialization formats.
 */
class CameraEditorEvent
{
	public var time:Float = 0; // In milliseconds
	public var name:String = "FocusCamera"; // "FocusCamera", "ZoomCamera", "Change Character", "Play Anim"
	public var target:Int = 0; // 0: BF, 1: Dad, 2: GF, -1: Custom Point
	public var x:Float = 0; // Offset or absolute X
	public var y:Float = 0; // Offset or absolute Y
	public var zoom:Float = 1.0; // Target camera zoom
	public var duration:Float = 4.0; // In song steps (4 steps = 1 beat)
	public var ease:String = "CLASSIC"; // Easing name or CLASSIC / INSTANT
	public var mode:String = "direct"; // "direct" or "stage"
	public var layer:Int = 0; // Timeline track/layer index
	public var groupName:String = ""; // Optional Event Group name
	public var charName:String = ""; // Target character JSON name for "Change Character"
	public var animName:String = ""; // Target animation name for "Play Anim"
	public var animLock:Bool = false; // Lock flag for "Play Anim"
	public var stageName:String = ""; // Target stage name for "Change Stage"
	public var stageOptions:String = ""; // Extra flags/options (norepos, nozoom, snap, flash, zoom)

	public function new(time:Float = 0, name:String = "FocusCamera", layer:Int = 0)
	{
		this.time = time;
		this.name = name;
		this.layer = layer;
		if (name == "ZoomCamera")
		{
			this.ease = "linear";
			this.duration = 4.0;
		}
		else if (name == "Change Character" || name == "Play Anim" || name == "Change Stage")
		{
			this.duration = 1.0;
		}
	}

	public function clone():CameraEditorEvent
	{
		var copy = new CameraEditorEvent(this.time, this.name, this.layer);
		copy.target = this.target;
		copy.x = this.x;
		copy.y = this.y;
		copy.zoom = this.zoom;
		copy.duration = this.duration;
		copy.ease = this.ease;
		copy.mode = this.mode;
		copy.groupName = this.groupName;
		copy.charName = this.charName;
		copy.animName = this.animName;
		copy.animLock = this.animLock;
		copy.stageName = this.stageName;
		copy.stageOptions = this.stageOptions;
		return copy;
	}

	/**
	 * Converts the event to a V-Slice formatted dynamic object.
	 */
	public function toVSlice():Dynamic
	{
		if (name == "ZoomCamera")
		{
			return {
				t: time,
				e: "ZoomCamera",
				v: {
					zoom: zoom,
					duration: duration,
					ease: ease,
					mode: mode
				}
			};
		}
		else
		{
			return {
				t: time,
				e: "FocusCamera",
				v: {
					char: target,
					x: x,
					y: y,
					duration: duration,
					ease: ease
				}
			};
		}
	}

	/**
	 * Converts the event to a standard Psych / Gaze formatted array: [strumTime, [[eventName, val1, val2]]].
	 */
	public function toPsych():Array<Dynamic>
	{
		if (name == "ZoomCamera")
		{
			var v1 = Std.string(zoom);
			var v2 = '${duration},${ease}';
			return [time, [["ZoomCamera", v1, v2]]];
		}
		else if (name == "Change Character")
		{
			var targetStr = (target == 0) ? "bf" : ((target == 1) ? "dad" : "gf");
			var v1 = (x != 0 || y != 0) ? '$targetStr,${x},${y}' : targetStr;
			var v2 = charName;
			return [time, [["Change Character", v1, v2]]];
		}
		else if (name == "Play Anim")
		{
			var targetStr = (target == 0) ? "bf" : ((target == 1) ? "dad" : "gf");
			var v1 = targetStr;
			var v2 = animLock ? '$animName,lock' : animName;
			return [time, [["Play Anim", v1, v2]]];
		}
		else if (name == "Change Stage")
		{
			return [time, [["Change Stage", stageName, stageOptions]]];
		}
		else
		{
			var v1 = '${target},${x},${y}';
			var v2 = '${duration},${ease}';
			return [time, [["FocusCamera", v1, v2]]];
		}
	}

	/**
	 * Parses a CameraEditorEvent from a V-Slice event object or a Psych song event tuple.
	 */
	public static function fromRaw(raw:Dynamic):Null<CameraEditorEvent>
	{
		var list = parseAllFromRaw(raw);
		return (list.length > 0) ? list[0] : null;
	}

	public static function fromVSlice(raw:Dynamic):Null<CameraEditorEvent>
	{
		if (raw == null || !Reflect.hasField(raw, "e")) return null;

		var eName:String = Std.string(Reflect.field(raw, "e"));
		if (!isCameraEventName(eName)) return null;

		var eTime:Float = Reflect.hasField(raw, "t") ? Std.parseFloat(Std.string(Reflect.field(raw, "t"))) : 0.0;
		if (Math.isNaN(eTime)) eTime = 0;

		var isZoom = (eName.toLowerCase().indexOf("zoom") != -1);
		var ev = new CameraEditorEvent(eTime, isZoom ? "ZoomCamera" : "FocusCamera", isZoom ? 2 : 1);

		var val = Reflect.field(raw, "v");
		if (val != null)
		{
			if (ev.name == "ZoomCamera")
			{
				if (Std.isOfType(val, Float) || Std.isOfType(val, Int))
				{
					ev.zoom = Std.parseFloat(Std.string(val));
				}
				else if (Reflect.isObject(val))
				{
					if (Reflect.hasField(val, "zoom")) ev.zoom = Std.parseFloat(Std.string(Reflect.field(val, "zoom")));
					if (Reflect.hasField(val, "duration")) ev.duration = Std.parseFloat(Std.string(Reflect.field(val, "duration")));
					if (Reflect.hasField(val, "ease")) ev.ease = Std.string(Reflect.field(val, "ease"));
					if (Reflect.hasField(val, "mode")) ev.mode = Std.string(Reflect.field(val, "mode"));
				}
			}
			else
			{
				if (Std.isOfType(val, Int))
				{
					ev.target = Std.parseInt(Std.string(val));
				}
				else if (Reflect.isObject(val))
				{
					if (Reflect.hasField(val, "char")) ev.target = Std.parseInt(Std.string(Reflect.field(val, "char")));
					if (Reflect.hasField(val, "x")) ev.x = Std.parseFloat(Std.string(Reflect.field(val, "x")));
					if (Reflect.hasField(val, "y")) ev.y = Std.parseFloat(Std.string(Reflect.field(val, "y")));
					if (Reflect.hasField(val, "duration")) ev.duration = Std.parseFloat(Std.string(Reflect.field(val, "duration")));
					if (Reflect.hasField(val, "ease")) ev.ease = Std.string(Reflect.field(val, "ease"));
				}
			}
		}
		return ev;
	}

	public static function parseAllFromRaw(raw:Dynamic):Array<CameraEditorEvent>
	{
		var result:Array<CameraEditorEvent> = [];
		if (raw == null) return result;

		// 1. V-Slice style object: { t: Float, e: String, v: Dynamic }
		if (Reflect.hasField(raw, "e"))
		{
			var ev = fromVSlice(raw);
			if (ev != null)
				result.push(ev);
			return result;
		}

		// 2. Psych style array: [strumTime, [ [name, val1, val2] ]] or [name, val1, val2]
		if (Std.isOfType(raw, Array))
		{
			var arr:Array<Dynamic> = cast raw;
			if (arr.length >= 2 && !Std.isOfType(arr[0], String))
			{
				var t:Float = Std.parseFloat(Std.string(arr[0]));
				if (Math.isNaN(t)) t = 0;
				var subEvents:Dynamic = arr[1];
				if (subEvents != null && Std.isOfType(subEvents, Array))
				{
					var subArr:Array<Dynamic> = cast subEvents;
					for (sub in subArr)
					{
						if (sub != null && Std.isOfType(sub, Array))
						{
							var sArr:Array<Dynamic> = cast sub;
							var eName:String = (sArr.length > 0 && sArr[0] != null) ? Std.string(sArr[0]) : "";
							if (isCameraEventName(eName))
							{
								var v1:String = (sArr.length > 1 && sArr[1] != null) ? Std.string(sArr[1]) : "";
								var v2:String = (sArr.length > 2 && sArr[2] != null) ? Std.string(sArr[2]) : "";
								result.push(parsePsychEvent(t, eName, v1, v2));
							}
						}
					}
				}
			}
			else if (arr.length >= 3 && Std.isOfType(arr[0], String))
			{
				var eName:String = Std.string(arr[0]);
				if (isCameraEventName(eName))
				{
					var v1:String = (arr.length > 1 && arr[1] != null) ? Std.string(arr[1]) : "";
					var v2:String = (arr.length > 2 && arr[2] != null) ? Std.string(arr[2]) : "";
					result.push(parsePsychEvent(0, eName, v1, v2));
				}
			}
		}

		return result;
	}

	public static function isCameraEvent(raw:Dynamic):Bool
	{
		if (raw == null) return false;
		if (Reflect.hasField(raw, "e"))
		{
			var eName:String = Std.string(Reflect.field(raw, "e"));
			return isCameraEventName(eName);
		}
		if (Std.isOfType(raw, Array))
		{
			var arr:Array<Dynamic> = cast raw;
			if (arr.length >= 2 && !Std.isOfType(arr[0], String))
			{
				var subEvents:Dynamic = arr[1];
				if (subEvents != null && Std.isOfType(subEvents, Array))
				{
					for (sub in cast(subEvents, Array<Dynamic>))
					{
						if (sub != null && Std.isOfType(sub, Array))
						{
							var sArr:Array<Dynamic> = cast sub;
							if (sArr.length > 0 && isCameraEventName(Std.string(sArr[0])))
								return true;
						}
					}
				}
			}
			else if (arr.length >= 3 && Std.isOfType(arr[0], String))
			{
				return isCameraEventName(Std.string(arr[0]));
			}
		}
		return false;
	}

	public static function isCameraEventName(name:String):Bool
	{
		if (name == null) return false;
		var lower = name.toLowerCase().replace(" ", "").replace("_", "").replace("-", "").trim();
		return (lower == "focuscamera" 
			|| lower == "zoomcamera" 
			|| lower == "campos" 
			|| lower == "camposto" 
			|| lower == "addcamzoom" 
			|| lower == "addcamerazoom"
			|| lower == "changecharacter"
			|| lower == "changechar"
			|| lower == "playanim"
			|| lower == "playanimation"
			|| lower == "changestage");
	}

	public static function parsePsychEvent(time:Float, name:String, val1:String, val2:String):CameraEditorEvent
	{
		var clean = (name != null) ? name.toLowerCase().replace(" ", "").replace("_", "").replace("-", "").trim() : "";
		var isZoom = (clean == "zoomcamera" || clean == "addcamzoom" || clean == "addcamerazoom");
		var isChangeChar = (clean == "changecharacter" || clean == "changechar");
		var isPlayAnim = (clean == "playanim" || clean == "playanimation");
		var isChangeStage = (clean == "changestage");

		var evName = isZoom ? "ZoomCamera" : (isChangeChar ? "Change Character" : (isPlayAnim ? "Play Anim" : (isChangeStage ? "Change Stage" : "FocusCamera")));
		var evLayer = isZoom ? 2 : (isChangeChar ? 3 : (isPlayAnim ? 4 : (isChangeStage ? 0 : 1)));
		var ev = new CameraEditorEvent(time, evName, evLayer);

		if (isChangeStage)
		{
			ev.duration = 1.0;
			ev.stageName = (val1 != null) ? val1.trim() : "";
			ev.stageOptions = (val2 != null) ? val2.trim() : "";
		}
		else if (isZoom)
		{
			if (val1 != null && val1.trim() != "")
			{
				var z = Std.parseFloat(val1.trim());
				if (!Math.isNaN(z)) ev.zoom = z;
			}
			if (val2 != null && val2.trim() != "")
			{
				var parts = val2.split(",");
				if (parts.length >= 1)
				{
					var dur = Std.parseFloat(parts[0].trim());
					if (!Math.isNaN(dur)) ev.duration = dur;
				}
				if (parts.length >= 2)
				{
					ev.ease = parts[1].trim();
				}
			}
		}
		else if (isChangeChar)
		{
			ev.duration = 1.0;
			var parsed = parseChangeCharParams(val1, val2);
			ev.target = parsed.target;
			ev.charName = parsed.charName;
			ev.x = (parsed.x != null) ? parsed.x : 0.0;
			ev.y = (parsed.y != null) ? parsed.y : 0.0;
		}
		else if (isPlayAnim)
		{
			ev.duration = 1.0;
			var rawVal1:String = (val1 != null) ? val1.trim().toLowerCase() : "";
			if (rawVal1 == "0" || rawVal1 == "bf" || rawVal1 == "boyfriend" || rawVal1 == "player")
				ev.target = 0;
			else if (rawVal1 == "2" || rawVal1 == "gf" || rawVal1 == "girlfriend")
				ev.target = 2;
			else
				ev.target = 1;

			if (val2 != null)
			{
				var rawV2 = val2.trim();
				if (rawV2.indexOf(",") != -1)
				{
					var parts = rawV2.split(",");
					ev.animName = parts[0].trim();
					if (parts.length > 1)
					{
						var f = parts[1].trim().toLowerCase();
						if (f == "lock" || f == "locked" || f == "true" || f == "1") ev.animLock = true;
					}
				}
				else
				{
					var lowV2 = rawV2.toLowerCase();
					if (lowV2.endsWith(" lock"))
					{
						ev.animLock = true;
						ev.animName = rawV2.substr(0, rawV2.length - 5).trim();
					}
					else if (lowV2.endsWith(" locked"))
					{
						ev.animLock = true;
						ev.animName = rawV2.substr(0, rawV2.length - 7).trim();
					}
					else
					{
						ev.animName = rawV2;
					}
				}
				if (ev.animName.startsWith('"') && ev.animName.endsWith('"'))
					ev.animName = ev.animName.substring(1, ev.animName.length - 1).trim();
				if (ev.animName.startsWith("'") && ev.animName.endsWith("'"))
					ev.animName = ev.animName.substring(1, ev.animName.length - 1).trim();
			}
		}
		else
		{
			// Focus Camera: val1 = "char,x,y" or "0" or "bf"
			if (val1 != null && val1.trim() != "")
			{
				var parts = val1.split(",");
				var rawChar = parts[0].trim().toLowerCase();
				if (rawChar == "0" || rawChar == "bf" || rawChar == "boyfriend" || rawChar == "player")
					ev.target = 0;
				else if (rawChar == "1" || rawChar == "dad" || rawChar == "opponent")
					ev.target = 1;
				else if (rawChar == "2" || rawChar == "gf" || rawChar == "girlfriend")
					ev.target = 2;
				else if (rawChar == "-1" || rawChar == "custom" || rawChar == "point")
					ev.target = -1;
				else
				{
					var parsedInt = Std.parseInt(rawChar);
					if (parsedInt != null) ev.target = parsedInt;
				}

				if (parts.length >= 2)
				{
					var px = Std.parseFloat(parts[1].trim());
					if (!Math.isNaN(px)) ev.x = px;
				}
				if (parts.length >= 3)
				{
					var py = Std.parseFloat(parts[2].trim());
					if (!Math.isNaN(py)) ev.y = py;
				}
			}

			if (val2 != null && val2.trim() != "")
			{
				var parts = val2.split(",");
				if (parts.length >= 1)
				{
					var dur = Std.parseFloat(parts[0].trim());
					if (!Math.isNaN(dur)) ev.duration = dur;
				}
				if (parts.length >= 2)
				{
					ev.ease = parts[1].trim();
				}
			}
		}

		return ev;
	}

	public static function splitEventParams(raw:String):Array<String>
	{
		var out:Array<String> = [];
		if (raw == null) return out;
		var normalized = raw.replace(";", ",");
		var parts = normalized.split(",");
		for (p in parts)
		{
			var t = p.trim();
			if (t.length > 0) out.push(t);
		}
		return out;
	}

	public static function isTargetToken(raw:String):Bool
	{
		if (raw == null) return false;
		var lower = raw.trim().toLowerCase();
		return (lower == "0" || lower == "bf" || lower == "boyfriend" || lower == "player"
			|| lower == "1" || lower == "dad" || lower == "opponent"
			|| lower == "2" || lower == "gf" || lower == "girlfriend");
	}

	public static function parseTargetToken(raw:String, defaultTarget:Int = 1):Int
	{
		if (raw == null) return defaultTarget;
		var lower = raw.trim().toLowerCase();
		if (lower == "0" || lower == "bf" || lower == "boyfriend" || lower == "player")
			return 0;
		if (lower == "2" || lower == "gf" || lower == "girlfriend")
			return 2;
		if (lower == "1" || lower == "dad" || lower == "opponent")
			return 1;
		var parsed = Std.parseInt(lower);
		if (parsed != null && (parsed == 0 || parsed == 1 || parsed == 2))
			return parsed;
		return defaultTarget;
	}

	/**
	 * Parses Change Character Val1 and Val2 flexibly across all supported formats:
	 * - Val1: "1, x, y", Val2: "charName" (Standard CameraEditor / ChartEditor format)
	 * - Val1: "1", Val2: "charName, x, y" (Val2 with coordinates)
	 * - Val1: "1, charName", Val2: "x, y" (Val1 with char, Val2 with coordinates)
	 * - Val1: "1, charName, x, y", Val2: "" (Single-field format)
	 * - Val1: "charName", Val2: "1, x, y" (Swapped Val1/Val2)
	 */
	public static function parseChangeCharParams(val1:String, val2:String):{target:Int, charName:String, x:Null<Float>, y:Null<Float>}
	{
		var p1 = splitEventParams(val1);
		var p2 = splitEventParams(val2);

		var target:Int = 1;
		var charName:String = "";
		var nums:Array<Float> = [];

		var p1Start:Int = 0;
		var p2Start:Int = 0;

		if (p1.length > 0 && isTargetToken(p1[0]))
		{
			target = parseTargetToken(p1[0], 1);
			p1Start = 1;
		}
		else if (p2.length > 0 && isTargetToken(p2[0]) && (p1.length == 0 || Math.isNaN(Std.parseFloat(p1[0]))))
		{
			target = parseTargetToken(p2[0], 1);
			p2Start = 1;
		}
		else if (p1.length > 0)
		{
			target = parseTargetToken(p1[0], 1);
			if (!Math.isNaN(Std.parseFloat(p1[0])))
				p1Start = 1;
		}

		for (i in p1Start...p1.length)
		{
			var tok = p1[i];
			var f = Std.parseFloat(tok);
			if (!Math.isNaN(f))
				nums.push(f);
			else if (charName == "")
				charName = tok;
		}

		for (i in p2Start...p2.length)
		{
			var tok = p2[i];
			var f = Std.parseFloat(tok);
			if (!Math.isNaN(f) && (charName != "" || i > p2Start || p2.length >= 2))
				nums.push(f);
			else if (charName == "")
				charName = tok;
			else if (!Math.isNaN(f))
				nums.push(f);
		}

		var outX:Null<Float> = (nums.length >= 1) ? nums[0] : null;
		var outY:Null<Float> = (nums.length >= 2) ? nums[1] : null;

		return {
			target: target,
			charName: charName.trim(),
			x: outX,
			y: outY
		};
	}
}

package funkin.editors.camera;

import haxe.Json;

using StringTools;

/**
 * Data representation of a Camera Event for the Camera Editor.
 * Supports both V-Slice and Psych / Gaze serialization formats.
 */
class CameraEditorEvent
{
	public var time:Float = 0; // In milliseconds
	public var name:String = "FocusCamera"; // "FocusCamera" or "ZoomCamera"
	public var target:Int = 0; // 0: BF, 1: Dad, 2: GF, -1: Custom Point
	public var x:Float = 0; // Offset or absolute X
	public var y:Float = 0; // Offset or absolute Y
	public var zoom:Float = 1.0; // Target camera zoom
	public var duration:Float = 4.0; // In song steps (4 steps = 1 beat)
	public var ease:String = "CLASSIC"; // Easing name or CLASSIC / INSTANT
	public var mode:String = "direct"; // "direct" or "stage"
	public var layer:Int = 0; // Timeline track/layer index

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
		var lower = name.toLowerCase().trim();
		return (lower == "focuscamera" || lower == "zoomcamera" || lower == "campos" || lower == "camposto" || lower == "addcamzoom");
	}

	public static function parsePsychEvent(time:Float, name:String, val1:String, val2:String):CameraEditorEvent
	{
		var lower = name.toLowerCase().trim();
		var isZoom = (lower == "zoomcamera" || lower == "addcamzoom");
		var ev = new CameraEditorEvent(time, isZoom ? "ZoomCamera" : "FocusCamera", isZoom ? 2 : 1);

		if (isZoom)
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
}

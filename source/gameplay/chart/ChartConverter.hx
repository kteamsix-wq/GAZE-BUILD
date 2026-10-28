package gameplay.chart;

import haxe.Json;
import gameplay.chart.Song.SwagSong;
import gameplay.chart.Section.SwagSection;
#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end

using StringTools;

enum ChartEngine
{
	GAZE;
	CODENAME;
	VSLICE;
	NIGHTMARE_VISION;
	PSYCH_MODERN;
	PSYCH_LEGACY;
	KADE;
	DENPA;
	YOSHI;
	UNKNOWN;
}

typedef InternalNote =
{
	var strumTime:Float;
	var noteData:Int; // 0..3 = Opponent (Dad), 4..7 = Player (Boyfriend)
	var susLength:Float;
	var noteType:Dynamic;
}

class ChartConverter
{
	/**
	 * Detects the engine format of a parsed JSON object or raw JSON string.
	 */
	public static function detectEngine(data:Dynamic, ?rawStr:String = ""):ChartEngine
	{
		if (data == null)
			return UNKNOWN;

		// 1. YoshiCrafter Engine (explicit flags)
		if (Reflect.field(data, "version") == "YoshiCrafter Engine Chart" || Reflect.field(data, "yoshiEngine") == true)
			return YOSHI;

		// 2. Codename Engine
		if (Reflect.field(data, "codenameChart") == true)
			return CODENAME;

		if (Reflect.hasField(data, "strumLines"))
		{
			var sl:Dynamic = Reflect.field(data, "strumLines");
			if (Std.isOfType(sl, Array))
			{
				var slArr:Array<Dynamic> = cast sl;
				if (slArr.length > 0)
				{
					var hasCodenamePosition = false;
					var hasCharacters = false;
					var hasYoshiK = false;
					var hasCodenameNoteKeys = false;

					for (line in slArr)
					{
						if (line == null) continue;
						if (Reflect.hasField(line, "position") || Reflect.hasField(line, "strumCover") || Reflect.hasField(line, "strumScale") || Reflect.hasField(line, "strumLinePos"))
							hasCodenamePosition = true;
						if (Reflect.hasField(line, "characters"))
							hasCharacters = true;

						if (Reflect.hasField(line, "notes") && Std.isOfType(Reflect.field(line, "notes"), Array))
						{
							var notesList:Array<Dynamic> = cast Reflect.field(line, "notes");
							if (notesList.length > 0 && notesList[0] != null)
							{
								var fn = notesList[0];
								if (Reflect.hasField(fn, "k"))
									hasYoshiK = true;
								if (Reflect.hasField(fn, "time") || Reflect.hasField(fn, "id") || Reflect.hasField(fn, "sLen") || (Reflect.hasField(fn, "t") && Reflect.hasField(fn, "n")))
									hasCodenameNoteKeys = true;
							}
						}
					}

					if (hasYoshiK && !hasCodenamePosition && !hasCharacters)
						return YOSHI;

					if (hasCodenamePosition || hasCharacters || hasCodenameNoteKeys || Reflect.hasField(data, "stage") || Reflect.hasField(data, "meta"))
						return CODENAME;

					return CODENAME;
				}
			}
		}

		// 3. V-Slice (Base game 0.3.0+ / Erect)
		var ver = Reflect.field(data, "version");
		if (ver != null && Std.isOfType(ver, String))
		{
			var vStr:String = cast ver;
			if ((vStr.startsWith("2.") || vStr.startsWith("0.") || vStr.startsWith("1."))
				&& (Reflect.hasField(data, "notes") || Reflect.hasField(data, "scrollSpeed") || Reflect.hasField(data, "playData") || Reflect.hasField(data, "timeChanges")))
			{
				return VSLICE;
			}
		}

		if (Reflect.hasField(data, "playData") || Reflect.hasField(data, "timeChanges"))
			return VSLICE;

		if (Reflect.hasField(data, "notes") && !Reflect.hasField(data, "song"))
		{
			var notesField:Dynamic = Reflect.field(data, "notes");
			if (!Std.isOfType(notesField, Array) && (Reflect.hasField(notesField, "easy") || Reflect.hasField(notesField, "normal") || Reflect.hasField(notesField, "hard")))
				return VSLICE;
		}

		// 4. Denpa Engine
		if (Reflect.field(data, "denpaEngine") == true || Reflect.field(data, "denpaVersion") != null)
			return DENPA;

		var songObj:Dynamic = Reflect.hasField(data, "song") ? Reflect.field(data, "song") : data;
		if (songObj != null)
		{
			// Explicit Gaze Engine chart format
			if (Reflect.field(songObj, "format") == "gaze" || Reflect.field(data, "format") == "gaze")
				return GAZE;

			if (Reflect.field(songObj, "denpaVersion") != null || Reflect.field(songObj, "hudSkin") != null || Reflect.field(songObj, "ratingSkin") != null || Reflect.field(songObj, "extraKeys") != null)
				return DENPA;

			// 5. Nightmare Vision / Andromeda / Hit Single
			if (Reflect.field(songObj, "nightmareVision") == true
				|| Reflect.field(songObj, "andromeda") == true
				|| Reflect.field(data, "nightmareVision") == true
				|| Reflect.hasField(songObj, "initialSpeed")
				|| Reflect.hasField(songObj, "sliderVelocities"))
				return NIGHTMARE_VISION;

			// 6. Modern Psych Engine (1.0+ / psych_v1) vs Legacy (0.1 - 0.7.x)
			if (Reflect.field(songObj, "format") == "psych_v1" || Reflect.field(data, "format") == "psych_v1")
				return PSYCH_MODERN;

			var psychVer:Dynamic = Reflect.field(songObj, "psychEngineVersion");
			if (psychVer == null)
				psychVer = Reflect.field(data, "psychEngineVersion");
			if (psychVer != null && Std.isOfType(psychVer, String))
			{
				var pv:String = cast psychVer;
				if (isVersionAtLeast(pv, "1.0"))
					return PSYCH_MODERN;
				else
					return PSYCH_LEGACY;
			}

			// 7. Kade Engine
			if (Reflect.field(songObj, "chartVersion") != null || Reflect.field(songObj, "kadeEngine") == true || Reflect.field(data, "kadeEngine") == true)
				return KADE;

			// Section-based analysis (distinguish Legacy FNF / Kade vs Modern / Gaze)
			var notesList:Dynamic = Reflect.field(songObj, "notes");
			if (notesList != null && Std.isOfType(notesList, Array))
			{
				var sections:Array<Dynamic> = cast notesList;
				if (hasLegacyNoteFlipping(sections))
				{
					// If it has events array with Psych items, it is Psych Legacy
					var evs:Dynamic = Reflect.field(songObj, "events");
					if (evs != null && Std.isOfType(evs, Array) && cast(evs, Array<Dynamic>).length > 0)
						return PSYCH_LEGACY;
					return KADE;
				}
				else
				{
					return GAZE;
				}
			}
		}

		return UNKNOWN;
	}

	/**
	 * Checks if a version string (e.g. "0.7.1h") is at least the target ("0.7").
	 */
	private static function isVersionAtLeast(ver:String, target:String):Bool
	{
		if (ver == null) return false;
		var cleanVer = "";
		for (i in 0...ver.length)
		{
			var c = ver.charAt(i);
			if ((c >= '0' && c <= '9') || c == '.')
				cleanVer += c;
			else
				break;
		}
		var parts = cleanVer.split('.');
		var tParts = target.split('.');
		for (i in 0...tParts.length)
		{
			var v1 = (i < parts.length) ? Std.parseInt(parts[i]) : 0;
			var v2 = Std.parseInt(tParts[i]);
			if (v1 == null) v1 = 0;
			if (v2 == null) v2 = 0;
			if (v1 > v2) return true;
			if (v1 < v2) return false;
		}
		return true;
	}

	/**
	 * Heuristic to detect if a chart uses legacy section-based note flipping.
	 * In legacy charts (Base Game pre-vslice, Kade, Psych <= 0.7.x),
	 * when mustHitSection is true, the player's notes were charted on lanes 0..3!
	 * In modern charts (Gaze, Psych 1.0+ psych_v1), notes are independent of mustHitSection.
	 */
	private static function hasLegacyNoteFlipping(sections:Array<Dynamic>):Bool
	{
		var legacySectionsCount:Int = 0;
		var modernSectionsCount:Int = 0;

		for (sec in sections)
		{
			if (sec == null) continue;
			var mustHit:Bool = Reflect.field(sec, "mustHitSection") == true;
			if (!mustHit) continue;

			var secNotes:Dynamic = Reflect.field(sec, "sectionNotes");
			if (secNotes != null && Std.isOfType(secNotes, Array))
			{
				var notesArr:Array<Dynamic> = cast secNotes;
				var under4:Int = 0;
				var fourOrMore:Int = 0;

				for (n in notesArr)
				{
					if (n != null && Std.isOfType(n, Array) && cast(n, Array<Dynamic>).length >= 2)
					{
						var nData:Int = Std.int(cast(n, Array<Dynamic>)[1]);
						if (nData < 4)
							under4++;
						else
							fourOrMore++;
					}
				}

				if (under4 > fourOrMore)
					legacySectionsCount++;
				else if (fourOrMore > under4)
					modernSectionsCount++;
			}
		}

		if (legacySectionsCount + modernSectionsCount > 0)
			return legacySectionsCount > modernSectionsCount;

		return false;
	}

	/**
	 * Main conversion entry point. Converts any chart format into GAZE BUILD's native SwagSong.
	 *
	 * @param rawInput Either a raw JSON String or an already parsed Dynamic object.
	 * @param songFolder Optional name of the song folder (e.g. 'stress').
	 * @param chartPath Optional absolute/relative path to the chart file on disk.
	 * @param targetDifficulty Optional difficulty ('easy', 'normal', 'hard') to extract for V-Slice.
	 */
	public static function convert(rawInput:Dynamic, ?songFolder:String = "", ?chartPath:String = "", ?targetDifficulty:String = "normal"):SwagSong
	{
		var rawJsonStr:String = "";
		var parsedData:Dynamic = null;

		if (Std.isOfType(rawInput, String))
		{
			rawJsonStr = cleanJsonString(cast rawInput);
			try
			{
				parsedData = Json.parse(rawJsonStr);
			}
			catch (e:Dynamic)
			{
				trace('ChartConverter: Error parsing JSON: $e');
				return createFallbackSong(songFolder);
			}
		}
		else
		{
			parsedData = rawInput;
		}

		if (parsedData == null)
			return createFallbackSong(songFolder);

		var engine:ChartEngine = detectEngine(parsedData, rawJsonStr);
		#if debug
		trace('ChartConverter: Detected chart engine: $engine for song folder "$songFolder"');
		#end

		var converted:SwagSong = null;

		switch (engine)
		{
			case CODENAME:
				converted = convertCodename(parsedData, songFolder, chartPath);
			case VSLICE:
				converted = convertVSlice(parsedData, songFolder, chartPath, targetDifficulty);
			case YOSHI:
				converted = convertYoshi(parsedData, songFolder, chartPath);
			case KADE:
				converted = convertSectionBased(parsedData, songFolder, chartPath, true, false);
			case PSYCH_LEGACY:
				converted = convertSectionBased(parsedData, songFolder, chartPath, true, true);
			case NIGHTMARE_VISION:
				converted = convertSectionBased(parsedData, songFolder, chartPath, true, true);
			case DENPA:
				converted = convertDenpa(parsedData, songFolder, chartPath);
			case PSYCH_MODERN:
				converted = convertPsychModern(parsedData, songFolder, chartPath);
			case GAZE:
				converted = convertSectionBased(parsedData, songFolder, chartPath, false, true);
			case UNKNOWN:
				// Try section-based fallback, checking note flipping heuristic
				converted = convertSectionBased(parsedData, songFolder, chartPath, null, true);
		}

		if (converted == null)
			converted = createFallbackSong(songFolder);

		// Post-process to ensure all required fields are present and safe
		finalizeSong(converted, songFolder, chartPath);

		return converted;
	}

	/**
	 * Converts Codename Engine charts to SwagSong.
	 */
	private static function convertCodename(data:Dynamic, songFolder:String, chartPath:String):SwagSong
	{
		var songName:String = (songFolder != null && songFolder != "") ? songFolder : "unknown";
		var bpm:Float = 100.0;
		var speed:Float = 1.0;
		var stage:String = "stage";
		var player1:String = "bf";
		var player2:String = "dad";
		var gfVersion:String = "gf";

		if (Reflect.hasField(data, "scrollSpeed"))
		{
			var s:Dynamic = Reflect.field(data, "scrollSpeed");
			if (s != null)
			{
				var parsedSpeed = Std.parseFloat(Std.string(s));
				if (!Math.isNaN(parsedSpeed) && parsedSpeed > 0)
					speed = parsedSpeed;
			}
		}
		else if (Reflect.hasField(data, "speed"))
		{
			var s:Dynamic = Reflect.field(data, "speed");
			if (s != null)
			{
				var parsedSpeed = Std.parseFloat(Std.string(s));
				if (!Math.isNaN(parsedSpeed) && parsedSpeed > 0)
					speed = parsedSpeed;
			}
		}

		if (Reflect.hasField(data, "stage") && Reflect.field(data, "stage") != null)
			stage = Std.string(Reflect.field(data, "stage"));

		// Load companion meta.json if available
		var metaData:Dynamic = null;
		#if sys
		if (chartPath != null && chartPath != "")
		{
			var dir = Path.directory(chartPath);
			var metaPath = Path.join([dir, "meta.json"]);
			if (!FileSystem.exists(metaPath))
			{
				var parentDir = Path.directory(dir);
				metaPath = Path.join([parentDir, "meta.json"]);
			}
			if (FileSystem.exists(metaPath))
			{
				try
				{
					metaData = Json.parse(cleanJsonString(File.getContent(metaPath)));
				}
				catch (e:Dynamic) {}
			}
		}
		#end

		if (metaData == null && Reflect.hasField(data, "meta"))
			metaData = Reflect.field(data, "meta");

		if (metaData != null)
		{
			if (Reflect.hasField(metaData, "displayName") && Reflect.field(metaData, "displayName") != null)
				songName = Std.string(Reflect.field(metaData, "displayName"));
			else if (Reflect.hasField(metaData, "name") && Reflect.field(metaData, "name") != null)
				songName = Std.string(Reflect.field(metaData, "name"));

			if (Reflect.hasField(metaData, "bpm") && Reflect.field(metaData, "bpm") != null)
				bpm = Std.parseFloat(Std.string(Reflect.field(metaData, "bpm")));
		}

		if (bpm <= 0 && Reflect.hasField(data, "bpm"))
			bpm = Std.parseFloat(Std.string(Reflect.field(data, "bpm")));
		if (bpm <= 0) bpm = 100.0;

		var allNotes:Array<InternalNote> = [];
		var slArr:Array<Dynamic> = Reflect.hasField(data, "strumLines") ? cast Reflect.field(data, "strumLines") : [];

		for (sl in slArr)
		{
			if (sl == null) continue;
			var pos:String = Reflect.hasField(sl, "position") ? Std.string(Reflect.field(sl, "position")).toLowerCase().trim() : "";
			var typeVal:Null<Int> = Reflect.hasField(sl, "type") ? Std.parseInt(Std.string(Reflect.field(sl, "type"))) : null;
			var isAi:Bool = Reflect.field(sl, "ai") == true;

			// Determine if this strumline belongs to Player (lanes 4..7) or Opponent/Additional (lanes 0..3)
			var isPlayer:Bool = false;
			if (typeVal == 1 || pos == "boyfriend" || pos == "player" || pos == "bf" || pos == "right")
			{
				isPlayer = true;
			}
			else if (typeVal == 0 || typeVal == 2 || pos == "dad" || pos == "opponent" || pos == "girlfriend" || pos == "gf" || pos == "left" || pos == "middle" || pos == "center" || isAi)
			{
				isPlayer = false;
			}
			else
			{
				// Check characters array for player indications
				var chars:Array<Dynamic> = Reflect.hasField(sl, "characters") && Std.isOfType(Reflect.field(sl, "characters"), Array) ? cast Reflect.field(sl, "characters") : [];
				for (c in chars)
				{
					var cStr = Std.string(c).toLowerCase();
					if (cStr == "bf" || cStr == "boyfriend" || cStr.startsWith("bf-") || cStr.startsWith("boyfriend-"))
					{
						isPlayer = true;
						break;
					}
				}
			}

			// Character extraction
			var chars:Array<Dynamic> = Reflect.hasField(sl, "characters") && Std.isOfType(Reflect.field(sl, "characters"), Array) ? cast Reflect.field(sl, "characters") : [];
			if (chars.length > 0 && chars[0] != null)
			{
				var charName = Std.string(chars[0]);
				if (isPlayer && (player1 == "bf" || player1 == null))
					player1 = charName;
				else if (!isPlayer && pos != "girlfriend" && pos != "gf" && (player2 == "dad" || player2 == null))
					player2 = charName;
				else if ((pos == "girlfriend" || pos == "gf") && (gfVersion == "gf" || gfVersion == null))
					gfVersion = charName;
			}

			// Extract notes
			var notesArr:Array<Dynamic> = Reflect.hasField(sl, "notes") && Std.isOfType(Reflect.field(sl, "notes"), Array) ? cast Reflect.field(sl, "notes") : [];
			for (n in notesArr)
			{
				if (n == null) continue;

				var t:Float = 0.0;
				var d:Int = 0;
				var l:Float = 0.0;
				var noteType:Dynamic = 0;

				if (Std.isOfType(n, Array))
				{
					var na:Array<Dynamic> = cast n;
					t = Std.parseFloat(Std.string(na[0]));
					d = Std.parseInt(Std.string(na[1]));
					if (na.length > 2 && na[2] != null) l = Std.parseFloat(Std.string(na[2]));
					if (na.length > 3 && na[3] != null) noteType = na[3];
				}
				else
				{
					// Strum time: Codename uses "time", "t", or "strumTime"
					if (Reflect.hasField(n, "time")) t = Std.parseFloat(Std.string(Reflect.field(n, "time")));
					else if (Reflect.hasField(n, "t")) t = Std.parseFloat(Std.string(Reflect.field(n, "t")));
					else if (Reflect.hasField(n, "strumTime")) t = Std.parseFloat(Std.string(Reflect.field(n, "strumTime")));

					// Direction: Codename uses "id", "d", or "noteData"
					if (Reflect.hasField(n, "id")) d = Std.parseInt(Std.string(Reflect.field(n, "id")));
					else if (Reflect.hasField(n, "d")) d = Std.parseInt(Std.string(Reflect.field(n, "d")));
					else if (Reflect.hasField(n, "noteData")) d = Std.parseInt(Std.string(Reflect.field(n, "noteData")));

					// Sustain length: Codename uses "sLen", "l", "sustainLength", or "length"
					if (Reflect.hasField(n, "sLen")) l = Std.parseFloat(Std.string(Reflect.field(n, "sLen")));
					else if (Reflect.hasField(n, "l")) l = Std.parseFloat(Std.string(Reflect.field(n, "l")));
					else if (Reflect.hasField(n, "sustainLength")) l = Std.parseFloat(Std.string(Reflect.field(n, "sustainLength")));
					else if (Reflect.hasField(n, "length")) l = Std.parseFloat(Std.string(Reflect.field(n, "length")));

					// Note type: Codename uses "type", "n", or "noteType"
					if (Reflect.hasField(n, "type")) noteType = Reflect.field(n, "type");
					else if (Reflect.hasField(n, "n")) noteType = Reflect.field(n, "n");
					else if (Reflect.hasField(n, "noteType")) noteType = Reflect.field(n, "noteType");
					else if (Reflect.hasField(n, "k")) noteType = Reflect.field(n, "k");
				}

				if (Math.isNaN(t)) t = 0.0;
				if (t < 0) t = 0.0;
				if (Math.isNaN(l) || l < 0) l = 0.0;
				if (d < 0) d = 0;

				var lane = (d % 4) + (isPlayer ? 4 : 0);
				allNotes.push({
					strumTime: t,
					noteData: lane,
					susLength: l,
					noteType: (noteType != null && Std.string(noteType) != "" && Std.string(noteType) != "0") ? noteType : 0
				});
			}
		}

		// Convert events
		var eventsArr:Array<Dynamic> = [];
		if (Reflect.hasField(data, "events") && Std.isOfType(Reflect.field(data, "events"), Array))
		{
			var evList:Array<Dynamic> = cast Reflect.field(data, "events");
			for (ev in evList)
			{
				if (ev == null) continue;
				var evTime:Float = Reflect.hasField(ev, "time") ? Std.parseFloat(Std.string(Reflect.field(ev, "time"))) : 0.0;
				var evName:String = Reflect.hasField(ev, "name") ? Std.string(Reflect.field(ev, "name")) : "";
				var params:Array<Dynamic> = Reflect.hasField(ev, "params") && Std.isOfType(Reflect.field(ev, "params"), Array) ? cast Reflect.field(ev, "params") : [];
				var val1 = params.length > 0 ? Std.string(params[0]) : "";
				var val2 = params.length > 1 ? Std.string(params[1]) : "";
				addEventToPsychList(eventsArr, evTime, evName, val1, val2);
			}
		}

		var sections = sliceNotesIntoSections(allNotes, bpm);

		return {
			song: songName,
			notes: sections,
			events: eventsArr,
			bpm: bpm,
			needsVoices: true,
			speed: speed,
			defaultSpeed: speed,
			player1: player1,
			player2: player2,
			player3: gfVersion,
			gfVersion: gfVersion,
			stage: stage,
			noteSkin: "",
			assetModifier: "base",
			validScore: true
		};
	}

	/**
	 * Converts V-Slice (FNF Base Game 0.3.0+) charts to SwagSong.
	 */
	private static function convertVSlice(data:Dynamic, songFolder:String, chartPath:String, ?targetDifficulty:String = "normal"):SwagSong
	{
		var songName:String = (songFolder != null && songFolder != "") ? songFolder : "unknown";
		var bpm:Float = 0.0;
		var speed:Float = 1.0;
		var stage:String = "stage";
		var player1:String = "bf";
		var player2:String = "dad";
		var gfVersion:String = "gf";

		// Companion metadata resolution
		var metaData:Dynamic = null;
		#if sys
		if (chartPath != null && chartPath != "")
		{
			var dir = Path.directory(chartPath);
			var fileBase = Path.withoutExtension(Path.withoutDirectory(chartPath));
			// Look for <song>-metadata.json, metadata.json, or fileBase-metadata.json
			var candidates = [
				Path.join([dir, fileBase + "-metadata.json"]),
				Path.join([dir, "metadata.json"]),
				Path.join([dir, (songFolder != "" ? songFolder : "song") + "-metadata.json"])
			];
			for (c in candidates)
			{
				if (FileSystem.exists(c))
				{
					try
					{
						metaData = Json.parse(cleanJsonString(File.getContent(c)));
						break;
					}
					catch (e:Dynamic) {}
				}
			}
		}
		#end

		if (metaData == null && Reflect.hasField(data, "metadata"))
			metaData = Reflect.field(data, "metadata");

		if (metaData != null)
		{
			if (Reflect.hasField(metaData, "songName"))
				songName = Std.string(Reflect.field(metaData, "songName"));

			if (Reflect.hasField(metaData, "timeChanges") && Std.isOfType(Reflect.field(metaData, "timeChanges"), Array))
			{
				var tc:Array<Dynamic> = cast Reflect.field(metaData, "timeChanges");
				if (tc.length > 0 && tc[0] != null && Reflect.hasField(tc[0], "bpm"))
					bpm = Std.parseFloat(Std.string(Reflect.field(tc[0], "bpm")));
			}

			if (Reflect.hasField(metaData, "playData"))
			{
				var pd = Reflect.field(metaData, "playData");
				if (Reflect.hasField(pd, "stage") && Reflect.field(pd, "stage") != null)
					stage = Std.string(Reflect.field(pd, "stage"));

				if (Reflect.hasField(pd, "characters"))
				{
					var chars = Reflect.field(pd, "characters");
					if (Reflect.hasField(chars, "player") && Reflect.field(chars, "player") != null)
						player1 = Std.string(Reflect.field(chars, "player"));
					if (Reflect.hasField(chars, "opponent") && Reflect.field(chars, "opponent") != null)
						player2 = Std.string(Reflect.field(chars, "opponent"));
					if (Reflect.hasField(chars, "girlfriend") && Reflect.field(chars, "girlfriend") != null)
						gfVersion = Std.string(Reflect.field(chars, "girlfriend"));
				}
			}
		}

		if (bpm <= 0 && Reflect.hasField(data, "timeChanges") && Std.isOfType(Reflect.field(data, "timeChanges"), Array))
		{
			var tc:Array<Dynamic> = cast Reflect.field(data, "timeChanges");
			if (tc.length > 0 && tc[0] != null && Reflect.hasField(tc[0], "bpm"))
				bpm = Std.parseFloat(Std.string(Reflect.field(tc[0], "bpm")));
		}
		if (bpm <= 0 && Reflect.hasField(data, "bpm"))
			bpm = Std.parseFloat(Std.string(Reflect.field(data, "bpm")));
		if (bpm <= 0) bpm = 100.0;

		// Resolve scroll speed
		if (Reflect.hasField(data, "scrollSpeed"))
		{
			var ss = Reflect.field(data, "scrollSpeed");
			if (ss != null)
			{
				if (Std.isOfType(ss, Float) || Std.isOfType(ss, Int))
				{
					speed = cast ss;
				}
				else
				{
					// Difficulty object: { easy: 2.1, normal: 2.5, hard: 2.7, default: 2.5 }
					var diffKey = (targetDifficulty != null && targetDifficulty != "") ? targetDifficulty.toLowerCase() : "normal";
					if (Reflect.hasField(ss, diffKey))
						speed = Std.parseFloat(Std.string(Reflect.field(ss, diffKey)));
					else if (Reflect.hasField(ss, "default"))
						speed = Std.parseFloat(Std.string(Reflect.field(ss, "default")));
					else if (Reflect.hasField(ss, "normal"))
						speed = Std.parseFloat(Std.string(Reflect.field(ss, "normal")));
					else if (Reflect.hasField(ss, "hard"))
						speed = Std.parseFloat(Std.string(Reflect.field(ss, "hard")));
					else if (Reflect.hasField(ss, "easy"))
						speed = Std.parseFloat(Std.string(Reflect.field(ss, "easy")));
				}
			}
		}

		var allNotes:Array<InternalNote> = [];

		// Extract notes from V-Slice notes structure
		if (Reflect.hasField(data, "notes"))
		{
			var rawNotes = Reflect.field(data, "notes");
			var notesList:Array<Dynamic> = null;

			if (Std.isOfType(rawNotes, Array))
			{
				notesList = cast rawNotes;
			}
			else
			{
				// Object with difficulty keys: { easy: [...], normal: [...], hard: [...] }
				var diffKey = (targetDifficulty != null && targetDifficulty != "") ? targetDifficulty.toLowerCase() : "normal";
				if (Reflect.hasField(rawNotes, diffKey))
					notesList = cast Reflect.field(rawNotes, diffKey);
				else if (Reflect.hasField(rawNotes, "normal"))
					notesList = cast Reflect.field(rawNotes, "normal");
				else if (Reflect.hasField(rawNotes, "hard"))
					notesList = cast Reflect.field(rawNotes, "hard");
				else if (Reflect.hasField(rawNotes, "easy"))
					notesList = cast Reflect.field(rawNotes, "easy");
				else
				{
					var fields = Reflect.fields(rawNotes);
					if (fields.length > 0)
						notesList = cast Reflect.field(rawNotes, fields[0]);
				}
			}

			if (notesList != null)
			{
				for (n in notesList)
				{
					if (n == null) continue;
					var t:Float = Reflect.hasField(n, "t") ? Std.parseFloat(Std.string(Reflect.field(n, "t"))) : 0.0;
					var d:Int = Reflect.hasField(n, "d") ? Std.parseInt(Std.string(Reflect.field(n, "d"))) : 0;
					var l:Float = Reflect.hasField(n, "l") ? Std.parseFloat(Std.string(Reflect.field(n, "l"))) : 0.0;
					var k:Dynamic = Reflect.hasField(n, "k") ? Reflect.field(n, "k") : 0;

					// In V-Slice: 0..3 is Player (Boyfriend), 4..7 is Opponent (Dad).
					// In GAZE BUILD standard: 0..3 is Opponent (Dad), 4..7 is Player (Boyfriend).
					// Invert sides: 0..3 -> 4..7 (BF); 4..7 -> 0..3 (Dad)
					var lane = (d + 4) % 8;
					allNotes.push({
						strumTime: t,
						noteData: lane,
						susLength: Math.max(0, l),
						noteType: (k != null && Std.string(k) != "") ? k : 0
					});
				}
			}
		}

		// Also check strumLines in V-Slice variations
		if (allNotes.length == 0 && Reflect.hasField(data, "strumLines"))
		{
			var slArr:Array<Dynamic> = cast Reflect.field(data, "strumLines");
			for (sl in slArr)
			{
				if (sl == null) continue;
				var pos:String = Reflect.hasField(sl, "position") ? Std.string(Reflect.field(sl, "position")).toLowerCase() : "";
				var isPlayer = (pos == "player" || pos == "boyfriend" || pos == "bf" || pos == "1");
				if (pos == "" && Reflect.hasField(sl, "type"))
				{
					var tStr:String = Std.string(Reflect.field(sl, "type"));
					if (tStr == "1" || tStr == "player") isPlayer = true;
				}
				var nList:Array<Dynamic> = Reflect.hasField(sl, "notes") ? cast Reflect.field(sl, "notes") : (Reflect.hasField(sl, "noteData") ? cast Reflect.field(sl, "noteData") : []);
				for (n in nList)
				{
					if (n == null) continue;
					var t:Float = Reflect.hasField(n, "t") ? Std.parseFloat(Std.string(Reflect.field(n, "t"))) : 0.0;
					var d:Int = Reflect.hasField(n, "d") ? Std.parseInt(Std.string(Reflect.field(n, "d"))) : 0;
					var l:Float = Reflect.hasField(n, "l") ? Std.parseFloat(Std.string(Reflect.field(n, "l"))) : 0.0;
					var k:Dynamic = Reflect.hasField(n, "k") ? Reflect.field(n, "k") : 0;
					var lane = (d % 4) + (isPlayer ? 4 : 0);
					allNotes.push({
						strumTime: t,
						noteData: lane,
						susLength: Math.max(0, l),
						noteType: (k != null && Std.string(k) != "") ? k : 0
					});
				}
			}
		}

		// Sort notes chronologically before slicing
		allNotes.sort(function(a, b) {
			if (a.strumTime < b.strumTime) return -1;
			if (a.strumTime > b.strumTime) return 1;
			return 0;
		});

		// Convert events
		var eventsArr:Array<Dynamic> = [];
		if (Reflect.hasField(data, "events") && Std.isOfType(Reflect.field(data, "events"), Array))
		{
			var evList:Array<Dynamic> = cast Reflect.field(data, "events");
			for (ev in evList)
			{
				if (ev == null) continue;
				var evTime:Float = Reflect.hasField(ev, "t") ? Std.parseFloat(Std.string(Reflect.field(ev, "t"))) : 0.0;
				var evName:String = Reflect.hasField(ev, "e") ? Std.string(Reflect.field(ev, "e")) : "";
				var evVal:Dynamic = Reflect.hasField(ev, "v") ? Reflect.field(ev, "v") : "";
				var val1 = Std.isOfType(evVal, String) ? cast(evVal, String) : Std.string(evVal);
				addEventToPsychList(eventsArr, evTime, evName, val1, "");
			}
		}

		var sections = sliceNotesIntoSections(allNotes, bpm);

		return {
			song: songName,
			notes: sections,
			events: eventsArr,
			bpm: bpm,
			needsVoices: true,
			speed: speed,
			defaultSpeed: speed,
			player1: player1,
			player2: player2,
			player3: gfVersion,
			gfVersion: gfVersion,
			stage: stage,
			noteSkin: "",
			assetModifier: "base",
			validScore: true
		};
	}

	/**
	 * Converts YoshiCrafter Engine charts to SwagSong.
	 */
	private static function convertYoshi(data:Dynamic, songFolder:String, chartPath:String):SwagSong
	{
		var songName:String = (songFolder != null && songFolder != "") ? songFolder : "unknown";
		var bpm:Float = 100.0;
		var speed:Float = 1.0;
		var stage:String = "stage";
		var player1:String = "bf";
		var player2:String = "dad";
		var gfVersion:String = "gf";

		if (Reflect.hasField(data, "bpm") && Reflect.field(data, "bpm") != null)
			bpm = Std.parseFloat(Std.string(Reflect.field(data, "bpm")));
		if (bpm <= 0) bpm = 100.0;

		if (Reflect.hasField(data, "scrollSpeed") && Reflect.field(data, "scrollSpeed") != null)
			speed = Std.parseFloat(Std.string(Reflect.field(data, "scrollSpeed")));

		if (Reflect.hasField(data, "stage") && Reflect.field(data, "stage") != null)
			stage = Std.string(Reflect.field(data, "stage"));

		var allNotes:Array<InternalNote> = [];
		var slArr:Array<Dynamic> = Reflect.hasField(data, "strumLines") ? cast Reflect.field(data, "strumLines") : [];

		for (sl in slArr)
		{
			if (sl == null) continue;
			var type:Int = Reflect.hasField(sl, "type") ? Std.parseInt(Std.string(Reflect.field(sl, "type"))) : 0;
			var isPlayer:Bool = (type == 1);

			var chars:Array<Dynamic> = Reflect.hasField(sl, "characters") && Std.isOfType(Reflect.field(sl, "characters"), Array) ? cast Reflect.field(sl, "characters") : [];
			if (chars.length > 0 && chars[0] != null)
			{
				var charName = Std.string(chars[0]);
				if (type == 1) player1 = charName;
				else if (type == 0) player2 = charName;
				else if (type == 2) gfVersion = charName;
			}

			var notesArr:Array<Dynamic> = Reflect.hasField(sl, "notes") && Std.isOfType(Reflect.field(sl, "notes"), Array) ? cast Reflect.field(sl, "notes") : [];
			for (n in notesArr)
			{
				if (n == null) continue;
				var t:Float = 0.0;
				var d:Int = 0;
				var l:Float = 0.0;
				var k:Dynamic = 0;

				if (Std.isOfType(n, Array))
				{
					var na:Array<Dynamic> = cast n;
					t = Std.parseFloat(Std.string(na[0]));
					d = Std.parseInt(Std.string(na[1]));
					if (na.length > 2) l = Std.parseFloat(Std.string(na[2]));
					if (na.length > 3) k = na[3];
				}
				else
				{
					if (Reflect.hasField(n, "time")) t = Std.parseFloat(Std.string(Reflect.field(n, "time")));
					else if (Reflect.hasField(n, "t")) t = Std.parseFloat(Std.string(Reflect.field(n, "t")));
					else if (Reflect.hasField(n, "strumTime")) t = Std.parseFloat(Std.string(Reflect.field(n, "strumTime")));

					if (Reflect.hasField(n, "id")) d = Std.parseInt(Std.string(Reflect.field(n, "id")));
					else if (Reflect.hasField(n, "d")) d = Std.parseInt(Std.string(Reflect.field(n, "d")));
					else if (Reflect.hasField(n, "noteData")) d = Std.parseInt(Std.string(Reflect.field(n, "noteData")));

					if (Reflect.hasField(n, "sLen")) l = Std.parseFloat(Std.string(Reflect.field(n, "sLen")));
					else if (Reflect.hasField(n, "l")) l = Std.parseFloat(Std.string(Reflect.field(n, "l")));
					else if (Reflect.hasField(n, "sustainLength")) l = Std.parseFloat(Std.string(Reflect.field(n, "sustainLength")));
					else if (Reflect.hasField(n, "length")) l = Std.parseFloat(Std.string(Reflect.field(n, "length")));

					if (Reflect.hasField(n, "k")) k = Reflect.field(n, "k");
					else if (Reflect.hasField(n, "type")) k = Reflect.field(n, "type");
					else if (Reflect.hasField(n, "n")) k = Reflect.field(n, "n");
					else if (Reflect.hasField(n, "noteType")) k = Reflect.field(n, "noteType");
				}

				var lane = (d % 4) + (isPlayer ? 4 : 0);
				allNotes.push({
					strumTime: t,
					noteData: lane,
					susLength: Math.max(0, l),
					noteType: (k != null && Std.string(k) != "") ? k : 0
				});
			}
		}

		var eventsArr:Array<Dynamic> = [];
		if (Reflect.hasField(data, "events") && Std.isOfType(Reflect.field(data, "events"), Array))
		{
			var evList:Array<Dynamic> = cast Reflect.field(data, "events");
			for (ev in evList)
			{
				if (ev == null) continue;
				var evTime:Float = Reflect.hasField(ev, "time") ? Std.parseFloat(Std.string(Reflect.field(ev, "time"))) : 0.0;
				var evName:String = Reflect.hasField(ev, "name") ? Std.string(Reflect.field(ev, "name")) : "";
				var args:Array<Dynamic> = Reflect.hasField(ev, "args") && Std.isOfType(Reflect.field(ev, "args"), Array) ? cast Reflect.field(ev, "args") : [];
				var v1 = args.length > 0 ? Std.string(args[0]) : "";
				var v2 = args.length > 1 ? Std.string(args[1]) : "";
				addEventToPsychList(eventsArr, evTime, evName, v1, v2);
			}
		}

		var sections = sliceNotesIntoSections(allNotes, bpm);

		return {
			song: songName,
			notes: sections,
			events: eventsArr,
			bpm: bpm,
			needsVoices: true,
			speed: speed,
			defaultSpeed: speed,
			player1: player1,
			player2: player2,
			player3: gfVersion,
			gfVersion: gfVersion,
			stage: stage,
			noteSkin: "",
			assetModifier: "base",
			validScore: true
		};
	}

	/**
	 * Converts Denpa Engine charts to SwagSong.
	 */
	private static function convertDenpa(data:Dynamic, songFolder:String, chartPath:String):SwagSong
	{
		var songObj:Dynamic = Reflect.hasField(data, "song") ? Reflect.field(data, "song") : data;
		var extraKeys:Int = Reflect.hasField(songObj, "extraKeys") ? Std.parseInt(Std.string(Reflect.field(songObj, "extraKeys"))) : 4;
		if (extraKeys <= 0) extraKeys = 4;

		// Standardize notes if multi-key: ensure lanes fit within 4-key (0..3 Dad, 4..7 BF)
		return convertSectionBased(data, songFolder, chartPath, null, true, extraKeys);
	}

	/**
	 * Converts Psych Engine 1.0+ (psych_v1) charts.
	 * In native psych_v1, lanes 0..3 belong to Player and 4..7 belong to Opponent.
	 * If the chart still uses legacy section flipping, it falls back to legacy flipping.
	 */
	private static function convertPsychModern(data:Dynamic, songFolder:String, chartPath:String):SwagSong
	{
		var songObj:Dynamic = Reflect.hasField(data, "song") ? Reflect.field(data, "song") : data;
		var rawSections:Array<Dynamic> = (songObj != null && Reflect.hasField(songObj, "notes") && Std.isOfType(Reflect.field(songObj, "notes"), Array)) ? cast Reflect.field(songObj, "notes") : [];

		if (hasLegacyNoteFlipping(rawSections))
			return convertSectionBased(data, songFolder, chartPath, true, true);

		return convertSectionBased(data, songFolder, chartPath, false, true, 4, true);
	}

	/**
	 * Converts section-based charts (Psych, Kade, Legacy FNF, Denpa, NMV).
	 *
	 * @param forceFlip If true, forces legacy note flipping. If false, keeps absolute. If null, auto-detects.
	 * @param allowEvents Whether to preserve and merge Psych events.
	 * @param keysPerSide Standard number of keys per side (default 4).
	 * @param invertPlayfields Whether playfield 0 is Player and playfield 1 is Opponent (Psych 1.0 psych_v1).
	 */
	private static function convertSectionBased(data:Dynamic, songFolder:String, chartPath:String, ?forceFlip:Null<Bool> = null, ?allowEvents:Bool = true, ?keysPerSide:Int = 4, ?invertPlayfields:Bool = false):SwagSong
	{
		var songObj:Dynamic = Reflect.hasField(data, "song") ? Reflect.field(data, "song") : data;
		if (songObj == null)
			return createFallbackSong(songFolder);

		var songName:String = Reflect.hasField(songObj, "song") ? Std.string(Reflect.field(songObj, "song")) : songFolder;
		if (songName == null || songName == "" || songName == "unknown")
			songName = (songFolder != null && songFolder != "") ? songFolder : "unknown";

		var bpm:Float = Reflect.hasField(songObj, "bpm") ? Std.parseFloat(Std.string(Reflect.field(songObj, "bpm"))) : 100.0;
		if (bpm <= 0) bpm = 100.0;

		var speed:Float = Reflect.hasField(songObj, "speed") ? Std.parseFloat(Std.string(Reflect.field(songObj, "speed"))) : 1.0;
		if (speed <= 0) speed = 1.0;

		var player1:String = Reflect.hasField(songObj, "player1") && Reflect.field(songObj, "player1") != null ? Std.string(Reflect.field(songObj, "player1")) : "bf";
		var player2:String = Reflect.hasField(songObj, "player2") && Reflect.field(songObj, "player2") != null ? Std.string(Reflect.field(songObj, "player2")) : "dad";
		var gfVersion:String = Reflect.hasField(songObj, "gfVersion") && Reflect.field(songObj, "gfVersion") != null ? Std.string(Reflect.field(songObj, "gfVersion")) : (Reflect.hasField(songObj, "player3") ? Std.string(Reflect.field(songObj, "player3")) : "gf");
		var stage:String = Reflect.hasField(songObj, "stage") && Reflect.field(songObj, "stage") != null ? Std.string(Reflect.field(songObj, "stage")) : "stage";
		var needsVoices:Bool = Reflect.hasField(songObj, "needsVoices") ? (Reflect.field(songObj, "needsVoices") == true) : true;

		var rawSections:Array<Dynamic> = Reflect.hasField(songObj, "notes") && Std.isOfType(Reflect.field(songObj, "notes"), Array) ? cast Reflect.field(songObj, "notes") : [];

		// Auto-detect note flip if not explicitly specified
		var shouldFlip:Bool = (forceFlip != null) ? forceFlip : hasLegacyNoteFlipping(rawSections);

		var convertedSections:Array<SwagSection> = [];
		var eventsArr:Array<Dynamic> = [];

		for (sec in rawSections)
		{
			if (sec == null) continue;
			var mustHit:Bool = Reflect.hasField(sec, "mustHitSection") ? (Reflect.field(sec, "mustHitSection") == true) : false;
			var secBpm:Float = Reflect.hasField(sec, "bpm") ? Std.parseFloat(Std.string(Reflect.field(sec, "bpm"))) : bpm;
			var changeBpm:Bool = Reflect.hasField(sec, "changeBPM") ? (Reflect.field(sec, "changeBPM") == true) : false;
			var altAnim:Bool = Reflect.hasField(sec, "altAnim") ? (Reflect.field(sec, "altAnim") == true) : false;
			var lenInSteps:Int = Reflect.hasField(sec, "lengthInSteps") ? Std.parseInt(Std.string(Reflect.field(sec, "lengthInSteps"))) : 16;
			if (lenInSteps <= 0) lenInSteps = 16;

			var rawSecNotes:Array<Dynamic> = Reflect.hasField(sec, "sectionNotes") && Std.isOfType(Reflect.field(sec, "sectionNotes"), Array) ? cast Reflect.field(sec, "sectionNotes") : [];
			var newSecNotes:Array<Dynamic> = [];

			for (n in rawSecNotes)
			{
				if (n == null || !Std.isOfType(n, Array)) continue;
				var noteArr:Array<Dynamic> = cast n;
				if (noteArr.length < 2) continue;

				var rawStrum:Float = Std.parseFloat(Std.string(noteArr[0]));
				var rawData:Int = Std.parseInt(Std.string(noteArr[1]));
				var susLen:Float = (noteArr.length > 2 && noteArr[2] != null) ? Std.parseFloat(Std.string(noteArr[2])) : 0.0;
				var nType:Dynamic = (noteArr.length > 3 && noteArr[3] != null) ? noteArr[3] : 0;

				var normalizedData:Int = rawData;

				if (shouldFlip)
				{
					// Legacy engine: when mustHitSection is true, 0..3 is Player, 4..7 is Opponent
					var daCol = rawData % keysPerSide;
					var playfield = Std.int(rawData / keysPerSide);
					var isPlayer = (mustHit ? (playfield == 0) : (playfield == 1));

					normalizedData = isPlayer ? (daCol + 4) : daCol;
				}
				else
				{
					// Modern absolute: clamp to standard 4-key playfields (0..3 Dad, 4..7 BF)
					var daCol = rawData % keysPerSide;
					var playfield = Std.int(rawData / keysPerSide);
					if (invertPlayfields)
					{
						// In psych_v1: playfield 0 = Player (BF), playfield 1 = Opponent (Dad)
						if (playfield == 0)
							normalizedData = (daCol % 4) + 4; // Player
						else
							normalizedData = (daCol % 4); // Opponent
					}
					else
					{
						// GAZE BUILD native: playfield 0 = Opponent (Dad), playfield 1 = Player (BF)
						if (playfield == 1)
							normalizedData = (daCol % 4) + 4;
						else
							normalizedData = (daCol % 4);
					}
				}

				newSecNotes.push([rawStrum, normalizedData, Math.max(0, susLen), nType]);
			}

			// Extract section-level events (Psych 0.5.x / Andromeda / NightmareVision)
			if (allowEvents && Reflect.hasField(sec, "events") && Std.isOfType(Reflect.field(sec, "events"), Array))
			{
				var sEvents:Array<Dynamic> = cast Reflect.field(sec, "events");
				for (sev in sEvents)
				{
					if (sev == null) continue;
					var evTime:Float = Reflect.hasField(sev, "time") ? Std.parseFloat(Std.string(Reflect.field(sev, "time"))) : 0.0;
					var subEvents:Dynamic = Reflect.field(sev, "events");
					if (subEvents != null && Std.isOfType(subEvents, Array))
					{
						var subArr:Array<Dynamic> = cast subEvents;
						for (sub in subArr)
						{
							if (sub == null) continue;
							var evName:String = Reflect.hasField(sub, "name") ? Std.string(Reflect.field(sub, "name")) : "";
							var evArgs:Array<Dynamic> = Reflect.hasField(sub, "args") && Std.isOfType(Reflect.field(sub, "args"), Array) ? cast Reflect.field(sub, "args") : [];
							var val1 = evArgs.length > 0 ? Std.string(evArgs[0]) : "";
							var val2 = evArgs.length > 1 ? Std.string(evArgs[1]) : "";
							addEventToPsychList(eventsArr, evTime, evName, val1, val2);
						}
					}
				}
			}

			convertedSections.push({
				sectionNotes: newSecNotes,
				lengthInSteps: lenInSteps,
				typeOfSection: 0,
				mustHitSection: mustHit,
				bpm: secBpm,
				changeBPM: changeBpm,
				altAnim: altAnim
			});
		}

		if (convertedSections.length == 0)
		{
			convertedSections.push({
				sectionNotes: [],
				lengthInSteps: 16,
				typeOfSection: 0,
				mustHitSection: false,
				bpm: bpm,
				changeBPM: false,
				altAnim: false
			});
		}

		// Handle events
		if (allowEvents && Reflect.hasField(songObj, "events") && Std.isOfType(Reflect.field(songObj, "events"), Array))
		{
			var rawEvents:Array<Dynamic> = cast Reflect.field(songObj, "events");
			for (e in rawEvents)
			{
				if (e == null || !Std.isOfType(e, Array)) continue;
				var eArr:Array<Dynamic> = cast e;
				if (eArr.length < 2) continue;

				var eTime:Float = Std.parseFloat(Std.string(eArr[0]));
				var evList:Dynamic = eArr[1];

				if (Std.isOfType(evList, Array))
				{
					var subList:Array<Dynamic> = cast evList;
					for (sub in subList)
					{
						if (sub != null && Std.isOfType(sub, Array))
						{
							var subArr:Array<Dynamic> = cast sub;
							var eName = subArr.length > 0 ? Std.string(subArr[0]) : "";
							var v1 = subArr.length > 1 ? Std.string(subArr[1]) : "";
							var v2 = subArr.length > 2 ? Std.string(subArr[2]) : "";
							addEventToPsychList(eventsArr, eTime, eName, v1, v2);
						}
					}
				}
			}
		}

		// Check companion events.json (Psych / Denpa / NMV standard)
		#if sys
		if (chartPath != null && chartPath != "")
		{
			var dir = Path.directory(chartPath);
			var evJsonPath = Path.join([dir, "events.json"]);
			if (FileSystem.exists(evJsonPath))
			{
				try
				{
					var parsedEv = Json.parse(cleanJsonString(File.getContent(evJsonPath)));
					var evSongObj = Reflect.hasField(parsedEv, "song") ? Reflect.field(parsedEv, "song") : parsedEv;
					if (Reflect.hasField(evSongObj, "events") && Std.isOfType(Reflect.field(evSongObj, "events"), Array))
					{
						var fEvs:Array<Dynamic> = cast Reflect.field(evSongObj, "events");
						for (fe in fEvs)
						{
							if (fe != null && Std.isOfType(fe, Array) && cast(fe, Array<Dynamic>).length >= 2)
							{
								var feArr:Array<Dynamic> = cast fe;
								var fTime:Float = Std.parseFloat(Std.string(feArr[0]));
								var fSub:Dynamic = feArr[1];
								if (Std.isOfType(fSub, Array))
								{
									for (item in cast(fSub, Array<Dynamic>))
									{
										if (item != null && Std.isOfType(item, Array))
										{
											var iArr:Array<Dynamic> = cast item;
											var eName = iArr.length > 0 ? Std.string(iArr[0]) : "";
											var v1 = iArr.length > 1 ? Std.string(iArr[1]) : "";
											var v2 = iArr.length > 2 ? Std.string(iArr[2]) : "";
											addEventToPsychList(eventsArr, fTime, eName, v1, v2);
										}
									}
								}
							}
						}
					}
				}
				catch (e:Dynamic) {}
			}
		}
		#end

		// Sort events by timestamp
		eventsArr.sort(function(a:Dynamic, b:Dynamic):Int {
			var v1:Float = a[0];
			var v2:Float = b[0];
			if (v1 < v2) return -1;
			if (v1 > v2) return 1;
			return 0;
		});

		return {
			song: songName,
			notes: convertedSections,
			events: eventsArr,
			bpm: bpm,
			needsVoices: needsVoices,
			speed: speed,
			defaultSpeed: speed,
			player1: player1,
			player2: player2,
			player3: gfVersion,
			gfVersion: gfVersion,
			stage: stage,
			noteSkin: "",
			assetModifier: "base",
			validScore: true
		};
	}

	/**
	 * Divides a flat list of notes into 16-step SwagSections.
	 */
	private static function sliceNotesIntoSections(notes:Array<InternalNote>, bpm:Float):Array<SwagSection>
	{
		var sections:Array<SwagSection> = [];
		if (bpm <= 0) bpm = 100.0;

		var crochet:Float = (60.0 / bpm) * 1000.0;
		var stepCrochet:Float = crochet / 4.0;
		var sectionDuration:Float = stepCrochet * 16.0;

		// Sort notes chronologically
		notes.sort(function(a, b) {
			if (a.strumTime < b.strumTime) return -1;
			if (a.strumTime > b.strumTime) return 1;
			return 0;
		});

		var maxTime:Float = 0.0;
		for (n in notes)
		{
			var noteEnd = n.strumTime + n.susLength;
			if (noteEnd > maxTime)
				maxTime = noteEnd;
		}

		// Ensure at least 4 sections (16 bars / intro)
		var totalSections:Int = Math.ceil(maxTime / sectionDuration) + 1;
		if (totalSections < 4) totalSections = 4;

		var curNoteIdx:Int = 0;
		var lastMustHit:Bool = false;

		for (secIdx in 0...totalSections)
		{
			var secStart:Float = secIdx * sectionDuration;
			var secEnd:Float = (secIdx + 1) * sectionDuration;

			var secNotes:Array<Dynamic> = [];
			var playerNoteCount:Int = 0;
			var opponentNoteCount:Int = 0;
			var earliestNoteIsPlayer:Null<Bool> = null;

			while (curNoteIdx < notes.length && notes[curNoteIdx].strumTime < secEnd)
			{
				var note = notes[curNoteIdx];
				if (secIdx == 0 || note.strumTime >= secStart)
				{
					secNotes.push([Math.max(0, note.strumTime), note.noteData, Math.max(0, note.susLength), note.noteType]);

					var isPlayer = (note.noteData >= 4);
					if (earliestNoteIsPlayer == null)
						earliestNoteIsPlayer = isPlayer;

					if (isPlayer)
						playerNoteCount++;
					else
						opponentNoteCount++;
				}
				curNoteIdx++;
			}

			// Decide section camera target
			var secMustHit:Bool = lastMustHit;
			if (playerNoteCount > opponentNoteCount)
				secMustHit = true;
			else if (opponentNoteCount > playerNoteCount)
				secMustHit = false;
			else if (earliestNoteIsPlayer != null)
				secMustHit = earliestNoteIsPlayer;

			lastMustHit = secMustHit;

			sections.push({
				sectionNotes: secNotes,
				lengthInSteps: 16,
				typeOfSection: 0,
				mustHitSection: secMustHit,
				bpm: bpm,
				changeBPM: false,
				altAnim: false
			});
		}

		return sections;
	}

	/**
	 * Adds or merges an event entry into a Psych 2D event list [time, [[name, v1, v2], ...]].
	 */
	private static function addEventToPsychList(eventsArr:Array<Dynamic>, time:Float, name:String, v1:String, v2:String):Void
	{
		if (name == null || name.trim() == "") return;

		for (e in eventsArr)
		{
			if (e != null && Std.isOfType(e, Array) && cast(e, Array<Dynamic>).length >= 2)
			{
				var t:Float = cast(e, Array<Dynamic>)[0];
				if (Math.abs(t - time) < 1.0)
				{
					var subList:Array<Dynamic> = cast(e, Array<Dynamic>)[1];
					subList.push([name, v1, v2]);
					return;
				}
			}
		}

		// New timestamp
		eventsArr.push([time, [[name, v1, v2]]]);
	}

	/**
	 * Ensures all fields of a SwagSong are safe, non-null, and conform to GAZE BUILD's specification.
	 */
	private static function finalizeSong(song:SwagSong, songFolder:String, chartPath:String):Void
	{
		if (song.song == null || song.song == "" || song.song == "unknown")
			song.song = (songFolder != null && songFolder != "") ? songFolder : "unknown";

		if (song.bpm <= 0)
		{
			if (song.notes != null)
			{
				for (sec in song.notes)
				{
					if (sec != null && sec.bpm > 0)
					{
						song.bpm = sec.bpm;
						break;
					}
				}
			}
			if (song.bpm <= 0) song.bpm = 100.0;
		}

		if (song.speed <= 0) song.speed = 1.0;
		song.defaultSpeed = song.speed;

		if (song.player1 == null || song.player1 == "") song.player1 = "bf";
		if (song.player2 == null || song.player2 == "") song.player2 = "dad";
		if (song.gfVersion == null || song.gfVersion == "") song.gfVersion = (song.player3 != null && song.player3 != "") ? song.player3 : "gf";
		if (song.player3 == null || song.player3 == "") song.player3 = song.gfVersion;
		if (song.stage == null || song.stage == "") song.stage = "stage";
		if (song.assetModifier == null || song.assetModifier == "") song.assetModifier = "base";
		if (song.events == null) song.events = [];
		if (song.notes == null) song.notes = [];
		song.validScore = true;
	}

	/**
	 * Creates a blank safe fallback SwagSong when a chart cannot be parsed.
	 */
	public static function createFallbackSong(name:String):SwagSong
	{
		return {
			song: (name != null && name != "") ? name : "unknown",
			notes: [
				{
					sectionNotes: [],
					lengthInSteps: 16,
					typeOfSection: 0,
					mustHitSection: false,
					bpm: 100,
					changeBPM: false,
					altAnim: false
				}
			],
			events: [],
			bpm: 100,
			needsVoices: true,
			speed: 1,
			defaultSpeed: 1,
			player1: "bf",
			player2: "dad",
			player3: "gf",
			gfVersion: "gf",
			stage: "stage",
			noteSkin: "",
			assetModifier: "base",
			validScore: true
		};
	}

	/**
	 * Cleans invalid trailing characters or commas before parsing JSON.
	 */
	public static function cleanJsonString(raw:String):String
	{
		if (raw == null) return "{}";
		var s = raw.trim();

		// Remove byte order mark (BOM) if present
		if (s.charCodeAt(0) == 0xFEFF)
			s = s.substr(1);

		// Cut off any trailing garbage after the last closing brace
		var lastBrace = s.lastIndexOf("}");
		if (lastBrace != -1 && lastBrace < s.length - 1)
			s = s.substring(0, lastBrace + 1);

		return s;
	}

	/**
	 * Finds a chart file path across all supported engine layouts and directory structures.
	 */
	public static function findChartPath(songFolder:String, chartName:String):String
	{
		if (songFolder == null || chartName == null)
			return null;

		var folder = songFolder.toLowerCase();
		var chart = chartName.toLowerCase();

		var searchPaths:Array<String> = [];

		#if sys
		var curMod = core.scripting.Mods.currentModDirectory;
		if (curMod != null && curMod.length > 0)
		{
			// Mod search paths
			searchPaths.push('mods/$curMod/songs/$folder/$chart.json');
			searchPaths.push('mods/$curMod/songs/$folder/charts/$chart.json');
			searchPaths.push('mods/$curMod/songs/$folder/chart/chart.json');
			searchPaths.push('mods/$curMod/songs/$folder/$folder-chart.json');
			searchPaths.push('mods/$curMod/data/$folder/$chart.json');
		}

		// Global mods search paths
		searchPaths.push('mods/songs/$folder/$chart.json');
		searchPaths.push('mods/songs/$folder/charts/$chart.json');
		searchPaths.push('mods/songs/$folder/chart/chart.json');
		searchPaths.push('mods/songs/$folder/$folder-chart.json');
		searchPaths.push('mods/data/$folder/$chart.json');
		#end

		// Base assets search paths
		searchPaths.push('assets/songs/$folder/$chart.json');
		searchPaths.push('assets/songs/$folder/charts/$chart.json');
		searchPaths.push('assets/songs/$folder/chart/chart.json');
		searchPaths.push('assets/songs/$folder/$folder-chart.json');
		searchPaths.push('assets/data/$folder/$chart.json');

		// Handle cases where chartName has song-prefix (e.g. "stress-hard") -> check "hard.json"
		if (chart.startsWith(folder + "-"))
		{
			var diffOnly = chart.substring(folder.length + 1);
			#if sys
			if (curMod != null && curMod.length > 0)
			{
				searchPaths.push('mods/$curMod/songs/$folder/$diffOnly.json');
				searchPaths.push('mods/$curMod/songs/$folder/charts/$diffOnly.json');
				searchPaths.push('mods/$curMod/data/$folder/$diffOnly.json');
			}
			searchPaths.push('mods/songs/$folder/$diffOnly.json');
			searchPaths.push('mods/songs/$folder/charts/$diffOnly.json');
			searchPaths.push('mods/data/$folder/$diffOnly.json');
			#end
			searchPaths.push('assets/songs/$folder/$diffOnly.json');
			searchPaths.push('assets/songs/$folder/charts/$diffOnly.json');
			searchPaths.push('assets/data/$folder/$diffOnly.json');
		}

		#if sys
		for (p in searchPaths)
		{
			if (FileSystem.exists(p))
				return p;
		}
		#end

		return null;
	}

	/**
	 * Saves a converted SwagSong to disk in GAZE BUILD's standard JSON format.
	 */
	public static function saveToFile(song:SwagSong, targetPath:String):Bool
	{
		#if sys
		try
		{
			var jsonObj = { "song": song };
			var formatted = Json.stringify(jsonObj, "\t");
			var dir = Path.directory(targetPath);
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			File.saveContent(targetPath, formatted);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('ChartConverter: Error saving chart to $targetPath: $e');
			return false;
		}
		#else
		return false;
		#end
	}
}

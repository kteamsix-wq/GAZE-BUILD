package gameplay.chart;

import gameplay.objects.FunkinArrows;
import gameplay.chart.Song.SwagSong;
import gameplay.chart.ChartConverter;
import gameplay.PlayState;
import core.base.Init;

class ChartLoader
{
	/**
	 * Automatically converts any chart from Codename, V-Slice, NightmareVision, Psych, Kade, Denpa, or Yoshi to GAZE BUILD standard.
	 */
	public static function convert(rawInput:Dynamic, ?songFolder:String = "", ?chartPath:String = "", ?targetDifficulty:String = "normal"):SwagSong
	{
		return ChartConverter.convert(rawInput, songFolder, chartPath, targetDifficulty);
	}

	public static function generateChartType(songData:SwagSong, ?typeOfChart:String = "FNF"):Array<Note>
	{
		var unspawnNotes:Array<Note> = [];
		if (songData == null || songData.notes == null)
			return unspawnNotes;

		var noteData = songData.notes;
		var offset:Float = 0;
		#if !neko
		if (Init.trueSettings.exists('Offset'))
			offset = Init.trueSettings.get('Offset');
		#end

		switch (typeOfChart)
		{
			case 'forever':
				// Future implementation for forever charts
			
			default:
				// Load FNF style charts (PRE 2.8)
				for (section in noteData)
				{
					if (section == null || section.sectionNotes == null)
						continue;

					var mustHitSection:Bool = section.mustHitSection;

					for (songNotes in section.sectionNotes)
					{
						if (songNotes == null || songNotes.length < 2)
							continue; // Skip invalid note data

						var rawStrumTime:Float = songNotes[0];
						var daStrumTime:Float = rawStrumTime - offset;
						var rawNoteData:Int = Std.int(songNotes[1]);
						var daNoteData:Int = rawNoteData % 4;
						var daNoteAlt:Float = 0;

						if (songNotes.length > 3 && songNotes[3] != null)
							daNoteAlt = songNotes[3];

						var gottaHitNote:Bool = (rawNoteData > 3);

						// V-Slice Anti-Stack/Spam Logic: Prevent overlapping notes
						var isStacked = false;
						var checkAmount = Std.int(Math.min(unspawnNotes.length, 15));
						for (i in 0...checkAmount) {
							var checkNote = unspawnNotes[unspawnNotes.length - 1 - i];
							if (checkNote == null || checkNote.isSustainNote) continue;
							if (Math.abs(checkNote.strumTime - daStrumTime) < 2 && checkNote.noteData == daNoteData && checkNote.mustPress == gottaHitNote) {
								isStacked = true;
								break;
							}
						}
						if (isStacked) continue;

						var oldNote:Note = unspawnNotes.length > 0 ? unspawnNotes[unspawnNotes.length - 1] : null;

						var swagNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, daStrumTime, daNoteData, 0, daNoteAlt);
						swagNote.noteSpeed = songData.speed;
						swagNote.mustPress = gottaHitNote;
						swagNote.scrollFactor.set(0, 0);
						
						var susLength:Float = 0;
						if (songNotes.length > 2 && songNotes[2] != null)
							susLength = songNotes[2];
							
						swagNote.sustainLength = susLength;
						unspawnNotes.push(swagNote);

						var stepSusLength:Int = Math.round(susLength / Conductor.stepCrochet);
						
						if (stepSusLength > 0)
						{
							for (susNote in 0...stepSusLength)
							{
								oldNote = unspawnNotes[unspawnNotes.length - 1];
								
								var sustainTime:Float = daStrumTime + (Conductor.stepCrochet * susNote);
								var sustainNote:Note = FunkinArrows.generateArrow(PlayState.assetModifier, sustainTime, daNoteData, 0, daNoteAlt, true, oldNote);
								sustainNote.mustPress = gottaHitNote;
								sustainNote.scrollFactor.set(0, 0);
								sustainNote.sustainLength = Conductor.stepCrochet;
								sustainNote.isSustainEnd = (susNote == stepSusLength - 1);
								sustainNote.parentNote = swagNote;

								unspawnNotes.push(sustainNote);
							}
						}
					}
				}
		}

		return unspawnNotes;
	}
}

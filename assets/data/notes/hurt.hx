// Hurt Note Script
// When hit, damages the player and plays miss animation & sound!

function goodNoteHit(note, character, characterStrums) {
	// Deduct health
	if (game != null) {
		game.health -= 0.3;
	} else {
		health -= 0.3;
	}
	
	// Play miss sound
	FlxG.sound.play(Paths.soundRandom('system/miss/missnote', 1, 3), 0.7);

	// Play miss animation
	var targetChar = (character != null) ? character : (game != null ? game.boyfriend : null);
	if (targetChar != null) {
		var dirName = UIStaticArrow.getArrowFromNumber(note.noteData).toUpperCase();
		targetChar.playAnim('sing' + dirName + 'miss', true);
	}

	// Returning false prevents the standard positive rating/combo popup
	return false;
}

function noteMiss(note, character) {
	// Successfully dodging / missing a hurt note does not penalize the player!
	return false;
}

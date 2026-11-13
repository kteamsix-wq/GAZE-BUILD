package menus;

import core.base.MusicBeatState;

// aron = https://gamebanana.com/members/4735677
// vic  = https://x.com/silly4zzcat
// asta = https://x.com/AstaLimboz

class CreditsState extends MusicBeatState { 

	override function create():Void {
		super.create();

	}

	override function update(elapsed:Float):Void {
		if (controls.BACK) Main.switchState(this, new MainMenuState());

		super.update(elapsed);
	}
}

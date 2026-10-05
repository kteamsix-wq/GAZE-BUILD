package;
import backend.*;
import funkin.objects.*;
import funkin.objects.FunkinArrows;
import funkin.states.*;
import funkin.substates.*;
import funkin.editors.*;

import flixel.FlxG;
import flixel.sound.FlxSound;
import Assets;
import sys.FileSystem;

/**
	This class is used as an extension to many other forever engine stuffs, please don't delete it as it is not only exclusively used in forever engine
	custom stuffs, and is instead used globally.
**/
class Utils
{
	// set up maps and stuffs
	public static function resetMenuMusic(resetVolume:Bool = false)
	{
		// make sure the music is playing
		if (((FlxG.sound.music != null) && (!FlxG.sound.music.playing)) || (FlxG.sound.music == null))
			FlxG.sound.playMusic(Paths.music("system/freakyMenu"));
		//
	}

		public static function returnSkinAsset(asset:String, assetModifier:String = 'base', changeableSkin:String = 'default', baseLibrary:String,
			?defaultChangeableSkin:String = 'default', ?defaultBaseAsset:String = 'base'):String
	{
		var realAsset = '$baseLibrary/$changeableSkin/$assetModifier/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;
		
		realAsset = '$baseLibrary/$assetModifier/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;

		realAsset = '$baseLibrary/$changeableSkin/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;

		realAsset = '$baseLibrary/$defaultChangeableSkin/$assetModifier/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;
		
		realAsset = '$baseLibrary/$defaultChangeableSkin/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;
		
		realAsset = '$baseLibrary/$defaultBaseAsset/$asset';
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;

				realAsset = "$baseLibrary/$asset";
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;
		
		realAsset = asset;
		if (sys.FileSystem.exists(Paths.getPath('images/' + realAsset + '.png', IMAGE))) return realAsset;

		return "$baseLibrary/$changeableSkin/$assetModifier/$asset";
	}

	public static function killMusic(songsArray:Array<FlxSound>)
	{
		for (i in 0...songsArray.length)
		{
			songsArray[i].stop();
			songsArray[i].destroy();
		}
	}
}


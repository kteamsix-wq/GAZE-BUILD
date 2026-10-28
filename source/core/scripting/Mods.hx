package core.scripting;

import sys.FileSystem;

import flixel.FlxG;

class Mods {
	public static var currentModDirectory(default, set):String = 'example'; // Defaulting to example

	private static function set_currentModDirectory(value:String):String {
		currentModDirectory = value;
		if (FlxG.save.data != null) {
			FlxG.save.data.currentModDirectory = value;
			FlxG.save.flush();
		}
		return value;
	}

	public static function loadModDirectory():Void {
		if (FlxG.save.data != null && FlxG.save.data.currentModDirectory != null) {
			// Set it directly to avoid re-flushing during load
			currentModDirectory = FlxG.save.data.currentModDirectory;
		}
	}

	public static function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = 'mods/';
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
}

package backend;

import sys.FileSystem;

class Mods {
	public static var currentModDirectory:String = 'example'; // Defaulting to example

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

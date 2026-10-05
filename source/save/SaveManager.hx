package save;

import haxe.Json;
import openfl.filesystem.File;
import openfl.filesystem.FileMode;
import openfl.utils.ByteArray;
import sys.FileSystem;

class SaveManager {
    private static var savePath:String = "save/saveData.json";
    private static var data:SaveData = null;

    public static function load():Void {
        var fullPath = getFullPath();
        if (FileSystem.exists(fullPath)) {
            try {
                var raw:String = sys.io.File.getContent(fullPath);
                data = cast Json.parse(raw);
                if (data == null) data = new SaveData();
            } catch (e:Dynamic) {
                trace('Erro ao ler save: $e');
                data = new SaveData();
            }
        } else {
            data = new SaveData();
        }
    }

    public static function save():Void {
        var fullPath = getFullPath();
        var dir = fullPath.substr(0, fullPath.lastIndexOf("/"));
        if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
        try {
            var json:String = Json.stringify(data);
            sys.io.File.saveContent(fullPath, json);
        } catch (e:Dynamic) {
            trace('Erro ao escrever save: $e');
        }
    }

    public static function getData():SaveData {
        if (data == null) load();
        return data;
    }

    private static function getFullPath():String {
        var base:String = File.applicationStorageDirectory.nativePath;
        return base + "/" + savePath;
    }

    public static function setHighScore(score:Int):Void {
        if (data == null) load();
        if (score > data.highScore) data.highScore = score;
    }

    public static function unlockSong(song:String):Void {
        if (data == null) load();
        if (data.unlockedSongs.indexOf(song) == -1) data.unlockedSongs.push(song);
    }

    public static function setSetting(key:String, value:Dynamic):Void {
        if (data == null) load();
        data.settings.set(key, value);
    }

    public static function flush():Void {
        save();
    }
}

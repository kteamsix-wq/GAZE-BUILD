package save;

class SaveData {
    public var version:Int = 1;
    public var highScore:Int = 0;
    public var unlockedSongs:Array<String> = [];
    public var settings:Map<String, Dynamic> = new Map();

    public function new() {
        settings.set("volumeMusic", 0.7);
        settings.set("volumeSFX", 0.7);
        settings.set("fullscreen", false);
    }
}

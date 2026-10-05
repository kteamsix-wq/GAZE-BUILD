import flixel.FlxG;
import flixel.FlxState;
import flxanimate.frames.FlxAnimateFrames;

class TestState extends FlxState {
    override public function create():Void {
        super.create();
        var atlas = FlxAnimateFrames.fromTextureAtlas("assets/images/characters/bf");
        var names = [for(frame in atlas.frames) frame.name];
        trace(names.slice(0, 10));
        Sys.exit(0);
    }
}

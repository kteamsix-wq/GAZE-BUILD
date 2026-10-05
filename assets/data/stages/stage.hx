var wall;
var floor;
var curtains;

var path = 'backgrounds/stage/';

function create() {
    wall = new FlxSprite(0, 0);
    wall.loadGraphic(Paths.getSparrowAtlas(path + 'stageback'));
    wall.antialiasing = true;
    add(wall);

    floor = new FlxSprite(0, 0);
    floor.loadGraphic(Paths.getSparrowAtlas(path + 'stagefront'));
    floor.antialiasing = true;
    add(floor);

    curtains = new FlxSprite(0, 0);
    curtains.loadGraphic(Paths.getSparrowAtlas(path + 'stagecurtains'));
    curtains.antialiasing = true;
    add(curtains);
}

function update(elapsed) {

}

function stepHit(curStep) {

}

function beatHit(curBeat) {

}

function endSong() {

}

package gameplay.modchart.events;

class SetEvent extends ModEvent
{
	override function run(curStep:Float)
	{
		manager.setValue(modName, endVal, player);
		finished = true;
	}
}

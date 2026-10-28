package gameplay.modchart.events;

class CallbackEvent extends BaseEvent
{
	public var callback:(CallbackEvent, Float) -> Void;

	public function new(step:Float, callback:(CallbackEvent, Float) -> Void, modMgr:ModManager)
	{
		super(step, modMgr);
		this.callback = callback;
	}

	override function run(curStep:Float)
	{
		if (callback != null) callback(this, curStep);
		finished = true;
	}
}

package gameplay.modchart;

import gameplay.modchart.events.ModEvent;
import gameplay.modchart.events.BaseEvent;

class EventTimeline
{
	public var modEvents:Map<String, Array<ModEvent>> = [];
	public var events:Array<BaseEvent> = [];

	public function new() {}

	public function addMod(modName:String)
	{
		if (!modEvents.exists(modName))
			modEvents.set(modName, []);
	}

	public function addEvent(event:BaseEvent)
	{
		if ((event is ModEvent))
		{
			var modEvent:ModEvent = cast event;
			var name = modEvent.modName;
			if (!modEvents.exists(name)) addMod(name);

			if (!modEvents.get(name).contains(modEvent)) modEvents.get(name).push(modEvent);

			modEvents.get(name).sort((a, b) -> (a.executionStep < b.executionStep ? -1 : (a.executionStep > b.executionStep ? 1 : 0)));
		}
		else if (!events.contains(event))
		{
			events.push(event);
			events.sort((a, b) -> (a.executionStep < b.executionStep ? -1 : (a.executionStep > b.executionStep ? 1 : 0)));
		}
	}

	public function update(step:Float)
	{
		for (modName in modEvents.keys())
		{
			var garbage:Array<ModEvent> = [];
			var schedule = modEvents.get(modName);
			if (schedule == null) continue;

			for (event in schedule)
			{
				if (event.finished)
				{
					garbage.push(event);
					continue;
				}

				if (event.ignoreExecution) continue;

				if (step >= event.executionStep)
				{
					event.run(step);
				}
				else break;

				if (event.finished) garbage.push(event);
			}

			for (trash in garbage)
				schedule.remove(trash);
		}

		var garbage:Array<BaseEvent> = [];
		for (event in events)
		{
			if (event.finished)
			{
				garbage.push(event);
				continue;
			}

			if (event.ignoreExecution) continue;

			if (step >= event.executionStep) event.run(step);
			else break;

			if (event.finished) garbage.push(event);
		}

		for (trash in garbage)
			events.remove(trash);
	}
}

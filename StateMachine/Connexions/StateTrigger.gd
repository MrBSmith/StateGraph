extends Resource
class_name StateTrigger

@export var events : Array[StateEvent]


func find_event(event_trigger: Signal) -> StateEvent:
	for event in events:
		if event.trigger == event_trigger:
			return event
	return null



func add_event(event_trigger : Signal) -> StateEvent:
	if find_event(event_trigger) != null:
		push_warning("Couldn't create a new event, an event with the trigger %s already exists" % str(event_trigger.get_name()))
		return null
	
	var event = StateEvent.new(event_trigger, [])
	
	events.append(event)
	return event


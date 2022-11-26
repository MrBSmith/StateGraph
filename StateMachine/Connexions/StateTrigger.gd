extends Resource
class_name StateTrigger

@export var events : Array[StateEvent]


func find_event(event_trigger: String) -> StateEvent:
	for event in events:
		if event.trigger == event_trigger:
			return event
	return null



func add_event(event_trigger : String, emitter_path: NodePath) -> StateEvent:
	if find_event(event_trigger) != null:
		push_warning("Couldn't create a new event, an event with the trigger %s already exists" % event_trigger)
		return null
	
	var event = StateEvent.new()
	event.trigger = event_trigger
	event.emitter_path = emitter_path
	
	events.append(event)
	return event


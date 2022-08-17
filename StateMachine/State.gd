tool
extends Node
class_name State

# Abstract base class for a State in a StateMachine

# Defines the behaviour of the entity possesing the statemachine 
# when the entity is in this state

# The enter_state is called every time the state is entered and exit_state when it's exited
# the update_state method of the currrent state is called every physics tick,  
# by the physics_process of the StateMachine 

onready var states_machine = get_parent() if get_parent().is_class("StateMachine") else null

export var connexions_array : Array
export var standalone_trigger : Dictionary

# Defines the position of the StateNode in the StateGraph. Expressed in ratio of the container size.
export var graph_position := Vector2.ZERO

signal standalone_trigger_added
signal standalone_trigger_removed
signal entered
signal exited

#### ACCESSORS ####

func get_class() -> String : return "State"
func is_class(value: String) -> bool: return value == "State" or .is_class(value)


#### BUILT-IN ####

func _ready() -> void:
	if states_machine != null && states_machine.is_class("StateMachine"):
		states_machine.emit_signal("state_added", self)


func _exit_tree() -> void:
	if states_machine != null && states_machine.is_class("StateMachine"):
		states_machine.emit_signal("state_removed", self)


#### CALLBACKS ####


# Called when the current state of the state machine is set to this node
func enter_state() -> void:
	pass

# Called when the current state of the state machine is switched to another one
func exit_state() -> void:
	pass

# Called every frames, for real time behaviour
# Use a return "State_node_name" or return Node_reference to change the current state of the state machine at a given time
func update_state(_delta: float) -> void:
	pass



#### LOGIC ###

# Returns true if the StateMachine is in this state. 
# Check reccursivly in case of nested StateMachines/PushdownAutomata
func is_current_state() -> bool:
	if states_machine.has_method("is_current_state"):
		return states_machine.current_state == self && states_machine.is_current_state()
	else:
		return states_machine.current_state == self



#### CONDITIONS & TRIGGER LOGIC ####

func check_exit_conditions(event_trigger: String = "process") -> Object:
	for connexion in connexions_array:
		var event = trigger_find_event(connexion, event_trigger)
		if event.empty():
			continue
		
		if are_all_conditions_verified(event):
			var state = owner.get_node(connexion.to)
			return state
	return null


func connect_connexions_events(listener: Node, disconnect: bool = false) -> void:
	for connexion in connexions_array:
		for event in connexion["events"]:
			var trigger = event["trigger"]
			
			if trigger == "process":
				continue
			
			var emitter_path = event["emitter_path"]
			var emitter = get_node_or_null(emitter_path)
			
			if emitter == null:
				push_error("event emitter can't be found at path %s" % emitter_path)
			else:
				if emitter.has_signal(trigger):
					if disconnect:
						var __ = emitter.disconnect(trigger, listener, "_on_current_state_event")
					else:
						var __ = emitter.connect(trigger, listener, "_on_current_state_event", [self, connexion, event], CONNECT_REFERENCE_COUNTED)
				else:
					push_error("The emitter %s found at path %s has no signal named %s" % [emitter.name, emitter_path, trigger])


func add_connexion(to: State, connexion : Dictionary = {}) -> void:
	if !find_connexion(to).empty():
		return
	
	if connexion.empty():
		connexion = {
			"type": "connexion",
			"to": str(owner.get_path_to(to)),
			"events": []
		}
	
	if connexions_array.empty():
		connexions_array = [connexion]
	else:
		connexions_array.append(connexion)


func remove_connexion(to: State) -> void:
	var connexion_id = find_connexion_id(to)
	connexions_array.remove(connexion_id)


func add_standalone_trigger() -> void:
	if standalone_trigger.empty():
		standalone_trigger = {
			"type": "standalone_trigger",
			"events": []
		}
		
		emit_signal("standalone_trigger_added")
	else:
		push_error("Can't add a standalone trigger, the state %s already has one" % name)


func remove_standalone_trigger() -> void:
	standalone_trigger = {}
	emit_signal("standalone_trigger_removed")


func find_connexion(to: State) -> Dictionary:
	for con in connexions_array:
		if con["to"] == str(owner.get_path_to(to)):
			return con
	return {}


func find_connexion_id(to: State) -> int:
	var connexion = find_connexion(to)
	return connexions_array.find(connexion)


func trigger_find_event(trigger: Dictionary, event_trigger: String) -> Dictionary:
	for event in trigger["events"]:
		if event["trigger"] == event_trigger:
			return event
	return {}


func trigger_add_event(trigger: Dictionary, event_trigger : String = "process", emitter_path: String = str(get_path_to(owner))) -> Dictionary:
	if !trigger_find_event(trigger, event_trigger).empty():
		push_warning("Couldn't create a new event, an event with the tirgger %s already exists" % trigger)
		return {}
	
	var event = {
		"type": "event",
		"trigger": event_trigger,
		"emitter_path": emitter_path,
		"conditions": []
	}
	
	trigger["events"].append(event)
	return event


func trigger_add_condition(connexion: Dictionary, event_dict: Dictionary = {}, str_condition: String = "", target_path: NodePath = get_path_to(owner)) -> void:
	var condition = {
		"type": "condition",
		"condition": str_condition,
		"target_path": target_path
	}
	
	if event_dict.empty():
		if connexion["events"].empty():
			event_dict = trigger_add_event(connexion)
		else:
			event_dict = connexion["events"][0]
	
	event_dict["conditions"].append(condition)


func event_find_condition_index(event : Dictionary, str_condition := "", target_path: NodePath = get_path_to(owner)) -> int:
	for i in range(event["conditions"].size()):
		var cond = event["conditions"][i]
		if cond["condition"] == str_condition && cond["target_path"] == target_path:
			return i
	return -1


func are_all_conditions_verified(event: Dictionary) -> bool:
	for condition in event["conditions"]:
		if !is_condition_verified(condition):
			return false
	return true


func is_condition_verified(condition_dict: Dictionary) -> bool:
	var target = get_node(condition_dict["target_path"])
	var condition = condition_dict["condition"]
	
	var expression = Expression.new()
	expression.parse(condition)
	var result = expression.execute([], target)
	
	if expression.has_execute_failed():
		push_error("Condition execution failed, check its expression is valid")
		return false
		
	elif not result is bool:
		push_error("Condition expression didn't retruned a bool value, condition aborted (retruned false)")
		return false
	
	else:
		return result



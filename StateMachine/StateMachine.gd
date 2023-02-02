tool
extends State
class_name StateMachine

# An implementation of the Finite State Machine design pattern
# Each state must inherit State and be a child node of a StateMachine node

# Each state defines the behaviour of the entity possesing this StateMachine when the StateMachine is in this state
# You can refer to the main node using the keyword owner
# In that case the main node must be the root of the scene

# The default state is always the first child of this node, unless default_state_path has a value

# StatesMachines can also be nested
# In that case the StateMachine behave also as a state, and the enter_state callback is called recursivly

export var default_state_path : NodePath

# Set this to true if you want the default state to be null, no matter what the default_state_path value is
export var no_default_state : bool = false

# If this propery is true, the first enter_state call will be deffered after the scene owner  ready
export var deffer_first_enter_state : bool = false
var owner_ready : bool = false

var current_state : State = null
var previous_state : State = null
var default_state : State = null

# Contains the reference of the states that have a standalone trigger
var standalone_triggers_states : Array = []

# Usefull only if this instance of StateMachine is nested (ie its parent is also a StateMachine)
# When this state is entered, if this bool is true, reset the child state to the default one
export var reset_to_default : bool = false

# Called after the state have changed (After the enter_state callback)
signal state_entered(state)
signal state_entered_recursive(state)

# Called after the exit_state of the previous_state and before the enter_state of the current_state
signal state_changing(from_state, to_state)

signal state_exited(state)

#warning-ignore:unused_signal
signal state_added(state)
#warning-ignore:unused_signal
signal state_removed(state)


#### ACCESSORS ####

func is_class(value: String): return value == "StateMachine" or .is_class(value)
func get_class() -> String: return "StateMachine"


#### BUILT-IN ####


func _ready():
	if Engine.editor_hint:
		set_physics_process(false)
		return
	
	var __ = connect("state_entered", self, "_on_state_entered")
	__ = owner.connect("ready", self, "_on_owner_ready")
	
	if get_parent().is_class("StateMachine"):
		__ = connect("state_entered_recursive", get_parent(), "_on_State_state_entered_recursive")
	
	# Set the state to be the default one, unless we are in a nested StateMachine
	# Nested StateMachines shouldn't have a current_state if they are not the current_state of its parent
	default_state = get_child(0) if default_state_path.is_empty() else get_node_or_null(default_state_path)
	
	if is_nested() or no_default_state:
		set_state(null)
	else:
		set_state(default_state)
	
	# Connect all state's standalone triggers
	for child in get_children():
		if child is State:
			if !child.standalone_trigger.has("events"):
				continue
			
			for event in child.standalone_trigger["events"]:
				if event["trigger"] == "process":
					standalone_triggers_states.append(child)
				else:
					var emitter = child.get_node_or_null(event["emitter_path"])
					__ = emitter.connect(event["trigger"], self, "_on_standalone_trigger_event", [child, event])


# Call for the current state process at every frame of the physic process
func _physics_process(delta):
	if current_state == null:
		return
	
	if !is_nested() or (is_nested() && is_current_state()):
		current_state.update_state(delta)
	
	for state in standalone_triggers_states:
		for event in state.standalone_trigger["events"]:
			if event["trigger"] == "process" && state.are_all_conditions_verified(event):
				set_state(state)
				return
	
	if current_state != null:
		var new_state = current_state.check_exit_conditions()
		if new_state != null:
			set_state(new_state)


#### LOGIC ####

# Returns the current state
func get_state() -> Object:
	return current_state


func get_state_recursive() -> Object:
	if current_state.is_class("StateMachine"):
		return current_state.get_state_recursive()
	else: 
		return current_state


# Returns the name of the current state
func get_state_name() -> String:
	if current_state == null:
		return ""
	else:
		return current_state.name


# Set current_state at a new state, also set previous state, 
# and emit a signal to notify the change, to anybody needing it
# The new_state argument can either be a State or a String representing the name of the targeted State
func set_state(new_state):
	# This method can handle only String and States
	if not new_state is State and not new_state is String and new_state != null:
		return 
	
	# If the given argument is a string, get the node that has the name that correspond
	if new_state is String:
		var state_name = new_state
		
		new_state = get_node_or_null(new_state)
		
		if new_state == null and state_name != "":
			push_error("The given state %s couldn't be found" % state_name)
	
	
	# Discard the method if the new_state is the current_state
	if new_state == current_state:
		return
	
	# Use the exit state function of the current state
	if current_state != null:
		current_state.connect_connexions_events(self, true)
		current_state.exit_state()
		emit_signal("state_exited", current_state)
		current_state.emit_signal("exited")
	
	previous_state = current_state
	current_state = new_state
	
	emit_signal("state_changing", previous_state, current_state)
	
	# Use the enter_state function of the current state
	if new_state != null && (!is_nested() or new_state.is_current_state()):
		current_state.connect_connexions_events(self)
		
		if !owner_ready && deffer_first_enter_state:
			yield(owner, "ready")
		
		current_state.enter_state()
		emit_signal("state_entered", current_state)
		current_state.emit_signal("entered")


# Set the state based on the id of the state (id of the node, ie position in the hierachy)
func set_state_by_id(state_id: int):
	var state = get_child(state_id)
	if state == null:
		if state_id >= get_child_count() or state_id < 0:
			push_error("The given state_id is out of bound")
		
		elif !state.is_class("State"):
			push_error("The child of the statemachine pointed by the state_id: " + String(state_id)
			 + " does not inherit State")
	else:
		set_state(state)


func get_state_by_name(state_name: String) -> Node:
	var state = get_node_or_null(state_name)
	
	if state is State:
		return state
	else:
		return null


# Returns true if a state with the given name is a direct child of the statemachine, and inherit State
func has_state(state_name: String) -> bool:
	return get_state_by_name(state_name) != null


# Fills the given array with all the states children of this FSM
# If the recursive argument is true, this function will fetch states recursivly, meaning also nested states 
func fetch_states(array: Array, recursive: bool = false) -> void:
	for child in get_children():
		if child is State && not child in array:
			array.append(child)
			
			if recursive && child.is_class("StateMachine"):
				child.fetch_states(array, true)


func is_nested() -> bool:
	return get_parent().is_class("StateMachine")


# Set state by incrementing its id (id of the node, ie position in the hierachy)
func increment_state(increment: int = 1, wrapping : bool = true) -> void:
	if get_state() == null:
		push_error("Current state is null, cannot increment")
		return
	
	var current_state_id = get_state().get_index()
	var id = wrapi(current_state_id + increment, 0, get_child_count()) if wrapping else current_state_id + increment 
	var state = get_child(id)
	
	if state == null or not state is State:
		while(!state is State):
			if wrapping:
				id = wrapi(id + increment, 0, get_child_count())
			else:
				id += increment
			state = get_child(id)
			if state == null && !wrapping:
				break
	
	if state == null:
		print_debug("There is no node at the given id: " + String(id))
	elif !(state is State):
		print_debug("The node found at the id: " + String(id) + " does not inherit State")
	else:
		set_state(state)


func get_animation_handler() -> StateAnimationHandler:
	for child in get_children():
		if child is StateAnimationHandler:
			return child
	return null


#### NESTED STATES MACHINES LOGIC ####
# Applies only if this StateMachine instance is nested (ie if it has a StateMachine as a parent)

func enter_state() -> void:
	if (reset_to_default && current_state != default_state) or current_state == null:
		set_state(default_state)
	else:
		current_state.enter_state()


func exit_state() -> void:
	set_state(null)


func update_state(delta: float) -> void:
	if current_state != null:
		current_state.update_state(delta)


func is_current_state() -> bool:
	var parent = get_parent()
	if parent is State or (parent.is_class("StateMachine") && parent.is_nested()):
		return parent.current_state == self && parent.is_current_state()
	else:
		return true


#### SIGNAL RESPONSES ####

func _on_state_entered(_state: Node) -> void:
	emit_signal("state_entered_recursive", current_state)


func _on_State_state_entered_recursive(_state: Node) -> void:
	emit_signal("state_entered_recursive", current_state)


func _on_current_state_event(state: State, connexion: Dictionary, event: Dictionary) -> void:
	if state.are_all_conditions_verified(event):
		var dest_state = owner.get_node_or_null(connexion["to"])
		
		if dest_state == null:
			push_error("The connexion event & conditions are fullfiled, but the destination state couldn't be find, aborting")
		else:
			set_state(dest_state)


func _on_standalone_trigger_event(state: State, event: Dictionary) -> void:
	if state.are_all_conditions_verified(event):
		set_state(state)


func _on_owner_ready() -> void:
	owner_ready = true


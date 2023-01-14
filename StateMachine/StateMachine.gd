@tool
extends State
class_name StateMachine

## An implementation of the Finite State Machine design pattern[br]
## Each state must inherit State and be a child node of a StateMachine node[br]

## Each state defines the behaviour of the entity possesing this StateMachine when the StateMachine is in this state[br]
## You can refer to the main node using the keyword owner[br]
## In that case the main node must be the root of the scene[br]

## The default state is always the first child of this node, unless default_state_path has a value[br]

## StatesMachines can also be nested[br]
## In that case the StateMachine behave also as a state, and the enter_state callback is called recursivly

@export var default_state_path : NodePath

# Set this to true if you want the default state to be null, no matter what the default_state_path value is
@export var no_default_state : bool = false

# If this propery is true, the first enter_state call will be deffered after the scene owner  ready
@export var deffer_first_enter_state : bool = false
var owner_ready : bool = false

var current_state : State = null
var previous_state : State = null
var default_state : State = null

# Contains the reference of the states that have a standalone trigger
var standalone_triggers_states : Array[State]

# Usefull only if this instance of StateMachine is nested (ie its parent is also a StateMachine)
# When this state is entered, if this bool is true, reset the child state to the default one
@export var reset_to_default : bool = false

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


#### BUILT-IN ####


func _ready():
	super._ready()
	
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	
	var __ = state_entered.connect(_on_state_entered)
	__ = owner.ready.connect(_on_owner_ready)
	
	if states_machine:
		__ = state_entered_recursive.connect(states_machine._on_State_state_entered_recursive)
	
	# Set the state to be the default one, unless we are in a nested StateMachine
	# Nested StateMachines shouldn't have a current_state if they are not the current_state of its parent
	if default_state_path.is_empty():
		if get_child_count() > 0:
			default_state = get_child(0) 
	else:
		get_node_or_null(default_state_path)
	
	if is_nested() or no_default_state:
		set_state(null)
	else:
		set_state(default_state)
	
	# Connect all state's standalone triggers
	for child in get_children():
		if child is State:
			if child.standalone_trigger == null:
				continue
			
			for event in child.standalone_trigger.events:
				if event.trigger == "process":
					standalone_triggers_states.append(child)
				else:
					var emitter = child.get_node_or_null(event.emitter_path)
					__ = emitter.connect(event.trigger, _on_standalone_trigger_event.bind(child, event))


# Call for the current state process at every frame of the physic process
func _physics_process(delta):
	if current_state == null:
		return
	
	if !is_nested() or (is_nested() && is_current_state()):
		current_state.update_state(delta)
	
	for state in standalone_triggers_states:
		for event in state.standalone_trigger.events:
			if event.trigger == "process" && state.are_all_conditions_verified(event):
				set_state(state)
				return
	
	if current_state != null:
		var new_state = current_state.check_exit_conditions("process")
		if new_state != null:
			set_state(new_state)


#### LOGIC ####

# Returns the current state
func get_state() -> State:
	return current_state


func get_state_recursive() -> State:
	if current_state == null:
		return null
	
	if current_state is StateMachine:
		return current_state.get_state_recursive()
	else: 
		return current_state


# Returns the name of the current state
func get_state_name() -> String:
	if current_state == null:
		return ""
	else:
		return str(current_state.name)


## Set [member current_state]
##
## Emit a signal to notify the change, to anybody needing it
## The new_state argument can either be a [State] a [String], or a [NodePath] representing path to the state (relative to this [StateMachine]).[br]
## You can also pass it state paths, in that case, every member of the path exept for the last one must inherit [StateMachine].[br]
## For exemple: if you pass it [code]Attack/ComboA[/code] then Attack must be a [StateMachine].[br]
## Then it will set the [member current_state] to the one designated by the path, recursively if needed
func set_state(new_state) -> void:
	# This method can handle only String and States
	if not new_state is State and not new_state is String and not new_state is NodePath and new_state != null:
		return 
	
	if new_state is NodePath: new_state = String(new_state)
	
	# If the given argument is a path, set the passed state to the one designated by the path, recursively if needed
	if new_state is String or new_state is NodePath:
		var path_elem_array = new_state.split("/")
		var state_name = path_elem_array[0]
		path_elem_array.remove_at(0)
		
		var state = get_node_or_null(state_name)
		set_state(state)
		
		if !path_elem_array.is_empty() && state is StateMachine:
			state.set_state("/".join(path_elem_array))
		
		return
	
	# Discard the method if the new_state is the current_state
	if new_state == current_state:
		return
	
	if new_state != null && new_state.get_parent() != self:
		var state_path = get_path_to(new_state)
		push_error("The current state at path %s is not a direct child of %s" % [str(state_path), name])
	
	# Use the exit state function of the current state
	if current_state != null:
		current_state.connect_connections_events(self, true)
		current_state.exit_state()
		emit_signal("state_exited", current_state)
		current_state.emit_signal("exited")
	
	previous_state = current_state
	current_state = new_state
	
	if print_logs:
		var previous_state_name = str(previous_state.name) if previous_state else "null" 
		var current_state_name = str(current_state.name) if current_state else "null" 
		print("%s state_changed from %s to %s" % [str(owner.name), previous_state_name, current_state_name])
		emit_signal("state_changing", previous_state, current_state)
	
	# Use the enter_state function of the current state
	if new_state != null && (!is_nested() or new_state.is_current_state()):
		current_state.connect_connections_events(self)
		
		if !owner_ready && deffer_first_enter_state:
			await owner.ready
		
		current_state.enter_state()
		emit_signal("state_entered", current_state)
		current_state.emit_signal("entered")


# Set the state based checked the id of the state (id of the node, ie position in the hierachy)
func set_state_by_id(state_id: int):
	var state : State = get_child(state_id)
	if state == null:
		if state_id >= get_child_count() or state_id < 0:
			push_error("The given state_id is out of bound")
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
			
			if recursive && child is StateMachine:
				child.fetch_states(array, true)


func is_nested() -> bool: return states_machine != null


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
		push_error("There is no node at the given id: " + str(id))
	elif !(state is State):
		push_error("The node found at the id: " + str(id) + " does not inherit State")
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
	if states_machine == null:
		return false
	
	if states_machine.is_nested():
		return states_machine.current_state == self && states_machine.is_current_state()
	else:
		return states_machine.current_state == self


#### SIGNAL RESPONSES ####

func _on_state_entered(_state: Node) -> void:
	emit_signal("state_entered_recursive", current_state)


func _on_State_state_entered_recursive(_state: Node) -> void:
	emit_signal("state_entered_recursive", current_state)


func _on_current_state_event(state: State, connection: StateConnection, event: StateEvent) -> void:
	if event.are_all_conditions_verified(state):
		var dest_state = owner.get_node_or_null(connection.to)
		
		if dest_state == null:
			push_error("The connection event & conditions are fullfiled, but the destination state couldn't be find, aborting")
		else:
			set_state(dest_state)


func _on_standalone_trigger_event(state: State, event: StateEvent) -> void:
	if event.are_all_conditions_verified(state):
		set_state(state)


func _on_owner_ready() -> void:
	owner_ready = true


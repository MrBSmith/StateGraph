@tool
extends Node
class_name State

# Abstract base class for a State in a StateMachine

# Defines the behaviour of the entity possesing the statemachine 
# when the entity is in this state

# The enter_state is called every time the state is entered and exit_state when it's exited
# the update_state method of the currrent state is called every physics tick,  
# by the physics_process of the StateMachine 

@onready var states_machine : StateMachine = get_parent() if get_parent() is StateMachine else null

@export var connections_array : Array[StateConnection]
@export var standalone_trigger : StateTrigger

# Defines the position of the StateNode in the StateGraph. Expressed in ratio of the container size.
@export var graph_position := Vector2.ZERO

@export var print_logs : bool = false

signal standalone_trigger_added
signal standalone_trigger_removed
signal entered
signal exited

#### ACCESSORS ####


#### BUILT-IN ####

func _ready() -> void:
	if states_machine != null:
		states_machine.emit_signal("state_added", self)


func _exit_tree() -> void:
	if states_machine != null:
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
	if states_machine == null:
		push_warning("The State: ", name, " has no StateMachine parent")
		return false
	
	if states_machine != null:
		return states_machine.current_state == self && states_machine.is_current_state()
	else:
		return states_machine.current_state == self


func get_master_state_machine() -> State:
	if not get_parent() is State:
		return self
	else :
		return get_parent().get_master_state_machine()


#### CONDITIONS & TRIGGER LOGIC ####

func check_exit_conditions(event_trigger: String = "") -> State:
	for connection in connections_array:
		var event = connection.find_event(event_trigger)
		if event == null:
			continue
		
		if event.are_all_conditions_verified(self):
			var state = owner.get_node(connection.to)
			return state
	return null


func connect_connections_events(listener: Node, disconnect: bool = false) -> void:
	for connection in connections_array:
		for event in connection.events:
			var trigger = event.trigger
			var emitter = get_node_or_null(event.emitter_path)
			
			if trigger == "process":
				continue
			
			if emitter == null:
				push_error("event emitter can't be found at path %s" % event.emitter_path)
			
			else:
				if !emitter.has_signal(trigger):
					push_error("The emitter %s found at path %s has no signal named %s" % [emitter.name, event.emitter_path, trigger])
				else:
					if disconnect:
						emitter.disconnect(trigger, listener._on_current_state_event)
					else:
						emitter.connect(trigger, listener._on_current_state_event.bind(self, connection, event))


func add_connection(to: State, connection : StateConnection = null) -> void:
	if find_connection(to) != null:
		return
	
	var conn : StateConnection = connection
	if conn == null:
		conn = StateConnection.new()
		conn.to = owner.get_path_to(to)
	
	connections_array.append(conn)


func remove_connection(to: State) -> void:
	var connection_id = find_connection_id(to)
	connections_array.remove_at(connection_id)


func add_standalone_trigger() -> void:
	if standalone_trigger == null:
		standalone_trigger = StateTrigger.new()
		
		emit_signal("standalone_trigger_added")
	else:
		push_error("Can't add a standalone trigger, the state %s already has one" % name)


func remove_standalone_trigger() -> void:
	standalone_trigger = null
	emit_signal("standalone_trigger_removed")


func find_connection(to: State) -> StateConnection:
	for con in connections_array:
		if con.to == owner.get_path_to(to):
			return con
	return null


func find_connection_id(to: State) -> int:
	var connection = find_connection(to)
	return connections_array.find(connection)




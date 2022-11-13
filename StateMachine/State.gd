@tool
extends Node
class_name State

# Abstract base class for a State in a StateMachine

# Defines the behaviour of the entity possesing the statemachine 
# when the entity is in this state

# The enter_state is called every time the state is entered and exit_state when it's exited
# the update_state method of the currrent state is called every physics tick,  
# by the physics_process of the StateMachine 

@onready var states_machine = get_parent() if get_parent().is_class("StateMachine") else null

@export var connexions_array : Array[StateConnexion]
@export var standalone_trigger : StateTrigger

# Defines the position of the StateNode in the StateGraph. Expressed in ratio of the container size.
@export var graph_position := Vector2.ZERO

signal standalone_trigger_added
signal standalone_trigger_removed
signal entered
signal exited

#### ACCESSORS ####

func get_class() -> String : return "State"
func is_class(value: String) -> bool: return value == "State" or super.is_class(value)


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


func get_master_state_machine() -> State:
	if not get_parent() is State:
		return self
	else :
		return get_parent().get_master_state_machine()


#### CONDITIONS & TRIGGER LOGIC ####

func check_exit_conditions(event_trigger: Signal) -> State:
	for connexion in connexions_array:
		var event = connexion.find_event(event_trigger)
		if event == null:
			continue
		
		if event.are_all_conditions_verified(self):
			var state = owner.get_node(connexion.to)
			return state
	return null


func connect_connexions_events(listener: Node, disconnect: bool = false) -> void:
	for connexion in connexions_array:
		for event in connexion.events:
			var trigger = event.trigger
			var emitter = get_node_or_null(event.emitter_path)
			
			if emitter == null:
				push_error("event emitter can't be found at path %s" % event.emitter_path)
			else:
				if trigger.get_object() != emitter:
					push_error("The emitter %s found at path %s has no signal named %s" % [emitter.name, event.emitter_path, str(trigger.get_name())])
				else:
					if disconnect:
#						var __ = emitter.disconnect(trigger, Callable(listener,"_on_current_state_event"))
						trigger.disconnect(listener._on_current_state_event)
					else:
#						var __ = emitter.connect(trigger, Callable(listener,"_on_current_state_event").bind(self, connexion, event), CONNECT_REFERENCE_COUNTED)
						trigger.connect(listener._on_current_state_event.bind(self, connexion, event), CONNECT_REFERENCE_COUNTED)


func add_connexion(to: State, connexion : StateConnexion = null) -> void:
	if find_connexion(to) != null:
		return
	
	var conn : StateConnexion = connexion
	if conn == null:
		conn = StateConnexion.new(str(owner.get_path_to(to)), [])
	
	connexions_array.append(conn)


func remove_connexion(to: State) -> void:
	var connexion_id = find_connexion_id(to)
	connexions_array.remove_at(connexion_id)


func add_standalone_trigger() -> void:
	if standalone_trigger == null:
		standalone_trigger = StateTrigger.new()
		
		emit_signal("standalone_trigger_added")
	else:
		push_error("Can't add a standalone trigger, the state %s already has one" % name)


func remove_standalone_trigger() -> void:
	standalone_trigger = null
	emit_signal("standalone_trigger_removed")


func find_connexion(to: State) -> StateConnexion:
	for con in connexions_array:
		if con.to == owner.get_path_to(to):
			return con
	return null


func find_connexion_id(to: State) -> int:
	var connexion = find_connexion(to)
	return connexions_array.find(connexion)




tool
extends StateMachine
class_name PushdownAutomata

var state_queue : Array = []
var state_index : int = -1

export var state_queue_max_size : int = 5

#### ACCESSORS ####

func is_class(value: String): return value == "PushdownAutomata" or .is_class(value)
func get_class() -> String: return "PushdownAutomata"


#### BUILT-IN ####



#### VIRTUALS ####



#### LOGIC ####

func set_state(state) -> void:
	if state is String:
		state = get_node(state)
	
	if state == current_state:
		return
	
	.set_state(state)
	
	if state == null:
		return
	
	# If the current state is the last of the queue
	if state_index != state_queue.size() - 1:
		for i in range(state_index + 1, state_queue.size() - 1):
			state_queue.remove(i)
	
	_append_state_to_queue(state)


func _append_state_to_queue(state: Object) -> void:
	state_queue.append(state)
	
	if state_queue.size() > state_queue_max_size:
		state_queue.remove(0)
		state_index = state_queue.size() - 1
	else:
		state_index += 1


func _print_queue() -> void:
	print(" ")
	
	for i in range(state_queue.size()):
		var state = state_queue[i]
		var sufix = " <-" if i == state_index else ""
		print(state.name + sufix)


# Sets the state with the state at the id position of the queue
func go_to_queued_state_by_index(id: int) -> void:
	if id == state_index : return
	
	if id < 0 or id > state_queue.size() - 1:
		push_error("The given index: " + String(id) + "isn't inside the queue bouderies")
		return
	
	state_index = id
	.set_state(state_queue[id])


# Sets the state to the previous one in the queue
func go_to_previous_state() -> void:
	if state_index == 0:
		push_warning("There is no previous state - state_index is currently 0")
		return
	
	go_to_queued_state_by_index(state_index - 1)


# Sets the state to the next one in the queue
func go_to_next_state() -> void:
	if state_index == state_queue.size() - 1:
		push_warning("There is no next state - the current index is the last of the queue")
		return
	
	go_to_queued_state_by_index(state_index + 1)



#### INPUTS ####



#### SIGNAL RESPONSES ####

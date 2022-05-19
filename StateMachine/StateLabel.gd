extends Label
class_name StateLabel

onready var states_machine : Node = get_parent()

#### ACCESSORS ####

func is_class(value: String): return value == "StateLabel" or .is_class(value)
func get_class() -> String: return "StateLabel"


#### BUILT-IN ####

func _ready() -> void:
	yield(get_parent(), "ready")
	var __ = get_parent().connect("state_entered_recursive", self, "_on_StateMachine_state_entered_recursive")
	
	_update_text(get_parent().current_state)

#### SIGNAL RESPONSES ####


func _update_text(state: Node) -> void:
	if state != null:
		set_text(_get_state_name_recursive(state))


func _get_state_name_recursive(state: Node) -> String:
	if state is StateMachine:
		return state.name + " -> " +  _get_state_name_recursive(state.get_state())
	else:
		if state == null:
			return ""
		else:
			return state.name


func _on_StateMachine_state_entered_recursive(state: Node) -> void:
	_update_text(state)

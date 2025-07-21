extends Label
class_name StateLabel

@onready var states_machine : Node = get_parent()

#### ACCESSORS ####


#### BUILT-IN ####

func _ready() -> void:
	await get_parent().ready
	states_machine.state_entered_recursive.connect(_on_StateMachine_state_entered_recursive)
	
	_update_text(get_parent().current_state)

#### SIGNAL RESPONSES ####


func _update_text(state: Node) -> void:
	if state != null:
		set_text(_get_state_name_recursive(state))


func _get_state_name_recursive(state: Node) -> String:
	if state is StateMachine:
		return str(state.name) + " -> " +  _get_state_name_recursive(state.get_state())
	else:
		if state == null:
			return ""
		else:
			return str(state.name)


func _on_StateMachine_state_entered_recursive(state: Node) -> void:
	_update_text(state)

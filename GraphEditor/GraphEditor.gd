tool
extends Control
class_name GraphEditor

onready var nodes_editor = $HSplitContainer/NodesEditor
onready var condition_editor = $HSplitContainer/ConditionEditor

onready var nodes_container = nodes_editor.get_node("VBoxContainer/NodeEditorContainer/NodesContainer")
onready var connexions_container = nodes_editor.get_node("VBoxContainer/NodeEditorContainer/ConnexionsContainer")

onready var node_editor_header = nodes_editor.get_node("VBoxContainer/Header")
onready var toolbar = condition_editor.get_node("VBoxContainer/Toolbar")
onready var footer = condition_editor.get_node("VBoxContainer/Footer")

onready var add_standalone_trigger_button = node_editor_header.get_node("AddStandaloneTrigger")

var edited_scene_path : String = ""

var fsm : StateMachine = null

var state_node_scene = preload("res://addons/StateGraph/GraphEditor/FSM_EditorStateNode.tscn")
var node_connexion_scene = preload("res://addons/StateGraph/GraphEditor/FSM_Connexion.tscn")
var fsm_connexion_container_scene = preload("res://addons/StateGraph/GraphEditor/FSM_ConnexionContainer.tscn")

var states_array = []

var selected_node : Control setget set_selected_node
var selected_trigger : Control = null setget set_selected_trigger
var selected_trigger_dict : Dictionary setget set_selected_trigger_dict
var edited_state : State

signal inspect_node_query(node)
signal selected_trigger_changed(con)
signal selected_trigger_dict_changed(dict)
signal selected_node_changed()

#### ACCESSORS ####

func is_class(value: String): return value == "FSM_Editor" or .is_class(value)
func get_class() -> String: return "FSM_Editor"

func set_selected_trigger(con: FSM_Connexion) -> void:
	if con != selected_trigger:
		selected_trigger = con
		emit_signal("selected_trigger_changed", selected_trigger)

func set_selected_node(value: Control) -> void:
	if value != selected_node:
		selected_node = value
		emit_signal("selected_node_changed")

func set_selected_trigger_dict(value: Dictionary) -> void:
	if value != selected_trigger_dict:
		selected_trigger_dict = value
		emit_signal("selected_trigger_dict_changed", selected_trigger_dict)

#### BUILT-IN ####

func _ready() -> void:
	connect("selected_trigger_changed", self, "_on_selected_trigger_changed")
	connect("selected_trigger_dict_changed", self, "_on_selected_trigger_dict_changed")
	connect("selected_node_changed", self, "_on_selected_node_changed")

	nodes_container.connect("item_rect_changed", self, "_on_NodesContainer_item_rect_changed")

	$Panel.add_stylebox_override("panel", get_stylebox("Content", "EditorStyles"))

	condition_editor.connect("remove_condition", self, "_on_ConditionEditor_remove_condition")
	condition_editor.connect("remove_event", self, "_on_ConditionEditor_remove_event")
	condition_editor.connect("connexion_path_changed_query", self, "_on_connexion_path_changed_query")

	for button in node_editor_header.get_children():
		button.connect("pressed", self, "_on_node_editor_header_button_pressed", [button])

	for button in toolbar.get_children():
		button.connect("pressed", self, "_on_toolbar_button_pressed", [button])

	for button in footer.get_children():
		button.connect("pressed", self, "_on_footer_button_pressed", [button])



#### VIRTUALS ####



#### LOGIC ####

func feed(state_machine: StateMachine) -> void:
	if state_machine == fsm:
		return

	if fsm != null && !is_instance_valid(fsm):
		var __ = fsm.disconnect("state_added", self, "_on_fsm_state_added")
		__ = fsm.disconnect("state_removed", self, "_on_fsm_state_removed")

	_clear()

	if state_machine != null:
		state_machine.fetch_states(states_array)
		fsm = state_machine

		var __ = fsm.connect("state_added", self, "_on_fsm_state_added")
		__ = fsm.connect("state_removed", self, "_on_fsm_state_removed")

		yield(get_tree(), "idle_frame")
		_update()


func _clear() -> void:
	states_array = []

	for child in nodes_container.get_children():
		child.queue_free()


func _update_states_array() -> void:
	states_array = []
	fsm.fetch_states(states_array)


func _update() -> void:
	# Remove useless state nodes
	for child in nodes_container.get_children():
		if !fsm.has_state(child.name):
			child.queue_free()

	# Add missing state nodes
	for state in states_array:
		if !_has_state_node(state.name):
			var node = state_node_scene.instance()
			node.name = state.name
			node.has_standalone_trigger = !state.standalone_trigger.empty()
			node.set_position(state.graph_position * nodes_container.get_size())
			nodes_container.add_child(node)

			var __ = node.connect("item_rect_changed", self, "_on_state_node_item_rect_changed", [node])
			__ = node.connect("connexion_attempt", self, "_on_state_node_connexion_attempt", [node])
			__ = node.connect("trigger_selected", self, "_on_node_trigger_selected", [node])
			__ = node.connect("selected_changed", self, "_on_node_selected_changed", [node])
			__ = state.connect("standalone_trigger_added", node, "_on_standalone_trigger_added")
			__ = state.connect("standalone_trigger_removed", node, "_on_standalone_trigger_removed")
			__ = state.connect("renamed", self, "_on_state_renamed", [state, node])
	
	# Update connexions
	for state in states_array:
		var from_node = nodes_container.get_node(state.name)

		for con in state.connexions_array:
			var to_state_path = str(fsm.owner.get_path()) + "/" + str(con["to"])
			var to_state = get_node(to_state_path)
			var to_node = nodes_container.get_node(to_state.name)

			if !has_connexion(from_node, to_node):
				add_node_connexion(from_node, to_node)


func _update_nodes_position() -> void:
	for node in nodes_container.get_children():
		var state = fsm.get_state_by_name(node.name)
		node.set_position(state.graph_position * nodes_container.get_size())


func update_connexion_editor() -> void:
	if selected_trigger_dict.empty():
		condition_editor.clear()
	else:
		var from = selected_trigger.from if selected_trigger != null else null
		var from_path = fsm.name + "/" + from.name if from != null else ""
		condition_editor.update_content(from_path, selected_trigger_dict)


func update_line_containers() -> void:
	for line_container in connexions_container.get_children():
		var from = line_container.from
		var to = line_container.to

		line_container.set_global_position(from.get_global_position() + from.get_size() / 2)

		var line_global_pos = line_container.get_global_position()
		var dest = to.get_global_position() + to.get_size() / 2.0

		var angle = dest.angle_to_point(line_global_pos)
		var distance = line_global_pos.distance_to(dest)

		line_container.v_box_container.set_rotation(angle)
		line_container.v_box_container.rect_size.x = distance


func _has_state_node(state_name: String) -> bool:
	for child in nodes_container.get_children():
		if child.name == state_name:
			return true
	return false


func _find_hovered_node() -> Control:
	var mouse_pos = get_global_mouse_position()
	for node in nodes_container.get_children():
		var rect = node.get_global_rect()

		if rect.has_point(mouse_pos):
			return node
	return null


func add_node_connexion(from: Control, to: Control) -> void:
	var connexion = node_connexion_scene.instance()
	connexion.from = from
	connexion.to = to

	var line_container = find_line_container(from, to)

	if line_container == null:
		line_container = fsm_connexion_container_scene.instance()
		line_container.from = from
		line_container.to = to

	line_container.name = from.name + to.name
	line_container.set_position(from.get_position())

	if !line_container.is_inside_tree():
		connexions_container.add_child(line_container)

	connexion.inverted = from == line_container.to
	line_container.add_connexion(connexion)

	connexion.connect("removed", self, "_on_connection_removed", [connexion])
	connexion.connect("selected", self, "_on_connection_selected", [connexion])
	connexion.connect("unselected", self, "_on_connection_unselected", [connexion])

	var from_state = fsm.get_state_by_name(from.name)
	var to_state = fsm.get_state_by_name(to.name)

	from_state.add_connexion(to_state)

	update_line_containers()


func find_line_container(from: Control, to: Control) -> FSM_ConnexionContainer:
	for line_container in connexions_container.get_children():
		if line_container.from in [from, to] && line_container.to in [from, to]:
			return line_container
	return null


func has_connexion(from: Control, to: Control) -> bool:
	for con in get_tree().get_nodes_in_group("FSM_Connexions"):
		if con.from == from && con.to == to:
			return true
	return false


func inspect_connexion(connexion: FSM_Connexion) -> void:
	var from_state = fsm.get_state_by_name(connexion.from.name)

	emit_signal("inspect_node_query", from_state)


func fsm_connexion_get_connexion_dict(connexion: FSM_Connexion) -> Dictionary:
	if connexion == null:
		return {}
	
	var from_state = fsm.get_state_by_name(connexion.from.name)
	var to_state = fsm.get_state_by_name(connexion.to.name)

	return from_state.find_connexion(to_state)


func force_connexions_update() -> void:
	for connexion in get_tree().get_nodes_in_group("FSM_Connexions"):
		connexion.update_line()


func get_selected_trigger_origin_path() -> String:
	if selected_trigger == null:
		if edited_state != null:
			return str(edited_state.owner.get_path_to(edited_state))
		return ""

	var from_state = fsm.get_state_by_name(selected_trigger.from.name)
	return str(from_state.owner.get_path_to(from_state))


func unselect_all_connexions(exeption: FSM_Connexion = null) -> void:
	for connexion in get_tree().get_nodes_in_group("FSM_Connexions"):
		if connexion != exeption:
			connexion.set_state(FSM_Connexion.STATE.NORMAL)


func unselect_all_triggers(exeption: Control = null) -> void:
	for node in nodes_container.get_children():
		if node != exeption:
			node.unselect_trigger()


func unselect_all_nodes(exeption: Control = null) -> void:
	for node in nodes_container.get_children():
		if node != exeption:
			node.set_selected(false)


# The key must be "from" or "to"
func selected_connexion_change_state(key: String, new_state: State) -> void:
	if selected_trigger == null:
		push_error("Can't change the selected connexion %s state, the selected_trigger is null" % key)
		return
	
	if not selected_trigger is FSM_Connexion:
		push_error("Can't change the connexion state, the selected trigger is not a connexion")
	
	# Change the backend connexion
	match(key):
		"from":
			var from_state = fsm.get_state_by_name(selected_trigger.from.name)
			var to_state = fsm.get_state_by_name(selected_trigger.to.name)
			var connexion_dict = from_state.find_connexion(to_state)
			
			from_state.remove_connexion(to_state)
			new_state.add_connexion(to_state, connexion_dict)
		
		"to":
			var connexion_dict = fsm_connexion_get_connexion_dict(selected_trigger)
			connexion_dict["to"] = str(fsm.owner.get_path_to(new_state))
	
	# Change the frontend connexion
	selected_trigger.set(key, nodes_container.get_node(new_state.name))
	var from_node = selected_trigger.from
	var to_node = selected_trigger.to
	
	selected_trigger.queue_free()
	add_node_connexion(from_node, to_node)



#### INPUTS ####

func _input(event: InputEvent) -> void:
	if !visible:
		return

	if event is InputEventKey && event.scancode == KEY_DELETE:
		if event.is_pressed() && !event.is_echo():
			if selected_trigger != null:
				selected_trigger.delete()
				get_tree().set_input_as_handled()


#### SIGNAL RESPONSES ####


func _on_fsm_state_added(_state: State) -> void:
	_update_states_array()
	_update()


func _on_fsm_state_removed(_state: State) -> void:
	_update_states_array()
	_update()


func _on_state_node_item_rect_changed(node: Control) -> void:
	var state = fsm.get_state_by_name(node.name)
	state.graph_position = node.get_position() / nodes_container.get_size()

	update_line_containers()


func _on_state_node_connexion_attempt(starting_node: Control) -> void:
	var hovered_node = _find_hovered_node()

	if hovered_node != null && hovered_node != starting_node:
		add_node_connexion(starting_node, hovered_node)


func _on_connection_removed(connexion: FSM_Connexion) -> void:
	var from = fsm.get_state_by_name(connexion.from.name)
	var to = fsm.get_state_by_name(connexion.to.name)

	from.remove_connexion(to)


func _on_connection_selected(connexion: FSM_Connexion) -> void:
	unselect_all_nodes()
	unselect_all_connexions(connexion)
	unselect_all_triggers()
	
	set_selected_trigger(connexion)

	condition_editor.animation_handler = fsm.get_animation_handler()


func _on_connection_unselected(connexion: FSM_Connexion) -> void:
	if selected_trigger == connexion:
		set_selected_trigger(null)


func _on_selected_trigger_changed(fsm_connexion: FSM_Connexion) -> void:
	set_selected_trigger_dict(fsm_connexion_get_connexion_dict(fsm_connexion))


func _on_toolbar_button_pressed(button: Button) -> void:
	var is_condition : bool = selected_trigger_dict["type"] == "connexion"

	var from_state = fsm.get_state_by_name(selected_trigger.from.name) if is_condition else edited_state
	var from_state_path = from_state.owner.get_path_to(from_state)

	match(button.name):
		"AddCondition":
			from_state.trigger_add_condition(selected_trigger_dict, condition_editor.edited_event)

		"AddEvent":
			from_state.trigger_add_event(selected_trigger_dict)

		"AddAnimFinishedEvent":
			var anim_handler = condition_editor.animation_handler
			var animated_sprite = anim_handler.animated_sprite
			var animated_sprite_path = from_state.get_path_to(animated_sprite)

			from_state.trigger_add_event(selected_trigger_dict, "animation_finished", animated_sprite_path)

	condition_editor.update_content(from_state_path, selected_trigger_dict)


func _on_footer_button_pressed(button: Button) -> void:
	match(button.name):
		"DeleteConnexion":
			if selected_trigger == null:
				push_error("There is no selected connexion, the ConditionEditor shouln't be visible")
			else:
				selected_trigger.delete()

		"DeleteStandaloneTrigger":
			var state = fsm.get_state_by_name(selected_node.name)
			state.remove_standalone_trigger()

			selected_node.set_has_standalone_trigger(false)


func _on_NodesContainer_item_rect_changed() -> void:
	_update_nodes_position()
	force_connexions_update()
	update_line_containers()


func _on_ConditionEditor_remove_condition(condition_dict: Dictionary) -> void:
	print("condition remove attempt")

	if selected_trigger_dict.empty():
		push_error("Can't remove the given condition: no connexion is currently selected")
	else:
		for event in selected_trigger_dict["events"]:
			var id = event["conditions"].find(condition_dict)
			if id != -1:
				event["conditions"].remove(id)
				print("condition removed successfully")
				update_connexion_editor()
				return

	push_error("condition couldn't be found, removal aborted")


func _on_ConditionEditor_remove_event(event_dict: Dictionary) -> void:
	print("event remove attempt")

	if selected_trigger_dict.empty():
		push_error("Can't remove the given event: no connexion is currently selected")
	else:
		var id = selected_trigger_dict["events"].find(event_dict)
		if id != -1:
			selected_trigger_dict["events"].remove(id)
			update_connexion_editor()
			print("event removed successfully")
			return

	push_error("event couldn't be found, removal aborted")


func _on_node_trigger_selected(node: Control) -> void:
	unselect_all_triggers(node)
	unselect_all_connexions()

	edited_state = fsm.get_state_by_name(node.name)

	condition_editor.animation_handler = null
	set_selected_trigger_dict(edited_state.standalone_trigger)


func _on_node_selected_changed(selected: bool, node: Control) -> void:
	if selected:
		unselect_all_nodes(node)
		set_selected_node(node)
	else:
		if node == selected_node:
			set_selected_node(null)


func _on_node_editor_header_button_pressed(button: Button) -> void:
	match(button.name):
		"AddStandaloneTrigger":
			var state = fsm.get_state_by_name(selected_node.name)
			state.add_standalone_trigger()
			add_standalone_trigger_button.set_visible(false)


func _on_selected_node_changed() -> void:
	var add_button_needed = selected_node != null && !selected_node.has_standalone_trigger
	add_standalone_trigger_button.set_visible(add_button_needed)
	
	if selected_node != null:
		unselect_all_connexions()


func _on_selected_trigger_dict_changed(_dict: Dictionary) -> void:
	update_connexion_editor()


func _on_state_renamed(state: State, node: Control) -> void:
	node.set_name(state.name)
	update_connexion_editor()


func _on_connexion_path_changed_query(key: String, path: String) -> void:
	var state = fsm.owner.get_node_or_null(path)
	
	if state == null or not state is State:
		push_error("No State could be found at the given path. The path must be relative to the root of the scene, and to designated node must be a State.")
		return
	
	selected_connexion_change_state(key, state)

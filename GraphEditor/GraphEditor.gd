@tool
extends Control
class_name GraphEditor

@onready var nodes_editor = $HSplitContainer/NodesEditor
@onready var condition_editor = $HSplitContainer/ConditionEditor

@onready var graph_edit = nodes_editor.get_node("VBoxContainer/GraphEdit")
@onready var connexions_container = graph_edit.get_node("ConnexionsContainer")

@onready var node_editor_header = nodes_editor.get_node("VBoxContainer/Header")
@onready var toolbar = condition_editor.get_node("VBoxContainer/Toolbar")
@onready var footer = condition_editor.get_node("VBoxContainer/Footer")

@onready var add_standalone_trigger_button = node_editor_header.get_node("AddStandaloneTrigger")

@export var logs : bool = false

var fsm : StateMachine = null

var state_node_scene = preload("res://addons/StateGraph/GraphEditor/StateGraphNode.tscn")
var node_connexion_scene = preload("res://addons/StateGraph/GraphEditor/FSM_Connexion.tscn")
var fsm_connexion_container_scene = preload("res://addons/StateGraph/GraphEditor/FSM_ConnexionContainer.tscn")

var edited_scene_root : Node = null
var states_array = []

var selected_node : Control :
	get:
		return selected_node
	set(value):
		if value != selected_node:
			selected_node = value
			emit_signal("selected_node_changed")
var selected_trigger : Control = null :
	get:
		return selected_trigger
	set(value):
		if value != selected_trigger:
			selected_trigger = value
			emit_signal("selected_trigger_changed", selected_trigger)
var selected_trigger_dict : Dictionary :
	get:
		return selected_trigger_dict

	set(value):
		if value != selected_trigger_dict:
			if logs: print("selected_trigger_dict changed:" + str(value))
			selected_trigger_dict = value
			emit_signal("selected_trigger_dict_changed", selected_trigger_dict)

var edited_state : State

signal inspect_node_query(node)
signal selected_trigger_changed(con)
signal selected_trigger_dict_changed(dict)
signal selected_node_changed()


#### ACCESSORS ####

func is_class(value: String): return value == "FSM_Editor" or super.is_class(value)
func get_class() -> String: return "FSM_Editor"


#### BUILT-IN ####

func _ready() -> void:
	connect("selected_trigger_changed", Callable(self,"_on_selected_trigger_changed"))
	connect("selected_trigger_dict_changed", Callable(self,"_on_selected_trigger_dict_changed"))
	connect("selected_node_changed", Callable(self,"_on_selected_node_changed"))
	connect("visibility_changed", Callable(self,"_on_visibility_changed"))
	
	graph_edit.connect("item_rect_changed",Callable(self,"_on_GraphEdit_item_rect_changed"))
	graph_edit.connect("scroll_offset_changed",Callable(self,"_on_GraphEdit_scroll_offset_changed"))
	graph_edit.connect("gui_input",Callable(self,"_on_GraphEdit_gui_input"))
	OS.low_processor_usage_mode = true
	
	$Panel.add_theme_stylebox_override("panel", get_theme_stylebox("Content", "EditorStyles"))

	condition_editor.connect("remove_condition",Callable(self,"_on_ConditionEditor_remove_condition"))
	condition_editor.connect("remove_event",Callable(self,"_on_ConditionEditor_remove_event"))
	condition_editor.connect("connexion_path_changed_query",Callable(self,"_on_connexion_path_changed_query"))

	for button in node_editor_header.get_children():
		button.connect("pressed",Callable(self,"_on_node_editor_header_button_pressed").bind(button))

	for button in toolbar.get_children():
		button.connect("pressed",Callable(self,"_on_toolbar_button_pressed").bind(button))

	for button in footer.get_children():
		button.connect("pressed",Callable(self,"_on_footer_button_pressed").bind(button))



#### VIRTUALS ####



#### LOGIC ####


func feed(state_machine: StateMachine) -> void:
	if state_machine == fsm:
		return
	
	if logs: print("GraphEditor fed with %s" % str(state_machine.name))

	if fsm != null && is_instance_valid(fsm):
		var __ = fsm.disconnect("state_added",Callable(self,"_on_fsm_state_added"))
		__ = fsm.disconnect("state_removed",Callable(self,"_on_fsm_state_removed"))
	
	clear()
	fsm = state_machine
	
	if state_machine != null:
		fsm.fetch_states(states_array)
		
		var __ = fsm.connect("state_added",Callable(self,"_on_fsm_state_added"))
		__ = fsm.connect("state_removed",Callable(self,"_on_fsm_state_removed"))

		_update()


func clear() -> void:
	states_array = []
	selected_node = null
	selected_trigger = null
	selected_trigger_dict = {}
	
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	
	for child in connexions_container.get_children():
		child.queue_free()


func _update_states_array() -> void:
	states_array = []
	fsm.fetch_states(states_array)


func _update() -> void:
	if fsm == null:
		return
	
	if fsm.owner != edited_scene_root:
		push_error("Cannot update the GraphEditor: the StateMachine isn't inside the edited scene anymore")
		return
	
	if logs: print("update GraphEditor")
	
	# Remove useless state nodes
	for child in graph_edit.get_children():
		if child is GraphNode && !fsm.has_state(child.name):
			child.queue_free()

	# Add missing state nodes
	for state in states_array:
		var state_name = str(state.name)
		
		if !_has_state_node(state_name):
			var node = state_node_scene.instantiate()
			node.name = state_name
			node.set_title(state_name)
			node.has_standalone_trigger = !state.standalone_trigger.is_empty()
			graph_edit.add_child(node)
			
			var __ = node.connect("item_rect_changed", Callable(self,"_on_state_node_item_rect_changed").bind(node))
			__ = node.connect("connexion_attempt", Callable(self,"_on_state_node_connexion_attempt").bind(node))
			__ = node.connect("trigger_selected", Callable(self,"_on_node_trigger_selected").bind(node))
			__ = node.connect("selected", Callable(self, "_on_node_selected_changed").bind(node))
			__ = node.deselected.connect(Callable(self, "_on_node_selected_changed").bind(node))
			__ = state.connect("standalone_trigger_added",Callable(node,"_on_standalone_trigger_added"))
			__ = state.connect("standalone_trigger_removed",Callable(node,"_on_standalone_trigger_removed"))
			__ = state.connect("renamed",Callable(node,"_on_state_renamed").bind(state))

	# Update connexions
	for state in states_array:
		var from_node = graph_edit.get_node(str(state.name))

		for con in state.connexions_array:
			var to_state_path = str(fsm.owner.get_path()) + "/" + str(con["to"])
			var to_state = get_node(to_state_path)
			var to_node = graph_edit.get_node(str(to_state.name))

			if !has_connexion(from_node, to_node):
				add_node_connexion(from_node, to_node)


# Update state nodes graph position
func _update_nodes_position() -> void:
	for state in states_array:
		var node = graph_edit.get_node(str(state.name))
		var pos = state.graph_position * graph_edit.get_size()
		
		node.set_position_offset(pos)


func _update_graph_display() -> void:
	force_connexions_update()
	update_line_containers()


func update_connexion_editor() -> void:
	if selected_trigger_dict.is_empty():
		condition_editor.clear()
	else:
		var from = selected_trigger.from if selected_trigger != null else null
		var from_path = str(fsm.name) + "/" + str(from.name) if from != null else ""
		condition_editor.update_content(from_path, selected_trigger_dict)


func update_line_containers() -> void:
	for line_container in connexions_container.get_children():
		var from = line_container.from
		var to = line_container.to

		line_container.set_global_position(from.get_global_position() + from.get_size() / 2.0 * from.scale)

		var line_global_pos = line_container.get_global_position()
		var dest = to.get_global_position() + to.get_size() / 2.0 * to.scale

		var angle = dest.angle_to_point(line_global_pos) + deg_to_rad(180.0)
		var distance = line_global_pos.distance_to(dest)

		line_container.v_box_container.set_rotation(angle)
		line_container.v_box_container.size.x = distance


func _has_state_node(state_name: String) -> bool:
	for child in graph_edit.get_children():
		if child is GraphNode && child.name == state_name:
			return true
	return false


func _find_hovered_node() -> Control:
	var mouse_pos = get_global_mouse_position()
	for node in graph_edit.get_children():
		if node is GraphNode:
			var rect = node.get_global_rect()

			if rect.has_point(mouse_pos):
				return node
	return null


func add_node_connexion(from: Control, to: Control) -> void:
	if logs: print("add node connexion")
	
	var connexion = node_connexion_scene.instantiate()
	connexion.from = from
	connexion.to = to

	var line_container = find_line_container(from, to)

	if line_container == null:
		line_container = fsm_connexion_container_scene.instantiate()
		line_container.from = from
		line_container.to = to

	line_container.name = str(from.name) + str(to.name)
	line_container.set_position(from.get_position())

	if !line_container.is_inside_tree():
		connexions_container.add_child(line_container)

	connexion.inverted = from == line_container.to
	line_container.add_connexion(connexion)

	connexion.connect("removed", Callable(self,"_on_connection_removed").bind(connexion))
	connexion.connect("selected", Callable(self,"_on_connection_selected").bind(connexion))
	connexion.connect("unselected", Callable(self,"_on_connection_unselected").bind(connexion))

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
	if fsm.owner != edited_scene_root:
		return ""
	
	if selected_trigger == null:
		if edited_state != null:
			return str(edited_state.owner.get_path_to(edited_state))
		return ""

	var from_state = fsm.get_state_by_name(str(selected_trigger.from.name))
	return str(from_state.owner.get_path_to(from_state))


func unselect_all_connexions(exeption: FSM_Connexion = null) -> void:
	for connexion in get_tree().get_nodes_in_group("FSM_Connexions"):
		if connexion != exeption:
			connexion.state = FSM_Connexion.STATE.NORMAL


func unselect_all_triggers(exeption: Control = null) -> void:
	for node in graph_edit.get_children():
		if node is GraphNode && node != exeption:
			node.unselect_trigger()


func unselect_all_nodes(exeption: Control = null) -> void:
	for node in graph_edit.get_children():
		if node is GraphNode && node != exeption:
			node.set_selected(false)


# The key must be "from" or "to"
func selected_connexion_change_state(key: String, new_state: State) -> void:
	if logs: print("selected_connexion_change_state")
	
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
	selected_trigger.set(key, graph_edit.get_node(str(new_state.name)))
	var from_node = selected_trigger.from
	var to_node = selected_trigger.to
	
	selected_trigger.queue_free()
	add_node_connexion(from_node, to_node)



#### INPUTS ####

func _input(event: InputEvent) -> void:
	if !visible:
		return

	if event is InputEventKey && event.keycode == KEY_DELETE:
		if event.is_pressed() && !event.is_echo():
			if selected_trigger != null:
				selected_trigger.delete()
				get_tree().set_input_as_handled()


#### SIGNAL RESPONSES ####


func _on_fsm_state_added(state: State) -> void:
	if logs: print("StateMachine state added %s" % str(state.name))
	_update_states_array()
	_update()


func _on_fsm_state_removed(state: State) -> void:
	if logs: print("StateMachine state removed %s" % str(state.name))
	_update_states_array()
	_update()


func _on_state_node_item_rect_changed(node: Control) -> void:
	if !node.selected:
		return
	
	var state = fsm.get_state_by_name(node.name)
	state.graph_position = node.get_position() / graph_edit.get_size()
	
	if logs: print(str(node.name) + " changed position: " + str(node.position))
	
	update_line_containers()


func _on_state_node_connexion_attempt(starting_node: Control) -> void:
	var hovered_node = _find_hovered_node()

	if hovered_node != null && hovered_node != starting_node:
		add_node_connexion(starting_node, hovered_node)


func _on_connection_removed(connexion: FSM_Connexion) -> void:
	if connexion.from == null or connexion.to == null:
		push_error("the connexion form or to state is null, abort removal")
		return
	
	var from = fsm.get_state_by_name(str(connexion.from.name))
	var to = fsm.get_state_by_name(str(connexion.to.name))

	from.remove_connexion(to)


func _on_connection_selected(connexion: FSM_Connexion) -> void:
	if connexion.from == null or connexion.to == null:
		return
	
	unselect_all_nodes()
	unselect_all_connexions(connexion)
	unselect_all_triggers()
	
	selected_trigger = connexion

	condition_editor.animation_handler = fsm.get_animation_handler()


func _on_connection_unselected(connexion: FSM_Connexion) -> void:
	if selected_trigger == connexion:
		selected_trigger = null


func _on_selected_trigger_changed(fsm_connexion: FSM_Connexion) -> void:
	var dict = fsm_connexion_get_connexion_dict(fsm_connexion)
	selected_trigger_dict = dict


func _on_toolbar_button_pressed(button: Button) -> void:
	if logs: print("toolbar button pressed %s" % str(button.name))
	var is_condition : bool = selected_trigger_dict["type"] == "connexion"

	var from_state = fsm.get_state_by_name(selected_trigger.from.name) if is_condition else edited_state
	var from_state_path = from_state.owner.get_path_to(from_state)

	match(str(button.name)):
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
	match(str(button.name)):
		"DeleteConnexion":
			if selected_trigger == null:
				push_error("There is no selected connexion, the ConditionEditor shouln't be visible")
			else:
				selected_trigger.delete()

		"DeleteStandaloneTrigger":
			var state = fsm.get_state_by_name(str(selected_node.name))
			state.remove_standalone_trigger()

			selected_node.has_standalone_trigger = false


func _on_GraphEdit_item_rect_changed() -> void:
	_update_graph_display()
	if logs: print("item_rect_changed called, update display")


func _on_GraphEdit_scroll_offset_changed(offset: Vector2) -> void:
	_update_graph_display()
	if logs: print("scroll_offset_changed called, update display")


func _on_GraphEdit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT]:
			if logs: print("mouse wheel used, update display")
			await get_tree().process_frame
			_update_graph_display()


func _on_ConditionEditor_remove_condition(condition_dict: Dictionary) -> void:
	if selected_trigger_dict.is_empty():
		push_error("Can't remove_at the given condition: no connexion is currently selected")
	else:
		for event in selected_trigger_dict["events"]:
			var id = event["conditions"].find(condition_dict)
			if id != -1:
				event["conditions"].remove_at(id)
				update_connexion_editor()
				return

	push_error("condition couldn't be found, removal aborted")


func _on_ConditionEditor_remove_event(event_dict: Dictionary) -> void:
	if selected_trigger_dict.is_empty():
		push_error("Can't remove_at the given event: no connexion is currently selected")
	else:
		var id = selected_trigger_dict["events"].find(event_dict)
		if id != -1:
			selected_trigger_dict["events"].remove_at(id)
			update_connexion_editor()
			return

	push_error("event couldn't be found, removal aborted")


func _on_node_trigger_selected(node: Control) -> void:
	unselect_all_triggers(node)
	unselect_all_connexions()

	edited_state = fsm.get_state_by_name(node.name)

	condition_editor.animation_handler = null
	selected_trigger_dict = edited_state.standalone_trigger


func _on_node_selected_changed(node: StateGraphNode) -> void:
	if node.selected:
		unselect_all_nodes(node)
		selected_node = node
	else:
		if node == selected_node:
			selected_node = null
			selected_trigger_dict = {}


func _on_node_editor_header_button_pressed(button: Button) -> void:
	match(str(button.name)):
		"AddStandaloneTrigger":
			var state = fsm.get_state_by_name(str(selected_node.name))
			state.add_standalone_trigger()
			add_standalone_trigger_button.set_visible(false)


func _on_selected_node_changed() -> void:
	var add_button_needed = selected_node != null && !selected_node.has_standalone_trigger
	add_standalone_trigger_button.set_visible(add_button_needed)
	
	if selected_node != null:
		unselect_all_connexions()


func _on_selected_trigger_dict_changed(_dict: Dictionary) -> void:
	update_connexion_editor()


func _on_connexion_path_changed_query(key: String, path: String) -> void:
	var state = fsm.owner.get_node_or_null(path)
	
	if state == null or not state is State:
		push_error("No State could be found at the given path. The path must be relative to the root of the scene, and to designated node must be a State.")
		return
	
	selected_connexion_change_state(key, state)


func _on_visibility_changed() -> void:
	if visible:
		_update()
		
		await get_tree().process_frame
		_update_nodes_position()
		
		await get_tree().process_frame
		_update_graph_display()

@tool
extends Control
class_name GraphEditor

@onready var nodes_editor = $HSplitContainer/NodesEditor
@onready var condition_editor = $HSplitContainer/ConditionEditor

@onready var graph_edit = nodes_editor.get_node("VBoxContainer/GraphEdit")
@onready var connections_container = %ConnectionsContainer

@onready var node_editor_header = nodes_editor.get_node("VBoxContainer/Header")
@onready var toolbar = condition_editor.get_node("VBoxContainer/Toolbar")
@onready var footer = condition_editor.get_node("VBoxContainer/Footer")

@onready var add_standalone_trigger_button = node_editor_header.get_node("AddStandaloneTrigger")

@export var logs : bool = false

var fsm : StateMachine = null

var state_node_scene = preload("res://addons/StateGraph/GraphEditor/StateGraphNode.tscn")
var node_connection_scene = preload("res://addons/StateGraph/GraphEditor/FSM_Connection.tscn")
var fsm_connection_container_scene = preload("res://addons/StateGraph/GraphEditor/FSM_ConnectionContainer.tscn")

var edited_scene_root : Node = null
var states_array = []

var selected_node : Control :
	get:
		return selected_node
	set(value):
		if value != selected_node:
			selected_node = value
			emit_signal("selected_node_changed")
var selected_trigger_control : Control = null :
	get:
		return selected_trigger_control
	set(value):
		if value != selected_trigger_control:
			selected_trigger_control = value
			emit_signal("selected_trigger_control_changed", selected_trigger_control)
var selected_trigger : StateTrigger :
	get:
		return selected_trigger

	set(value):
		if value != selected_trigger:
			if logs: print_debug("selected_trigger changed:" + str(value))
			selected_trigger = value
			emit_signal("selected_trigger_changed", selected_trigger)

var edited_state : State

signal inspect_node_query(node)
signal selected_trigger_changed(trigger)
signal selected_trigger_control_changed(trigger)
signal selected_node_changed()


#### ACCESSORS ####

func is_class(value: String): return value == "FSM_Editor" or super.is_class(value)
func get_class() -> String: return "FSM_Editor"


#### BUILT-IN ####

func _ready() -> void:
	OS.low_processor_usage_mode = true
	
	selected_trigger_changed.connect(_on_selected_trigger_changed)
	selected_trigger_control_changed.connect(_on_selected_trigger_control_changed)
	selected_node_changed.connect(_on_selected_node_changed)
	visibility_changed.connect(_on_visibility_changed)
	
	graph_edit.connect("item_rect_changed",Callable(self,"_on_GraphEdit_item_rect_changed"))
	graph_edit.connect("scroll_offset_changed",Callable(self,"_on_GraphEdit_scroll_offset_changed"))
	graph_edit.connect("gui_input",Callable(self,"_on_GraphEdit_gui_input"))
	
	$Panel.add_theme_stylebox_override("panel", get_theme_stylebox("Content", "EditorStyles"))

	condition_editor.connect("remove_condition",Callable(self,"_on_ConditionEditor_remove_condition"))
	condition_editor.connect("remove_event",Callable(self,"_on_ConditionEditor_remove_event"))
	condition_editor.connect("connection_path_changed_query",Callable(self,"_on_connection_path_changed_query"))

	for button in node_editor_header.get_children():
		button.connect("pressed", _on_node_editor_header_button_pressed.bind(button))

	for button in toolbar.get_children():
		button.connect("pressed", _on_toolbar_button_pressed.bind(button))

	for button in footer.get_children():
		button.connect("pressed", _on_footer_button_pressed.bind(button))



#### VIRTUALS ####



#### LOGIC ####


func feed(state_machine: StateMachine) -> void:
	if state_machine == fsm:
		return
	
	if logs: print_debug("GraphEditor fed with %s" % str(state_machine.name))

	clear_fsm()
	clear()
	
	fsm = state_machine
	
	if state_machine != null:
		fsm.fetch_states(states_array)
		
		var __ = fsm.connect("state_added",Callable(self,"_on_fsm_state_added"))
		__ = fsm.connect("state_removed",Callable(self,"_on_fsm_state_removed"))

		_update()


func clear() -> void:
	if logs: print_debug("Graph Editor cleared")
	
	states_array = []
	selected_node = null
	selected_trigger_control = null
	selected_trigger = null
	
	clear_fsm()
	
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	
	for child in connections_container.get_children():
		child.queue_free()


func clear_fsm() -> void:
	if fsm != null && is_instance_valid(fsm):
		fsm.disconnect("state_added", Callable(self,"_on_fsm_state_added"))
		fsm.disconnect("state_removed", Callable(self,"_on_fsm_state_removed"))
	
	fsm = null


func _update_states_array() -> void:
	states_array = []
	fsm.fetch_states(states_array)


func _update() -> void:
	if fsm == null:
		if logs: print_debug("Cannot update the graph editor: the given fsm is null")
		return
	
	if fsm.owner != edited_scene_root:
		push_error("Cannot update the GraphEditor: the StateMachine owner %s isn't the edited scene root %s" % [str(fsm.owner.name), str(edited_scene_root.name)])
		return
	
	if logs: print_debug("--- update GraphEditor started ---")
	
	# Remove useless state nodes
	for child in graph_edit.get_children():
		if child is GraphNode && !fsm.has_state(child.name):
			if logs: print_debug("Remove state node %s from the graph" % str(child.name))
			child.queue_free()

	# Add missing state nodes
	for state in states_array:
		var state_name = str(state.name)
		
		if !_has_state_node(state_name):
			var graph_node : GraphNode = state_node_scene.instantiate()
			graph_node.name = state_name
			graph_node.set_title(state_name)
			graph_node.has_standalone_trigger = state.standalone_trigger != null
			graph_edit.add_child(graph_node)
			if logs: print_debug("Add state node %s to the graph" % state_name)
			
			var __ = graph_node.item_rect_changed.connect(_on_state_node_item_rect_changed.bind(graph_node))
			__ = graph_node.connection_attempt.connect(_on_state_node_connection_attempt.bind(graph_node))
			__ = graph_node.trigger_selected.connect(_on_node_trigger_selected.bind(graph_node))
			__ = graph_node.node_selected.connect(_on_node_selected_changed.bind(graph_node))
			__ = graph_node.node_deselected.connect(_on_node_selected_changed.bind(graph_node))
			
			__ = state.standalone_trigger_added.connect(Callable(graph_node,"_on_standalone_trigger_added"))
			__ = state.standalone_trigger_removed.connect(Callable(graph_node,"_on_standalone_trigger_removed"))
			__ = state.renamed.connect(Callable(graph_node,"_on_state_renamed").bind(state))

	# Update connections
	for state in states_array:
		var from_node = graph_edit.get_node(str(state.name))

		for con in state.connections_array:
			var to_state_path = str(fsm.owner.get_path()) + "/" + str(con["to"])
			var to_state = get_node(to_state_path)
			var to_node = graph_edit.get_node(str(to_state.name))

			if !has_connection(from_node, to_node):
				add_node_connection(from_node, to_node)
	
	if logs: print_debug("--- update GraphEditor finished ---")


# Update state nodes graph position
func _update_nodes_position() -> void:
	for state in states_array:
		var node = graph_edit.get_node(str(state.name))
		var pos = state.graph_position * graph_edit.get_size()
		
		node.set_position_offset(pos)


func _update_graph_display() -> void:
	force_connections_update()
	update_line_containers()


func update_connection_editor() -> void:
	if selected_trigger == null:
		condition_editor.clear()
	else:
		var from = selected_trigger_control.from if selected_trigger_control != null else null
		var from_path = str(fsm.name) + "/" + str(from.name) if from != null else ""
		condition_editor.update_content(from_path, selected_trigger)


func update_line_containers() -> void:
	for line_container in connections_container.get_children():
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


func add_node_connection(from: Control, to: Control) -> void:
	if logs: print_debug("add node connection between %s & %s nodes" % [str(from.name), str(to.name)])
	
	var connection = node_connection_scene.instantiate()
	connection.from = from
	connection.to = to

	var line_container = find_line_container(from, to)

	if line_container == null:
		line_container = fsm_connection_container_scene.instantiate()
		line_container.from = from
		line_container.to = to

	line_container.name = str(from.name) + str(to.name)
	line_container.set_position(from.get_position())

	if !line_container.is_inside_tree():
		connections_container.add_child(line_container)

	connection.inverted = from == line_container.to
	line_container.add_connection(connection)

	connection.connect("removed", Callable(self,"_on_connection_removed").bind(connection))
	connection.connect("selected", Callable(self,"_on_connection_selected").bind(connection))
	connection.connect("unselected", Callable(self,"_on_connection_unselected").bind(connection))

	var from_state = fsm.get_state_by_name(from.name)
	var to_state = fsm.get_state_by_name(to.name)
	
	from_state.add_connection(to_state)

	update_line_containers()


func find_line_container(from: Control, to: Control) -> FSM_ConnectionContainer:
	for line_container in connections_container.get_children():
		if line_container.from in [from, to] && line_container.to in [from, to]:
			return line_container
	return null


func has_connection(from: Control, to: Control) -> bool:
	for con in get_tree().get_nodes_in_group("FSM_Connections"):
		if con.from == from && con.to == to:
			return true
	return false


func inspect_connection(connection: FSM_Connection) -> void:
	var from_state = fsm.get_state_by_name(connection.from.name)

	emit_signal("inspect_node_query", from_state)


func fsm_connection_get_connection(connection: FSM_Connection) -> StateConnection:
	if connection == null:
		return null
	
	var from_state = fsm.get_state_by_name(connection.from.name)
	var to_state = fsm.get_state_by_name(connection.to.name)

	return from_state.find_connection(to_state)


func force_connections_update() -> void:
	for connection in get_tree().get_nodes_in_group("FSM_Connections"):
		connection.update_line()


func get_selected_trigger_origin_path() -> String:
	if fsm.owner != edited_scene_root:
		return ""
	
	if selected_trigger_control == null:
		if edited_state != null:
			return str(edited_state.owner.get_path_to(edited_state))
		return ""

	var from_state = fsm.get_state_by_name(str(selected_trigger_control.from.name))
	return str(from_state.owner.get_path_to(from_state))


func unselect_all_connections(exeption: FSM_Connection = null) -> void:
	for connection in get_tree().get_nodes_in_group("FSM_Connections"):
		if connection != exeption:
			connection.state = FSM_Connection.STATE.NORMAL


func unselect_all_triggers(exeption: Control = null) -> void:
	for node in graph_edit.get_children():
		if node is GraphNode && node != exeption:
			node.unselect_trigger()


func unselect_all_nodes(exeption: Control = null) -> void:
	for node in graph_edit.get_children():
		if node is GraphNode && node != exeption:
			node.set_selected(false)


# The key must be "from" or "to"
func selected_connection_change_state(key: String, new_state: State) -> void:
	if logs: print_debug("selected_connection_change_state, key: %s" % key)
	
	if selected_trigger_control == null:
		push_error("Can't change the selected connection %s state, the selected_trigger_control is null" % key)
		return
	
	if not selected_trigger_control is FSM_Connection:
		push_error("Can't change the connection state, the selected trigger is not a connection")
	
	# Change the backend connection
	match(key):
		"from":
			var from_state = fsm.get_state_by_name(selected_trigger_control.from.name)
			var to_state = fsm.get_state_by_name(selected_trigger_control.to.name)
			var connection = from_state.find_connection(to_state)
			
			from_state.remove_connection(to_state)
			new_state.add_connection(to_state, connection)
		
		"to":
			var connection = fsm_connection_get_connection(selected_trigger_control)
			connection.to = edited_scene_root.get_path_to(new_state)
	
	# Change the frontend connection
	selected_trigger_control.set(key, graph_edit.get_node(str(new_state.name)))
	var from_node = selected_trigger_control.from
	var to_node = selected_trigger_control.to
	
	selected_trigger_control.queue_free()
	selected_trigger_control = null
	add_node_connection(from_node, to_node)
	
	condition_editor.clear()



#### INPUTS ####

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return

	if event is InputEventKey && event.keycode == KEY_DELETE:
		if event.is_pressed() && !event.is_echo():
			if selected_trigger_control != null:
				selected_trigger_control.delete()
				get_tree().set_input_as_handled()


#### SIGNAL RESPONSES ####


func _on_fsm_state_added(state: State) -> void:
	if logs: print_debug("StateMachine state added %s" % str(state.name))
	
	await get_tree().process_frame
	
	_update_states_array()
	_update()


func _on_fsm_state_removed(state: State) -> void:
	if logs: print_debug("StateMachine state removed %s" % str(state.name))
	
	await get_tree().process_frame
	
	_update_states_array()
	_update()


func _on_state_node_item_rect_changed(node: Control) -> void:
	if !node.selected:
		return
	
	var state = fsm.get_state_by_name(node.name)
	state.graph_position = node.get_position() / graph_edit.get_size()
	
	if logs: print_debug(str(node.name) + " changed position: " + str(node.position))
	
	update_line_containers()


func _on_state_node_connection_attempt(starting_node: Control) -> void:
	var hovered_node = _find_hovered_node()

	if hovered_node != null && hovered_node != starting_node:
		add_node_connection(starting_node, hovered_node)


func _on_connection_removed(connection: FSM_Connection) -> void:
	if connection.from == null or connection.to == null:
		push_error("the connection form or to state is null, abort removal")
		return
	
	var from = fsm.get_state_by_name(str(connection.from.name))
	var to = fsm.get_state_by_name(str(connection.to.name))

	from.remove_connection(to)


func _on_connection_selected(connection: FSM_Connection) -> void:
	if connection.from == null or connection.to == null:
		return
	
	unselect_all_nodes()
	unselect_all_connections(connection)
	unselect_all_triggers()
	
	edited_state = fsm.get_state_by_name(connection.from.name)
	condition_editor.edited_state = edited_state
	
	selected_trigger_control = connection

	condition_editor.animation_handler = fsm.get_animation_handler()
	print("_on_connection_selected")


func _on_connection_unselected(connection: FSM_Connection) -> void:
	if selected_trigger_control == connection:
		selected_trigger_control = null


func _on_selected_trigger_control_changed(trigger_control: Control) -> void:
	selected_trigger = fsm_connection_get_connection(trigger_control)
	print_stack()
	print("selected_trigger_control_changed: %s" % str(trigger_control.name))


func _on_selected_trigger_changed(trigger: StateTrigger) -> void:
	update_connection_editor()


func _on_toolbar_button_pressed(button: Button) -> void:
	if logs: print_debug("toolbar button pressed %s" % str(button.name))
	var is_connection : bool = selected_trigger is StateConnection

	var from_state_name = selected_trigger_control.from.name if is_connection else ""
	var from_state = fsm.get_state_by_name(from_state_name) if is_connection else edited_state
	
	if from_state == null:
		push_error("From state with name %s couldn't be found" % from_state_name)
		return
	
	var from_state_path = from_state.owner.get_path_to(from_state)

	match(str(button.name)):
		"AddCondition":
			var edited_event : StateEvent = condition_editor.edited_event
			edited_event.add_condition("", from_state.get_path_to(from_state.owner))

		"AddEvent":
			selected_trigger.add_event("process", from_state.get_path_to(from_state.owner))

		"AddAnimFinishedEvent":
			var anim_handler = condition_editor.animation_handler
			var animated_sprite = anim_handler.animated_sprite
			
			var animated_sprite_path = from_state.get_path_to(animated_sprite)
			
			selected_trigger.add_event("animation_finished", animated_sprite_path)

	condition_editor.update_content(from_state_path, selected_trigger)


func _on_footer_button_pressed(button: Button) -> void:
	match(str(button.name)):
		"DeleteConnection":
			if selected_trigger_control == null:
				push_error("There is no selected connection, the ConditionEditor shouln't be visible")
			else:
				selected_trigger_control.delete()

		"DeleteStandaloneTrigger":
			var state = fsm.get_state_by_name(str(selected_node.name))
			state.remove_standalone_trigger()

			selected_node.has_standalone_trigger = false


func _on_GraphEdit_item_rect_changed() -> void:
	_update_graph_display()
	if logs: print_debug("item_rect_changed called, update display")


func _on_GraphEdit_scroll_offset_changed(offset: Vector2) -> void:
	_update_graph_display()


func _on_GraphEdit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT]:
			if logs: print_debug("mouse wheel used, update display")
			await get_tree().process_frame
			_update_graph_display()


func _on_ConditionEditor_remove_condition(condition: StateCondition) -> void:
	if selected_trigger == null:
		push_error("Can't remove_at the given condition: no connection is currently selected")
	else:
		for event in selected_trigger.events:
			var id = event.conditions.find(condition)
			if id != -1:
				event.conditions.remove_at(id)
				update_connection_editor()
				return

	push_error("condition couldn't be found, removal aborted")


func _on_ConditionEditor_remove_event(event: StateEvent) -> void:
	if selected_trigger == null:
		push_error("Can't remove_at the given event: no connection is currently selected")
	else:
		var id = selected_trigger.events.find(event)
		print("found event to remove at id %d" % id)
		
		if id != -1:
			selected_trigger.events.remove_at(id)
			update_connection_editor()
			return

	push_error("event couldn't be found, removal aborted")


func _on_node_trigger_selected(node: Control) -> void:
	unselect_all_triggers(node)
	unselect_all_connections()

	edited_state = fsm.get_state_by_name(node.name)
	condition_editor.edited_state = edited_state
	
	condition_editor.animation_handler = null
	selected_trigger = edited_state.standalone_trigger


func _on_node_selected_changed(node: StateGraphNode) -> void:
	if node.selected:
		unselect_all_nodes(node)
		selected_node = node
	else:
		if node == selected_node:
			selected_node = null
			selected_trigger = null


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
		unselect_all_connections()


func _on_connection_path_changed_query(key: String, path: NodePath) -> void:
	var state = fsm.owner.get_node_or_null(path)
	
	if state == null or not state is State:
		push_error("No State could be found at the given path. The path must be relative to the root of the scene, and to designated node must be a State.")
		return
	
	selected_connection_change_state(key, state)


func _on_visibility_changed() -> void:
	if visible:
		_update()
		
		await get_tree().process_frame
		_update_nodes_position()
		
		await get_tree().process_frame
		_update_graph_display()

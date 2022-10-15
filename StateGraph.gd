@tool
extends EditorPlugin
class_name StateGraph

var fsm_editor_scene = preload("res://addons/StateGraph/GraphEditor/GraphEditor.tscn")

var edited_scene_path = ""
var current_scene_root : Node = null

var fsm_editor : Node = null
var fsm_editor_button : Button = null


#### ACCESSORS ####

func is_class(value: String): return value == "StateMachineHandler" or super.is_class(value)
func get_class() -> String: return "StateMachineHandler"


#### BUILT-IN ####

func _ready() -> void:
	var __ = connect("scene_changed", Callable(self,"_on_scene_changed"))

	__ = fsm_editor.connect("inspect_node_query", Callable(self,"_on_inspect_node_query"))


func _enter_tree() -> void:
	fsm_editor = fsm_editor_scene.instantiate()
	fsm_editor_button = add_control_to_bottom_panel(fsm_editor, "StateMachine")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(fsm_editor)


#### VIRTUALS ####

func _handles(obj: Variant) -> bool:
	_update_graph_editor_visibility()
	
	if obj is GDScript:
		return false
	
	return obj is State




#### LOGIC ####

func _update_graph_editor_visibility() -> void:
	var state_selected : bool = has_state_selected()
	
	if state_selected:
		var interface = get_editor_interface()
		var state = interface.get_selection().get_selected_nodes()[0]
		var fsm = state.get_master_state_machine()
		
		if fsm.owner == current_scene_root:
			fsm_editor.feed(fsm)
	else:
		fsm_editor_button.set_pressed(false)
	
	fsm_editor_button.set_visible(state_selected)


func has_state_selected() -> bool:
	var interface = get_editor_interface()
	var selection = interface.get_selection()
	
	for node in selection.get_selected_nodes():
		if node is State:
			return true
	return false



#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_scene_changed(scene_root: Node) -> void:
	print_debug("scene_changed to %s" % str(scene_root.name))
	
	if not scene_root is State:
		fsm_editor.clear()
	
	current_scene_root = scene_root
	fsm_editor.edited_scene_root = scene_root
	
	await get_tree().process_frame
	
	_update_graph_editor_visibility()


func _on_inspect_node_query(node: Node) -> void:
	var interface = get_editor_interface()
	var selection = interface.get_selection()

	selection.clear()
	selection.add_node(node)

@tool
extends EditorPlugin
class_name StateGraph

var fsm_editor_scene = preload("res://addons/StateGraph/GraphEditor/GraphEditor.tscn")

var edited_scene_path = ""

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
	
	var handled = obj is StateMachine or (obj is State && obj.get_parent() is StateMachine)
	
	return handled


func _edit(obj: Variant) -> void:
	var handled_fsm = obj if obj is StateMachine else obj.get_parent()
	fsm_editor.feed(handled_fsm)



#### LOGIC ####

func _update_graph_editor_visibility() -> void:
	var state_selected : bool = has_state_selected()
	
	if !state_selected:
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
	if not scene_root is State:
		fsm_editor.clear()
	
	fsm_editor.set_visible(scene_root is State)
	fsm_editor_button.set_visible(scene_root is State)
	
	fsm_editor.edited_scene_root = scene_root
	
	_update_graph_editor_visibility()


func _on_inspect_node_query(node: Node) -> void:
	var interface = get_editor_interface()
	var selection = interface.get_selection()

	selection.clear()
	selection.add_node(node)

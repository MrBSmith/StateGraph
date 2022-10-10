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
	var __ = connect("scene_changed",Callable(self,"_on_scene_changed"))

	__ = fsm_editor.connect("inspect_node_query",Callable(self,"_on_inspect_node_query"))
	__ = fsm_editor.connect("visibility_changed",Callable(self,"_on_fsm_editor_visibility_changed"))


func _enter_tree() -> void:
	fsm_editor = fsm_editor_scene.instantiate()
	fsm_editor_button = add_control_to_bottom_panel(fsm_editor, "StateMachine")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(fsm_editor)


#### VIRTUALS ####

func _handles(obj: Variant) -> bool:
	if obj is GDScript:
		return false
	
	var handled = obj is StateMachine or (obj is State && obj.get_parent() is StateMachine)
	
	fsm_editor_button.set_visible(obj is State)

	if fsm_editor_button.pressed:
		fsm_editor.set_visible(obj is State)
	
	if handled:
		print("%s obj is handled" % str(obj.name))
	else:
		print("%s obj is NOT handled" % str(obj.name))
	
	return handled


func _edit(obj: Variant) -> void:
	var handled_fsm = obj if obj is StateMachine else obj.get_parent()
	fsm_editor.feed(handled_fsm)


#### LOGIC ####



#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_scene_changed(scene_root: Node) -> void:
	if scene_root == null:
		edited_scene_path = ""
	else:
		edited_scene_path = scene_root.scene_file_path



func _on_inspect_node_query(node: Node) -> void:
	var interface = get_editor_interface()
	var selection = interface.get_selection()

	selection.clear()
	selection.add_node(node)


func _on_fsm_editor_visibility_changed() -> void:
	pass

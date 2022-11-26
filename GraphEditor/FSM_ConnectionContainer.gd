@tool
extends Container
class_name FSM_ConnectionContainer

@onready var v_box_container = $VBoxContainer

var from : Control
var to : Control

#### ACCESSORS ####

func is_class(value: String): return value == "FSM_ConnectionContainer" or super.is_class(value)
func get_class() -> String: return "FSM_ConnectionContainer"


#### BUILT-IN ####

func _ready() -> void:
	var __ = connect("sort_children",Callable(self,"_on_sort_children"))

#### VIRTUALS ####



#### LOGIC ####

func add_connection(fsm_connection: FSM_Connection) -> void:
	$VBoxContainer.add_child(fsm_connection)
	fsm_connection.connect("removed",Callable(self,"_on_connection_removed").bind(fsm_connection))
	
	update_vbox_container()


func update_vbox_container() -> void:
	v_box_container.set_position(Vector2(0, -v_box_container.size.y / 2))
	v_box_container.set_pivot_offset(-v_box_container.get_position())


#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_sort_children() -> void:
	update_vbox_container()


func _on_connection_removed(connection: FSM_Connection) -> void:
	await connection.tree_exited
	v_box_container.size.y = 0.0
	
	update_vbox_container()

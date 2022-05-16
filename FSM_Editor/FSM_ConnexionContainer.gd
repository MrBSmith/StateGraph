tool
extends Container
class_name FSM_ConnexionContainer

onready var v_box_container = $VBoxContainer

var from : Control
var to : Control

#### ACCESSORS ####

func is_class(value: String): return value == "FSM_ConnexionContainer" or .is_class(value)
func get_class() -> String: return "FSM_ConnexionContainer"


#### BUILT-IN ####

func _ready() -> void:
	var __ = connect("sort_children", self, "_on_sort_children")

#### VIRTUALS ####



#### LOGIC ####

func add_connexion(fsm_connexion: FSM_Connexion) -> void:
	$VBoxContainer.add_child(fsm_connexion)
	fsm_connexion.connect("removed", self, "_on_connexion_removed", [fsm_connexion])
	
	update_vbox_container()


func update_vbox_container() -> void:
	v_box_container.set_position(Vector2(0, -v_box_container.rect_size.y / 2))
	v_box_container.set_pivot_offset(-v_box_container.get_position())


#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_sort_children() -> void:
	update_vbox_container()


func _on_connexion_removed(connexion: FSM_Connexion) -> void:
	yield(connexion, "tree_exited")
	v_box_container.rect_size.y = 0.0
	
	update_vbox_container()

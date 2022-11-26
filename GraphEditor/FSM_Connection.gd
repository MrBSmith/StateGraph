@tool
extends Control
class_name FSM_Connection

enum STATE {
	NORMAL,
	HOVERED,
	SELECTED
}

@onready var line = $Line2D
@onready var clickable_area = $ClickableArea
@onready var color_rect = %ColorRect
@onready var texture_rect = %TextureRect

var from : Control = null
var to : Control = null

var state : int = STATE.NORMAL :
	get:
		return state
	set(value):
		if state != value:
			var previous_state = state
			state = value
			emit_signal("state_changed", previous_state, state)


var inverted : bool = false

@export var normal_color := Color.BLUE_VIOLET
@export var hovered_color := Color.AQUA
@export var selected_color := Color.RED

signal state_changed(previous_state, state)
signal selected()
signal unselected()
signal removed()

#### ACCESSORS ####



#### BUILT-IN ####


func _ready() -> void:
	var __

	if from:
		__ = from.connect("tree_exited",Callable(self,"_on_node_tree_exited"))
	if to:
		__ = to.connect("tree_exited",Callable(self,"_on_node_tree_exited"))

	__ = clickable_area.connect("gui_input", Callable(self,"_on_clickable_area_gui_input"))
	__ = clickable_area.connect("mouse_entered", Callable(self,"_on_clickable_area_mouse_entered"))
	__ = clickable_area.connect("mouse_exited", Callable(self,"_on_clickable_area_mouse_exited"))
	__ = clickable_area.connect("focus_exited", Callable(self,"_on_clickable_area_focus_exited"))

	__ = connect("state_changed", Callable(self,"_on_state_changed"))
	__ = connect("item_rect_changed", Callable(self,"_on_item_rect_changed"))
	
	texture_rect.set_flip_h(inverted)
	color_rect.set_color(normal_color)
	
	if is_instance_valid(from) && is_instance_valid(to):
		update_line()


#### VIRTUALS ####



#### LOGIC ####

func update_line() -> void:
	if !is_instance_valid(from) or !is_instance_valid(to):
		queue_free()
		return
	
	var origin = Vector2(0, size.y / 2)
	var dest = Vector2(size.x, size.y / 2)
	line.set_points(PackedVector2Array([origin, dest]))



func delete() -> void:
	emit_signal("unselected")
	emit_signal("removed")
	get_viewport().set_input_as_handled()
	queue_free()



#### INPUTS ####

func _input(event: InputEvent) -> void:
	if event is InputEventKey && !event.is_echo():
		if event.keycode == KEY_ESCAPE:
			state = STATE.NORMAL



#### SIGNAL RESPONSES ####

func _on_node_tree_exited() -> void:
	queue_free()


func _on_clickable_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed() && !event.is_echo():
			state = STATE.SELECTED


func _on_state_changed(previous_state: int, new_state: int) -> void:
	
	match(new_state):
		STATE.NORMAL:
			color_rect.set_color(normal_color)

		STATE.HOVERED:
			color_rect.set_color(hovered_color)

		STATE.SELECTED:
			color_rect.set_color(selected_color)
			emit_signal("selected")

	if previous_state == STATE.SELECTED:
		emit_signal("unselected")


func _on_clickable_area_mouse_entered() -> void:
	if state == STATE.NORMAL:
		state = STATE.HOVERED


func _on_clickable_area_mouse_exited() -> void:
	if state == STATE.HOVERED:
		state = STATE.NORMAL


func _on_clickable_area_focus_exited() -> void:
	state = STATE.NORMAL


func _on_item_rect_changed() -> void:
	update_line()

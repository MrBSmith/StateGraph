tool
extends Control
class_name FSM_Connexion

enum STATE {
	NORMAL,
	HOVERED,
	SELECTED
}

onready var line = $Line2D
onready var clickable_area = $ClickableArea
onready var color_rect = $ClickableArea/ColorRect
onready var texture_rect = $ClickableArea/TextureRect

onready var arrow_texture = clickable_area.get_icon("TransitionImmediateBig", "EditorIcons")

var from : Control = null
var to : Control = null

var state : int = STATE.NORMAL setget set_state

var inverted : bool = false

export var normal_color := Color.transparent
export var hovered_color := Color.aqua
export var selected_color := Color.red

signal state_changed(previous_state, state)
signal selected()
signal unselected()
signal removed()

#### ACCESSORS ####


func set_state(value: int) -> void:
	if state != value:
		var previous_state = state
		state = value
		emit_signal("state_changed", previous_state, state)


#### BUILT-IN ####


func _ready() -> void:
	var __

	if from :
		__ = from.connect("tree_exited", self, "_on_node_tree_exited")
	if to:
		__ = to.connect("tree_exited", self, "_on_node_tree_exited")

	__ = clickable_area.connect("gui_input", self, "_on_clickable_area_gui_input")
	__ = clickable_area.connect("mouse_entered", self, "_on_clickable_area_mouse_entered")
	__ = clickable_area.connect("mouse_exited", self, "_on_clickable_area_mouse_exited")
	__ = clickable_area.connect("focus_exited", self, "_on_clickable_area_focus_exited")

	__ = connect("state_changed", self, "_on_state_changed")
	__ = connect("item_rect_changed", self, "_on_item_rect_changed")
	
	texture_rect.set_texture(arrow_texture)
	texture_rect.set_flip_h(inverted)
	
	if is_instance_valid(from) && is_instance_valid(to):
		update_line()


#### VIRTUALS ####



#### LOGIC ####

func update_line() -> void:
	if !is_instance_valid(from) or !is_instance_valid(to):
		queue_free()
		return
	
	var origin = Vector2(0, rect_size.y / 2)
	var dest = Vector2(rect_size.x, rect_size.y / 2)
	line.set_points(PoolVector2Array([origin, dest]))



func delete() -> void:
	emit_signal("unselected")
	emit_signal("removed")
	get_tree().set_input_as_handled()
	queue_free()



#### INPUTS ####

func _input(event: InputEvent) -> void:
	if event is InputEventKey && !event.is_echo():
		if event.scancode == KEY_ESCAPE:
			set_state(STATE.NORMAL)



#### SIGNAL RESPONSES ####

func _on_node_tree_exited() -> void:
	queue_free()


func _on_clickable_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.button_index == BUTTON_LEFT:
		if event.is_pressed() && !event.is_echo():
			set_state(STATE.SELECTED)


func _on_state_changed(previous_state: int, new_state: int) -> void:
	match(new_state):
		STATE.NORMAL:
			color_rect.set_frame_color(normal_color)

		STATE.HOVERED:
			color_rect.set_frame_color(hovered_color)

		STATE.SELECTED:
			color_rect.set_frame_color(selected_color)
			emit_signal("selected")

	if previous_state == STATE.SELECTED:
		emit_signal("unselected")


func _on_clickable_area_mouse_entered() -> void:
	if state == STATE.NORMAL:
		set_state(STATE.HOVERED)


func _on_clickable_area_mouse_exited() -> void:
	if state == STATE.HOVERED:
		set_state(STATE.NORMAL)


func _on_clickable_area_focus_exited() -> void:
	set_state(STATE.NORMAL)


func _on_item_rect_changed() -> void:
	update_line()

tool
extends Control

onready var line = $Line2D
onready var label = $CenterContainer/Label
onready var trigger_button = $TriggerButton

var drawing_line : bool = false setget set_drawing_line
var dragged : bool = false setget set_dragged
var mouse_offset := Vector2.ZERO
var has_standalone_trigger : bool = false setget set_has_standalone_trigger

var selected : bool = false setget set_selected, is_selected

signal selected_changed(value)
signal connexion_attempt()
signal drawing_line_changed(value)
signal dragged_changed(value)
signal trigger_selected()
signal has_standalone_trigger_changed(value)

#### ACCESSORS ####

func set_drawing_line(value: bool) -> void:
	if drawing_line != value:
		drawing_line = value
		emit_signal("drawing_line_changed", drawing_line)

func set_dragged(value: bool) -> void:
	if dragged != value:
		dragged = value
		emit_signal("dragged_changed", dragged)

func set_selected(value: bool) -> void:
	if value != selected:
		selected = value
		emit_signal("selected_changed", selected)
func is_selected() -> bool: return selected

func set_has_standalone_trigger(value: bool) -> void:
	if value != has_standalone_trigger:
		has_standalone_trigger = value
		emit_signal("has_standalone_trigger_changed", value)

#### BUILT-IN ####

func _ready() -> void:
	connect("drawing_line_changed", self, "_on_drawing_line_changed")
	connect("dragged_changed", self, "_on_dragged_changed")
	connect("selected_changed", self, "_on_selected_changed")
	connect("has_standalone_trigger_changed", self, "_on_has_standalone_trigger_changed")
	trigger_button.connect("pressed", self, "_on_trigger_button_pressed")
	
	label.set_text(name)
	
	trigger_button.set_button_icon(get_icon("Signals", "EditorIcons"))
	trigger_button.set_visible(has_standalone_trigger)


func _process(delta: float) -> void:
	if dragged:
		var mouse_pos = get_parent().get_local_mouse_position()
		var node_pos = mouse_pos - mouse_offset
		node_pos = Vector2(clamp(node_pos.x, 0.0, get_parent().rect_size.x - rect_size.x),
						clamp(node_pos.y, 0.0, get_parent().rect_size.y - rect_size.y))
		
		set_position(node_pos)
	
	if drawing_line:
		line.set_points([get_size() / 2, get_local_mouse_position()])
	else:
		line.set_points(PoolVector2Array())


#### VIRTUALS ####



#### LOGIC ####


func unselect_trigger() -> void:
	trigger_button.set_pressed(false)


#### INPUTS ####

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.is_pressed() && !event.is_echo():
		match(event.button_index):
			BUTTON_LEFT: 
				set_dragged(true)
				set_selected(true)

			BUTTON_RIGHT: 
				set_drawing_line(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton && !event.is_pressed():
		match(event.button_index):
			BUTTON_LEFT: set_dragged(false)
			BUTTON_RIGHT: set_drawing_line(false)
	
	elif event is InputEventKey && event.is_pressed() && !event.is_echo():
		match(event.scancode):
			KEY_ESCAPE:
				set_selected(false)
				$TriggerButton.set_pressed(false)


#### SIGNAL RESPONSES ####


func _on_drawing_line_changed(_value: bool) -> void:
	if !drawing_line:
		emit_signal("connexion_attempt")


func _on_dragged_changed(_value: bool) -> void:
	if dragged:
		mouse_offset = get_local_mouse_position()
	else:
		mouse_offset = Vector2.ZERO


func _on_trigger_button_pressed() -> void:
	emit_signal("trigger_selected")
	set_selected(true)


func _on_standalone_trigger_added() -> void:
	trigger_button.set_visible(true)
	has_standalone_trigger = true


func _on_standalone_trigger_removed() -> void:
	trigger_button.set_visible(false)
	has_standalone_trigger = false


func _on_selected_changed(_value: bool) -> void:
	$SelectedPanel.set_visible(selected)
	if !selected:
		$TriggerButton.pressed = false


func _on_has_standalone_trigger_changed(value: bool) -> void:
	$TriggerButton.pressed = false
	$TriggerButton.set_visible(value)

@tool
extends GraphNode
class_name StateGraphNode

@onready var line = $Line2D
@onready var trigger_button : Button = $TriggerButton

var drawing_line : bool = false :
	get:
		return drawing_line
	set(value):
		if drawing_line != value:
			drawing_line = value
			emit_signal("drawing_line_changed", drawing_line)

var mouse_offset := Vector2.ZERO

var has_standalone_trigger : bool = false :
	get:
		return has_standalone_trigger 
	set(value):
		if value != has_standalone_trigger:
			has_standalone_trigger = value
			emit_signal("has_standalone_trigger_changed", value)

signal connection_attempt()
signal drawing_line_changed(value)
signal trigger_selected()
signal has_standalone_trigger_changed(value)

#### ACCESSORS ####


func is_selected() -> bool: return selected


#### BUILT-IN ####

func _ready() -> void:
	drawing_line_changed.connect(_on_drawing_line_changed)
	node_selected.connect(_on_selected_changed)
	node_deselected.connect(_on_selected_changed)
	has_standalone_trigger_changed.connect(_on_has_standalone_trigger_changed)
	
	trigger_button.pressed.connect(_on_trigger_button_pressed)
	trigger_button.set_button_icon(get_theme_icon("Signals", "EditorIcons"))
	trigger_button.set_visible(has_standalone_trigger)


func _process(delta: float) -> void:
	if drawing_line:
		line.set_points([get_size() / 2, get_local_mouse_position()])
	else:
		line.set_points(PackedVector2Array())


#### VIRTUALS ####



#### LOGIC ####


func unselect_trigger() -> void:
	trigger_button.set_pressed(false)


#### INPUTS ####

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.is_pressed() && !event.is_echo():
		match(event.button_index):
			MOUSE_BUTTON_LEFT:
				set_selected(true)

			MOUSE_BUTTON_RIGHT: 
				drawing_line = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton && !event.is_pressed():
		match(event.button_index):
			MOUSE_BUTTON_RIGHT: 
				drawing_line = false
	
	elif event is InputEventKey && event.is_pressed() && !event.is_echo():
		match(event.keycode):
			KEY_ESCAPE:
				set_selected(false)
				$TriggerButton.set_pressed(false)


#### SIGNAL RESPONSES ####


func _on_drawing_line_changed(value: bool) -> void:
	if !drawing_line:
		emit_signal("connection_attempt")


func _on_trigger_button_pressed() -> void:
	emit_signal("trigger_selected")
	set_selected(true)


func _on_standalone_trigger_added() -> void:
	trigger_button.set_visible(true)
	has_standalone_trigger = true


func _on_standalone_trigger_removed() -> void:
	trigger_button.set_visible(false)
	has_standalone_trigger = false


func _on_selected_changed() -> void:
	if !selected:
		$TriggerButton.button_pressed = false


func _on_has_standalone_trigger_changed(value: bool) -> void:
	$TriggerButton.button_pressed = false
	$TriggerButton.set_visible(value)


func _on_state_renamed(state: State) -> void:
	set_name(state.name)
	set_title(name)

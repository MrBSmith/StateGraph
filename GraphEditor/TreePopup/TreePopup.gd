@tool
extends PopupPanel
class_name TreePopup

@onready var tree = %Tree
@onready var button_container = %ButtonContainer

var root_node : Node = null:
	get:
		return root_node
	set(value):
		if value != root_node:
			root_node = value
			root_node_changed.emit()
var selected_tree_item : TreeItem
var wanted_class : String = ""
var exeptions : Array = []
var direct_parent : Node = null

signal root_node_changed
signal finished(node_path)


#### BUILT-IN ####

func _init() -> void:
	root_node_changed.connect(_update_tree)


func _ready() -> void:
	exclusive = true

	set_position(get_tree().get_root().size / 2 - size / 2) 
	_update_tree()
	
	print("wanted_class: " + wanted_class)
	print("direct_parent: " + str(direct_parent))
	print("exeptions: " + str(exeptions))
	
	for button in button_container.get_children():
		button.pressed.connect(_on_button_pressed.bind(button))


#### LOGIC ####

func _update_tree() -> void:
	if tree == null:
		return
	
	tree.clear()
	
	if root_node != null:
		_display_tree(root_node)


func _display_tree(node: Node, parent: TreeItem = null) -> void:
	if parent == null:
		var root = _add_tree_item(node)
	
	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		var is_wanted = wanted_class == "" or child.is_class(wanted_class)
		var rightful_child = child.get_parent() == direct_parent or direct_parent == null
		var selectable = is_wanted && !is_exeption(child) && rightful_child
		var tree_node = _add_tree_item(child, parent, selectable, i)
		
		_display_tree(child, tree_node)


func _add_tree_item(node: Node, parent: TreeItem = null, selectable := true, id: int = -1) -> TreeItem:
	var tree_item = tree.create_item(parent, id)
	tree_item.set_text(0, str(node.name))
	tree_item.set_metadata(0, root_node.get_path_to(node))
	tree_item.set_selectable(0, selectable)
	
	if !selectable:
		tree_item.set_custom_color(0, Color.DARK_SLATE_GRAY)
	
	var icon = get_theme_icon(node.get_class(), "EditorIcons")
	if icon != null:
		tree_item.set_icon(0, icon)
	
	return tree_item


func is_exeption(node: Node) -> bool:
	for node_path in exeptions:
		if str(node_path) == str(root_node.get_path_to(node)):
			return true
	return false


func _confirm() -> void:
	var selected_item = tree.get_selected()
	if selected_item == null:
		return
	
	var node_path = tree.get_selected().get_metadata(0)
	print("confirm with node at path: %s" % str(node_path))
	finished.emit(node_path)
	queue_free()


func _cancel() -> void:
	finished.emit(NodePath())
	queue_free()


#### INPUTS ####


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey && !event.is_echo():
		match(event.keycode):
			KEY_ENTER: _confirm()
			KEY_ESCAPE: _cancel()


#### SIGNAL RESPONSES ####

func _on_button_pressed(button: Button) -> void:
	print("button pressed: %s" % str(button.name))
	
	match(str(button.name)):
		"Confirm": _confirm()
		"Cancel": _cancel()



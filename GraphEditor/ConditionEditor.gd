@tool
extends PanelContainer
class_name ConditionEditor

enum BUTTON_TYPE {
	REMOVE,
	EMITTER_PATH
}

@onready var add_event_button = $VBoxContainer/Toolbar/AddEvent
@onready var delete_trigger_button = $VBoxContainer/Footer/DeleteStandaloneTrigger
@onready var delete_connexion_button = $VBoxContainer/Footer/DeleteConnexion
@onready var add_anim_event_button = $VBoxContainer/Toolbar/AddAnimFinishedEvent
@onready var add_condition_button = $VBoxContainer/Toolbar/AddCondition
@onready var state_path_container = %StatePathContainer
@onready var tree = $VBoxContainer/Panel/VBoxContainer/Tree

@export var logs : bool = false
@export var tree_popup_scene : PackedScene

var animation_handler : StateAnimationHandler = null :
	get:
		return animation_handler
	set(value):
		if value != animation_handler:
			animation_handler = value
			emit_signal("animation_handler_changed")
var edited_event : StateEvent :
	get:
		return edited_event
	set(value):
		if edited_event != value:
			edited_event = value
			emit_signal("edited_event_changed")
var edited_trigger : StateTrigger
var edited_state : State

var tree_popup : TreePopup = null 

signal remove_event(dict)
signal remove_condition(dict)
signal animation_handler_changed()
signal edited_event_changed()
signal connexion_path_changed_query(key, path)
signal _change


class TreeItemData:
	var obj : Object = null
	var key : String = ""
	
	func _init(_obj: Object, _key: String) -> void:
		obj = _obj
		key = _key


#### ACCESSORS ####


#### BUILT-IN ####


func _ready() -> void:
	tree.button_clicked.connect(_on_tree_button_clicked)
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_edited.connect(_on_tree_item_edited)
	
	edited_event_changed.connect(_on_edited_event_changed)
	animation_handler_changed.connect(_on_animation_handler_changed)
	remove_event.connect(_on_remove_event)
	
	for child in state_path_container.get_children():
		var line_edit = child.get_node("LineEdit")
		line_edit.text_submitted.connect(_on_text_entered.bind(child))
		
		var edit_button = child.get_node("EditButton")
		edit_button.set_texture_normal(get_theme_icon("Edit", "EditorIcons"))
		edit_button.pressed.connect(_on_state_path_edit_button_pressed.bind(child))



#### VIRTUALS ####



#### LOGIC ####

func clear() -> void:
	hide_all_buttons()
	tree.clear()
	
	for child in state_path_container.get_children():
		var line_edit = child.get_node("LineEdit")
		line_edit.set_editable(false)
		line_edit.set_text("None")


func hide_all_buttons() -> void:
	for button in $VBoxContainer/Toolbar.get_children():
		button.set_visible(false)
	
	for button in $VBoxContainer/Footer.get_children():
		button.set_visible(false)


func update_content(origin_state_path: NodePath, trigger: StateTrigger) -> void:
	edited_trigger = trigger
	
	var is_connection : bool = trigger is StateConnexion
	
	delete_connexion_button.set_visible(is_connection)
	delete_trigger_button.set_visible(!is_connection)
	
	update_state_path_line_edits(origin_state_path)
	
	add_event_button.set_visible(true)
	add_anim_event_button.set_visible(true)
	
	update_tree()


func update_state_path_line_edits(origin_state_path: NodePath) -> void:
	var is_connexion : bool = edited_trigger is StateConnexion
	
	var origin_path = str(origin_state_path) if is_connexion else "None"
	var dest_path = str(edited_trigger.to) if is_connexion else "None"
	
	state_path_container.get_node("OriginState/LineEdit").set_text(origin_path)
	state_path_container.get_node("DestState/LineEdit").set_text(dest_path)


func update_tree() -> void:
	tree.clear()
	tree.set_columns(2)
	var root = tree.create_item()
	tree.set_hide_root(true)
	
	if edited_trigger == null:
		return
	
	for event in edited_trigger.events:
		var event_tree_item = add_tree_item(root, TreeItemData.new(event, "trigger"), 
											get_theme_icon("Signals", "EditorIcons"))
		
		var emitter_path_item = add_tree_item(event_tree_item, TreeItemData.new(event, "emitter_path"),
											get_theme_icon("Signal", "EditorIcons"), false, false)
		
		for condition in event.conditions:
			var condition_tree_item = add_tree_item(event_tree_item, TreeItemData.new(condition, "condition"), get_theme_icon("Key", "EditorIcons"), true)
			var target_tree_item = add_tree_item(condition_tree_item, TreeItemData.new(condition, "target_path"), get_theme_icon("NodePath", "EditorIcons"), false, false)


func add_tree_item(parent: TreeItem, tree_item_data : TreeItemData = null, icon: Texture = null, collapsed: bool = false, removeable: bool = true, editable: bool = true) -> TreeItem:
	var item = tree.create_item(parent)
	item.set_text(0, tree_item_data.key.capitalize())
	item.set_text(1, tree_item_data.obj.get(tree_item_data.key))
	item.set_custom_color(0, Color.DIM_GRAY)
	item.set_editable(1, editable)
	item.set_metadata(1, tree_item_data)
	item.set_icon(0, icon)
	item.set_collapsed(collapsed)
	
	if removeable:
		item.add_button(1, get_theme_icon("Remove", "EditorIcons"), BUTTON_TYPE.REMOVE)
	
	if tree_item_data.key == "emitter_path":
		item.add_button(1, get_theme_icon("Edit", "EditorIcons"), BUTTON_TYPE.EMITTER_PATH)
	
	return item


func create_tree_popup(wanted_class : String = "", direct_parent: Node = null, exeptions : Array = []) -> void:
	tree_popup = tree_popup_scene.instantiate()
	tree_popup.root_node = edited_state.owner
	tree_popup.wanted_class = wanted_class
	tree_popup.exeptions = exeptions
	tree_popup.direct_parent = direct_parent
	add_child(tree_popup)


#### INPUTS ####



#### SIGNAL RESPONSES ####


func _on_tree_item_edited() -> void:
	var tree_item = tree.get_edited()
	var value = tree_item.get_text(1)
	var tree_item_data = tree_item.get_metadata(1)
	
	tree_item_data.obj.set(tree_item_data.key, value)


func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, _button_index: int) -> void:
	if logs: print("tree button pressed")
	
	match(id):
		BUTTON_TYPE.REMOVE: 
			var tree_item_data = item.get_metadata(1)
			
			match(tree_item_data.key):
				"trigger": emit_signal("remove_event", tree_item_data.obj)
				"condition": emit_signal("remove_condition", tree_item_data.obj)
		
		BUTTON_TYPE.EMITTER_PATH:
			create_tree_popup()
			
			var node_path = await tree_popup.finished
			if node_path.is_empty():
				return
			
			var data_dict = item.get_metadata(1)
			var target_node = edited_state.owner.get_node_or_null(node_path)
			
			if target_node == null:
				push_error("The target node couldn't be found a path %s" % str(node_path))
				return
			
			var relative_path = edited_state.get_path_to(target_node)
			
			item.set_text(1, str(relative_path))
			data_dict.obj.set(data_dict.key, str(relative_path))


func _on_tree_item_selected() -> void:
	if logs: print("tree item selected")
	
	var selected_item = tree.get_selected()
	var tree_item_data = selected_item.get_metadata(1)
	
	edited_event = tree_item_data.obj as StateEvent


func _on_animation_handler_changed() -> void:
	add_anim_event_button.set_visible(animation_handler != null)


func _on_edited_event_changed() -> void:
	add_condition_button.set_visible(edited_event != null)


func _on_remove_event(_event: StateEvent) -> void:
	edited_event = null


# Key is either "from" or "to" here
func _on_text_entered(path: String, key: String) -> void:
	emit_signal("connexion_path_changed_query", key, NodePath(path))


func _on_state_path_edit_button_pressed(container: Control) -> void:
	print("%s edit button pressed" % str(container.name))
	var line_edit = container.get_node("LineEdit") as LineEdit
	var exeptions = [NodePath(line_edit.text)]
	
	create_tree_popup("State", edited_state.get_parent(), exeptions)
	
	var node_path = await tree_popup.finished
	
	if node_path.is_empty():
		return
	
	line_edit.set_text(str(node_path))
	var key = "to" if str(container.name) == "DestState" else "from"
	
	emit_signal("connexion_path_changed_query", key, node_path)

tool
extends PanelContainer
class_name ConditionEditor

enum BUTTON_TYPE {
	REMOVE
}

onready var add_event_button = $VBoxContainer/Toolbar/AddEvent
onready var delete_trigger_button = $VBoxContainer/Footer/DeleteStandaloneTrigger
onready var delete_connexion_button = $VBoxContainer/Footer/DeleteConnexion
onready var add_anim_event_button = $VBoxContainer/Toolbar/AddAnimFinishedEvent
onready var add_condition_button = $VBoxContainer/Toolbar/AddCondition
onready var origin_state_line_edit = $VBoxContainer/Panel/VBoxContainer/OriginState/LineEdit
onready var dest_state_line_edit = $VBoxContainer/Panel/VBoxContainer/DestState/LineEdit

onready var tree = $VBoxContainer/Panel/VBoxContainer/Tree

var animation_handler : StateAnimationHandler = null setget set_animation_handler
var edited_event : Dictionary setget set_edited_event
var edited_trigger_dict : Dictionary

signal remove_event(dict)
signal remove_condition(dict)
signal animation_handler_changed()
signal edited_event_changed()
signal connexion_path_changed_query(key, path)


class DataDict:
	var dict : Dictionary = {}
	var key : String = ""
	
	func _init(_dict: Dictionary, _key: String) -> void:
		dict = _dict
		key = _key

#### ACCESSORS ####

func is_class(value: String): return value == "ConditionEditor" or .is_class(value)
func get_class() -> String: return "ConditionEditor"

func set_animation_handler(value: StateAnimationHandler) -> void:
	if value != animation_handler:
		animation_handler = value
		emit_signal("animation_handler_changed")

func set_edited_event(value: Dictionary) -> void:
	if edited_event != value:
		edited_event = value
		emit_signal("edited_event_changed")

#### BUILT-IN ####


func _ready() -> void:
	var __ = tree.connect("item_edited", self, "_on_tree_item_edited")
	__ = tree.connect("button_pressed", self, "_on_tree_button_pressed")
	__ = tree.connect("item_selected", self, "_on_item_selected")
	
	__ = connect("edited_event_changed", self, "_on_edited_event_changed")
	__ = connect("animation_handler_changed", self, "_on_animation_handler_changed")
	__ = connect("remove_event", self, "_on_remove_event")
	
	origin_state_line_edit.connect("text_entered", self, "_on_text_entered", ["from"])
	dest_state_line_edit.connect("text_entered", self, "_on_text_entered", ["to"])


#### VIRTUALS ####



#### LOGIC ####

func clear() -> void:
	hide_all_buttons()
	tree.clear()
	
	origin_state_line_edit.set_editable(false)
	dest_state_line_edit.set_editable(false)
	
	origin_state_line_edit.set_text("None")
	dest_state_line_edit.set_text("None")


func hide_all_buttons() -> void:
	for button in $VBoxContainer/Toolbar.get_children():
		button.set_visible(false)
	
	for button in $VBoxContainer/Footer.get_children():
		button.set_visible(false)


func update_content(origin_state_path: String, trigger: Dictionary) -> void:
	edited_trigger_dict = trigger
	
	var is_connection : bool = trigger["type"] == "connexion"
	
	delete_connexion_button.set_visible(is_connection)
	delete_trigger_button.set_visible(!is_connection)
	
	update_state_path_line_edits(origin_state_path)
	
	add_event_button.set_visible(true)
	add_anim_event_button.set_visible(true)
	
	update_tree()


func update_state_path_line_edits(origin_state_path: String) -> void:
	var is_connexion : bool = edited_trigger_dict["type"] == "connexion"
	
	origin_state_line_edit.set_editable(is_connexion)
	dest_state_line_edit.set_editable(is_connexion)
	
	var origin_path = origin_state_path if is_connexion else "None"
	var dest_path = edited_trigger_dict["to"] if is_connexion else "None"
	
	origin_state_line_edit.set_text(origin_path)
	dest_state_line_edit.set_text(dest_path)


func update_tree() -> void:
	tree.clear()
	tree.set_columns(2)
	var root = tree.create_item()
	tree.set_hide_root(true)
	
	if !edited_trigger_dict.has("events"):
		return
	
	for event in edited_trigger_dict["events"]:
		var event_tree_item = add_tree_item(root, DataDict.new(event, "trigger"), 
											get_icon("Signals", "EditorIcons"))
		
		var emitter_path_item = add_tree_item(event_tree_item, DataDict.new(event, "emitter_path"),
											get_icon("Signal", "EditorIcons"), false, false)
		
		for condition in event["conditions"]:
			var condition_tree_item = add_tree_item(event_tree_item, DataDict.new(condition, "condition"), get_icon("Key", "EditorIcons"), true)
			var target_tree_item = add_tree_item(condition_tree_item, DataDict.new(condition, "target_path"), get_icon("NodePath", "EditorIcons"), false, false)


func add_tree_item(parent: TreeItem, data_dict : DataDict = null, icon: Texture = null, collapsed: bool = false, removeable: bool = true, editable: bool = true) -> TreeItem:
	var item = tree.create_item(parent)
	item.set_text(0, data_dict.key.capitalize())
	item.set_text(1, data_dict.dict[data_dict.key])
	item.set_custom_color(0, Color.dimgray)
	item.set_editable(1, editable)
	item.set_metadata(1, data_dict)
	item.set_icon(0, icon)
	item.set_collapsed(collapsed)
	
	if removeable:
		item.add_button(1, get_icon("Remove", "EditorIcons"), 0)
	
	return item



#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_tree_item_edited() -> void:
	var tree_item = tree.get_edited()
	var value = tree_item.get_text(1)
	var data_dict = tree_item.get_metadata(1)
	
	data_dict.dict[data_dict.key] = value


func _on_tree_button_pressed(item: TreeItem, _column: int, button_index: int) -> void:
	match(button_index):
		BUTTON_TYPE.REMOVE: 
			var data_dict = item.get_metadata(1)
			
			match(data_dict.key):
				"trigger": emit_signal("remove_event", data_dict.dict)
				"condition": emit_signal("remove_condition", data_dict.dict)


func _on_item_selected() -> void:
	var selected_item = tree.get_selected()
	var data_dict = selected_item.get_metadata(1)
	
	set_edited_event(data_dict.dict)


func _on_animation_handler_changed() -> void:
	add_anim_event_button.set_visible(animation_handler != null)


func _on_edited_event_changed() -> void:
	add_condition_button.set_visible(!edited_event.empty())


func _on_remove_event(_event_dict: Dictionary) -> void:
	set_edited_event({})


# Key is either "from" or "to" here
func _on_text_entered(path: String, key: String) -> void:
	emit_signal("connexion_path_changed_query", key, path)

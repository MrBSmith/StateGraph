tool
extends Node
class_name StateAnimationHandler

enum MODE {
	ANIMATED_SPRITE,
	ANIMATION_PLAYER
}

const DIRECTIONS_4 : Dictionary = {
	"Up": Vector2.UP,
	"Right": Vector2.RIGHT,
	"Down": Vector2.DOWN,
	"Left": Vector2.LEFT
}

const DIRECTIONS_8 : Dictionary = {
	"Up": Vector2.UP,
	"UpRight": Vector2(1, -1),
	"Right": Vector2.RIGHT,
	"DownRight": Vector2.ONE,
	"Down": Vector2.DOWN,
	"DownLeft": Vector2(-1, 1),
	"Left": Vector2.LEFT,
	"UpLeft": Vector2(-1, -1)
}

onready var animated_sprite : AnimatedSprite = get_node_or_null(animated_sprite_path)
onready var animation_player : AnimationPlayer = get_node_or_null(animation_player_path)
onready var states_machine = get_parent()

export var animation_player_path : NodePath
export var animated_sprite_path : NodePath
export var recursive_animation_triggering : bool = true

export(MODE) var finished_trigger_mode : int = MODE.ANIMATED_SPRITE

var object_direction := Vector2.ZERO

#### ACCESSORS ####

func is_class(value: String): return value == "StateAnimationHandler" or .is_class(value)
func get_class() -> String: return "StateAnimationHandler"


#### BUILT-IN ####

func _ready() -> void:
	if Engine.editor_hint:
		return
	
	yield(owner, "ready")
	
	var __ = get_parent().connect("state_entered", self, "_on_StateMachine_state_entered")
	
	if animated_sprite && finished_trigger_mode == MODE.ANIMATED_SPRITE:
		__ = animated_sprite.connect("animation_finished", self, "_on_animation_finished")
	
	elif animation_player && finished_trigger_mode == MODE.ANIMATION_PLAYER:
		__ = animation_player.connect("animation_finished", self, "_on_animation_finished")
		


#### VIRTUALS ####


func trigger_state_sound(state: State) -> void:
	if state == null:
		return
	
	var audio_stream_player = state.get_node_or_null("AudioStreamPlayer")
	if audio_stream_player != null:
		audio_stream_player.stop()
		audio_stream_player.play()


func _update_sprite_animation(state: State) -> void:
	if state == null or animated_sprite == null:
		return

	var sprite_frames = animated_sprite.get_sprite_frames()
	if sprite_frames == null:
		return
	
	var dir_name = find_dir_name(object_direction)
	var previous_state = states_machine.previous_state
	
	var anim_name = state.name + dir_name
	var start_anim_name = "Start" + anim_name
	var trans_anim_name = previous_state.name + "To" + anim_name if previous_state else ""

	if sprite_frames.has_animation(start_anim_name):
		animated_sprite.play(start_anim_name)
	
	elif previous_state && sprite_frames.has_animation(trans_anim_name):
		animated_sprite.play(trans_anim_name)

	else:
		if sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)


func _update_animation_player(state: State) -> void:
	if state == null or animation_player == null:
		return
	
	var dir_name = find_dir_name(object_direction)
	var previous_state = states_machine.previous_state
	
	var anim_name = state.name + dir_name
	var start_anim_name = "Start" + anim_name
	var trans_anim_name = previous_state.name + "To" + anim_name if previous_state else ""

	if animation_player.has_animation(start_anim_name):
		animation_player.play(start_anim_name)
	
	elif previous_state && animation_player.has_animation(trans_anim_name):
		animation_player.play(trans_anim_name)

	else:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)


#### LOGIC ####

# Find the name of the given direction and returns it as a String
func find_dir_name(dir: Vector2) -> String:
	var dir_values_array = DIRECTIONS_8.values()
	var dir_index = dir_values_array.find(dir)
	
	if dir_index == -1:
		return ""
	
	var dir_keys_array = DIRECTIONS_8.keys()
	var dir_key = dir_keys_array[dir_index]
	
	return dir_key


#### SIGNAL RESPONSES #####

func _on_animation_finished() -> void:
	if animated_sprite == null:
		return
	
	var state = get_parent().get_state()
	
	if state == null:
		return
	
	var state_name = state.name
	
	var sprite_frames = animated_sprite.get_sprite_frames()
	var current_animation = animated_sprite.get_animation()
	
	if !state_name.is_subsequence_ofi(current_animation):
		return
	
	if current_animation == "Start" + state_name or ("To" + state_name).is_subsequence_ofi(current_animation):
		if sprite_frames != null and sprite_frames.has_animation(state_name):
			animated_sprite.play(state_name)


func _on_StateMachine_state_entered(new_state: Node) -> void:
	_update_sprite_animation(new_state)
	_update_animation_player(new_state)


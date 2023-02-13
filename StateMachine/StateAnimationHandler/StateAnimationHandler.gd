tool
extends Node
class_name StateAnimationHandler

enum FLIP {
	NONE = 0
	H = 1,
	V = 2
	ISO = 4
}

enum ANIM_NAME_MODE {
	PARENT_MOST_STATE_NAME,
	CHILD_MOST_STATE_NAME,
	RECURSIVE_NAME_COMPOSITION
}

enum MODE {
	ANIMATED_SPRITE,
	ANIMATION_PLAYER
}

enum DIRECTION_MODE {
	NONE,
	DIR_2,
	DIR_4,
	DIR_8
}

const DIRECTIONS_2 : Dictionary = {
	"Right": Vector2.RIGHT,
	"Left": Vector2.LEFT
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
	"UpLeft": -Vector2.ONE
}

onready var animated_sprite : AnimatedSprite = get_node_or_null(animated_sprite_path)
onready var animation_player : AnimationPlayer = get_node_or_null(animation_player_path)
onready var states_machine = get_parent()

export var animation_player_path : NodePath
export var animated_sprite_path : NodePath
export(ANIM_NAME_MODE) var anim_name_mode : int = ANIM_NAME_MODE.RECURSIVE_NAME_COMPOSITION

export(int, FLAGS, "flip_h", "flip_v", "flip_iso") var flip_mode = FLIP.H
export(MODE) var finished_trigger_mode : int = MODE.ANIMATED_SPRITE
export(DIRECTION_MODE) var direction_mode : int = DIRECTION_MODE.NONE

export var direction := Vector2.DOWN
export var debug_logs : bool = false

export var interupts_animations : bool = false

var state : State = null

#### ACCESSORS ####

func is_class(value: String): return value == "StateAnimationHandler" or .is_class(value)
func get_class() -> String: return "StateAnimationHandler"


#### BUILT-IN ####

func _ready() -> void:
	if Engine.editor_hint:
		return
	
	yield(owner, "ready")
	
	var __ = get_parent().connect("state_entered_recursive", self, "_on_StateMachine_state_entered_recursive")
	
	if animated_sprite && finished_trigger_mode == MODE.ANIMATED_SPRITE:
		__ = animated_sprite.connect("animation_finished", self, "_on_animation_finished")
	
#	elif animation_player && finished_trigger_mode == MODE.ANIMATION_PLAYER:
#		__ = animation_player.connect("animation_finished", self, "_on_animation_finished")
		


#### VIRTUALS ####


func trigger_state_sound() -> void:
	if state == null:
		return
	
	var audio_stream_player = state.get_node_or_null("AudioStreamPlayer")
	if audio_stream_player != null:
		audio_stream_player.stop()
		audio_stream_player.play()


func _update_animation() -> void:
	if state == null or (animated_sprite == null && animation_player == null):
		return
	
	# Handles flipping the sprites if necesary
	if flip_mode != FLIP.NONE:
		if flip_mode & FLIP.ISO:
			var flip_h = direction in [Vector2.DOWN, Vector2.LEFT] 
			animated_sprite.set_flip_h(flip_h)
		else:
			if direction.x != 0.0:
				var flip_h = (flip_mode & FLIP.H) && (direction.x < 0)
				animated_sprite.set_flip_h(flip_h)
			
			if direction.y != 0.0:
				var flip_v = (flip_mode & FLIP.V) && (direction.y < 0)
				animated_sprite.set_flip_v(flip_v)
	
	# Compute the animation name that needs to be played
	var dir_sufix = find_dir_name(direction)
	var previous_state = states_machine.previous_state
	
	var anim_name = get_anim_name(state) + dir_sufix
	var start_anim_name = "Start" + anim_name
	var trans_anim_name = previous_state.name + "To" + anim_name if previous_state else ""
	
	var sprite_frames = animated_sprite.get_sprite_frames() if animated_sprite else null
	
	# Play the animation
	for target in [animated_sprite, animation_player]:
		if target == null: continue
		
		var target_anim_owner = target if target is AnimationPlayer else sprite_frames
		var animation_to_play = ""
		if debug_logs: print("%s searched for an animation for state %s in %s" % [owner.name, state.name, target.name])
		
		
		if target_anim_owner.has_animation(start_anim_name):
			animation_to_play = start_anim_name
		
		elif previous_state && target_anim_owner.has_animation(trans_anim_name):
			animation_to_play = trans_anim_name

		else:
			if target_anim_owner.has_animation(anim_name):
				animation_to_play = anim_name
		
		if target_anim_owner.has_animation(animation_to_play):
			if interupts_animations and target is AnimationPlayer: 
				target.stop(true)
			
			target.play(animation_to_play)
			if debug_logs: print("StateAnimationHandler trigger %s animation in %s" % [animation_to_play, target.name])


#### LOGIC ####

# Find the name of the given direction and returns it as a String
func find_dir_name(dir: Vector2) -> String:
	var dir_dict = {}
	
	match(direction_mode):
		DIRECTION_MODE.NONE: return ""
		DIRECTION_MODE.DIR_2: dir_dict = DIRECTIONS_2
		DIRECTION_MODE.DIR_4: dir_dict = DIRECTIONS_4
		DIRECTION_MODE.DIR_8: dir_dict = DIRECTIONS_8
	
	if flip_mode & FLIP.ISO:
		if dir in [Vector2.DOWN, Vector2.LEFT]:
			dir = Vector2(dir.y, dir.x)
	else:
		if flip_mode & FLIP.H: dir.x = abs(dir.x)
		if flip_mode & FLIP.V: dir.y = abs(dir.y)
	
	var dir_values_array = dir_dict.values()
	var dir_index = dir_values_array.find(dir)
	
	if dir_index == -1:
		var dir_mode_id = DIRECTION_MODE.values().find(direction_mode)
		var dir_mode_name = DIRECTION_MODE.keys()[dir_mode_id]
		push_warning("Can't find any direction name corresponding to the direction %s in mode %s" % [str(dir), dir_mode_name])
		return ""
	
	var dir_keys_array = dir_dict.keys()
	var dir_key = dir_keys_array[dir_index]
	
	return dir_key


# Based on the anim_name_mode, returns a different anim name:
# If anim_name_mode is PARENT_MOST_STATE_NAME
# 	it will return only the parent state's name

# If anim_name_mode is CHILD_MOST_STATE_NAME
# 	it will return only the recursive current state name

# If anim_name_mode is RECURSIVE_NAME_COMPOSITION
# 	it will recursively add the children state's name together
func get_anim_name(state: Object) -> String:
	if anim_name_mode == ANIM_NAME_MODE.PARENT_MOST_STATE_NAME:
		return state.name
	
	if state.is_class("StateMachine"):
		var child_state = state.get_state()
		
		if child_state != null:
			match(anim_name_mode):
				ANIM_NAME_MODE.CHILD_MOST_STATE_NAME:
					return get_anim_name(child_state)
				ANIM_NAME_MODE.RECURSIVE_NAME_COMPOSITION:
					return state.name + get_anim_name(child_state)
	return state.name


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
	
	var anim_name = get_anim_name(state)
	
	if current_animation == "Start" + anim_name or ("To" + anim_name).is_subsequence_ofi(current_animation):
		if sprite_frames != null and sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)


func _on_StateMachine_state_entered_recursive(new_state: Node) -> void:
	state = new_state
	_update_animation()


func _on_direction_changed(dir: Vector2) -> void:
	direction = dir
	_update_animation()

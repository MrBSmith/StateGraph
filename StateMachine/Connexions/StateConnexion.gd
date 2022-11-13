extends StateTrigger
class_name StateConnexion

@export var to : NodePath


func _init(to_path: NodePath, events_array : Array[StateEvent]) -> void:
	to = to_path
	events = events_array

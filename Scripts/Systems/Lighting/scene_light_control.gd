@tool
extends Node

@export var scene_lights: Array[Node]
@export var scene_objects: Array[Node]

var tmp_index

func _process(delta: float) -> void:
	if scene_lights == null:
		scene_lights = []

func register_light(light_node):
	#needs a double check for empty slots and cleanup later
	if  not light_node in scene_lights:
		scene_lights.append(light_node)
		print("Registered light. New Count: ", scene_lights.size())

	return scene_lights.find(light_node)

func register_object(object_node):
	scene_objects.append(object_node)
	print("Registered object. New Count: ", scene_objects.size())
	return scene_objects.size() -1

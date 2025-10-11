@tool
extends Node

@export var scene_lights: Array[Node]
@export var scene_objects: Array[Node]

var tmp_index

func _process(delta: float) -> void:
	if scene_lights == null:
		scene_lights = []

func register_light(light_node):
	#replace with code for cycling through the list and checking if the light is registered
	if  light_node.light_id == -1:
		scene_lights.append(light_node)
		print("Registered light. New Count: ", scene_lights.size())
		tmp_index = scene_lights.size() -1
	else:
		tmp_index = light_node.light_id
	return tmp_index

func register_object(object_node):
	scene_objects.append(object_node)
	print("Registered object. New Count: ", scene_objects.size())
	return scene_objects.size() -1

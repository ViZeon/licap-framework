@tool
extends Node

@export var scene_lights = []
var scene_objects = []

var tmp_index

func register_light(light_node):
	if  light_node.light_id_set == true:
		tmp_index = light_node.light_id
		
	else:
		scene_lights.append(light_node)
		print("Registered light. New Count: ", scene_lights.size())
		tmp_index = scene_lights.size() -1
		light_node.light_id_set = true
	return tmp_index

func register_object(object_node):
	scene_objects.append(object_node)
	print("Registered object. New Count: ", scene_objects.size())
	return scene_objects.size() -1

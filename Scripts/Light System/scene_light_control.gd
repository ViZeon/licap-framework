@tool
extends Node

var scene_lights = []
var scene_objects = []

func register_light(light_node):
	scene_lights.append(light_node)
	print("Registered light. New Count: ", scene_lights.size())
	return scene_lights.size() -1

func register_object(object_node):
	scene_objects.append(object_node)
	print("Registered object. New Count: ", scene_objects.size())
	return scene_objects.size() -1

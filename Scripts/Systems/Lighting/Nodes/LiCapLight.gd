@tool
extends Node3D
class_name LiCapLight

@export var light_control: Node: 
	get:
		return light_control
	set(detected_conrol):
		light_control = detected_conrol
@export var light_control_initialized = false

@export var light_id: int = -1

func _ready() -> void:
	find_light_control()

func _process(delta: float) -> void:
	if not light_control_initialized:
		find_light_control()
		notify_property_list_changed()
		light_control_initialized = true
		light_id = light_control.register_light(self)

func find_light_control():
	light_control = get_owner().find_child("SceneLightControl")
	print (light_control)

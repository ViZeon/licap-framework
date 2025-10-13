@tool
extends Node3D
class_name LiCapLight

@export var licap_mat: Array [Material]
@export var light_var_name: String

@export var light_control_initialized = false
@export var detection_area_initialized = false

@export var light_id: int = -1
@export var light_range: float = 10.0

@export var detection_area: Area3D
@export var shape: CollisionShape3D
@export	var sphere: SphereShape3D

@export var bodies: Array[Node3D]

@export var light_control: Node: 
	get:
		return light_control
	set(detected_conrol):
		light_control = detected_conrol


var currObject
var current_pos

func _ready() -> void:
	setup()

func _process(delta: float) -> void:
	#setup()
	update_light_capture()


func tmp_process():
	bodies = detection_area.get_overlapping_bodies()
	for body in bodies:
		print("Overlapping: ", body.name)
		for child in body.get_children():
			if child is LiCapMesh3D:
				child.add_light(self)
			
func update_light_capture():
	current_pos = self.global_transform.origin
	for material in licap_mat:
		material.set_shader_parameter(light_var_name, current_pos)

func  setup():	
	if not detection_area_initialized:
		setup_detection_area()
		detection_area_initialized = true
	if not light_control_initialized:
		find_light_control()
		light_control_initialized = true

func find_light_control():	
	light_control = get_owner().find_child("SceneLightControl")
	notify_property_list_changed()
	
	light_id = light_control.register_light(self)
	print (light_control)

func setup_detection_area():
	#detection_area = Area3D.new()
	if detection_area == null:
		detection_area = Area3D.new()	
		add_child(detection_area)
		detection_area.owner = owner
	if shape == null:
		shape = CollisionShape3D.new()

	if sphere == null:
		sphere = SphereShape3D.new()
		shape.shape = sphere
		sphere.radius = light_range
		detection_area.add_child(shape)
		shape.owner = owner
	
	detection_area.collision_layer = 0
	detection_area.collision_mask = 1<<19
	detection_area.body_entered.connect(_on_object_entered)
	detection_area.body_exited.connect(_on_object_exited)


func _on_object_entered(body:Node):
	currObject = null
	print("something is colliding")
	currObject = body.find_child("*",true,false) as LiCapMesh3D
	print(currObject)
		
	#has_method("add_light"):
		#body.add_light(self)

func _on_object_exited(body):
	if body.has_method("remove_light"):
		body.remove_light(self)

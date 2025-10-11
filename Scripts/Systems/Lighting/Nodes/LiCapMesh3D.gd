@tool
extends MeshInstance3D
class_name LiCapMesh3D

var affecting_lights: Array[LiCapLight] = []
var collision_body: StaticBody3D
var shape: CollisionShape3D

@export var collision_set = false

func _ready():
	setup()
func _process(delta: float) -> void:
	setup()
	
func setup():
	if not collision_set:
		if not mesh == null:
			setup_collision()
		collision_set = true
		
func setup_collision():
	if get_parent() is StaticBody3D:
		collision_body = get_parent()
	collision_body = StaticBody3D.new()
	get_parent().add_child(collision_body)
	collision_body.owner = owner

	# Move this mesh under the body
	get_parent().remove_child(self)
	collision_body.add_child(self)
	owner = collision_body.owner

	# Auto-create collision from mesh
	shape = CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	collision_body.add_child(shape)
	shape.owner = owner
	return


func add_light(light: LiCapLight):
	if light not in affecting_lights:
		affecting_lights.append(light)
		# Update shader with light data
		get_surface_override_material(0).set_shader_parameter("light_data", light.get_data())

func remove_light(light: LiCapLight):
	affecting_lights.erase(light)

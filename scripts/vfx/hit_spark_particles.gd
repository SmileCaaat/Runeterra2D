extends CPUParticles3D

var burst_count := 0
var particle_profile: ParticleProfileDefinition


func _ready() -> void:
	var database := CombatData.database()
	particle_profile = database.get_particle_profile(&"hit_spark") if database != null else null
	emitting = false
	amount = particle_profile.amount if particle_profile != null else 22
	lifetime = particle_profile.lifetime if particle_profile != null else 0.28
	one_shot = true
	explosiveness = 1.0
	randomness = particle_profile.randomness if particle_profile != null else 0.35
	local_coords = false
	direction = Vector3(1.0, 0.25, 0.0)
	spread = particle_profile.spread if particle_profile != null else 150.0
	gravity = particle_profile.gravity if particle_profile != null else Vector3(0.0, -4.5, 0.0)
	initial_velocity_min = particle_profile.velocity_min if particle_profile != null else 2.4
	initial_velocity_max = particle_profile.velocity_max if particle_profile != null else 5.2
	angular_velocity_min = particle_profile.angular_velocity_min if particle_profile != null else -720.0
	angular_velocity_max = particle_profile.angular_velocity_max if particle_profile != null else 720.0
	scale_amount_min = particle_profile.scale_min if particle_profile != null else 0.45
	scale_amount_max = particle_profile.scale_max if particle_profile != null else 1.35
	color_ramp = _create_color_ramp()
	mesh = _create_spark_mesh()


func burst(world_contact: Vector3, impact_direction: Vector3) -> void:
	global_position = world_contact
	var planar_direction := impact_direction
	planar_direction.y = 0.25
	direction = planar_direction.normalized()
	restart()
	emitting = true
	burst_count += 1


func _create_color_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		particle_profile.gradient_start if particle_profile != null else Color(1.0, 1.0, 0.92, 1.0),
		particle_profile.gradient_mid if particle_profile != null else Color(1.0, 0.84, 0.28, 1.0),
		particle_profile.gradient_late if particle_profile != null else Color(1.0, 0.28, 0.04, 0.75),
		particle_profile.gradient_end if particle_profile != null else Color(0.35, 0.02, 0.0, 0.0),
	])
	return ramp


func _create_spark_mesh() -> QuadMesh:
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.albedo_color = Color.WHITE
	spark_material.emission_enabled = true
	spark_material.emission = particle_profile.emission_color if particle_profile != null else Color(1.0, 0.55, 0.08, 1.0)
	spark_material.emission_energy_multiplier = particle_profile.emission_energy if particle_profile != null else 2.5

	var spark_mesh := QuadMesh.new()
	spark_mesh.size = particle_profile.mesh_size if particle_profile != null else Vector2(0.16, 0.045)
	spark_mesh.material = spark_material
	return spark_mesh

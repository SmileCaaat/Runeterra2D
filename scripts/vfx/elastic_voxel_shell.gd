class_name ElasticVoxelShell
extends Node3D

## A thin cube shell that rides an authored projectile.  On bounce it
## squash-stretches so the hop reads as elastic instead of a rigid slide.

var voxel_count := 16
var voxel_size := 0.08
var voxel_radius := 0.36
var voxel_color := Color(0.47, 0.85, 1.0, 0.35)
var _multi: MultiMeshInstance3D
var _offsets: Array[Vector3] = []
var _pulse := 0.0
var _apex := 0.0
var _travel := Vector3.RIGHT
var _spin := 0.0


func configure(database: CombatDatabase) -> void:
	if database != null:
		voxel_count = clampi(int(database.get_rule(&"ryze.e.voxel_count", voxel_count)), 8, 32)
		voxel_size = float(database.get_rule(&"ryze.e.voxel_size", voxel_size))
		voxel_radius = float(database.get_rule(&"ryze.e.voxel_radius", voxel_radius))
		var raw := String(database.get_rule(&"ryze.e.voxel_color", "78d9ff59"))
		if not raw.begins_with("#"):
			raw = "#" + raw
		voxel_color = Color.from_string(raw, voxel_color)
	_offsets = _fibonacci_shell(voxel_count, voxel_radius)
	_build_mesh()
	pulse_elastic(0.8)


func set_travel(direction: Vector3) -> void:
	var planar := direction
	if planar.length_squared() > 0.0001:
		_travel = planar.normalized()


func set_apex_stretch(apex: float) -> void:
	_apex = clampf(apex, 0.0, 1.0)


func pulse_elastic(strength: float = 1.0) -> void:
	_pulse = maxf(_pulse, strength)


func _process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 5.2)
	_spin += delta * (2.4 + _pulse * 6.0 + _apex * 2.2)
	if _multi == null or _multi.multimesh == null:
		return
	var squash := 1.0 + sin(clampf(_pulse, 0.0, 1.0) * PI) * 0.42 + _apex * 0.28
	var along := _travel
	var side := along.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = along.cross(Vector3.FORWARD)
	side = side.normalized()
	var up := along.cross(side).normalized()
	var stretch := Basis(side, up, along).scaled(Vector3(2.0 - squash, 2.0 - squash, squash))
	var mesh := _multi.multimesh
	for index in _offsets.size():
		var orbit := _offsets[index].rotated(Vector3.UP, _spin * 0.35).rotated(Vector3.RIGHT, _spin * 0.18)
		var xform := Transform3D(stretch, stretch * orbit)
		mesh.set_instance_transform(index, xform)


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * voxel_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = voxel_color
	material.emission_enabled = true
	material.emission = Color(voxel_color.r, voxel_color.g, voxel_color.b, 1.0)
	material.emission_energy_multiplier = 0.55
	material.no_depth_test = true
	material.disable_receive_shadows = true
	box.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.instance_count = _offsets.size()
	instances.mesh = box
	_multi = MultiMeshInstance3D.new()
	_multi.name = "VoxelShell"
	_multi.multimesh = instances
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)


func _fibonacci_shell(count: int, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	var denom := maxf(float(count - 1), 1.0)
	for index in count:
		var y := 1.0 - (float(index) / denom) * 2.0
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := golden * float(index)
		points.append(Vector3(cos(theta) * ring, y, sin(theta) * ring) * radius)
	return points

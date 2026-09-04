extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	var passed := packed != null
	if packed == null:
		push_error("Training stage scene failed to load")
		quit(1)
		return

	var stage := packed.instantiate() as Node3D
	var authored_camera := stage.get_node("CameraRig/DNFCamera") as Camera3D
	var authored_camera_transform := authored_camera.transform
	var authored_camera_size := authored_camera.size
	var authored_layer_positions: Dictionary = {}
	for layer_name: StringName in [&"BackgroundFar", &"BackgroundMid", &"ForegroundNearLeft", &"ForegroundNearRight"]:
		authored_layer_positions[layer_name] = (stage.get_node("World/Backdrop").get_node(NodePath(layer_name)) as MeshInstance3D).position
	root.add_child(stage)
	await process_frame
	passed = passed and stage.name == "TrainingGround"
	passed = passed and StringName(stage.get_meta(&"stage_profile_id", &"")) == &"small"
	passed = passed and StringName(stage.get_meta(&"stage_mode", &"")) == &"training"
	passed = passed and String(stage.get_meta(&"stage_display_name", "")) == "训练场"
	passed = passed and int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920
	passed = passed and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080
	passed = passed and String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep"
	var camera := stage.get_node("CameraRig/DNFCamera") as Camera3D
	passed = passed and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	passed = passed and camera.keep_aspect == Camera3D.KEEP_HEIGHT
	passed = passed and camera.current
	passed = passed and camera.transform.is_equal_approx(authored_camera_transform)
	passed = passed and is_equal_approx(camera.size, authored_camera_size)

	var ground := stage.get_node("World/Ground/GroundMesh") as MeshInstance3D
	var ground_mesh := ground.mesh as QuadMesh
	var ground_material := ground.material_override as ShaderMaterial
	var ground_texture := ground_material.get_shader_parameter(&"albedo_texture") as Texture2D
	var ground_uv_scale := ground_material.get_shader_parameter(&"uv_scale") as Vector2
	passed = passed and ground_mesh.size.is_equal_approx(Vector2(32.0, 8.0))
	passed = passed and ground_material.shader.resource_path.ends_with("stage_readability.gdshader")
	passed = passed and ground_texture.resource_path.ends_with("training_ground/ground.png")
	var ground_source_aspect := (
		float(ground_texture.get_width())
		/ float(ground_texture.get_height())
	)
	var ground_effective_aspect := ground_source_aspect / absf(ground_uv_scale.y)
	passed = passed and is_equal_approx(ground_effective_aspect, 4.0)

	var background := stage.get_node("World/Backdrop/BackgroundFar") as MeshInstance3D
	var background_mesh := background.mesh as QuadMesh
	var background_material := background_mesh.material as ShaderMaterial
	var background_texture := background_material.get_shader_parameter(&"albedo_texture") as Texture2D
	passed = passed and background_mesh.size.is_equal_approx(Vector2(32.0, 12.0))
	passed = passed and background_material.shader.resource_path.ends_with("stage_readability.gdshader")
	passed = passed and background_texture.resource_path.ends_with("training_ground/bg_far.png")
	passed = passed and is_equal_approx(
		float(background_texture.get_width()) / float(background_texture.get_height()),
		8.0 / 3.0
	)
	passed = passed and background.position.is_equal_approx(authored_layer_positions[&"BackgroundFar"])
	for layer_name: StringName in [&"BackgroundMid", &"ForegroundNearLeft", &"ForegroundNearRight"]:
		var layer := stage.get_node("World/Backdrop").get_node(NodePath(layer_name)) as MeshInstance3D
		var layer_mesh := layer.mesh as QuadMesh
		var layer_material := layer_mesh.material as ShaderMaterial
		passed = passed and layer_mesh.size.is_equal_approx(Vector2(32.0, 12.0))
		passed = passed and layer_material.shader.resource_path.ends_with("stage_readability_alpha.gdshader")
		passed = passed and layer_material.render_priority == -100
		passed = passed and layer.position.is_equal_approx(authored_layer_positions[layer_name])
	passed = passed and float(background_material.get_shader_parameter(&"saturation")) < float(ground_material.get_shader_parameter(&"saturation"))
	var player_readability := stage.get_node("Characters/Player/UnitReadability")
	var player_frames := stage.get_node("Characters/Player/CharacterFrames") as AnimatedSprite3D
	passed = passed and not player_frames.no_depth_test
	passed = passed and not player_readability.has_node("MaskOutline")
	passed = passed and not player_readability.has_node("OutlineGlow")

	var environment := (stage.get_node("Environment") as WorldEnvironment).environment
	var sun := stage.get_node("Sun") as DirectionalLight3D
	print("TRAINING_LIGHT stage_shader=%s far_saturation=%s ground_saturation=%s ambient=%s sun_visible=%s sun_energy=%s sun_shadow=%s" % [
		ground_material.shader.resource_path,
		background_material.get_shader_parameter(&"saturation"),
		ground_material.get_shader_parameter(&"saturation"),
		environment.ambient_light_energy,
		sun.visible,
		sun.light_energy,
		sun.shadow_enabled,
	])
	passed = passed and is_zero_approx(environment.ambient_light_energy)
	passed = passed and not sun.visible
	passed = passed and is_zero_approx(sun.light_energy)
	passed = passed and not sun.shadow_enabled

	passed = passed and is_equal_approx(stage.get_node("World/Architecture/BackWall").position.z, -4.0)
	passed = passed and is_equal_approx(stage.get_node("World/StageBounds/FrontLimit").position.z, 4.0)
	passed = passed and is_equal_approx(stage.get_node("World/Architecture/LeftWall").position.x, -16.0)
	passed = passed and is_equal_approx(stage.get_node("World/StageBounds/RightLimit").position.x, 16.0)
	passed = passed and not (stage.get_node("World/Architecture/BackWall/BackWallMesh") as MeshInstance3D).visible
	passed = passed and (stage.get_node("World/Architecture/RaisedPlatform/PlatformCollision") as CollisionShape3D).disabled
	passed = passed and (stage.get_node("World/Props/Crate01/CrateCollision") as CollisionShape3D).disabled
	passed = passed and (stage.get_node("World/Props/Pillar01/PillarCollision") as CollisionShape3D).disabled

	print("TRAINING_STAGE profile=small authored_camera=true authored_layers=true readability=stage-grade/no-team-outline ground_uv=4:1 placeholders=disabled")
	stage.queue_free()
	if not passed:
		push_error("Training stage visual verification failed")
	quit(0 if passed else 2)

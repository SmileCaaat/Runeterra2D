extends SceneTree

const MODEL_PATH := "res://assets/characters/rogue_admiral_garen_3d/rogue_admiral_garen.glb"
const PREVIEW_SCENE_PATH := "res://scenes/tests/garen_3d_model_test.tscn"
const EXPECTED_ANIMATION_COUNT := 33
var required_animations := PackedStringArray([
	"Idle1_Base",
	"Run",
	"Attack1",
	"Attack2",
	"Spell1",
	"Spell3_0",
	"Spell4_Base",
	"Death",
])

func _initialize() -> void:
	var passed := true
	var model_scene := load(MODEL_PATH) as PackedScene
	if model_scene == null:
		push_error("Could not load Garen 3D model: %s" % MODEL_PATH)
		quit(1)
		return
	var model := model_scene.instantiate()
	var player := _find_animation_player(model)
	if player == null:
		push_error("Garen 3D model has no AnimationPlayer")
		passed = false
	else:
		var animation_names := player.get_animation_list()
		if animation_names.size() != EXPECTED_ANIMATION_COUNT:
			push_error("Expected %d model animations, found %d" % [EXPECTED_ANIMATION_COUNT, animation_names.size()])
			passed = false
		for animation_name in required_animations:
			if not player.has_animation(animation_name):
				push_error("Missing required 3D animation: %s" % animation_name)
				passed = false
		if passed:
			player.play(&"Idle1_Base")

	var preview_scene := load(PREVIEW_SCENE_PATH) as PackedScene
	if preview_scene == null:
		push_error("Could not load Garen 3D preview scene: %s" % PREVIEW_SCENE_PATH)
		passed = false
	var preview_instance: Node
	var preview_player: AnimationPlayer
	if preview_scene != null:
		preview_instance = preview_scene.instantiate()
		preview_player = _find_animation_player(preview_instance)
		if preview_player == null:
			push_error("Garen 3D preview scene does not instance the model AnimationPlayer")
			passed = false
	print("GAREN_3D_MODEL animations=%d required=%d preview_scene=%s" % [
		player.get_animation_list().size() if player != null else 0,
		required_animations.size(),
		preview_player != null,
	])
	model.queue_free()
	if preview_instance != null:
		preview_instance.queue_free()
	quit(0 if passed else 2)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

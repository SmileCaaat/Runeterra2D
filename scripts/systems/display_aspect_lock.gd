extends Node

## Keeps the standalone game window at the project design aspect (16:9).
## Embedded editor chrome outside the game Viewport is ignored on purpose.

const DESIGN_ASPECT := 16.0 / 9.0
const ASPECT_EPSILON_PX := 2

var _locking := false


func _ready() -> void:
	var win := get_window()
	if win == null:
		return
	var window_id := win.get_window_id()
	if DisplayServer.window_get_mode(window_id) == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
	win.size_changed.connect(_on_window_size_changed)
	call_deferred(&"_enforce_aspect")


func _on_window_size_changed() -> void:
	_enforce_aspect()


func _enforce_aspect() -> void:
	if _locking:
		return
	var win := get_window()
	if win == null:
		return
	var size := win.size
	if size.x <= 0 or size.y <= 0:
		return
	var target_height := int(round(float(size.x) / DESIGN_ASPECT))
	if abs(size.y - target_height) <= ASPECT_EPSILON_PX:
		return
	if target_height < 1:
		return
	_locking = true
	win.size = Vector2i(size.x, target_height)
	_locking = false

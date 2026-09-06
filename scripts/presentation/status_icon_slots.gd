class_name StatusIconSlots
extends Node3D

const TINT_SHADER := preload("res://assets/shaders/status_icon_tint.gdshader")

@export var icon_pixel_size := 0.00028
@export var row_height := 2.34
@export var icon_spacing := 0.18

var buff_row: Node3D
var debuff_row: Node3D
var debuff_icons: Dictionary[StringName, Sprite3D] = {}


func _ready() -> void:
	buff_row = _make_row("BuffSlots", row_height)
	debuff_row = _make_row("DebuffSlots", row_height + 0.22)


func show_debuff(icon_id: StringName, texture: Texture2D, color: Color) -> void:
	if texture == null:
		return
	var icon := debuff_icons.get(icon_id) as Sprite3D
	if icon == null:
		icon = Sprite3D.new()
		icon.name = "Debuff_%s" % icon_id
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.no_depth_test = true
		icon.render_priority = 45
		icon.pixel_size = icon_pixel_size
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = TINT_SHADER
		icon.material_override = material
		debuff_row.add_child(icon)
		debuff_icons[icon_id] = icon
	icon.texture = texture
	(icon.material_override as ShaderMaterial).set_shader_parameter(&"tint_color", color)
	icon.visible = true
	_layout(debuff_icons, debuff_row)


func hide_debuff(icon_id: StringName) -> void:
	var icon := debuff_icons.get(icon_id) as Sprite3D
	if icon != null:
		icon.visible = false
	_layout(debuff_icons, debuff_row)


func _make_row(row_name: String, height: float) -> Node3D:
	var row := Node3D.new()
	row.name = row_name
	row.position = Vector3(0.0, height, 0.02)
	add_child(row)
	return row


func _layout(entries: Dictionary[StringName, Sprite3D], _row: Node3D) -> void:
	var visible_icons: Array[Sprite3D] = []
	for icon: Sprite3D in entries.values():
		if icon.visible:
			visible_icons.append(icon)
	for index: int in visible_icons.size():
		visible_icons[index].position.x = (float(index) - float(visible_icons.size() - 1) * 0.5) * icon_spacing

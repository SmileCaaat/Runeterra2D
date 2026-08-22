@tool
extends EditorPlugin

const MENU_LABEL := "Build Combat Database"
const BuilderScript = preload("res://scripts/data/combat_data_builder.gd")


func _enter_tree() -> void:
	add_tool_menu_item(MENU_LABEL, _build_database)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_LABEL)


func _build_database() -> void:
	var result: Dictionary = BuilderScript.new().build()
	for warning: String in result.warnings:
		push_warning("Combat data: %s" % warning)
	for error: String in result.errors:
		push_error("Combat data: %s" % error)
	if result.success:
		print("Combat data generated: %s" % result.output_path)
		EditorInterface.get_resource_filesystem().scan()

class_name BuffDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var duration := 0.0
@export var max_stacks := 1
@export_enum("replace", "stack", "independent") var stacking_policy := "replace"
@export_enum("refresh", "extend", "keep_longest", "none") var refresh_policy := "refresh"
@export_enum("none", "positive", "negative", "crowd_control", "slow") var dispel_category := "none"
@export var visible := true
@export var nonlethal := false
@export var vfx_profile_id: StringName
@export var tags: Array[StringName] = []

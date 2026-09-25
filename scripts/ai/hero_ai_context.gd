class_name HeroAIContext
extends RefCounted

var actor: CharacterBody3D
var target: CharacterBody3D
var database: CombatDatabase
var archetype: AIArchetypeDefinition
var archetype_evaluator: AIArchetypeEvaluator
var profile: AIProfileDefinition
var delta := 0.0
var now_seconds := 0.0
var self_health_ratio := 1.0
var target_health_ratio := 1.0
var self_position := Vector3.ZERO
var target_position := Vector3.ZERO
var target_velocity := Vector3.ZERO
var target_distance := INF
var target_closing_speed := 0.0
var target_rooted := false
var target_is_hero := false
var target_is_training_dummy := false
var nearby_enemy_count := 0
var nearest_enemy_distance := INF
var enemies: Array[CharacterBody3D] = []
var preferred_distance := 0.0
var engage_distance := 0.0
var disengage_distance := 0.0
var attack_range := 0.0
var cast_range := 0.0
var output_range := 0.0
var control_range := 0.0
var control_available := false
var q_ready := false
var w_ready := false
var e_ready := false
var r_ready := false
var t_ready := false
var silenced := false
var rooted := false
var action_locked := false
var arena_min := Vector2.ZERO
var arena_max := Vector2.ZERO
var current_intent: StringName = &""
var current_intent_age := 0.0
var blocked_actions: Dictionary = {}
var extras: Dictionary = {}
var outcome_evaluations: Dictionary = {}


func block_action(action_id: StringName, reason: String = "") -> void:
	blocked_actions[action_id] = reason


func is_action_blocked(action_id: StringName) -> bool:
	return blocked_actions.has(action_id)

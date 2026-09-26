class_name HeroAIDecision
extends RefCounted

var action_id: StringName = &"hold"
## Slot consumed by this candidate; the generic brain never decodes hero action IDs.
var skill_slot: StringName = &""
var score := 0.0
var target: CharacterBody3D
var destination := Vector3.ZERO
var has_destination := false
var reason := ""
var commit_seconds := 0.20
var generation := 0
var metadata: Dictionary = {}


static func make(id: StringName, value: float, why: String = "") -> HeroAIDecision:
	var decision := HeroAIDecision.new()
	decision.action_id = id
	if String(id).begins_with("skill_"):
		decision.skill_slot = StringName(String(id).trim_prefix("skill_"))
	decision.score = value
	decision.reason = why
	return decision

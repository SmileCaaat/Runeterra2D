class_name HeroActionRequest
extends RefCounted

## Runtime intent shared by manual input and AI. It contains no utility score or
## decision lifecycle; the hero validates it before starting an action.
enum Source { AI, PLAYER }

var source := Source.AI
var action_id: StringName = &"hold"
var skill_slot: StringName = &""
var target: CharacterBody3D
var direction := Vector2.ZERO
var ground_position := Vector3.ZERO
var has_ground_position := false

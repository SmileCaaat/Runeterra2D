class_name AIArchetypeDefinition
extends Resource

## Shared decision parameters for one combat subclass. Per-hero AI profiles only
## bind/override arena and presentation timing; live state never lives here.
@export var id: StringName
@export var decision_mode := ""
@export var preferred_distance := 1.5
@export var engage_distance := 2.4
@export var disengage_distance := 0.0
@export var pressure_health_ratio := 0.75
@export var defend_health_ratio := 0.55
@export var execute_health_ratio := 0.33
@export var aoe_min_targets := 2
@export var awakening_health_ratio := 0.45
@export var decision_interval := 0.15

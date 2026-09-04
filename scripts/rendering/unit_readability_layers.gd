extends Node3D

## Reserved hook for future non-outline readability features. Faction outlines
## are intentionally disabled for friendly, enemy, and neutral units.
@export_node_path("AnimatedSprite3D") var source_sprite_path: NodePath
@export_node_path("Node") var team_source_path := NodePath("..")

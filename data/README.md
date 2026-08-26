# Combat Data v0.2

This directory is the source of truth for the prototype combat system. It combines MOBA-style stat and buff semantics with side-scrolling action timing, hit reaction, poise, knockback, depth and presentation bindings.

Project design policy, formula provenance and per-hero fidelity records live in [`docs/combat/`](../docs/combat/README.md). Read those rules before adding a referenced hero or changing formula semantics.

## Workflow

1. Edit UTF-8 CSV files in `data/source/`.
2. In Godot choose **Project > Tools > Build Combat Database**, or run:

   ```powershell
   Godot_v4.7-stable_win64.exe --headless --path D:\godot_projects\gemheart2d --script res://scripts/tools/build_combat_database.gd
   ```

3. Fix every reported table, row, reference or resource error.
4. The builder writes `data/generated/combat_database.tres`.
5. Run `tests/verify_combat_database.gd`, `tests/verify_garen_skill_rules.gd` and `tests/verify_combat_workflow.gd`.

Never edit `data/generated/combat_database.tres` by hand. Runtime timers, cooldowns, current health, buff stacks and targets must not be written into Resources because Resources are shared definitions.

## Override order

`combat_rules` global defaults -> game mode -> unit -> skill/effect -> active buff -> resolved combat value.

`unit_mode_modifiers.csv` now provides typed per-unit mode deltas. The runtime aggregation pass is deliberately not implemented yet: tables can be authored and validated before a mode resolver is introduced.

## Source tables

- `combat_rules.csv`: global constants, progression coefficients and policy enums. Formula code lives in typed scripts; arbitrary code is never evaluated from a cell.
- `stats.csv`: canonical stat IDs, units, valid ranges and default modifier operation.
- `units.csv`: hero, monster, summon and training-dummy identity, reusable `instance_template_id`（当前为 `hero` 或 `monster`）, role, resource type, skill and AI references.
- `unit_stats.csv`: level-1 values, growth coefficients, growth formula, auditable source values and world-unit conversion.
- `skills.csv`: targeting, cast model, cooldown, range, radius, duration, movement/facing policy and animation/presentation references.
- `skill_effects.csv`: ordered damage, buff, control, cleanse, delayed-damage and shield operations.
- `skill_ranks.csv`: typed per-rank cast shell values. Do not encode rank arrays in scalar cells.
- `skill_effect_ranks.csv`: typed per-rank damage, coefficient, interval and control values for an effect.
- `unit_mode_modifiers.csv`: optional game-mode stat deltas with an explicit operation; mode application remains a later runtime resolver.
- `buffs.csv`: lifetime, stacking, refresh, dispel, visibility, nonlethal and VFX lifecycle semantics.
- `buff_modifiers.csv`: stat modifiers with explicit operation, phase and priority.
- `hit_profiles.csv`: shape, size, depth tolerance, active window, hitstop, hitstun, poise damage, knockback and impact presentation.
- `animation_events.csv`: frame/normalized/seconds events for hits, audio, VFX, movement, cancel and invulnerability windows.
- `asset_manifest.csv`: SpriteFrames, animations, audio, scale, origin, shader, layer, depth and lifecycle binding.
- `particle_profiles.csv`: hit-particle simulation and visual parameters.
- `hero_classes.csv`: broad hero combat taxonomies; does not contain live balance values.
- `hero_subclasses.csv`: branch identity and its reusable AI archetype binding.
- `ai_archetypes.csv`: reusable distance, pressure, defense, execute and AOE decision thresholds.
- `ai_profiles.csv`: per-unit AI binding/overrides, arena bounds, optional legacy sequence and deterministic test seed.

## ID and cell conventions

- IDs use stable lowercase `snake_case`. Display names are never references.
- Multiple ID references use `|`, for example `skill_a|skill_b`.
- Percentages are stored as ratios: `0.35` means 35%.
- Durations use seconds; planar distances and speed use Godot world meters.
- `add_percent` means additive percentage points in one modifier layer; `multiply` means a multiplicative factor.
- Damage types are `physical`, `magic`, `true` and `none`.
- Target types distinguish `unit`, `direction`, `ground_area`, `self_area` and `self`.

## Champion growth and source fidelity

The normalized unit-stat table keeps both runtime values and source values. For example, Garen's source move speed `340` is stored beside runtime speed `3.4` with `conversion_scale=0.01`; this avoids mixing LoL units with Godot world meters while keeping every conversion reviewable.

Primary growing stats use `base + growth * n * (0.7025 + 0.0175 * n)`, where `n = level - 1`. Attack speed applies the same growth factor through `attack_speed_ratio`. Monster endpoint interpolation can use `linear = base + growth * n`. Levels are clamped by `progression.level_cap` (currently 30). Each stat row explicitly declares `none`, `linear`, `primary` or `attack_speed` growth.

Reference semantics and current Garen source values were checked against [Champion statistics](https://wiki.leagueoflegends.com/en-us/Champion_statistic) and [Template:Data Garen](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen).

ChampionData-compatible reference fields such as `missile_speed`, `attack_cast_time`, `attack_total_time`, `critical_damage_base`, `critical_damage_modifier`, `attack_range_growth` and `move_speed_growth` are stored separately from the current prototype's resolved action values. This keeps a future ranged/basic-attack implementation traceable without claiming that every source field is already simulated.

## Design boundary

Stat names such as health, armor, magic resistance, critical chance, ability haste and tenacity follow familiar MOBA semantics. Action fields such as active hit windows, hitstop, hitstun, poise, knockback, launch velocity, cancel windows and depth tolerance are first-class data and must not be inferred from MOBA rules.

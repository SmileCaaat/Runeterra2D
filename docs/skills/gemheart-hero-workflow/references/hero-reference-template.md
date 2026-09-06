# Hero reference record template

Use this structure for `docs/combat/heroes/<hero_id>.md`. Remove irrelevant sections rather than leaving placeholders.

## Source snapshot

- Target game and mode:
- Access date:
- Patch or revision:
- Stats URL:
- Hero hub URL:
- Ability data URLs:
- Conflicts or unknowns:

## Identity brief

Describe the core loop and list the mechanics that must remain recognizable.

## Base and growth stats

Record source field names, source values, normalized runtime values, formulas, and conversion scales. Distinguish reference values from project-only action stats.

## Ability mapping

| Source ability | Project ability | Classification | Preserved | Removed or changed | Reason |
| --- | --- | --- | --- | --- | --- |

Cover the passive and every canonical ability. Mark anything absent as `missing`; do not omit it from the table.

## Formula registry

| Formula ID | Expression | Source type | URL or local rule | Runtime location | Test |
| --- | --- | --- | --- | --- | --- |

Use `reference`, `derived`, or `project`. Record percentages as ratios and include units.

## Action adaptation

Record target shape, depth, startup/active/recovery timing, cancel windows, movement/facing policy, hitstop, hitstun, poise, knockback, launch, repeated-hit rules, VFX/audio lifecycle, and left/right behavior.

## Original-content gate

List any `missing` identity mechanics, the reason for deferral, and why each proposed original ability is still justified.

## Validation

List database, formula, mechanics, scene, direction, depth, and presentation-lifecycle checks with observed results.

---
name: gemheart-hero-workflow
description: Research, adapt, implement, document, and verify playable heroes for the Gemheart Godot project when LoL or another live game is used as a reference. Enforces canonical-kit-first design, traceable formulas, combat-table contracts, and DNF-style frame and hit rules. Do not use for isolated VFX or audio-only edits.
---

# Gemheart Hero Workflow

Use this workflow for new referenced heroes, substantial skill redesigns, hero stat imports, or audits of whether an implementation still matches its source identity.

## Locate project rules

Find the workspace root containing `project.godot` and `data/source/combat_rules.csv`. Before changing hero mechanics or data, read:

- `docs/combat/hero-design-rules.md`
- `docs/combat/formula-reference.md`
- `docs/combat/data-contracts.md`
- `docs/combat/heroes/<hero_id>.md` when it exists
- `data/README.md` for build and test commands

If these project documents are absent, use [the hero reference template](references/hero-reference-template.md) to create the missing audit record, but do not invent project-specific table names or claim unsupported runtime features.

## Preserve the source hero before extending it

Map the passive and every canonical skill before proposing original abilities. Classify each mapping as `faithful`, `simplified`, `adapted`, `original`, `original_legacy`, or `missing`. Original additions are permitted only after identity-critical missing items have been implemented or explicitly deferred with a reason.

Preserve the hero's gameplay identity rather than blindly copying numbers. Translate the kit into the project's X/Z movement, sequence-frame animation, hitstop, hitstun, poise, knockback, cancel-window, facing, depth, VFX, and audio lifecycle rules.

## Build a current source snapshot

Browse the live source at the time of work. Record target game and mode, access date, URLs, patch or revision when known, base/growth stats, skill mechanics, damage types, targeting, durations, and formula structure. Never mix PC LoL, Wild Rift, TFT, Arena, or historical versions without explicitly selecting that mode.

Treat remembered and cached values as unverified. Prefer current official data or patch notes, then current Wiki data templates and mechanic pages. Paraphrase mechanics; do not copy long source text or source assets.

## Register every formula

Label each formula:

- `reference`: external structure or value; include URL and access date.
- `derived`: explicit conversion from source units to project units.
- `project`: Gemheart-specific rules; cite a local rule ID, CSV row, or code path instead of inventing an external source.

Keep percentages as ratios and preserve source values and conversion scales. Put runtime numbers in source CSVs, global constants in `combat_rules`, and formula logic in typed code. Do not leave authoritative values only in documentation or Inspector fallbacks.

Be explicit about partially modeled systems. A stat ID or Resource field does not prove its runtime calculation is implemented.

## Implement through the data model

Separate hero identity, unit stats, skill casting, effects, buffs, hit profiles, animation events, assets, particles, and AI into their existing tables. Respect table references and lifecycle constraints. Do not encode executable expressions or rank arrays into scalar CSV cells.

If the requested reference requires unsupported semantics such as skill-rank arrays, penetration ordering, shield layers, or a generic effect trigger, either extend the typed schema with tests or document a deliberate prototype simplification. Never silently hardcode around the schema.

## Verify

Run the combat database builder, database verification, hero-specific rule tests, and full combat workflow. Add assertions for formula boundary levels, conversions, status transitions, movement while casting, left/right facing, depth, repeated hits, nonlethal rules, and presentation lifecycle as applicable.

Finish with a short fidelity report listing faithful, simplified, adapted, original, and missing items; source URLs; schema changes; and test results.

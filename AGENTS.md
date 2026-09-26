# Runeterra2D development rules

Read this file before changing gameplay code, scenes, or tests.

- Build permanent hero hierarchies, HUD layout, cameras, collision, skill anchors, and persistent audio/VFX anchors in scenes. Spawn short-lived combat entities from a `PackedScene`, resource, or pool.
- Treat required scenes, templates, and gameplay data as required dependencies. Report missing dependencies with `push_error()` and stop the affected behavior; do not silently create substitutes.
- Use `CombatDatabase` as the single source of gameplay numbers. Inspector exports may tune presentation and editor previews, but must not supply missing damage, cooldown, range, duration, coefficients, or resource costs at runtime.
- Treat Player and AI as sources of action intent. Both must pass through the hero's shared runtime action gate before execution. Player code must not construct `HeroAIDecision`.
- Keep generic AI free of hero names and hero-specific action IDs. Put hero-specific mechanics and action selection in the actor, skill controller, or hero AI kit.
- Keep combat rules out of HUD scripts. HUD code reads runtime state and updates presentation only.
- Commit structural refactors separately from behavior changes. Run targeted tests and the full combat regression after each structural phase; do not remove tests to make a refactor pass.
- Make a new hero fully playable by manual control before connecting its AI. Follow data, scene/model/animator, skill controller, manual runtime, manual tests, AI kit, AI regression, then team integration.
- Document public APIs, action request contracts, targeting semantics, special rules, non-obvious invariants, and important asynchronous behavior with `##` comments. Avoid comments that merely repeat a function name.

# Version control

This project uses Git with the `main` branch and Git LFS for large binary source assets.

## Tracked source of truth

- Godot project settings, scenes, scripts and addon source.
- Character, VFX and project audio source assets.
- Combat CSVs in `data/source/`, typed data definitions and tests.
- Design, formula, table-contract and hero-reference documentation.

Godot `.import` sidecar files and `.uid` files are project metadata and should remain tracked. The `.godot/` directory is machine-generated cache and must never be committed.

## Generated and local-only content

- `data/generated/combat_database.tres` is rebuilt from CSV and is intentionally ignored.
- `addons/Sound FX Starter Pack Vol. 1/` remains available locally but is ignored because it is a large third-party library with no current project references.
- Export output, IDE state, logs and temporary files are ignored.

After a clean clone, rebuild the combat database before running the prototype:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path D:\godot_projects\gemheart2d --script res://scripts/tools/build_combat_database.gd
```

## Commit discipline

- Keep code, its related CSV changes, documentation and tests in the same commit when they implement one behavior.
- Do not commit `.godot/`, generated databases, exports or copied external asset libraries.
- Use Git LFS for binary art and audio; verify with `git lfs ls-files` before pushing a large asset change.
- Prefer small commits that describe an outcome, for example `feat(combat): add Garen stat growth data`.
- Run the relevant headless tests before committing combat-system changes.

No remote repository is configured by default. Add one only after choosing the hosting location and repository visibility.

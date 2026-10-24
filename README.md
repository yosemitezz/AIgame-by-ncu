# Bellkeep: Shattered Refrain

Original Godot 4.7 2D pixel side-scroller. New implementation; no old project code, Blender renders, commercial assets, or private listening track.

## Run
Open `project.godot` with Godot 4.7, or run `./run.ps1`. The launcher places caches/logs under ignored `.local/` beside the project. `./run.ps1 -Editor` opens the editor. Godot executable can be supplied with `-Godot`.

Current bootstrap milestone displays the project title. Gameplay is being integrated on `feat/pixel-bellkeep-20261024`.

## Parallel Cursor work
Read [COLLABORATION.md](COLLABORATION.md). Use an independent work directory and suggested branch `cursor/art-ui`. Cursor owns final pixel assets, VFX and HUD appearance; gameplay code emits stable presentation signals. Do not overwrite another editor's uncommitted files. Cursor has not been directly connected or messaged.

See [art and UI interface](docs/art-ui-contract.md). Existing MIT LICENSE is preserved. Original code and program-authored placeholder art use the repository license. No commercial soundtrack is included; the planned original synth placeholder and its beat timeline are configurable.

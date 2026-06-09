# Starfield Director (working title)

> Drop-in repo context for AI agents (Claude Code, Codex, Cursor, etc.) and human collaborators joining the project mid-stream. Read this first.

---

## Project Summary

L4D-style **AI Director** for Bethesda's Starfield. A dynamic encounter system that observes player state (tension, stress, time-since-combat, location, loadout) and orchestrates spawns, behavior overrides, and pacing to produce the "uncertainty, fear, and excitement" loop Valve nailed in L4D/L4D2.

This is **not** a simple spawner mod. It is a brain that *uses* the existing game systems as a toolbox.

**Inspirations:**
- Mike Booth's L4D AI Director (the canonical reference — find his GDC talks)
- Valve's NextBot locomotion architecture (the layer-below-Director equivalent)
- SKK's Combat Stalkers (FO4) and Stalkers and Followers (SF) — the closest existing prior art on the Bethesda side

---

## Status

- **Phase:** scoping / architecture
- **Target game version:** latest Steam Starfield supported by current SFSE (verify each session)
- **Platform target:** PC, Steam only (Gamepass/MS Store/EGS not supported by SFSE)
- **Authors:** [fill in]
- **License:** [TBD — note that linking against CommonLibSF means GPL-3.0-or-later WITH Modding Exception. Choose accordingly.]
- **Repo state:** pre-scaffold — docs + approved design spec (`docs/superpowers/specs/2026-06-09-sfse-hello-world-design.md`), git initialized 2026-06-09. No code yet; the "Proposed Repo Layout" below is still aspirational. Machine-specific paths (game, MO2, deploy target) live in `.claude.local.md` (gitignored).
- **AGENTS.md:** byte-identical copy of this file for non-Claude tooling. Edit `CLAUDE.md` first, then sync: `Copy-Item CLAUDE.md AGENTS.md`. Never edit AGENTS.md directly.

---

## Architecture (Inverted Two-Layer)

Most Bethesda mods are *Papyrus-first with optional C++ helpers*. This project inverts that:

### Layer 1 — The Brain (C++ plugin)

The director itself. Owns:

- Tension/stress state model
- Phase machine (Build → Peak → Relax → Respite)
- Decisions about *what* should happen, *when*, and *where*
- Real-time event hooks (combat, alarm, location change, menu state)
- Spawn budget arithmetic
- Spawn point selection (LOS checks, distance bands, faction filtering)
- Behavior override dispatch (assigning packages to spawned actors)

Built on:
- **SFSE** — runtime loader, plugin interface
- **CommonLibSF** (use the `libxse/CommonLibSF` fork — the `Starfield-Reverse-Engineering/CommonLibSF` fork is archived)
- **Address Library for SFSE Plugins** — for version-resilient memory offsets
- C++23, MSVC or Clang-CL
- XMake (template: `libxse/commonlibsf-template`) or CMake (template: `epinter/sfse-clib-template`)

### Layer 2 — The Toolbox (Creation Kit content)

The director never invents behavior from scratch. It picks from a library of authored CK assets:

- **Packages** — investigate, patrol, ambush, flank-and-hold, retreat. Authored once in CK, assigned at runtime by the brain.
- **Leveled Lists / Encounter Templates** — what kinds of NPCs spawn for what contexts (Spacer ambush, Ecliptic mercenary squad, alien predator pack, etc.)
- **Idle Markers** — pre-placed at known POIs as candidate flanking positions. Director picks from these instead of computing geometry at runtime.
- **Alarm Quests** — vanilla SQ_Alarm and equivalents become triggers the director listens for.
- **Faction Data** — relationship matrices, reaction values, alert thresholds. Director can temporarily override via faction reaction edits.

### Bridge

- Custom Papyrus natives exposed by the C++ plugin (for CK-side scripts to push events up, or for the director to invoke editor-authored behaviors down)
- Quest stage hooks for two-way signaling
- Form ID registry: C++ side holds known form IDs for packages, factions, leveled lists, quest aliases — populated at startup from a config

---

## Tech Stack

| Component | Choice | Notes |
|---|---|---|
| Runtime loader | SFSE | Steam only |
| C++ framework | CommonLibSF (libxse fork) | Active as of mid-2026. ⚠️ "A minefield disarmed, but not actually disarmed" (xSE RE Discord, 2026-04): many class definitions broke on game 1.14→1.15 and were never fixed. Treat every engine-struct definition as unverified until tested; SFSE-side interfaces (plugin load, messaging, logging) are safe. Verified-broken/working findings go in `/docs/re-notes/`. |
| Build | XMake (decided 2026-06-09) | Template: `libxse/commonlibsf-template`. CMake was the considered alternative. |
| Compiler | MSVC or Clang-CL | C++23 |
| Memory safety across patches | Address Library for SFSE Plugins | Required |
| Scripting | Papyrus (Starfield CK flavor) | New features vs FO4 — see Starfield Wiki Papyrus reference |
| Asset authoring | Starfield Creation Kit | Free on Steam |
| Decompilation / RE | Caprica (decompile only), CK PapyrusCompiler.exe (compile) | Caprica lacks GUARD support; use CK compiler for production |
| Source control | git | submodules for CommonLibSF, DKUtil |

---

## Proposed Repo Layout

```
/director-root
├── CLAUDE.md                  (agent + collaborator context — canonical)
├── AGENTS.md                  (byte-identical mirror of CLAUDE.md for non-Claude tools)
├── README.md                  (user-facing)
├── LICENSE
├── xmake.lua                  (or CMakeLists.txt)
├── vcpkg.json                 (if CMake)
├── /src                       (C++ plugin source)
│   ├── main.cpp               (SFSE entry point)
│   ├── Director/              (brain core)
│   │   ├── TensionModel.{h,cpp}
│   │   ├── PhaseMachine.{h,cpp}
│   │   ├── SpawnBudget.{h,cpp}
│   │   ├── SpawnPointPicker.{h,cpp}
│   │   ├── AlarmOverride.{h,cpp}
│   │   └── EncounterDispatcher.{h,cpp}
│   ├── Hooks/                 (engine event hooks)
│   │   ├── CombatHooks.{h,cpp}
│   │   ├── AlarmHooks.{h,cpp}
│   │   └── MenuStateHooks.{h,cpp}
│   ├── PapyrusBridge/         (custom natives + form registry)
│   └── Util/                  (logging, config, math)
├── /papyrus                   (Papyrus source — .psc)
│   ├── DirectorBridge.psc     (bridge script for CK side)
│   └── DirectorConfig.psc     (MCM-style config quest)
├── /ck                        (CK plugin source — .esm/.esp build artifacts)
├── /docs                      (design notes, RE notes)
│   ├── architecture.md
│   ├── papyrus-natives.md
│   └── re-notes/              (offsets, struct layouts as we discover them)
└── /scripts                   (build/deploy helpers)
```

---

## Core Concepts / Glossary

Disambiguate carefully — terms collide between L4D-world and Bethesda-world.

| Term | Meaning in this project |
|---|---|
| **Director** | Layer 1, the C++ brain. The thing that decides what happens. |
| **NextBot** | Valve's locomotion system. In this project, the *equivalent* is the engine's actor AI + navmesh + packages. We do not rebuild locomotion. |
| **Package** | Bethesda AI Package. A behavior the director assigns to an actor at runtime. |
| **Encounter Zone** | Bethesda CK concept — a region with leveling rules and respawn timers. We mostly bypass this in favor of dynamic spawning, but read it for context. |
| **Phase** | Director state: Build, Peak, Relax, Respite. |
| **Tension** | A scalar in `[0, 1]` representing player stress. Climbs in combat/danger, decays in safety. |
| **Spawn Budget** | Hard cap on actors the director has currently active. |
| **Stalker** | A director-spawned hostile assigned the "stalk" package. |
| **Flank Position** | A pre-authored idle marker the director treats as a candidate approach point during alarm response. |
| **Alarm Source** | The point in world space the director uses as the center for flanking distribution when SQ_Alarm fires. |
| **Safety Gate** | A condition that suppresses director activity (dialogue, sleep, build mode, ship interior, menus, Unity transition). |

---

## Subsystems

### Tension Model

- Scalar float `[0, 1]`
- Increments on: damage taken, enemy proximity, low health, low ammo, recent kills *by* enemies
- Decays on: time without contact, safe location (settlements, ship interior, key story locations)
- Sampled by Phase Machine every tick

### Phase Machine

| Phase | Director behavior |
|---|---|
| Build | Spawn aggressively, increase variety |
| Peak | Hold — no new spawns, let combat resolve |
| Relax | Allow tension to drain, suppress new spawns |
| Respite | Hard suppression, safe period before next Build |

Transitions are tension-threshold driven with hysteresis to prevent flapping. Min/max duration per phase to prevent degenerate states.

### Spawn Budget

- Hard cap: start at **20–30 active director actors** (tune empirically; SKK's guidance for SF is ~30 total including followers)
- Per-encounter-template sub-caps to prevent "every spawn is the same thing"
- Cleanup on phase transition to Respite

### Spawn Point Picker

Required checks before approving a spawn point:
1. On navmesh
2. Out of player line-of-sight (or in LOS only for ambush-from-cover patterns)
3. Within distance band appropriate to encounter type (close ambush: 15–30m, mid patrol: 40–80m, far stalker: 100m+)
4. Not inside a forbidden cell type (settlement, ship interior, vendor radius)
5. Faction-coherent with the cell (Spacers don't spawn in UC Vanguard HQ)

### Alarm Override / Flanking Distributor

The crown jewel feature. When `GetAlarmed` flips or SQ_Alarm (or its Starfield equivalent — **RE TODO: verify quest ID and stages on SF**) advances:

1. Director catches the event via hook
2. Query actors of relevant faction within radius R of alarm source
3. For each candidate: stop current package, push custom "investigate-and-flank" package
4. Destination = alarm source + per-actor offset
5. Offset computed by angular distribution (N actors → N evenly spaced angles around source, with jitter) OR by selection from pre-authored flank position markers in the cell
6. ETAs staggered over a 10–20s window so arrivals feel distributed, not synchronized
7. On no-contact arrival: transition to search package
8. On contact: yield to vanilla combat AI

The "spread out" behavior is what creates emergent fear. Vanilla AI clumps to the alert marker; this distributes.

### Safety Gates

Director MUST NO-OP when ANY of:
- Player in dialogue
- Player in any menu (inventory, map, ship builder, outpost builder, vendor)
- Player sleeping or waiting
- Player in ship interior (debatable — could allow for boarding encounters, flag for later)
- Player in Unity / NG+ transition
- Currently in a scripted quest scene with cinematic camera
- Save/load in progress (use SFSE save callback)

### Encounter Templates

Data-driven. Each template defines:
- Spawn list (leveled or fixed)
- Default package on spawn
- Behavior tags (ambush, patrol, hunt, swarm)
- Minimum/maximum count
- Phase eligibility (which director phases can spawn this)
- Location type filter (planet surface, derelict interior, station, etc.)
- Faction alignment

Loaded from JSON config at plugin init OR from CK form lists. Prefer JSON for iteration speed during development.

---

## Workflow

### Build (C++ plugin)

```
git clone --recurse-submodules <repo>
cd director
xmake build           # XMake path
# or
cmake --build build --preset ALL-release   # CMake path
```

Output: `Director.dll` → drop in `Data/SFSE/Plugins/`

### Build (Papyrus)

Use `CreationKit/Tools/Papyrus Compiler/PapyrusCompiler.exe` against `/papyrus/*.psc` → output `.pex` → into `Data/Scripts/`. Caprica works for decompilation but use CK compiler for production builds (GUARD support).

### Test loop

1. Build plugin + scripts
2. Deploy to game `Data/` via env vars `XSE_SF_MODS_PATH` or `XSE_SF_GAME_PATH`
3. Launch via `sfse_loader.exe` (NOT the Steam shortcut)
4. Use console: `coc <cell>` to a known test area
5. Enable director via MCM/config quest
6. Use debug commands (define a Papyrus console function during dev)
7. Monitor `Documents/My Games/Starfield/Logs/Script/Papyrus.0.log` for script trace
8. Monitor SFSE log for plugin-side activity

### Iterate fast

- Hot-reload Papyrus with `HotLoadPlugin` console command (limited; CK relaunch sometimes needed)
- For C++ changes: game must fully exit and relaunch
- Set up a one-button build-and-deploy script

---

## Conventions

### C++ side
- Namespace everything under `Director::`
- Subsystem files own their state; communicate via a `DirectorContext` singleton (not the prettiest, but matches the SFSE plugin pattern)
- Logging: use spdlog via CommonLibSF's logger setup; channel name `"Director"`
- Never allocate in tight hot paths (per-tick update loops); pool actor pointers
- Address Library IDs in a single `Offsets.h` with comments referencing the game version they were captured against

### Papyrus side
- Script prefix: `DIR_` (e.g., `DIR_BridgeMain`, `DIR_ConfigQuest`)
- Quests use `DIR_` prefix too
- Properties auto-filled where possible
- Never put gameplay logic in fragments; fragments call into proper scripts only
- Use guards (Starfield CK feature) for thread-safety on shared state

### Logging
- Three channels: `Director` (plugin), `DirectorScript` (Papyrus), `DirectorRE` (when reverse engineering / debugging engine state)
- Verbosity controlled by config, default to INFO in release
- Every major decision the director makes logs at DEBUG with reasoning ("Spawned Spacer ambush at <pos> because tension=0.7, phase=Build, time_since_combat=180s")

---

## Known Unknowns / RE Backlog

Things we need to verify or document before they bite us:

- [ ] Exact SQ_Alarm equivalent quest ID in Starfield (FO4 had specific quest forms; SF may differ)
- [ ] AI Package class layout in SF vs FO4 — fields renamed/reordered/added
- [ ] Faction reaction matrix internals — does CommonLibSF expose this cleanly?
- [ ] Navmesh query API surface — what's exposed for finding valid spawn points?
- [ ] Actor cap before engine starts dropping AI ticks — needs empirical benchmark
- [ ] How Starfield handles cell loading for non-contiguous space (planet → orbit → planet) and whether spawned director actors persist correctly across boundaries
- [ ] Whether the Unity / NG+ transition cleans up plugin state correctly
- [ ] Save/load callback semantics — does SFSE call us reliably on SF the way it does on SSE?

---

## Constraints (Do NOT)

- ❌ Do not spawn during dialogue, menus, sleep/wait, build mode, ship interior (unless boarding feature flag enabled), Unity transition
- ❌ Do not bypass Safety Gates "just for testing" without a kill switch
- ❌ Do not hardcode form IDs — use Address Library / form registry
- ❌ Do not assume FO4 Papyrus signatures work in SF — check Starfield CK Papyrus reference
- ❌ Do not block the main thread from C++ hooks; queue work to a dedicated thread or yield
- ❌ Do not spawn corpses faster than the engine cleans them (`iHoursToClearCorpses`); cap spawn rate
- ❌ Do not assume cross-version binary compatibility; recompile against new Address Library per game patch
- ❌ Do not link against the archived `Starfield-Reverse-Engineering/CommonLibSF` — use `libxse/CommonLibSF`

---

## Reference Materials

- **CommonLibSF (active fork):** `github.com/libxse/CommonLibSF`
- **SFSE source:** `github.com/ianpatt/sfse`
- **Plugin templates:** `github.com/libxse/commonlibsf-template`, `github.com/epinter/sfse-clib-template`
- **SKK Stalkers and Followers (SF):** `nexusmods.com/starfield/mods/6336`
- **SKK Combat Stalkers (FO4 — older, more polished):** `nexusmods.com/fallout4/mods/57842`
- **Starfield CK Papyrus reference:** `starfieldwiki.net/wiki/Starfield_Mod:Papyrus_Syntax_Reference`
- **Starfield CK Papyrus new features:** `starfieldwiki.net/wiki/Starfield_Mod:Papyrus_-_New_Features`
- **Console help command dump (function reference):** `starfield.fandom.com/wiki/Help_command`
- **Mike Booth on L4D Director:** search "Replayability in Left 4 Dead" GDC talk
- **L4D Director academic-ish writeup:** Booth, "The AI Systems of Left 4 Dead" (slides available)

---

## AI Agent Notes (Claude Code / Codex / Cursor — read this section)

If you are an AI agent picking up this codebase:

1. **Architecture is inverted on purpose.** The C++ plugin is the brain; CK content is data the brain consumes. Do not "helpfully" move director logic into Papyrus — that defeats the entire design.
2. **Check Address Library version before using any offset.** Game patches break offsets. If a hook stops firing after an update, first thing to check is whether the offset ID still maps to what we think it does.
3. **Reverse-engineering work goes in `/docs/re-notes/` with date and game version stamp.** If you discover a struct layout, document it before you use it.
4. **Performance budget is tight.** Director ticks should be <1ms on a midrange CPU. Profile before adding work to hot paths.
5. **When in doubt about Bethesda-engine behavior, look at how SKK or other established SF mod authors solved it before inventing.** Half the problems in this space are already-solved; the trick is finding the prior art.
6. **Do not break Safety Gates "temporarily for testing."** Always behind a feature flag. The director crashing someone's playthrough during a main quest scene is unrecoverable trust damage.
7. **When generating Papyrus, verify the function exists in the SF flavor first.** Many FO4/SSE functions were renamed, removed, or changed signature.
8. **Prefer data-driven over hardcoded.** New encounter type → new JSON entry, not new C++ code, where possible.

---

## Open Design Questions

- Should the director also handle *friendly* spawn pacing (random allied patrols, traveler encounters) or stay hostile-only? L4D was hostile-only; Bethesda games usually mix.
- Should we expose a public API for other mods to register their own encounter templates? (Long-term yes, but adds maintenance burden.)
- MCM-style runtime config vs JSON-only — what's the UX bar?
- Ship boarding as a director-managed encounter type — feasible or out of scope for v1?
- Multiplanet "campaign tension" that persists across cell changes — interesting but probably v2.

---

## Changelog

- `[YYYY-MM-DD]` Initial CLAUDE.md draft. Architecture sketch, subsystem outline, RE backlog established.
- `[2026-06-09]` Audit pass: documented actual repo state (docs-only, pre-scaffold, no git yet), established AGENTS.md as a synced byte-copy of CLAUDE.md, flagged XMake-vs-CMake as the blocking decision for scaffolding.

# SFSE Hello-World Plugin — Design Spec

**Date:** 2026-06-09
**Status:** Approved approach (Option A: template + submodule), pending spec review
**Purpose:** Validate the full SFSE plugin toolchain end-to-end before any Director logic is written. The scaffold produced here *is* the permanent project skeleton — not a throwaway.

---

## Goal

Build, deploy, and load a minimal SFSE plugin (`Director.dll` v0.0.1) that proves:

1. The toolchain compiles a CommonLibSF-based plugin on this machine (XMake + MSVC, VS 2026).
2. SFSE loads the plugin at game launch.
3. SFSE runtime messaging events reach our code (the pipeline the Director will live on).

## Success Criteria (Pass = all three)

1. `Documents\My Games\Starfield\SFSE\Logs\Director.log` exists and contains the load banner (plugin name, version, game version).
2. `Director.log` contains at least one logged SFSE runtime message event (e.g., PostLoad / PostDataLoad).
3. `sfse.log` lists the plugin as loaded without errors.

## Verified Environment (2026-06-09)

| Item | Value |
|---|---|
| Game | `D:\SteamLibrary\steamapps\common\Starfield`, v1.16.242.0 (Steam) |
| SFSE | `sfse_1_16_242.dll` — exact runtime match, loader present |
| Mod manager | MO2, instance `C:\Users\DJLegnds\AppData\Local\ModOrganizer\Starfield`, base dir `D:\SFMO2` |
| Address Library | `versionlib-1-16-242-0.bin` present as MO2 mod — exact runtime match |
| Deploy target | `D:\SFMO2\mods\Starfield Director\SFSE\Plugins\` (existing MO2 mod folder; stale `StarfieldDirector.dll` from a prior attempt deleted 2026-06-09) |
| Toolchain | VS Community 2026 (18.5), xmake, cmake, ninja, git — all installed |

**MO2 constraint (load-bearing):** MO2 uses a virtual file system. Mods (including Address Library and our plugin) only exist in `Data\` when the game is launched **through MO2**. The test MUST launch `sfse_loader.exe` via MO2, with the "Starfield Director" mod enabled in the active profile.

## Architecture

### Scaffold (Option A — approved)

- Repo: `C:\Users\DJLegnds\Downloads\Mods\Starfield Director` (git initialized 2026-06-09).
- Base: `libxse/commonlibsf-template` (XMake), adapted into the repo layout from CLAUDE.md.
- `libxse/CommonLibSF` as a git submodule at `extern/CommonLibSF`, pinned to a recorded commit. Submodule (not package fetch) so broken definitions can be patched in-tree — CommonLibSF is a known minefield (many class definitions broke on game 1.14→1.15 and were never fixed).
- Plugin name `Director`, version 0.0.1, C++23.

### Plugin behavior (`src/main.cpp` only)

Safe-zone API only — no engine struct definitions touched:

1. Declare SFSE plugin version data (name, version, runtime compatibility).
2. `SFSEPluginLoad`: initialize spdlog per CLAUDE.md conventions (channel `Director`, file `Documents\My Games\Starfield\SFSE\Logs\Director.log`), log banner with plugin + game version.
3. Register an SFSE messaging-interface listener that logs every message type received, by name where known, by numeric type otherwise.

### Build & deploy

- `xmake f -m release` / `xmake` → `Director.dll`.
- `scripts/deploy.ps1`: build, then copy the DLL to the MO2 mod folder deploy target. One button.

## Test Procedure

1. Build + deploy via `scripts/deploy.ps1`.
2. User launches the game through MO2 (`sfse_loader.exe` executable entry), with "Starfield Director" mod enabled.
3. Reach the main menu (loading a save is optional — DataLoaded-class messages may require it; main menu is sufficient for criterion 2 if any message arrives).
4. Quit. Inspect `Director.log` and `sfse.log` against the success criteria.

## Risks & Fallbacks

| Risk | Likelihood | Fallback |
|---|---|---|
| XMake can't drive VS 2026 (18.5) toolset; template expects VS2022-era MSVC | Medium | Pass explicit toolchain config to xmake; if hopeless, install VS2022 Build Tools alongside, or clang-cl |
| CommonLibSF HEAD doesn't declare compatibility with runtime 1.16.242 | Low-Medium | Check the template's runtime-compat declaration; loosen to address-library-independent mode for this plugin (no engine offsets used) |
| Submodule HEAD is broken for reasons unrelated to us | Low | Pin to last known-good tagged commit instead of HEAD |

Out of scope for this test: any engine hook, any engine struct access, Papyrus, CK content. Anything broken discovered in CommonLibSF gets documented in `/docs/re-notes/` with date + game version per CLAUDE.md.

## Test Results (2026-06-10)

**PASS — all three criteria.** Game v1.16.242.0, SFSE 1.16.242, launched via MO2 (profile "CK"), CommonLibSF pinned `12d665b5`, VS 2026 MSVC build. No crash.

1. ✅ `Director.log` created; banner `Director v0.0.1 loaded` + `message listener registered`.
2. ✅ All four runtime messages received: `kPostLoad`, `kPostPostLoad` (main menu), `kPostDataLoad`, `kPostPostDataLoad` (save load).
3. ✅ `sfse.txt`: `plugin Director.dll (00000001 Director 00000010) loaded correctly (handle 6)`; zero errors. (Note: SFSE's own log is `sfse.txt` on this install, not `sfse.log`.)

**RE finding:** SFSE messages arrive on different threads — load-phase messages on thread 108572, DataLoad-phase on thread 319060. Director event intake must be thread-safe (use guards/queues; see CLAUDE.md constraint about not blocking hooks).

## Aftermath

1. Update CLAUDE.md: repo-state line (no longer docs-only), replace aspirational build commands with the real ones, record the pinned CommonLibSF commit.
2. Sync AGENTS.md (byte-copy).
3. Machine-specific paths live in `.claude.local.md` (gitignored), not CLAUDE.md.
4. Commit scaffold + first green build.

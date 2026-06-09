# SFSE Hello-World Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and load `Director.dll` v0.0.1 — a minimal SFSE plugin proving the full toolchain (XMake + MSVC + CommonLibSF submodule → SFSE load → runtime messaging events reach our code).

**Architecture:** Scaffold from `libxse/commonlibsf-template` (verified 2026-06-09: `xmake.lua` + `src/main.cpp` + `src/pch.h` + submodule at `lib/commonlibsf`). The template's `commonlibsf.plugin` xmake rule generates plugin version data; REX logging is initialized by `SFSE::Init()` and writes to `Documents\My Games\Starfield\SFSE\Logs\<plugin-name>.log`. We add one thing on top of the stock template: an SFSE messaging listener that logs every message type.

**Tech Stack:** XMake, MSVC (VS Community 2026 / 18.5), C++23, CommonLibSF (libxse, pinned submodule), SFSE 1.16.242, MO2 deploy.

**Verified API facts (fetched from live repos 2026-06-09 — do not re-derive from memory):**
- Template `main.cpp` uses macros `SFSE_PLUGIN_PRELOAD(const SFSE::PreLoadInterface* a_sfse)` and `SFSE_PLUGIN_LOAD(const SFSE::LoadInterface* a_sfse)`; logging via `REX::INFO("...")`.
- `SFSE::MessagingInterface::MessageType`: `kPostLoad`, `kPostPostLoad`, `kPostDataLoad`, `kPostPostDataLoad` (0–3).
- `SFSE::GetMessagingInterface()` → `const MessagingInterface*`; `RegisterListener(EventCallback)` returns `bool`; callback type `void(Message* a_msg)`.
- Template build modes are `debug` and `releasedbg` (NOT `release` — the spec's `xmake f -m release` was wrong; this plan corrects it).

**Environment facts (from `.claude.local.md`):**
- Repo: `C:\Users\DJLegnds\Downloads\Mods\Starfield Director` (git initialized, initial commit done)
- Deploy target: `D:\SFMO2\mods\Starfield Director\SFSE\Plugins\`
- Game launch: ONLY through MO2 (VFS), `sfse_loader.exe` as MO2 executable
- Logs: `%USERPROFILE%\Documents\My Games\Starfield\SFSE\Logs\`

**Testing note:** A game plugin has no unit-testable surface without an engine harness. "Tests" in this plan are honest equivalents: configure/build success with expected artifacts, and runtime log verification against the spec's three pass criteria. The manual game-launch step is performed by the user.

---

### Task 1: Scaffold build files + CommonLibSF submodule

**Files:**
- Create: `xmake.lua`
- Create: `src/pch.h`
- Create: `lib/commonlibsf` (git submodule)

- [ ] **Step 1: Add the CommonLibSF submodule**

```powershell
git -C "C:\Users\DJLegnds\Downloads\Mods\Starfield Director" submodule add https://github.com/libxse/CommonLibSF.git lib/commonlibsf
git -C "C:\Users\DJLegnds\Downloads\Mods\Starfield Director" submodule status
```

Expected: submodule cloned; `submodule status` prints a commit hash + ` lib/commonlibsf`. **Record that hash** — it goes into CLAUDE.md in Task 6.

- [ ] **Step 2: Write `xmake.lua`** (template's, with our identity; target name `Director` → `Director.dll`)

```lua
-- include subprojects
includes("lib/commonlibsf")

-- set project constants
set_project("starfield-director")
set_version("0.0.1")
set_license("GPL-3.0")
set_languages("c++23")
set_warnings("allextra")

-- add common rules
add_rules("mode.debug", "mode.releasedbg")
add_rules("plugin.vsxmake.autoupdate")

-- define targets
target("Director")
    add_rules("commonlibsf.plugin", {
        name = "Director",
        author = "DJLegends",
        description = "AI Director for Starfield",
        email = "dkidd799@gmail.com"
    })

    -- add src files
    add_files("src/**.cpp")
    add_headerfiles("src/**.h")
    add_includedirs("src")
    set_pcxxheader("src/pch.h")
```

- [ ] **Step 3: Write `src/pch.h`** (template-faithful — both includes; do not trim on the first build)

```cpp
#pragma once

#include "RE/Starfield.h"
#include "SFSE/SFSE.h"
```

- [ ] **Step 4: Verify configure succeeds (this is the VS 2026 risk gate)**

```powershell
Set-Location "C:\Users\DJLegnds\Downloads\Mods\Starfield Director"
xmake f -m releasedbg -y
```

Expected: configure completes, MSVC toolchain detected, packages fetched (network needed on first run).
**If MSVC detection fails:** try `xmake f -m releasedbg -y --vs=2026`; if still failing, `xmake f -m releasedbg -y --toolchain=clang-cl`. If all fail, STOP and report — fallback decision (VS2022 Build Tools install) belongs to the user.

- [ ] **Step 5: Commit**

```powershell
git add xmake.lua src/pch.h .gitmodules lib/commonlibsf
git commit -m "feat: scaffold xmake build with CommonLibSF submodule (template: libxse/commonlibsf-template)"
```

---

### Task 2: Plugin source — load banner + messaging listener

**Files:**
- Create: `src/main.cpp`

- [ ] **Step 1: Write `src/main.cpp`**

Stock template entry points, plus the messaging listener (our one addition). Fixed-string logs only — REX format-arg signature is unverified, and verifying it isn't worth it for v0.0.1. Registration failure returns `false` so the plugin fails loudly in `sfse.log` instead of silently half-loading.

```cpp
namespace
{
    void MessageCallback(SFSE::MessagingInterface::Message* a_msg)
    {
        switch (a_msg->type) {
            case SFSE::MessagingInterface::kPostLoad:
                REX::INFO("Director: received kPostLoad");
                break;
            case SFSE::MessagingInterface::kPostPostLoad:
                REX::INFO("Director: received kPostPostLoad");
                break;
            case SFSE::MessagingInterface::kPostDataLoad:
                REX::INFO("Director: received kPostDataLoad");
                break;
            case SFSE::MessagingInterface::kPostPostDataLoad:
                REX::INFO("Director: received kPostPostDataLoad");
                break;
            default:
                REX::INFO("Director: received unknown message type");
                break;
        }
    }
}

SFSE_PLUGIN_PRELOAD(const SFSE::PreLoadInterface* a_sfse)
{
    SFSE::Init(a_sfse);

    return true;
}

SFSE_PLUGIN_LOAD(const SFSE::LoadInterface* a_sfse)
{
    SFSE::Init(a_sfse);

    REX::INFO("Director v0.0.1 loaded");

    const auto messaging = SFSE::GetMessagingInterface();
    if (!messaging || !messaging->RegisterListener(MessageCallback)) {
        REX::ERROR("Director: failed to register SFSE message listener");
        return false;
    }
    REX::INFO("Director: message listener registered");

    return true;
}
```

- [ ] **Step 2: Build**

```powershell
Set-Location "C:\Users\DJLegnds\Downloads\Mods\Starfield Director"
xmake
```

Expected: compiles and links; final artifact `build\windows\x64\releasedbg\Director.dll` exists. First build is slow (precompiled `RE/Starfield.h` is huge).

- [ ] **Step 3: Verify artifact**

```powershell
Get-Item "build\windows\x64\releasedbg\Director.dll" | Select-Object Name, Length, LastWriteTime
```

Expected: `Director.dll` listed with a fresh timestamp.

- [ ] **Step 4: Commit**

```powershell
git add src/main.cpp
git commit -m "feat: hello-world plugin - load banner + SFSE message listener"
```

---

### Task 3: One-button deploy script

**Files:**
- Create: `scripts/deploy.ps1`

- [ ] **Step 1: Write `scripts/deploy.ps1`**

```powershell
# Build Director.dll and deploy to the MO2 mod folder.
# Usage: .\scripts\deploy.ps1 [-Mode releasedbg|debug]
param(
    [ValidateSet("releasedbg", "debug")]
    [string]$Mode = "releasedbg"
)

$repo = Split-Path -Parent $PSScriptRoot
$deployDir = "D:\SFMO2\mods\Starfield Director\SFSE\Plugins"
$dll = Join-Path $repo "build\windows\x64\$Mode\Director.dll"

Set-Location $repo
xmake f -m $Mode -y
if ($LASTEXITCODE -ne 0) { throw "xmake configure failed (exit $LASTEXITCODE)" }
xmake
if ($LASTEXITCODE -ne 0) { throw "xmake build failed (exit $LASTEXITCODE)" }
if (-not (Test-Path $dll)) { throw "Build artifact not found: $dll" }

New-Item -ItemType Directory -Force $deployDir | Out-Null
Copy-Item $dll $deployDir -Force
Write-Host "Deployed $dll -> $deployDir"
```

- [ ] **Step 2: Run it**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\DJLegnds\Downloads\Mods\Starfield Director\scripts\deploy.ps1"
```

Expected: ends with `Deployed ... -> D:\SFMO2\mods\Starfield Director\SFSE\Plugins`.

- [ ] **Step 3: Verify deployed file**

```powershell
Get-Item "D:\SFMO2\mods\Starfield Director\SFSE\Plugins\Director.dll" | Select-Object Name, Length, LastWriteTime
```

Expected: fresh `Director.dll` at the deploy target.

- [ ] **Step 4: Commit**

```powershell
git add scripts/deploy.ps1
git commit -m "feat: one-button build-and-deploy script to MO2 mod folder"
```

---

### Task 4: Runtime load test (manual step — user launches the game)

**Files:** none (verification only)

- [ ] **Step 1: Pre-flight — note current log state**

```powershell
$logs = "$env:USERPROFILE\Documents\My Games\Starfield\SFSE\Logs"
Get-ChildItem $logs -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
```

- [ ] **Step 2: USER ACTION — launch through MO2**

Ask the user to: enable the "Starfield Director" mod in their active MO2 profile, launch `sfse_loader.exe` through MO2, reach the main menu, optionally load a save, then quit. **Do not launch the game programmatically** — it's the user's session.

- [ ] **Step 3: Verify pass criteria (all three from the spec)**

```powershell
$logs = "$env:USERPROFILE\Documents\My Games\Starfield\SFSE\Logs"
Get-Content "$logs\Director.log"
Select-String -Path "$logs\sfse.log" -Pattern "Director"
```

Expected:
1. `Director.log` exists and contains `Director v0.0.1 loaded` and `Director: message listener registered`.
2. `Director.log` contains at least one `Director: received k...` line.
3. `sfse.log` shows the plugin loaded without errors.

**If the log file has a different name** (the plugin rule controls it): `Get-ChildItem $logs | Sort-Object LastWriteTime -Descending` and inspect the newest file.
**If criteria fail:** STOP. Capture both logs verbatim, report findings — do not patch-and-relaunch in a loop; each relaunch costs the user a game boot.

- [ ] **Step 4: Commit a test record**

Append results (date, game version, SFSE version, pass/fail per criterion, log excerpts) to `docs/superpowers/specs/2026-06-09-sfse-hello-world-design.md` under a new `## Test Results` section, then:

```powershell
git add docs/superpowers/specs/2026-06-09-sfse-hello-world-design.md
git commit -m "docs: hello-world load test results"
```

---

### Task 5: Aftermath — make CLAUDE.md tell the truth

**Files:**
- Modify: `CLAUDE.md` (Status repo-state line; Workflow build commands)
- Modify: `AGENTS.md` (byte-copy sync)

- [ ] **Step 1: Update CLAUDE.md**

Replace the Status repo-state line with the now-true state (scaffolded, building, pinned submodule hash from Task 1 Step 1). In the Workflow section, replace the aspirational build block with the real commands:

```
xmake f -m releasedbg -y
xmake
# or one-button build+deploy:
.\scripts\deploy.ps1
```

Also note: deploy goes to the MO2 mod folder (path in `.claude.local.md`), and the game must be launched through MO2.

- [ ] **Step 2: Sync AGENTS.md**

```powershell
Copy-Item "C:\Users\DJLegnds\Downloads\Mods\Starfield Director\CLAUDE.md" "C:\Users\DJLegnds\Downloads\Mods\Starfield Director\AGENTS.md" -Force
```

- [ ] **Step 3: Commit**

```powershell
git add CLAUDE.md AGENTS.md
git commit -m "docs: record real build/deploy workflow after first green load test"
```

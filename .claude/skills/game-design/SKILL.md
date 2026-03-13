---
name: game-design
description: Must be used whenever the user requests a game developed from scratch, or a large gameplay system. This skill governs how you break down work into scene building and scripting, and defines the quality gates you must pass.
---

# Game Design Workflow

Every game is built in two phases: **Scene** (the world) then **Scripts** (the logic). Plan both up front, build the scene first, verify it, then bring it to life with scripts.

This will be a production-grade, polished game. It will not be done in one shot. That is why planning matters. **Never use placeholder art. Never write throwaway scripts.** Every asset, every entity, every line of code ships.

## Core Rules

1. Inspect the request and the existing project before planning. Reuse what exists.
2. Every game is multiplayer. Design for many concurrent players from the start. Use ownership patterns (plot-based, instance-based, per-player state on the player class) so players don't collide on shared world state.
3. Search for real assets. Use the All Out MCP `asset_remote_search` and `asset_remote_download` tools. Prefer animated Spine assets if appropriate. 
4. After any script change, compile with the All Out MCP compile tool.

---

### 1. Break Into Scene and Script Epics

Think in two categories:

**Scene epics** — the physical world the player sees and walks through:
- Environment and terrain (ground, walls, decorations, lighting)
- Spawn points, lanes, zones, arenas
- Interactable objects and NPCs (placed as entities with components)
- UI anchors and HUD elements
- Prefabs for anything spawned at runtime

**Script epics** — the logic that makes the world dynamic:
- Player abilities and input handling
- Enemy/NPC behavior and AI
- Match flow, game state, win/loss conditions
- Economy, resources, progression
- Wave systems, spawners, timers
- HUD updates and feedback
- Polish (screen shake, sound, particles)

### 3. Write `game_plan.json`

Write this to the project root:

```json
{
  "game": "Game Title",
  "description": "One sentence",
  "scene_epics": [
    {
      "id": "arena-layout",
      "name": "Arena Layout",
      "status": "pending",
      "tasks": [
        { "name": "Search and download ground/wall/decoration assets", "done": false },
        { "name": "Place arena boundary walls", "done": false },
        { "name": "Place spawn points for players and enemies", "done": false },
        { "name": "Add decorative props to fill the space", "done": false }
      ],
      "verified": false
    }
  ],
  "script_epics": [
    {
      "id": "enemy-waves",
      "name": "Enemy Wave System",
      "status": "pending",
      "skills": ["syntax", "testing"],
      "tasks": [
        { "name": "Create wave manager script with timed spawns", "done": false },
        { "name": "Implement enemy pathfinding to target", "done": false },
        { "name": "Scale difficulty across waves", "done": false }
      ],
      "gate_test": "test_gate_enemy_waves",
      "gate_passed": false
    }
  ]
}
```

---

## 2. Build the Scene
For each scene epic:

1. **Find assets** — use `asset_remote_search` to find high-quality assets. Download them with `asset_remote_download`. Never skip this step, never use placeholder art.
2. **Build the world** — use the All Out MCP scene tools (`modify_scene`, `scene_hierarchy`, `scene_find_entities`, `instantiate_asset`, etc.) to place entities, set positions, attach sprites, and compose the environment.
3. **Mark tasks done** in `game_plan.json` as you go.

### Scene Verification (Subagent)

After completing a scene epic, **launch a verification subagent**. This subagent's job is to genuinely critique the work — not rubber-stamp it.

The verification subagent prompt must include:

1. **What to verify** — the specific scene epic that was just built.
2. **How to verify** — use `editor_scene_screenshot` from multiple camera positions, use `scene_hierarchy` to inspect the entity tree, use `scene_find_entities` to confirm everything exists.
3. **Quality criteria** — the subagent must check for:
   - **No gaps** — no empty space where there should be ground, walls, or props. The world must feel complete and intentional.
   - **No missing textures** — every entity with a `Sprite_Renderer` must have a texture assigned. No invisible or default-white sprites.
   - **Proper scale and positioning** — entities must be appropriately sized relative to each other AND THE PLAYER. Nothing floating in space or buried in the ground.
   - **Production-grade density** — the scene should feel like a finished game, not a prototype. Enough props, enough detail, enough variety.
   - **Correct structure** — spawn points exist where expected, interactable entities are reachable, zones are properly bounded.
4. **What to return** — a pass/fail verdict with specific issues listed. If it fails, list exactly what needs fixing.

**Do NOT write test.csl files for scene verification.** Scene quality is verified visually and structurally through the subagent, not through the test runner.

Only set `verified: true` on the scene epic after the verification subagent passes. If it fails, fix the issues and re-verify.

Example verification subagent prompt:

```
Verify the "Arena Layout" scene epic for the Tower Defense game.

Read these skills first:
- <absolute path to game-design SKILL.md>

Use these MCP tools to critique this scene with a critical lens:
1. Call scene_hierarchy to get the full entity tree
2. Call editor_scene_screenshot to capture the current view
3. Call scene_camera to move to different positions, then screenshot again (get at least 3 angles)
4. Call scene_find_entities to confirm key entities exist: "Spawn_Point_1", "Spawn_Point_2", "Tower_Pad_1" through "Tower_Pad_6", "Base"
5. Call viewport_entities to see what's actually visible

Evaluate against these criteria:
- NO GAPS: Is there ground/terrain covering the entire play area? Any holes or missing tiles?
- NO MISSING TEXTURES: Does every entity have a real sprite? Zoom in on suspicious areas.
- DENSITY: Does this look like a shipped game or an empty prototype? Are there enough decorative props?
- SCALE: Are towers, enemies, and the base appropriately sized relative to the lane?
- STRUCTURE: Are spawn points at lane entrances? Are tower pads along the lane? Is the base at the end?

Return a verdict: PASS or FAIL.
If FAIL, list every minor issue along with entity names and positions so they can be fixed.
```

---

## Phase 3 — Build the Scripts

After all scene epics are verified, build the `script_epics` in order.

For each script epic:

### Step 1: Load Skills

Read the `SKILL.md` for every skill listed on the epic before starting.

### Step 2: Implement

Work through the `tasks` array in order:

1. Implement the task in CSL
2. Compile after every change
3. Fix errors before moving on
4. Mark the task done in `game_plan.json`

Use the appropriate engine skills as you go and constantly reference AGENTS.md. 

### Step 3: Gate Test
You must have a subagent write a gate_test for every skill. Have it follow the testing skill. 

Gate subagent prompt: 
```
Write the gate test for the "{epic name}" script epic.

Read these skills first:
- <absolute path to testing/SKILL.md>
- <absolute path to syntax/SKILL.md>

Read these files to understand what was built:
- <list every script file the epic created or modified>

The test procedure must be named `{gate_test name}`.
It should:
- <specific assertions for this epic's deliverable>
- Take screenshots at key moments

Write the test to tests/{test_file}.csl.
After writing, compile using the All Out MCP compile tool and fix any errors.
```

### Step 4: Run the Gate Test

Use MCP `run_tests` with the gate test name.

- **Pass** → set `gate_passed: true`, set `status: "done"`, continue
- **Fail** → inspect, fix, recompile, re-run

### Step 5: Checkpoint

Update `game_plan.json` after each epic.

---

## Phase 4 — Final Verification

After all epics are done:

1. Run the full test suite
2. Take screenshots of the complete game
3. Report what was built and any remaining risks

---

## Resume

If `game_plan.json` already exists:

1. Read it and show current status
2. Resume from the first incomplete epic (scene epics first, then script epics)
3. If the user changes scope, add/modify/reorder epics and update the file immediately

---

## Example: 2D Tower Defense

Given: "Make a tower defense where enemies follow a lane to a base, the player places towers, towers auto-fire, waves scale up, match ends when the base dies."

```json
{
  "game": "Lane Defense",
  "description": "Place towers to stop waves of enemies from reaching the base",
  "scene_epics": [
    {
      "id": "arena-environment",
      "name": "Arena Environment",
      "status": "pending",
      "tasks": [
        { "name": "Search and download ground tile, wall, and decoration assets", "done": false },
        { "name": "Lay out the lane path with ground tiles from spawn to base", "done": false },
        { "name": "Place boundary walls and obstacle props along the lane", "done": false },
        { "name": "Add decorative environment props (trees, rocks, grass) to fill empty space", "done": false },
        { "name": "Set up camera bounds for the play area", "done": false }
      ],
      "verified": false
    },
    {
      "id": "gameplay-entities",
      "name": "Gameplay Entities",
      "status": "pending",
      "tasks": [
        { "name": "Search and download tower, enemy, and base assets", "done": false },
        { "name": "Place the base entity at the lane endpoint with sprite and health component", "done": false },
        { "name": "Place 6 tower pad entities along the lane with interaction zones", "done": false },
        { "name": "Place enemy spawn point entities at the lane entrance", "done": false },
        { "name": "Create tower prefab and enemy prefab for runtime spawning", "done": false }
      ],
      "verified": false
    }
  ],
  "script_epics": [
    {
      "id": "enemy-wave-loop",
      "name": "Enemy Wave Loop",
      "status": "pending",
      "skills": ["syntax", "testing"],
      "tasks": [
        { "name": "Implement wave manager with timed spawns from spawn points", "done": false },
        { "name": "Move enemies along the lane using pathfinding", "done": false },
        { "name": "Damage the base when an enemy reaches it and destroy the enemy", "done": false }
      ],
      "gate_test": "test_gate_enemy_wave_loop",
      "gate_passed": false
    },
    {
      "id": "tower-placement",
      "name": "Tower Placement",
      "status": "pending",
      "skills": ["syntax", "testing"],
      "tasks": [
        { "name": "Implement tap-to-build on tower pads using plot ownership (per-player pad locking)", "done": false },
        { "name": "Spend currency to place a tower, block if pad is occupied or owned by another player", "done": false },
        { "name": "Visual feedback on valid/invalid/owned pads", "done": false }
      ],
      "gate_test": "test_gate_tower_placement",
      "gate_passed": false
    },
    {
      "id": "tower-combat",
      "name": "Tower Combat",
      "status": "pending",
      "skills": ["syntax", "testing"],
      "tasks": [
        { "name": "Give towers targeting rules and fire cadence", "done": false },
        { "name": "Spawn projectiles that travel to and damage enemies", "done": false },
        { "name": "Award currency to the tower's owner on kill", "done": false }
      ],
      "gate_test": "test_gate_tower_combat",
      "gate_passed": false
    },
    {
      "id": "economy-and-scaling",
      "name": "Economy and Wave Scaling",
      "status": "pending",
      "skills": ["syntax", "testing"],
      "tasks": [
        { "name": "Track per-player currency as a field on the player class", "done": false },
        { "name": "Register currency with Economy system for persistence", "done": false },
        { "name": "Scale enemy count and stats between waves", "done": false }
      ],
      "gate_test": "test_gate_economy_scaling",
      "gate_passed": false
    },
    {
      "id": "hud-and-match-flow",
      "name": "HUD and Match Flow",
      "status": "pending",
      "skills": ["syntax", "ui", "testing"],
      "tasks": [
        { "name": "Display per-player currency, shared base health, wave number", "done": false },
        { "name": "Show build menu with tower options and costs", "done": false },
        { "name": "Implement win state (all waves cleared) and loss state (base destroyed)", "done": false },
        { "name": "End-of-match screen with player stats", "done": false }
      ],
      "gate_test": "test_gate_hud_match_flow",
      "gate_passed": false
    }
  ]
}
```

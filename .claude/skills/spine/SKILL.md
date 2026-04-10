---
name: spine
description: You must load this tool when working with Spine animators or player animations, it provides the Spine API surface you must adhere to. 
---
# Spine Animation System

Two ways to use Spine animations:
1. **Spine_Animator** (Component) - Animated entity in the scene
2. **Spine_Instance** (Standalone) - UI animations

## Spine_Animator (Component)
For runtime-spawned non-player entities:
```csl
entity := Scene.create_entity();
animator := entity.add_component(Spine_Animator);
animator.awaken();  // REQUIRED before calling animation methods
animator.set_skeleton(get_asset(Spine_Asset, "anims/rig.spine"));
animator.set_skin("variant");
animator.refresh_skins(); // REQUIRED after any skin change
// set_animation(animation_name, loop, track, speed = 1)
animator.set_animation("Idle", true, 0);
```
```csl
animator.layer: s32;
animator.scale: v2;
animator.speed_multiplier: float;
```

**You MUST call `awaken()` before calling any animation methods** if your component and the Spine_Animator start at the same time on the same entity.

## Player Animations
Every player has a Spine_Animator. Do not set its skeleton manually. It uses the $AO/streamed_character

### How the Player Rig Works

The player's Spine rig is configured in `scene.config` and a player.merged_spine_rig file, NOT in code:

```json
"default_player_rig": "player.merged_spine_rig#output"
```

The `player.merged_spine_rig` file combines a base rig with game-specific animation rigs. 

**CRITICAL NOTE**: Spine rigs in player merged rigs must be PRE-VETTED. The main additional rig you have access to is the reusable-weapons (https://github.com/All-Out-Games/reusable-weapons-csl.git) rig.

```json
{
    "base_rig": "anims/player/004RAND_Base.spine",
    "rigs_to_merge": [
        { "rig": "anims/roles/Mimicer/playercharacter.spine" },
        { "rig": "anims/roles/Pyro/playercharacter.spine" },
        { "rig": "anims/roles/Ggg/004RAND_base.spine" },
        // ... other rigs (e.g. reusable weapons)
    ],
}
```

This merges all skins & animations into a single skeleton so the player's Spine_Animator has access to every animation at runtime. It's up to you to **extend** the default state machine to support these new animations. 

### Setup Pattern

```csl
Player :: class : Player_Base {
    sm_inited: bool;

    ao_start :: proc(using this: Player) {
        this.ensure_anim_state_machine();
    }

    ensure_anim_state_machine :: proc(using this: Player) {
        if sm_inited return;

        // Get the EXISTING state machine from the editor
        sm := this.animator.state_machine;
        if sm == null return;

        // Get the existing layer and idle state
        layer := sm.try_get_layer("main");
        if layer == null return;
        idle_state := layer.try_get_state("Idle");
        if idle_state == null return;

        // Extend with game-specific states (split into helper procs)
        setup_combat_states(sm, layer, idle_state);
        setup_role_states(sm, layer, idle_state);

        sm_inited = true;
    }
}
```

### Adding a One-Shot Animation State

The standard pattern for adding a triggered animation that plays once and returns to idle:

```csl
setup_combat_states :: proc(sm: State_Machine, layer: State_Machine_Layer, idle_state: State_Machine_State) {
    // 1. Create a trigger variable on the state machine
    attack_var := sm.create_variable("attack", State_Machine_Variable.Kind.TRIGGER);

    // 2. Create the animation state (name, is_loop, duration)
    attack_state := layer.create_state("Attack_Melee_1", false, 1.0);

    // 3. Create a global transition INTO the state, triggered by the variable
    layer.create_global_transition(attack_state, false).create_trigger_condition(attack_var);

    // 4. Create an auto-transition BACK to idle when the animation finishes
    layer.create_transition(attack_state, idle_state, true);
}
```

### Chained Animation States

For animations that flow through multiple states before returning to idle (e.g., start → loop → end):

```csl
// Trapped start (one-shot) -> Trapped loop (looping) -> Trapped end (one-shot) -> Idle
trapped_start_var := sm.create_variable("trapped_start", State_Machine_Variable.Kind.TRIGGER);
trapped_start_state := layer.create_state("Trapped_Start", false, 0.5);
layer.create_global_transition(trapped_start_state, false).create_trigger_condition(trapped_start_var);

trapped_loop_state := layer.create_state("Trapped_Loop", true, 0.0);
layer.create_transition(trapped_start_state, trapped_loop_state, true); // auto after start finishes

// End is triggered separately (e.g., when player is freed)
trapped_end_var := sm.create_variable("trapped_end", State_Machine_Variable.Kind.TRIGGER);
trapped_end_state := layer.create_state("Trapped_End", false, 0.5);
layer.create_global_transition(trapped_end_state, false).create_trigger_condition(trapped_end_var);
layer.create_transition(trapped_end_state, idle_state, true); // auto back to idle
```

## NPC State Machine
For complex non-player spines, you can create a state machine: 

```csl
Enemy_NPC :: class : Component {
    animator: Spine_Animator @ao_serialize;
    state_machine: State_Machine;

    ao_start :: method() {
        state_machine = State_Machine.create();

        // Variables
        is_moving := state_machine.create_variable("is_moving", .BOOL);
        attack_trigger := state_machine.create_variable("attack", .TRIGGER);  // auto-resets after triggering
        die_trigger := state_machine.create_variable("die", .TRIGGER);

        // Layer maps to a Spine track
        layer := state_machine.create_layer("main", 0);

        // States -- name must match Spine animation
        // create_state(name, loop, duration = 0) -- duration pulled from spine rig
        idle_state := layer.create_state("idle", true);
        walk_state := layer.create_state("walk", true);
        attack_state := layer.create_state("attack", false);   // one-shot
        death_state := layer.create_state("death", false);

        layer.set_initial_state(idle_state);

        // create_transition(from, to, require_state_complete)
        idle_to_walk := layer.create_transition(idle_state, walk_state, false);
        idle_to_walk.create_bool_condition(is_moving, true);

        walk_to_idle := layer.create_transition(walk_state, idle_state, false);
        walk_to_idle.create_bool_condition(is_moving, false);

        // create_global_transition(to, allow_transition_to_self) -- from any state
        to_attack := layer.create_global_transition(attack_state, true);
        to_attack.create_trigger_condition(attack_trigger);

        // require_state_complete = true: waits for attack to finish
        attack_to_idle := layer.create_transition(attack_state, idle_state, true);

        to_death := layer.create_global_transition(death_state, false);
        to_death.create_trigger_condition(die_trigger);

        animator.awaken();
        animator.set_state_machine(state_machine, true);  // true = transfer ownership
    }

    ao_update :: method(dt: float) {
        state_machine.set_bool("is_moving", is_moving());
    }

    on_attack :: method() { state_machine.set_trigger("attack"); }
    on_death :: method() { state_machine.set_trigger("die"); }
}
```

Variable types: `.BOOL`, `.TRIGGER`, `.INT`, `.FLOAT`. Numeric conditions accept a kind: `.GREATER`, `.GREATER_EQUAL`, `.LESS`, `.LESS_EQUAL`, `.EQUAL`.

## Skins

```csl
animator.set_skin("armor_heavy");
animator.refresh_skins(); // REQUIRED after any skin modification

// Combine multiple skins 
animator.disable_all_skins();
animator.enable_skin("base/crewchsia"); // (required when using the streamed character skeleton)
animator.enable_skin("body/alien");
animator.refresh_skins();

skins := animator.get_skins();
```

## Bone Positions

```csl
hand_pos := animator.get_bone_local_position("Hand_R");
```

```csl
layer := animator.state_machine.try_get_layer("main");
if layer != null {
    current := layer.get_current_state();
    running_state := layer.try_get_state("Run_Fast");
}
animator.state_machine.set_trigger("jump");
```

## Color

```csl
// Tint/flash (e.g. damage flash, transparency)
animator.color_multiplier = {brightness, brightness, brightness, 0.25};
```


## Spine_Instance (Standalone for UI)

**You MUST call `destroy()` on Spine_Instance when done -- memory leak otherwise.**

If an API has `create()`, it MUST have a matching `destroy()`. Exception: APIs with a `transfer_ownership` parameter -- passing `true` transfers destroy responsibility to the receiver (e.g. `instance.set_state_machine(sm, true)`).

```csl
Popup :: class {
    spine_asset: Spine_Asset;
    spine_instance: Spine_Instance;

    init :: proc(using this: Popup) {
        spine_asset = get_asset(Spine_Asset, "anims/popup.spine");
        spine_instance = Spine_Instance.create();
        spine_instance.set_skeleton(spine_asset);
    }

    cleanup :: proc(using this: Popup) {
        spine_instance.destroy();  // REQUIRED
    }

    update :: proc(using this: Popup, dt: float) {
        spine_instance.update(dt);  // Manual update required for standalone
    }

    render :: proc(using this: Popup) {
        UI.push_screen_draw_context();
        defer UI.pop_draw_context();
        rect := UI.get_safe_screen_rect();
        // Spine assets authored in world space are ~1-2 units tall.
        // In screen space that's 1-2 pixels, so scale up for UI.
        // In world space, {1,1} is fine.
        scale := v2{100, 100};
        UI.spine(rect.center(), spine_instance, scale, 0.0);
    }
}
```

### Player UI Clone Example (voting screens, PiP displays)
Clones a player to display them in UI, etc...

```csl
player: Player = ...;
player_ui_instance := Spine_Instance.create();
player_ui_instance.set_skeleton(player.animator.get_skeleton());
for skin: player.animator.get_skins() {
    player_ui_instance.enable_skin(skin);
}
player_ui_instance.refresh_skins();
player_ui_instance.set_color_replace_color(player.avatar_color);

// Every frame:
player_ui_instance.update(dt);
UI.spine(UI.get_screen_rect().center(), player_ui_instance, {100, 100});
```

```csl
Color_Replace_Color :: enum {
    NONE; RED; CYAN; GREEN; YELLOW; LIGHT_GREEN; PINK; ORANGE; BLACK;
    PURPLE; LIGHT_GRAY; BLACK2; BLUE2; BROWN1; GREEN3; ORANGE2; PURPLE2;
    PURPLE3; RED2; WHITE1;
}
```


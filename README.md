# Reusable Weapons Pack

A drop-in weapon system with 27 weapons, 6 fire modes, 10 ammo types, and full multiplayer support.

## Setup

### 1. Copy the files into your project

```
scripts/reusable_weapons/   -> your-project/scripts/reusable_weapons/
res/reusable_weapons/       -> your-project/res/reusable_weapons/
```

### 2. Add the import

In your `main.csl`, add:

```csl
import "reusable_weapons"
```

### 3. Add fields to your Player class

```csl
Player :: class : Player_Base {
    health: float;
    max_health: float;
    equipped_weapon_type: Weapon_Type;
    equipped_item_def: Item_Definition;
    last_selected_index: s64;
    boomwheel_cannon: Boomwheel_Cannon; // only needed if using Boomwheel

    ao_start :: method() {
        health = 100.0;
        max_health = 100.0;
        last_selected_index = -1;

        if Game.is_server() {
            init_weapon_items();
        }
        setup_reusable_weapons_player_state_machine(this);
    }
}
```

### 4. Wire up the hotbar and abilities

In your player's `ao_late_update`:

```csl
ao_late_update :: method(dt: float) {
    if is_local_or_server() {
        // Draw fire ability button based on equipped weapon
        if equipped_weapon_type != .NONE {
            config := get_weapon_config(equipped_weapon_type);
            switch config.fire_mode {
                case .CONTINUOUS:  { draw_ability_button(this, Continuous_Fire_Ability, 0); }
                case .SINGLE_SHOT: { draw_ability_button(this, Single_Shot_Ability, 0); }
                case .SPREAD:      { draw_ability_button(this, Spread_Shot_Ability, 0); }
                case .LOBBED:      { draw_ability_button(this, Lobbed_Shot_Ability, 0); }
                case .BEAM:        { draw_ability_button(this, Beam_Ability, 0); }
                case .SPECIAL:     { draw_ability_button(this, Special_Ability, 0); }
            }
            draw_ability_button(this, Melee_Ability, 1); // optional melee
        }

        // Draw hotbar and handle equip/unequip
        options := Inventory_Draw_Options.default();
        hotbar := Items.draw_hotbar(this, default_inventory, options);
        handle_equipped_item_changing(hotbar.selected_item_index);
    }

    if !Game.is_server() {
        draw_health_bar(this); // from weapons_ui_helpers.csl
    }
}
```

### 5. Copy the `handle_equipped_item_changing` method

Add the method from `main.csl` into your Player class. It handles detecting hotbar selection changes and calling `weapon_equip` / `weapon_unequip`.

## Giving weapons to players

```csl
// Give a single weapon
give_weapon(.ASSAULT_RIFLE, player.default_inventory);

// Give ammo
info := get_ammo_info(0); // 0 = AR ammo index
ammo := Items.create_item_instance(g_ammo_item_defs[0], info.stack_size);
Items.move_item_to_inventory(ammo, player.default_inventory);
```

See `weapon_items.csl` for all ammo type indices (0-9).

## Key files you'll want to change

| File | What's in it | Why you'd change it |
|---|---|---|
| `weapon_config.csl` | Damage, fire rate, speed, AOE radius for every weapon | **Balancing** - all stats are here |
| `weapon_items.csl` | Item definitions, ammo types, stack sizes, icons | Adding/removing weapons or ammo types |
| `weapon_types.csl` | `Weapon_Type` and `Fire_Mode` enums | Adding new weapon or fire mode variants |
| `weapon_animations.csl` | Player state machine setup (IK, additive layer) | Custom animation states or layers |
| `weapons_ui_helpers.csl` | Health bar drawing | Replacing with your own health UI |

## Weapons reference

| Weapon | Fire Mode | Damage | Fire Rate | Notes |
|---|---|---|---|---|
| Assault Rifle | Continuous | 8 | 0.2s | |
| Submachine Gun | Continuous | 5 | 0.15s | |
| Gatling Gun | Continuous | 3 | 0.1s | Fastest fire rate |
| Beam Machine | Continuous | 12 | 0.5s | Piercing projectiles |
| Water Gun | Continuous | 10 | 0.3s | |
| Missile Barrage | Continuous | 25 | 0.3s | Homing projectiles |
| Blunderbuss | Single Shot | 30 | 2.0s | |
| Ray Gun | Single Shot | 50 | 2.0s | |
| Plasma Burst | Single Shot | 30 | 2.0s | Projectile grows over time |
| Mega Blade | Single Shot | 30 | 2.0s | Bounces 10 times |
| Buzzshot | Single Shot | 30 | 2.0s | Bounces 30 times |
| Hydro Cannon | Single Shot | 10 | 3.0s | |
| Explosive Shotgun | Spread | 15 | 2.0s | 10 AOE damage |
| Sunny Side Shotty | Spread | 15 | 2.0s | 15 AOE, 5 projectiles |
| Golden Rocket Launcher | Lobbed | 100 | 5.0s | 100 AOE damage |
| Water Balloon RPG | Lobbed | 100 | 5.0s | 100 AOE damage |
| Poison Grenade | Lobbed | 25 | 2.5s | No ammo cost |
| Boomwheel | Lobbed | 100 | 5.0s | Custom cannon mechanic |
| Fire Ray | Beam | 8 | 0.5s | 6 unit range |
| Ice Launcher | Beam | 5 | 0.5s | 6 unit range |
| Glaciator | Beam | 5 | 0.5s | 6 unit range |
| Solar Siphoner | Beam | 10 | 1.0s | Heals 5 hp/tick |
| Octo Siphoner | Beam | 5 | 1.0s | Heals 3 hp/tick |
| Void Splitter | Beam | 30 | 0.5s | 8 unit range, 2 ammo/shot |
| Akimbo Pistols | Special | 20 | 0.6s | |
| Wind Blaster | Special | 3 | 5.0s | 2.0 AOE radius |
| Storm's Eye | Special | 10 | 3.0s | 2.5 AOE radius |

## Adding a new weapon

1. Add a variant to `Weapon_Type` in `weapon_types.csl`
2. Add its config in `get_weapon_config()` in `weapon_config.csl`
3. Add its index mapping in `weapon_type_to_index()` in `weapon_items.csl`
4. Add its item definition in `init_weapon_items()` in `weapon_items.csl`
5. Add firing logic in the matching ability file (or create a new one for a new fire mode)
6. Create a projectile prefab in `res/reusable_weapons/`

## Notes

- **Animations**: `setup_reusable_weapons_player_state_machine()` adds an additive animation layer to the player. If you have your own state machine setup, you may need to merge the two — check `weapon_animations.csl`.
- **Health**: The system uses `player.health` and `player.max_health` fields directly. If you have your own health system, search for those references and swap them.

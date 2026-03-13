# Reusable Weapons Pack

A drop-in weapon system just for you with 27 weapons, 6 fire modes, and 10 ammo types! :D 

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
    weapon_target: Weapon_Target;
    equipped_weapon_type: Weapon_Type;
    equipped_item_def: Item_Definition;
    last_selected_index: s64;
    boomwheel_cannon: Boomwheel_Cannon; // only needed if using Boomwheel

    ao_start :: method() {
        wt := entity->add_component(Weapon_Target);
        wt.health = 100.0;
        wt.max_health = 100.0;
        wt.owner_entity_id = entity.id;
        weapon_target = wt;

        last_selected_index = -1;

        init_weapon_items();
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

### 6. Update your scene.config file to set the default_player_rig to the reusable weapons one:
```json
{
  "default_player_rig": "reusable_weapons/anims/reusable-weapons/player/player.merged_spine_rig#output"
}
```

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

## Making custom entities damageable by weapons

The weapons system uses a `Weapon_Target` component for all hit detection. Any entity with a `Weapon_Target` can be hit by any weapon — players, mobs, destructibles, bosses, etc.

### Basic usage

Add a `Weapon_Target` component to any entity you want weapons to hit:

```csl
My_Mob :: class : Component {
    ao_start :: method() {
        target := entity->add_component(Weapon_Target);
        target.health = 50.0;
        target.max_health = 50.0;
        // That's it — all weapons now hit this entity
    }

    ao_update :: method(dt: float) {
        target := entity->get_component(Weapon_Target);
        if target.health <= 0 {
            // Handle death
            entity->destroy();
        }
    }
}
```

### Reacting to damage

Set the `on_damaged` callback to run custom logic when hit (death animations, loot drops, knockback, etc.):

```csl
My_Mob :: class : Component {
    ao_start :: method() {
        target := entity->add_component(Weapon_Target);
        target.health = 50.0;
        target.max_health = 50.0;
        target.on_damaged_userdata = this;
        target.on_damaged = proc(target: Weapon_Target, damage: float, attacker_id: u64, userdata: Object) {
            mob := userdata.(My_Mob);
            if target.health <= 0 {
                // Spawn loot, play death animation, etc.
                target.entity->destroy();
            }
        };
    }
}
```

### Friendly-fire exclusion

The `owner_entity_id` field prevents weapons from hitting their own source entity. For the player this is set automatically. For entities owned by a player (turrets, pets), set it to the player's entity ID:

```csl
target := turret_entity->add_component(Weapon_Target);
target.health = 200.0;
target.max_health = 200.0;
target.owner_entity_id = player.entity.id; // player's weapons won't hit their own turret
```

### Weapon_Target fields

| Field | Type | Description |
|---|---|---|
| `health` | `float` | Current health |
| `max_health` | `float` | Maximum health |
| `owner_entity_id` | `u64` | Entity ID of the owner (for self-hit exclusion) |
| `on_damaged` | `proc` | Callback fired after damage is applied |
| `on_damaged_userdata` | `Object` | Userdata passed to the callback |

### Reading health from the Player

Player health now lives on the `Weapon_Target` component. Access it via the `weapon_target` field:

```csl
// Reading player health
current_hp := player.weapon_target.health;
max_hp := player.weapon_target.max_health;

// Healing the player
player.weapon_target.health += 10.0;
if player.weapon_target.health > player.weapon_target.max_health {
    player.weapon_target.health = player.weapon_target.max_health;
}
```

## Notes

- **Animations**: `setup_reusable_weapons_player_state_machine()` adds an additive animation layer to the player. If you have your own state machine setup, you may need to merge the two — check `weapon_animations.csl`.
- **Health**: Player health lives on the `Weapon_Target` component, accessed via `player.weapon_target.health` and `player.weapon_target.max_health`.

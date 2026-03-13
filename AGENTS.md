You will be developing a multiplayer game in a custom scripting language (.csl)

## Networking

> **NEVER wrap gameplay logic in `Game.is_server()`.** The engine uses client-side prediction with automatic server reconciliation. Gameplay code **must** run on both client and server for smooth behavior.

- All gameplay state is automatically synced. You do not need to write RPCs or manually replicate state.
- The client runs the same gameplay code as the server and predicts outcomes immediately. The server's authoritative result is reconciled automatically — you get correctness **and** responsiveness for free, but **only if the code runs on both sides**.
- Do not forget that **multiple players will be connecting**. Avoid global state that will break with multiple players. Store these as fields on the player.

### is_local_or_server() vs is_local()
```csl
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        // Use for gameplay UI and inputs (runs on server + local client only, 
        // skips remote clients who don't need this player's UI/input)
        if is_local_or_server() {
            draw_ability_button(this, Shoot_Ability, 0);
        }
        
        // Use for purely cosmetic/local-only effects (runs only on local client, rarely used since gameplay code should run on both)
        if is_local() {
            UI.text(..., "Waiting for host to start the game...");
            // Particle effects, cosmetic UI, etc.
            // These don't need to run on the server—it's wasteful
        }
    }
}
```

## Imports
All imports go in main.csl only. You only need to import folders you create, not individual scripts.
```csl
// main.csl
import "core:ao"
import "ui" // add folder imports here if needed
```

## Assets/Resources
Find assets with the MCP: 
asset_local_search (query: "tree")

- When referencing assets use <path>.<ext>, omit /res from the path. 
- Engine assets are available with the $AO prefix.
- Check that assets actually exist before using. 

### Available Asset Types
```csl
texture := get_asset(Texture_Asset, "ui/button.png");
sound := get_asset(SFX_Asset, "sfx/click.wav");
spine := get_asset(Spine_Asset, "anims/dog/dog.spine");
```

## Entities
Most entities should be placed in the scene using the mcp. 

Use scripts to add entities that must be dynamically spawned (like towers or waves of enemies in a tower defense game)
```csl
entity := Scene.create_entity();
entity->set_local_position({10, 20});
entity->set_local_scale({2.5, 2.5});
entity->set_local_rotation(0);

my_comp := entity->add_component(My_Component);
other := entity->get_component(Other_Component);

entity->destroy();
```

#### Iterating Entities

```csl
foreach entity: entity_iterator() {
}
```

## Components

### Out-of-the-box components
#### Sprite_Renderer
```csl
sprite := entity->get_component(Sprite_Renderer);
sprite->set_texture(texture);
sprite.color = {1, 1, 1, 1}; // RGBA
sprite.depth_offset = 0.5;
sprite.layer = 10;
```

#### Prefab_Asset
```csl
prefab_asset := get_asset(Prefab_Asset, "MyPrefab.prefab");
entity := instantiate(prefab_asset);
```

#### Spine_Animator
Reference the spine skill when working with Spine_Animators 

### Creating Custom Components
> Make new components in dedicated files. You do not need to import them unless they're in a separate folder. 

Can override these lifecycle methods:

- ao_start
- ao_update
- ao_late_update - After all updates
- ao_end - When component is destroyed
```csl
// orbiter.csl
Orbiter :: class : Component {
    center: v2;
    radius: float;
    speed: float;
    angle: float;
    
    ao_start :: method() {
        center = entity.local_position;
        radius = 2.0;
        speed = 1.0;
        angle = 0.0;
    }
    
    ao_update :: method(dt: float) {
        angle += speed * dt;
        
        offset_x := cos(angle) * radius;
        offset_y := sin(angle) * radius;
        
        new_pos := v2{center.x + offset_x, center.y + offset_y};
        entity->set_local_position(new_pos);
    }
}
```
> You can add components you've made to entities in the scene using the modify_scene tool. 

#### Iterating Components

```csl
foreach player: component_iterator(My_Player) {
}
```

#### Finding components close to the player
> csl does not have collision callbacks instead get components near them and check distance
```csl
nearby: [..]Enemy;
Scene.get_all_components_in_range(player_pos, 5.0, ref nearby);

closest, found := Scene.get_closest_component_in_range(player_pos, 2.0, Pickup);
```

## Random Generators
```csl
rng: u64 = rng_seed(entity.id);
// or
rng: u64 = rng_root_seed();

// Pass seed using ref. Range values are inclusive.
random_float := rng_range_float(ref rng, 0, 1);
random_int := rng_range_int(ref rng, 1, 10);
```

## String Formatting
```csl
format_string("Value: %", {42});
format_string("health: 100%%");

hp := 67;
// %0 as alias for % when you want either multiple args next to eachother ("%0%") or an arg then a percent literal ("%0%%")
format_string("health: %0%%", {hp}); // health: 67%

// Use Format_Float wrapper struct for decimal rounding
value := 3.14159;
format_string("pi: %", {format_float(value, decimals=2)}); // "pi: 3.14"
```

my_str.count gets length 

## Time

```csl
current_time := get_time(); // Float seconds since game start
frame := get_frame_number();
```

## SFX
```csl
desc := SFX.default_sfx_desc();
desc.entity_to_follow = entity.id;
desc.delay = 0.25;
sound_id := SFX.play(sound_asset, desc);

SFX.stop(sound_id);
```

## Economy
> Automatically persists currencies (cash, points, etc...)
```csl
Economy.register_currency("Coins", coin_texture_asset);

balance := Economy.get_balance(player, "Coins");

Economy.deposit_currency(player, "Coins", 100);

// Remove currency, checking that they have enough to do so. 
COST :: 50;
if Economy.can_withdraw_currency(player, "Coins", COST) {
    Economy.withdraw_currency(player, "Coins", COST);
}
```

## Math Functions
`sin`, `cos`, `pow`, `sqrt`, `lerp`, `clamp`, `abs`, `min`, `max`, `length`, `length_squared`, `normalize` there are no other math functions. 

### Player_Base Reference
- p->get_username()
- p->get_user_id() -> string
- p.avatar_color -> Color_Replace_Color 
- p.device_kind -> .PHONE, .TABLET, .PC 
- p->add_freeze_reason(reason: string)
- p->add_invisibility_reason(reason: string)

### Serialized fields
Use `@ao_serialize` to expose a field to the user in the editor. 

## Best Practices
- Do not hallucinate syntax from other languages. Use skills to keep up on syntax and APIs.
- These games are mobile-first, don't rely on keyboard input. 
- Logging: `log_info("Name: %, age: %", {get_name(), get_age()});`
- CSL does not have closures, if needed add a `userdata: Object` field alongside the callbacks. Any class instance can be stored in an `Object` variable and cast back to its original type.

After you make script changes, run the All Out MCP compile tool.
When the prompt requires building a game world, prefer doing so using the allout MCP scene editing tools instead of scripts. 

To add weapons to your game clone the https://github.com/All-Out-Games/reusable-weapons-csl.git repo with curl/https and follow the README. 
---
name: navmeshes-and-collision
description: Reference this when implementing pathfinding, Movement_Agent movement collision, collider trigger callbacks for traps/teleporters/pickups, or navmesh-based spawning.
---
# CSL Navmesh System

## Components
- **Navmesh** -- Main navigation mesh container. Handles triangulation, pathfinding, and closest-point queries.
- **Navmesh_Loop** -- Defines walkable area boundaries as polygons. Can be flipped inside-out to create holes/obstacles. Automatically updates parent navmesh.
- **Movement_Agent** -- Entity movement with navmesh pathfinding, simple collider movement, and trigger detection.
- **Colliders** -- `Box_Collider`, `Circle_Collider`, `Polygon_Collider`, and `Edge_Collider` can block Movement_Agent movement or act as trigger volumes.

## Editor Setup
1. Create an entity with a `Navmesh` component
2. Create child entities with `Navmesh_Loop` components to define walkable areas
3. For each `Navmesh_Loop`: add points for the polygon shape; set `Flip Inside Outside` to true for obstacles/holes
4. Colliders can contribute to navmesh loops via `Make Navmesh Loop` and `Flip Navmesh Loop` in inspector. Navmeshes automatically hash loop/collider/tilemap inputs each frame and rebuild when those inputs change.
   - Disable collider contribution with Navmesh `Ignore Colliders` = true
5. Use Navmesh `Debug Enabled` and `Debug Rebuild Every Frame` to visualize

## Code API

### Finding Closest Point on Navmesh

```csl
point: v2 = {10, 10};
result: v2;
triangle_hint: s64; // 0 = not set; reuse for repeated nearby queries for speed

if navmesh.try_find_closest_point_on_navmesh(point, ref result, ref triangle_hint) {
    spawn_entity.set_local_position(result);
}
```

### Pathfinding with Movement_Agent

```csl
agent.agent_radius = 0.5; // pathfinding clearance radius
result := agent.set_path_target(target, speed);

if result.success {
    // result.next_point - next waypoint
    // result.move_direction - normalized direction
    if result.move_direction.x > 0.01 { sprite.flip_x = false; }
    else if result.move_direction.x < -0.01 { sprite.flip_x = true; }
}
```

**`set_path_target` is processed later in the frame in parallel with other agents, so the first frame you set a new target will NOT return `success == true`.**

`agent_radius` controls pathfinding clearance. Increase it when an agent should route wider around corners or stay farther from navmesh edges. To fully avoid walls during actual movement, the agent should also have a collider, usually a `Circle_Collider`, with a matching radius.

### Locking Movement to a Navmesh

```csl
agent.set_navmesh_to_lock_to(navmesh); // constrains agent to navmesh each frame
agent.set_navmesh_to_lock_to(null); // clear constraint
```

### Movement_Agent Properties

```csl
agent.movement_speed = 300.0; // 300 is the default player speed
agent.friction = 0.5;
current_velocity := agent.velocity; // read-only
input := agent.input_this_frame; // read-only
```

### CSL Movement Physics and Triggers

Movement_Agent entities have a CSL physics path for simple ballistic movement and/or trigger detection.

Rigidbody collision: the agent's enabled non-trigger colliders block against enabled non-trigger world colliders, taking `category_bits` / `mask_bits` filtering into account. Movement stops at the first hit and slides along the hit surface.

Trigger overlap detection: if a collider has `is_trigger == true`, it can report when another collider enters, stays inside, or exits its bounds.

```csl
Trigger_Listener :: class : Component {
    ao_start :: method() {
        trigger_collider := entity.get_component(Circle_Collider); // any collider type works, as long as `is_trigger` is true
        trigger_collider.on_trigger_start = proc(self: Collider, other: Collider) {
            log("OVERLAP START: %", {other.entity.get_name()});
        };

        trigger_collider.on_trigger_stay = proc(self: Collider, other: Collider) {
            log("OVERLAP STAY: %", {other.entity.get_name()});
        };

        trigger_collider.on_trigger_end = proc(self: Collider, other: Collider) {
            log("OVERLAP END: %", {other.entity.get_name()});
        };
    }
}
```

Movement_Agent has velocity/friction fields but you do not have to use them. For a stationary trap, teleporter, pickup zone, or similar trigger volume, add a Movement_Agent and a trigger collider to the entity and assign trigger callbacks.

### Forcing Navmesh Rebuild

- **`rebuild_immediately()`** -- Immediate rebuild. Use only when you need to query the updated navmesh in the same frame. Returns success bool.

Most input changes rebuild automatically. Force a rebuild only when you need to query the updated navmesh immediately in the same frame.

### Parent/Child Navmesh Setup

```
Parent Entity (Navmesh)
+-- Child Entity 1 (Navmesh)
|   +-- Navmesh_Loop
+-- Child Entity 2 (Navmesh)
|   +-- Navmesh_Loop
+-- Child Entity 3 (Navmesh)
    +-- Navmesh_Loop
```

Parent rebuild collects all child navmesh points and creates a unified navigation mesh with cross-boundary neighbor relationships.

**Critical gotchas:**
- **Nested navmeshes refresh child-first** -- parent navmeshes automatically pick up child mesh input changes.
- **Query the parent navmesh for pathfinding** -- child navmeshes only contain their local area.
- **Set `IgnoreColliders` to true on parent navmeshes** -- prevents redundant work since children already process colliders.

## NPC Pathfinding Example

```csl
NPC :: class : Component {
    agent: Movement_Agent @ao_serialize;
    target: Entity;

    ao_update :: method(dt: float) {
        if !#alive(target) return; // #alive checks entity validity
        result := agent.set_path_target(target.world_position, agent.movement_speed);
    }
}
```

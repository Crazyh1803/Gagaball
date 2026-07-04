# Gaga Pit Showdown (working title)

A retro 8-bit arcade take on Gaga Ball for Android, inspired by NES *Super
Dodge Ball*. Built with **Godot 4.x** (GDScript), 100% free to play.

## Current status — iteration 1: core physics & movement

This iteration lays the physics/movement foundation:

- **Octagonal pit** — `Arena.gd` generates the 8 wall segments at runtime
  (thick rectangles with overlapped corners so the ball can't tunnel through
  a joint). Wall geometry is driven by exports (`pit_radius`, `pit_sides`,
  `wall_thickness`) so campaign stages can reshape the pit later.
- **Elastic ball** — `Ball.gd` is a `RigidBody2D` with `bounce = 1.0` /
  `friction = 0.0` on *both* the ball and the walls, so wall rebounds lose no
  energy regardless of Godot's material-combine rule. `linear_damp` alone
  slows the ball; `max_speed` is clamped inside `_integrate_forces()`.
  The ball tracks `last_touched_by` and emits `wall_bounced` /
  `character_touched` — the hooks the double-touch rule will consume.
- **8-way movement** — `Character.gd` (`CharacterBody2D`, floating motion
  mode) owns acceleration/deceleration movement and an 8-way `facing`
  direction (future slap aim). Subclasses override `get_move_input()`:
  `PlayerCharacter.gd` reads the input map; the future `AI_Controller.gd`
  will return steering decisions. Characters nudge the ball by walking into
  it (`push_force`).
- **Below-the-waist hurtbox** — each character has a `LowerHurtbox` Area2D
  that senses only the ball and emits `ball_contact_below_waist`. The
  elimination rule (later iteration) just listens to that signal.

### Collision layers

| # | Name       | Used by                              |
|---|------------|--------------------------------------|
| 1 | walls      | Runtime-built pit `StaticBody2D`s    |
| 2 | ball       | `Ball.tscn`                          |
| 3 | characters | `Character.tscn` bodies              |
| 4 | hurtboxes  | `LowerHurtbox` sensors               |

Shared constants live in `Scripts/CollisionLayers.gd`.

## How to test

1. Open the project in **Godot 4.3+** and press Play — `GameArena.tscn` is
   the main scene. The ball drops at center with a random opening bounce and
   caroms elastically around the pit.
2. Move with **WASD / arrow keys** (temporary stand-in for the virtual
   joystick — the joystick will emit the same input actions later). Walk into
   the ball to nudge it; walls block you.
3. **Space** (`strike`) and **Shift** (`dash`) are mapped but intentionally
   do nothing yet — next iteration.

## Project layout

```
Assets/
  Sprites/          # pixel art (placeholder _draw() graphics for now)
  Audio/            # chiptune + SFX (later)
Scenes/
  GameArena.tscn    # the pit, ball, player, camera
  Ball.tscn         # RigidBody2D gaga ball
  Character.tscn    # base body: movement collider + lower hurtbox
  Player.tscn       # Character with PlayerCharacter.gd
Scripts/
  Arena.gd          # builds the octagon, drops the ball
  Ball.gd           # elastic physics, touch tracking
  Character.gd      # base 8-way movement + facing + hurtbox signal
  PlayerCharacter.gd# input-map-driven Character
  CollisionLayers.gd# shared layer constants
  GameState.gd      # autoload stub (campaign unlocks/stats later)
```

## Roadmap (per PRD)

- Strike/slap (tap) + charged Power Slap (hold & release), dash/jump
- Double-touch rule + below-waist elimination + out-of-bounds
- Virtual joystick + touch buttons (Android)
- `AI_Controller.gd` state machine (Easy/Medium/Hard)
- Friendly Match (4/6/8-player FFA) and the 10-stage **USA Pit Tour** campaign
- Main menu, settings with "Support the Dev" link
  (https://buymeacoffee.com/appsbydan), retro UI, screenshake & juice

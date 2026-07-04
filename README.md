# Gaga Pit Showdown (working title)

A retro 8-bit arcade take on Gaga Ball for Android, inspired by NES *Super
Dodge Ball*. Built with **Godot 4.x** (GDScript), 100% free to play.

## Current status — iterations 1–2: physics, movement, strike & dash

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
- **Strike & Power Slap** — one context-aware button: tap for a slap along
  `facing`, hold to charge (a wind-up ring fills over the character, movement
  slows) and release for a Power Slap up to `power_slap_speed`. The strike
  connects when the ball is inside the `StrikeZone` Area2D; whiffs are
  harmless. `struck_ball(ball, power)` is the future screenshake/SFX hook.
- **Dash** — a short burst in the current move direction (or `facing` when
  standing), with a cooldown. `is_dashing()` is exposed for the future
  "leap over low balls" rule.
- **Double-touch tracking** — the ball records `repeat_toucher`, cleared by
  wall bounces and replaced when someone else touches it. Enforcement
  (elimination) comes with the rules iteration; the data is already correct.

### Collision layers

| # | Name       | Used by                              |
|---|------------|--------------------------------------|
| 1 | walls      | Runtime-built pit `StaticBody2D`s    |
| 2 | ball       | `Ball.tscn`                          |
| 3 | characters | `Character.tscn` bodies              |
| 4 | hurtboxes  | `LowerHurtbox` sensors               |

Shared constants live in `Scripts/CollisionLayers.gd`.

## How to test

### In the editor (desktop)

1. Open the project in **Godot 4.3+** and press Play — `GameArena.tscn` is
   the main scene. The ball drops at center with a random opening bounce and
   caroms elastically around the pit.
2. Move with **WASD / arrow keys**, or click-drag the left half of the window
   to use the touch joystick (mouse emulates touch in this project). Walk
   into the ball to nudge it; walls block you.
3. **Space** — tap to slap the ball in your facing direction when it's in
   reach; hold to charge and release for a Power Slap.
4. **Shift** — dash.

### On an Android device

Touch a finger down anywhere on the **left half of the screen** to summon the
floating joystick and move. On the right: the big **SLAP** button (tap or
hold-release to charge) and the **DASH** button above it.

## Exporting to Android

An `Android` export preset is committed in `export_presets.cfg` (arm64-v8a,
landscape, immersive mode, package `com.appsbydan.gagapitshowdown`; it
contains no secrets — keystores stay local and are gitignored).

One-time setup on your machine:

1. In the Godot editor: **Editor → Manage Export Templates → Download**.
2. Install Android Studio (or just the SDK command-line tools) and a JDK,
   then point Godot at them in **Editor → Editor Settings → Export → Android**.
   Godot auto-generates a debug keystore for you.
3. **Project → Export → Android → Export Project** (or use one-click deploy —
   the Android icon in the top-right of the editor — with a device connected
   over USB debugging).

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
  VirtualJoystick.gd# floating touch stick (feeds the move_* actions)
  TouchActionButton.gd # round SLAP/DASH buttons (feed strike/dash actions)
  CollisionLayers.gd# shared layer constants
  GameState.gd      # autoload stub (campaign unlocks/stats later)
export_presets.cfg  # Android export preset (no secrets)
```

## Roadmap (per PRD)

- Double-touch rule enforcement + below-waist elimination + out-of-bounds
- Curved-trajectory Power Slap variants (Super Dodge Ball specials)
- `AI_Controller.gd` state machine (Easy/Medium/Hard)
- Friendly Match (4/6/8-player FFA) and the 10-stage **USA Pit Tour** campaign
- Main menu, settings with "Support the Dev" link
  (https://buymeacoffee.com/appsbydan), retro UI, screenshake & juice

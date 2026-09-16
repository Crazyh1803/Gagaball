# Gaga Pit Showdown

A top-down, pixel-art arcade take on Gaga Ball built in Godot 4.3+.
One human, CPU opponents, an octagonal pit, and a last-one-standing round.

## Open the right project

Open **`project.godot` at the repository root**, not `gagaball/project.godot`.
The nested folder is a separate empty Godot project and is intentionally
left untouched. The root project contains the scenes, assets, input map,
and GameState autoload. Press F5, then **Jump Into the Pit** for quick play.

The desktop revival was checked with the locally installed **Godot 4.6.1**.
The Compatibility renderer is used for broader desktop/mobile support.

## How to play

- **WASD / arrows:** move; the last movement direction aims your slap.
- **Mouse movement:** switch to precise pointer aim. Press a movement key
  again to return to movement-based aim.
- **Space / left click:** tap to slap; hold and release for a power slap.
- **Shift:** dash through an incoming ball. Dashing grants temporary hit
  immunity, but the cooldown means you cannot evade continuously.
- **Escape / Pause:** pause, resume, restart, or return to the menu.
- On mobile, use the left floating joystick and right SLAP / DASH buttons.
  Touch controls are hidden on desktop.

Slap when the ball is within 70 pixels of your feet. A short swing window
lets a slightly early tap connect; the arc shows the outgoing direction.
Charge slows your movement and fills a ring above your head. A ring around
your feet and the HUD show dash recharge.

A fast ball hitting your feet knocks you out. Orange means the ball is
dangerous; mint means it is a harmless slow roll. Your own slap cannot
eliminate you until the ball rebounds from a wall or another fighter slaps
it. You cannot slap twice consecutively without either event: **DOUBLE!**
means the attempt was blocked.

Every fighter is an individual. There are no teams: Easy, Medium, and Hard
CPUs all choose among every surviving opponent, including other CPUs.
Knockout callouts name both striker and victim so this is visible in play.

A ready countdown freezes the roster before the opening roll. Rounds end
with a results panel, **Rematch**, and **Main Menu**, rather than forcing you
back to the menu. Campaign victories save progress and unlock the next pit.

## Revival changes

The original body-contact bookkeeping could grant immunity to the fighter
being hit before the hurtbox callback ran. The ball now physically collides
with walls only. The referee checks swept ball paths against fighters'
feet, independently of legal-strike ownership and sensor callback order.
Walking into a ball is no longer an automatic nudge or legal touch.

Other changes include:

- Buffered slaps, a strike cooldown, same-frame aiming, and very short tap handling.
- Actual dash evasion, consistent slow-roll safety, and stopped fighters/balls at results.
- CPUs retrieve dying balls, aim shots from the ball position, and have
  difficulty-based reactions and fallible defensive reads instead of perfect saves.
- Free-for-all CPU targeting, individual fighter names, and credited knockouts.
- Original generated 8-bit effects for menus, countdown, slaps, wall rebounds,
  double-touch warnings, knockouts, and victory.
- A new neighborhood schoolyard backdrop, court markings, and individual
  outfit details in the character palettes.
- Quick play, a refreshed menu theme, ball trails/danger outlines, aim and
  charge indicators, remaining-player count, and pause/rematch controls.
- Touch inputs are released on scene exit and cleared when pausing.

## Modes

**USA Pit Tour:** ten venues, increasingly difficult opponents, saved
unlocks, surface-specific ball drag, and Baltimore's second-ball event.

**Custom Match:** four, six, or eight fighters at Easy, Medium, or Hard CPU
difficulty, in a randomly selected venue.

## Verification

Run the real scene/physics integration suite:

```powershell
& "D:\Users\dwhit\Downloads\Godot_v4.6.1-stable_win64.exe" --headless --path . --script res://tools/test_gameplay.gd
```

On Windows, use `Start-Process -Wait` if your GUI Godot executable returns
before it finishes. Substitute your own Godot executable path as needed.

Tests cover the ready phase, real input taps, slaps/charging/buffering,
double-touch, wall resets, dash immunity, harmless rolls, swept knockouts,
pause/resume, round results, menu setup, and live 4/6/8-player matches.
The suite exits nonzero on failure and includes a timeout guard.

The dedicated AI soak test proves that CPUs legally target and eliminate
one another in a live match:

```powershell
& "D:\Users\dwhit\Downloads\Godot_v4.6.1-stable_win64.exe" --headless --path . --script res://tools/test_free_for_all.gd
```

Rendered preview capture (run **without** `--headless`):

```text
godot --path . --script res://tools/capture_preview.gd
godot --path . --script res://tools/capture_preview.gd -- --arena
godot --path . --script res://tools/capture_preview.gd -- --campaign
godot --path . --script res://tools/capture_preview.gd -- --arena --pause
```

PNGs are saved under the ignored `.godot/` directory. Android touch
behavior/export still needs verification on an actual device; desktop
tests are not a substitute for that.

## Art and project layout

`tools/generate_art.py` generates the 8×3 character sheets, ball sprite,
and stage ground tiles. `tools/generate_audio.py` generates the original
chip-style WAV effects. The image-generated schoolyard plate and its exact
prompt live together under `Assets/Backgrounds/`. `tools/preview_arena.py` creates
an offline arena mockup. The runtime preview above captures the actual game.

- `Scenes/`: menu, arena, ball, player, and CPU scenes.
- `Scripts/`: shared fighter mechanics, ball physics, referee/UI,
  CPU decisions, input controls, menu theme, and saved campaign state.
- `Assets/`: existing generated pixel art and textures.
- `tools/`: art generation, rendered previews, gameplay integration checks.

## Android export

`export_presets.cfg` includes a landscape Android preset for
`com.appsbydan.gagapitshowdown`. Install matching Godot export templates,
an Android SDK, and a JDK, then configure them in Godot's export settings.
Keep signing credentials local. Export from the root project.

## Still unfinished

Looping music, richer bosses, multi-round match scoring,
out-of-bounds/ball height, and special curved shots remain future work.
This pass restores the playable foundation; it does not implement those
features or claim device-tested Android support.

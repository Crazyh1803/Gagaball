# Gaga Pit Showdown

A three-quarter-view, pixel-art arcade take on Gaga Ball built in Godot 4.3+.
One human, CPU opponents, an octagonal pit, and a last-one-standing round.

## Open the right project

Open **`project.godot` at the repository root**. The obsolete nested
`gagaball/project.godot` marker has been removed so Godot no longer reports
a second project during filesystem scans. The root project contains the
scenes, assets, input map, and GameState autoload. Press F5, then
**Jump Into the Pit** for quick play.

The current character-creator/tour build is verified with **Godot 4.3 stable**.
Use that version for this checkout. The Compatibility renderer is used for
broader desktop/mobile support; avoid mixing editor versions and import caches.

If Godot reports repeated **Safe save failed** messages while importing, close
every editor and running game for this project, remove the root `.godot`
directory, and reopen the project in one Godot version. `.godot` is ignored by
Git and is rebuilt automatically; do not disable safe saves as the first fix.

## How to play

- **WASD / arrows:** move; the last movement direction aims your slap.
- **Mouse movement:** switch to precise pointer aim. Press a movement key
  again to return to movement-based aim.
- **Space / left click:** tap to slap; hold and release for a power slap.
- **Shift:** dash through an incoming ball. Dashing grants temporary hit
  immunity, but the cooldown means you cannot evade continuously.
- **J / E:** jump. A 0.62-second arc clears the ball in midair; takeoff and
  landing remain vulnerable. A 0.95-second cooldown prevents endless hopping.
  You cannot slap the grounded ball or start a dash while jumping.
- **C:** tap within reach to trap an incoming ball or steal another fighter's
  dribble. The 0.18-second action window forgives a slightly early tap. Once
  trapped, the ball dribbles automatically for up to 1.6 seconds; slap to shoot,
  tap C again to drop it, or jump/dash to release it.
- **Escape / Pause:** pause, resume, restart, or return to the menu.
- **PC controller:** left stick / D-pad moves, right stick aims, X / RB slaps
  (hold to charge), A jumps, B dashes, Y traps/steals, Start pauses. These are Xbox-style
  labels; the equivalent PlayStation face buttons are Square, Cross, Circle.
  Menus support directional navigation, A to confirm and B to go back.
- **Android touch:** floating left stick plus independent SLAP, JUMP, DASH and TRAP
  buttons. Multiple fingers can steer and act simultaneously. Short taps
  are buffered; pausing, leaving a button, or exiting releases held touches.
  Touch controls appear automatically on mobile (`--touch` previews them on PC).
- Losing application focus or disconnecting a controller pauses the match.

Slap when the ball is within 70 pixels of your feet. A short swing window
lets a slightly early tap connect; the arc shows the outgoing direction.
Charge slows your movement and fills a ring above your head. A ring around
your feet and the HUD show dash recharge.

Legal ball contacts produce an oversized comic palm, impact burst and
SLAP! / SMAAACK! callout. Whiffs and illegal double-touches do not get a hit
effect. Eliminations produce a WHUMP!, a backwards tumble and landing bounce;
the results panel waits briefly so the final fall stays visible.

A fast ball hitting your feet knocks you out. Orange means the ball is
dangerous; mint means it is a harmless slow roll. Your own slap cannot
eliminate you until the ball rebounds from a wall or another fighter slaps
it. You cannot slap twice consecutively without either event: **DOUBLE!**
means the attempt was blocked.

Every fighter is an individual. There are no teams: Easy, Medium, and Hard
CPUs all choose among every surviving opponent, including other CPUs.
Knockout callouts name both striker and victim so this is visible in play.

A ready countdown freezes the roster while the home representative throws the
ball overhead toward a safe random direction. A short opening grace prevents
the thrower from being eliminated before play begins. Rounds end
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
- Original layered stereo arcade effects for menus, countdown, throws, dribbles,
  steals, jumps, slaps, wall rebounds, double-touch warnings, knockouts and victory.
  A subtle room bus gives impacts depth without washing out their comic attack.
- Five original 16-bit-era music loops—Schoolyard Sprint, County Line Clash,
  Capital Circuit, City Lights and World Final—rotate deterministically by map.
- Ten original city-specific stage backgrounds, a foreshortened court that
  shares their three-quarter perspective, and larger, more readable fighters.
- A heavily foreshortened, perspective-tapered ground plane with waist-high
  rear boards, a low front cutaway, and pavement-anchored contact shadows.
- A widened playable pit anchored in the foreground courtyard so no wall or
  floor is composited across buildings, roofs, or background trees.
- Distinct wall palettes and subtle court tints for every city, while the
  stage artwork's brick, asphalt, sand, or courtyard paving remains visible.
- A Wiesbaden opener at Aukamm Elementary, followed by Topeka, Houston,
  Maine, Humboldt, Baltimore, Phoenix, Boston, Chicago, and Orlando.
- Quick play, a refreshed menu theme, ball trails/danger outlines, aim and
  charge indicators, remaining-player count, and pause/rematch controls.
- Touch inputs are released on scene exit and cleared when pausing.

## Modes

**Pit Leagues:** four promotion/relegation divisions with independent saved
careers for each player slot. Kindergarten visits small cities and county seats
(including Aukamm Elementary); Elementary School visits state capitals; Middle
School visits large American cities; High School tours world capitals across
the inhabited continents. Each city is a best-of-three free-for-all series.
Two round wins clinch early; otherwise round wins, round podium totals and
summed finishing places rank the series. The final city podium receives 3, 2
and 1 league point; everyone else receives zero. At season end the top two clubs
are promoted and the bottom two relegated (except at the top/bottom divisions).
Results automatically continue to the next game or city after four seconds.

**Custom Match:** four, six, or eight fighters at Easy, Medium, or Hard CPU
difficulty, in a randomly selected venue.

**My Players / Create & Equip:** three independent saved slots, each with a
14-character name, 12 plainly named skin shades, 12 hairstyles, six hair
colours, seven eye colours, four body types, four hat options, four facial-hair
options, and six accessory choices (none, glasses, sunglasses, wristbands,
elbow pads, scarf). Body types are cosmetic: every fighter has the same hitbox.
The **Appearance** and **Clothes & Accessories** tabs keep the options readable.
Shirts support solid, two-tone split, contrast shoulders and chest stripe
designs. Primary shirt, secondary shirt/trim, shorts and shoes each have an
independent 16-colour palette. Existing saved outfits migrate automatically;
old shorts/shoes retain their former trim colour. Preview poses and jump
from three directions. Shirt secondary also supplies hat/accessory accents.
**Save & Use** saves and equips the current slot. Switching slots retains
draft edits; **Back / Discard Unsaved** asks before discarding unsaved edits. The equipped
player carries into quick play, custom matches, rematches and every tour city.
Each profile also chooses a home city. Their supporters travel in variants of
the player's clothing palette and occupy the away side, switching to HOME when
the match reaches that player's city.
Players are stored in Godot's `user://players.cfg`, separate from tour unlocks
in `user://save.cfg` (Editor: Project > Open User Data Folder).

### Home rivals

Every venue spawns its own original named rival, marked **HOME**, plus animated
HOME and AWAY spectators outside the collision roster. Local supporters mix
several regional sports palettes—Baltimore includes both orange/black and
purple/black—while avoiding logos and licensed character designs. Supporter
loyalty never creates gameplay teams: the pit remains an individual free-for-all.

| Venue | Home rival | Colour inspiration |
| --- | --- | --- |
| Wiesbaden | Lena | Wehen Wiesbaden red / black |
| Topeka | Bo | Washburn blue / white |
| Houston | Jet | Astros orange / navy |
| Maine Woods | Finn | Black Bears light blue / navy |
| Humboldt | Rowan | Humboldt green / gold |
| Baltimore | Cam | Orioles orange / black |
| Phoenix | Sol | Suns purple / orange |
| Boston | Quinn | Celtics green / white |
| Chicago | Dre | Bulls red / black |
| Orlando | Nova | Magic blue / black |

Palette references: [Wehen Wiesbaden](https://svww.de/news/artikel/svww-und-errea-praesentieren-heim-und-auswaertstrikot),
[Washburn brand guide](https://www.washburn.edu/about/public-relations/licensing/files/Washburn-Brand-Book.pdf),
[Astros](https://www.mlb.com/astros/news/new-astros-uniforms-met-with-widespread-approval/c-40159484),
[Maine](https://umaine.edu/marcom/brand/visual-identity/),
[Humboldt](https://now.humboldt.edu/news/humboldt-state-unveils-new-athletics-logo),
[Orioles](https://www.mlb.com/orioles/news/orioles-release-city-connect-2-0-jerseys),
[Suns](https://store.nba.com/phoenix-suns/mens-phoenix-suns-fanatics-purple/orange-big-and-tall-pullover-hoodie/t-36257568+p-466611508083289+z-9-529040160),
[Celtics](https://www.nba.com/celtics/news/sidebar/prac-093016-horford-humbled-during-celtics-open-practice),
[Bulls](https://shop.bulls.com/pages/2025-26-chicago-bulls-statement),
[Magic](https://www.nba.com/news/magic-unveil-new-logo-uniforms-2025-26).

Bayou Academy uses a dedicated lower ground-plane anchor and a dirt surface
so its entire pit sits in the dry clearing, below the bayou waterline.

## Verification

Run the real scene/physics integration suite:

```powershell
& "D:\GODOT\Godot_v4.3-stable_win64.exe" --headless --path . --script res://tools/test_gameplay.gd
```

On Windows, use `Start-Process -Wait` if your GUI Godot executable returns
before it finishes. Substitute your own Godot executable path as needed.

Tests cover the ready phase, real input taps, slaps/charging/buffering,
double-touch, wall resets, dash immunity, harmless rolls, swept knockouts,
pause/resume, round results, menu setup, and live 4/6/8-player matches.

The league/series, crowd, trap/steal, ricochet and music integration suite is:

```powershell
& "D:\GODOT\Godot_v4.3-stable_win64.exe" --headless --path . --script res://tools/test_leagues.gd
```

Audio is reproducible from `tools/generate_audio.py` and
`tools/generate_music.py`. Godot 4.3 accepts 32-bit WAV sources but converts
WAV imports into its internal 16-bit sample representation, so the shipped
assets invest the file budget in stereo layers, dynamics and ambience instead.
The suite exits nonzero on failure and includes a timeout guard.

The dedicated AI soak test proves that CPUs legally target and eliminate
one another in a live match:

```powershell
& "D:\GODOT\Godot_v4.3-stable_win64.exe" --headless --path . --script res://tools/test_free_for_all.gd
```

Player saves, creator controls, all ten home sprites, Bayou placement, and
automatic tour travel (including loss, cancellation, and final-city cases):

```powershell
& "D:\GODOT\Godot_v4.3-stable_win64.exe" --headless --path . --script res://tools/test_profiles_tour.gd
```

The profile/tour suite uses isolated temporary saves, never the user's slots.

Controller/touch/jump/pratfall and expanded-save checks run with isolated
temporary profile files, simulated physical gamepad events and transformed
multitouch events:

```text
godot --headless --path . --script res://tools/test_controls_customization.gd
godot --path . --script res://tools/capture_action_preview.gd
```

Mappings follow Godot 4.3's [controller input guidance](https://docs.godotengine.org/en/4.3/tutorials/inputs/controllers_gamepads_joysticks.html);
touch taps use [Input.parse_input_event](https://docs.godotengine.org/en/4.3/classes/class_input.html)
so both press and release reach the buffered gameplay handler.
These simulations do **not** replace physical PC gamepad and Android hardware
testing. No Android APK/device certification is implied by desktop checks.

Art regression checks cover 1,152 rendered frames across every hairstyle/hat
pair, skin tones, facial hair, facings and poses. They detect frame-edge
clipping, nondeterministic texture and duplicate action poses:

```text
godot --headless --path . --script res://tools/test_fighter_art.gd
godot --path . --script res://tools/capture_fighter_art.gd
godot --path . --script res://tools/capture_fighter_art.gd -- --poses
```

The two visual checks write `fighter-roster.png` and `fighter-poses.png` under
`.godot/`. The latter previews the equipped player without changing any saves.

Rendered preview capture (run **without** `--headless`):

```text
godot --path . --script res://tools/capture_preview.gd
godot --path . --script res://tools/capture_preview.gd -- --arena
godot --path . --script res://tools/capture_preview.gd -- --campaign
godot --path . --script res://tools/capture_preview.gd -- --arena --pause
godot --path . --script res://tools/capture_preview.gd -- --stage=0
godot --path . --script res://tools/capture_preview.gd -- --stage=2 --lineup
godot --path . --script res://tools/capture_preview.gd -- --creator
```

PNGs are saved under the ignored `.godot/` directory. Android touch
behavior/export still needs verification on an actual device; desktop
tests are not a substitute for that.

## Art and project layout

`Scripts/FighterArt.gd` draws original textured 80×96 pixel fighters into 8×3
animation sheets at runtime. Warm highlights, cool shadows, sculpted faces,
hair strands, cloth weave/folds, hat stitching, and laced sneakers share the
city backgrounds' richer palette. Every cosmetic works across every pose and
facing, and saved profiles remain compatible. On-court dimensions and hitboxes
are unchanged; flattened contact shadows sit on the courtyard ground plane.
`tools/generate_art.py` supplies legacy fallback sheets, the ball
sprite and stage ground tiles. `tools/generate_audio.py` generates the original
chip-style WAV effects. The ten image-generated city plates and their prompt
set live together under `Assets/Backgrounds/Stages/`. `tools/preview_arena.py`
creates an offline arena mockup. The runtime preview above captures the actual game.

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

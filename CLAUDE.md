# Electric Football - Digital Recreation

## Project Overview

A digital recreation of the classic Tudor Electric Football tabletop game using Godot 4.x. The game simulates the iconic vibrating metal field where plastic football players on adjustable bases move semi-chaotically to play out football games.

## Core Concept

The original physical game works by:
1. Players place plastic figures with prong/brush bases on a metal field
2. A motor vibrates the field, causing figures to move based on their base configuration
3. "Coaching" involves bending the prongs to control direction and speed
4. Special figures (Triple Threat QB) handle passing and kicking via spring mechanisms
5. Ball carrier is tackled when contacted by a defender

## Tech Stack

- **Engine:** Godot 4.x (GDScript)
- **Platform:** Linux (Arch) primary, with cross-platform export capability
- **Style:** 2D top-down view

## Project Structure

```
/project.godot
/scenes/
    main.tscn           # Main game scene
    field.tscn          # Football field
    player.tscn         # Individual player figure
    ball.tscn           # Football for passing/kicking
    ui/                 # UI scenes
/scripts/
    field.gd            # Field rendering, yard lines, LOS display, goal posts
    player.gd           # Player figure with base configuration
    ball.gd             # Football entity for passing/kicking
    vibration_controller.gd  # Autoload singleton for vibration physics
    audio_manager.gd    # Autoload singleton for procedural audio
    game_manager.gd     # Game state, phases, downs, ball tracking
    formation.gd        # Formation save/load resource
    main.gd             # Main controller, input handling, UI, passing/kicking
/assets/
    /sprites/
    /audio/
/resources/
    /formations/        # Preset formation resources (10 total)
```

## Key Systems

### Vibration Physics (CRITICAL)

The core mechanic that makes the game feel authentic. Each player's movement is determined by:

- **Global vibration state:** on/off, frequency, amplitude
- **Per-player base configuration:**
  - `base_direction: float` — primary movement angle (radians)
  - `base_speed: float` — movement magnitude modifier
  - `base_curve: float` — rotational drift per frame
- **Random perturbation:** small noise added each physics frame

Movement should feel emergent and slightly unpredictable while still being influenced by base tuning.

### Player Figure

Use `RigidBody2D` for natural collision response. Each player has:
- Team affiliation (0 or 1)
- Position role (lineman, receiver, QB, etc.)
- Base configuration (the "coached" prong settings)
- Ball carrier state

### Collision Layers

- Layer 1: Players
- Layer 2: Field boundaries
- Layer 3: Ball

### Game Flow

1. **Setup phase:** Position players in formations
2. **Pre-snap:** Allow pivots/audibles
3. **Snap:** Activate vibration, players move
4. **Play ends:** Tackle, out of bounds, TD, or incomplete pass
5. **Reset:** Next down or possession change

## Implementation Phases

### Phase 1: Core Physics & Field ✓ COMPLETE
- [x] Field rendering with yard lines, boundaries (portrait orientation)
- [x] Player figure scene with base configuration
- [x] Vibration physics algorithm with random perturbation
- [x] Collision detection and layers
- [x] Debug UI for tuning vibration/base values
- [x] VibrationController autoload singleton

### Phase 2: Player Figures & Base System ✓ COMPLETE
- [x] Drag-to-rotate direction control (right-click drag)
- [x] Pre-snap player dragging (left-click drag when selected)
- [x] Distinct visual shapes for each role (6 unique shapes)
- [x] Team color distinction (red vs blue)
- [x] Full 11v11 rosters (I-Formation offense vs 4-3 defense)

### Phase 3: Formation & Play Setup ✓ COMPLETE
- [x] Formation save/load system (9 user slots, F5/F9 keys)
- [x] Preset formations (5 offense, 5 defense, Shift/Ctrl+1-5)
- [x] Line of scrimmage indicator (blue) and first down marker (yellow)
- [x] Snap mechanic with game phases (PRE_SNAP → PLAYING → PLAY_OVER)

### Phase 4: Passing & Kicking ✓ COMPLETE
- [x] Ball entity with physics (RigidBody2D, collision detection)
- [x] QB passing mechanic (click QB to aim, right-click to throw)
- [x] Power-based throwing (distance determines throw power)
- [x] Catch detection (eligible receivers: WR, RB, QB)
- [x] Interception detection (defensive players)
- [x] Incomplete pass detection (timeout, out of bounds, stopped)
- [x] Kicking mechanic (K key, aim and power)
- [x] Goal posts on field (visual + detection positions)
- [x] Visual aim indicator (orange for passing, cyan for kicking)

### Phase 5: Game Rules & Flow ✓ COMPLETE
- [x] Possession tracking (HOME/AWAY with automatic changes)
- [x] LOS advancement based on ball carrier position at tackle
- [x] Down progression (1st & 10, yards to go calculation)
- [x] First down detection (auto-reset to 1st & 10)
- [x] Touchdown detection (6 points when carrier enters opponent end zone)
- [x] Safety detection (2 points when tackled in own end zone)
- [x] Field goal detection (3 points when kick goes through uprights)
- [x] Turnover on downs (possession change after 4th down failure)
- [x] Interception handling (immediate possession change, play continues)
- [x] Score display in UI (HOME X - AWAY X format)
- [x] Possession indicator in UI
- [ ] Clock management (optional - future)
- [ ] Penalties (optional - future)

### Phase 6: Polish ✓ COMPLETE
- [x] Scoreboard UI (dedicated panel with large score, down & distance, possession arrow)
- [x] Sound design (procedural buzz, whistle, touchdown/field goal celebration, kick/throw sounds)
- [x] Visual style refinement (player outlines, yard line numbers, end zone text, pulsing ball indicator)

## Code Style Guidelines

- Use static typing in GDScript where possible
- Prefix private variables/methods with underscore
- Use signals for decoupled communication
- Keep scenes modular and reusable
- Comment non-obvious physics calculations

## Physics Tuning Notes

These values will need iteration. Start with:

```gdscript
# VibrationController defaults
var vibration_frequency: float = 60.0  # perturbations per second
var vibration_amplitude: float = 50.0  # force magnitude

# Player base defaults
var base_direction: float = 0.0        # radians, 0 = right
var base_speed: float = 1.0            # multiplier
var base_curve: float = 0.0            # radians per second
```

## Commands

```bash
# Run the project (from project root)
godot --path . 

# Run specific scene
godot --path . scenes/main.tscn

# Export (after configuring export presets)
godot --headless --export-release "Linux/X11" build/electric_football.x86_64
```

## Reference Material

- Original game field sizes: 24"x13" up to 61"x27.5"
- Tudor Games official site: https://tudorgames.com
- National Electric Football Museum: https://nefgm.org
- The vibration creates linear oscillations; prong angle/length determines direction/speed

## Current Status

**All phases complete!** Full gameplay loop with vibration physics, 11v11 players, formation management, passing/kicking, automatic game rules, and polish (scoreboard UI, procedural audio, visual refinements).

## Controls

| Key/Action | Function |
|------------|----------|
| SPACE (pre-snap) | Snap the ball, start the play |
| SPACE (playing) | Blow whistle, end the play |
| SPACE (play over) | Ready for next play |
| R | Reset players to formation, ready for snap |
| Q | Quit game |
| ESC | Cancel aiming/kick mode, or deselect player |
| F5 | Save current formation to selected slot |
| F9 | Load formation from selected slot |
| 1-9 | Select formation slot (shown in UI with * if saved) |
| Shift+1-5 | Load offense preset (I-Form, Shotgun, Singleback, Spread, Goal Line) |
| Ctrl+1-5 | Load defense preset (4-3, 3-4, Nickel, 46, Goal Line) |
| UP | Move line of scrimmage toward away end zone (-5 yards) |
| DOWN | Move line of scrimmage toward home end zone (+5 yards) |
| K (pre-snap) | Enter kick mode |
| Click | Select player |
| Left-drag (selected) | Move player position (pre-snap only) |
| Right-drag (selected) | Rotate player direction (pre-snap only) |
| Click QB (playing) | Enter aim mode for passing |
| Right-click (aiming) | Throw ball toward mouse position |
| Right-click (kick mode) | Kick ball toward mouse position |
| Sliders | Adjust vibration frequency/amplitude |
| Sliders (selected) | Adjust player speed/curve |

## Game Flow

1. **PRE-SNAP**: Position players, adjust formations. Press SPACE to snap, or K to enter kick mode.
2. **PLAYING**: Ball is live, players vibrate. Click QB to aim pass, right-click to throw. Press SPACE to whistle.
3. **PLAY OVER**: Play ended (tackle, touchdown, safety, field goal, incomplete pass, or whistle). Press R to reset for next play.

### Automatic Rules
- **Downs**: Starts at 1st & 10. Gain 10+ yards for new first down, or advance down counter.
- **Turnover on Downs**: After 4th down failure, possession changes to other team.
- **Touchdown**: 6 points when ball carrier enters opponent's end zone. Scored team receives.
- **Safety**: 2 points when ball carrier tackled in own end zone. Scored-on team kicks from own 20.
- **Field Goal**: 3 points when kicked ball goes through uprights. Kicking team kicks off.
- **Interception**: Possession changes immediately, play continues with interceptor as ball carrier.

## Passing System

- During PLAYING phase, click on the home team's QB (red, diamond shape) to enter aim mode
- An orange aim line shows the throw trajectory from QB to mouse cursor
- Line thickness indicates throw power (based on distance)
- Right-click to throw the ball
- Ball travels toward target with physics-based movement
- Eligible receivers (WR, RB, QB) on same team can catch the pass
- Defensive players intercepting the ball results in turnover
- Incomplete if: ball goes out of bounds, stops moving, or times out (2 seconds)

## Kicking System

- Press K during PRE_SNAP to enter kick mode
- A cyan aim line appears from behind the QB position
- Right-click to kick after the snap
- Ball travels in a parabolic arc (simulated height with scale)
- Goal posts are visible on both end zones for field goal attempts

## Preset Formations

### Offense (Shift+1-5)
| Key | Formation | Description |
|-----|-----------|-------------|
| Shift+1 | I-Formation | Classic power running, FB leads for HB |
| Shift+2 | Shotgun | QB in pistol, RBs flanking |
| Shift+3 | Singleback | One RB behind QB, balanced attack |
| Shift+4 | Spread | 4 WR spread wide, 1 RB, passing focus |
| Shift+5 | Goal Line | Tight formation for short yardage |

### Defense (Ctrl+1-5)
| Key | Formation | Description |
|-----|-----------|-------------|
| Ctrl+1 | 4-3 | 4 DL, 3 LB, balanced coverage |
| Ctrl+2 | 3-4 | 3 DL, 4 LB, versatile blitzing |
| Ctrl+3 | Nickel | 5 DBs, pass defense focus |
| Ctrl+4 | 46 | Aggressive 8-man front, run stopping |
| Ctrl+5 | Goal Line | Stacked box, short yardage defense |

## Player Roles & Shapes

| Role | Shape | Used For |
|------|-------|----------|
| LINEMAN | Wide, blocky | OL, DL |
| RECEIVER | Slim, tall | WR, TE |
| QUARTERBACK | Diamond/pointed | QB |
| RUNNING_BACK | Medium, rounded | RB, FB |
| LINEBACKER | Wide defensive | LB |
| DEFENSIVE_BACK | Slim defensive | CB, S |

## Default Formations

**Offense (Red - Home):** I-Formation (Shift+1)
- 5 Offensive Linemen (LT, LG, C, RG, RT)
- 1 Tight End
- 2 Wide Receivers
- 1 Quarterback
- 1 Fullback
- 1 Halfback

**Defense (Blue - Away):** 4-3 (Ctrl+1)
- 4 Defensive Linemen (2 DE, 2 DT)
- 3 Linebackers (2 OLB, 1 MLB)
- 4 Defensive Backs (2 CB, 2 S)

## Formation Files

Preset formations are stored in `res://resources/formations/`:
- `offense_i_formation.tres`
- `offense_shotgun.tres`
- `offense_singleback.tres`
- `offense_spread.tres`
- `offense_goal_line.tres`
- `defense_4_3.tres`
- `defense_3_4.tres`
- `defense_nickel.tres`
- `defense_46.tres`
- `defense_goal_line.tres`

User-saved formations are stored in `user://formations/` (persists between sessions).

# HealIQ – Design Document

## Overview

**HealIQ** is a smart healing spell suggestion addon for **Restoration Druids** in World of Warcraft. Inspired by addons like Hekili and MaxDps, HealIQ focuses not on DPS rotations but on assisting healers by providing intelligent, context-aware spell suggestions.

This tool is designed to:
- Help newer and intermediate healers make optimal healing decisions.
- Improve muscle memory and reaction time through visual suggestions.
- Adapt to the reactive, non-rotational nature of healing in WoW.

## Scope and Goals

### Primary Goals
- Suggest next-best healing spell in real time during combat.
- Track HoTs (Lifebloom, Rejuvenation, Regrowth) and cooldown-based spells (Swiftmend, Wild Growth, Tranquility).
- Provide a clean, configurable UI for visualizing spell recommendations.
- Remain modular, efficient, and extensible.
- Work without needing target-specific logic (i.e. doesn't pick who to heal).

### Stretch Goals
- Hybrid healer/DPS suggestion support (e.g. catweaving or Wrath weaving).
- Multi-spec support (Holy Priest, Mistweaver, etc.).
- Optional WeakAura export for power users.
- DBM/BigWigs integration for encounter-awareness.

## Non-Goals
- HealIQ will **not**:
  - Suggest specific healing *targets*.
  - Auto-cast or assist with automation of any kind.
  - Replace human decision-making for triage or positioning.

## Architecture

### Modules

| File        | Purpose                                                      |
|-------------|--------------------------------------------------------------|
| `Core.lua`  | Addon initialization, event registration, and saved variables |
| `Engine.lua`| Priority logic engine that determines the suggested spell    |
| `UI.lua`    | Renders suggestion icons and manages configuration display   |
| `Tracker.lua`| Tracks buffs, cooldowns, and relevant unit conditions       |
| `Config.lua`| Handles slash commands and user options                      |

### Data Flow

1. **Game events** (UNIT_AURA, SPELL_UPDATE_COOLDOWN, COMBAT_LOG_EVENT_UNFILTERED, etc.) update internal state.
2. **Tracker** gathers and updates spell/buff/cooldown status.
3. **Engine** evaluates rules and priorities based on the state.
4. **UI** updates to show the recommended spell.

## Priority Logic (Initial Rules)

```lua
-- Pseudo-priority system:
1. If Wild Growth is off cooldown and 3+ allies recently damaged → Suggest Wild Growth
2. If Clearcasting active → Suggest Regrowth
3. If Lifebloom on tank < 4s → Suggest refresh
4. If Swiftmend is usable and Rejuv+Regrowth are active → Suggest Swiftmend
5. If no Rejuvenation on current target → Suggest Rejuvenation
6. If none of the above → Idle (show no suggestion)
````

This logic will be modular and eventually configurable.

## UI Design

* Central floating suggestion icon (customizable position/scale)
* Optional cooldown overlay and spell name
* Optional "queue mode" to show next 2–3 recommendations
* Future: draggable UI config mode or `/healiq` command options

## Addon API Constraints and Considerations

* Addons **cannot** read live health/mana of units during combat (except player/target/focus).
* Suggestions will rely on combat log events, known auras, cooldowns, and predicted AoE phases.
* Addon must not attempt to cast spells or make target-specific recommendations.

## Compatibility

* World of Warcraft Retail (The War Within, patch 11.1.7+)
* Compatible with DBM, BigWigs, and WeakAuras
* No required dependencies

## Development Roadmap

### Milestone 1: MVP

* [ ] Spell suggestion engine with 5–6 rules
* [ ] UI overlay with single suggestion
* [ ] Basic `/healiq` command

### Milestone 2: Visual & Config Enhancements

* [ ] Movable/resizable UI
* [ ] Queue display
* [ ] Basic in-game configuration options

### Milestone 3: Smart Integrations

* [ ] DBM/BigWigs sync (for incoming damage phases)
* [ ] WeakAura export support
* [ ] Additional healing spec support

## License

MIT License (open source, contributions welcome)

## Author

Ryan Trauntvein (DJ DeFi)
[https://github.com/djdefi](https://github.com/djdefi)
Contact: \[Add your preferred contact or Discord handle]

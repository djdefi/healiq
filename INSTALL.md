# HealIQ Installation and Usage Guide

## Installation

1. Download or clone this repository
2. Copy the entire `healiq` folder to your WoW `Interface/AddOns/` directory
3. Make sure the folder is named `HealIQ` (case sensitive)
4. Enable the addon in the WoW AddOn menu
5. Log in with a Restoration Druid character

## File Structure

```
HealIQ/
├── HealIQ.toc       # Addon metadata and loading order
├── Core.lua         # Main addon initialization and event handling
├── Tracker.lua      # Tracks spells, buffs, cooldowns, and combat events
├── Engine.lua       # Priority logic system for spell suggestions
├── UI.lua          # User interface display and interaction
├── Config.lua       # Slash commands and configuration
├── README.md        # Project documentation
└── DESIGN.md        # Design document and architecture
```

## Usage

### Basic Commands

- `/healiq` or `/hiq` - Show help
- `/healiq enable` - Enable the addon
- `/healiq disable` - Disable the addon
- `/healiq toggle` - Toggle addon on/off
- `/healiq status` - Show current status

### UI Commands

- `/healiq ui lock` - Lock UI position
- `/healiq ui unlock` - Unlock UI position (allows dragging)
- `/healiq ui scale <0.5-2.0>` - Set UI scale
- `/healiq ui reset` - Reset UI position to center
- `/healiq ui name show/hide` - Show/hide spell names
- `/healiq ui cooldown show/hide` - Show/hide cooldown timers

### Rule Management

- `/healiq rules list` - List all rules and their status
- `/healiq rules enable <rule>` - Enable a specific rule
- `/healiq rules disable <rule>` - Disable a specific rule

Available rules: `wildGrowth`, `clearcasting`, `lifebloom`, `swiftmend`, `rejuvenation`

### Testing

- `/healiq test` - Test the UI display
- `/healiq test engine` - Test engine rules
- `/healiq debug` - Toggle debug mode

## How It Works

HealIQ provides intelligent spell suggestions for Restoration Druids based on:

1. **Wild Growth Priority**: Suggests Wild Growth when off cooldown and 3+ party members recently took damage
2. **Clearcasting Procs**: Suggests Regrowth when Clearcasting is active
3. **Lifebloom Management**: Suggests refreshing Lifebloom when it has < 4 seconds remaining
4. **Swiftmend Combos**: Suggests Swiftmend when available and target has Rejuvenation or Regrowth
5. **Rejuvenation Coverage**: Suggests Rejuvenation when target doesn't have it

## Requirements

- World of Warcraft: The War Within (11.1.7+)
- Restoration Druid character
- No other addon dependencies

## Configuration

All settings are automatically saved and persist between sessions. The addon:

- Only activates for Restoration Druids
- Automatically detects spec changes
- Provides visual feedback through a movable UI element
- Includes right-click to lock/unlock positioning
- Supports drag-and-drop repositioning

## Troubleshooting

If the addon doesn't load:
1. Check that the folder is named `HealIQ` exactly
2. Verify you're playing a Restoration Druid
3. Try `/healiq status` to check addon state
4. Enable debug mode with `/healiq debug`

## Version

Current version: 0.0.1

This is the initial release with core functionality. Future versions will include additional features like DBM integration, WeakAura export, and support for other healing specs.
# HealIQ Encounter Integration Guide

## Overview

HealIQ now includes encounter integration with **DBM (Deadly Boss Mods)** and **BigWigs** to provide encounter-aware healing suggestions. This feature automatically adjusts spell recommendations based on upcoming boss abilities and damage phases.

## Features

### Automatic Detection
- Detects when DBM or BigWigs is loaded and available
- No manual configuration required for basic functionality
- Works with both addons simultaneously if both are installed

### Encounter-Aware Suggestions
- **Pre-ramping Phase** (12-15 seconds before damage): Prioritizes Rejuvenation, Lifebloom, and Efflorescence
- **Cooldown Preparation** (5 seconds before damage): Prioritizes major cooldowns like Tranquility and Incarnation
- **Smart Priority Adjustment**: Automatically reorders spell suggestions based on encounter timing

### Supported Event Types
The integration recognizes various boss ability patterns:
- AoE damage phases
- Raid-wide damage events  
- Tank damage spikes
- Phase transitions
- Damage over time effects

## Configuration

### Basic Commands
```
/healiq encounter status     # Show current integration status
/healiq encounter toggle     # Enable/disable encounter integration
/healiq encounter enable     # Enable encounter integration
/healiq encounter disable    # Disable encounter integration
/healiq encounter test       # Test encounter detection
```

### Configuration Options
Access via saved variables or future UI options:

- **enabled** (default: true) - Enable/disable encounter integration
- **preparationWindow** (default: 15) - How far ahead to look for events (seconds)
- **cooldownPrepTime** (default: 5) - When to prioritize cooldowns before events
- **preRampTime** (default: 12) - When to prioritize pre-ramping before events
- **enableDebugMessages** (default: false) - Show debug messages for encounter events

## How It Works

### Event Detection
1. **DBM Integration**: Hooks into DBM timer callbacks to detect upcoming boss abilities
2. **BigWigs Integration**: Listens for BigWigs timer events and encounter state changes
3. **Event Filtering**: Analyzes ability names and spell IDs to identify healing-relevant events
4. **Priority Calculation**: Assigns priority levels (high/medium/low) based on event characteristics

### Suggestion Modification
When healing-relevant events are detected within the preparation window:

1. **Immediate Preparation** (≤5s): Suggests major cooldowns first
   - Tranquility, Incarnation, Nature's Swiftness move to top priority
   
2. **Pre-ramping Phase** (5-12s): Prioritizes HoT setup
   - Rejuvenation, Lifebloom, Efflorescence move to higher priority
   
3. **Planning Phase** (12-15s): Normal priority with encounter awareness
   - Standard suggestions with encounter context logged

### Event Keywords
The system recognizes these keywords in boss ability names:
- **High Priority**: "raid", "aoe" 
- **Medium Priority**: "damage", "phase", "transition"
- **General Indicators**: "storm", "blast", "wave", "pulse", "explosion", "fire", "shadow", "void", "cleave", "spread", "dot", "debuff"

## Examples

### Pre-AoE Ramping
```
DBM Timer: "Raid Storm - 10s"
HealIQ Response: Prioritizes Rejuvenation and Lifebloom to prepare for incoming damage
```

### Cooldown Preparation  
```
BigWigs Timer: "AoE Blast - 3s"
HealIQ Response: Suggests Tranquility or Incarnation for immediate use
```

### Tank Damage Spike
```
DBM Timer: "Tank Cleave - 8s" 
HealIQ Response: Prioritizes Lifebloom refresh on tank
```

## Troubleshooting

### Integration Not Working
1. Verify DBM or BigWigs is loaded: `/healiq encounter status`
2. Check if encounter integration is enabled: `/healiq encounter enable`
3. Ensure you're in an encounter with active timers

### No Event Detection
1. Check if the boss ability names contain recognized keywords
2. Enable debug messages: Set `enableDebugMessages = true` in saved variables
3. Test with `/healiq encounter test` during an encounter

### Suggestions Not Changing
1. Verify events are within the preparation window (default 15 seconds)
2. Check that the events are classified as healing-relevant
3. Ensure your normal spell suggestions are working first

## Advanced Configuration

For advanced users, the encounter detection can be customized by modifying the `IsHealingRelevantEvent` function in `EncounterIntegration.lua`. You can:

- Add specific spell IDs for certain encounters
- Modify keyword detection patterns
- Adjust priority assignment logic
- Add custom encounter-specific rules

## Compatibility

- **DBM**: All recent versions supported
- **BigWigs**: All recent versions supported  
- **Performance**: Minimal impact, only processes events during encounters
- **Other Addons**: Fully compatible with other healing and boss mod addons

## Feedback and Issues

If you encounter issues with encounter integration:
1. Report the specific encounter and boss ability names
2. Include DBM/BigWigs version information
3. Share any debug output or error messages
4. Specify whether the issue is with detection or suggestion prioritization

The encounter integration system is designed to be robust and fall back gracefully when addons are not available or events are not recognized.
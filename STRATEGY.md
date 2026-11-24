# HealIQ Strategy Configuration Guide

## Overview

HealIQ now implements an enhanced healing strategy based on the Wowhead Restoration Druid guide, with extensive customization options to adapt to different playstyles and encounter needs.

## New Rule Priorities

The spell priorities have been reordered to match optimal Restoration Druid gameplay:

1. **Tranquility** - Emergency group healing (4+ targets damaged)
2. **Incarnation: Tree of Life** - Major cooldown for high damage phases
3. **Nature's Swiftness** - Emergency instant cast setup
4. **Efflorescence** - Maintain active frequently (ground AoE healing)
5. **Lifebloom** - Keep active on tank with proper refresh timing
6. **Regrowth** - Prioritize with Clearcasting procs
7. **Swiftmend** - Setup for Wild Growth combos
8. **Wild Growth** - AoE healing when 3+ targets damaged
9. **Flourish** - Extend multiple HoTs when expiring
10. **Ironbark** - Damage reduction on tank/focus
11. **Barkskin** - Self-defense when taking damage
12. **Rejuvenation** - Basic HoT with smart ramping logic
13. **Wrath** - Mana restoration filler during downtime

## New Spells Added

### Wrath
- **Purpose**: Mana restoration during downtime
- **Strategy**: Only suggests when no immediate healing needs and enemy target available
- **Configuration**: Controlled by `useWrathForMana` setting

## Strategy Configuration

Access strategy settings with `/healiq strategy list` and modify with `/healiq strategy set <setting> <value>`.

### Core Strategy Toggles

- `prioritizeEfflorescence` (default: true) - Keep Efflorescence active frequently
- `maintainLifebloomOnTank` (default: true) - Always maintain Lifebloom on tank
- `preferClearcastingRegrowth` (default: true) - Prioritize Regrowth with procs
- `swiftmendWildGrowthCombo` (default: true) - Link Swiftmend and Wild Growth usage
- `avoidRandomRejuvenationDowntime` (default: true) - Don't cast random Rejuvs during downtime
- `useWrathForMana` (default: true) - Fill downtime with Wrath for mana
- `emergencyNaturesSwiftness` (default: true) - Use Nature's Swiftness for emergency heals

### Tunable Thresholds

- `wildGrowthMinTargets` (default: 1) - Minimum targets damaged to suggest Wild Growth (0=solo mode)
- `tranquilityMinTargets` (default: 4) - Minimum targets damaged to suggest Tranquility
- `efflorescenceMinTargets` (default: 2) - Minimum targets damaged to suggest Efflorescence
- `flourishMinHots` (default: 2) - Minimum expiring HoTs to suggest Flourish
- `recentDamageWindow` (default: 3) - Time window to consider "recent damage" (seconds)
- `lowHealthThreshold` (default: 0.3) - Health percentage to consider "emergency"
- `lifebloomRefreshWindow` (default: 4.5) - Refresh Lifebloom in last X seconds for bloom

## Examples

### Basic Usage
```
/healiq strategy list                           # Show all settings
/healiq strategy set wildGrowthMinTargets 1     # Default: good for small groups
/healiq strategy set wildGrowthMinTargets 0     # Solo mode: always suggest Wild Growth
/healiq strategy set lowHealthThreshold 0.4     # Emergency threshold at 40% health
/healiq strategy set useWrathForMana false      # Disable Wrath suggestions
```

### Raid vs Mythic+ Tuning
```
# Solo/Small Group settings (more permissive)
/healiq strategy set wildGrowthMinTargets 0
/healiq strategy set tranquilityMinTargets 2

# Raid settings (more conservative)
/healiq strategy set wildGrowthMinTargets 4
/healiq strategy set tranquilityMinTargets 5

# Mythic+ settings (balanced)
/healiq strategy set wildGrowthMinTargets 2
/healiq strategy set tranquilityMinTargets 3
```

### Reset to Defaults
```
/healiq strategy reset                          # Reset all strategy settings
```

## Integration with Wowhead Guide

This implementation closely follows the Wowhead Restoration Druid guide recommendations:

1. **Efflorescence Priority** - Now properly prioritized for frequent maintenance
2. **Lifebloom Tank Maintenance** - Smart refresh timing to get bloom effect
3. **Clearcasting Utilization** - Regrowth prioritized when proc is active
4. **AoE Healing Flow** - Swiftmend → Wild Growth combo logic
5. **Ramping Strategy** - Rejuvenation timing based on damage phases vs downtime
6. **Cooldown Management** - Flourish HoT extension and emergency responses
7. **Mana Efficiency** - Wrath filler to maintain mana levels

## Advanced Configuration

For power users, all settings can be adjusted to match specific encounter needs or personal preferences. The system is designed to be flexible while maintaining optimal defaults based on current theorycrafting.
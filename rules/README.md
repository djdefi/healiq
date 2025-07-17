# Rules Directory

This directory contains modular rule files for HealIQ spell suggestions.

## Structure

- `BaseRule.lua` - Base rule interface and common functionality
- `DefensiveCooldowns.lua` - Defensive cooldown rules (Ironbark, Barkskin)
- `HealingCooldowns.lua` - Healing cooldown rules (Tranquility, Nature's Swiftness, Incarnation)
- `UtilityRules.lua` - Utility and buff rules (Flourish, Grove Guardians)
- `AoERules.lua` - Area of effect healing rules (Efflorescence)
- `OffensiveRules.lua` - Offensive/DPS rules (Wrath)

## Usage

Each rule file exports functions that can be called by the main Tracker module.
Rules maintain the same interface as the original ShouldUse* functions.
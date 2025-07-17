# HealIQ

**HealIQ** is a smart spell suggestion addon for Restoration Druids in World of Warcraft. It helps you prioritize your next healing spell based on current combat context, active HoTs, procs, and cooldowns.

## 🧠 What It Does

- Displays optimal healing spell suggestions based on Wowhead Restoration Druid guide
- Tracks HoT durations (e.g. Lifebloom, Rejuvenation)
- Recognizes Clearcasting procs and emergency situations
- Shows Swiftmend combo opportunities and AoE healing priorities
- Alerts for cooldown-based healing (e.g. Wild Growth, Tranquility)
- Supports movement and configuration of suggestion UI
- Shows upcoming suggestions in a queue display
- Provides extensive strategy customization options

**Enhanced Strategy Features:**
- Efflorescence maintenance prioritization
- Smart Lifebloom tank management with bloom timing
- Clearcasting proc optimization
- Swiftmend + Wild Growth combo suggestions
- Grove Guardians charge pooling
- Wrath filler for mana restoration
- Configurable thresholds for all healing decisions

**Encounter Integration Features:**
- DBM/BigWigs integration for encounter-aware suggestions
- Pre-ramping recommendations before known AoE damage phases
- Cooldown preparation alerts for major encounter events
- Automatic priority adjustments based on boss timers
- Configurable encounter awareness settings

**Note:** HealIQ provides visual suggestions only. Due to Blizzard restrictions, spell casting must be done manually using your normal keybinds or action bars.

> HealIQ is inspired by Hekili, but for healing. Designed with Restoration Druids in mind, support for other healers may be added later.

## 📦 Installation

### From CurseForge (Recommended)
- Download from [CurseForge](https://curseforge.com) using the CurseForge app or website
- Automatic updates and dependency management

### Manual Installation
1. Download the latest release from [GitHub Releases](https://github.com/djdefi/healiq/releases)
2. Unzip to your `Interface/AddOns/` directory
3. Enable the addon in the WoW AddOn menu
4. Type `/healiq` for basic options and slash commands (coming soon)

## 🔧 Configuration

- UI icon is movable (drag-and-drop)
- Suggestions shown via a single icon by default
- Queue preview shows upcoming spell suggestions
- Extensive strategy customization via `/healiq strategy` commands
- Rule enable/disable via `/healiq rules` commands
- All healing thresholds and priorities are tunable

**Strategy Configuration:**
- Access via `/healiq strategy list` to see all settings
- Modify with `/healiq strategy set <setting> <value>`
- Reset to optimal defaults with `/healiq strategy reset`
- See [STRATEGY.md](STRATEGY.md) for detailed configuration guide

## 📜 Planned Features

- ~~DBM integration for upcoming damage phases~~ ✅ **Completed**
- Rule customization (enable/disable rules)
- Visual “queue” preview
- Support for hybrid Resto-DPS catweaving

## 💡 Why Use This?

Healing doesn’t follow a strict rotation, but there are patterns of optimal decision-making. HealIQ helps you build muscle memory and learn when to refresh HoTs, use procs, or prep cooldowns for big AoE.

## 🛠 For Developers

This addon is written in Lua using the WoW AddOn API.

Contributions and suggestions welcome via [Issues](https://github.com/djdefi/healiq/issues) and PRs.

---

## 🔒 License

MIT License

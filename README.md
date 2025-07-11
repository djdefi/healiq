# HealIQ

**HealIQ** is a smart spell suggestion addon for Restoration Druids in World of Warcraft. It helps you prioritize your next healing spell based on current combat context, active HoTs, procs, and cooldowns.

## 🧠 What It Does

- Suggests your next optimal healing spell
- Tracks HoT durations (e.g. Lifebloom, Rejuvenation)
- Recognizes Clearcasting procs
- Prompts Swiftmend combo use
- Alerts for cooldown-based AoE healing (e.g. Wild Growth)
- Supports movement and configuration of suggestion UI

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
- Future: support for WeakAura export, config GUI, and profile-based tuning

## 📜 Planned Features

- DBM integration for upcoming damage phases
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

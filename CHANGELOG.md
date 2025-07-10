# HealIQ Changelog

## [0.0.1] - 2024-07-10

### Added
- Initial addon structure and core functionality
- **Core.lua**: Main addon initialization and event handling
- **Tracker.lua**: Spell/buff/cooldown tracking system
- **Engine.lua**: Priority logic engine for spell suggestions
- **UI.lua**: Movable suggestion display with icon and text
- **Config.lua**: Comprehensive slash command system
- **HealIQ.toc**: Addon metadata for WoW 11.1.7+

### Features
- Smart spell suggestions for Restoration Druids
- 5 priority rules implemented:
  1. Wild Growth (AoE healing when 3+ players damaged)
  2. Clearcasting proc detection → Regrowth
  3. Lifebloom refresh management (< 4s remaining)
  4. Swiftmend combo suggestions
  5. Rejuvenation coverage
- Movable UI with drag-and-drop positioning
- Configurable UI scale, spell names, and cooldown display
- Right-click lock/unlock functionality
- Comprehensive `/healiq` command system
- Rule enable/disable system
- Debug mode for troubleshooting
- Automatic Restoration Druid spec detection

### Documentation
- Complete installation and usage guide (INSTALL.md)
- Design document with architecture details (DESIGN.md)
- Project README with feature overview
- Inline code documentation and comments

### Technical Details
- WoW API integration for spell tracking
- Combat log parsing for damage detection
- Aura monitoring for buff/debuff tracking
- Cooldown tracking system
- Saved variables for persistent configuration
- Event-driven architecture for performance
- No external dependencies required

### Commands Added
- `/healiq` - Main command help
- `/healiq enable/disable/toggle` - Addon control
- `/healiq ui` - UI configuration commands
- `/healiq rules` - Rule management
- `/healiq test` - Testing and debug functions
- `/healiq status` - Status information
- `/healiq reset` - Reset to defaults
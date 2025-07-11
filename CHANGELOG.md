# HealIQ Changelog

## [0.0.9] - 2025-07-11

### Added
- 

### Changed
- 

### Fixed
- 


## [0.0.8] - 2025-07-10

### Added
- 

### Changed
- 

### Fixed
- 


## [0.0.7] - 2025-07-10

### Added
- 

### Changed
- 

### Fixed
- 


## [0.0.6] - 2025-07-10

### Added
- 

### Changed
- 

### Fixed
- 


## [0.0.5] - 2025-07-10

### Added
- 

### Changed
- 

### Fixed
- 


## [0.0.4] - 2025-07-10

### Added
- Comprehensive in-game polish improvements merged from PR #16

### Changed
- Updated WoW API calls to use newer C_Spell.GetSpellCooldown and C_Item.GetItemCooldown APIs
- Maintained backward compatibility with enhanced error handling

### Fixed
- Fixed WoW API deprecation warnings by updating to current API functions
- Resolved merge conflicts while preserving all SafeCall error handling enhancements


## [0.0.3] - 2025-07-10

### Added - In-Game Polish Improvements
- **Version Display**: Version number now prominently displayed in options frame and minimap button tooltip
- **Enhanced Error Handling**: Comprehensive error handling throughout all modules with SafeCall wrapper
- **Reload Functionality**: Added `/healiq reload` command for soft addon reloading
- **Improved Status Command**: Enhanced `/healiq status` with colored output and memory usage display
- **Better User Feedback**: Improved success/error messages with proper color coding
- **Icon Enhancements**: Added proper icon to options frame title bar
- **Cleanup System**: Added proper addon cleanup for disable/reload scenarios

### Enhanced Features
- **Error Recovery**: All major functions now wrapped in error handling with debug stack traces
- **User Messages**: Clear distinction between debug messages and user-facing messages
- **Memory Tracking**: Status command now shows addon memory usage
- **Tooltip Improvements**: Minimap button tooltip shows version and description
- **Options Frame**: Better visual presentation with icons and version display

### Technical Improvements
- **SafeCall Wrapper**: All critical functions protected with pcall error handling
- **Update Loop Management**: Proper start/stop functionality for engine update loop
- **Event Cleanup**: Better event management and cleanup procedures
- **Debug Mode**: Enhanced debug output with stack traces when enabled
- **Code Standards**: Following WoW addon best practices for error handling

### Bug Fixes
- **Stability**: Improved overall addon stability with comprehensive error handling
- **UI Robustness**: Better handling of UI edge cases and error conditions
- **Memory Management**: Proper cleanup of frames and event handlers

### User Experience
- **Professional Polish**: Version numbers and proper branding throughout UI
- **Clear Feedback**: Better user communication with colored status messages
- **Reload Support**: Ability to reload configuration without full addon restart
- **Status Information**: Comprehensive status display including memory usage


## [0.0.2] - 2024-07-10

### Added - Major Rule Expansion
- **8 new restoration druid rules** addressing commonly overlooked abilities:
  - **Ironbark**: Damage reduction cooldown suggestions
  - **Efflorescence**: Ground-targeted persistent AoE healing
  - **Tranquility**: Major emergency healing cooldown
  - **Incarnation: Tree of Life**: Transformation cooldown for high damage phases
  - **Nature's Swiftness**: Instant cast spell proc
  - **Barkskin**: Self-defense damage reduction
  - **Flourish**: HoT duration extension for multiple expiring effects
  - **Trinket Usage**: Active healing trinket detection and suggestions

### Enhanced Features
- **Priority System**: Updated with 13 total rules in optimal priority order
- **Trinket Tracking**: Monitors both trinket slots (13 & 14) for active healing effects
- **Combat Log Integration**: Enhanced tracking for Efflorescence placement and duration
- **Buff Monitoring**: Expanded player buff tracking for all new defensive/healing procs
- **Intelligent Suggestions**: Context-aware rules (e.g., Tranquility for 4+ damaged allies)

### Technical Improvements
- **Tracker.lua**: Added comprehensive spell ID definitions for all new abilities
- **Engine.lua**: Restructured priority evaluation with proper ordering
- **Core.lua**: Extended default rule configuration
- **UI.lua**: Enhanced options frame to accommodate new rules (increased height)
- **Config.lua**: Updated help text and rule management for new abilities

### Rule Logic Details
- **Tranquility**: Triggered when 4+ allies recently took damage (emergency healing)
- **Incarnation**: Suggested during high damage phases (3+ recent damage)
- **Ironbark**: Suggested when target needs damage reduction and doesn't have it
- **Efflorescence**: Suggested when not active and 2+ allies took damage
- **Flourish**: Suggested when 2+ HoTs are expiring soon (within 6 seconds)
- **Nature's Swiftness**: Suggested when available for instant cast needs
- **Barkskin**: Suggested when player is in combat for self-defense
- **Trinket**: Suggested when healing trinkets are off cooldown

### Compatibility
- All new features maintain backward compatibility
- Existing rule configurations preserved
- No breaking changes to existing functionality

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
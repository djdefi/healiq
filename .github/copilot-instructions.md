# HealIQ WoW Addon Development Instructions

**HealIQ** is a smart spell suggestion addon for Restoration Druids in World of Warcraft, written in Lua using the WoW AddOn API.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

- Bootstrap, build, and test the repository:
  - `./setup-dev.sh` - NEVER CANCEL: Takes 2-3 minutes. Set timeout to 300+ seconds.
  - `luacheck *.lua` - Run linting (takes <1 second)
  - `lua5.1 test_runner.lua` - NEVER CANCEL: Run main test suite, takes <5 seconds. Set timeout to 30+ seconds.
  - `lua5.1 test_loading_order.lua` - Run loading order regression tests (takes <1 second)
  - `lua5.1 test_packaging.lua` - Run packaging validation tests (takes <1 second)
  - `lua5.1 validate_runner.lua` - Run quick validation (takes <1 second)

- Development workflow commands:
  - `luacheck *.lua` - Run linting on all Lua files
  - `lua5.1 Tests.lua` - Run basic tests (may fail outside test runner environment)
  - `./setup-dev.sh` - Reinstall development dependencies if needed

## Validation

- ALWAYS manually validate any new code by running the complete test suite after making changes.
- ALWAYS run through at least one complete validation scenario after making changes:
  1. Run `luacheck *.lua` to verify no linting errors
  2. Run `lua5.1 test_runner.lua` to verify all 150+ tests pass
  3. Run `lua5.1 test_loading_order.lua` to verify addon loading order
  4. Run `lua5.1 test_packaging.lua` to verify packaging configuration
  5. Run `lua5.1 validate_runner.lua` to verify quick validation passes
- You cannot run the addon outside of World of Warcraft, but the test suite provides comprehensive mocked validation.
- The addon requires extensive WoW API mocking (CreateFrame, GetTime, UnitHealth, etc.) - use the existing test infrastructure rather than trying to create minimal mocks.
- For full functionality testing, ALWAYS use `lua5.1 test_runner.lua` which provides complete WoW API simulation.
- Manual validation without the test runner is limited to syntax checking only.
- Always run `luacheck *.lua` before you are done or the CI (.github/workflows/test.yml) will fail.
- NEVER modify the test mocking infrastructure in test_runner.lua or WoWAPIMock.lua unless specifically working on test improvements.

## Critical Packaging Guidelines

- **CRITICAL**: After any file structure changes, ALWAYS run `lua5.1 test_packaging.lua` to prevent distribution issues
- **TOC-Packaging Sync**: Every file listed in `HealIQ.toc` MUST be included in `.pkgmeta` move-folders section
- **Missing Files Prevention**: The v0.1.12 critical issue was caused by missing `rules/` directory and `Performance.lua`/`Validation.lua` files in `.pkgmeta`
- **When adding new files**:
  1. Add the file to `HealIQ.toc` in the correct loading order position
  2. Add the file to `.pkgmeta` move-folders → HealIQ section 
  3. If adding a new directory, include the directory name in `.pkgmeta`
  4. Run `lua5.1 test_packaging.lua` to verify packaging consistency
- **When removing files**:
  1. Remove from `HealIQ.toc` first
  2. Remove from `.pkgmeta` move-folders section
  3. Run `lua5.1 test_packaging.lua` to verify no broken references

## Critical Build and Test Information

- **CRITICAL**: All build and test commands complete in under 5 seconds - any longer indicates an issue
- **NEVER CANCEL**: Setup script takes 2-3 minutes for dependency installation only
- **Build Time**: No compilation needed - this is a pure Lua project
- **Test Time**: Complete test suite runs 154 tests in under 1 second  
- **Linting Time**: Luacheck processes all files in under 1 second
- **Loading Test Time**: Loading order validation completes in under 1 second

## Project Structure

### Core Architecture
- `Core.lua` - Main addon initialization and event handling
- `Engine.lua` - Priority logic system for spell suggestions  
- `UI.lua` - User interface display and interaction
- `Tracker.lua` - Tracks spells, buffs, cooldowns, and combat events
- `Config.lua` - Slash commands and configuration management
- `Logging.lua` - Logging and diagnostic systems
- `Performance.lua` - Performance monitoring and optimization

### Rule System
- `rules/BaseRule.lua` - Base class for all rule implementations
- `rules/HealingCooldowns.lua` - Healing cooldown management rules
- `rules/DefensiveCooldowns.lua` - Defensive cooldown rules  
- `rules/AoERules.lua` - Area-of-effect healing rules
- `rules/UtilityRules.lua` - Utility spell rules
- `rules/OffensiveRules.lua` - Offensive capability rules

### Testing Infrastructure
- `Tests.lua` - Main test cases (154 total tests)
- `test_runner.lua` - Primary test execution with WoW API mocking
- `test_loading_order.lua` - Regression tests for addon loading order  
- `test_packaging.lua` - Packaging configuration validation tests
- `validate_runner.lua` - Quick CI validation
- `WoWAPIMock.lua` - Mock WoW API for testing outside the game

### Configuration Files
- `HealIQ.toc` - WoW addon metadata and file loading order
- `.luacheckrc` - Luacheck linting configuration
- `.pkgmeta` - CurseForge packaging configuration

## Common Development Tasks

### Making Code Changes
1. Make your changes to the relevant Lua files
2. Run `luacheck *.lua` to check for linting issues
3. Run `lua5.1 test_runner.lua` to verify tests still pass
4. If adding new rules, ensure they extend from `rules/BaseRule.lua`
5. If modifying loading order, run `lua5.1 test_loading_order.lua`
6. **If modifying file structure, run `lua5.1 test_packaging.lua` to verify packaging consistency**

### Adding New Files or Directories
1. Add the file to `HealIQ.toc` in the correct loading order position
2. Add the file or directory to `.pkgmeta` move-folders → HealIQ section
3. Run `lua5.1 test_packaging.lua` to verify packaging consistency
4. If adding new rules, ensure they extend from `rules/BaseRule.lua`
5. Add tests for new functionality in `Tests.lua`
6. Run full test suite to verify integration

### Removing Files or Directories  
1. Remove from `HealIQ.toc` first
2. Remove from `.pkgmeta` move-folders section
3. Run `lua5.1 test_packaging.lua` to verify no broken references
4. Remove related tests from `Tests.lua`
5. Run full test suite to verify no broken dependencies

### Debugging Issues
1. Enable debug mode: Set `HealIQ.debug = true` in Core.lua
2. Use logging functions from `Logging.lua`
3. Run `lua5.1 validate_runner.lua` for quick health checks
4. Check loading order with `lua5.1 test_loading_order.lua`

## Validation Scenarios

After making any changes, ALWAYS validate using these scenarios:

### Scenario 1: Basic Functionality Test
```bash
luacheck *.lua
lua5.1 test_runner.lua
```
Expected: Linting passes with 0 errors, tests show "All tests passed!" with 154/154 success rate.

### Scenario 2: Loading Order Validation  
```bash
lua5.1 test_loading_order.lua
```
Expected: Output shows "✓ All loading order tests passed!" with 3/3 tests passed.

### Scenario 3: Packaging Configuration Validation
```bash
lua5.1 test_packaging.lua
```
Expected: Output shows "✅ All packaging validation tests passed!" with 8/8 tests passed.

### Scenario 4: Quick Health Check
```bash
lua5.1 validate_runner.lua
```
Expected: Output shows "Quick validation completed successfully".

### Scenario 5: Full CI Pipeline Simulation
```bash
# Syntax check
for file in *.lua; do luac -p "$file" || exit 1; done
# Linting  
luacheck *.lua
# All tests
lua5.1 test_runner.lua && lua5.1 test_loading_order.lua && lua5.1 test_packaging.lua && lua5.1 validate_runner.lua
```
Expected: All commands succeed with no errors.

### Scenario 6: Simple Manual Validation (No WoW API Required)
```lua
lua5.1 -e '
local files = {"Core.lua", "Engine.lua", "UI.lua", "Tracker.lua", "Config.lua"}
print("=== Manual Syntax Validation ===")
for _, file in ipairs(files) do
    local f = io.open(file, "r") 
    if f then
        f:close()
        local result = os.execute("luac -p " .. file)
        if result == 0 then
            print("✓", file, "syntax valid")
        else
            print("✗", file, "syntax error")
        end
    else
        print("✗", file, "not found")
    end
end
print("✓ Manual syntax validation completed")
'
```
Expected: All files show "✓ [filename] syntax valid".

## Technology Stack and Dependencies

### Required Software
- **Lua 5.1** - Primary runtime (installed via setup-dev.sh)
- **luarocks** - Lua package manager (installed via setup-dev.sh)  
- **luacheck** - Lua linting tool (installed via setup-dev.sh)

### Installation Commands (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

### Installation Commands (macOS with Homebrew)
```bash
brew install lua luarocks  
luarocks install luacheck
```

## CI Pipeline Requirements

The GitHub Actions workflow (`.github/workflows/test.yml`) requires:
- All Lua files pass syntax checking with `luac -p`
- All files pass luacheck linting with 0 errors
- Addon structure validation (HealIQ.toc format and file references)
- Version consistency between HealIQ.toc and Core.lua
- All loading order tests pass
- **All packaging validation tests pass (prevents v0.1.12-style distribution issues)**
- All logic tests pass (154/154 success rate required)
- Coverage analysis completes successfully

## Packaging Configuration Management

**CRITICAL**: The v0.1.12 issue was caused by incomplete `.pkgmeta` configuration leading to missing files in distribution packages.

### .pkgmeta File Structure
The `.pkgmeta` file controls what gets packaged for CurseForge/WoWInterface distribution:
- `move-folders` → `HealIQ` section: Lists all files/directories to include
- `ignore` section: Lists files/directories to exclude from packaging

### Packaging Validation Rules
1. **Every file in `HealIQ.toc` MUST be listed in `.pkgmeta` move-folders section**
2. **Critical directories like `rules/` must be explicitly included**
3. **Test files MUST be excluded** via the ignore section
4. **Version consistency** between TOC and Core.lua files must be maintained

### Common Packaging Mistakes to Avoid
- ❌ Adding files to TOC without updating .pkgmeta (causes v0.1.12-style errors)
- ❌ Missing directory entries in .pkgmeta (causes entire directories to be missing from packages)
- ❌ Including test files in packages (bloats addon size unnecessarily)
- ❌ Missing ignore entries for development-only files
- ❌ Hardcoded addon paths that break in different install locations
- ❌ Including build artifacts, coverage files, or backup files in packages
- ❌ Large files (>1MB) being included without justification
- ❌ Version mismatches between different files referencing the addon version

### Packaging Validation Test Coverage
The `test_packaging.lua` validates:
- TOC-pkgmeta consistency (prevents missing file errors)
- File existence verification
- Critical files inclusion check
- Version consistency validation  
- Proper ignore list configuration
- Dependency resolution validation
- Hardcoded path detection
- File size sanity checks
- TOC metadata completeness

### Related Validation Tools
- `./quick_packaging_check.sh` - Fast packaging sanity check for file changes
- `lua5.1 test_loading_order.lua` - Validates addon loading sequence
- CI pipeline automatically runs all packaging validation tests

## Common Command Reference

### Quick Reference Commands
```bash
# Development setup (run once)
./setup-dev.sh

# Code validation (run frequently)  
luacheck *.lua
lua5.1 test_runner.lua

# Quick packaging check (run after file structure changes)
./quick_packaging_check.sh

# Full validation (run before commits)
luacheck *.lua && lua5.1 test_runner.lua && lua5.1 test_loading_order.lua && lua5.1 test_packaging.lua && lua5.1 validate_runner.lua
```

### File Structure at Repository Root
```
HealIQ/
├── .github/workflows/test.yml    # CI pipeline
├── .luacheckrc                   # Linting configuration  
├── HealIQ.toc                   # WoW addon metadata
├── Core.lua                     # Main addon initialization
├── Engine.lua                   # Spell suggestion logic
├── UI.lua                       # User interface
├── Tracker.lua                  # Combat event tracking
├── Config.lua                   # Configuration and commands
├── Logging.lua                  # Logging system
├── Performance.lua              # Performance monitoring
├── rules/                       # Rule system modules
├── Tests.lua                    # Test cases
├── test_runner.lua              # Test execution
├── setup-dev.sh                 # Development setup script
├── README.md                    # Project documentation  
└── INSTALL.md                   # Installation guide
```

## Important Notes

- This is a **World of Warcraft addon** - it cannot be executed outside of WoW, but comprehensive testing is available through mocked environments
- All tests run in **under 5 seconds** - longer execution times indicate problems
- The addon targets **Restoration Druids** specifically in WoW  
- **Loading order matters** - always run loading order tests after structural changes
- **Version consistency** is enforced between HealIQ.toc and Core.lua
- **Mock testing environment** allows full validation without needing World of Warcraft installed
#!/bin/bash
# Development setup script for HealIQ
# Run this script to set up your local development environment with linting

set -e

echo "🚀 Setting up HealIQ development environment..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ This doesn't appear to be a git repository"
    echo "Please run this script from the root of the HealIQ repository"
    exit 1
fi

# Install Lua and luacheck if needed (Ubuntu/Debian)
if command -v apt-get &> /dev/null; then
    echo "📦 Installing Lua and development tools (requires sudo)..."
    if ! command -v lua5.1 &> /dev/null || ! command -v luarocks &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y lua5.1 luarocks
    fi
    
    if ! command -v luacheck &> /dev/null; then
        echo "📦 Installing luacheck..."
        sudo luarocks install luacheck
    fi
elif command -v brew &> /dev/null; then
    # macOS with Homebrew
    echo "📦 Installing Lua and development tools via Homebrew..."
    if ! command -v lua &> /dev/null; then
        brew install lua
    fi
    
    if ! command -v luarocks &> /dev/null; then
        brew install luarocks
    fi
    
    if ! command -v luacheck &> /dev/null; then
        echo "📦 Installing luacheck..."
        luarocks install luacheck
    fi
else
    echo "ℹ️  Please install Lua, LuaRocks, and luacheck manually:"
    echo "   - Lua 5.1+: https://www.lua.org/download.html"
    echo "   - LuaRocks: https://luarocks.org/"
    echo "   - luacheck: luarocks install luacheck"
fi

# Verify installations
echo "🔍 Verifying installations..."
if ! command -v lua &> /dev/null && ! command -v lua5.1 &> /dev/null; then
    echo "❌ Lua is not installed or not in PATH"
    exit 1
fi

if ! command -v luacheck &> /dev/null; then
    echo "❌ luacheck is not installed or not in PATH"
    exit 1
fi

# Set up pre-commit hook (should already exist from our repo)
if [ ! -f ".git/hooks/pre-commit" ]; then
    echo "⚠️  Pre-commit hook not found, this is unexpected"
    echo "The hook should be included in the repository"
else
    echo "✅ Pre-commit hook is already set up"
fi

# Test that linting works
echo "🧹 Testing linting setup..."
if luacheck *.lua > /dev/null; then
    echo "✅ Linting test passed"
else
    echo "❌ Linting test failed - please check your .lua files"
    echo "Run 'luacheck *.lua' to see specific issues"
fi

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "💡 Useful commands:"
echo "   luacheck *.lua          # Run linting manually"
echo "   lua5.1 test_runner.lua  # Run the test suite"
echo "   lua5.1 Tests.lua        # Run main tests"
echo ""
echo "📝 The pre-commit hook will automatically run linting before each commit."
echo "   To bypass it (not recommended): git commit --no-verify"
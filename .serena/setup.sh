#!/bin/bash

# Serena Development Environment Setup for NoteAI

echo "Setting up Serena for NoteAI development..."

# Check Python installation
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required. Please install Python 3.11 or higher."
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
REQUIRED_VERSION="3.11"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Python $REQUIRED_VERSION or higher is required. Found Python $PYTHON_VERSION"
    exit 1
fi

# Install uv if not present
if ! command -v uv &> /dev/null; then
    echo "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Clone Serena repository
if [ ! -d "serena" ]; then
    echo "Cloning Serena repository..."
    git clone https://github.com/oraios/serena.git
fi

cd serena

# Create Serena configuration directory
mkdir -p ~/.serena

# Copy configuration template if not exists
if [ ! -f "~/.serena/serena_config.yml" ]; then
    echo "Creating Serena configuration..."
    cp src/serena/resources/serena_config.template.yml ~/.serena/serena_config.yml
fi

# Create project configuration for NoteAI
echo "Creating NoteAI project configuration..."
mkdir -p /Users/hashimotokenichi/Desktop/NoteAI/.serena
cat > /Users/hashimotokenichi/Desktop/NoteAI/.serena/project.yml << EOF
name: NoteAI
description: Voice Note Processing Application with AI

# Language server configuration
language_servers:
  - language: python
    enabled: true
  - language: typescript
    enabled: true
  - language: go
    enabled: false

# File patterns to include/exclude
include_patterns:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
  - "Package.swift"
  - "*.md"
  - ".kiro/**/*"

exclude_patterns:
  - ".build/**"
  - ".swiftpm/**"
  - "DerivedData/**"
  - "*.xcodeproj/**"
  - "node_modules/**"

# Project-specific tools configuration
tools:
  execute_shell_command:
    allowed_commands:
      - swift
      - swift test
      - swift build
      - swift package
      - git
      - uv
      - python
      - npm
    
# Memory categories for better organization
memory_categories:
  - architecture
  - development
  - features
  - testing
EOF

echo "Serena setup complete!"
echo ""
echo "To use Serena with NoteAI:"
echo "1. Start MCP server: uv run serena-mcp-server"
echo "2. Or integrate with Claude Code:"
echo "   claude mcp add serena -- uv run --directory $(pwd) serena-mcp-server --context ide-assistant --project /Users/hashimotokenichi/Desktop/NoteAI"
echo ""
echo "For more information, see .serena/README.md"
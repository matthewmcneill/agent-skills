#!/usr/bin/env zsh

# init.sh — Bootstrap script for skill-manager

# Source common utilities
# Use absolute path relative to script directory
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
# Expecting $1 to be a JSON string like '{"force": true}'
INPUT="${1:-"{}"}"
# Ensure input is valid JSON
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

FORCE=$(echo "$INPUT" | jq -r '.force // false')

HOME_DIR=$(resolve_skill_manager_home)
REGISTRY_DIR="$HOME_DIR/registry"
CONFIG_FILE="$HOME_DIR/config.json"
REGISTRY_FILE="$REGISTRY_DIR/registry.json"
CACHE_DIR="$HOME_DIR/cache"

# Check if already initialized
if [[ -d "$REGISTRY_DIR" && "$FORCE" != "true" ]]; then
    json_error "Registry already exists at $REGISTRY_DIR" "Use {\"force\": true} to re-initialize"
fi

# Create directory structure
mkdir -p "$HOME_DIR" || json_error "Failed to create home directory" "Check permissions for $HOME_DIR"
mkdir -p "$CACHE_DIR" || json_error "Failed to create cache directory" "Check permissions for $CACHE_DIR"

# Handle re-initialization
if [[ "$FORCE" == "true" && -d "$REGISTRY_DIR" ]]; then
    # We could be more careful, but --force implies overwrite
    rm -rf "$REGISTRY_DIR"
fi

# Initialize registry
mkdir -p "$REGISTRY_DIR"
(cd "$REGISTRY_DIR" && git init -q) || json_error "Failed to initialize git in registry" "Check if git is installed"

# Create registry.json
echo '{"version": 1, "skills": {}}' > "$REGISTRY_FILE"

# Create config.json if it doesn't exist or if forced
if [[ ! -f "$CONFIG_FILE" || "$FORCE" == "true" ]]; then
    echo '{"version": 1, "remotes": []}' > "$CONFIG_FILE"
fi

# Return success JSON
json_response "status" "initialized" \
              "registryPath" "$REGISTRY_DIR" \
              "created" "config.json, registry/, cache/"

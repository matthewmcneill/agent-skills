#!/usr/bin/env zsh

# common.sh — Shared utilities for skill-manager

# Dependency check: jq
if ! command -v jq >/dev/null 2>&1; then
    echo '{"error": "jq not found", "hint": "Please install jq (e.g., brew install jq)"}' >&2
    exit 1
fi

# Path resolver
resolve_skill_manager_home() {
    echo "${SKILL_MANAGER_HOME:-$HOME/.gemini/skill-library}"
}

# JSON response helper
# Usage: json_response key1 value1 key2 value2 ...
json_response() {
    local -A data
    while [[ $# -gt 0 ]]; do
        data[$1]=$2
        shift 2
    done
    
    # Build jq arguments
    local args=()
    for k in ${(k)data}; do
        args+=("--arg" "$k" "$data[$k]")
    done
    
    jq -n "${args[@]}" '$ARGS.named'
}

# JSON error helper
# Usage: json_error "message" "hint"
json_error() {
    local message="$1"
    local hint="$2"
    echo "$(json_response "error" "$message" "hint" "$hint")" >&2
    exit 1
}

# Config loader
load_config() {
    local home
    home=$(resolve_skill_manager_home)
    local config_path="$home/config.json"
    
    if [[ ! -f "$config_path" ]]; then
        json_error "Config file not found" "Run scripts/init.sh first"
    fi
    
    # Export key paths/vars
    export SKILL_MANAGER_HOME="$home"
    export SKILL_REGISTRY_PATH="$home/registry"
    export SKILL_CACHE_PATH="$home/cache"
}

# GitHub URL parser
# decomposes https://github.com/org/repo/tree/branch/path into repo, branch, path
parse_github_url() {
    local url="$1"
    # Remove trailing slash
    url="${url%/}"
    
    local repo branch path
    
    if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.*)$ ]]; then
        repo="https://github.com/${match[1]}/${match[2]}.git"
        branch="${match[3]}"
        path="${match[4]}"
    elif [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)$ ]]; then
        repo="https://github.com/${match[1]}/${match[2]}.git"
        branch="main"
        path=""
    else
        return 1
    fi
    
    echo "repo='$repo' branch='$branch' path='$path'"
}

# SKILL.md frontmatter parser
# Returns JSON: {"name": "...", "description": "..."}
parse_frontmatter() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo '{"error": "File not found"}'
        return 1
    fi
    
    # Extract block between --- and ---
    local frontmatter
    # Use sed to get lines between the first two ---
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')
    
    if [[ -z "$frontmatter" ]]; then
        echo '{"name": "", "description": ""}'
        return 0
    fi
    
    # Simple YAML key extraction
    local name=$(echo "$frontmatter" | grep "^name:" | head -n 1 | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//;s/^'\''//;s/'\''$//')
    local description=$(echo "$frontmatter" | grep "^description:" | head -n 1 | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//;s/^'\''//;s/'\''$//')
    
    jq -n --arg name "$name" --arg desc "$description" '{name: $name, description: $desc}'
}

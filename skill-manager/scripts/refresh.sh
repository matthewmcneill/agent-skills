#!/usr/bin/env zsh

# refresh.sh — Update or initially clone remote repo caches

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

REMOTE_NAME=$(echo "$INPUT" | jq -r '.remote // "all"')

# Load global config
load_config
CONFIG_FILE="$SKILL_MANAGER_HOME/config.json"
mkdir -p "$SKILL_CACHE_PATH"

REMOTES_JSON=$(jq -c '.remotes[]' "$CONFIG_FILE")

REFRESHED_RESULTS=()

while IFS= read -r remote_json; do
    name=$(echo "$remote_json" | jq -r '.name')
    url=$(echo "$remote_json" | jq -r '.url')
    skills_path=$(echo "$remote_json" | jq -r '.skillsPath // "skills/"')
    searchable=$(echo "$remote_json" | jq -r '.searchable // false')
    
    # Filter if a specific remote was requested
    if [[ "$REMOTE_NAME" != "all" && "$REMOTE_NAME" != "$name" ]]; then
        continue
    fi
    
    CACHE_PATH="$SKILL_CACHE_PATH/$name"
    STATUS="updated"
    
    if [[ ! -d "$CACHE_PATH" ]]; then
        # Initial clone
        mkdir -p "$CACHE_PATH"
        if git clone -q --filter=blob:none --sparse "$url" "$CACHE_PATH"; then
            STATUS="cloned"
        else
            REFRESHED_RESULTS+=("$(jq -n --arg name "$name" --arg status "failed" --arg error "Clone failed" '{name: $name, status: $status, error: $error}')")
            continue
        fi
    fi
    
    # Update
    (
        cd "$CACHE_PATH" || exit 1
        git fetch -q origin 2>/dev/null
        # Try to checkout main or master
        git checkout -q origin/main 2>/dev/null || git checkout -q origin/master 2>/dev/null
        
        if [[ "$searchable" == "true" ]]; then
            # Set sparse checkout to include the skills path
            # Remove trailing slash for git sparse-checkout
            CLEAN_PATH="${skills_path%/}"
            git sparse-checkout set "$CLEAN_PATH" 2>/dev/null
        fi
    )
    
    # Count skills
    SKILL_COUNT=$(find "$CACHE_PATH" -name "SKILL.md" | wc -l | tr -d ' ')
    
    REFRESHED_RESULTS+=("$(jq -n \
        --arg name "$name" \
        --arg status "$STATUS" \
        --argjson count "$SKILL_COUNT" \
        --argjson searchable "$searchable" \
        '{name: $name, status: $status, totalSkills: $count, searchable: $searchable}')")
    
done <<EOF
$REMOTES_JSON
EOF

# Build final JSON response
jq -n --argjson refreshed "$(printf '%s\n' "${REFRESHED_RESULTS[@]}" | jq -s .)" '{refreshed: $refreshed}'

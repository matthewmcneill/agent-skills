#!/usr/bin/env zsh

# add-remote.sh — Register a new remote skill repository

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

NAME=$(echo "$INPUT" | jq -r '.name // empty')
URL=$(echo "$INPUT" | jq -r '.url // empty')
TRUST_TIER=$(echo "$INPUT" | jq -r '.trustTier // 2')
SKILLS_PATH=$(echo "$INPUT" | jq -r '.skillsPath // "skills/"')
FORCE=$(echo "$INPUT" | jq -r '.force // false')
REFRESH=$(echo "$INPUT" | jq -r '.refresh // false')

if [[ -z "$NAME" ]]; then
    json_error "Missing remote name" "Provide 'name' in JSON input"
fi

if [[ -z "$URL" ]]; then
    json_error "Missing remote URL" "Provide 'url' in JSON input"
fi

# Simple URL validation
if [[ ! "$URL" =~ ^(https?|git|ssh):// || "$URL" =~ \.git$ ]] || [[ "$URL" =~ ^[^/]+@[^:]+:.+ ]]; then
    # Acceptable git URL formats
    :
else
    # Basic check, can be improved
    if [[ ! "$URL" =~ ^/ ]]; then # Local paths are also okay for testing
        json_error "Invalid Git URL" "Must be a valid https, git, or ssh URL"
    fi
fi

# Load global config
load_config
CONFIG_FILE="$SKILL_MANAGER_HOME/config.json"

# Check if remote already exists
EXISTING=$(jq -r ".remotes[] | select(.name == \"$NAME\") | .name" "$CONFIG_FILE")

if [[ -n "$EXISTING" && "$FORCE" != "true" ]]; then
    json_error "Remote '$NAME' already exists" "Use force:true to update"
fi

# Prepare new remote object
NEW_REMOTE=$(jq -n \
    --arg name "$NAME" \
    --arg url "$URL" \
    --argjson trust "$TRUST_TIER" \
    --arg path "$SKILLS_PATH" \
    '{name: $name, url: $url, defaultTrust: $trust, skillsPath: $path, searchable: true}')

TMP_CONFIG=$(mktemp)
if [[ -n "$EXISTING" ]]; then
    # Replace existing
    jq --arg name "$NAME" --argjson new "$NEW_REMOTE" \
       '.remotes = [.remotes[] | if .name == $name then $new else . end]' \
       "$CONFIG_FILE" > "$TMP_CONFIG"
else
    # Append new
    jq --argjson new "$NEW_REMOTE" \
       '.remotes += [$new]' \
       "$CONFIG_FILE" > "$TMP_CONFIG"
fi

mv "$TMP_CONFIG" "$CONFIG_FILE"

# Trigger refresh if requested
if [[ "$REFRESH" == "true" ]]; then
    "$SCRIPT_DIR/refresh.sh" "$(jq -n --arg name "$NAME" '{remote: $name}')" >/dev/null
fi

TOTAL_REMOTES=$(jq '.remotes | length' "$CONFIG_FILE")

json_response "status" "added" \
              "name" "$NAME" \
              "url" "$URL" \
              "trustTier" "$TRUST_TIER" \
              "totalRemotes" "$TOTAL_REMOTES"

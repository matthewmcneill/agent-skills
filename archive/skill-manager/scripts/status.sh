#!/usr/bin/env zsh

# status.sh — Show sync status per skill

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

PROJECT_PATH=$(echo "$INPUT" | jq -r '.project // empty')

if [[ -z "$PROJECT_PATH" ]]; then
    json_error "Missing project path" "Provide 'project' in JSON input"
fi

# Load global config
load_config

WORKSPACE_FILE="$PROJECT_PATH/.agents/skills/skill-manager-workspace/workspace.json"
if [[ ! -f "$WORKSPACE_FILE" ]]; then
    json_error "workspace.json not found" "Run scripts/add.sh or scripts/install.sh first"
fi

SKILLS_JSON=$(jq -c '.skills' "$WORKSPACE_FILE")
declare -A RESULTS
SKILL_NAMES=($(echo "$SKILLS_JSON" | jq -r 'keys[]'))

# Load registry.json for comparison
REGISTRY_JSON=$(cat "$SKILL_REGISTRY_PATH/registry.json")

for NAME in $SKILL_NAMES; do
    PROJECT_SKILL_DIR="$PROJECT_PATH/.agents/skills/$NAME"
    REGISTRY_SKILL_DIR="$SKILL_REGISTRY_PATH/$NAME"
    
    REG_SKILL_INFO=$(echo "$REGISTRY_JSON" | jq -c ".skills[\"$NAME\"] // empty")
    
    if [[ -z "$REG_SKILL_INFO" ]]; then
        RESULTS[$NAME]="{\"status\": \"missing-in-registry\"}"
        continue
    fi
    
    if [[ ! -d "$PROJECT_SKILL_DIR" ]]; then
        RESULTS[$NAME]="{\"status\": \"missing-in-project\"}"
        continue
    fi
    
    # Compare project vs registry
    DIFF_OUT=$(diff -r "$REGISTRY_SKILL_DIR" "$PROJECT_SKILL_DIR" 2>/dev/null)
    
    SYNC_STATUS="up-to-date"
    if [[ -n "$DIFF_OUT" ]]; then
        # For MVP, we'll just say modified-locally if there's a diff
        # A better implementation would check timestamps or hashes to see if registry is ahead
        SYNC_STATUS="modified-locally"
    fi
    
    TYPE=$(echo "$REG_SKILL_INFO" | jq -r '.type')
    ORIGIN=$(echo "$REG_SKILL_INFO" | jq -c '.origin')
    
    RESULTS[$NAME]="{\"syncStatus\": \"$SYNC_STATUS\", \"type\": \"$TYPE\", \"origin\": $ORIGIN}"
done

# Build response
RESULTS_JSON="["
FIRST=true
for K in "${(k)RESULTS[@]}"; do
    if [[ "$FIRST" == "false" ]]; then RESULTS_JSON+=","; fi
    ITEM=$(echo "${RESULTS[$K]}" | jq --arg name "$K" '. + {name: $name}')
    RESULTS_JSON+="$ITEM"
    FIRST=false
done
RESULTS_JSON+="]"

echo "{\"skills\": $RESULTS_JSON}"

#!/usr/bin/env zsh

# pull.sh — Registry → project

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

PROJECT_PATH=$(echo "$INPUT" | jq -r '.project // empty')
SKILLS_TO_PULL=($(echo "$INPUT" | jq -r '.skills[]? // empty'))

if [[ -z "$PROJECT_PATH" ]]; then
    json_error "Missing project path" "Provide 'project' in JSON input"
fi

# Load global config
load_config

WORKSPACE_FILE="$PROJECT_PATH/.agents/skills/skill-manager-workspace/workspace.json"
if [[ ! -f "$WORKSPACE_FILE" ]]; then
    json_error "workspace.json not found" "Run scripts/add.sh or scripts/install.sh first"
fi

# If no skills specified, get all from workspace
if [[ ${#SKILLS_TO_PULL[@]} -eq 0 ]]; then
    SKILLS_TO_PULL=($(jq -r '.skills | keys[]' "$WORKSPACE_FILE"))
fi

declare -A RESULTS

for NAME in $SKILLS_TO_PULL; do
    PROJECT_SKILL_DIR="$PROJECT_PATH/.agents/skills/$NAME"
    REGISTRY_SKILL_DIR="$SKILL_REGISTRY_PATH/$NAME"
    
    if [[ ! -d "$REGISTRY_SKILL_DIR" ]]; then
        RESULTS[$NAME]="{\"status\": \"error\", \"message\": \"Skill not found in registry\"}"
        continue
    fi
    
    # Compare project vs registry to report changes
    DIFF_OUT=$(diff -r "$PROJECT_SKILL_DIR" "$REGISTRY_SKILL_DIR" 2>/dev/null)
    FILES_CHANGED=$(echo "$DIFF_OUT" | grep -c "^diff" || echo "0")
    
    if [[ -z "$DIFF_OUT" ]]; then
        RESULTS[$NAME]="{\"status\": \"up-to-date\", \"filesChanged\": 0}"
        continue
    fi
    
    # Copy registry -> project
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$REGISTRY_SKILL_DIR/" "$PROJECT_SKILL_DIR/"
    else
        rm -rf "$PROJECT_SKILL_DIR"
        mkdir -p "$PROJECT_SKILL_DIR"
        cp -R "$REGISTRY_SKILL_DIR/" "$PROJECT_SKILL_DIR/"
    fi
    
    RESULTS[$NAME]="{\"status\": \"updated\", \"filesChanged\": $FILES_CHANGED}"
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

echo "{\"status\": \"pulled\", \"skills\": $RESULTS_JSON}"

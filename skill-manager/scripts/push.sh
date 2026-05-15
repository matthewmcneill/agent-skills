#!/usr/bin/env zsh

# push.sh — Project edits → registry (with fork detection)

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

PROJECT_PATH=$(echo "$INPUT" | jq -r '.project // empty')
SKILLS_TO_PUSH=($(echo "$INPUT" | jq -r '.skills[]? // empty'))
REMOTE_PUSH=$(echo "$INPUT" | jq -r '.remote // false')

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
if [[ ${#SKILLS_TO_PUSH[@]} -eq 0 ]]; then
    SKILLS_TO_PUSH=($(jq -r '.skills | keys[]' "$WORKSPACE_FILE"))
fi

declare -A RESULTS
CHANGES_COUNT=0
COMMITTED_SKILLS=()

for NAME in $SKILLS_TO_PUSH; do
    PROJECT_SKILL_DIR="$PROJECT_PATH/.agents/skills/$NAME"
    REGISTRY_SKILL_DIR="$SKILL_REGISTRY_PATH/$NAME"
    
    if [[ ! -d "$PROJECT_SKILL_DIR" ]]; then
        RESULTS[$NAME]="{\"status\": \"error\", \"message\": \"Skill not found in project\"}"
        continue
    fi
    
    # Compare project vs registry
    # Use diff -r to see if there are any changes
    DIFF_OUT=$(diff -r "$REGISTRY_SKILL_DIR" "$PROJECT_SKILL_DIR" 2>/dev/null)
    
    if [[ -z "$DIFF_OUT" ]]; then
        RESULTS[$NAME]="{\"status\": \"up-to-date\"}"
        continue
    fi
    
    # Changes detected!
    FILES_CHANGED=$(echo "$DIFF_OUT" | grep -c "^diff" || echo "0")
    
    # Copy project -> registry
    # We use rsync if available, otherwise rm + cp
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$PROJECT_SKILL_DIR/" "$REGISTRY_SKILL_DIR/"
    else
        rm -rf "$REGISTRY_SKILL_DIR"
        mkdir -p "$REGISTRY_SKILL_DIR"
        cp -R "$PROJECT_SKILL_DIR/" "$REGISTRY_SKILL_DIR/"
    fi
    
    # Fork detection logic
    REG_INFO=$(jq -r ".skills[\"$NAME\"]" "$SKILL_REGISTRY_PATH/registry.json")
    CURRENT_TYPE=$(echo "$REG_INFO" | jq -r '.type')
    PREVIOUS_TYPE="$CURRENT_TYPE"
    STATUS="updated"
    
    if [[ "$CURRENT_TYPE" == "imported" ]]; then
        # Flip to forked
        CURRENT_TYPE="forked"
        STATUS="forked"
        
        # Get latest hash from cache to record fork-point
        # For now, we assume the origin info is in the REG_INFO
        ORIGIN=$(echo "$REG_INFO" | jq -c '.origin')
        FORKED_FROM=$(echo "$ORIGIN" | jq -r '.pinnedHash // empty')
        FORKED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Update registry.json info
        NEW_INFO=$(echo "$REG_INFO" | jq --arg type "$CURRENT_TYPE" \
                                       --arg hash "$FORKED_FROM" \
                                       --arg at "$FORKED_AT" \
                                       '.type = $type | .origin.forkedFromHash = $hash | .origin.forkedAt = $at')
        
        TMP_REGISTRY=$(mktemp)
        jq --arg name "$NAME" --argjson info "$NEW_INFO" \
           '.skills[$name] = $info' "$SKILL_REGISTRY_PATH/registry.json" > "$TMP_REGISTRY" && mv "$TMP_REGISTRY" "$SKILL_REGISTRY_PATH/registry.json"
        
        # Update workspace.json too
        TMP_WORKSPACE=$(mktemp)
        jq --arg name "$NAME" --argjson info "$NEW_INFO" \
           '.skills[$name] = $info' "$WORKSPACE_FILE" > "$TMP_WORKSPACE" && mv "$TMP_WORKSPACE" "$WORKSPACE_FILE"
    fi
    
    RESULTS[$NAME]="{\"status\": \"$STATUS\", \"filesChanged\": $FILES_CHANGED, \"previousType\": \"$PREVIOUS_TYPE\"}"
    COMMITTED_SKILLS+=("$NAME")
    CHANGES_COUNT=$((CHANGES_COUNT + 1))
done

COMMIT_HASH=""
REMOTE_PUSHED="false"

if [[ $CHANGES_COUNT -gt 0 ]]; then
    MESSAGE="Update skills: ${(j:, :)COMMITTED_SKILLS} from project"
    (cd "$SKILL_REGISTRY_PATH" && git add . && git commit -m "$MESSAGE")
    COMMIT_HASH=$(cd "$SKILL_REGISTRY_PATH" && git rev-parse HEAD)
    
    if [[ "$REMOTE_PUSH" == "true" ]]; then
        (cd "$SKILL_REGISTRY_PATH" && git push) && REMOTE_PUSHED="true"
    fi
fi

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

echo "{\"status\": \"pushed\", \"skills\": $RESULTS_JSON, \"committed\": $([[ $CHANGES_COUNT -gt 0 ]] && echo "true" || echo "false"), \"commitHash\": \"$COMMIT_HASH\", \"remotePushed\": $REMOTE_PUSHED}"

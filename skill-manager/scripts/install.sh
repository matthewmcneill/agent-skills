#!/usr/bin/env zsh

# install.sh — Materialize all skills listed in workspace.json

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
    # Create empty workspace if missing
    mkdir -p "$(dirname "$WORKSPACE_FILE")"
    echo "{\"version\": 1, \"library\": \"$SKILL_MANAGER_HOME\", \"skills\": {}}" > "$WORKSPACE_FILE"
fi

SKILLS_JSON=$(jq -c '.skills' "$WORKSPACE_FILE")
declare -A RESULTS
SKILL_NAMES=($(echo "$SKILLS_JSON" | jq -r 'keys[]'))

for NAME in $SKILL_NAMES; do
    INFO=$(echo "$SKILLS_JSON" | jq -c ".[\"$NAME\"]")
    TYPE=$(echo "$INFO" | jq -r '.type')
    ORIGIN=$(echo "$INFO" | jq -c '.origin // empty')
    
    PROJECT_SKILL_DIR="$PROJECT_PATH/.agents/skills/$NAME"
    STATUS="installed"
    SOURCE="registry"
    
    # 1. Check Registry
    if [[ ! -d "$SKILL_REGISTRY_PATH/$NAME" ]]; then
        # If missing from registry, try to fetch from origin
        if [[ -n "$ORIGIN" && "$ORIGIN" != "null" ]]; then
            REPO=$(echo "$ORIGIN" | jq -r '.repo')
            BRANCH=$(echo "$ORIGIN" | jq -r '.branch')
            PATH=$(echo "$ORIGIN" | jq -r '.path')
            
            REPO_NAME=$(basename "$REPO" .git)
            CACHE_PATH="$SKILL_CACHE_PATH/$REPO_NAME"
            
            if [[ ! -d "$CACHE_PATH" ]]; then
                git clone -q --filter=blob:none --sparse "$REPO" "$CACHE_PATH" || continue
            fi
            
            (cd "$CACHE_PATH" && git sparse-checkout add "$PATH") || continue
            
            mkdir -p "$SKILL_REGISTRY_PATH/$NAME"
            cp -R "$CACHE_PATH/$PATH/" "$SKILL_REGISTRY_PATH/$NAME/"
            
            # Update registry.json
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            TMP_REGISTRY=$(mktemp)
            jq --arg name "$NAME" \
               --arg type "$TYPE" \
               --argjson origin "$ORIGIN" \
               --arg ts "$TIMESTAMP" \
               '.skills[$name] = {type: $type, origin: $origin, importedAt: $ts}' \
               "$SKILL_REGISTRY_PATH/registry.json" > "$TMP_REGISTRY" && mv "$TMP_REGISTRY" "$SKILL_REGISTRY_PATH/registry.json"
            
            (cd "$SKILL_REGISTRY_PATH" && git add . && git commit -m "Fetch skill $NAME from origin")
            STATUS="fetched"
            SOURCE="origin"
        else
            RESULTS[$NAME]="{\"status\": \"missing\", \"error\": \"No origin found for missing registry skill\"}"
            continue
        fi
    fi
    
    # 2. Copy to Project if missing or check for updates (simplified check for now)
    if [[ ! -d "$PROJECT_SKILL_DIR" ]]; then
        mkdir -p "$PROJECT_SKILL_DIR"
        cp -R "$SKILL_REGISTRY_PATH/$NAME/" "$PROJECT_SKILL_DIR/"
        RESULTS[$NAME]="{\"status\": \"$STATUS\", \"source\": \"$SOURCE\"}"
    else
        # For MVP, we just report up-to-date if directory exists
        # In status.sh we do deeper comparison
        RESULTS[$NAME]="{\"status\": \"up-to-date\"}"
    fi
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

echo "{\"status\": \"installed\", \"skills\": $RESULTS_JSON, \"total\": ${#SKILL_NAMES[@]}}"

#!/usr/bin/env zsh

# add.sh — Add a skill to a project

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

NAME=$(echo "$INPUT" | jq -r '.name // empty')
SOURCE=$(echo "$INPUT" | jq -r '.source // empty')
PROJECT_PATH=$(echo "$INPUT" | jq -r '.project // empty')
URL=$(echo "$INPUT" | jq -r '.url // empty')
FORCE=$(echo "$INPUT" | jq -r '.force // false')

if [[ -z "$PROJECT_PATH" ]]; then
    json_error "Missing project path" "Provide 'project' in JSON input"
fi

# Load global config
load_config

# 1. Handle URL mode (Mode 2)
if [[ -n "$URL" ]]; then
    parsed=$(parse_github_url "$URL")
    if [[ $? -ne 0 ]]; then
        json_error "Invalid GitHub URL" "Format: https://github.com/org/repo/tree/branch/path"
    fi
    eval "$parsed" # Sets $repo, $branch, $path
    
    REPO_NAME=$(basename "$repo" .git)
    CACHE_PATH="$SKILL_CACHE_PATH/$REPO_NAME"
    
    # Check if cached
    if [[ ! -d "$CACHE_PATH" ]]; then
        # Initial sparse clone
        mkdir -p "$SKILL_CACHE_PATH"
        git clone -q --filter=blob:none --sparse "$repo" "$CACHE_PATH" || json_error "Failed to clone repository" "$repo"
    fi
    
    # Widen cone for the specific path
    (cd "$CACHE_PATH" && git sparse-checkout add "$path") || json_error "Failed to add path to sparse-checkout" "$path"
    
    # Identify skill name from path or repo
    if [[ -z "$NAME" ]]; then
        NAME=$(basename "$path")
        [[ -z "$NAME" ]] && NAME="$REPO_NAME"
    fi
    
    SKILL_SRC_DIR="$CACHE_PATH/$path"
    PINNED_HASH=$(cd "$CACHE_PATH" && git rev-parse HEAD)
    
    ORIGIN_JSON=$(jq -n \
        --arg repo "$repo" \
        --arg branch "$branch" \
        --arg path "$path" \
        --arg pinnedHash "$PINNED_HASH" \
        '{repo: $repo, branch: $branch, path: $path, pinnedHash: $pinnedHash}')
else
    # 2. Handle Named mode (Mode 1)
    if [[ -z "$NAME" ]]; then
        json_error "Missing skill name or URL" "Provide 'name' or 'url' in JSON input"
    fi
    
    # Look in registry first
    if [[ -d "$SKILL_REGISTRY_PATH/$NAME" ]]; then
        SKILL_SRC_DIR="$SKILL_REGISTRY_PATH/$NAME"
        # Get provenance from registry.json
        ORIGIN_JSON=$(jq -r ".skills[\"$NAME\"].origin // empty" "$SKILL_REGISTRY_PATH/registry.json")
    elif [[ -n "$SOURCE" && -d "$SKILL_CACHE_PATH/$SOURCE" ]]; then
        # Look in specific cache
        # This part is simplified; ideally we'd search for the skill in the cache
        # For now, assume path is standard (skills/<name>)
        SKILL_SRC_DIR="$SKILL_CACHE_PATH/$SOURCE/skills/$NAME"
        if [[ ! -d "$SKILL_SRC_DIR" ]]; then
             # Try root of cache
             SKILL_SRC_DIR="$SKILL_CACHE_PATH/$SOURCE/$NAME"
        fi
        
        if [[ ! -d "$SKILL_SRC_DIR" ]]; then
            json_error "Skill not found in cache '$SOURCE'" "Try providing a full URL"
        fi
        
        # Get hash
        PINNED_HASH=$(cd "$SKILL_CACHE_PATH/$SOURCE" && git rev-parse HEAD)
        # We don't have full origin details easily here without more logic
        # For now, use a placeholder or best effort
        REPO_URL=$(cd "$SKILL_CACHE_PATH/$SOURCE" && git remote get-url origin)
        ORIGIN_JSON=$(jq -n \
            --arg repo "$REPO_URL" \
            --arg branch "main" \
            --arg path "$NAME" \
            --arg pinnedHash "$PINNED_HASH" \
            '{repo: $repo, branch: $branch, path: $path, pinnedHash: $pinnedHash}')
    else
        json_error "Skill '$NAME' not found in registry" "Try providing a source or URL"
    fi
fi

# 3. Copy to Registry if not there (and update registry.json)
if [[ ! -d "$SKILL_REGISTRY_PATH/$NAME" ]]; then
    mkdir -p "$SKILL_REGISTRY_PATH/$NAME"
    cp -R "$SKILL_SRC_DIR/" "$SKILL_REGISTRY_PATH/$NAME/"
    
    # Update registry.json
    TYPE="imported"
    if [[ -z "$ORIGIN_JSON" ]]; then
        TYPE="authored"
        ORIGIN_JSON="null"
    fi
    
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    TMP_REGISTRY=$(mktemp)
    jq --arg name "$NAME" \
       --arg type "$TYPE" \
       --argjson origin "$ORIGIN_JSON" \
       --arg ts "$TIMESTAMP" \
       '.skills[$name] = {type: $type, origin: $origin, importedAt: $ts}' \
       "$SKILL_REGISTRY_PATH/registry.json" > "$TMP_REGISTRY" && mv "$TMP_REGISTRY" "$SKILL_REGISTRY_PATH/registry.json"
    
    # Commit to registry
    (cd "$SKILL_REGISTRY_PATH" && git add . && git commit -m "Add skill $NAME")
fi

# 4. Copy to Project
PROJECT_SKILL_DIR="$PROJECT_PATH/.agents/skills/$NAME"
if [[ -d "$PROJECT_SKILL_DIR" && "$FORCE" != "true" ]]; then
    json_error "Skill '$NAME' already exists in project" "Use {\"force\": true} to overwrite"
fi

mkdir -p "$PROJECT_SKILL_DIR"
cp -R "$SKILL_REGISTRY_PATH/$NAME/" "$PROJECT_SKILL_DIR/"

# 5. Update workspace.json
WORKSPACE_DIR="$PROJECT_PATH/.agents/skills/skill-manager-workspace"
mkdir -p "$WORKSPACE_DIR"
WORKSPACE_FILE="$WORKSPACE_DIR/workspace.json"

if [[ ! -f "$WORKSPACE_FILE" ]]; then
    echo "{\"version\": 1, \"library\": \"$SKILL_MANAGER_HOME\", \"skills\": {}}" > "$WORKSPACE_FILE"
fi

# Get full registry info for workspace
REG_INFO=$(jq -r ".skills[\"$NAME\"]" "$SKILL_REGISTRY_PATH/registry.json")

TMP_WORKSPACE=$(mktemp)
jq --arg name "$NAME" \
   --argjson info "$REG_INFO" \
   '.skills[$name] = $info' \
   "$WORKSPACE_FILE" > "$TMP_WORKSPACE" && mv "$TMP_WORKSPACE" "$WORKSPACE_FILE"

# Return success
json_response "status" "added" \
              "name" "$NAME" \
              "installedTo" "$PROJECT_SKILL_DIR" \
              "hash" "$(cd "$SKILL_REGISTRY_PATH" && git rev-parse HEAD)"

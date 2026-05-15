#!/usr/bin/env zsh

# search.sh — Search cached remotes and local registry for skills

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.sh"

# Parse JSON input
INPUT="${1:-"{}"}"
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    json_error "Invalid JSON input" "Please provide a valid JSON object"
fi

QUERY=$(echo "$INPUT" | jq -r '.query // empty')
REMOTE_FILTER=$(echo "$INPUT" | jq -r '.remote // "all"')
LIMIT=$(echo "$INPUT" | jq -r '.limit // 20')

if [[ -z "$QUERY" ]]; then
    json_error "Missing search query" "Provide 'query' in JSON input"
fi

# Load global config
load_config

RESULTS=()

# Function to search a directory
search_dir() {
    local dir="$1"
    local source_name="$2"
    local base_path="$3"
    
    if [[ ! -d "$dir" ]]; then
        return
    fi
    
    # Find all SKILL.md files
    # Use process substitution to avoid subshell and preserve RESULTS array
    while read -r skill_file; do
        # Extract relative path from base_path
        local rel_path="${skill_file#$base_path/}"
        rel_path="${rel_path%/SKILL.md}"
        
        # Match query (case-insensitive) against SKILL.md content first for speed
        if ! grep -qi "$QUERY" "$skill_file"; then
            # If not in content, check if it matches name/desc in frontmatter
            # We'll parse anyway if we want to rank
            :
        fi

        # Parse frontmatter
        skill_fm_data="$(parse_frontmatter "$skill_file")"
        
        local name=$(echo "$skill_fm_data" | jq -r '.name // empty')
        local desc=$(echo "$skill_fm_data" | jq -r '.description // empty')
        
        # If name is empty in frontmatter, use directory name
        if [[ -z "$name" || "$name" == "null" ]]; then
            name=$(basename "$rel_path")
        fi
        
        # Match query (case-insensitive)
        local match=false
        local score=0
        
        # Exact name match
        if [[ "${name:l}" == "${QUERY:l}" ]]; then
            match=true
            score=100
        # Substring name match
        elif [[ "${name:l}" == *"${QUERY:l}"* ]]; then
            match=true
            score=50
        # Description match
        elif [[ "${desc:l}" == *"${QUERY:l}"* ]]; then
            match=true
            score=10
        fi
        
        if [[ "$match" == "true" ]]; then
            # Get latest hash if in a git repo
            local hash=""
            if [[ -d "$dir/.git" || -d "$(dirname "$dir")/.git" ]]; then
                hash=$(cd "$(dirname "$skill_file")" && git rev-parse HEAD 2>/dev/null)
            fi
            
            RESULTS+=("$(jq -n \
                --arg name "$name" \
                --arg desc "$desc" \
                --arg remote "$source_name" \
                --arg path "$rel_path" \
                --arg hash "$hash" \
                --argjson score "$score" \
                '{name: $name, description: $desc, remote: $remote, path: $path, latestHash: $hash, score: $score}')")
        fi
    done < <(find "$dir" -name "SKILL.md")
}

# 1. Search Local Registry
if [[ "$REMOTE_FILTER" == "all" || "$REMOTE_FILTER" == "local" ]]; then
    search_dir "$SKILL_REGISTRY_PATH" "local" "$SKILL_REGISTRY_PATH"
fi

# 2. Search Cached Remotes
if [[ "$REMOTE_FILTER" == "all" || "$REMOTE_FILTER" != "local" ]]; then
    if [[ ! -d "$SKILL_CACHE_PATH" ]]; then
        # Only error if no cache exists and we are specifically looking for remotes
        if [[ "$REMOTE_FILTER" != "all" ]]; then
            json_error "No cached repos found" "Run scripts/refresh.sh first"
        fi
    else
        # Iterate over cache directories
        for cache_dir in "$SKILL_CACHE_PATH"/*; do
            [[ -d "$cache_dir" ]] || continue
            local cache_name=$(basename "$cache_dir")
            
            if [[ "$REMOTE_FILTER" != "all" && "$REMOTE_FILTER" != "$cache_name" ]]; then
                continue
            fi
            
            search_dir "$cache_dir" "$cache_name" "$cache_dir"
        done
    fi
fi

# Sort and limit results
# Ranking: Score descending, then Name ascending
FINAL_RESULTS=$(printf '%s\n' "${RESULTS[@]}" | jq -s ". | sort_by(-.score, .name) | .[0:$LIMIT] | map(del(.score))")

# Return final JSON with proper types
jq -n \
   --argjson results "$FINAL_RESULTS" \
   --argjson total "$(echo "$FINAL_RESULTS" | jq 'length')" \
   --argjson cached true \
   '{results: $results, total: $total, cached: $cached}'

# Registry & Workspace Formats

This document specifies the JSON schemas for the three primary configuration files used by the `skill-manager`.

## 1. Global Config (`config.json`)

Located at `~/.gemini/skill-library/config.json`. Tracks remote repositories and global settings.

### Schema
```json
{
  "version": 1,
  "remotes": [
    {
      "name": "string",       // Unique local name for the remote
      "url": "string",        // Git repository URL
      "defaultTrust": number, // Default trust tier (1, 2, or 3)
      "skillsPath": "string", // Relative path within repo where skills are located
      "searchable": boolean   // If true, the entire skillsPath is cached for searching
    }
  ]
}
```

### Example
```json
{
  "version": 1,
  "remotes": [
    {
      "name": "antigravity-skills",
      "url": "https://github.com/antigravity/skillrepo.git",
      "defaultTrust": 1,
      "skillsPath": "skills/",
      "searchable": true
    }
  ]
}
```

---

## 2. Global Registry (`registry.json`)

Located at `~/.gemini/skill-library/registry/registry.json`. Tracks all skills known to the local library.

### Schema
```json
{
  "version": 1,
  "skills": {
    "<skill-name>": {
      "type": "authored" | "imported" | "forked",
      "importedAt": "ISO8601",
      "origin": {
        "repo": "string",
        "branch": "string",
        "path": "string",
        "pinnedHash": "string",
        "forkedFromHash": "string", // Only for type: forked
        "forkedAt": "ISO8601"        // Only for type: forked
      }
    }
  }
}
```

### Example
```json
{
  "version": 1,
  "skills": {
    "distillery": {
      "type": "authored",
      "importedAt": "2026-05-15T10:00:00Z"
    },
    "prompt-engineering": {
      "type": "imported",
      "importedAt": "2026-05-15T12:00:00Z",
      "origin": {
        "repo": "https://github.com/antigravity/skillrepo.git",
        "branch": "main",
        "path": "skills/prompt-engineering",
        "pinnedHash": "abc123def456"
      }
    }
  }
}
```

---

## 3. Project Workspace (`workspace.json`)

Located at `.agents/skills/skill-manager-workspace/workspace.json`. Tracks skills active in a specific project. This file is committed to the project's repository.

### Schema
```json
{
  "version": 1,
  "library": "string", // Hint for the global library path (usually ~/.gemini/skill-library)
  "skills": {
    "<skill-name>": {
      // Identical structure to the entry in registry.json
    }
  }
}
```

### Example
```json
{
  "version": 1,
  "library": "~/.gemini/skill-library",
  "skills": {
    "skill-manager": {
      "type": "authored",
      "importedAt": "2026-05-15T19:30:00Z"
    }
  }
}
```

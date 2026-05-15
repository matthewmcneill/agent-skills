---
name: skill-manager
description: Manage, version, and sync AI skills across projects. Use this skill to find new capabilities, add skills to your project, sync edits back to your library, and share skills between different workspace contexts.
---

# Skill Manager

The `skill-manager` is a "Skill-as-Toolbox" that allows you to declaratively manage AI skills. Skills are physical copies of instruction sets located in `.agents/skills/`.

## First-Time Setup

Before using the manager, ensure the global library is initialized:

1. **Detect Home:** Check if `~/.gemini/skill-library/` exists.
2. **Initialize:** If missing, run `init`.
3. **Add Remotes:** Add trusted repositories (e.g., `https://github.com/antigravity/skillrepo.git`).

## Command Reference

All commands are shell scripts that accept a single JSON argument and return a JSON response.

### `init` — Bootstrap Library
Initializes the global `~/.gemini/skill-library/` structure.
- **When to use:** First time setup or to reset the library.
- **Input:** `{"force": boolean}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/init.sh \'{}\'')`

### `search` — Find Skills
Search cached remote repos and the local registry.
- **When to use:** When the user asks for a capability you don't have.
- **Input:** `{"query": "string", "remote": "all"|"local"|"<name>", "limit": 20}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/search.sh \'{"query": "distillery"}\'')`

### `add` — Add to Project
Adds a skill to the current project from registry, cache, or URL.
- **When to use:** To install a new skill found via search or a direct link.
- **Input:** `{"name": "string", "url": "string", "project": "string", "force": boolean}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/add.sh \'{"name": "distillery", "project": "."}\'')`

### `install` — Materialize Skills
Installs all skills listed in `workspace.json`.
- **When to use:** Setting up a fresh project clone.
- **Input:** `{"project": "string"}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/install.sh \'{"project": "."}\'')`

### `push` — Sync to Registry
Copies project-local edits back to the global registry. Detects if an imported skill has become a "fork".
- **When to use:** After you have improved or modified a skill's instructions.
- **Input:** `{"project": "string", "skills": ["string"], "remote": boolean}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/push.sh \'{"project": ".", "remote": true}\'')`

### `pull` — Sync from Registry
Copies updates from the global registry into the current project.
- **When to use:** To get the latest version of your authored skills into a project.
- **Input:** `{"project": "string", "skills": ["string"]}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/pull.sh \'{"project": "."}\'')`

### `status` — Check Sync State
Shows sync status, fork status, and versions for all installed skills.
- **When to use:** To see what skills are modified or need updating.
- **Input:** `{"project": "string"}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/status.sh \'{"project": "."}\'')`

### `refresh` — Update Caches
Updates sparse clones of remote repositories.
- **When to use:** Before searching to ensure you have the latest catalog.
- **Input:** `{"remote": "all"|"<name>"}`
- **Example:** `run_command('.agents/skills/skill-manager/scripts/refresh.sh \'{"remote": "all"}\'')`

## Common Workflows

### Finding and Adding a Skill
1. `refresh` (optional)
2. `search {"query": "..."}`
3. `add {"name": "...", "project": "."}`
4. Verify with `status`

### Improving an Authored Skill
1. Edit the `SKILL.md` in `.agents/skills/<name>/`.
2. Test the new instructions.
3. `push {"project": ".", "skills": ["<name>"]}` to save to your library.

## Error Handling

All scripts return JSON errors to `stderr` and human-readable hints.
- **Invalid JSON:** Ensure arguments are properly escaped for the shell.
- **Missing Path:** Always provide an absolute path for `"project"` or use `.` for the current directory.
- **Registry Not Found:** Run `init` if the global library is missing.

## Further Reading
- [Registry & Workspace Formats](references/registry-format.md)
- [Trust Tiers Specification](references/trust-tiers.md)

# Verification Comment

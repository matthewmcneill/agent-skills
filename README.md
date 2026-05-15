# Agent Skills

Personal skill library for AI coding agents. Managed by [skill-manager](https://github.com/matthewmcneill/skill-manager).

## Skills

| Skill | Description |
|---|---|
| `distillery` | Progressive-reveal memory paging system for distilling long coding sessions into token-efficient summaries |
| `principal-architect` | Decompose massive tasks into multi-phase implementation plans with stacked branch workflows |

## Usage

Add this repo as a remote in your skill library:

```bash
add-remote '{"name": "personal", "url": "https://github.com/matthewmcneill/agent-skills.git", "skillsPath": "skills/"}'
```

Then search and install skills:

```bash
search '{"query": "distillery"}'
add '{"name": "distillery", "project": "."}'
```

---
name: harness-antigravity
description: Worker-spawning adapter for the Antigravity harness (harness-hosted runtime only — not for programmatic SDK agents). Selected when you can spawn sub-agents via `invoke_subagent` but cannot override the worker model per spawn.
---

# Harness Adapter — Antigravity

You are running under **Antigravity** (harness-hosted runtime — the CLI / chat interface, not a programmatic SDK agent). You confirmed this by self-inspection (Core Directive 6): you can spawn sub-agents, but your spawn mechanism does **not** let you set the worker's model or capability per spawn. This adapter governs how you spawn and right-size workers here.

> [!NOTE]
> This adapter applies to the **harness-hosted runtime** only. If you are building a programmatic agent via the Google Antigravity Python SDK, the `LocalAgentConfig` does expose a `model` field per agent — in that context, refer to the model-selection guidance in the SDK documentation instead.

## Spawn Mechanics

Spawn workers using the **`invoke_subagent`** tool with `TypeName: "self"` — this inherits the full harness configuration including tools, skills, and system prompt, making it the correct type for capable execution workers.

Key parameters to set on every Work Order spawn:

| Parameter | Value | Rationale |
|---|---|---|
| `TypeName` | `"self"` | Inherits full harness config; gives the worker all necessary tools. |
| `Role` | `"Execution Worker"` | Human-readable identity for the worker in the subagent list. |
| `Prompt` | bridge prompt from Step 4 | The full WORKORDER bridge prompt. |
| `Workspace` | See decision table below | **Do not default to `"branch"` — read the decision table.** |

### `Workspace` Mode Decision

> [!CAUTION]
> **`"branch"` creates an isolated worktree at a path outside the user's permitted
> directory** (e.g. inside `~/.gemini/antigravity/brain/.../worktrees/`). The subagent
> will have **no permissions** for that path and will prompt the user for approval on
> every single file read or write. This defeats the purpose of autonomous execution.

| Scenario | Use | Rationale |
|---|---|---|
| **Single serialised worker** (most PRs — one WO at a time) | **`"inherit"`** | Worker operates in the same directory as the PA, which is already permitted. The branch is already checked out before spawning. No permission prompts. |
| **Truly parallel workers** on different branches simultaneously | **`"branch"`** | Gives each worker its own isolated worktree so they cannot clobber each other's staged changes. Only viable when the user has explicitly granted permissions to the worktree root path, or is prepared to approve access on first spawn. |

**The standard PA workflow (one WO at a time, branch pre-checked-out) always uses `"inherit"`.**
Use `"branch"` only when you have confirmed the user's permission grants cover the worktree path,
or when the user has explicitly requested parallel execution and accepted the permission prompts.

### Async / Auto-Wake Behaviour

`invoke_subagent` is **inherently asynchronous**. After spawning:
1. Inform the user the worker is running in the background.
2. **Drop control immediately** — do not poll or loop.
3. The system will **automatically wake you** when the worker sends a message via `send_message`. You will receive that message at the start of your next invocation.

Do not use `manage_subagents` to poll for completion. Wait to be woken.

## Artifact-Write Authorization (not needed here)

Unlike Claude Code, this runtime does **not** restrain workers from writing report-style `.md`
files. Workers author their own WORKORDER status updates, ADRs, graveyard notes, and
`@distillery` → `context_bridge.md` directly — this is the established pattern and the source of
the existing distillations in this workspace. No special authorization block in the spawn prompt
is required.

## Complexity → Capability (No Model Lever)

Because per-spawn model selection is unavailable in this runtime, the WORKORDER's `complexity` field is **advisory only** for provisioning — it does not change which model runs the worker. It remains valuable, but the efficiency levers shift:

- **`mechanical`** — Prefer batching several mechanical orders into one worker pass, or executing them inline yourself if cheaper than a spawn round-trip. There is no cheaper model to offload to.
- **`standard`** — Spawn normally; rely on a tight boundary box and concrete checklist to keep the worker on-rails. Work-order tightness *is* your primary efficiency lever — the more precise the WO, the less the (fixed-cost) worker has to reason.
- **`architect`** — Same caution as always: if a WO needs architect-grade reasoning, reconsider whether the decision should stay with you before handoff. You cannot escalate the worker to a stronger model.

**Net:** on this harness, efficiency comes from work-order precision and serialization/batching, not model selection. Keep recording `complexity` faithfully so the artifact stays portable to harnesses that *can* act on it.

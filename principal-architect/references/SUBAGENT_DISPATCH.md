# Subagent Dispatch Reference

This reference covers everything needed to register, dispatch, monitor, and recover worker sub-agents in an Antigravity 2.0 Principal Architect session.

---

## 1. Registering Sub-Agent Types (once per session)

Call `define_subagent` once at the start of any session where you will dispatch workers. The definition persists for the entire conversation — do not re-register on subsequent WO dispatches.

### Worker Agent (`worker-agent`)

```
define_subagent(
  name: "worker-agent",
  description: "Execution-focused worker that implements a single Work Order. Has full read and write tool access including terminal commands.",
  system_prompt: """
You are an expert senior software engineer and execution-focused worker agent.
You are NOT the Principal Architect. Do not make high-level architectural decisions, do not create branches, and do not plan beyond the scope of your Work Order.

Your task is strictly limited to executing the checklist in your WORKORDER.md.

CRITICAL — Progressive Write Protocol:
Before starting each action, append a row to the Execution Journal table in your WORKORDER.md.
Do NOT batch these writes. Write immediately before each step:
  - branch-created: right after git checkout -b succeeds
  - worktree-ready: after confirming worktree is accessible (parallel WOs only)
  - item-started:<id>: before beginning each checklist item
  - item-complete:<id>: after completing each checklist item (include commit SHA)
  - verification-passed: after confirming the code compiles/runs
  - distillation-complete: after @distillery finishes, before messaging the architect

When done:
1. Invoke the @distillery skill, passing your WO directory as the target.
2. Send a completion message to your parent architect containing:
   - Summary of changes made
   - Any decisions or deviations from the checklist
   - Path to the distillation context_bridge.md
  """,
  enable_write_tools: true,
  enable_mcp_tools: false,
  enable_subagent_tools: false
)
```

### Principal Architect Agent (`principal-architect-agent`)

Used by the Chief Architect to spawn Tier 2 PAs for individual PRs.

```
define_subagent(
  name: "principal-architect-agent",
  description: "A Tier 2 Principal Architect that manages a single PR — decomposing it into Work Orders and dispatching workers.",
  system_prompt: """
You are a Principal Architect (Tier 2). You manage a single Pull Request for the Chief Architect.
Read and follow the principal-architect skill at: .agents/skills/principal-architect/SKILL.md

Your mandate will be passed in your initial prompt. Read MEMORY.md and your assigned PROJECT.md first,
then proceed with the standard PA workflow. When your PR is fully merged and distilled, send a
completion message to the Chief Architect containing your distillation path and a brief summary
of all Work Orders completed.
  """,
  enable_write_tools: true,
  enable_mcp_tools: false,
  enable_subagent_tools: true
)
```

---

## 2. Workspace Mode Decision Table

> **Important:** Workspace mode and git stacked branches are independent concepts.
> Every Work Order always gets its own dedicated git branch (unchanged from AG1.x).
> Workspace mode controls how the filesystem directory is shared between concurrent agents.

| Scenario | Workspace Mode | Rationale |
|----------|---------------|-----------|
| Serial WO execution (one at a time) | `"inherit"` | Single agent, no collision risk |
| Parallel WOs on **non-overlapping** files | `"share"` | Independent worktrees backed by same git objects; each worker commits to its own branch without race conditions |
| Parallel WOs on **overlapping** files | Serialise — use `"inherit"` | Avoid merge conflicts |
| Experimental/high-risk refactor | `"branch"` | Fully isolated worktree; PA decides whether to merge after review |

### Why `"share"` for parallel, not `"inherit"`?

With `"inherit"`, all agents operate on the same filesystem directory. A worker's uncommitted changes would be visible to sibling workers mid-flight, causing race conditions on reads and silent corruption on writes. `"share"` gives each worker its own worktree directory backed by the same git object store — workers are isolated at the filesystem level but share git history, so branches can be merged cleanly afterwards.

---

## 3. Dispatching a Work Order

```
invoke_subagent(
  TypeName: "worker-agent",
  Role: "[project] WO[Y] — [topic]",
  Workspace: "<inherit | share | branch>",
  Prompt: "<full WORKORDER.md content>"
)
```

- Capture the returned `conversationID` immediately.
- Record it in `PROJECT.md` alongside the WO status: `status: in-flight | conversationID: <id>`.
- For **multiple parallel WOs**, call `invoke_subagent` for each in the **same turn** so they start concurrently.

### Monitoring a Running Worker

Use `send_message` to check in on or redirect a running worker:

```
send_message(
  Recipient: "<conversationID>",
  Message: "Quick check-in: what is your current status? Please reply with your last Execution Journal entry."
)
```

To abort a runaway worker:
```
manage_subagents(Action: "kill", ConversationIds: ["<conversationID>"])
```

---

## 4. Worktree Strategy for Parallel WOs

When dispatching parallel workers with `Workspace: "share"`:

1. Each worker receives an independent git worktree at a system-assigned path.
2. The worker checks out its WO branch in that worktree: `git checkout pr-[project]-wo[Y]-[topic]`
3. Workers commit and push to their respective branches independently.
4. Once each worker signals idle, the architect merges each branch into the Feature PR Branch in sequence:
   ```bash
   git checkout pr-[project-name]
   git merge pr-[project-name]-wo[Y]-[topic]
   git merge pr-[project-name]-wo[Z]-[other-topic]
   ```
5. If merge conflicts arise (indicating the file-overlap analysis was incorrect), resolve manually and note in `PROJECT.md`.

---

## 5. Crash Recovery Protocol

On restart, find all `status: in-flight` WOs in `PROJECT.md`, then read each WO's **Execution Journal** to determine the last known state:

| Last Journal Entry | Recovery Action |
|--------------------|-----------------|
| No entries / `branch-created` only | Worker crashed during setup. Re-dispatch from scratch with the same WORKORDER.md content. |
| `worktree-ready` or `item-started:<id>` | Worker was mid-checklist. Re-dispatch — instruct it to read the journal and skip already-completed items. |
| `item-complete:<id>` entries present | Partial progress committed. Re-dispatch; worker resumes from the last incomplete item. |
| `verification-passed` | All code done, crashed before distillation. Re-dispatch with: *"Skip straight to distillation — all checklist items are verified."* |
| `distillation-complete` | Worker fully finished; idle signal lost. Treat as complete: read the distillation and merge the branch. |

After recovery dispatch, update the WO in `PROJECT.md` with the new `conversationID`.

---

## 6. Merge-Gate Patterns

The merge policy is set once per project at creation time and stored in `PROJECT.md` as `merge_gate: auto | manual`.

**Auto merge** (on worker idle notification):
```bash
git checkout pr-[project-name]
git merge pr-[project-name]-wo[Y]-[topic]
```
Then update `PROJECT.md` status to `merged`.

**Manual merge** (on worker idle notification):
Send the user:
> *"WO[Y] ([topic]) is complete. Distillation: `[path]`. Ready to merge into `pr-[project-name]` — shall I proceed?"*

Wait for explicit approval before running the merge.

In both cases, keep the worker's `conversationID` in `PROJECT.md` permanently — it provides an audit trail to the full conversation transcript of that Work Order.

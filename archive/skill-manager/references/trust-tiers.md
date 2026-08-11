# Trust Tiers Specification

The `skill-manager` uses a three-tier trust system to manage updates from remote skill repositories. These tiers determine the level of human intervention required before a skill is updated in the local registry.

## Tier 1: Automated Updates
**Description:** High-trust repositories (e.g., your own personal mono-repo or official company repos).
- **Behaviour:** Updates are automatically applied to the registry during a `refresh` or `update` operation.
- **Project Impact:** If a project uses an `imported` skill from a Tier 1 remote, it can be updated to the latest version without intervention.

## Tier 2: Notification & Manual Trigger
**Description:** Semi-trusted community repositories.
- **Behaviour:** The system detects updates and notifies the user (e.g., via `status` or a dedicated notification in the UI). 
- **User Action:** A manual command (e.g., `update --skill <name>`) is required to pull the update into the local registry.
- **Project Impact:** Changes are staged in the registry but not pushed to projects until the user triggers the update.

## Tier 3: Review & Explicit Approval
**Description:** Untrusted or experimental repositories.
- **Behaviour:** Any update mandates a full review.
- **User Action:** The system generates a Git diff between the current local version and the upstream version. The user must review the diff and provide explicit approval (e.g., `update --approve --skill <name>`) to apply the change.
- **Project Impact:** Maximum security. No changes can enter the registry without a human "eyes-on" check.

---

## Technical Implementation (Phase 2)

While trust tiers are defined in `config.json` and `registry.json`, the enforcement logic is scheduled for Phase 2 (`update.sh`).

### Storage
- **Global Default:** Defined in `config.json` under the remote configuration.
- **Per-Skill Override:** Stored in `registry.json` for each imported skill.

### Transition to 'Forked'
If a user modifies an `imported` skill locally, the system automatically transitions the skill type to `forked`. Trust tiers no longer apply to auto-updates for forked skills; instead, the system will only show the diff between the local fork and the upstream, allowing for manual merging.

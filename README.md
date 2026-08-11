# ⚠️ DEPRECATED: Agent Skills Monorepo

> [!CAUTION]
> **This monolithic repository has been deprecated.**
> 
> Skills are no longer managed centrally in this massive repository. Instead, we have adopted a decentralized architecture where **every skill is its own individual repository**.

## The New Workflow: `skill-manager`

All skills are now hosted under the [mm-skills](https://github.com/mm-skills) GitHub organization. 

Projects now include these skills as **git submodules** via the `skill-manager` tool, ensuring you only pull in the exact skills you need, when you need them.

To get started with the new architecture, install the `skill-manager` globally or check its documentation here:
**[https://github.com/mm-skills/skill-manager](https://github.com/mm-skills/skill-manager)**

## Redirects

Some of the core skills have direct redirects in this repository to prevent old links from breaking immediately:
* `principal-architect` -> [mm-skills/principal-architect](https://github.com/mm-skills/principal-architect)
* `distillery` -> [mm-skills/distillery](https://github.com/mm-skills/distillery)
* `squareline-studio` -> [mm-skills/squareline-studio](https://github.com/mm-skills/squareline-studio)

All other legacy skills from this repo have been moved to the `archive/` directory for reference purposes only. They will not receive updates. Please check the `mm-skills` organization for their active equivalents.

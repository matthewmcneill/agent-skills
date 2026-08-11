---
name: house-style-documentation
description: Consistently and thoroughly document code following the project's "house style". Use this skill whenever documenting, refactoring, or creating new modules to ensure they meet the specific header, method, and inline comment standards. Also use this skill whenever drafting or reviewing an implementation plan to ensure it adheres to the project structure. Trigger on mentions of naming conventions, documentation standards, code style, implementation plan review, or house style.
triggers: implementation plan, drafting plan, documentation, refactoring, review-ip, ip-review, naming conventions, code style
---

# House Style Documentation

Enforce a consistent set of documentation and naming standards across the project. This skill is **language-agnostic at the principle level** — concrete syntax, examples, and naming conventions live in language-specific reference files loaded on demand.

## Universal Principles

These principles apply to **all** codebases regardless of language:

### 1. Module Headers
Every source file must begin with a standard header block containing: project attribution, license, module path, description, and an exported API summary. The header allows a developer to understand the file's purpose and public surface without reading the implementation.

### 2. Function and Method Documentation
All public and protected functions/methods must have structured documentation comments (language-appropriate format). Include: a brief summary, parameter descriptions, return value description, and any thrown exceptions or error conditions.

### 3. Scoped Variables and Constants
Module-level variables, constants, and configuration values must have a short descriptive comment — either inline (same line) or immediately preceding the declaration.

### 4. Internal Functional Flow
For functions longer than ~15 lines, use block comments to group logical steps and explain the "why" and "how" of the process. This creates a scannable narrative through complex logic.

### 5. Arcane and Complex Logic
Identify lines of code that are not self-explanatory — bit manipulation, complex expressions, hardware-specific quirks, non-obvious algorithms — and provide an inline explanation.

### 6. Naming Conventions
All type names, file names, variable names, and directory names must follow the conventions defined in the **language-specific reference file** (see below). Consistency is non-negotiable.

---

## Language-Specific Conventions

This skill supports multiple development contexts. Detect the project type and load the **appropriate reference file** for language-specific rules, naming conventions, documentation syntax, and code examples.

| Indicator | Context | Reference File |
|-----------|---------|---------------|
| `platformio.ini` in project root | Embedded C++ (ESP32/Arduino) | `references/cpp-embedded.md` |
| `build.gradle.kts` in project root | Kotlin Android | `references/kotlin-android.md` |
| `package.json` in project root | Web / JS / TS | `references/web-frontend.md` |

Read **only** the reference file matching the detected context. If multiple indicators are present, prefer the most specific match. If no context is detected, default to `references/cpp-embedded.md`.

> [!IMPORTANT]
> The reference file contains the **concrete examples, templates, and naming tables** for the detected language. Do not apply conventions from one language context to another.

---

## 7. Implementation Plans

Whenever an implementation plan is produced, it MUST be reviewed and updated to adhere to the project's house style.

### Structure
- **Goal Description**: Clear, concise explanation of the objective.
- **User Review Required**: Highlight critical decisions or breaking changes using GitHub alerts (`IMPORTANT`, `WARNING`, `CAUTION`).
- **Proposed Changes**: Grouped by component, using `[MODIFY]`, `[NEW]`, and `[DELETE]` tags with repository-relative file links (e.g., `[file.cpp](modules/foo/file.cpp)`). Absolute paths to the project directory are FORBIDDEN.
- **Verification Plan**: Practical steps for automated and manual verification.

---

## Workflow

1. Detect the project context and load the appropriate language reference file.
2. Read the target file OR implementation plan.
3. Identify missing or substandard documentation/content based on the universal principles above AND the language-specific reference.
4. Verify all naming conventions match the language-specific naming table.
5. For implementation plans, ensure all standard sections are present and correctly formatted.
6. Regenerate the content with the improved house style.
7. Ensure existing logic or plan details are PRESERVED exactly; only formatting and clarity should change.

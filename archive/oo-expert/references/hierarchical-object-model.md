# Hierarchical Object Model Pattern

> **Load this reference** when reviewing a module that: exposes sub-objects via flat getter
> methods; has Law of Demeter violations where callers chain multiple calls to achieve one
> effect; or when designing a new module API that will contain multiple named sub-objects.

---

## The Core Rule: Expose Sub-Objects as Domain Concepts

When a class owns multiple distinct sub-objects, prefer exposing them as a **navigable
object hierarchy** rather than as flat methods on the root class. This is the C++ equivalent
of the COM/VB object model (e.g. `myForm.dropDown.Items.Add(newItem)`), and produces APIs
that are self-documenting, compositional, and naturally scoped.

---

## The Domain Meaning Test

A sub-object should be part of the public hierarchy if and only if it passes the
**Domain Meaning Test**:

> *Does this sub-object have meaningful identity and purpose independent of its parent?*

**Pass — expose as a navigable sub-object:**
- `order.lineItems` — a line-item collection is independently meaningful (you can reason
  about it without knowing the full order)
- `wizard.networkStep` — a wizard step is a distinct configuration domain entity
- `report.summaryPanel` — a named panel is a meaningful, addressable part of a report
- `myForm.dropDown.Items` — the items collection is meaningful without the form

**Fail — do NOT expose; use intent-based methods on the parent instead:**
- `wizard.networkStep.internalFieldRenderer` — a renderer is a rendering primitive
  (implementation detail), not a domain concept
- `order.lineItems.internalSortBuffer` — internal mechanics have no external identity
- `report.summaryPanel.headerLabelWidget` — a label widget is below the meaningful
  abstraction boundary

The test distinguishes **domain structure** (expose it) from **implementation topology**
(hide it). Exposing implementation topology as sub-objects gives callers knowledge they
should not have and couples them to internal decisions that will change.

---

## Concrete Types at the Caller Layer; Interfaces at Engine Boundaries

This is the most commonly misapplied rule. The correct mapping is:

| Boundary | Type to Use | Rationale |
|---|---|---|
| **Caller → sub-object** | **Concrete type** (`NetworkStep&`) | Each sub-object IS a different domain entity with a distinct API. Abstracting to an interface destroys the value of the hierarchy — the caller cannot call `setEndpoint()` on an `IWizardStep`. |
| **Engine → sub-object** | **Interface** (`IWizardStep*`) | The execution engine doesn't care which step it is running — it only needs `execute()`. Polymorphism earns its place here. |

**Anti-pattern** — interface at the wrong boundary:
```cpp
// Returning an interface to the caller destroys the hierarchy:
IWizardStep& getNetworkStep();   // ❌ caller cannot call setEndpoint()
```

**Correct pattern** — interface only at the engine boundary:
```cpp
// Caller gets the concrete type — full domain API available:
wizard.networkStep.setEndpoint(url);     // ✅ NetworkStep& — caller has full API
wizard.networkStep.setTimeout(5000);     // ✅

// Engine uses the interface — doesn't care which step it is:
void runStep(IWizardStep* step);         // ✅ polymorphic at the execution boundary
void queue.add(IWizardStep* step);       // ✅ polymorphic at the collection boundary
```

---

## Data/Config Concerns vs. Presentation Concerns

Within a hierarchy, enforce a strict separation between what a sub-object **is configured
with** and how it **gets surfaced or activated**:

- **Data/config concerns** belong on the sub-object — it knows its own state:
  `wizard.networkStep.setEndpoint(url)` — what the step will do
  `report.summaryPanel.setRefreshRate(1000)` — how the panel behaves

- **Presentation/orchestration concerns** belong on the root — it decides when and how
  sub-objects are activated:
  `wizard.showStep(&wizard.networkStep)` — the wizard decides the active step
  `window.showModal(&dialog)` — the window decides the modal layer

### The Two-Step Smell

A sign that sub-objects are passive containers rather than live domain objects. If a caller
must (1) configure a sub-object AND (2) separately tell the root to surface it, the
hierarchy is not self-sufficient:

```cpp
// Two objects, three calls, one intended operation — broken hierarchy:
self->getNetworkStep().setTimeout(5000);          // configure ✅
self->getNetworkStep().setEndpoint(url);          // configure ✅
self->activateStep(&self->getNetworkStep());      // ❌ separate surfacing call required
```

**Correct pattern** — configure on the sub-object; single presentation call on the root:
```cpp
wizard.networkStep.setEndpoint(url);        // data — on the sub-object ✅
wizard.networkStep.setTimeout(5000);        // data — on the sub-object ✅
wizard.showStep(&wizard.networkStep);       // presentation — one call, clear intent ✅
```

---

## Widget/Primitive Depth Heuristic

When a domain sub-object itself owns further sub-objects (panels, fields, widgets), apply the
Domain Meaning Test recursively. Ask: *is the next level independently configurable as a
domain concept by an external caller?*

**Go deeper when sub-objects represent independently meaningful named panels or fields:**
```cpp
// A diagnostics view with named, configurable readout panels:
diagnostics.cpuPanel.setUpdateRate(1000);     // ✅ panel is a domain concept
diagnostics.memPanel.setWarningThreshold(80); // ✅ panel is independently meaningful
```

**Do NOT go deeper when sub-objects are rendering or layout primitives:**
```cpp
// LabelWidget, ProgressBar, ImageRenderer — HOW a panel renders, not WHAT it represents:
report.summaryPanel.headerLabelWidget.setFont(boldFont);  // ❌ rendering detail
report.summaryPanel.progressBar.setColor(red);            // ❌ internal layout decision

// Correct — the panel exposes a domain-level API that hides its rendering internals:
report.summaryPanel.setTitle("Summary");       // ✅
report.summaryPanel.setCompletionRatio(0.75f); // ✅
```

The boundary: **named controls** (in the COM sense) are domain objects — expose them.
**Rendering primitives** (labels, bars, images, layout helpers) are visual mechanics — hide
them behind the owning sub-object's own API.

---

## Layered Subsystem Priority Model

When a root object manages multiple content layers simultaneously (common in UI systems,
rendering pipelines, and notification stacks), define an explicit, documented priority stack.
Each layer must have:
- A defined **trigger model** (who activates it, and under what conditions)
- A defined **override behaviour** (which layers it supersedes)
- A defined **yield behaviour** (which layers supersede it)

**Generic three-tier model:**
```
┌──────────────────────────────────────┐  Priority
│  TRANSIENT OVERLAY                   │  HIGHEST
│  (app-driven, short-lived)           │  overrides all layers below
│  e.g. modal dialog, error alert      │
├──────────────────────────────────────┤
│  PRIMARY CONTENT                     │  MID
│  (app-driven, persistent)            │  overrides idle layer
│  e.g. active view, content carousel  │
├──────────────────────────────────────┤
│  IDLE / BACKGROUND POLICY            │  LOWEST
│  (system-driven, inactivity)         │  yields to all layers above
│  e.g. screensaver, default state     │
└──────────────────────────────────────┘
```

**Critical rule for the idle layer**: the idle/background policy must never be implemented
as a transient overlay. Doing so assigns it TRANSIENT priority, allowing it to suppress
legitimate application overlays. The idle layer is a distinct third tier, driven by the
system's own inactivity timer — not by application decision.

# Service Module Pattern (vs. Orchestrator Anti-Pattern)

> **Load this reference** when reviewing a module that: holds a reference to the application
> hub or god-object; polls external system state in its `tick()` or `update()` loop; contains
> `if (systemState == X)` logic that belongs upstream; or when a module's tick() contains
> phase-transition logic beyond its own internal concerns.

---

## Definition: A Module Should Be a Pure Service

A well-designed module is a **service provider**: it accepts commands from its callers and
executes them. It does not make decisions on its callers' behalf about *when* those
commands should be issued.

The **Orchestrator Anti-Pattern** occurs when a module's internal implementation begins
polling external state and making decisions that belong upstream, in the calling layer
(Application, Coordinator, or Presenter).

---

## Identifying the Orchestrator Anti-Pattern

Look for these four symptoms in a module's implementation:

### Symptom 1 — External state polling in the update/tick loop

```cpp
// ❌ A service module has no business reading system-level state to make
//    presentational or business decisions:
void ServiceModule::tick() {
    if (_hub->getSystemState() == SystemState::Configuring) {
        if (_hub->getNetworkManager().isInFallbackMode()) {
            _fallbackView.configure(_hub->getConfig().hostname);
            activate(&_fallbackView);
        }
    }
}
```

### Symptom 2 — The module holds a reference to the application hub or god object

```cpp
ApplicationHub* _hub = nullptr;  // ❌ a service module should not need the whole hub
```

### Symptom 3 — Application domain logic disguised as service logic

Comments like *"eliminate race conditions from event ordering"* appearing in service code
indicate that orchestration timing has leaked downward into the wrong layer. Race conditions
in event sequencing are an application architecture problem — not a service concern.

### Symptom 4 — A state machine embedded inside the service's update loop

A `tick()` or `update()` that contains phase-transition `if/switch` chains is acting
as an orchestrator. A service's update loop should be: *check own timers → advance own
state → produce output*. Decisions about *which application phase* to be in belong upstream.

---

## The Correct Inversion: Orchestration Belongs Upstream

Move all "when to do what" decisions upward to the Application or a dedicated Coordinator:

```cpp
// In Application / Coordinator — owns the lifecycle logic:
void Application::onEnterConfiguring() {
    _service.suspend();
    _service.showStatus(&_service.items.configuringView);
}

void Application::onNetworkFallbackStarted(const char* id) {
    _service.items.fallbackView.configure(id);
    _service.showOverlay(&_service.items.fallbackView);
}

void Application::onNetworkRestored() {
    _service.clearOverlay();
}

void Application::onEnterRunning() {
    _service.resume();
}
```

The service module's update loop becomes purely a service concern:
```cpp
void ServiceModule::tick() {
    _idlePolicy.tick();      // service-intrinsic: inactivity management
    _advanceQueue();         // service-intrinsic: queue/rotation timing
    _executeOutput();        // service-intrinsic: produce the service's output
    // No system state. No hub. No business logic.
}
```

---

## The Service-Intrinsic Exception

Not all autonomous behaviour in a module is the Orchestrator Anti-Pattern. Some behaviour
is genuinely **service-intrinsic**: it concerns only the service's own hardware or
internal resource state.

**Service-intrinsic (acceptable autonomy):**
- Inactivity timeout → dim or suspend output
- Extended inactivity → enter low-power or idle state
- Activity signal received → restore to active state

These are internal resource management concerns. The caller provides a single
`resetActivity()` signal on the service; the service manages the resulting state
transitions internally without needing to know *why* the activity occurred.

**Application-intrinsic (must be pushed upstream):**
- "Enter fallback mode when the network service is in AP mode" — business logic
- "Suspend the queue during system configuration phase" — application state machine
- "Clear the overlay when a configuration gate is satisfied" — application lifecycle

**The key question**: Does this decision require knowledge of application domain state
(system phases, business service states, domain events)? If yes — it belongs upstream.
If it requires only the service's own internal state (timers, output levels, queue
position) — it can live in the service module.

---

## Coupling Audit for Service Modules

When reviewing a module for the Orchestrator Anti-Pattern, audit its `#include` list and
member variables against this table:

| Dependency found in module | Verdict |
|---|---|
| Message bus / event bus (publishing own-domain events) | ✅ Acceptable — module notifies, does not orchestrate |
| Message bus (subscribing to own-domain events) | ✅ Acceptable — reactive to events in its own domain |
| Own configuration/persistence interface | ✅ Acceptable — standard self-management |
| Web/API contributor interface | ✅ Acceptable — module exposes its own REST endpoints |
| Application hub or god-object reference | ⚠️ Smell — why does a service need the whole application? |
| System / application state enum | ⚠️ Smell — a service should not know about application boot phases |
| Sibling module's concrete class (non-interface) | ❌ Orchestrator Anti-Pattern — tight coupling |
| Business domain services unrelated to this module | ❌ Orchestrator Anti-Pattern — wrong layer |

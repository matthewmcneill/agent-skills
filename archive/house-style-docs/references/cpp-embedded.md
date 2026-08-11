# C++ Embedded (ESP32/Arduino) — House Style Reference

This reference file contains all language-specific documentation patterns, code examples, and naming conventions for embedded C++ projects targeting the ESP32 platform with PlatformIO.

---

## 1. Module Header Template

Every `.hpp` and `.cpp` file must begin with this header block. Replace placeholders with actual project values — derive `PROJECT_NAME` from `library.json`, `platformio.ini`, or `README.md`.

```cpp
/*
 * [PROJECT_NAME] (c) [YEAR_RANGE] [AUTHOR/ORG]
 *
 * [REPO_URL]
 *
 * [LICENSE_TEXT]
 *
 * Module: [file path relative to repo root]
 * Description: [Multi-line description of the module's responsibility.
 *               What does it manage? What abstractions does it provide?]
 *
 * Exported Functions/Classes:
 * - [ClassName]: [Class description]
 *   - [methodName](): [Single-line description]
 *   - [_memberVar]: [Single-line description]
 * - [freeFunction](): [Single-line description]
 */
```

> [!IMPORTANT]
> The "Exported Functions/Classes" list is critical. It allows a developer to quickly see the services offered by the module without reading the whole file. Provide a one-line summary for EVERY externalized method, property, and variable.

---

## 2. Function and Method Documentation

Use Doxygen-style comment blocks for all declarations and implementations.

```cpp
/**
 * @brief Connects to the configured WiFi network with retry logic.
 *
 * Attempts connection up to maxRetries times with exponential backoff.
 * Publishes a WiFiConnected event on success via the EventBus.
 *
 * @param ssid        Network SSID to connect to.
 * @param password    Network password (WPA2).
 * @param maxRetries  Maximum connection attempts (default: 5).
 * @return true if connection succeeded, false if all retries exhausted.
 */
bool connectToNetwork(const char* ssid, const char* password, int maxRetries = 5);
```

For simple getters/setters, a single-line `@brief` is sufficient:

```cpp
/** @brief Returns the current connection state. */
bool isConnected() const;
```

---

## 3. Scoped Variables and Constants

For variables and constants defined at module level (headers or file-scope in `.cpp`), add a short description on the same line or immediately above.

```cpp
#define MAX_RETRY_COUNT 5           // Maximum number of connection attempts before failing
constexpr int kBufferSize = 256;    // Pre-allocated receive buffer size in bytes
static bool _initialized = false;   // Guards against double-init in setup()
```

For `enum class` values, document the enum itself and any non-obvious values:

```cpp
/** @brief Represents the device's current operational state. */
enum class AppState : uint8_t {
    Booting,       // Hardware initialisation in progress
    Configuring,   // Awaiting user configuration via portal
    Running,       // Normal operation — data fetch + display loop
    Updating,      // OTA firmware update in progress
    Error          // Unrecoverable error — awaiting restart
};
```

---

## 4. Internal Functional Flow

For functions longer than ~15 lines, use block comments to group logical steps and explain the flow.

```cpp
void performOtaUpdate() {
    // --- Step 1: Validate firmware metadata ---
    // Fetch the release manifest and compare semantic versions.
    // Abort early if the remote version <= current version.
    ...

    // --- Step 2: Download firmware binary ---
    // Stream the binary in 4KB chunks to avoid heap exhaustion.
    // Each chunk is verified via running MD5 checksum.
    ...

    // --- Step 3: Apply and reboot ---
    // Write to the inactive OTA partition, verify the image,
    // then set the boot partition and trigger a controlled restart.
    ...
}
```

---

## 5. Arcane and Complex Logic

Identify lines of code that are not self-explanatory and provide an explanation.

```cpp
uint8_t flags = (data >> 4) & 0x0F;         // Extract 4-bit status nibble from high byte
uint32_t timeout = 1 << (retryCount + 2);   // Exponential backoff: 4ms, 8ms, 16ms, ...
portYIELD_FROM_ISR(xHigherPriorityTaskWoken); // FreeRTOS: yield to unblocked higher-priority task
```

---

## 6. Naming Conventions

### Type and Symbol Names

| Category | Convention | Example |
|----------|-----------|---------|
| **Classes** | PascalCase | `ConfigManager`, `ClockWidget`, `EventBus` |
| **Interfaces** | PascalCase with `I` prefix | `ITickable`, `IConfigurable`, `IWebContributor` |
| **Structs** | PascalCase | `FrameworkConfig`, `DisplayInfo`, `OtaProgressEvent` |
| **Enums** | `enum class`, PascalCase | `enum class AppState`, `enum class OtaError` |
| **Enum values** | PascalCase | `AppState::Running`, `OtaError::ChecksumMismatch` |
| **Methods / Functions** | camelCase | `void getData()`, `bool isReady()` |
| **Variables** | camelCase | `int retryCount`, `bool isConnected` |
| **Member variables** | camelCase with `_` prefix | `int _retryCount`, `String _hostname` |
| **Constants / Macros** | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT`, `PIN_LED`, `FIRMWARE_VERSION` |
| **Namespaces** | lowercase | `namespace config {}` |

### File and Directory Names

| Category | Convention | Example |
|----------|-----------|---------|
| **Source files** | PascalCase, matching primary class | `ConfigManager.hpp`, `EventBus.cpp` |
| **Interface files** | PascalCase, matching interface name | `ITickable.hpp`, `IConfigurable.hpp` |
| **Module directories** | camelCase | `configManager/`, `otaUpdateManager/` |
| **Library directories** | camelCase | `deviceCrypto/`, `otaDownloadEngine/` |

> [!IMPORTANT]
> **File ↔ Class Alignment Rule**: The file name MUST match the primary class or type it exports.
> - `class ConfigManager` → `ConfigManager.hpp` / `ConfigManager.cpp`
> - `class ITickable` → `ITickable.hpp`
> - `enum class OtaError` → `OtaError.hpp` / `OtaError.cpp`
>
> This eliminates ambiguity and follows the LLVM/Unreal/Qt convention.

### Naming Exemptions

The following are exempt from the naming conventions above:

| Category | Reason | Example |
|----------|--------|---------|
| **Test files** | PlatformIO requires `test_` prefix for test discovery | `test/test_unit/test_configManager/test_configManager.cpp` |
| **Auto-generated portal assets** | Generated from web filenames; changing breaks the build pipeline | `include/portal_assets/app_css.hpp` |
| **Binary/XBM assets** | Embedded image data with conventional names | `cblabs_logo.h` |
| **Third-party / SDK mock stubs** | Must match upstream header names for compatibility | `Arduino.h`, `WiFi.h`, `HTTPClient.h` |

### Git Case Sensitivity Note

On macOS (case-insensitive filesystem), renaming a file from `configManager.hpp` to `ConfigManager.hpp` requires a two-step `git mv` to avoid index confusion:

```bash
git mv ConfigManager.hpp ConfigManager.hpp.tmp
git mv ConfigManager.hpp.tmp ConfigManager.hpp
```

This is reliable and scriptable. No git database cleanup is needed.

---

## Summary Cheat Sheet

```
Files:        PascalCase  →  ConfigManager.hpp, ITickable.hpp
Classes:      PascalCase  →  ConfigManager, EventBus
Interfaces:   I + Pascal  →  ITickable, IWebContributor
Structs:      PascalCase  →  FrameworkConfig, DisplayInfo
Enums:        PascalCase  →  enum class AppState
Methods:      camelCase   →  getData(), isReady()
Variables:    camelCase   →  retryCount, isConnected
Members:      _camelCase  →  _retryCount, _hostname
Constants:    SCREAMING   →  MAX_RETRY_COUNT, PIN_LED
Directories:  camelCase   →  configManager/, eventBus/
```

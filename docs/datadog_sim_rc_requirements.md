# DatadogSim Remote Config — Requirements and Issues

This document captures everything learned while getting `simulate_service` to appear
as a live, DI-enabled service to the Datadog backend. Each section describes a
requirement, the symptom when it is violated, and the root cause.

**References:**
- `debugger-backend/debugger-common/src/main/kotlin/com/datadog/debugger/enablement/Heartbeat.kt`
- `debugger-backend/debugger-common/src/main/kotlin/com/datadog/debugger/enablement/TracerVersionChecker.kt`
- `debugger-backend/debugger-common/src/main/kotlin/com/datadog/debugger/enablement/AgentVersionChecker.kt`
- `lib/datadog_sim/remote_config.rb`
- `lib/datadog_sim/languages.rb`

---

## Requirement 1: Non-empty capabilities bitmask

**Symptom:** Every RC poll returns `"targets": {}`. No configs are ever delivered,
regardless of how long the script runs.

**Root cause:** The backend validates `client.capabilities` to confirm the client is a
genuine tracer. An empty string (`""`) or `Base64("\x00")` is treated as an unknown or
invalid client — the backend's heartbeat listener discards the entry entirely.

**Fix:** Send APM_TRACING capability bits (12, 13, 14, 29):

```
(1<<12)|(1<<13)|(1<<14)|(1<<29) = 0x20007000 = bytes [32, 0, 112, 0] = "IABwAA=="
```

These are the bits a real Ruby/Java tracer sends for:
- `APM_TRACING_SAMPLE_RATE` (bit 12)
- `APM_TRACING_LOGS_INJECTION` (bit 13)
- `APM_TRACING_HTTP_HEADER_TAGS` (bit 14)
- `APM_TRACING_SAMPLE_RULES` (bit 29)

**Note:** DI and SymDB products have no defined capability bits of their own — only
`APM_TRACING` bits are needed to pass validation.

---

## Requirement 2: Valid semver tracer version above minimum

**Symptom:** `targets: {}` even with correct capabilities. The DI UI does not show
the service as alive. Backend logs show "Tracer version, language, or agent version
not set".

**Root cause:** `Heartbeat.meetsVersionRequirements()` reads `tracer_version` from the
tags set and calls `TracerVersionChecker.isDISupported(language, version)`. An invalid
semver like `"1.x.x"` fails parsing and the heartbeat is silently discarded.

**Minimum versions required** (source: `TracerVersionChecker.kt`):

| Language | DI minimum | SymDB minimum |
|----------|-----------|---------------|
| java     | 1.5.0     | 1.34.0        |
| dotnet   | 2.23.0    | 2.57.0        |
| python   | 1.8.0     | 2.9.0         |
| go       | 1.64.0    | see VERSION_RANGES |
| ruby     | 2.9.0     | 2.11.0        |
| node     | 5.39.0    | —             |
| php      | 1.5.0     | —             |

**Fix:** Use real semver strings exceeding the minimums. See `languages.rb`.

---

## Requirement 3: Declare LIVE_DEBUGGING and/or LIVE_DEBUGGING_SYMBOL_DB products

**Symptom:** Client is not selected for DI or SymDB config delivery.

**Root cause:** `HeartbeatUtils.validActiveClientsList()` filters out clients that
don't declare at least one of `LIVE_DEBUGGING` or `LIVE_DEBUGGING_SYMBOL_DB` in
`client.products`.

**Fix:** Always include both, plus `APM_TRACING` to match a real tracer:

```ruby
products: ['APM_TRACING', 'LIVE_DEBUGGING', 'LIVE_DEBUGGING_SYMBOL_DB']
```

---

## Requirement 4: TUF bootstrap — accumulate root_version with +=

**Symptom:** Infinite bootstrap loop. Agent keeps returning `roots` arrays on every
poll. `root_version` oscillates between 1 and 15 instead of converging to 16.

**Root cause:** The agent uses TUF (The Update Framework). On first connect it returns
a `roots` array. The client must send the updated `root_version` on the next request
to signal it processed the roots. The agent sends roots in batches:
- Poll 1: 15 roots → client should set root_version = 1 + 15 = 16
- Poll 2: 1 more root → client should set root_version = 16 + 1 = 17

Using assignment (`root_version = roots.size`) resets to 1 after the second batch,
causing the loop to restart.

**Fix:** Use accumulation:
```ruby
@root_version += roots.size  # NOT @root_version = roots.size
```

---

## Requirement 5: Advance targets_version and backend_client_state

**Symptom:** Agent sends the same `targets` response on every poll after bootstrap.
`targets_version` never advances. `client_configs` is never included.

**Root cause:** The agent's RC protocol requires the client to echo back the
`targets_version` and `opaque_backend_state` from the previous response. Without this,
the backend treats each request as if it hasn't seen any configs yet and resends the
same targets.

The `targets` field in the response is a **base64-encoded TUF JSON string**, not a
nested hash. Calling `body.dig('targets', 'signed', 'version')` raises
`TypeError: String does not have #dig method`.

**Fix:** Decode and extract:
```ruby
targets = JSON.parse(Base64.decode64(body['targets']))
@targets_version = targets.dig('signed', 'version')
@backend_client_state = targets.dig('signed', 'custom', 'opaque_backend_state')
```

---

## Requirement 6: Stable client_id and runtime_id across all polls

**Symptom:** Each poll looks like a new unknown instance. The backend never selects
this client for config delivery even after many heartbeats.

**Root cause:** The backend tracks live instances in Cassandra (60s TTL) keyed by
`runtimeId` and `datadogAgentId`. If these change between polls the backend sees a
new instance each time and the heartbeat store never builds up enough state.

**Fix:** Generate both once at initialization and reuse throughout the session.

---

## Issue: RC worker not started in plain Ruby scripts

**Symptom:** RC client initialises but never polls. No "polled" log output appears.
`Datadog.send(:components).remote.started?` returns false.

**Root cause:** The RC worker is normally started by the Rack middleware
(`Datadog::Tracing::Contrib::Rack::Patcher`) when the first HTTP request arrives.
In a plain Ruby script with no Rack, the worker is built but never started.

**Fix:** Call `Datadog.send(:components).remote.start` explicitly after configuring
the tracer. See `bin/test_rc`.

---

## Issue: Setting c.logger with a plain Logger instance crashes

**Symptom:** `NoMethodError: undefined method 'instance' for #<Logger:...>`

**Root cause:** `Datadog.configure { |c| c.logger = my_logger }` expects a Datadog
logger wrapper, not a plain `Logger`. The components build method calls
`settings.logger.instance` which doesn't exist on `Logger`.

**Fix:** Use `DD_TRACE_DEBUG=true` env var for debug output instead of setting
`c.logger` directly.

---

## Issue: DI configuration causes reconfiguration loop

**Symptom:** RC worker starts, immediately stops. Log shows:
`remote worker stopping (pid: ...)` within milliseconds of startup.

**Root cause:** Setting `c.dynamic_instrumentation.enabled = true` inside
`Datadog.configure` when RC isn't available yet triggers a reconfiguration cycle,
which shuts down and rebuilds components including the RC worker.

**Fix:** Set all configuration via environment variables (`DD_REMOTE_CONFIGURATION_ENABLED`,
`DD_DYNAMIC_INSTRUMENTATION_ENABLED`) **before** requiring the tracer, so it configures
only once. See `bin/test_rc`.

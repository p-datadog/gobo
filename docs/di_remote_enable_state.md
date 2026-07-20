# Dynamic Instrumentation enablement

How Dynamic Instrumentation (DI) gets enabled, what the DI Status page's
**Remote enablement (DI enable state)** panel shows, and why a running service
like gobo can sit at `can_enable_remotely` even with sessions/probes defined.

**References:**
- `lib/remote_enablement_query.rb`, `app/controllers/di_status_controller.rb`
  (`fetch_remote_enablement`, `fetch_di_enabled_status`),
  `app/views/di_status/index.html.erb`, `bin/run` (gobo)
- `dd-trace-rb/lib/datadog/di/remote.rb`, `dd-trace-rb/lib/datadog/di/component.rb` (tracer)
- `dd-go/remote-config/apps/rc-api/products/apmtracing/debugger_config_routes.go` (backend)
- web-ui `packages/apps/live-debugger/toolkit/probe-modal/NewProbeModal.tsx`,
  `.../probe-modal/ProbeModalProvider.heavy.tsx`,
  `.../service-setup/use-remote-enablement-with-reauth.hook.ts`,
  `.../service-setup/use-implicit-enablement-eligibility.hook.ts`

---

## The two states, and why they differ

The DI Status page surfaces two independent signals that are easy to confuse:

- **Tracer in-process state** (`di_enabled`, top of the page) — what *this*
  process is doing: `enabled_explicitly`, `enabled_implicitly`,
  `can_enable_remotely`, `disabled_explicitly`, etc. (see
  `fetch_di_enabled_status`).
- **Backend enable state** (`dynamic_instrumentation_enabled`, Remote enablement
  panel) — what the backend has *stored* as its intent for the service+env.

`can_enable_remotely` (tracer) + `enabled` (backend) means the backend wants DI
on but this process has not been switched on yet. `can_enable_remotely` +
`not set` (backend) means nothing is telling the tracer to turn DI on — DI stays
off, correctly.

## How DI actually turns on in the tracer

DI starts in exactly these ways (current tracer, `di/remote.rb` /
`di/component.rb`):

1. **Explicit env var** — `DD_DYNAMIC_INSTRUMENTATION_ENABLED=1` at boot. In
   gobo, `bin/run -i` sets this (and `DD_SYMBOL_DATABASE_UPLOAD_ENABLED`).
2. **Remote enablement** — an `APM_TRACING` remote-config payload carrying
   `dynamic_instrumentation_enabled=true` invokes `Remote.handle_rc_enablement(true)`
   → `component.start!`. The tracer advertises this via the
   `APM_TRACING_ENABLE_DYNAMIC_INSTRUMENTATION` capability and subscribes to the
   `LIVE_DEBUGGING` product for probes.

`DD_DYNAMIC_INSTRUMENTATION_ENABLED=false` blocks remote enablement entirely.

**A defined probe does not start DI on its own.** While the component is
stopped, `#receivers` ignores `LIVE_DEBUGGING` changes, so a delivered probe is
dropped and never enters the repository. Only the enable signal (env var or the
`APM_TRACING` enable) starts DI; on the stopped→started transition the tracer
reconciles against the current `LIVE_DEBUGGING` contents so a
previously-dropped probe installs then. Consequence: if the backend never sends
the enable, Remote Config returns empty every poll, DI never starts, and probes
never install.

## The backend enable flag

`dynamic_instrumentation_enabled` is `LibConfig.DynamicInstrumentation` (`*bool`)
inside the org's `apm_tracing` remote-config config, keyed by service + env.
Served as JSON:API `debugger_config` objects at

    GET /api/unstable/remote_config/products/apm_tracing/debugger_configs/envs/<env>/services/<service>

Tri-state: `true` = enabled, `false` = explicitly disabled, absent = **unset**
(treated as automatic/eligible, not enabled). `config_exists=true` only means
*some* `apm_tracing` flag has been written for the service+env — the DI bit can
still be absent.

### What writes it

1. **Explicit toggle** — the Remote Enablement switch in the Datadog UI → PUT
   `dynamicInstrumentationEnabled: true/false`; DELETE clears it to unset.
2. **Implicit one-click enable on probe creation** — the New Probe modal fires
   a silent PUT (`enablement: true`, `feature: 'dynamic-instrumentation'`,
   `isImplicit: true`) *before* submitting the probe
   (`NewProbeModal.onCreateProbeClick` → `handleCreateDebuggerConfiguration`).
   **This is gated** and is skipped unless all hold:
     - a concrete env is selected (not `NONE`, not `ALL`);
     - `isSelectedEnvConfigured` is false — and that is defined as
       `envInstances.length > 0` (`ProbeModalProvider.heavy.tsx`), i.e. the enable
       fires **only when the env has no live instances**;
     - the language/version supports remote enablement.
   So creating a probe enables DI **only for a fresh env with no reporting
   instances**. For an already-running service (live instances present), probe
   creation does **not** enable DI.
3. **Backend implicit guard** — on the implicit path, an existing explicit
   `false` is preserved (the implicit PUT does not override an opt-out)
   (`debugger_config_routes.go`).
4. **Env/org-level fallback** — a `service=*` config can supply the value by
   inheritance for multi-config-capable tracers only. **Not applicable to ruby**
   (ruby is absent from `MinVersionForDIMultiConfig`).

### Support requirements (from the backend `features` block)

For ruby the backend reports: `dynamic_instrumentation` supported (min `2.9.0`),
`remote_enablement` supported (min `2.37.0`), `remote_enablement_multi_config`
**not** supported. So a ruby tracer ≥ 2.37 (e.g. gobo's `2.39.0-dev`) fully
supports service+env remote enablement — the only missing input to enable DI is
the flag being set to `true`.

## Enabling DI for gobo

gobo runs with live instances, so **creating a probe will not enable DI** for it
(the implicit enable is gated on an env with no instances). To turn DI on:

- **Locally:** `bin/run -i` (sets `DD_DYNAMIC_INSTRUMENTATION_ENABLED=1`), or
- **Remotely:** set the backend flag `true` for gobo + its env via the Remote
  Enablement toggle in the Datadog UI. The tracer then receives the `APM_TRACING`
  enable and starts DI on the next Remote Config poll.

## Sequences that do NOT enable DI (and the one that does)

- **Creating a probe while gobo is running does not enable DI.** The implicit
  one-click enable is skipped because the env has live instances
  (`isSelectedEnvConfigured = envInstances.length > 0`). The backend flag stays
  unset, so nothing enables DI. The probe erroring is irrelevant — enablement is
  written (or not) at creation time via the PUT, independent of install status.
- **Stopping and restarting gobo does not enable DI either.** Restart creates no
  probe and sets no flag; the tracer polls Remote Config and, with the flag
  unset, receives no enable. So "create a probe, stop gobo, restart gobo" does
  **not** turn DI on automatically.
- **The only implicit-path sequence that works:** stop gobo → wait for its
  instances to age out of the backend (so the env shows zero live instances) →
  create the probe (now the one-click enable fires and sets the flag `true`) →
  start gobo (Remote Config delivers the `APM_TRACING` enable →
  `component.start!`, then the pending probe reconciles/installs). Order and the
  zero-instances condition are both required.

### Verifying from the tracer log (`-d`)

With `DD_TRACE_DEBUG=1`, DI is enabled only if the log shows the enable being
received. When DI is not being enabled you will see the Remote Config worker
reporting `remote: no changes` / `remote: empty response => NOOP` on every poll,
and **no** `handle_rc_enablement`, `received … probe`, `component.start!`, or
`di: installed` lines. Note the `apm_tracing/debugger_configs` URLs that appear
as trace spans are gobo's own `RemoteEnablementQuery` calls, not the tracer's
Remote Config receiving an enable.

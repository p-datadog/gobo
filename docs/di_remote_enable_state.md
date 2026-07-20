# Dynamic Instrumentation remote-enable state

Explains the `dynamic_instrumentation_enabled` value shown in the DI Status
page's **Remote enablement (DI enable state)** panel: what it is, and what
causes the backend to set it.

**References:**
- `lib/remote_enablement_query.rb` (gobo query)
- `app/controllers/di_status_controller.rb` (`fetch_remote_enablement`)
- `app/views/di_status/index.html.erb` (Remote enablement panel)
- `dd-go/remote-config/apps/rc-api/products/apmtracing/debugger_config_routes.go` (backend)
- web-ui `packages/apps/live-debugger/toolkit/service-setup/use-implicit-enablement-eligibility.hook.ts`
- web-ui `packages/apps/live-debugger/toolkit/service-setup/use-remote-enablement-with-reauth.hook.ts`

---

## What it is

In gobo the field is **mirrored** from the backend endpoint —
`RemoteEnablementQuery` reads it from

    GET /api/unstable/remote_config/products/apm_tracing/debugger_configs/envs/<env>/services/<service>

Nothing in gobo sets it. On the backend it is `LibConfig.DynamicInstrumentation`
(`*bool`, json `dynamic_instrumentation_enabled`) inside the org's `apm_tracing`
remote-config config, keyed by service + env. Tri-state:

- `true` → badge **enabled**: the backend wants DI turned on remotely for this
  service+env.
- `false` → badge **disabled**: explicitly turned off.
- absent → badge **not set**: never written.

This is distinct from the tracer's in-process `di_enabled` state at the top of
the page. `can_enable_remotely` (tracer) + `enabled` (backend) means the backend
wants DI on but this process has not been switched on yet.

## What causes it to be set

A PUT/POST to the `apm_tracing` `debugger_configs` route runs `ApplyLibConfig`
→ `LibConfig.DynamicInstrumentation`. Three triggers:

1. **Explicit toggle** — the Remote Enablement switch in the Datadog UI sends a
   PUT with `dynamicInstrumentationEnabled: true/false`; DELETE clears it back
   to "not set".

2. **Implicit enablement on probe/session creation** (`?implicit=true`).
   Creating a DI probe/session in the UI makes the frontend (probe-modal →
   `useImplicitEnablementEligibility` → `shouldImplicitlyEnable`) fire an
   implicit-enable PUT. Backend logic
   (`debugger_config_routes.go` lines 1080–1123, comment *"Check if this is an
   implicit flow (for DI probe creation)"*):
     - config absent → create it with enablement = `true`;
     - config exists but DI explicitly `false` → implicit flow **preserves** the
       disable (does not override);
     - otherwise → set enablement.

   So creating a probe/session sets `dynamic_instrumentation_enabled = true`,
   unless DI had been explicitly turned off. This is the usual cause when a
   service shows enabled after a session/probe was created.

3. **Env/org-level fallback** — a `service=*` config can supply the value by
   inheritance for multi-config-capable tracers, with no per-service write. This
   does not apply to ruby (ruby is absent from `MinVersionForDIMultiConfig` in
   `debugger_config_routes.go`).

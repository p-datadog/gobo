# frozen_string_literal: true

module DatadogSim
  # Known Datadog tracer language profiles.
  # Each entry defines the values a real tracer of that language would send
  # in telemetry, remote config, and trace payloads.
  #
  # == tracer_version constraints
  #
  # `tracer_version` is checked against TWO INDEPENDENT version gates between
  # this simulator and the implicit-DI-enablement signal. Both must pass for
  # the UI "create a probe" flow to trigger enablement against a simulated
  # service. The simulator's reported version must exceed BOTH floors.
  #
  # 1. Backend gate — `TracerVersionChecker.kt` in debugger-backend. Drops
  #    the heartbeat if the tracer version is below the minimum, so the
  #    service does not even appear alive in the DI UI.
  #      DI:    java>=1.5.0, dotnet>=2.23.0, python>=1.8.0, go>=1.64.0,
  #             ruby>=2.9.0, node>=5.39.0, php>=1.5.0
  #      SymDB: java>=1.34.0, dotnet>=2.57.0, python>=2.9.0, ruby>=2.11.0
  #
  # 2. Frontend gate — `REMOTE_ENABLEMENT_MIN_TRACER_VERSION_BY_CLIENT_RUNTIME`
  #    in web-ui (`packages/apps/live-debugger/lib/remote-enablement/constants.ts`).
  #    If the tracer version is below the minimum, the probe-creation flow
  #    silently skips the call to the enablement endpoint — the service
  #    appears alive but creating a probe does NOT trigger
  #    `dynamic_instrumentation_enabled: true` via APM_TRACING RC.
  #    Current floors (as of 2026-06-08, verify against the linked file):
  #      java   1.48.0
  #      dotnet 3.29.0
  #      python 3.10.0
  #      ruby   2.31.0 (placeholder per web-ui PR #286651 — will be bumped
  #             to the actual dd-trace-rb release containing PR #5525,
  #             expected >= 2.35.0)
  #      go     2.6.0
  #      node   5.83.0 (DI) / 5.84.0 (live-debugger)
  #      php    — not yet supported
  #
  # Fake versions below intentionally exceed BOTH floors so that all
  # backend AND frontend gates pass. When bumping these, cross-check both
  # the backend `TracerVersionChecker.kt` floors AND the web-ui
  # `constants.ts` floors — a sim version that passes only the backend gate
  # will look alive in the UI but creating a probe will silently fail to
  # trigger enablement.
  LANGUAGES = {
    'ruby' => {
      language_name: 'ruby',
      runtime_name: 'ruby',
      runtime_version: RUBY_VERSION,
      # 2.35.35 — intentionally above web-ui PR #286651's 2.31.0 placeholder
      # AND above the expected real-release floor (>= 2.35.0). High patch
      # number to stay above any near-term bump of the web-ui placeholder.
      tracer_version: '2.35.35',
      rc_language: 'ruby',
    },
    'java' => {
      language_name: 'jvm',
      runtime_name: 'OpenJDK 64-Bit Server VM',
      runtime_version: '17.0.9',
      tracer_version: '1.40.0',
      rc_language: 'java',
    },
    'python' => {
      language_name: 'CPython',
      runtime_name: 'CPython',
      runtime_version: '3.11.0',
      tracer_version: '2.10.0',
      rc_language: 'python',
    },
    'dotnet' => {
      language_name: 'dotnet',
      runtime_name: 'dotnet',
      runtime_version: '7.0.0',
      tracer_version: '2.60.0',
      rc_language: 'dotnet',
    },
    'go' => {
      language_name: 'go',
      runtime_name: 'go',
      runtime_version: '1.21.0',
      tracer_version: '1.70.0',
      rc_language: 'go',
    },
    'node' => {
      language_name: 'nodejs',
      runtime_name: 'nodejs',
      runtime_version: '20.0.0',
      tracer_version: '5.40.0',
      rc_language: 'nodejs',
    },
    'php' => {
      language_name: 'php',
      runtime_name: 'php',
      runtime_version: '8.2.0',
      tracer_version: '1.6.0',
      rc_language: 'php',
    },
  }.freeze
end

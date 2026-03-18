# frozen_string_literal: true

module DatadogSim
  # Known Datadog tracer language profiles.
  # Each entry defines the values a real tracer of that language would send
  # in telemetry, remote config, and trace payloads.
  # Tracer versions must be valid semver and meet the backend's minimum version
  # requirements for DI and SymDB support (see TracerVersionChecker.kt):
  #   DI:    java>=1.5.0, dotnet>=2.23.0, python>=1.8.0, go>=1.64.0, ruby>=2.9.0, node>=5.39.0, php>=1.5.0
  #   SymDB: java>=1.34.0, dotnet>=2.57.0, python>=2.9.0, ruby>=2.11.0
  # Fake versions intentionally exceed minimums to pass all checks.
  LANGUAGES = {
    'ruby' => {
      language_name: 'ruby',
      runtime_name: 'ruby',
      runtime_version: RUBY_VERSION,
      tracer_version: '2.30.0',
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

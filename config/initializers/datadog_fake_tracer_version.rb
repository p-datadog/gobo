# Applies GOBO_FAKE_TRACER_VERSION (set by `bin/run -V`) so the app reports a
# fake tracer library version to the Datadog backend.

fake_tracer_version = ENV['GOBO_FAKE_TRACER_VERSION']
if fake_tracer_version && !fake_tracer_version.empty?
  require_relative '../../lib/fake_tracer_version'
  FakeTracerVersion.apply(fake_tracer_version)
end

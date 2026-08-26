# Overrides the tracer library version that dd-trace-rb reports to the Datadog
# backend. The tracer derives its reported version from
# Datadog::Core::Environment::Identity.gem_datadog_version (RubyGems form) and
# .gem_datadog_version_semver2 (semver-2 form, computed from the former), which
# feed telemetry, remote configuration, process discovery, tags and Dynamic
# Instrumentation. Redefining gem_datadog_version makes every reporter emit the
# fake version.
module FakeTracerVersion
  # Accepts a leading MAJOR.MINOR.PATCH with optional dot-separated prerelease
  # and build segments (e.g. "2.9.0", "2.40.0.dev").
  VERSION_PATTERN = /\A\d+\.\d+\.\d+(\.[0-9A-Za-z-]+)*\z/

  class Error < StandardError; end

  def self.apply(version)
    unless version.is_a?(String) && version.match?(VERSION_PATTERN)
      raise Error, "Invalid fake tracer version: #{version.inspect} (expected MAJOR.MINOR.PATCH with optional dot-separated segments)"
    end

    unless defined?(Datadog::Core::Environment::Identity)
      raise Error, "Cannot fake tracer version: Datadog::Core::Environment::Identity is not defined (datadog gem not loaded)"
    end

    Datadog::Core::Environment::Identity.define_singleton_method(:gem_datadog_version) { version }
    version
  end
end

# Audits the DI CodeTracker registry against $LOADED_FEATURES to find
# files that Ruby has loaded but CodeTracker doesn't know about.
#
# Usage: called from bin/audit-code-tracker after Rails boots.
module CodeTrackerAudit
  # Returns a hash with audit results:
  #   :loaded       - all .rb files from $LOADED_FEATURES with absolute paths
  #   :tracked      - all paths in the CodeTracker registry
  #   :missing      - loaded but not tracked (line probes won't work)
  #   :extra        - tracked but not in $LOADED_FEATURES (e.g. backfill found orphaned iseqs)
  #   :c_extensions - .so/.bundle files from $LOADED_FEATURES (can't be tracked)
  def self.run
    loaded_rb = $LOADED_FEATURES
      .select { |f| f.end_with?(".rb") && f.start_with?("/") }
      .uniq
      .sort

    c_extensions = $LOADED_FEATURES
      .select { |f| f.end_with?(".so", ".bundle", ".dll") }
      .sort

    registry = if defined?(Datadog::DI) && Datadog::DI.code_tracker
      Datadog::DI.code_tracker.send(:registry)
    else
      {}
    end

    tracked = registry.keys.sort

    missing = loaded_rb - tracked
    extra = tracked - loaded_rb

    {
      loaded: loaded_rb,
      tracked: tracked,
      missing: missing,
      extra: extra,
      c_extensions: c_extensions,
    }
  end

  def self.categorize(path)
    app_root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
    gem_dirs = Gem.path

    if path.start_with?(app_root)
      :app
    elsif gem_dirs.any? { |d| path.start_with?(d) } ||
        path.include?("/vendor/bundle/") ||
        path.include?("/bundler/gems/")
      :gem
    elsif path.start_with?(RbConfig::CONFIG["rubylibdir"]) ||
        path.start_with?(RbConfig::CONFIG["archdir"])
      :stdlib
    else
      :other
    end
  end

  def self.format_report(results)
    lines = []
    lines << "=== Code Tracker Audit ==="
    lines << "Loaded .rb files:    #{results[:loaded].size}"
    lines << "Tracked in registry: #{results[:tracked].size}"
    lines << "C extensions:        #{results[:c_extensions].size}"
    lines << "Missing from registry: #{results[:missing].size}"
    lines << "Extra in registry:     #{results[:extra].size}"
    lines << ""

    if results[:missing].any?
      grouped = results[:missing].group_by { |p| categorize(p) }
      lines << "--- Missing (loaded but not tracked) ---"
      [:app, :gem, :stdlib, :other].each do |cat|
        files = grouped[cat]
        next unless files&.any?
        lines << "  #{cat} (#{files.size}):"
        files.each { |f| lines << "    #{f}" }
      end
      lines << ""
    end

    if results[:extra].any?
      lines << "--- Extra (tracked but not in $LOADED_FEATURES) ---"
      results[:extra].each { |f| lines << "    #{f}" }
      lines << ""
    end

    lines.join("\n")
  end
end

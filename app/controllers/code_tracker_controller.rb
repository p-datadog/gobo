class CodeTrackerController < ApplicationController
  def index
    @tracking_active = false
    @entries = []
    @counts = {app: 0, gem: 0, stdlib: 0, other: 0}
    @audit = nil

    return unless defined?(Datadog::DI)

    code_tracker = Datadog::DI.code_tracker
    return unless code_tracker

    @tracking_active = code_tracker.active?
    registry = code_tracker.send(:registry)

    app_root = Rails.root.to_s
    gem_dirs = Gem.path

    have_iseq_type = defined?(Datadog::DI) && Datadog::DI.respond_to?(:iseq_type)

    registry.each do |path, iseq|
      category = categorize_path(path, app_root, gem_dirs)
      @counts[category] += 1

      iseq_type = if have_iseq_type
        Datadog::DI.iseq_type(iseq)
      end

      @entries << {
        path: path,
        category: category,
        iseq_type: iseq_type,
        first_lineno: iseq.first_lineno,
      }
    end

    @entries.sort_by! { |e| [e[:category].to_s, e[:path]] }

    # Audit: compare registry against $LOADED_FEATURES
    tracked_paths = registry.keys.to_set
    loaded_rb = $LOADED_FEATURES
      .select { |f| f.end_with?(".rb") && f.start_with?("/") }
      .uniq

    missing = loaded_rb.reject { |f| tracked_paths.include?(f) }
    missing_by_category = missing.group_by { |f| categorize_path(f, app_root, gem_dirs) }

    @audit = {
      loaded_rb: loaded_rb.size,
      tracked: tracked_paths.size,
      c_extensions: $LOADED_FEATURES.count { |f| f.end_with?(".so", ".bundle", ".dll") },
      missing: missing.size,
      missing_by_category: missing_by_category,
      missing_app: missing_by_category[:app] || [],
    }
  rescue => e
    Rails.logger.error "Error reading code tracker registry: #{e.class}: #{e}"
    @error = "#{e.class}: #{e}"
  end

  private

  def categorize_path(path, app_root, gem_dirs)
    if path.start_with?(app_root)
      :app
    elsif gem_dirs.any? { |dir| path.start_with?(dir) } ||
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
end

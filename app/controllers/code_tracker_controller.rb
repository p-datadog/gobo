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

    # Per-method iseq coverage: how many missing files have surviving
    # per-method iseqs that could be used for line probes?
    method_iseq_coverage = if Datadog::DI.respond_to?(:all_iseqs) && have_iseq_type
      missing_set = missing.to_set
      files_with_method_iseqs = Set.new
      method_iseq_count_by_file = Hash.new(0)

      Datadog::DI.all_iseqs.each do |iseq|
        path = iseq.absolute_path
        next unless path && missing_set.include?(path)
        type = Datadog::DI.iseq_type(iseq)
        next if type == :top || type == :main
        files_with_method_iseqs << path
        method_iseq_count_by_file[path] += 1
      end

      {
        missing_with_method_iseqs: files_with_method_iseqs.size,
        missing_without_any_iseqs: missing.size - files_with_method_iseqs.size,
        total_method_iseqs: method_iseq_count_by_file.values.sum,
        by_category: [:app, :gem, :stdlib, :other].map { |cat|
          cat_files = (missing_by_category[cat] || [])
          covered = cat_files.count { |f| files_with_method_iseqs.include?(f) }
          [cat, {total: cat_files.size, with_method_iseqs: covered}]
        }.to_h,
      }
    end

    @audit = {
      loaded_rb: loaded_rb.size,
      tracked: tracked_paths.size,
      c_extensions: $LOADED_FEATURES.count { |f| f.end_with?(".so", ".bundle", ".dll") },
      missing: missing.size,
      missing_by_category: missing_by_category,
      missing_app: missing_by_category[:app] || [],
      method_iseq_coverage: method_iseq_coverage,
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

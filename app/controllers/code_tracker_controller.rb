class CodeTrackerController < ApplicationController
  before_action :load_registry_data

  def index
    # Show app + stdlib entries only, including partially covered stdlib
    @entries = @all_entries.select { |e| e[:category] == :app || e[:category] == :stdlib }
    @entries.sort_by! { |e| [e[:coverage].to_s, e[:path]] }
  end

  def full
    @entries = @all_entries.sort_by { |e| [e[:category].to_s, e[:coverage].to_s, e[:path]] }
  end

  private

  def load_registry_data
    @tracking_active = false
    @all_entries = []
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

    @ruby_github_tag = "v#{RUBY_VERSION.tr('.', '_')}"
    @stdlib_prefix = RbConfig::CONFIG["rubylibdir"] + "/"

    # Fully covered entries from main registry.
    registry.each do |path, iseq|
      category = categorize_path(path, app_root, gem_dirs)
      @counts[category] += 1

      iseq_type = if have_iseq_type
        Datadog::DI.iseq_type(iseq)
      end

      @all_entries << {
        path: path,
        category: category,
        coverage: :full,
        iseq_type: iseq_type,
        first_lineno: iseq.first_lineno,
      }
    end

    # Partially covered entries from per-method registry.
    has_per_method = code_tracker.send(:instance_variable_defined?, :@per_method_registry)
    per_method = has_per_method ? code_tracker.send(:per_method_registry) : {}

    per_method.each do |path, iseqs|
      next if registry.key?(path) # already fully covered
      category = categorize_path(path, app_root, gem_dirs)

      @all_entries << {
        path: path,
        category: category,
        coverage: :partial,
        iseq_count: iseqs.size,
      }
    end

    # Audit stats.
    tracked_paths = registry.keys.to_set
    per_method_paths = per_method.keys.to_set

    loaded_rb = $LOADED_FEATURES
      .select { |f| f.end_with?(".rb") && f.start_with?("/") }
      .uniq

    not_in_registry = loaded_rb.reject { |f| tracked_paths.include?(f) }
    partially_covered = not_in_registry.select { |f| per_method_paths.include?(f) }
    not_covered = not_in_registry.reject { |f| per_method_paths.include?(f) }

    not_covered_by_category = not_covered.group_by { |f| categorize_path(f, app_root, gem_dirs) }
    partially_by_category = partially_covered.group_by { |f| categorize_path(f, app_root, gem_dirs) }

    @audit = {
      loaded_rb: loaded_rb.size,
      fully_covered: tracked_paths.size,
      partially_covered: partially_covered.size,
      not_covered: not_covered.size,
      c_extensions: $LOADED_FEATURES.count { |f| f.end_with?(".so", ".bundle", ".dll") },
      total_method_iseqs: per_method.values.sum(&:size),
      not_covered_by_category: not_covered_by_category,
      partially_by_category: partially_by_category,
      missing_app: not_covered_by_category[:app] || [],
    }
  rescue => e
    Rails.logger.error "Error reading code tracker registry: #{e.class}: #{e}"
    @error = "#{e.class}: #{e}"
  end

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

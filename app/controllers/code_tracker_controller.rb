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

    # For linking stdlib files to Ruby source on GitHub.
    @ruby_github_tag = "v#{RUBY_VERSION.tr('.', '_')}"
    @stdlib_prefix = RbConfig::CONFIG["rubylibdir"] + "/"

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
    has_per_method = code_tracker.send(:instance_variable_defined?, :@per_method_registry)
    per_method = has_per_method ? code_tracker.send(:per_method_registry) : {}
    per_method_paths = per_method.keys.to_set

    loaded_rb = $LOADED_FEATURES
      .select { |f| f.end_with?(".rb") && f.start_with?("/") }
      .uniq

    # Three categories:
    # - fully covered: in main registry (whole-file iseq)
    # - partially covered: not in main registry but has per-method iseqs
    # - not covered: no iseqs at all
    not_in_registry = loaded_rb.reject { |f| tracked_paths.include?(f) }
    partially_covered = not_in_registry.select { |f| per_method_paths.include?(f) }
    not_covered = not_in_registry.reject { |f| per_method_paths.include?(f) }

    not_covered_by_category = not_covered.group_by { |f| categorize_path(f, app_root, gem_dirs) }
    partially_by_category = partially_covered.group_by { |f| categorize_path(f, app_root, gem_dirs) }

    total_method_iseqs = per_method.values.sum(&:size)

    # Suggest line probe targets for testing each tier.
    test_targets = []

    # Fully covered: pick an app file from the main registry.
    registry.each do |path, iseq|
      next unless categorize_path(path, app_root, gem_dirs) == :app
      tps = iseq.trace_points.select { |_, ev| ev == :line }
      if tps.any?
        test_targets << {tier: :fully_covered, path: path, line: tps.first[0]}
        break
      end
    end

    # Partially covered: pick a gem file with per-method iseqs.
    if per_method.any?
      per_method.each do |path, iseqs|
        next unless categorize_path(path, app_root, gem_dirs) == :gem
        iseqs.each do |iseq|
          tps = iseq.trace_points.select { |_, ev| ev == :line }
          if tps.any?
            test_targets << {
              tier: :partially_covered,
              path: path,
              line: tps.first[0],
              method: iseq.label,
            }
            break
          end
        end
        break if test_targets.any? { |t| t[:tier] == :partially_covered }
      end
    end

    @audit = {
      loaded_rb: loaded_rb.size,
      fully_covered: tracked_paths.size,
      partially_covered: partially_covered.size,
      not_covered: not_covered.size,
      c_extensions: $LOADED_FEATURES.count { |f| f.end_with?(".so", ".bundle", ".dll") },
      total_method_iseqs: total_method_iseqs,
      not_covered_by_category: not_covered_by_category,
      partially_by_category: partially_by_category,
      missing_app: not_covered_by_category[:app] || [],
      test_targets: test_targets,
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

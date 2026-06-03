# Test scaffolding for PR #5697 (TracePoint :class hot-load hook).
# Adds a `/symdb_hot_load_test/define_class?n=N` endpoint that defines
# a top-level class named HotLoadN. Use after initial symdb upload completes
# to verify the hot-load hook captures runtime-defined classes and uploads
# them on a subsequent extraction.
#
# Gated on SYMDB_HOT_LOAD_TEST=1 so it has zero effect on normal runs.
# Pairs with bin/symdb-hot-load-test (orchestrator).

if ENV['SYMDB_HOT_LOAD_TEST'] == '1'
  Rails.application.config.after_initialize do
    Rails.application.routes.append do
      get '/symdb_hot_load_test/define_class' => 'symdb_hot_load_test#define_class'
      get '/symdb_hot_load_test/status'       => 'symdb_hot_load_test#status'
    end

    # Define a controller in the constant tree so Rails can resolve it
    # without needing autoload.
    Object.const_set(:SymdbHotLoadTestController, Class.new(ApplicationController) do
      skip_before_action :verify_authenticity_token, raise: false

      def define_class
        n = params[:n].to_s
        unless n.match?(/\A\d+\z/)
          render plain: "bad n", status: 400
          return
        end

        class_name = "HotLoad#{n}"
        already = Object.const_defined?(class_name)
        # Use eval-of-class-statement so the TracePoint :class event fires
        # against a named class (Class.new produces an anonymous class at
        # event time even when later const_set'd; the design doc calls this
        # out — anonymous modules are intentionally invisible to symdb).
        eval("class ::#{class_name}; def hot_load_method_#{n}; #{n}; end; end") unless already
        render plain: "defined #{class_name} (was_already=#{already}) pid=#{Process.pid}"
      end

      def status
        comp = Datadog.send(:components, allow_initialization: false)&.symbol_database
        render json: {
          pid: Process.pid,
          ppid: Process.ppid,
          symdb_present: !comp.nil?,
          enabled: comp&.respond_to?(:enabled) ? comp.enabled : nil,
          last_upload_time: comp&.respond_to?(:last_upload_time) ? comp.last_upload_time : nil,
          last_upload_scope_count: comp&.respond_to?(:last_upload_scope_count) ? comp.last_upload_scope_count : nil,
          upload_in_progress: comp&.respond_to?(:upload_in_progress) ? comp.upload_in_progress : nil,
        }
      end
    end)
  end
end

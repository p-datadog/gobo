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
        # Load a real file under lib/hot_load_runtime/ so the resulting class
        # has a non-(eval) source_location. The extractor filters out (eval)
        # paths (extractor.rb:212), so eval-defined classes would never reach
        # the upload — we want a real file path for the hot-load buffer to
        # produce a non-empty extraction.
        path = Rails.root.join('lib/hot_load_runtime', "hot_load_#{n}.rb")
        unless File.exist?(path)
          render plain: "no file: #{path}", status: 404
          return
        end
        load(path.to_s) unless already
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

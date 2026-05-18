require 'datadog'
require 'datadog/symbol_database'
require 'datadog/symbol_database/extractor'

module Stress
  module ExtractionLoop
    @mutex = Mutex.new
    @thread = nil
    @running = false
    @iter_count = 0

    class << self
      attr_reader :iter_count

      def start!
        @mutex.synchronize do
          return if @thread

          @running = true
          @iter_count = 0
          @thread = Thread.new { run_loop }
        end
      end

      def stop!
        @mutex.synchronize { @running = false }
        @thread&.join(5)
        @thread = nil
      end

      private

      def run_loop
        Thread.current.name = 'symdb-extract-loop' rescue nil
        logger = Datadog.logger
        settings = Datadog.configuration
        extractor = Datadog::SymbolDatabase::Extractor.new(logger: logger, settings: settings)
        interval = ENV.fetch('SYMDB_EXTRACT_INTERVAL', '0').to_f
        while @running
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            extractor.extract_all
          rescue => e
            warn "[symdb-loop pid=#{Process.pid}] error: #{e.class}: #{e.message}"
          end
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
          @iter_count += 1
          warn "[symdb-loop pid=#{Process.pid}] iter ##{@iter_count} #{elapsed_ms}ms"
          sleep interval if interval > 0
        end
      end
    end
  end
end

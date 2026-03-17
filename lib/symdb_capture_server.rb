# frozen_string_literal: true

# lib/symdb_capture_server.rb
#
# Parses and displays symdb upload payloads captured from the Datadog tracer.
# Used by bin/capture_symbols to run a mock agent for local development.
#
# The testable core is SymdbCaptureServer#handle_upload, which takes a
# WEBrick req.query hash (or any hash with "event"/"file" keys) and returns
# a formatted string of output while saving files to capture_dir.

require "json"
require "zlib"

class SymdbCaptureServer
  attr_reader :request_count

  def initialize(capture_dir:)
    @capture_dir = capture_dir
    @request_count = 0
  end

  # Parse and display a symdb multipart upload.
  # form_data is a hash with "event" (JSON string) and/or "file" (gzip binary).
  # Returns formatted output string. Saves files to capture_dir as a side effect.
  def handle_upload(form_data)
    @request_count += 1
    n = @request_count
    timestamp = Time.now.strftime("%H%M%S")
    output = []

    if (event_part = form_data["event"])
      output << format_event(event_part.to_s, n, timestamp)
    end

    if (file_part = form_data["file"])
      output << format_symbols(file_part.to_s.b, n, timestamp)
    end

    output.join
  end

  private

  def format_event(event_str, n, timestamp)
    event_path = File.join(@capture_dir, "#{timestamp}_#{n}_event.json")
    File.write(event_path, event_str)

    parsed = JSON.parse(event_str)
    lines = []
    lines << "=== Upload ##{n} -- Event metadata ===\n"
    lines << JSON.pretty_generate(parsed)
    lines << "\n\n"
    lines.join
  rescue JSON::ParserError
    "=== Upload ##{n} -- Event (unparseable): #{event_str} ===\n"
  end

  def format_symbols(gzip_data, n, timestamp)
    json_data = Zlib.gunzip(gzip_data)
    symbols_path = File.join(@capture_dir, "#{timestamp}_#{n}_symbols.json")
    File.write(symbols_path, json_data)

    parsed = JSON.parse(json_data)

    lines = []
    lines << "=== Upload ##{n} -- Symbols payload ===\n"
    lines << "  service:  #{parsed["service"]}\n"
    lines << "  env:      #{parsed["env"]}\n"
    lines << "  version:  #{parsed["version"]}\n"
    lines << "  language: #{parsed["language"]}\n"
    lines << "  scopes:   #{parsed["scopes"]&.size || 0}\n"
    lines << "\n"

    parsed["scopes"]&.each do |scope|
      lines << "  [#{scope["scope_type"]}] #{scope["name"]}\n"
      lines << "    source: #{scope["source_file"]}:#{scope["start_line"]}-#{scope["end_line"]}\n"
      scope["scopes"]&.each do |child|
        lines << "    [#{child["scope_type"]}] #{child["name"]}\n"
        child["symbols"]&.each do |sym|
          lines << "      #{sym["symbol_type"]}: #{sym["name"]} (line #{sym["line"]})\n"
        end
      end
      scope["symbols"]&.each do |sym|
        lines << "    #{sym["symbol_type"]}: #{sym["name"]} (line #{sym["line"]})\n"
      end
      lines << "\n"
    end

    pretty_path = File.join(@capture_dir, "#{timestamp}_#{n}_symbols_pretty.json")
    File.write(pretty_path, JSON.pretty_generate(parsed))

    lines.join
  rescue Zlib::GzipFile::Error => e
    "=== Upload ##{n} -- Could not decompress symbols: #{e} ===\n"
  end
end

# Start the WEBrick server when run directly (not when required by tests).
if __FILE__ == $PROGRAM_NAME
  require "webrick"

  capture_dir = ENV.fetch("CAPTURE_DIR", "/tmp/symdb_captures")
  capture_port = ENV.fetch("CAPTURE_PORT", "8877").to_i

  handler = SymdbCaptureServer.new(capture_dir: capture_dir)

  server = WEBrick::HTTPServer.new(
    Port: capture_port,
    Logger: WEBrick::Log.new("/dev/null"),
    AccessLog: []
  )

  server.mount_proc "/" do |req, res|
    if req.path == "/symdb/v1/input" && req.request_method == "POST"
      # Save raw body for debugging before req.query consumes the IO
      raw_body = req.body || ""
      output = handler.handle_upload(req.query)
      print output

      timestamp = Time.now.strftime("%H%M%S")
      raw_path = File.join(capture_dir, "#{timestamp}_#{handler.request_count}_raw.bin")
      File.binwrite(raw_path, raw_body)

      res.status = 200
      res.body = "{}"
    else
      # Accept everything else the tracer sends during init
      res.status = 200
      res.body = case req.path
      when "/info"
        '{"endpoints":["/symdb/v1/input"],"client_drop_p0s":true}'
      else
        "{}"
      end
    end
  end

  trap("INT") { server.shutdown }
  server.start
end

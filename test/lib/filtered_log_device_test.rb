require "test_helper"
require_relative "../../lib/filtered_log_device"

class FilteredLogDeviceTest < ActiveSupport::TestCase
  setup do
    @output = StringIO.new
    @device = FilteredLogDevice.new(@output)
  end

  test "passes through normal log messages unchanged" do
    @device.write("Started GET / for 127.0.0.1\n")
    assert_equal "Started GET / for 127.0.0.1\n", @output.string
  end

  test "strips single-field dd prefix" do
    msg = "[dd.env=production ddsource=ruby] Completed 200 OK\n"
    @device.write(msg)
    assert_equal "Completed 200 OK\n", @output.string
  end

  test "strips multi-field dd prefix" do
    msg = "[dd.env=staging dd.service=myapp dd.trace_id=abc123 dd.span_id=xyz789 ddsource=ruby] Started GET /\n"
    @device.write(msg)
    assert_equal "Started GET /\n", @output.string
  end

  test "strips all dd prefixes when multiple lines are batched" do
    msg = "[dd.env=x ddsource=ruby] Line one\n[dd.env=x ddsource=ruby] Line two\n"
    @device.write(msg)
    assert_equal "Line one\nLine two\n", @output.string
  end

  test "does not strip lines that merely contain dd words" do
    msg = "Error in dd module: something failed\n"
    @device.write(msg)
    assert_equal msg, @output.string
  end

  test "sync= delegates to underlying io" do
    io = Object.new
    sync_value = nil
    io.define_singleton_method(:sync=) { |v| sync_value = v }
    io.define_singleton_method(:sync)  { sync_value }
    io.define_singleton_method(:write) { |_| }
    device = FilteredLogDevice.new(io)
    device.sync = false
    assert_equal false, device.sync
  end
end

require 'rails_helper'
require_relative '../../lib/filtered_log_device'

RSpec.describe FilteredLogDevice do
  before do
    @output = StringIO.new
    @device = FilteredLogDevice.new(@output)
  end

  it "passes through normal log messages unchanged" do
    @device.write("Started GET / for 127.0.0.1\n")
    expect(@output.string).to eq("Started GET / for 127.0.0.1\n")
  end

  it "strips single-field dd prefix" do
    msg = "[dd.env=production ddsource=ruby] Completed 200 OK\n"
    @device.write(msg)
    expect(@output.string).to eq("Completed 200 OK\n")
  end

  it "strips multi-field dd prefix" do
    msg = "[dd.env=staging dd.service=myapp dd.trace_id=abc123 dd.span_id=xyz789 ddsource=ruby] Started GET /\n"
    @device.write(msg)
    expect(@output.string).to eq("Started GET /\n")
  end

  it "strips all dd prefixes when multiple lines are batched" do
    msg = "[dd.env=x ddsource=ruby] Line one\n[dd.env=x ddsource=ruby] Line two\n"
    @device.write(msg)
    expect(@output.string).to eq("Line one\nLine two\n")
  end

  it "does not strip lines that merely contain dd words" do
    msg = "Error in dd module: something failed\n"
    @device.write(msg)
    expect(@output.string).to eq(msg)
  end

  it "sync= delegates to underlying io" do
    io = Object.new
    sync_value = nil
    io.define_singleton_method(:sync=) { |v| sync_value = v }
    io.define_singleton_method(:sync)  { sync_value }
    io.define_singleton_method(:write) { |_| }
    device = FilteredLogDevice.new(io)
    device.sync = false
    expect(device.sync).to eq(false)
  end
end

require "spec_helper"
require "tmpdir"
require_relative "../../lib/symdb_capture_server"

RSpec.describe SymdbCaptureServer do
  let(:capture_dir) { Dir.mktmpdir }
  let(:server) { described_class.new(capture_dir: capture_dir) }

  after { FileUtils.rm_rf(capture_dir) }

  def gzip(json_str)
    Zlib.gzip(json_str)
  end

  def symbols_payload(overrides = {})
    {
      "service" => "demo-ruby",
      "env" => "development",
      "version" => "1.0",
      "language" => "ruby",
      "scopes" => [
        {
          "scope_type" => "CLASS",
          "name" => "UsersController",
          "source_file" => "app/controllers/users_controller.rb",
          "start_line" => 1,
          "end_line" => 50,
          "scopes" => [
            {
              "scope_type" => "FUNCTION",
              "name" => "index",
              "symbols" => [
                { "symbol_type" => "LOCAL", "name" => "users", "line" => 5 }
              ]
            }
          ],
          "symbols" => []
        }
      ]
    }.merge(overrides)
  end

  describe "#handle_upload" do
    context "with event and file parts" do
      let(:event_json) { JSON.generate(ddsource: "dd_debugger", service: "demo-ruby", type: "symdb") }
      let(:file_gz) { gzip(JSON.generate(symbols_payload)) }
      let(:form_data) { { "event" => event_json, "file" => file_gz } }

      it "increments request_count" do
        expect { server.handle_upload(form_data) }.to change(server, :request_count).from(0).to(1)
      end

      it "prints event metadata header" do
        output = server.handle_upload(form_data)
        expect(output).to include("Event metadata")
        expect(output).to include('"service": "demo-ruby"')
      end

      it "prints symbols payload header" do
        output = server.handle_upload(form_data)
        expect(output).to include("Symbols payload")
        expect(output).to include("service:  demo-ruby")
        expect(output).to include("env:      development")
        expect(output).to include("scopes:   1")
      end

      it "prints scope details" do
        output = server.handle_upload(form_data)
        expect(output).to include("[CLASS] UsersController")
        expect(output).to include("app/controllers/users_controller.rb:1-50")
        expect(output).to include("[FUNCTION] index")
        expect(output).to include("LOCAL: users (line 5)")
      end

      it "saves event.json to capture_dir" do
        server.handle_upload(form_data)
        saved = Dir.glob(File.join(capture_dir, "*_event.json"))
        expect(saved.size).to eq(1)
        expect(JSON.parse(File.read(saved.first))["service"]).to eq("demo-ruby")
      end

      it "saves symbols.json and pretty json to capture_dir" do
        server.handle_upload(form_data)
        expect(Dir.glob(File.join(capture_dir, "*_symbols.json")).size).to eq(1)
        expect(Dir.glob(File.join(capture_dir, "*_symbols_pretty.json")).size).to eq(1)
      end
    end

    context "with only the event part" do
      let(:form_data) { { "event" => '{"type":"symdb"}' } }

      it "outputs event metadata without crashing" do
        output = server.handle_upload(form_data)
        expect(output).to include("Event metadata")
        expect(output).not_to include("Symbols payload")
      end
    end

    context "with only the file part" do
      let(:form_data) { { "file" => gzip(JSON.generate(symbols_payload)) } }

      it "outputs symbols without crashing" do
        output = server.handle_upload(form_data)
        expect(output).to include("Symbols payload")
        expect(output).not_to include("Event metadata")
      end
    end

    context "with invalid gzip data" do
      let(:form_data) { { "file" => "this is not gzip data" } }

      it "returns an error message instead of raising" do
        output = server.handle_upload(form_data)
        expect(output).to include("Could not decompress symbols")
      end
    end

    context "with malformed event JSON" do
      let(:form_data) { { "event" => "not json {{{" } }

      it "returns an unparseable message instead of raising" do
        output = server.handle_upload(form_data)
        expect(output).to include("unparseable")
      end
    end

    context "called multiple times" do
      it "increments request_count on each call" do
        form_data = { "event" => '{"type":"symdb"}' }
        server.handle_upload(form_data)
        server.handle_upload(form_data)
        expect(server.request_count).to eq(2)
      end

      it "uses different upload numbers in output" do
        form_data = { "event" => '{"type":"symdb"}' }
        out1 = server.handle_upload(form_data)
        out2 = server.handle_upload(form_data)
        expect(out1).to include("Upload #1")
        expect(out2).to include("Upload #2")
      end
    end
  end
end

require 'rails_helper'

RSpec.describe "DebuggerTest", type: :request do
  it "json_error page loads" do
    get debugger_test_json_error_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("JSON Encoding Error Demo")
  end

  it "binary_data returns normal operation message" do
    get "/debugger_test/binary_data"
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/BinaryDataModel processed normally/)
  end

  it "binary_data with trigger_error returns error triggered message" do
    get "/debugger_test/binary_data", params: { trigger_error: "true" }
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/custom serializer error triggered/)
  end

  it "binary_data_param returns plain text response" do
    get "/debugger_test/binary_data_param"
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/BinaryDataModel#process/)
    expect(response.body).to match(/256 bytes/)
    expect(response.body).to match(/ASCII-8BIT/)
  end

  it "calculate returns fibonacci result" do
    get debugger_test_calculate_path, params: { fibonacci_n: 10 }
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/fibonacci\(10\) = 55/)
  end

  it "circuit_breaker returns plain text response" do
    get debugger_test_circuit_breaker_path, params: { fibonacci_n: 5 }
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/ExpensiveModel processed/)
  end

  it "exception_message page loads" do
    get debugger_test_exception_message_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Exception Message Demo")
    expect(response.body).to include("ExceptionDemo#raise_exception")
  end

  it "exception_standard rescues and returns exception info" do
    get "/debugger_test/exception_standard"
    expect(response).to have_http_status(:success)
    expect(response.body).to include("ActiveRecord::RecordNotFound")
    expect(response.body).to include("Record not found: id=42")
  end

  it "exception_overridden rescues and returns exception info" do
    get "/debugger_test/exception_overridden"
    expect(response).to have_http_status(:success)
    expect(response.body).to include("ExceptionDemo::InputValidationError")
  end

  it "exception_non_string rescues and returns exception info" do
    get "/debugger_test/exception_non_string"
    expect(response).to have_http_status(:success)
    expect(response.body).to include("ExceptionDemo::ContextError")
  end

  it "stdlib_probe page loads" do
    get debugger_test_stdlib_probe_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Stdlib Line Probe Demo")
  end

  it "stdlib_probe_run set_add returns set result" do
    get "/debugger_test/stdlib_probe_run", params: {kind: "set_add"}
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Set#add")
  end

  it "stdlib_probe_run pathname_join returns joined path" do
    get "/debugger_test/stdlib_probe_run", params: {kind: "pathname_join"}
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Pathname#join")
    expect(response.body).to include("production.log")
  end

  it "stdlib_probe_run digest_sha256 returns hash" do
    get "/debugger_test/stdlib_probe_run", params: {kind: "digest_sha256"}
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Digest::SHA256")
  end
end

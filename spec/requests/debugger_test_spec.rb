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
end

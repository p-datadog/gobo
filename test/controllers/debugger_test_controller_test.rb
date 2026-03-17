require "test_helper"

class DebuggerTestControllerTest < ActionDispatch::IntegrationTest
  test "json_error page loads" do
    get debugger_test_json_error_path
    assert_response :success
    assert_select "h1", "JSON Encoding Error Demo"
  end

  test "binary_data returns plain text response" do
    get "/debugger_test/binary_data"
    assert_response :success
    assert_match /BinaryDataModel processed/, response.body
  end

  test "binary_data with trigger_error returns plain text response" do
    get "/debugger_test/binary_data", params: { trigger_error: "true" }
    assert_response :success
    assert_match /BinaryDataModel processed/, response.body
  end

  test "binary_data_param returns plain text response" do
    get "/debugger_test/binary_data_param"
    assert_response :success
    assert_match /BinaryDataModel#process/, response.body
    assert_match /256 bytes/, response.body
    assert_match /ASCII-8BIT/, response.body
  end

  test "calculate returns fibonacci result" do
    get debugger_test_calculate_path, params: { fibonacci_n: 10 }
    assert_response :success
    assert_match /fibonacci\(10\) = 55/, response.body
  end

  test "circuit_breaker returns plain text response" do
    get debugger_test_circuit_breaker_path, params: { fibonacci_n: 5 }
    assert_response :success
    assert_match /ExpensiveModel processed/, response.body
  end
end

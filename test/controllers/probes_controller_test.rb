require 'test_helper'

class ProbesControllerTest < ActionDispatch::IntegrationTest

  test "should get index" do
    get probes_path
    assert_response :success
    assert_select "title", "Active Dynamic Instrumentation Probes | Ruby Debugger Demo"
  end

  test "should display message when no probes are active" do
    get probes_path
    assert_response :success
    assert_select "div.alert-info", text: /No active or pending probes found/
  end

  test "should display datadog configuration" do
    get probes_path
    assert_response :success
    assert_select "div.well" do
      assert_select "strong", text: "Service:"
      assert_select "strong", text: "Environment:"
      assert_select "strong", text: "DI Enabled:"
    end
  end
end

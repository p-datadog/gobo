require 'rails_helper'

RSpec.describe "Probes", type: :request do
  it "should get index" do
    get probes_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Active Dynamic Instrumentation Probes | Ruby Debugger Demo</title>")
  end

  it "should display probe counts when no probes are active" do
    get probes_path
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/Active: 0.*Disabled: 0.*Pending: 0.*Failed: 0/m)
  end

  it "should display datadog configuration" do
    get probes_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Service:")
    expect(response.body).to include("Environment:")
    expect(response.body).to include("DI Enabled:")
  end
end

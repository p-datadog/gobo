require 'rails_helper'

RSpec.describe "DI Status", type: :request do
  it "should get index" do
    get di_status_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>DI Status | Gobo</title>")
  end

  it "should display probe counts when no probes are active" do
    get di_status_path
    expect(response).to have_http_status(:success)
    expect(response.body).to match(/Active: 0.*Disabled: 0.*Pending: 0.*Failed: 0/m)
  end

  it "should display datadog configuration" do
    get di_status_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("DD_SERVICE:")
    expect(response.body).to include("DD_ENV:")
    expect(response.body).to include("DD_VERSION:")
    expect(response.body).to include("Agent:")
    expect(response.body).to include("DI Enabled:")
  end

  describe "send_status" do
    it "redirects with danger flash when DI component is not initialized" do
      post di_status_send_status_path(id: "probe-123", status: "installed")
      expect(response).to redirect_to(di_status_path)
      expect(flash[:danger]).to match(/Failed to send status/)
    end

    it "redirects with danger flash for unknown status" do
      post di_status_send_status_path(id: "probe-123", status: "bogus")
      expect(response).to redirect_to(di_status_path)
      expect(flash[:danger]).to match(/Failed to send status/)
    end
  end
end

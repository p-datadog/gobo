require 'rails_helper'

RSpec.describe "CodeTracker", type: :request do
  it "page loads" do
    get code_tracker_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("DI Code Tracker Registry")
  end

  it "shows tracking status" do
    get code_tracker_path
    expect(response.body).to match(/Code tracking active:/)
  end

  it "shows category counts" do
    get code_tracker_path
    expect(response.body).to match(/App:/)
    expect(response.body).to match(/Gem:/)
  end

  it "includes filter input" do
    get code_tracker_path
    expect(response.body).to include("path-filter")
  end
end

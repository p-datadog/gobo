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

  it "shows file table" do
    get code_tracker_path
    expect(response.body).to include("registry-table")
  end

  it "includes filter input" do
    get code_tracker_path
    expect(response.body).to include("path-filter")
  end

  it "full list page loads" do
    get code_tracker_full_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Full List")
  end
end

require 'rails_helper'

RSpec.describe "SiteLayout", type: :request do
  it "layout links" do
    get root_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("href=\"#{root_path}\"")
    expect(response.body).to include("href=\"#{help_path}\"")
    expect(response.body).to include("href=\"#{about_path}\"")
    expect(response.body).to include("href=\"#{contact_path}\"")
  end
end

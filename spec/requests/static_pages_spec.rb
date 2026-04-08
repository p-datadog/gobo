require 'rails_helper'

RSpec.describe "StaticPages", type: :request do
  it "should get home" do
    get root_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Ruby Debugger Demo</title>")
  end

  it "should get help" do
    get help_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Help | Ruby Debugger Demo</title>")
  end

  it "should get about" do
    get about_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>About | Ruby Debugger Demo</title>")
  end

  it "should get contact" do
    get contact_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Contact | Ruby Debugger Demo</title>")
  end

  describe "vote" do
    it "creates a vote and returns OK" do
      post = microposts(:orange)
      expect {
        get "/microposts/#{post.id}/vote/job-42"
      }.to change(Vote, :count).by(1)
      expect(response.body).to include("OK #{post.id} job-42")
    end
  end
end

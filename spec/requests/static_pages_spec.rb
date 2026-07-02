require 'rails_helper'

RSpec.describe "StaticPages", type: :request do
  it "should get home" do
    get root_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Gobo</title>")
  end

  it "invokes both probe-demo methods on every home load" do
    expect_any_instance_of(ProbeDemo).to receive(:args)
      .with(kind_of(ProbeDemo::Account), 'view_home', kind_of(Integer)).and_call_original
    expect_any_instance_of(ProbeDemo).to receive(:kw_args)
      .with(query: 'home_feed', filter: kind_of(ProbeDemo::SearchFilter), limit: 10).and_call_original
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "renders a link to the probe instructions page on home" do
    get root_path
    expect(response.body).to include(probe_instructions_path)
    expect(response.body).to include('Probe instructions')
  end

  it "still renders home when the probe demo raises" do
    allow_any_instance_of(ProbeDemo).to receive(:args).and_raise(StandardError, 'boom')
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "should get help" do
    get help_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Help | Gobo</title>")
  end

  it "should get about" do
    get about_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>About | Gobo</title>")
  end

  it "should get contact" do
    get contact_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Contact | Gobo</title>")
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

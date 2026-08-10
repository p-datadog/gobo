require 'rails_helper'

RSpec.describe "StaticPages", type: :request do
  it "should get home" do
    get root_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("<title>Gobo</title>")
  end

  it "invokes both probe-demo methods, directly and via virtual aliases, on every home load" do
    args_calls = []
    kw_calls = []
    allow_any_instance_of(ProbeDemo).to receive(:args).and_wrap_original do |orig, *a|
      args_calls << a
      orig.call(*a)
    end
    allow_any_instance_of(ProbeDemo).to receive(:kw_args).and_wrap_original do |orig, **kw|
      kw_calls << kw
      orig.call(**kw)
    end
    get root_path
    expect(response).to have_http_status(:success)
    expect(args_calls.size).to eq(3)
    expect(kw_calls.size).to eq(3)
    expect(args_calls.first).to match([kind_of(ProbeDemo::Account), 'view_home', kind_of(Integer)])
    expect(kw_calls.first).to match(hash_including(query: 'home_feed', filter: kind_of(ProbeDemo::SearchFilter), limit: 10))
    expect(args_calls).to include([kind_of(ProbeDemo::Account), 'virtual_home', kind_of(Integer)])
    expect(kw_calls).to include(hash_including(query: 'home_feed_virtual', filter: kind_of(ProbeDemo::SearchFilter)))
  end

  it "renders a link to the probe instructions page on home" do
    get root_path
    expect(response.body).to include(probe_instructions_path)
    expect(response.body).to include('Probe instructions')
  end

  it "invokes the fixed-signature probe target once on every home load" do
    fixed_calls = []
    allow_any_instance_of(ProbeDemo).to receive(:fixed_sig).and_wrap_original do |orig, *a, **kw|
      fixed_calls << [a, kw]
      orig.call(*a, **kw)
    end
    get root_path
    expect(response).to have_http_status(:success)
    expect(fixed_calls.size).to eq(1)
    expect(fixed_calls.first[0]).to match([kind_of(ProbeDemo::Account), 'fixed_home', kind_of(Integer)])
    expect(fixed_calls.first[1]).to match(hash_including(query: kind_of(String), filter: kind_of(ProbeDemo::SearchFilter), limit: kind_of(Integer)))
  end

  it "invokes the keyword-splat probe target once on every home load" do
    splat_calls = []
    allow_any_instance_of(ProbeDemo).to receive(:splat_kwargs).and_wrap_original do |orig, *a, **kw|
      splat_calls << [a, kw]
      orig.call(*a, **kw)
    end
    get root_path
    expect(response).to have_http_status(:success)
    expect(splat_calls.size).to eq(1)
    expect(splat_calls.first[0]).to match([kind_of(ProbeDemo::Account), 'splat_home'])
    expect(splat_calls.first[1]).to match(hash_including(account: kind_of(String), tag: kind_of(String)))
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

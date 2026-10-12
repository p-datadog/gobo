require 'rails_helper'

RSpec.describe "Stress endpoints", type: :request do
  ["/stress/simple", "/stress/cpu1s", "/stress/mix2s", "/stress/io2s"].each do |path|
    it "GET #{path} responds ok" do
      get path
      expect(response).to have_http_status(:success)
      expect(response.body).to eq("ok")
    end
  end
end

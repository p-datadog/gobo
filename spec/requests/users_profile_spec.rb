require 'rails_helper'

RSpec.describe "UsersProfile", type: :request do
  include ApplicationHelper

  before do
    @user = users(:michael)
  end

  it "profile display" do
    get user_path(@user)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(full_title(@user.name))
    expect(response.body).to include(@user.name)
    expect(response.body).to include("gravatar")
    expect(response.body).to include(@user.microposts.count.to_s)
    expect(response.body).to include("pagination")
    @user.microposts.paginate(page: 1).each do |micropost|
      expect(response.body).to include(micropost.content)
    end
  end
end

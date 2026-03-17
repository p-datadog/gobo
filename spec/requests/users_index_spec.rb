require 'rails_helper'

RSpec.describe "UsersIndex", type: :request do
  before do
    @admin     = users(:michael)
    @non_admin = users(:archer)
  end

  it "index as admin including pagination and delete links" do
    log_in_as(@admin)
    get users_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("pagination")
    first_page_of_users = User.paginate(page: 1)
    first_page_of_users.each do |user|
      expect(response.body).to include(user.name)
      unless user == @admin
        expect(response.body).to include("href=\"#{user_path(user)}\"")
      end
    end
    expect {
      delete user_path(@non_admin)
    }.to change(User, :count).by(-1)
  end

  it "index as non-admin" do
    log_in_as(@non_admin)
    get users_path
    expect(response.body).not_to match(/<a[^>]*>delete<\/a>/)
  end
end

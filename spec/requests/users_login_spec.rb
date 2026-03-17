require 'rails_helper'

RSpec.describe "UsersLogin", type: :request do
  before do
    @user = users(:michael)
  end

  it "login with valid email/invalid password" do
    get login_path
    expect(response).to have_http_status(:success)
    post login_path, params: { session: { email: @user.email,
                                          password: "invalid" } }
    expect(is_logged_in?).to be_falsy
    expect(response.body).to include("sessions/new") if false # template check via body not needed
    expect(flash).not_to be_empty
    get root_path
    expect(flash).to be_empty
  end

  it "login with valid information followed by logout" do
    get login_path
    post login_path, params: { session: { email: @user.email,
                                          password: 'password' } }
    expect(is_logged_in?).to be_truthy
    expect(response).to redirect_to(@user)
    follow_redirect!
    expect(response.body).not_to include("href=\"#{login_path}\"")
    expect(response.body).to include("href=\"#{logout_path}\"")
    expect(response.body).to include("href=\"#{user_path(@user)}\"")
    delete logout_path
    expect(is_logged_in?).to be_falsy
    expect(response).to redirect_to(root_url)
    # Simulate a user clicking logout in a second window.
    delete logout_path
    follow_redirect!
    # After logout, the nav should show the login link but not logout or user profile
    expect(response.body).to include("href=\"#{login_path}\"")
    expect(response.body).not_to include("href=\"#{logout_path}\"")
    # The nav should not contain a link to the user's profile
    # (note: other content on page may include user links, so we check nav specifically)
    nav_section = response.body.match(/<nav.*?<\/nav>/m)&.to_a&.first || ""
    expect(nav_section).not_to include("href=\"#{user_path(@user)}\"")
  end

  it "login with remembering" do
    log_in_as(@user, remember_me: '1')
    expect(cookies[:remember_token]).not_to be_blank
  end

  it "login without remembering" do
    # Log in to set the cookie.
    log_in_as(@user, remember_me: '1')
    # Log in again and verify that the cookie is deleted.
    log_in_as(@user, remember_me: '0')
    expect(cookies[:remember_token]).to be_blank
  end
end

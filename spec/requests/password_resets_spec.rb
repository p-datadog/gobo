require 'rails_helper'

RSpec.describe "PasswordResets", type: :request do
  before do
    @user = users(:michael)
  end

  it "password resets" do
    get new_password_reset_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('name="password_reset[email]"')
    # Invalid email
    post password_resets_path, params: { password_reset: { email: "" } }
    expect(flash).not_to be_empty
    # Valid email
    old_reset_digest = @user.reset_digest
    post password_resets_path,
         params: { password_reset: { email: @user.email } }
    @user.reload
    expect(@user.reset_digest).not_to eq(old_reset_digest)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(flash).not_to be_empty
    expect(response).to redirect_to(root_url)
    # Extract the reset token from the email
    mail = ActionMailer::Base.deliveries.last
    reset_url = mail.body.encoded.match(%r{/password_resets/([^/\s]+)/edit\?email=})
    reset_token = reset_url ? reset_url[1] : nil
    expect(reset_token).not_to be_nil
    # Wrong email
    get edit_password_reset_path(reset_token, email: "")
    expect(response).to redirect_to(root_url)
    # Inactive user
    @user.toggle!(:activated)
    get edit_password_reset_path(reset_token, email: @user.email)
    expect(response).to redirect_to(root_url)
    @user.toggle!(:activated)
    # Right email, wrong token
    get edit_password_reset_path('wrong token', email: @user.email)
    expect(response).to redirect_to(root_url)
    # Right email, right token
    get edit_password_reset_path(reset_token, email: @user.email)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("input")
    expect(response.body).to include(@user.email)
    # Invalid password & confirmation
    patch password_reset_path(reset_token),
          params: { email: @user.email,
                    user: { password:              "foobaz",
                            password_confirmation: "barquux" } }
    expect(response.body).to include("id=\"error_explanation\"")
    # Empty password
    patch password_reset_path(reset_token),
          params: { email: @user.email,
                    user: { password:              "",
                            password_confirmation: "" } }
    expect(response.body).to include("id=\"error_explanation\"")
    # Valid password & confirmation
    patch password_reset_path(reset_token),
          params: { email: @user.email,
                    user: { password:              "foobaz",
                            password_confirmation: "foobaz" } }
    expect(is_logged_in?).to be_truthy
    expect(flash).not_to be_empty
    expect(response).to redirect_to(@user)
  end
end

require 'rails_helper'

RSpec.describe "AccountActivations", type: :request do
  before do
    @user = User.create!(name: "Pending User",
                         email: "pending@example.com",
                         password: "password",
                         password_confirmation: "password",
                         activated: false,
                         activated_at: nil)
  end

  it "does not activate with invalid token" do
    get edit_account_activation_path("bad-token", email: @user.email)
    expect(@user.reload.activated?).to be_falsy
    expect(response).to redirect_to(root_url)
  end

  it "does not activate with wrong email" do
    get edit_account_activation_path(@user.activation_token, email: "wrong@example.com")
    expect(@user.reload.activated?).to be_falsy
    expect(response).to redirect_to(root_url)
  end

  it "activates with valid token and email" do
    get edit_account_activation_path(@user.activation_token, email: @user.email)
    expect(@user.reload.activated?).to be_truthy
    expect(is_logged_in?).to be_truthy
    expect(response).to redirect_to(user_path(@user))
  end

  it "does not re-activate an already activated user" do
    @user.activate
    get edit_account_activation_path(@user.activation_token, email: @user.email)
    expect(response).to redirect_to(root_url)
    expect(flash[:danger]).to eq("Invalid activation link")
  end
end

require 'rails_helper'

RSpec.describe "UsersSignup", type: :request do
  it "invalid signup information" do
    get signup_path
    expect {
      post users_path, params: { user: { name:  "",
                                         email: "user@invalid",
                                         password:              "foo",
                                         password_confirmation: "bar" } }
    }.not_to change(User, :count)
    expect(response.body).to include("id=\"error_explanation\"")
    expect(response.body).to include("field_with_errors")
  end

  it "valid signup creates user and redirects to home" do
    get signup_path
    expect {
      post users_path, params: { user: { name:  "Example User",
                                         email: "user@example.com",
                                         password:              "password",
                                         password_confirmation: "password" } }
    }.to change(User, :count).by(1)
    # Activation email is skipped in this demo app (users are auto-activated)
    expect(ActionMailer::Base.deliveries.size).to eq(0)
    user = User.find_by(email: "user@example.com")
    expect(user.activated?).to be_truthy
    expect(response).to redirect_to(root_url)
  end
end

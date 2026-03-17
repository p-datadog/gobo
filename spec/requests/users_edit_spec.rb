require 'rails_helper'

RSpec.describe "UsersEdit", type: :request do
  before do
    @user = users(:michael)
  end

  it "unsuccessful edit" do
    log_in_as(@user)
    get edit_user_path(@user)
    expect(response).to have_http_status(:success)
    patch user_path(@user), params: { user: { name:  "",
                                              email: "foo@invalid",
                                              password:              "foo",
                                              password_confirmation: "bar" } }
    expect(response.body).to include("edit")
  end

  it "successful edit with friendly forwarding" do
    get edit_user_path(@user)
    log_in_as(@user)
    expect(response).to redirect_to(edit_user_url(@user))
    name  = "Foo Bar"
    email = "foo@bar.com"
    patch user_path(@user), params: { user: { name:  name,
                                              email: email,
                                              password:              "",
                                              password_confirmation: "" } }
    expect(flash).not_to be_empty
    expect(response).to redirect_to(@user)
    @user.reload
    expect(@user.name).to eq(name)
    expect(@user.email).to eq(email)
  end
end

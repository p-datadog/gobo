require 'rails_helper'

RSpec.describe "MicropostsInterface", type: :request do
  before do
    @user = users(:michael)
  end

  it "micropost interface" do
    log_in_as(@user)
    get root_path
    expect(response.body).to include("pagination")
    expect(response.body).to include('type="file"')
    # Invalid submission
    post microposts_path, params: { micropost: { content: "" } }
    expect(response.body).to include("id=\"error_explanation\"")
    expect(response.body).to include("/?page=2")
    # Valid submission
    content = "This micropost really ties the room together"
    image = fixture_file_upload(Rails.root.join('spec/fixtures/files/kitten.jpg'), 'image/jpeg')
    expect {
      post microposts_path, params: { micropost: { content: content,
                                                   image:   image } }
    }.to change(Micropost, :count).by(1)
    micropost = Micropost.find_by(content: content)
    expect(micropost.image).to be_attached
    follow_redirect!
    expect(response.body).to include(content)
    # Delete a post.
    expect(response.body).to include("delete")
    first_micropost = @user.microposts.paginate(page: 1).first
    expect {
      delete micropost_path(first_micropost)
    }.to change(Micropost, :count).by(-1)
    # Visit a different user (no delete links).
    get user_path(users(:archer))
    expect(response.body).not_to match(/<a[^>]*>delete<\/a>/)
  end
end

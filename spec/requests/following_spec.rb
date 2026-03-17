require 'rails_helper'

RSpec.describe "Following", type: :request do
  before do
    @user  = users(:michael)
    @other = users(:archer)
    log_in_as(@user)
  end

  it "following page" do
    get following_user_path(@user)
    expect(@user.following).not_to be_empty
    expect(response.body).to include(@user.following.count.to_s)
    @user.following.each do |user|
      expect(response.body).to include("href=\"#{user_path(user)}\"")
    end
  end

  it "followers page" do
    get followers_user_path(@user)
    expect(@user.followers).not_to be_empty
    expect(response.body).to include(@user.followers.count.to_s)
    @user.followers.each do |user|
      expect(response.body).to include("href=\"#{user_path(user)}\"")
    end
  end

  it "should follow a user the standard way" do
    expect {
      post relationships_path, params: { followed_id: @other.id }
    }.to change { @user.following.count }.by(1)
  end

  it "should follow a user with Ajax" do
    expect {
      post relationships_path, xhr: true, params: { followed_id: @other.id }
    }.to change { @user.following.count }.by(1)
  end

  it "should unfollow a user the standard way" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    expect {
      delete relationship_path(relationship)
    }.to change { @user.following.count }.by(-1)
  end

  it "should unfollow a user with Ajax" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    expect {
      delete relationship_path(relationship), xhr: true
    }.to change { @user.following.count }.by(-1)
  end
end

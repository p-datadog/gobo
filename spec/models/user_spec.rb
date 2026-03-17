require 'rails_helper'

RSpec.describe User, type: :model do
  before do
    @user = User.new(name: "Example User", email: "user@example.com",
                     password: "foobar", password_confirmation: "foobar")
  end

  it "should be valid" do
    expect(@user).to be_valid
  end

  it "name should be present" do
    @user.name = ""
    expect(@user).not_to be_valid
  end

  it "email should be present" do
    @user.email = "     "
    expect(@user).not_to be_valid
  end

  it "name should not be too long" do
    @user.name = "a" * 51
    expect(@user).not_to be_valid
  end

  it "email should not be too long" do
    @user.email = "a" * 244 + "@example.com"
    expect(@user).not_to be_valid
  end

  it "email validation should accept valid addresses" do
    valid_addresses = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org
                         first.last@foo.jp alice+bob@baz.cn]
    valid_addresses.each do |valid_address|
      @user.email = valid_address
      expect(@user).to be_valid, "#{valid_address.inspect} should be valid"
    end
  end

  it "email validation should reject invalid addresses" do
    invalid_addresses = %w[user@example,com user_at_foo.org user.name@example.
                           foo@bar_baz.com foo@bar+baz.com]
    invalid_addresses.each do |invalid_address|
      @user.email = invalid_address
      expect(@user).not_to be_valid, "#{invalid_address.inspect} should be invalid"
    end
  end

  it "email addresses should be unique" do
    duplicate_user = @user.dup
    @user.save
    expect(duplicate_user).not_to be_valid
  end

  it "password should be present (nonblank)" do
    @user.password = @user.password_confirmation = " " * 6
    expect(@user).not_to be_valid
  end

  it "password should have a minimum length" do
    @user.password = @user.password_confirmation = "a" * 5
    expect(@user).not_to be_valid
  end

  it "authenticated? should return false for a user with nil digest" do
    expect(@user.authenticated?(:remember, '')).to be_falsy
  end

  it "associated microposts should be destroyed" do
    @user.save
    @user.microposts.create!(content: "Lorem ipsum")
    expect { @user.destroy }.to change(Micropost, :count).by(-1)
  end

  it "should follow and unfollow a user" do
    michael = users(:michael)
    archer  = users(:archer)
    expect(michael.following?(archer)).to be_falsy
    michael.follow(archer)
    expect(michael.following?(archer)).to be_truthy
    expect(archer.followers).to include(michael)
    michael.unfollow(archer)
    expect(michael.following?(archer)).to be_falsy
    # Users can't follow themselves.
    michael.follow(michael)
    expect(michael.following?(michael)).to be_falsy
  end

  it "feed should have the right posts" do
    michael = users(:michael)
    archer  = users(:archer)
    lana    = users(:lana)
    # Posts from followed user
    lana.microposts.each do |post_following|
      expect(michael.feed).to include(post_following)
    end
    # Self-posts for user with followers
    michael.microposts.each do |post_self|
      expect(michael.feed).to include(post_self)
    end
    # Self-posts for user with no followers
    archer.microposts.each do |post_self|
      expect(archer.feed).to include(post_self)
    end
    # Posts from unfollowed user
    archer.microposts.each do |post_unfollowed|
      expect(michael.feed).not_to include(post_unfollowed)
    end
  end
end

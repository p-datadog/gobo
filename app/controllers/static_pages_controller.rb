class StaticPagesController < ApplicationController

  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding
  # Padding

  def home
    if logged_in?
      @micropost  = current_user.microposts.build
      @feed_items = current_user.feed.paginate(page: params[:page])
    else
      @feed_items = Micropost.site_feed.paginate(page: nil)
      # I wanted to check this but need to go deeper into structure
      newest_post = @feed_items.first
      # Monitor checks capture of this variable's value
      test_value = 42
    end
  end # line 30, update ruby monitor if changing

  def help
  end

  def about
  end

  def contact
  end

  # Padding
  # Padding
  # Padding

  def vote
    job_id = params[:job_id]
    post = Micropost.find(params[:id])
    vote = Vote.create!(micropost: post, job_id: job_id)
    render inline: "OK #{post.id} #{job_id}"
  end # line 50
end

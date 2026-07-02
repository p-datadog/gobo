class StaticPagesController < ApplicationController
  before_action :invoke_probe_demo, only: :home

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

  private

  # Invokes the probe-demo methods so a method probe set on either fires on
  # every home page load. DI observes silently, so a failure here must not
  # affect the page.
  def invoke_probe_demo
    demo = ProbeDemo.new
    demo.positional_args(current_user&.id || 0, 'view_home', Micropost.count)
    demo.keyword_args(query: 'home_feed', limit: 10, offset: 0)
  rescue => e
    Rails.logger.error "Error invoking probe demo: #{e.class}: #{e}"
  end
end

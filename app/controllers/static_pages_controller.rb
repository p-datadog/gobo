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
    arguments = ProbeDemo.demo_arguments(user: current_user, count: Micropost.count)
    positional = arguments[:args]
    keyword = arguments[:kw_args]
    demo = ProbeDemo.new
    demo.args(*positional.values_at(:account, :action, :count))
    demo.args(positional[:account], "refresh_home", positional[:count] + 1)
    demo.kw_args(**keyword)
    demo.kw_args(query: "home_feed_refresh", filter: keyword[:filter], limit: keyword[:limit] * 2)
    demo.args_virtual(positional[:account], "virtual_home", positional[:count])
    demo.kw_args_virtual(query: "home_feed_virtual", filter: keyword[:filter], limit: keyword[:limit])
    demo.fixed_sig(
      positional[:account], "fixed_home", positional[:count],
      query: keyword[:query], filter: keyword[:filter], limit: keyword[:limit]
    )
    demo.splat_kwargs(positional[:account], "splat_home", account: "collision", tag: "live")
  rescue => e
    Rails.logger.error "Error invoking probe demo: #{e.class}: #{e}"
  end
end

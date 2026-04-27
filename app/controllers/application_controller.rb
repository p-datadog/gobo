class ApplicationController < ActionController::Base
  # Protect from CSRF attacks by raising an exception
  protect_from_forgery with: :exception

  include SessionsHelper

  private

    def fetch_agent_address
      return nil unless defined?(Datadog)

      settings = Datadog.configuration
      "#{settings.agent.host}:#{settings.agent.port}"
    rescue => e
      "error: #{e.class}: #{e}"
    end

    # Confirms a logged-in user.
    def logged_in_user
      unless logged_in?
        store_location
        flash[:danger] = "Please log in."
        redirect_to login_url
      end
    end
end

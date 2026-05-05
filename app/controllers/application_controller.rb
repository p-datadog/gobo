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

    def fetch_service
      return nil unless defined?(Datadog)
      Datadog.configuration.service
    rescue => e
      Rails.logger.error "Error fetching DD_SERVICE: #{e.class}: #{e}"
      nil
    end

    def fetch_env
      return nil unless defined?(Datadog)
      Datadog.configuration.env
    rescue => e
      Rails.logger.error "Error fetching DD_ENV: #{e.class}: #{e}"
      nil
    end

    def fetch_version
      return nil unless defined?(Datadog)
      Datadog.configuration.version
    rescue => e
      Rails.logger.error "Error fetching DD_VERSION: #{e.class}: #{e}"
      nil
    end

    def fetch_git_repository_url
      return nil unless defined?(Datadog::Core::Environment::Git)
      Datadog::Core::Environment::Git.git_repository_url
    rescue => e
      Rails.logger.error "Error fetching DD_GIT_REPOSITORY_URL: #{e.class}: #{e}"
      nil
    end

    def fetch_git_commit_sha
      return nil unless defined?(Datadog::Core::Environment::Git)
      Datadog::Core::Environment::Git.git_commit_sha
    rescue => e
      Rails.logger.error "Error fetching DD_GIT_COMMIT_SHA: #{e.class}: #{e}"
      nil
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

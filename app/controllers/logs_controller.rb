require_relative '../../lib/logs_query'
require_relative '../../lib/agent_environments'

class LogsController < ApplicationController
  DEFAULT_WINDOW_MINUTES = 30
  DEFAULT_LIMIT = 50

  def index
    @service = fetch_service
    @env = fetch_env
    @agent_environment_label = fetch_agent_environment_label
    @window_minutes = window_minutes_param
    @limit = limit_param
    @query = query_param
    @result = run_query if @agent_environment_label
    @no_environment_error = 'no known agent environment for the running tracer' unless @agent_environment_label

    respond_to do |format|
      format.html
      format.json { render json: logs_json }
    end
  end

  private

  def query_param
    params[:q].presence || default_query
  end

  def default_query
    @service ? "service:#{@service}" : '*'
  end

  def window_minutes_param
    minutes = params[:minutes].to_i
    minutes.positive? ? minutes : DEFAULT_WINDOW_MINUTES
  end

  def limit_param
    limit = params[:limit].to_i
    limit.positive? ? limit : DEFAULT_LIMIT
  end

  def run_query
    host = AgentEnvironments.fetch(@agent_environment_label)[:host]
    LogsQuery.new(
      host: host, cookie_label: @agent_environment_label,
      query: @query, window_minutes: @window_minutes, limit: @limit
    ).call
  rescue => e
    Rails.logger.error "Error querying Datadog logs: #{e.class}: #{e}"
    LogsQuery::Result.new(
      events: [], hit_count: nil, error: "#{e.class}: #{e}", query: @query,
      host: nil, cookie_path: nil, window_minutes: @window_minutes, limit: @limit
    )
  end

  def logs_json
    {
      service: @service,
      env: @env,
      agent_environment: @agent_environment_label,
      query: @query,
      window_minutes: @window_minutes,
      limit: @limit,
      host: @result&.host,
      cookie_path: @result&.cookie_path,
      hit_count: @result&.hit_count,
      events: (@result&.events || []).map(&:to_h),
      error: @result&.error || @no_environment_error,
    }
  end
end

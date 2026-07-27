require 'rails_helper'

RSpec.describe LogsController, type: :controller do
  render_views

  let(:result) do
    LogsQuery::Result.new(
      events: [
        LogsQuery::Event.new(
          id: 'AQ', timestamp: '2026-07-27T20:46:43.601Z', status: 'info',
          service: 'gobo', message: 'In static_pages_controller.rb, line 30',
          tags: ['source:dd_debugger']
        ),
      ],
      hit_count: 2149, error: nil, query: 'service:gobo',
      host: 'squirrel.datadoghq.com', cookie_path: '/cookies-dogfood.json',
      window_minutes: 30, limit: 50
    )
  end

  def stub_logs_query(returned)
    allow(LogsQuery).to receive(:new)
      .and_return(instance_double(LogsQuery, call: returned))
  end

  before do
    allow(controller).to receive(:fetch_service).and_return('gobo')
    allow(controller).to receive(:fetch_env).and_return('production')
    allow(controller).to receive(:fetch_agent_environment_label).and_return('dogfood')
  end

  describe 'GET #index (HTML)' do
    it 'renders the returned events with their fields' do
      stub_logs_query(result)
      get :index
      expect(response).to have_http_status(:success)
      expect(response.body).to include('2026-07-27T20:46:43.601Z')
      expect(response.body).to include('In static_pages_controller.rb, line 30')
      expect(response.body).to include('2149')
    end

    it 'defaults the query to the running service' do
      stub_logs_query(result)
      expect(LogsQuery).to receive(:new)
        .with(hash_including(query: 'service:gobo', cookie_label: 'dogfood'))
        .and_return(instance_double(LogsQuery, call: result))
      get :index
    end

    it 'passes an explicit query, window and limit through to LogsQuery' do
      expect(LogsQuery).to receive(:new)
        .with(hash_including(query: 'status:error', window_minutes: 5, limit: 3))
        .and_return(instance_double(LogsQuery, call: result))
      get :index, params: { q: 'status:error', minutes: '5', limit: '3' }
    end

    it 'shows the backend error when the query fails' do
      stub_logs_query(LogsQuery::Result.new(
        events: [], hit_count: nil, error: 'RuntimeError: no cookies staged',
        query: 'service:gobo', host: 'squirrel.datadoghq.com',
        cookie_path: '/cookies-dogfood.json', window_minutes: 30, limit: 50
      ))
      get :index
      expect(response.body).to include('RuntimeError: no cookies staged')
    end
  end

  describe 'GET #index (JSON)' do
    it 'serializes the events and hit count with correct values' do
      stub_logs_query(result)
      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json['service']).to eq('gobo')
      expect(json['env']).to eq('production')
      expect(json['query']).to eq('service:gobo')
      expect(json['hit_count']).to eq(2149)
      expect(json['events'].length).to eq(1)
      event = json['events'].first
      expect(event['id']).to eq('AQ')
      expect(event['status']).to eq('info')
      expect(event['service']).to eq('gobo')
      expect(event['message']).to eq('In static_pages_controller.rb, line 30')
      expect(json['error']).to be_nil
    end
  end

  describe 'when the tracer has no known agent environment' do
    before { allow(controller).to receive(:fetch_agent_environment_label).and_return(nil) }

    it 'does not query and reports the missing environment as an error (JSON)' do
      expect(LogsQuery).not_to receive(:new)
      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json['error']).to eq('no known agent environment for the running tracer')
      expect(json['events']).to eq([])
    end

    it 'shows the missing-environment error in HTML' do
      get :index
      expect(response.body).to include('no known agent environment for the running tracer')
    end
  end
end

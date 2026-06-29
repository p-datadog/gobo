require 'rails_helper'

RSpec.describe DiStatusController, type: :controller do
  describe 'GET #index DI enablement state' do
    # Drives the decision table in #fetch_di_enabled_status by stubbing the
    # individual predicate helpers, so each branch is exercised independently
    # of the installed tracer version.
    def stub_di_predicates(running:, explicitly_enabled: false, explicitly_disabled: false,
      supports_remote: true, unsupported: false)
      allow(controller).to receive(:di_explicitly_disabled?).and_return(explicitly_disabled)
      allow(controller).to receive(:di_component_running?).and_return(running)
      allow(controller).to receive(:di_explicitly_enabled?).and_return(explicitly_enabled)
      allow(controller).to receive(:di_supports_remote_enablement?).and_return(supports_remote)
      allow(controller).to receive(:di_unsupported?).and_return(unsupported)
    end

    it 'reports :enabled_explicitly when running and explicitly enabled' do
      stub_di_predicates(running: true, explicitly_enabled: true)
      get :index
      expect(assigns(:di_enabled)).to eq(:enabled_explicitly)
    end

    it 'reports :enabled_implicitly when running without explicit enablement' do
      stub_di_predicates(running: true, explicitly_enabled: false)
      get :index
      expect(assigns(:di_enabled)).to eq(:enabled_implicitly)
    end

    it 'reports :disabled_explicitly when explicitly disabled' do
      stub_di_predicates(running: false, explicitly_disabled: true)
      get :index
      expect(assigns(:di_enabled)).to eq(:disabled_explicitly)
    end

    it 'reports :can_enable_remotely when off, supported, and not explicitly disabled' do
      stub_di_predicates(running: false, supports_remote: true, unsupported: false)
      get :index
      expect(assigns(:di_enabled)).to eq(:can_enable_remotely)
    end

    it 'reports :unavailable when off and remote enablement is unsupported' do
      stub_di_predicates(running: false, supports_remote: false)
      get :index
      expect(assigns(:di_enabled)).to eq(:unavailable)
    end

    it 'reports :unavailable when off and the environment is unsupported' do
      stub_di_predicates(running: false, supports_remote: true, unsupported: true)
      get :index
      expect(assigns(:di_enabled)).to eq(:unavailable)
    end

    it 'resolves to one of the five known states against the real tracer' do
      get :index
      expect(assigns(:di_enabled)).to be_in(
        %i[enabled_explicitly enabled_implicitly disabled_explicitly can_enable_remotely unavailable]
      )
    end
  end

  describe 'displayed DI status' do
    render_views

    {
      enabled_explicitly: 'Yes — explicitly enabled',
      enabled_implicitly: 'Yes — enabled remotely',
      disabled_explicitly: 'No — explicitly disabled',
      can_enable_remotely: 'No — can be enabled remotely',
      unavailable: 'No — unavailable',
    }.each do |state, text|
      it "shows '#{text}' for #{state}" do
        allow(controller).to receive(:fetch_di_enabled_status).and_return(state)
        get :index
        expect(response.body).to include(text)
      end
    end
  end

  describe 'empty-state root cause' do
    render_views

    before { allow(controller).to receive(:fetch_all_installed_probes).and_return({}) }

    it 'states the accurate cause for the resolved DI state, not generic guesses' do
      allow(controller).to receive(:fetch_di_enabled_status).and_return(:disabled_explicitly)
      get :index
      expect(response.body).to include('No probes found.')
      expect(response.body).to include('explicitly disabled')
      expect(response.body).not_to include('This could mean:')
    end
  end

  describe 'agent operational status' do
    render_views

    it 'shows the agent as operational when /info responds' do
      allow(controller).to receive(:fetch_agent_operational)
        .and_return(AgentInfo::Result.new(operational: true, error: nil))
      get :index
      expect(response.body).to include('operational')
      expect(response.body).not_to include('not operational')
    end

    it 'shows the agent as not operational when /info fails' do
      allow(controller).to receive(:fetch_agent_operational)
        .and_return(AgentInfo::Result.new(operational: false, error: 'Errno::ECONNREFUSED: Connection refused'))
      get :index
      expect(response.body).to include('not operational')
    end

    it 'defaults the agent host to 127.0.0.1 when the setting is unset' do
      agent = double('agent', host: nil, port: 18126)
      allow(Datadog.configuration).to receive(:agent).and_return(agent)
      expect(AgentInfo).to receive(:new).with(host: '127.0.0.1', port: 18126)
        .and_return(instance_double(AgentInfo, call: AgentInfo::Result.new(operational: true)))
      controller.send(:fetch_agent_operational)
    end

    it 'serializes the operational flag in JSON' do
      allow(controller).to receive(:fetch_agent_operational)
        .and_return(AgentInfo::Result.new(operational: true, error: nil))
      get :index, format: :json
      expect(JSON.parse(response.body)['agent_operational']).to be(true)
    end
  end

  describe 'REDAPL service_config query' do
    render_views

    let(:result) do
      RedaplQuery::Result.new(
        rows: [RedaplQuery::Row.new(service_name: 'gobo', language_name: 'ruby', env: 'staging')],
        error: nil, query: "SELECT ... WHERE service_name = 'gobo'",
        host: 'dd.datad0g.com', cookie_path: '/cookies-staging.json', window_minutes: 10
      )
    end

    it 'does not run the query on a plain page load' do
      expect(RedaplQuery).not_to receive(:new)
      get :index
      expect(assigns(:redapl)).to be_nil
    end

    it 'runs the query for the requested environment and renders the rows' do
      expect(RedaplQuery).to receive(:new)
        .with(host: 'dd.datad0g.com', cookie_label: 'staging', service: anything)
        .and_return(instance_double(RedaplQuery, call: result))
      get :index, params: {redapl: 'staging'}
      expect(assigns(:redapl)[:rows]).to eq([{service_name: 'gobo', language_name: 'ruby', env: 'staging'}])
      expect(response.body).to include('cookies-staging.json')
      expect(response.body).to include('gobo')
      expect(response.body).to include('staging')
    end

    it 'shows the query error to the user when REDAPL fails' do
      failed = RedaplQuery::Result.new(
        rows: [], error: 'RuntimeError: no cookies staged at /cookies-dogfood.json',
        query: 'SELECT ...', host: 'squirrel.datadoghq.com',
        cookie_path: '/cookies-dogfood.json', window_minutes: 10
      )
      allow(RedaplQuery).to receive(:new).and_return(instance_double(RedaplQuery, call: failed))
      get :index, params: {redapl: 'dogfood'}
      expect(response.body).to include('REDAPL query failed')
      expect(response.body).to include('no cookies staged at /cookies-dogfood.json')
    end

    it 'ignores an unknown environment without running the query' do
      expect(RedaplQuery).not_to receive(:new)
      get :index, params: {redapl: 'bogus'}
      expect(assigns(:redapl)).to be_nil
    end
  end

  describe 'JSON di_enabled' do
    it 'serializes the state as a string' do
      allow(controller).to receive(:fetch_di_enabled_status).and_return(:can_enable_remotely)
      get :index, format: :json
      expect(JSON.parse(response.body)['di_enabled']).to eq('can_enable_remotely')
    end
  end

  describe '#di_setting_explicitly? fallback for older tracers' do
    let(:settings) { Datadog.configuration.dynamic_instrumentation }

    it 'is true only for the value the customer explicitly set' do
      allow(settings).to receive(:using_default?).with(:enabled).and_return(false)
      allow(settings).to receive(:enabled).and_return(true)
      expect(controller.send(:di_setting_explicitly?, true)).to be(true)
      expect(controller.send(:di_setting_explicitly?, false)).to be(false)
    end

    it 'is false when the setting is left at its default' do
      allow(settings).to receive(:using_default?).with(:enabled).and_return(true)
      expect(controller.send(:di_setting_explicitly?, true)).to be(false)
      expect(controller.send(:di_setting_explicitly?, false)).to be(false)
    end
  end

  context 'when the tracer lacks Datadog::DI (older or absent tracer)' do
    before { hide_const('Datadog::DI') }

    it 'reports :unavailable without raising' do
      get :index
      expect(response).to have_http_status(:success)
      expect(assigns(:di_enabled)).to eq(:unavailable)
    end
  end
end

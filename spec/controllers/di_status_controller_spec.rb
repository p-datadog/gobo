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

    it 'reports :explicitly_enabled_rc_disabled when explicitly enabled but not running' do
      stub_di_predicates(running: false, explicitly_enabled: true)
      get :index
      expect(assigns(:di_enabled)).to eq(:explicitly_enabled_rc_disabled)
    end

    it 'captures the specific unavailable reason from the tracer' do
      stub_di_predicates(running: false, supports_remote: true, unsupported: true)
      allow(Datadog::DI).to receive(:unsupported_reason).and_return('C extension is not available')
      get :index
      expect(assigns(:di_enabled)).to eq(:unavailable)
      expect(assigns(:di_unavailable_reason)).to eq('C extension is not available')
    end

    it 'reports :error and captures the message when the status check raises' do
      allow(controller).to receive(:di_explicitly_disabled?).and_raise(RuntimeError, 'boom')
      get :index
      expect(assigns(:di_enabled)).to eq(:error)
      expect(assigns(:di_status_error)).to eq('RuntimeError: boom')
    end

    it 'resolves to one of the known states against the real tracer' do
      get :index
      expect(assigns(:di_enabled)).to be_in(
        %i[enabled_explicitly enabled_implicitly disabled_explicitly
          explicitly_enabled_rc_disabled can_enable_remotely unavailable error]
      )
    end
  end

  describe 'displayed DI status' do
    render_views

    {
      enabled_explicitly: 'Yes — explicitly enabled',
      enabled_implicitly: 'Yes — enabled remotely',
      disabled_explicitly: 'No — explicitly disabled',
      explicitly_enabled_rc_disabled: 'No — disabled by Remote Configuration',
      can_enable_remotely: 'No — can be enabled remotely',
      unavailable: 'No — unavailable',
      error: 'Unknown — status check failed',
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

  describe 'failed probes' do
    render_views

    let(:message) do
      'Datadog::DI::Error::ProbeTargetForbidden: Method probes on Kernel#lambda are not permitted: Kernel#lambda'
    end

    before do
      allow(controller).to receive(:fetch_failed_probes).and_return('probe-1' => message)
    end

    it 'does not raise when failed_probes contains error message strings' do
      get :index
      expect(response).to have_http_status(:success)
      expect(response.body).to include('probe-1')
      expect(response.body).to include('Method probes on Kernel#lambda are not permitted')
    end

    it 'serializes failed probes as id/error pairs in JSON' do
      get :index, format: :json
      expect(JSON.parse(response.body)['failed']).to eq(
        [{'id' => 'probe-1', 'error' => message}]
      )
    end
  end

  describe 'capture expressions' do
    render_views

    def build_capture_probe(evaluate_at: :exit, capture_snapshot: false)
      limited = Datadog::DI::CaptureExpression.new(
        name: 'user_id',
        expr: Datadog::DI::EL::Expression.new({'ref' => 'user'}, 'nil'),
        limits: Datadog::DI::CaptureLimits.new(max_length: 100, max_reference_depth: 3)
      )
      plain = Datadog::DI::CaptureExpression.new(
        name: 'count',
        expr: Datadog::DI::EL::Expression.new({'ref' => 'count'}, 'nil'),
        limits: nil
      )
      Datadog::DI::Probe.new(
        id: 'probe-ce', type: :log, file: 'app/x.rb', line_no: 10,
        capture_expressions: [limited, plain],
        evaluate_at: evaluate_at, capture_snapshot: capture_snapshot
      )
    end

    before do
      allow(controller).to receive(:fetch_all_installed_probes)
        .and_return('probe-ce' => build_capture_probe)
    end

    it 'serializes each capture expression with name, DSL, and per-expression limits in JSON' do
      get :index, format: :json
      active = JSON.parse(response.body)['active']
      expect(active.size).to eq(1)
      expect(active.first['evaluate_at']).to eq('exit')
      expect(active.first['capture_snapshot']).to be(false)
      expect(active.first['capture_expressions']).to eq(
        [
          {'name' => 'user_id', 'dsl' => {'ref' => 'user'},
           'limits' => {'max_reference_depth' => 3, 'max_length' => 100}},
          {'name' => 'count', 'dsl' => {'ref' => 'count'}},
        ]
      )
    end

    it 'omits capture-expression fields for probes without capture expressions' do
      plain = Datadog::DI::Probe.new(id: 'plain', type: :log, file: 'app/x.rb', line_no: 5)
      allow(controller).to receive(:fetch_all_installed_probes).and_return('plain' => plain)
      get :index, format: :json
      active = JSON.parse(response.body)['active'].first
      expect(active).not_to have_key('capture_expressions')
      expect(active).not_to have_key('evaluate_at')
    end

    it 'renders each capture expression name, DSL, and limits in the HTML' do
      get :index
      expect(response.body).to include('Capture Expressions')
      expect(response.body).to include('user_id')
      expect(response.body).to include('count')
      expect(response.body).to include('&quot;ref&quot;: &quot;user&quot;')
      expect(response.body).to include('maxLength=100')
      expect(response.body).to include('maxReferenceDepth=3')
    end

    it 'shows the evaluation timing for capture expressions' do
      allow(controller).to receive(:fetch_all_installed_probes)
        .and_return('probe-ce' => build_capture_probe(evaluate_at: :entry))
      get :index
      expect(response.body).to include('Evaluated at:')
      expect(response.body).to include('entry')
    end

    it 'does not raise on a tracer whose probes lack capture-expression support' do
      legacy = double('legacy_probe',
        id: 'legacy', type: :log, file: 'app/x.rb', line_no: 5,
        type_name: nil, method_name: nil, template: nil, condition: nil,
        rate_limit: 5000, enabled?: true)
      allow(controller).to receive(:fetch_all_installed_probes).and_return('legacy' => legacy)
      get :index
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Capture Expressions')
      get :index, format: :json
      expect(JSON.parse(response.body)['active'].first).not_to have_key('capture_expressions')
    end
  end

  describe 'REDAPL service_config query' do
    render_views

    # This page also runs the heartbeats and live-service-instances lookups for
    # the same env; stub them so these REDAPL tests never touch wclip or the
    # network.
    before do
      allow(LiveServiceInstancesQuery).to receive(:new).and_return(
        instance_double(LiveServiceInstancesQuery, call: LiveServiceInstancesQuery::Result.new(
          active: [], inactive: [], error: nil, endpoint: '/x', host: 'h',
          cookie_path: '/c', service: 'gobo', env: 'staging'
        ))
      )
      allow(DebuggerHeartbeatsQuery).to receive(:new).and_return(
        instance_double(DebuggerHeartbeatsQuery, call: DebuggerHeartbeatsQuery::Result.new(
          instances: [], last_seen: nil, error: nil, host: 'h',
          cookie_path: '/c', service: 'gobo', env: 'staging'
        ))
      )
    end

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

    it 'offers a single query link for the agent environment, not a choice of environments' do
      allow(controller).to receive(:fetch_agent_environment_label).and_return('staging')
      get :index
      expect(response.body).to include('Query REDAPL service_config for staging')
      expect(response.body).not_to include('cookies-dogfood.json')
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

  describe 'debugger heartbeats' do
    render_views

    # This page also runs the REDAPL and live-service-instances lookups for the
    # same env; stub them so these heartbeat tests never touch wclip or the
    # network.
    before do
      allow(RedaplQuery).to receive(:new).and_return(
        instance_double(RedaplQuery, call: RedaplQuery::Result.new(
          rows: [], error: nil, query: 'SELECT ...', host: 'h',
          cookie_path: '/c', window_minutes: 10
        ))
      )
      allow(LiveServiceInstancesQuery).to receive(:new).and_return(
        instance_double(LiveServiceInstancesQuery, call: LiveServiceInstancesQuery::Result.new(
          active: [], inactive: [], error: nil, endpoint: '/x', host: 'h',
          cookie_path: '/c', service: 'gobo', env: 'staging'
        ))
      )
    end

    let(:result) do
      DebuggerHeartbeatsQuery::Result.new(
        instances: [DebuggerHeartbeatsQuery::Instance.new(
          runtime_id: 'rid-1', service_env: 'staging', service_version: '5e97551',
          tracer_version: '2.38.0-dev', language: 'ruby', agent_id: 'big-test-docker',
          hostname: nil, last_seen: '2026-07-14T14:49:26.888Z'
        )],
        last_seen: '2026-07-14T14:49:28.019Z', error: nil,
        host: 'dd.datad0g.com', cookie_path: '/cookies-staging.json',
        service: 'gobo', env: 'staging'
      )
    end

    it 'does not run the query on a plain page load' do
      expect(DebuggerHeartbeatsQuery).not_to receive(:new)
      get :index
      expect(assigns(:heartbeats)).to be_nil
    end

    it 'runs the query for the requested environment and renders instances' do
      expect(DebuggerHeartbeatsQuery).to receive(:new)
        .with(host: 'dd.datad0g.com', cookie_label: 'staging', service: anything, env: anything)
        .and_return(instance_double(DebuggerHeartbeatsQuery, call: result))
      get :index, params: {redapl: 'staging'}
      expect(assigns(:heartbeats)[:instances].first[:runtime_id]).to eq('rid-1')
      expect(response.body).to include('rid-1')
      expect(response.body).to include('2.38.0-dev')
      expect(response.body).to include('NOT DETECTED')
    end

    it 'shows the empty condition when there are no heartbeats' do
      empty = DebuggerHeartbeatsQuery::Result.new(
        instances: [], last_seen: nil, error: nil,
        host: 'dd.datad0g.com', cookie_path: '/cookies-staging.json',
        service: 'gobo', env: 'staging'
      )
      allow(DebuggerHeartbeatsQuery).to receive(:new)
        .and_return(instance_double(DebuggerHeartbeatsQuery, call: empty))
      get :index, params: {redapl: 'staging'}
      expect(response.body).to include('No debugger heartbeats for')
    end

    it 'shows the query error to the user when the lookup fails' do
      failed = DebuggerHeartbeatsQuery::Result.new(
        instances: [], last_seen: nil,
        error: 'RuntimeError: no cookies staged at /cookies-dogfood.json',
        host: 'squirrel.datadoghq.com', cookie_path: '/cookies-dogfood.json',
        service: 'gobo', env: nil
      )
      allow(DebuggerHeartbeatsQuery).to receive(:new)
        .and_return(instance_double(DebuggerHeartbeatsQuery, call: failed))
      get :index, params: {redapl: 'dogfood'}
      expect(response.body).to include('debugger heartbeats query failed')
      expect(response.body).to include('no cookies staged at /cookies-dogfood.json')
    end

    it 'ignores an unknown environment without running the query' do
      expect(DebuggerHeartbeatsQuery).not_to receive(:new)
      get :index, params: {redapl: 'bogus'}
      expect(assigns(:heartbeats)).to be_nil
    end

    it 'serializes heartbeats in JSON' do
      allow(DebuggerHeartbeatsQuery).to receive(:new)
        .and_return(instance_double(DebuggerHeartbeatsQuery, call: result))
      get :index, params: {redapl: 'staging'}, format: :json
      json = JSON.parse(response.body)
      expect(json['heartbeats']['instances'].first['runtime_id']).to eq('rid-1')
      expect(json['heartbeats']['env']).to eq('staging')
    end
  end

  describe 'live service instances' do
    render_views

    # This page also runs the REDAPL and heartbeats lookups for the same env;
    # stub them so these instance tests never touch wclip or the network.
    before do
      allow(RedaplQuery).to receive(:new).and_return(
        instance_double(RedaplQuery, call: RedaplQuery::Result.new(
          rows: [], error: nil, query: 'SELECT ...', host: 'h',
          cookie_path: '/c', window_minutes: 10
        ))
      )
      allow(DebuggerHeartbeatsQuery).to receive(:new).and_return(
        instance_double(DebuggerHeartbeatsQuery, call: DebuggerHeartbeatsQuery::Result.new(
          instances: [], last_seen: nil, error: nil, host: 'h',
          cookie_path: '/c', service: 'gobo', env: 'staging'
        ))
      )
    end

    let(:result) do
      LiveServiceInstancesQuery::Result.new(
        active: [LiveServiceInstancesQuery::Instance.new(
          runtime_id: 'rid-1', hostname: 'host-a', service_env: 'staging',
          service_version: '7cd00b1', client_library_version: '2.20.0',
          agent_version: '7.55.0', di_enabled: true,
          remote_config_products: %w[LIVE_DEBUGGING], language_name: 'ruby'
        )],
        inactive: [], error: nil,
        endpoint: '/api/unstable/live-service-instances?service_name=gobo&service_env=staging',
        host: 'dd.datad0g.com', cookie_path: '/cookies-staging.json',
        service: 'gobo', env: 'staging'
      )
    end

    it 'does not run the query on a plain page load' do
      expect(LiveServiceInstancesQuery).not_to receive(:new)
      get :index
      expect(assigns(:instances)).to be_nil
    end

    it 'runs the query for the requested environment and renders active instances' do
      expect(LiveServiceInstancesQuery).to receive(:new)
        .with(host: 'dd.datad0g.com', cookie_label: 'staging', service: anything, env: anything)
        .and_return(instance_double(LiveServiceInstancesQuery, call: result))
      get :index, params: {redapl: 'staging'}
      expect(assigns(:instances)[:active].first[:runtime_id]).to eq('rid-1')
      expect(response.body).to include('rid-1')
      expect(response.body).to include('2.20.0')
      expect(response.body).to include('LIVE_DEBUGGING')
    end

    it 'shows the empty condition when the active list is empty' do
      empty = LiveServiceInstancesQuery::Result.new(
        active: [], inactive: [], error: nil,
        endpoint: '/api/unstable/live-service-instances?service_name=gobo&service_env=staging',
        host: 'dd.datad0g.com', cookie_path: '/cookies-staging.json',
        service: 'gobo', env: 'staging'
      )
      allow(LiveServiceInstancesQuery).to receive(:new)
        .and_return(instance_double(LiveServiceInstancesQuery, call: empty))
      get :index, params: {redapl: 'staging'}
      expect(response.body).to include('No active instances for')
    end

    it 'shows the query error to the user when the lookup fails' do
      failed = LiveServiceInstancesQuery::Result.new(
        active: [], inactive: [], error: 'RuntimeError: no cookies staged at /cookies-dogfood.json',
        endpoint: '/api/unstable/live-service-instances?service_name=gobo',
        host: 'squirrel.datadoghq.com', cookie_path: '/cookies-dogfood.json',
        service: 'gobo', env: nil
      )
      allow(LiveServiceInstancesQuery).to receive(:new)
        .and_return(instance_double(LiveServiceInstancesQuery, call: failed))
      get :index, params: {redapl: 'dogfood'}
      expect(response.body).to include('live-service-instances query failed')
      expect(response.body).to include('no cookies staged at /cookies-dogfood.json')
    end

    it 'ignores an unknown environment without running the query' do
      expect(LiveServiceInstancesQuery).not_to receive(:new)
      get :index, params: {redapl: 'bogus'}
      expect(assigns(:instances)).to be_nil
    end

    it 'serializes instances in JSON' do
      allow(LiveServiceInstancesQuery).to receive(:new)
        .and_return(instance_double(LiveServiceInstancesQuery, call: result))
      get :index, params: {redapl: 'staging'}, format: :json
      json = JSON.parse(response.body)
      expect(json['instances']['active'].first['runtime_id']).to eq('rid-1')
      expect(json['instances']['env']).to eq('staging')
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

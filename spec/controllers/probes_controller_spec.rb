require 'rails_helper'

RSpec.describe ProbesController, type: :controller do
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

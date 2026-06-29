require 'rails_helper'

RSpec.describe ProbesHelper, type: :helper do
  describe '#probes_empty_state_reason' do
    it 'reports a fetch error above all else' do
      reason = helper.probes_empty_state_reason(:enabled_explicitly, 'RuntimeError: boom')
      expect(reason).to eq('Probes could not be fetched from the tracer (see the error above).')
    end

    it 'attributes the empty state to no probes created when DI is running explicitly' do
      reason = helper.probes_empty_state_reason(:enabled_explicitly)
      expect(reason).to include('running and ready')
      expect(reason).to include('no probes have been created')
    end

    it 'attributes the empty state to no probes created when DI is running implicitly' do
      reason = helper.probes_empty_state_reason(:enabled_implicitly)
      expect(reason).to include('running and ready')
      expect(reason).to include('no probes have been created')
    end

    it 'attributes the empty state to explicit disablement' do
      reason = helper.probes_empty_state_reason(:disabled_explicitly)
      expect(reason).to include('explicitly disabled')
      expect(reason).to include('DD_DYNAMIC_INSTRUMENTATION_ENABLED=false')
    end

    it 'attributes the empty state to DI not running but remotely enableable' do
      reason = helper.probes_empty_state_reason(:can_enable_remotely)
      expect(reason).to include('not running')
      expect(reason).to include('Remote')
    end

    it 'attributes the empty state to DI being unavailable' do
      reason = helper.probes_empty_state_reason(:unavailable)
      expect(reason).to include('not available in this environment')
    end
  end
end

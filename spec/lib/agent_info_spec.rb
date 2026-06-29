require 'rails_helper'
require_relative '../../lib/agent_info'

RSpec.describe AgentInfo do
  subject(:agent_info) { described_class.new(host: '127.0.0.1', port: 18126) }

  describe '#call' do
    it 'is operational when /info returns 200 with a JSON body' do
      allow(agent_info).to receive(:perform).and_return([200, '{"version":"7.50.0","endpoints":["/v0.4/traces"]}'])
      result = agent_info.call
      expect(result).to be_operational
      expect(result.error).to be_nil
    end

    it 'is not operational on a non-200 response' do
      allow(agent_info).to receive(:perform).and_return([404, 'not found'])
      result = agent_info.call
      expect(result).not_to be_operational
      expect(result.error).to eq('HTTP 404')
    end

    it 'is not operational when /info returns 200 with an unparseable body' do
      allow(agent_info).to receive(:perform).and_return([200, 'not json'])
      expect(agent_info.call).not_to be_operational
    end

    it 'is not operational and records the error when the agent is unreachable' do
      allow(agent_info).to receive(:perform).and_raise(Errno::ECONNREFUSED, 'Connection refused')
      result = agent_info.call
      expect(result).not_to be_operational
      expect(result.error).to match(/Errno::ECONNREFUSED/)
    end
  end
end

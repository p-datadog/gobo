require 'rails_helper'
require 'agent_environments'

RSpec.describe AgentEnvironments do
  describe '.all' do
    it 'returns dogfood and staging' do
      expect(described_class.all.keys).to contain_exactly('dogfood', 'staging')
    end

    it 'exposes agent_port and host for each label' do
      described_class.all.each_value do |attrs|
        expect(attrs).to include(:agent_port, :host)
        expect(attrs[:agent_port]).to be_a(Integer)
        expect(attrs[:host]).to be_a(String)
      end
    end
  end

  describe '.fetch' do
    it 'returns attributes for a known label' do
      expect(described_class.fetch('staging')).to include(agent_port: 28126, host: 'dd.datad0g.com')
    end

    it 'raises for an unknown label' do
      expect { described_class.fetch('bogus') }.to raise_error(ArgumentError, /Unknown agent environment/)
    end
  end

  describe '.label_for' do
    it 'returns the label for a known port' do
      expect(described_class.label_for(28126)).to eq('staging')
      expect(described_class.label_for(18126)).to eq('dogfood')
    end

    it 'accepts string ports' do
      expect(described_class.label_for('28126')).to eq('staging')
    end

    it 'returns nil for an unknown port' do
      expect(described_class.label_for(8126)).to be_nil
    end

    it 'returns nil for nil' do
      expect(described_class.label_for(nil)).to be_nil
    end
  end

  describe '.symdb_api_url' do
    it 'builds the api url from the host' do
      expect(described_class.symdb_api_url('staging')).to eq('https://dd.datad0g.com/api/unstable/symdb-api')
      expect(described_class.symdb_api_url('dogfood')).to eq('https://app.datadoghq.com/api/unstable/symdb-api')
    end
  end

  describe 'DEFAULT_LABEL' do
    it 'is dogfood' do
      expect(described_class::DEFAULT_LABEL).to eq('dogfood')
    end
  end
end

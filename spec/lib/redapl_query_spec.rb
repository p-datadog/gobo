require 'rails_helper'
require_relative '../../lib/redapl_query'

RSpec.describe RedaplQuery do
  let(:host) { 'dd.datad0g.com' }

  describe '#cookie_path' do
    it 'derives the wclip path from the environment label' do
      expect(described_class.new(host: host, cookie_label: 'staging').cookie_path)
        .to eq('/cookies-staging.json')
      expect(described_class.new(host: host, cookie_label: 'dogfood').cookie_path)
        .to eq('/cookies-dogfood.json')
    end
  end

  describe '#query' do
    it 'returns the unfiltered service_config query without a service' do
      expect(described_class.new(host: host, cookie_label: 'staging').query)
        .to eq(described_class::BASE_QUERY)
    end

    it 'narrows to the service and escapes single quotes' do
      query = described_class.new(host: host, cookie_label: 'staging', service: "go'bo").query
      expect(query).to eq("#{described_class::BASE_QUERY} WHERE service_name = 'go''bo'")
    end
  end

  describe '#call' do
    subject(:redapl) { described_class.new(host: host, cookie_label: 'staging', service: 'gobo') }

    let(:beagle_response) do
      {
        'data' => [
          {
            'attributes' => {
              'columns' => [
                {'name' => 'service_name', 'values' => %w[gobo gobo]},
                {'name' => 'language_name', 'values' => %w[ruby ruby]},
                {'name' => 'env', 'values' => %w[staging prod]},
              ],
            },
          },
        ],
      }
    end

    before do
      allow(redapl).to receive(:fetch_cookies).and_return([{'name' => 'dogweb', 'value' => 'x'}])
      allow(redapl).to receive(:fetch_csrf_token).and_return('deadbeef')
    end

    it 'returns parsed rows on success' do
      allow(redapl).to receive(:run_query).and_return(beagle_response)
      result = redapl.call
      expect(result).to be_ok
      expect(result.rows.map(&:env)).to eq(%w[staging prod])
      expect(result.rows.first.service_name).to eq('gobo')
      expect(result.rows.first.language_name).to eq('ruby')
      expect(result.query).to include("WHERE service_name = 'gobo'")
      expect(result.host).to eq(host)
      expect(result.cookie_path).to eq('/cookies-staging.json')
    end

    it 'maps the service_env column when the alias is absent' do
      allow(redapl).to receive(:run_query).and_return(
        'data' => [{'attributes' => {'columns' => [
          {'name' => 'service_name', 'values' => %w[gobo]},
          {'name' => 'language_name', 'values' => %w[ruby]},
          {'name' => 'service_env', 'values' => %w[staging]},
        ]}}]
      )
      expect(redapl.call.rows.first.env).to eq('staging')
    end

    it 'returns an empty row set when service_config has no data' do
      allow(redapl).to receive(:run_query).and_return('data' => [])
      result = redapl.call
      expect(result).to be_ok
      expect(result.rows).to be_empty
    end

    it 'captures any error into the result instead of raising' do
      allow(redapl).to receive(:fetch_cookies)
        .and_raise(RuntimeError, 'no cookies staged at /cookies-staging.json')
      result = redapl.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged at /cookies-staging.json')
      expect(result.rows).to be_empty
    end
  end
end

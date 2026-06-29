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

  describe '#fetch_csrf_token' do
    subject(:redapl) { described_class.new(host: 'squirrel.datadoghq.com', cookie_label: 'dogfood') }

    it 'reads csrf_token from the legacy_current_user JSON endpoint' do
      expect(redapl).to receive(:http_get)
        .with(URI('https://squirrel.datadoghq.com/api/v1/legacy_current_user'), anything)
        .and_return([nil, '{"id":1,"csrf_token":"0d6ac09d603a"}'])
      expect(redapl.send(:fetch_csrf_token, [])).to eq('0d6ac09d603a')
    end

    it 'raises when the user payload carries no csrf_token (unauthenticated)' do
      allow(redapl).to receive(:http_get).and_return([nil, '{"user_status":"not-logged-in"}'])
      expect { redapl.send(:fetch_csrf_token, []) }
        .to raise_error(/not authenticated/)
    end
  end

  describe '#http_get' do
    subject(:redapl) { described_class.new(host: host, cookie_label: 'staging') }

    def response(klass, code, body: '', location: nil)
      r = klass.new('1.1', code, 'msg')
      r['location'] = location if location
      allow(r).to receive(:body).and_return(body)
      r
    end

    it 'returns the body on success' do
      allow(redapl).to receive(:perform).and_return(response(Net::HTTPOK, '200', body: 'hi'))
      _, body = redapl.send(:http_get, URI('https://x/'))
      expect(body).to eq('hi')
    end

    it 'follows a non-login redirect' do
      allow(redapl).to receive(:perform).and_return(
        response(Net::HTTPFound, '302', location: 'https://x/apm/home'),
        response(Net::HTTPOK, '200', body: 'landed')
      )
      _, body = redapl.send(:http_get, URI('https://x/'))
      expect(body).to eq('landed')
    end

    it 'raises when redirected to login' do
      allow(redapl).to receive(:perform)
        .and_return(response(Net::HTTPFound, '302', location: 'https://x/account/login?next=%2F'))
      expect { redapl.send(:http_get, URI('https://x/')) }
        .to raise_error(/not authenticated/)
    end

    it 'raises on a non-success, non-redirect response' do
      allow(redapl).to receive(:perform).and_return(response(Net::HTTPInternalServerError, '500', body: 'boom'))
      expect { redapl.send(:http_get, URI('https://x/')) }
        .to raise_error(/HTTP 500/)
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

require 'rails_helper'
require_relative '../../lib/datadog_session'

RSpec.describe DatadogSession do
  let(:host) { 'dd.datad0g.com' }

  def build(**opts)
    described_class.new(host: host, cookie_label: 'staging', **opts)
  end

  def response(klass, code, body: '', location: nil)
    r = klass.new('1.1', code, 'msg')
    r['location'] = location if location
    allow(r).to receive(:body).and_return(body)
    r
  end

  describe '#cookie_path' do
    it 'derives the wclip path from the environment label' do
      expect(build.cookie_path).to eq('/cookies-staging.json')
      expect(described_class.new(host: host, cookie_label: 'dogfood').cookie_path)
        .to eq('/cookies-dogfood.json')
    end
  end

  describe '#http_get' do
    subject(:session) { build }

    it 'returns the body on success' do
      allow(session).to receive(:perform).and_return(response(Net::HTTPOK, '200', body: 'hi'))
      _, body = session.send(:http_get, URI('https://x/'))
      expect(body).to eq('hi')
    end

    it 'follows a non-login redirect' do
      allow(session).to receive(:perform).and_return(
        response(Net::HTTPFound, '302', location: 'https://x/apm/home'),
        response(Net::HTTPOK, '200', body: 'landed')
      )
      _, body = session.send(:http_get, URI('https://x/'))
      expect(body).to eq('landed')
    end

    it 'raises when redirected to login' do
      allow(session).to receive(:perform)
        .and_return(response(Net::HTTPFound, '302', location: 'https://x/account/login?next=%2F'))
      expect { session.send(:http_get, URI('https://x/')) }
        .to raise_error(/not authenticated/)
    end

    it 'raises on a non-success, non-redirect response' do
      allow(session).to receive(:perform).and_return(response(Net::HTTPInternalServerError, '500', body: 'boom'))
      expect { session.send(:http_get, URI('https://x/')) }
        .to raise_error(/HTTP 500/)
    end
  end

  describe '#get_json' do
    subject(:session) { build }

    it 'sends session cookies and parses the JSON body' do
      allow(session).to receive(:fetch_cookies).and_return([{'name' => 'dogweb', 'value' => 'x'}])
      allow(session).to receive(:perform) do |request, _uri|
        expect(request['cookie']).to eq('dogweb=x')
        expect(request['accept']).to eq('application/json')
        response(Net::HTTPOK, '200', body: '{"ok":true}')
      end
      expect(session.get_json('/api/thing')).to eq('ok' => true)
    end
  end

  describe '#post_json' do
    subject(:session) { build }

    before { allow(session).to receive(:fetch_cookies).and_return([{'name' => 'dogweb', 'value' => 'x'}]) }

    it 'posts the payload with the CSRF token and parses the response' do
      allow(session).to receive(:perform) do |request, _uri|
        expect(request['x-csrf-token']).to eq('deadbeef')
        expect(JSON.parse(request.body)).to eq('a' => 1)
        response(Net::HTTPOK, '200', body: '{"data":[]}')
      end
      expect(session.post_json('/api/thing', {a: 1}, csrf_token: 'deadbeef')).to eq('data' => [])
    end

    it 'raises on a non-success response' do
      allow(session).to receive(:perform).and_return(response(Net::HTTPInternalServerError, '500', body: 'boom'))
      expect { session.post_json('/api/thing', {}, csrf_token: 'x') }
        .to raise_error(/HTTP 500/)
    end
  end

  describe '#csrf_token' do
    subject(:session) { described_class.new(host: 'squirrel.datadoghq.com', cookie_label: 'dogfood') }

    it 'reads csrf_token from the legacy_current_user JSON endpoint' do
      allow(session).to receive(:get_json)
        .with('/api/v1/legacy_current_user')
        .and_return('id' => 1, 'csrf_token' => '0d6ac09d603a')
      expect(session.csrf_token).to eq('0d6ac09d603a')
    end

    it 'raises when the user payload carries no csrf_token (unauthenticated)' do
      allow(session).to receive(:get_json).and_return('user_status' => 'not-logged-in')
      expect { session.csrf_token }.to raise_error(/not authenticated/)
    end
  end
end

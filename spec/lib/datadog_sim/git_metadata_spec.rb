# frozen_string_literal: true

require 'rails_helper'
require 'datadog_sim/git_metadata'

RSpec.describe DatadogSim::GitMetadata do
  describe '.parse_github_url' do
    it 'parses HTTPS URL' do
      expect(described_class.parse_github_url('https://github.com/owner/repo'))
        .to eq(['owner', 'repo'])
    end

    it 'parses HTTPS URL with .git suffix' do
      expect(described_class.parse_github_url('https://github.com/owner/repo.git'))
        .to eq(['owner', 'repo'])
    end

    it 'parses SSH URL' do
      expect(described_class.parse_github_url('git@github.com:owner/repo.git'))
        .to eq(['owner', 'repo'])
    end

    it 'parses PR URL' do
      expect(described_class.parse_github_url('https://github.com/DataDog/dd-trace-rb/pull/5431'))
        .to eq(['DataDog', 'dd-trace-rb'])
    end

    it 'parses blob/file URL' do
      expect(described_class.parse_github_url('https://github.com/owner/repo/blob/main/README.md'))
        .to eq(['owner', 'repo'])
    end

    it 'parses issue URL' do
      expect(described_class.parse_github_url('https://github.com/owner/repo/issues/123'))
        .to eq(['owner', 'repo'])
    end

    it 'returns nil for non-GitHub URLs' do
      expect(described_class.parse_github_url('https://gitlab.com/owner/repo'))
        .to eq([nil, nil])
    end

    it 'returns nil for nil' do
      expect(described_class.parse_github_url(nil)).to eq([nil, nil])
    end
  end

  describe '.from_github_api' do
    it 'uses HTTP API first' do
      mock_http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, code: '200',
        body: { 'sha' => 'httpsha789' }.to_json)
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(response)

      result = described_class.from_github_api('https://github.com/owner/repo', 'main')

      expect(result[:repository_url]).to eq('https://github.com/owner/repo.git')
      expect(result[:commit_sha]).to eq('httpsha789')
    end

    it 'falls back to gh CLI when HTTP fails' do
      allow(Net::HTTP).to receive(:new).and_raise(Errno::ECONNREFUSED)
      allow(Open3).to receive(:capture3)
        .with('gh', 'api', 'repos/owner/repo/commits/main', '--jq', '.sha')
        .and_return(["ghsha123\n", '', double(success?: true)])

      result = described_class.from_github_api('https://github.com/owner/repo', 'main')

      expect(result[:commit_sha]).to eq('ghsha123')
    end

    it 'returns nil sha when both HTTP and gh CLI fail' do
      allow(Net::HTTP).to receive(:new).and_raise(Errno::ECONNREFUSED)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: false)])

      result = described_class.from_github_api('https://github.com/owner/repo', 'main')

      expect(result[:repository_url]).to eq('https://github.com/owner/repo.git')
      expect(result[:commit_sha]).to be_nil
    end
  end

  describe '.from_local_repo' do
    it 'returns url and sha from git commands' do
      allow(Open3).to receive(:capture3)
        .with('git remote get-url origin', chdir: '/some/dir')
        .and_return(["https://github.com/owner/repo\n", '', double(success?: true)])
      allow(Open3).to receive(:capture3)
        .with('git rev-parse HEAD', chdir: '/some/dir')
        .and_return(["deadbeef\n", '', double(success?: true)])

      result = described_class.from_local_repo('/some/dir')

      expect(result[:repository_url]).to eq('https://github.com/owner/repo')
      expect(result[:commit_sha]).to eq('deadbeef')
    end

    it 'returns nil values when git commands fail' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: false)])

      result = described_class.from_local_repo('/some/dir')

      expect(result[:repository_url]).to be_nil
      expect(result[:commit_sha]).to be_nil
    end
  end

  describe '.from_env' do
    it 'reads from environment variables' do
      allow(ENV).to receive(:[]).with('DD_GIT_REPOSITORY_URL').and_return('https://github.com/env/repo')
      allow(ENV).to receive(:[]).with('DD_GIT_COMMIT_SHA').and_return('envsha123')

      result = described_class.from_env

      expect(result[:repository_url]).to eq('https://github.com/env/repo')
      expect(result[:commit_sha]).to eq('envsha123')
    end
  end

  describe '.resolve' do
    it 'uses GitHub API when repo_url provided' do
      expect(described_class).to receive(:from_github_api).with('https://github.com/o/r', 'main')
        .and_return({ repository_url: 'url', commit_sha: 'sha' })

      described_class.resolve(repo_url: 'https://github.com/o/r')
    end

    it 'uses local repo when work_dir provided' do
      expect(described_class).to receive(:from_local_repo).with('/some/dir')
        .and_return({ repository_url: 'url', commit_sha: 'sha' })

      described_class.resolve(work_dir: '/some/dir')
    end

    it 'falls back to env when no options provided and no .git dir' do
      allow(File).to receive(:exist?).with('.git').and_return(false)
      expect(described_class).to receive(:from_env)
        .and_return({ repository_url: nil, commit_sha: nil })

      described_class.resolve
    end
  end
end

# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open3'
require 'uri'

module DatadogSim
  # Resolves git repository URL and commit SHA for use in telemetry, RC, and traces.
  #
  # Resolution order:
  #   1. Explicit --git-repo URL option: parses a GitHub URL and fetches the
  #      latest commit SHA on the default branch via the GitHub API (stdlib only).
  #   2. Local repo auto-detect: runs `git remote get-url origin` and
  #      `git rev-parse HEAD` in the given working directory.
  #   3. Environment variables: DD_GIT_REPOSITORY_URL, DD_GIT_COMMIT_SHA.
  #   4. Nothing — git metadata simply won't be sent.
  class GitMetadata
    GITHUB_API_HOST = 'api.github.com'

    # Resolve git metadata from the given options.
    # @param repo_url [String, nil]  explicit GitHub repo URL (--git-repo)
    # @param work_dir [String, nil]  local directory to run git commands in
    # @param branch   [String]       branch to use when fetching from GitHub API
    # @return [Hash] { repository_url:, commit_sha: } (values may be nil)
    def self.resolve(repo_url: nil, work_dir: nil, branch: 'main')
      if repo_url
        from_github_api(repo_url, branch)
      elsif work_dir || File.exist?('.git')
        from_local_repo(work_dir || Dir.pwd)
      else
        from_env
      end
    end

    # Fetch repository URL and latest commit SHA from GitHub.
    # Tries `gh api` first (authenticated, no rate limit concerns),
    # then falls back to unauthenticated HTTPS API (60 req/hr limit).
    # @param repo_url [String]  e.g. "https://github.com/owner/repo"
    # @param branch   [String]  e.g. "main"
    def self.from_github_api(repo_url, branch = 'main')
      owner, repo = parse_github_url(repo_url)
      return { repository_url: repo_url, commit_sha: nil } unless owner && repo

      canonical = "https://github.com/#{owner}/#{repo}.git"

      sha = from_github_http(owner, repo, branch) || from_gh_cli(owner, repo, branch)
      { repository_url: canonical, commit_sha: sha }
    end

    # Use `gh api` (GitHub CLI) — authenticated, avoids rate limits.
    def self.from_gh_cli(owner, repo, branch)
      out, _err, status = Open3.capture3(
        'gh', 'api', "repos/#{owner}/#{repo}/commits/#{branch}", '--jq', '.sha'
      )
      status.success? ? out.strip : nil
    rescue
      nil
    end

    # Fall back to unauthenticated HTTPS GitHub API.
    def self.from_github_http(owner, repo, branch)
      path = "/repos/#{owner}/#{repo}/commits/#{branch}"
      http = Net::HTTP.new(GITHUB_API_HOST, 443)
      http.use_ssl = true
      req = Net::HTTP::Get.new(path, 'User-Agent' => 'datadog-sim/1.0', 'Accept' => 'application/json')
      response = http.request(req)
      response.code == '200' ? JSON.parse(response.body)['sha'] : nil
    rescue => e
      $stderr.puts "GitMetadata: GitHub HTTP API failed: #{e.class}: #{e}"
      nil
    end

    private_class_method :from_gh_cli, :from_github_http

    # Detect git metadata from a local repository using git CLI.
    def self.from_local_repo(dir = Dir.pwd)
      url   = git_cmd('git remote get-url origin', dir)
      sha   = git_cmd('git rev-parse HEAD', dir)
      { repository_url: url&.strip, commit_sha: sha&.strip }
    end

    # Read from environment variables.
    def self.from_env
      {
        repository_url: ENV['DD_GIT_REPOSITORY_URL'],
        commit_sha:     ENV['DD_GIT_COMMIT_SHA'],
      }
    end

    # Parse any GitHub URL and extract owner/repo.
    # Accepts repo URLs, PR URLs, issue URLs, file paths — anything within the repo:
    #   https://github.com/owner/repo
    #   https://github.com/owner/repo/pull/5431
    #   https://github.com/owner/repo/blob/main/README.md
    #   git@github.com:owner/repo.git
    # Returns [owner, repo] or [nil, nil]
    def self.parse_github_url(url)
      return [nil, nil] unless url.is_a?(String)

      if (m = url.match(%r{github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?(?:/.*)?$}))
        [m[1], m[2]]
      else
        [nil, nil]
      end
    end

    def self.git_cmd(cmd, dir)
      stdout, _stderr, status = Open3.capture3(cmd, chdir: dir)
      status.success? ? stdout : nil
    rescue
      nil
    end

    private_class_method :git_cmd
  end
end

# Resolves DD_TRACER shorthand specifications into full tracer version strings.
#
# Supported formats:
#   pr:NUMBER        - Resolves a dd-trace-rb PR to its git source
#   branch:NAME      - Uses a branch from DataDog/dd-trace-rb
#   sha:HASH         - Uses a commit from DataDog/dd-trace-rb
#   fork:USER/BRANCH - Uses a branch from a fork of dd-trace-rb
#   /path/to/local   - Local path (passed through)
#   1.2.3            - Version constraint (passed through)
#   git+URL@REF      - Full git URL (passed through)
#   --reset          - Clears the saved tracer specification

module TracerResolver
  REPO = "DataDog/dd-trace-rb"

  class Error < StandardError; end

  def self.resolve(spec)
    case spec
    when "--reset"
      nil
    when /\Apr:(\d+)\z/
      resolve_pr($1)
    when /\Abranch:(.+)\z/
      "git+https://github.com/#{REPO}@#{$1}"
    when /\Asha:(.+)\z/
      "git+https://github.com/#{REPO}@#{$1}"
    when /\Afork:([^\/]+)\/(.+)\z/
      "git+https://github.com/#{$1}/dd-trace-rb@#{$2}"
    else
      spec
    end
  end

  def self.resolve_pr(number)
    json = `gh pr view #{number} --repo #{REPO} --json headRefName,headRepositoryOwner,headRepository 2>&1`
    unless $?.success?
      raise Error, "Failed to fetch PR #{number}: #{json}"
    end

    require 'json'
    data = JSON.parse(json)
    branch = data["headRefName"]
    owner = data.dig("headRepositoryOwner", "login")
    repo = data.dig("headRepository", "name") || "dd-trace-rb"

    "git+https://github.com/#{owner}/#{repo}@#{branch}"
  end
end

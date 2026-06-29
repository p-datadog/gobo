require 'json'
require 'net/http'

# Checks whether the Datadog agent is operational by querying its /info
# endpoint. The agent is considered operational when /info returns HTTP 200
# with a parseable JSON body.
class AgentInfo
  INFO_PATH = '/info'.freeze

  Result = Struct.new(:operational, :error, keyword_init: true) do
    def operational?
      operational
    end
  end

  def initialize(host:, port:, open_timeout: 2, read_timeout: 2)
    @host = host
    @port = port
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def call
    code, body = perform
    return Result.new(operational: false, error: "HTTP #{code}") unless code == 200

    JSON.parse(body)
    Result.new(operational: true, error: nil)
  rescue => e
    Result.new(operational: false, error: "#{e.class}: #{e}")
  end

  private

  def perform
    http = Net::HTTP.new(@host, @port)
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    response = http.request(Net::HTTP::Get.new(INFO_PATH))
    [response.code.to_i, response.body]
  end
end

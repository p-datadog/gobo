require 'yaml'

module AgentEnvironments
  CONFIG_PATH = File.expand_path('../config/agent_environments.yml', __dir__).freeze
  DEFAULT_LABEL = 'dogfood'.freeze

  class << self
    def all
      @all ||= YAML.load_file(CONFIG_PATH).each_with_object({}) do |(label, attrs), out|
        out[label] = { agent_port: attrs.fetch('agent_port'), host: attrs.fetch('host') }.freeze
      end.freeze
    end

    def fetch(label)
      all.fetch(label) { raise ArgumentError, "Unknown agent environment: #{label.inspect}" }
    end

    def label_for(port)
      port = port&.to_i
      all.each { |label, attrs| return label if attrs[:agent_port] == port }
      nil
    end

    def symdb_api_url(label)
      "https://#{fetch(label)[:host]}/api/unstable/symdb-api"
    end
  end
end

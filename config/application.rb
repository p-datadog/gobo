require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gobo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Include the authenticity token in remote forms.
    config.action_view.embed_authenticity_token_in_remote_forms = true

    require_relative '../lib/agent_environments'

    # Bootstrap 5 pagination renderer for the will_paginate helper.
    require_relative '../lib/bootstrap5_pagination_renderer'

    # Strip Datadog log injection prefixes ([dd.env=... ddsource=ruby]) from logs.
    require_relative '../lib/filtered_log_device'
    log_file = File.open(Rails.root.join('log', "#{Rails.env}.log"), 'a')
    log_file.sync = true
    config.logger = ActiveSupport::Logger.new(FilteredLogDevice.new(log_file))
  end
end

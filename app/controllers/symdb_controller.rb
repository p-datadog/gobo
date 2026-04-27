class SymdbController < ApplicationController
  SAMPLE_CLASSES = [
    {
      file: 'app/models/symdb_samples/basic_class.rb',
      entries: [
        {name: 'SymdbSamples::BasicClass', type: :CLASS, description: 'Instance methods, class methods, constants, class variables, visibility levels'},
        {name: 'SymdbSamples::EmptyClass', type: :CLASS, description: 'Empty class (no methods) — extractor returns nil (no source_location)'},
        {name: 'SymdbSamples::ConstantsOnlyClass', type: :CLASS, description: 'Constants only — found via const_source_location on Ruby 2.7+'},
        {name: 'SymdbSamples::ClassVariablesOnlyClass', type: :CLASS, description: 'Class variables only — extractor returns nil (no source_location)'},
      ],
    },
    {
      file: 'app/models/symdb_samples/basic_module.rb',
      entries: [
        {name: 'SymdbSamples::BasicModule', type: :MODULE, description: 'Module with constants and module methods'},
        {name: 'SymdbSamples::EmptyModule', type: :MODULE, description: 'Empty module — extractor returns nil'},
        {name: 'SymdbSamples::ConcernLikeModule', type: :MODULE, description: 'Concern-style module with included block and ClassMethods submodule'},
        {name: 'SymdbSamples::ConcernLikeModule::ClassMethods', type: :MODULE, description: 'Nested ClassMethods module'},
      ],
    },
    {
      file: 'app/models/symdb_samples/inheritance.rb',
      entries: [
        {name: 'SymdbSamples::Inheritance::Vehicle', type: :CLASS, description: 'Base class — no super_classes (Object excluded)'},
        {name: 'SymdbSamples::Inheritance::Car', type: :CLASS, description: 'Subclass — super_classes includes Vehicle'},
        {name: 'SymdbSamples::Inheritance::ElectricCar', type: :CLASS, description: 'Second-level subclass — super_classes includes Car'},
      ],
    },
    {
      file: 'app/models/symdb_samples/metaprogramming.rb',
      entries: [
        {name: 'SymdbSamples::Metaprogramming::DynamicMethods', type: :CLASS, description: 'define_method, keyword args, regular methods side-by-side'},
        {name: 'SymdbSamples::Metaprogramming::Point', type: :CLASS, description: 'Struct subclass with user-defined methods'},
        {name: 'SymdbSamples::Metaprogramming::SingletonMethods', type: :CLASS, description: 'class << self (eigenclass) for class methods'},
      ],
    },
    {
      file: 'app/models/symdb_samples/method_varieties.rb',
      entries: [
        {name: 'SymdbSamples::MethodVarieties', type: :CLASS, description: 'All Ruby parameter types, attr_accessor/reader/writer, visibility, exception handling'},
      ],
    },
    {
      file: 'app/models/symdb_samples/mixins.rb',
      entries: [
        {name: 'SymdbSamples::Mixins::Serializable', type: :MODULE, description: 'Module to be included — instance methods'},
        {name: 'SymdbSamples::Mixins::Auditable', type: :MODULE, description: 'Module to be included — instance methods'},
        {name: 'SymdbSamples::Mixins::Timestamped', type: :MODULE, description: 'Module to be prepended — wraps existing methods'},
        {name: 'SymdbSamples::Mixins::ClassFinder', type: :MODULE, description: 'Module to be extended — class-level methods'},
        {name: 'SymdbSamples::Mixins::MixinUser', type: :CLASS, description: 'Class with include + prepend + extend'},
        {name: 'SymdbSamples::Mixins::SampleConcern', type: :MODULE, description: 'Rails-style ActiveSupport::Concern'},
      ],
    },
    {
      file: 'app/models/symdb_samples/namespaces.rb',
      entries: [
        {name: 'SymdbSamples::Namespaces::Outer', type: :MODULE, description: 'Namespace module with own methods + nested classes'},
        {name: 'SymdbSamples::Namespaces::Outer::Inner', type: :CLASS, description: 'Nested class inside Outer'},
        {name: 'SymdbSamples::Namespaces::Outer::AnotherInner', type: :CLASS, description: 'Second nested class inside Outer'},
        {name: 'SymdbSamples::Namespaces::Outer2', type: :MODULE, description: 'Namespace-only module (no methods) — found via const_source_location on Ruby 2.7+'},
        {name: 'SymdbSamples::Namespaces::Outer2::Nested', type: :CLASS, description: 'Nested class inside namespace-only module'},
        {name: 'SymdbSamples::Namespaces::Deep::A::B::C', type: :CLASS, description: 'Deeply nested class (A::B::C pattern)'},
      ],
    },
  ].freeze

  def index
    @sample_classes = SAMPLE_CLASSES
    @service = fetch_service
    @env = fetch_env
    @symdb_enabled = symdb_enabled?
    @agent_address = fetch_agent_address
    @component_status = fetch_component_status
    @upload_info = fetch_upload_info

    respond_to do |format|
      format.html
      format.json { render json: symdb_json }
    end
  end

  private

  def fetch_agent_address
    return nil unless defined?(Datadog)

    settings = Datadog.configuration
    "#{settings.agent.host}:#{settings.agent.port}"
  rescue => e
    "error: #{e.message}"
  end

  def fetch_service
    return nil unless defined?(Datadog)
    Datadog.configuration.service
  rescue => e
    Rails.logger.error "Error fetching DD_SERVICE: #{e.class}: #{e}"
    nil
  end

  def fetch_env
    return nil unless defined?(Datadog)
    Datadog.configuration.env
  rescue => e
    Rails.logger.error "Error fetching DD_ENV: #{e.class}: #{e}"
    nil
  end

  def symdb_enabled?
    defined?(Datadog) && Datadog.configuration.respond_to?(:symbol_database) &&
      Datadog.configuration.symbol_database.enabled
  rescue => e
    Rails.logger.error "Error checking symdb status: #{e.class}: #{e}"
    false
  end

  def fetch_component_status
    return :no_datadog unless defined?(Datadog::SymbolDatabase)

    component = Datadog.send(:components).symbol_database
    return :not_created if component.nil?
    return :shutdown if component.shutdown?

    :active
  rescue => e
    Rails.logger.error "Error fetching symdb component status: #{e.class}: #{e}"
    :error
  end

  # Read upload status from the component's diagnostic accessors.
  # Returns nil if the component doesn't exist or the accessors aren't available
  # (older tracer without the attr_readers).
  def fetch_upload_info
    return nil unless defined?(Datadog::SymbolDatabase)

    component = Datadog.send(:components).symbol_database
    return nil if component.nil?
    return nil unless component.respond_to?(:last_upload_time)

    {
      enabled: component.enabled,
      last_upload_time: component.last_upload_time,
      upload_in_progress: component.upload_in_progress,
    }
  rescue => e
    Rails.logger.error "Error fetching symdb upload info: #{e.class}: #{e}"
    nil
  end

  def symdb_json
    {
      service: @service,
      env: @env,
      symdb_enabled: @symdb_enabled,
      component_status: @component_status,
      upload_info: @upload_info,
      sample_files: @sample_classes.map do |group|
        {
          file: group[:file],
          entries: group[:entries].map do |entry|
            {name: entry[:name], type: entry[:type], description: entry[:description]}
          end,
        }
      end,
    }
  end
end

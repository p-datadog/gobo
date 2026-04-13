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
    @symdb_enabled = symdb_enabled?
    @upload_enabled = upload_enabled?

    respond_to do |format|
      format.html
      format.json { render json: symdb_json }
    end
  end

  private

  def symdb_enabled?
    defined?(Datadog) && Datadog.configuration.respond_to?(:symbol_database) &&
      Datadog.configuration.symbol_database.enabled
  rescue => e
    Rails.logger.error "Error checking symdb status: #{e.class}: #{e}"
    false
  end

  def upload_enabled?
    defined?(Datadog) && Datadog.configuration.respond_to?(:symbol_database) &&
      Datadog.configuration.symbol_database.respond_to?(:upload) &&
      Datadog.configuration.symbol_database.upload.enabled
  rescue => e
    Rails.logger.error "Error checking symdb upload status: #{e.class}: #{e}"
    false
  end

  def symdb_json
    {
      symdb_enabled: @symdb_enabled,
      upload_enabled: @upload_enabled,
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

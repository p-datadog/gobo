# frozen_string_literal: true

require 'rails_helper'
require 'datadog_sim/languages'

RSpec.describe DatadogSim::LANGUAGES do
  it 'includes all known Datadog tracer languages' do
    expect(described_class.keys).to include('java', 'python', 'ruby', 'dotnet', 'go', 'node', 'php')
  end

  it 'each language has required keys' do
    required_keys = %i[language_name runtime_name runtime_version tracer_version rc_language]
    described_class.each do |lang, profile|
      required_keys.each do |key|
        expect(profile).to have_key(key), "#{lang} missing key: #{key}"
        expect(profile[key]).not_to be_nil, "#{lang}.#{key} is nil"
      end
    end
  end
end

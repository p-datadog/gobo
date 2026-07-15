require 'rails_helper'

RSpec.describe RegexMatchDemo do
  describe '.inputs' do
    it 'includes benign and pathological haystacks' do
      labels = described_class.inputs.map { |i| i[:label] }
      expect(labels).to include('Benign match', 'Benign non-match')
      expect(labels).to include(a_string_matching(/Pathological/))
    end

    it 'builds the pathological input as a run of "a" followed by a non-matching byte' do
      pathological = described_class.inputs.find { |i| i[:label].start_with?('Pathological') }
      expect(pathological[:haystack]).to eq(('a' * 30) + '!')
    end
  end

  describe '.probe_target' do
    it 'reports coordinates read from the live #check method' do
      method = described_class.instance_method(:check)
      file, line = method.source_location
      target = described_class.probe_target

      expect(target[:class_name]).to eq('RegexMatchDemo')
      expect(target[:method_name]).to eq('check')
      expect(target[:file]).to eq(file)
      expect(target[:line]).to eq(line)
    end
  end

  describe '.run' do
    it 'calls #check once per input and reports timing for each' do
      results = described_class.run

      expect(results.map { |r| r[:label] }).to eq(described_class.inputs.map { |i| i[:label] })
      results.each do |r|
        expect(r[:elapsed_ms]).to be_a(Numeric)
        expect(r[:bytes]).to be > 0
        expect(r[:error]).to be_nil
      end
    end

    it 'reports #check return value (haystack length) as length' do
      results = described_class.run
      described_class.inputs.each_with_index do |input, i|
        expect(results[i][:length]).to eq(input[:haystack].length)
      end
    end

    it 'records the error string without aborting the run when #check raises' do
      allow_any_instance_of(described_class).to receive(:check).and_raise(RuntimeError, 'boom')
      results = described_class.run

      expect(results.size).to eq(described_class.inputs.size)
      results.each do |r|
        expect(r[:error]).to eq('RuntimeError: boom')
        expect(r[:length]).to be_nil
      end
    end
  end
end

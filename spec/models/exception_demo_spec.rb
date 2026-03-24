require 'rails_helper'

RSpec.describe ExceptionDemo do
  subject(:demo) { described_class.new }

  describe '#raise_exception' do
    it 'raises ActiveRecord::RecordNotFound for :standard' do
      expect { demo.raise_exception(:standard) }.to raise_error(
        ActiveRecord::RecordNotFound, "Record not found: id=42"
      )
    end

    it 'raises InputValidationError for :overridden' do
      expect { demo.raise_exception(:overridden) }.to raise_error(
        ExceptionDemo::InputValidationError, "Custom: lookup failed"
      )
    end

    it 'raises ContextError for :non_string' do
      expect { demo.raise_exception(:non_string) }.to raise_error(
        ExceptionDemo::ContextError,
      )
    end

    it 'raises ArgumentError for unknown kind' do
      expect { demo.raise_exception(:bogus) }.to raise_error(
        ArgumentError, /Unknown exception kind/
      )
    end
  end

  describe ExceptionDemo::InputValidationError do
    it 'overrides message with Custom: prefix' do
      err = described_class.new("test")
      expect(err.message).to eq("Custom: test")
    end
  end

  describe ExceptionDemo::ContextError do
    it 'accepts non-string constructor argument' do
      err = described_class.new({key: "val"})
      expect(err.message).to include("ContextError")
    end
  end
end

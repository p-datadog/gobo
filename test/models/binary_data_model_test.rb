require "test_helper"

class BinaryDataModelTest < ActiveSupport::TestCase
  test "process returns expected keys" do
    model = BinaryDataModel.new
    result = model.process
    assert_includes result.keys, :data
    assert_includes result.keys, :reference
    assert_includes result.keys, :metadata
    assert_includes result.keys, :status
    assert_includes result.keys, :timestamp
  end

  test "process uses instance data by default" do
    model = BinaryDataModel.new(data: "hello")
    assert_equal "hello", model.process[:data]
  end

  test "process uses reference default" do
    model = BinaryDataModel.new
    assert_equal "reference data", model.process[:reference]
  end

  test "process accepts explicit data argument" do
    model = BinaryDataModel.new(data: "original")
    assert_equal "override", model.process("override")[:data]
  end

  test "process accepts explicit reference argument" do
    model = BinaryDataModel.new
    result = model.process("data", "my reference")
    assert_equal "my reference", result[:reference]
  end

  test "process accepts binary data argument" do
    binary = (0..255).map { |b| b.chr(Encoding::ASCII_8BIT) }.join
    model = BinaryDataModel.new
    result = model.process(binary)
    assert_equal binary, result[:data]
    assert_equal Encoding::ASCII_8BIT, result[:data].encoding
    assert_equal "reference data", result[:reference]
  end

  test "process status is processed" do
    assert_equal "processed", BinaryDataModel.new.process[:status]
  end
end

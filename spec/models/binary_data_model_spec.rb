require 'rails_helper'

RSpec.describe BinaryDataModel, type: :model do
  it "process returns expected keys" do
    model = BinaryDataModel.new
    result = model.process
    expect(result.keys).to include(:data)
    expect(result.keys).to include(:reference)
    expect(result.keys).to include(:metadata)
    expect(result.keys).to include(:status)
    expect(result.keys).to include(:timestamp)
  end

  it "process uses instance data by default" do
    model = BinaryDataModel.new(data: "hello")
    expect(model.process[:data]).to eq("hello")
  end

  it "process uses reference default" do
    model = BinaryDataModel.new
    expect(model.process[:reference]).to eq("reference data")
  end

  it "process accepts explicit data argument" do
    model = BinaryDataModel.new(data: "original")
    expect(model.process("override")[:data]).to eq("override")
  end

  it "process accepts explicit reference argument" do
    model = BinaryDataModel.new
    result = model.process("data", "my reference")
    expect(result[:reference]).to eq("my reference")
  end

  it "process accepts binary data argument" do
    binary = (0..255).map { |b| b.chr(Encoding::ASCII_8BIT) }.join
    model = BinaryDataModel.new
    result = model.process(binary)
    expect(result[:data]).to eq(binary)
    expect(result[:data].encoding).to eq(Encoding::ASCII_8BIT)
    expect(result[:reference]).to eq("reference data")
  end

  it "process status is processed" do
    expect(BinaryDataModel.new.process[:status]).to eq("processed")
  end
end

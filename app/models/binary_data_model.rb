class BinaryDataModel
  attr_accessor :data, :metadata

  def initialize(data: "test data", metadata: {})
    @data = data
    @metadata = metadata
  end

  def process
    {
      timestamp: Time.now,
      data: @data,
      metadata: @metadata,
      status: "processed"
    }
  end
end

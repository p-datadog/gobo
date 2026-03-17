class RawBinaryModel
  def process(data)
    { status: "processed", size: data.bytesize, encoding: data.encoding.to_s }
  end
end

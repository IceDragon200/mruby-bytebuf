assert 'ByteBuf' do
  data = NArray.uint8(16)

  assert_equal 16, data.size

  # Writing
  writer = ByteBuf::Writer.new(data)

  writer.write_int 32

  assert_equal 4, writer.index

  assert_equal 0, data[0]
  assert_equal 0, data[1]
  assert_equal 0, data[2]
  assert_equal 32, data[3]

  writer.write_byte 8
  assert_equal 8, data[4]

  writer.write_pstring "Hello, World"

  ary = []
  'Hello, World'.each_byte { |a| ary << a }
  assert_equal ary, data[6, 12].to_a

  writer.write_cstring "How are you?"

  assert_equal 31, writer.index

  writer.finalize!

  # Reading
  reader = ByteBuf::Reader.new(data)

  value = reader.read_int
  assert_equal 32, value

  value = reader.read_byte
  assert_equal 8, value

  value = reader.read_pstring
  assert_equal 12, value.size
  assert_equal value, "Hello, World"

  value = reader.read_cstring
  assert_equal value, "How are you?"

  assert_true reader.eos?
end

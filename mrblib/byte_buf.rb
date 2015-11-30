module ByteBuf
  class ReadError < RuntimeError
  end

  class Writer
    attr_reader :length
    attr_reader :index

    def initialize(val = 256, &block)
      @data = if val.is_a?(NArray)
        unless val.type == NArray::Type::UINT8
          raise ArgumentError, "data must have an UINT8 type"
        end
        val
      else
        NArray.new(NArray::Type::UNIT8, val)
      end
      @index = 0
      @length = 0
      @realloc_size = 32

      exec_block(&block) if block
    end

    def finalize!
      @data.resize! @length
    end

    def exec_block
      yield self
      finalize1
    end

    def rewind
      @index = 0
    end

    private def advance(len)
      @index += len
      @length += len
    end

    private def prepare_for_data_write
      if @data.size <= @index
        newsize = @data.size
        newsize += @realloc_size while newsize <= @index
        @data.resize! newsize
      end
    end

    def write_bytes(*bytes)
      bytes.each do |byte|
        prepare_for_data_write
        @data[@index] = byte & 0xFF
        advance 1
      end
    end

    def write_byte(value)
      write_bytes value
    end

    def write_num(len, value)
      (len - 1).downto 0 do |i|
        write_byte((value >> (i * 8)) & 0xFF)
      end
    end

    def write_short(value)
      write_num 2, value
    end
    alias :write_int16 :write_short

    def write_int24(value)
      write_num 3, value
    end

    def write_int(value)
      write_num 4, value
    end
    alias :write_int32 :write_int

    def write_long(value)
      write_num 8, value
    end
    alias :write_int64 :write_long

    # Writes each byte in the given string to the array
    # Only use this method if you know what you're doing, there is no way
    # to read this String back unless you know its length
    #
    # @param [String] str
    def write_string(str)
      str.each_byte do |byte|
        write_byte byte
      end
    end

    def write_pstring(str)
      if str.size > 255
        raise ArgumentError, "String must be 255 characters or less!"
      end
      write_byte str.size
      write_string str
    end

    def write_cstring(str)
      write_string str
      write_byte 0
    end
  end

  class Reader
    attr_reader :length
    attr_reader :index

    def initialize(val)
      unless val.is_a?(NArray)
        raise TypeError, "wrong argument type #{val.class} (expected #{NArray})"
      end
      unless val.type == NArray::Type::UINT8
        raise ArgumentError, "data must have an UINT8 type"
      end
      @data = val
      @index = 0
      @length = @data.size
    end

    private def advance(i)
      @index += i
    end

    def eos?
      @index >= @length
    end

    private def check_read_barrier
      raise ReadError, "Index out of range! #{@index}/#{@length}" if eos?
    end

    def read_byte
      check_read_barrier
      byte = @data[@index]
      advance 1
      byte & 0xFF
    end

    def read_until
      bytes = []
      loop do
        byte = read_byte
        break if yield byte
        bytes << byte
      end
      bytes
    end

    def read_bytes(count)
      if block_given?
        count.times { yield read_byte }
      else
        result = []
        count.times { result << read_byte }
        result
      end
    end

    def read_num(len)
      bytes = read_bytes len
      num = 0

      (len - 1).downto 0 do |i|
        byte = bytes[len - 1 - i]
        num |= byte << (i * 8)
      end
      num
    end

    def read_short
      read_num 2
    end
    alias :read_int16 :read_short

    def read_int24
      read_num 3
    end

    def read_int
      read_num 4
    end
    alias :read_int32 :read_int

    def read_long
      read_num 8
    end
    alias :read_int64 :read_long

    def read_pstring
      len = read_byte
      str = ''
      read_bytes len do |byte|
        str << byte.chr
      end
      str
    end

    def read_cstring
      bytes = read_until { |b| b == 0 }
      str = ''
      bytes.each { |byte| str << byte.chr }
      str
    end
  end
end

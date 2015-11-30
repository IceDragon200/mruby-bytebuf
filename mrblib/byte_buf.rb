module ByteBuf
  # Error raised when an attempt is made to read more data than available
  class ReadError < RuntimeError
  end

  # The ability to navigate a stream of data
  module Seekable
    # @!group Seek Constants
    SEEK_CUR = 0
    SEEK_END = 1
    SEEK_SET = 2
    # @!endgroup Seek Constants

    # @!attribute index
    #   @return [Integer] current stream position
    attr_accessor :index

    # @!attribute index
    #   @return [Integer] current stream size
    attr_accessor :length

    protected :index=
    protected :length=

    # Resets the index
    #
    # @return [self]
    def rewind
      self.index = 0
      self
    end

    # @return [Integer] Reports the current position
    def tell
      index
    end
    alias :pos :tell

    # @return [Boolean] true if at the end of the stream, false otherwise
    def eos?
      index >= length
    end

    # Seeks a position given a number and whence
    #
    # @param [Integer] i
    # @param [Symbol, Integer] seek mode
    # @return [self]
    def seek(i, whence = :SET)
      case whence
      when :SET, SEEK_SET
        self.index = i
      when :CUR, SEEK_CUR
        self.index += i
      when :END, SEEK_END
        self.index = length - 1 - i
      else
        raise ArgumentError, "bad seek value #{whence}"
      end
      self
    end
  end

  # The ability to write data
  module Writable
    # @!attribute [r] data
    #   @return [NArray<UNIT8>]
    attr_reader :data

    # @!attribute realloc_size
    #   @return [Integer] number of bytes to add to the stream when resizing
    attr_accessor :realloc_size
    protected :realloc_size

    # Call this method once you finish writing, this will resize the
    # underlying data to the maximum size used
    #
    # @return [self]
    def finalize!
      data.resize! length
      self
    end

    # Yields control and then finalizes
    #
    # @return [self]
    def exec_block
      yield self
      finalize!
    end

    # Advances the index by the given value
    #
    # @param [Integer] i  how far to advance the index
    # @return [self]
    private def advance(i)
      seek i, :CUR
      self.length = index if index > length
      self
    end

    # Checks that the data is writable, possibly resizing the underlying
    # stream to hold more data
    #
    # @return [self]
    private def prepare_for_data_write
      if data.size <= index
        newsize = data.size
        newsize += realloc_size while newsize <= index
        data.resize! newsize
      end
      self
    end

    # Writes a list of bytes to the stream, values will be truncated using &
    # 0xFF
    #
    # @param [Array<Integer>] bytes
    # @return [self]
    def write_bytes(*bytes)
      bytes.each do |byte|
        prepare_for_data_write
        data[index] = byte & 0xFF
        advance 1
      end
      self
    end

    # Writes a byte to the underlying stream
    #
    # @param [Integer] value  a byte
    # @return [self]
    def write_byte(value)
      write_bytes value
      self
    end

    # Writes arbitray length number to the stream
    #
    # @param [Integer] len  length of the number in bytes
    # @param [Integer] value  number to write
    # @return [self]
    def write_num(len, value)
      (len - 1).downto 0 do |i|
        write_byte((value >> (i * 8)) & 0xFF)
      end
      self
    end

    # Writes a short int (2 byte value) to the underlying stream
    #
    # @param [Integer] value  a short int
    # @return [self]
    def write_short(value)
      write_num 2, value
      self
    end
    alias :write_int16 :write_short

    # Writes an int24 (3 byte value) to the underlying stream
    #
    # @param [Integer] value  an int24
    # @return [self]
    def write_int24(value)
      write_num 3, value
      self
    end

    # Writes an int (4 byte value) to the underlying stream
    #
    # @param [Integer] value  an int
    # @return [self]
    def write_int(value)
      write_num 4, value
      self
    end
    alias :write_int32 :write_int

    # Writes a long int (8 byte value) to the underlying stream
    #
    # @param [Integer] value  a long int
    # @return [self]
    def write_long(value)
      write_num 8, value
      self
    end
    alias :write_int64 :write_long

    # Writes each byte in the given string to the array
    # Only use this method if you know what you're doing, there is no way
    # to read this String back unless you know its length
    #
    # @param [String] str
    # @return [self]
    def write_string(str)
      str.each_byte do |byte|
        write_byte byte
      end
      self
    end

    # Writes a pascal string to the stream, the first byte will be the length
    # followed by the ASCII bytes
    #
    # @param [Integer] str  the string to write
    # @return [self]
    def write_pstring(str)
      if str.size > 255
        raise ArgumentError, "String must be 255 characters or less!"
      end
      write_byte str.size
      write_string str
      self
    end

    # Writes a Null Terminated String to the stream
    #
    # @param [String] str  the string to write
    # @return [self]
    def write_cstring(str)
      write_string str
      write_byte 0
    end
  end

  # Writer class for the byte buffer
  class Writer
    include Seekable
    include Writable

    # Create a new ByteBuf::Reader with a Narray instance
    # The NArray must use a UINT8 type
    #
    # @param [NArray] val
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
  end

  # The ability to read a stream
  module Readable
    # @!attribute [r] data
    #   @return [NArray<UNIT8>]
    attr_reader :data

    # Advances the index by the given value
    #
    # @param [Integer] i
    # @return [self]
    private def advance(i)
      seek i, :CUR
      self
    end

    # Checks if anymore bytes can be read from the stream, raises
    # a ReadError if not.
    #
    # @return [self]
    private def check_read_barrier
      raise ReadError, "Index out of range! #{index}/#{length}" if eos?
      self
    end

    # Reads a byte from the stream
    #
    # @return [Integer] byte
    def read_byte
      check_read_barrier
      byte = data[index]
      advance 1
      byte & 0xFF
    end

    # Reads bytes until the block evaluates to true
    #
    # @yieldparam [Integer] byte
    # @yieldreturn [Boolean] true, break at the current position
    # @return [Array<Integer>] bytes
    def read_until
      bytes = []
      loop do
        byte = read_byte
        break if yield byte
        bytes << byte
      end
      bytes
    end

    # Reads the specified number of bytes from the stream
    #
    # @param [Integer] count  number of bytes to read
    # @return [Array<Integer>] bytes
    def read_bytes(count)
      if block_given?
        count.times { yield read_byte }
      else
        result = []
        count.times { result << read_byte }
        result
      end
    end

    # Reads an arbitary length number from the stream
    #
    # @param [Integer] len  number of bytes
    # @return [Integer] number
    def read_num(len)
      bytes = read_bytes len
      num = 0

      (len - 1).downto 0 do |i|
        byte = bytes[len - 1 - i]
        num |= byte << (i * 8)
      end
      num
    end

    # Reads a short int (2 bytes) from the stream
    #
    # @return [Integer] number
    def read_short
      read_num 2
    end
    alias :read_int16 :read_short

    # Reads an int24 (3 bytes) from the stream
    #
    # @return [Integer] number
    def read_int24
      read_num 3
    end

    # Reads an int (4 bytes) from the stream
    #
    # @return [Integer] number
    def read_int
      read_num 4
    end
    alias :read_int32 :read_int

    # Reads a long int (8 bytes) from the stream
    #
    # @return [Integer] number
    def read_long
      read_num 8
    end
    alias :read_int64 :read_long

    # Reads a Pascal String from the stream.
    # The first byte is expected to be the String's length
    #
    # @return [String]
    def read_pstring
      len = read_byte
      str = ''
      read_bytes len do |byte|
        str << byte.chr
      end
      str
    end

    # Reads a Null-Terminated String from the stream.
    #
    # @return [String]
    def read_cstring
      bytes = read_until { |b| b == 0 }
      str = ''
      bytes.each { |byte| str << byte.chr }
      str
    end
  end

  # Reader class
  class Reader
    include Seekable
    include Readable

    # Create a new ByteBuf::Reader with a Narray instance
    # The NArray must use a UINT8 type
    #
    # @param [NArray] val
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
  end
end

require "line_iterator/version"
require 'zlib'

class LineIterator
  include Enumerable
  
  BUFFER_SIZE = 100

  attr_reader :last_line_number, :done, :last_record_number
  attr_accessor :end_of_record_pattern
  
  def to_s
    "#{self.class} <#{@f}, last_line_number: #{last_line_number}>"
  end
  
  alias_method :inspect, :to_s
  
  
  # Open up the input. If it's a string, assume a filename and open it up.
  # Also, run it through GzipReader if the filename ends in .gz or if
  # :gzip => true was passed in the opts
  def initialize(input, opts={})
    if input.is_a? IO
      @f = input
      # deal with IO object
    else # assume string
      @f = File.open(input)
      opts[:gzip] ||= (input =~ /\.gz\Z/)
    end
    
    if opts[:gzip]
      @f =  Zlib::GzipReader.new(@f)
    end
    @base_iterator = @f.each_with_index
    @last_line_number = 0
    @last_record_number = 0
    @done = false
    @buffer = []
    @backup_buffer = []
    @end_of_record_pattern = /\A\s*\n/
  end
  
  
  
  # Override the normal enumerable #next to keep internal track
  # of line numbers
  def next
    # Get the next line from the backup buffer or the stream
    y = @backup_buffer.empty? ? @base_iterator.next : @backup_buffer.shift
    
    # Feed the buffer
    @buffer.shift if @buffer.size ==  BUFFER_SIZE
    @buffer.push y
    
    @last_line_number = y[1] + 1
    return y[0].chomp
  end
  
  alias_method :next_line, :next
  
  # Provide a #peek that takes into account the backup buffer
  
  def peek
    @backup_buffer.empty? ? @base_iterator.peek : @backup_buffer[0]
  end
  
  
  # Skip n lines (default: 1). Just calls next over and over again,
  # but will *never* throw StopIteration error
  def skip(n = 1)
    if n == 0
      return;
    elsif n > 0
      skip_forward(n)
    elsif n < 0
      skip_backwards(-n)
    else
      raise "Tried to skip backwards more than size of buffer (#{BUFFER_SIZE})"
    end
  end

  def skip_forward(n)
    begin
      n.times do
        self.next
      end
    rescue StopIteration
      @done = true
    end
  end
  
  def skip_backwards(n)    
    # can we back up?
    raise IndexError.new, "Tried to skip backwards too far", nil if n > @buffer.size
    n.times { @backup_buffer.unshift @buffer.pop }
    @last_line_number = @backup_buffer[0][1]
  end
  
  # Override normal #each to track last_line_nunber
  def each
    unless block_given?
      return enum_for :each
    end
    begin
      while true
        yield self.next
      end
    rescue StopIteration
      @done = true
    end
  end
  
  alias_method :each_line, :each
  
  # Like #each_with_index, but track line numbers
  # This allows you to call next/skip and still get the correct
  # line number out
  def each_with_line_number
    unless block_given? 
      return enum_for :each_with_line_number
    end
    
    begin
      while true
        yield [self.next, self.last_line_number]
      end
    rescue StopIteration
      @done = true
    end
  end
  
  # Detect the end_of_record for a line-based file, and 
  # do whatever you need to do 

  # This default implementation just checks for blank lines 
  # and eats them, but you can override this in a subclass 
  # (perhaps using the contents of the buffer to determine
  # EOR status)
  
  def end_of_record(buff)
    y = peek
    if  end_of_record_pattern.match(y[0])
      self.next # eat the next line
      return true
    else 
      return false
    end
  end
    
  # Get the next record and return (as an array of chomp'ed lines)
  def next_record
    raise StopIteration if self.done
    buff = []
    begin
      while true do
        if end_of_record(buff) and not buff.empty?
          @last_record_number += 1
          return buff
        else
          buff << self.next
        end
      end
    rescue StopIteration
      @last_record_number += 1
      @done = true
      return buff
    end
  end
  
  # iterate over records
  def each_record
    unless block_given?
      return enum_for(:each_record)
    end
    
    begin
      while !self.done
        yield self.next_record
      end
    end
  end
  
  # Skip over records (forward only!!!!)
  def skip_record(n = 1)
    begin
      n.times {self.next_record}
    rescue StopIteration
      @done = true
    end
  end
  
  alias_method :skip_records, :skip_record
  
  
end

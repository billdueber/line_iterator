require "line_iterator/version"
require 'zlib'

class LineIterator
  include Enumerable

  attr_reader :last_line_number, :done, :last_record_number
  
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
    @iter = @f.each_with_index
    @last_line_number = 0
    @last_record_number = 0
    @done = false
  end
  
  
  # Override the normal enumerable #next to keep internal track
  # of line numbers
  def next
    y = @iter.next
    @last_line_number = y[1] + 1
    return y[0].chomp
  end
  
  
  # Skip n lines (default: 1). Just calls next over and over again,
  # but will *never* throw StopIteration error
  def skip(n = 1)
    begin
      n.times do
        self.next
      end
    rescue StopIteration
      @done = true
    end
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
  
  # Override normal #each_with_index to track line numbers
  # This allows you to call next/skip and still get the correct
  # line number out
  def each_with_index
    unless block_given? 
      return enum_for :each_with_index
    end
    
    begin
      while true
        yield [self.next, self.last_line_number]
      end
    rescue StopIteration
      @done = true
    end
  end
  
  def next_record(delim = /\A\s*\n/)
    raise StopIteration if self.done
    buff = []
    begin
      while true do
        y = @iter.peek
        if delim.match y[0]
          self.next
          unless buff.empty?
            @last_record_number += 1
            return buff
          end
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


  
  # Work with records delimited by blank lines
  def each_record(delim = /\A\s*\n/) 
    unless block_given?
      return enum_for(:each_record, delim)
    end
    
    begin
      while !self.done
        yield self.next_record(delim)
      end
    end
  end
        
      
      
    
  
  
    
end

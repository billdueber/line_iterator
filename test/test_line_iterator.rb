require 'minitest_helper'

describe "creating a new iterator" do
  it "opens a real file" do
    i = LineIterator.new(test_data('numbers.txt'))
    assert_equal "One", i.next
  end
  
  it "opens a gzipped file" do
    i = LineIterator.new(test_data('numbers.txt.gz'))
    assert_equal "One", i.next
  end
  
  it "deals with a file object" do
    f = File.open(test_data('numbers.txt'))
    i = LineIterator.new(f)
    assert_equal 'One', i.next
  end
  
  it "deals with a gzipped file object" do
    f = File.open(test_data('numbers.txt.gz'))
    i = LineIterator.new(f, :gzip=>true)
    assert_equal 'One', i.next
  end    
end

describe "skip forward" do
  before do
    @i = LineIterator.new(test_data('numbers.txt'))
  end
    
  it "skips forward one" do
    @i.skip
    assert_equal 'Two', @i.next
  end
  
  it "skips forward N" do
    @i.skip(5)
    assert_equal 'Six', @i.next
  end
  
  it "skips to the end and will then raise stopiteration on next call" do
    @i.skip(100)
    assert_raises(StopIteration) { @i.next }
  end
  
end

describe "skip backwards" do
  before do
    @i = LineIterator.new(test_data('numbers.txt'))
  end
  
  it "does basic backwards skip" do
    @i.skip(5)
    @i.skip(-1)
    assert_equal "Five", @i.next
  end
  
  it "errors out if you back up past the beginning of the file" do
    @i.skip 2
    assert_raises(RangeError) {@i.skip(-10)}
  end
  
end



describe "maintain line number" do
  before do
    @i = LineIterator.new(test_data('numbers.txt'))
  end
  
  it "starts with a zero last_line_number" do
    assert_equal 0, @i.last_line_number   
  end
  
  it "advances when using next" do
    @i.next
    @i.next
    assert_equal 2, @i.last_line_number
  end
  
  it "advances when using each" do
    cnt = 0
    @i.each do |y|
      cnt += 1
      break if cnt == 3
    end
    assert_equal 3, @i.last_line_number
  end
  
  it "advances when using skip" do
    @i.skip(3)
    assert_equal 3, @i.last_line_number
  end
    
end


describe "working with empty-line-delimited records" do
  before do
    @i = LineIterator.new(test_data('poetry.txt'))
  end
  
  it "works with each_record()" do
    cnt = 0
    @i.each_record do |r|
      cnt += 1
    end
    
    assert_equal 5, cnt
    assert_equal 5, @i.last_record_number
  end
  
  it "gets the first record" do
    r = @i.next_record
    assert_equal 5, r.size
  end
    
  
  it "correctly deals with next_record" do
    r = @i.next_record
    r = @i.next_record
    assert_equal "Out of the bones' need to sharpen and the muscles' to stretch,", r[4]
  end
  
  it "throws StopIterator when it should stop" do
    begin
      while true
        @i.next_record
      end
    rescue StopIteration
      assert_equal 5, @i.last_record_number
    end
  end
  
  it "breaks out of each_record correctly" do
    rec = nil
    @i.each_record do |r|
      rec = r
      break if @i.last_record_number == 2
    end
    assert_equal "Out of the bones' need to sharpen and the muscles' to stretch,", rec[4]
  end
  
end


# Subclass to override end_of_record(buff)
# We introduce a new instance variable to track the most recent prefix
class PrefixBasedRecordIterator < LineIterator
  PREFIXP = /^(\d+)\s+/
  def prefix(line)
    (PREFIXP.match(line))[1]
  end
  
  def end_of_record(buff)
    return true if self.done
    line, line_no = @iter.peek
    p = prefix(line)
    if p != @previous_prefix
      @previous_prefix = p
      unless buff.empty?
        return true
      end
    else
      return false
    end
  end
end

describe "subclass to do prefix-based records" do
  before do
    @i = PrefixBasedRecordIterator.new(test_data('prefix_based_record.txt'))
  end
  
  it "finds all the records with each_record" do
    cnt = 0
    @i.each_record do |rec|
      cnt += 1
    end
    assert_equal 3, cnt
  end
  
  it "gets the prefixed records with next_record" do
    rec = @i.next_record
    assert_equal 3, rec.size

    rec = @i.next_record
    assert_equal 5, rec.size

    rec = @i.next_record
    assert_equal 2, rec.size

  end
end
  

    
  

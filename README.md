# LineIterator

A simple iterator designed to deal easiy with line-oriented text files.

## Features

* Automatically deal with files that end in .gz (via zlib)
* Methods like #next and #each (aliased to #next_line and #each_line) return the line data with the line endings already `chomp`ed off
* Skip forward or backwards by lines (limit on skipping backwards)
* Track line numbers (staring with 1) no matter how you use each_line, next_line, skip (forward and backwards), etc.
* Allow line-oriented records (where a record is a set of lines). The default implementation detends end-of-record as a blank line, but subclassing is easily for other types of line-oriented records.


## Installation

    $ gem install line_iterator

## Basic Usage

First, two quick warnings:

* The record iteration stuff works fine, but I may change the interface to return a smarter object than just an array (so I can pass along, e.g. the starting and ending line numbers in the file for that record).
* This works fine under MRI, fails hard under Jruby 1.7.9 (Null Pointer exception), and runs fine on jruby 1.7.10 in both 1.9 and 2.0 mode.


### Getting a new iterator

~~~ruby

  require 'line_iterator'

  # opening a file
  iter = LineIterator.open('myfile.txt')
  iter = LineIterator.open(already_open_file_or_io_object)
  iter = LineIterator.open('myfile.txt.gz') # automatically use Zlib::GzipReader
  iter = LineIterator.open($stdin, :gzip=>true) # manually set gzip status

~~~

### Getting line data and line numbers

It's an enumerator, so you can use #next, #each, etc.

For clarity you can use `#each_line` and `#next_line` as aliases of 
`#each` and `#next`, respectively.

Access the line number of the last returned (or just consumed via `#skip`) line via `#last_line_number` (where the first line is line 1, just like in an editor or when using head/tail/whatever)
  
~~~ruby  
  iter.each do |line|
    puts "Line number #{iter.last_line_number} : #{line}"
  end
  
  # Line numbers work regardless of how you move through the iterator
  
  iter = LineIterator.open('myfile.txt')
  iter.next
  iter.next
  iter.last_line_number #=> 2 
  iter.each do |line|
    puts iter.last_line_number
    break
  end #=> 3, since the two calls to #next advanced the line number


  # There's a special iterator, `#each_with_line_number`, to mirror 
  # `#each_with_index` but keep proper track of line numbers
  
  iter.each_with_line_number do |line, line_num|
    #...
  end

  # You can use things like #map, but of course that'll read in the whole 
  # input.
  
  iter.map{|line| [iter.last_line_number, line.size]}

~~~  

### Skipping forward and backward

A `LineIterator` can skip forward or (in some cases) backwards.

Calling `#skip` just skips the next line. Calling `#skip(num)` will skip forward `num` lines, or move to the end of the file if you run out of data.

**Unlike `#next`, `#skip` will never throw `StopIteration`**. 

If you call `#skip` with a negative number, the LineIterator will attempt to back up via an internal buffer (set at 100 lines). If you try to back up further than the available data allows, you'll get a `RangeError`.  

~~~ruby

  iter = LineIterator.open('myfile.txt')
  iter.skip 5
  iter.last_line_number #=> 5
  iter.skip(-3)
  iter.last_line_number #=> 2
  iter.next #=> <the third line of the file>
  iter.last_line_number #=> 3

  iter = LineIterator.open('myfile.txt')
  iter.skip(1_000_000) #=> doesn't raise an error!
  iter.next #=> StopIteration error
  
  iter = LineIterator.open('myfile.txt')
  iter.skip(10)
  iter.skip(-100) #=> RangeError
  
~~~


## Dealing with records

`LineIterator` has a simple line-oriented record interface. By default, it separates files on blank lines (lines with nothing but optional whitespace in them) and returns a "record" that simply consists of an array containing the appropriate lines from the file.

Like the line-based commands, the contents of the returned array are already `#chomp`ed.

Note two things:

* There's no `#skip` backwards implemented for records; you can use `#skip_record` or `#skip_records(n)` to skip recordsd forward.
* If you mix `#next_record / #each_record` with `#next_line` / `#each_line` / `#skip`, things are usually going to get *really* screwey. Mixed use is not really supported.

### Using blank-line delimited records


Given the file:

~~~
One Hat
Two Hat

Red Hat
Blue Hat

by Dr. Seuss
~~~

We can use the record interface as follows:

~~~ruby

iter = LineIterator.new('onehat.txt')
x = iter.next_record #=> ['One Hat', 'Two Hat']
y = iter.next_record #=> ['Red Hat', 'Blue Hat']

iter.last_record_number #=> 2

iter.each_record do |rec|
  puts rec.inspect
end #=> Show the one remaining record, ['by Dr. Seuss']

~~~

### Changing the end-of-record pattern

Maybe you have records that are separated by a line with nothing on it but dashes? You can set the pattern used to detect the end of a record by setting
`#end_of_record_pattern`

Given the file:

~~~
Bill Dueber
1234 Sample st.
Ann Arbor, MI 4813
---
Mike Dueber
1350 N. Nowhere
St. Paul, MN 55117
~~~

...you could get the two records out of it as follows:

~~~ruby
iter = LineIterator.new('addresses.txt')
iter.end_of_record_pattern = /\A--+\s*\Z/
iter.each_record do |rec|
  # do something with the arrays of lines returned
end
~~~


### Sublcassing `LineIterator` for different kinds of records

You can subclass `LineIterator` and override the method `#end_of_record(buff)` to return true when there's an end of record. Usually this invovles calling `line, line_number = @base_iterator.peek` to see what's coming up next.

The buffer passed in is the contents of the record so far.

Here's a simple implementation of a subclass that deals with records that are identified by contiguous lines that all have the same prefix string.

Given the file:

~~~
001 Red
001 White
001 Blue
002 One
002 Two
003 Alpha
003 Beta
003 Gamma
003 Delta
~~~

...we have three records, where the end of record is identified by the numeric prefix changing from one line to the next (or, for the last record, by the end of the input).

We can easily subclass `LineIterator` to take care of this case.

~~~ruby

  # Subclass to override end_of_record(buff)
  # We introduce a new instance variable to track the most recent prefix
  class PrefixBasedRecordIterator < LineIterator
    PREFIXP = /^(\d+)\s+/
    def prefix(line)
      (PREFIXP.match(line))[1]
    end
  
    def end_of_record(buff)
      return true if self.done
      line, line_no = @base_iterator.peek
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

  iter = PrefixBasedRecordIterator.new('prefix_file.txt')
  rec = iter.next_record
    #=> ['001 Red', '001 White', '001 Blue']
  rec = iter.next_record
    #=> ['002 One', '002 Two']

~~~





## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

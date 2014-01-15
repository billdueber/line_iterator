# LineIterator

A simple iterator designed to deal easiy with line-oriented text files.

## Features

* Automatically deal with files that end in .gz (via zlib)
* Skip forward by lines
* Allow line-oriented records (where, e.g., a record is a set of lines
separated by a blank line, or where contiguous lines with a comman prefix 
are part of the same record)

## Installation

Add this line to your application's Gemfile:

    gem 'line_iterator'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install line_iterator

## Examples

~~~ruby

  require 'line_iterator'

  # opening a file
  f = LineIterator.open('myfile.txt')
  f = LineIterator.open(already_open_file_or_io_object)
  f = LineIterator.open('myfile.txt.gz') # automatically use Zlib::GzipReader
  f = LineIterator.open($stdin, :gzip=>true) # manually set gzip status


  # Get the lines
  f.each {|line| ...} # use like a normal file
  f.skip              # skip one line
  f.skip(10)          # skip ten lines
  
  # Use line-oriented records
  # Default is to split on /\n\s*\n/ (i.e., any number of blank lines)
  f.each_record do |rec|
    # rec is an array of lines with the newlines stripped off
  end
  
  # Or split on, say, a line with nothing but at least two hash marks
  f.each_record(/\A\#\#+\s*\Z/) {|rec| ... }
  

  # You can also set up a lambda that takes two arguments (the current
  # line and the next line) to see if there's a record break
  # between them.

  

  # return true if there's a new prefix
  has_new_prefix = ->(current_line, next_line) do
    current_line.split(/\t/)[0].strip != next_line.split(/\t/)[0].strip
  end
   
  f.records(has_new_prefix).each do |rec|
    # rec is an array of lines with the newlines stripped off
  end
  
  # All other methods will be delegated to the underlying
  # iterator, so you can use, e.g., #peek

~~~  

## Usage

### Getting a new iterator

You can get a new iterator from


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

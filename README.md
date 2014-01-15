# LineIterator

A simple wrapper around a standard ruby File optimized for dealing with line-oriented text files.

## Features

* Automatically deal with files that end in .gz
* Skip forward and backward (when logical) by lines
* Allow line-oriented records (e.g., sets of lines separated by a blank line)

## Installation

Add this line to your application's Gemfile:

    gem 'line_iterator'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install line_iterator

## Examples

~~~ruby

  require 'linefile'

  # opening a file
  f = LineFile.open('myfile.txt')
  f = LineFile.open(already_open_file_or_io_object)
  f = LineFile.open('myfile.txt.gz') # automatically use Zlib::GzipReader
  f = LineFile.open($stdin, :gzipped=>true) # manually set gzip status


  # Get the lines
  f.each_line {|line| ...} # use like a normal file
  f.skip     # skip one line
  f.skip(10) # skip ten lines
  
  # Use line-oriented records
  # Default is to split on \n[\n\s]*\n (i.e., any number of blank lines)
  f.records.each do |rec|
    # rec is an array of lines with the newlines stripped off
  end
  
  # Or split on, say, a line with nothing but at least two hash marks
  f.records(/\A\#\#+\Z/).each {|rec| ... }
  

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

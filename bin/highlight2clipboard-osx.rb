#!/usr/bin/ruby
# coding: utf-8

# Usage: highlight2clipboard-osx.rb file.html

# Notes:
#
# The documentation of "set the clipboard to" is very terse. It only
# says that it can be set to a value. Multiple values, however, as
# handled by asetting the clipboard to a "record". The record can be
# retrieved by issuing:
#
#   osascript -e "the clipboard as record"
#
# Data can be specified either as a plain string or using the raw
# format, on the form "«data KIND--the-text-using-hex--»". There are
# many kinds, including TEXT and HTML.

# References:
#
# http://www.seanet.com/~jonpugh/JonsCommandsDocs.html
#
# https://developer.apple.com/library/mac/documentation/AppleScript

def usage
  puts "#{File.basename(__FILE__)} file.html"
  exit(0)
end

if ARGV.length != 1
  usage
end

# Note: Applications like Pages do not paste the text as formatted if
# the "styled Clipboard text" entry contains style information.
# Unfortunately, there is no easy way in AppleScript to remove a
# record entry, however, setting it to the empty string seems to work.

record = ""
record += "{"
record += "«class HTML»:«data HTML"
record += `hexdump -ve '1/1 "%.2x"' #{ARGV[0]}`
record += "»"
record += ", styled Clipboard text:\"\""
record += "}"

s = "set the clipboard to (#{record} & (the clipboard as record))"

# puts s

ok = system("osascript", "-e", s)

exit(ok ? 0 : 1)

# highlight2clipboard-osx.rb ends here.

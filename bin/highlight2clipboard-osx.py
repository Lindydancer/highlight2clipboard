#!/usr/bin/python
### highlight2clipboard-osx.py --- Add HTML to clipboard for OS X.

## Copyright (C) 2015 Anders Lindgren

## This program is free software# you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

### Commentary:

## Add a HTML version of the current clipboard, OS X version.
##
## This is part of the highlight2clipboard Emacs package.
##
## Usage:
##
##   highlight2clipboard-osx.py file.html
##

### Code:

import sys
import os
import AppKit
from AppKit import *

# Set the plain string and HTML variants of the pasteboard.
def set_pb(s, html):
    pb = NSPasteboard.generalPasteboard()

    pb.declareTypes_owner_([NSStringPboardType, NSHTMLPboardType], None)
    ns_str = NSString.stringWithString_(s)
    ns_data = ns_str.nsstring().dataUsingEncoding_(NSUTF8StringEncoding)
    pb.setData_forType_(ns_data, NSStringPboardType)

    ns_str = NSString.stringWithString_(html)
    ns_data = ns_str.nsstring().dataUsingEncoding_(NSUTF8StringEncoding)
    pb.setData_forType_(ns_data, NSHTMLPboardType)


# Get the plain string variant of the pasteboard.
def get_pb():
    pb = NSPasteboard.generalPasteboard()
    content = pb.stringForType_(NSStringPboardType)
    return content

if len(sys.argv) != 2:
    print "Add HTML text to pasteboard"
    print
    print "  Usage: " + os.path.basename(__file__) + " file.html"
    exit(0)

with open (sys.argv[1], "r") as myfile:
    html = myfile.read()

set_pb(get_pb(), html)

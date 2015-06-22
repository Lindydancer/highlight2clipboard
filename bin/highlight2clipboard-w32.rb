###############################################################################
# Add HTML text to clipboard MS-Windows version.
#

require "Win32API"

# Interface to MS-Windows.
class W32
  def self.init_functions
    add("user32",   "OpenClipboard",              ["I"],      "I");
    add("user32",   "CloseClipboard",             [],         "I");
  # add("user32",   "EmptyClipboard",             [],         "I");
  # add("user32",   "IsClipboardFormatAvailable", ["I"],      "I");
    add("user32",   "GetClipboardData",           ["I"],      "I");
    add("user32",   "SetClipboardData",           ["I", "I"], "I");
    add("user32",   "RegisterClipboardFormat",    "P",        "I")

    add("kernel32", "GlobalAlloc",                ["I","I"],  "I");
  # add("kernel32", "GlobalSize",                 ["I"],      "I");
    add("kernel32", "GlobalLock",                 ["I"],      "P");
    add("kernel32", "GlobalUnlock",               ["I"],      "I");
  # add("kernel32", "GlobalFree",                 ["I"],      "I");
    add("kernel32", "lstrcpyA",                   ["P", "P"], "P");
    add("kernel32", "lstrlenA",                   ["P"],      "I");

    add("kernel32", "lstrcpyA",                   ["I", "P"], "P",
        "lstrcpyIP");
    add("kernel32", "lstrcpyA",                   ["P", "I"], "P",
        "lstrcpyPI");
    add("kernel32", "GlobalLock",                 ["I"],      "I",
        "GlobalLockI");
  end

  def self.add(mod, name, args, ret, symbol = nil)
    unless symbol
      symbol = name
    end

    @@functions[symbol.to_sym] = Win32API.new(mod, name, args, ret)
  end

  def self.method_missing(m, *args)
    puts "HERE"
    puts @@functions
    return @@functions[m].Call(*args)
  end

  @@functions ||= {}
  if @@functions.empty?
    init_functions
  end
end

# Add a HTML version to the clipboard.
class AddToClipboard
  CF_TEXT         =  1;

  # Global Memory Flags
  GMEM_MOVEABLE   =    0x2;
  GMEM_ZEROINIT   =   0x40;
  GMEM_DDESHARE   = 0x2000;

  GHND = GMEM_MOVEABLE + GMEM_ZEROINIT;

  HTML_MARKER_BLOCK =
    "Version:1.0\r\n"      \
    "StartHTML:%d\r\n"     \
    "EndHTML:%d\r\n"       \
    "StartFragment:%d\r\n" \
    "EndFragment:%d\r\n"   \
    "SourceURL:%s\r\n"


  def get_clipboard(format = CF_TEXT)
    result = ""
    if W32.OpenClipboard(0) != 0
      if (h = W32.GetClipboardData(format)) != 0
        if (p = W32.GlobalLock(h)) != 0
          result = p;
          W32.GlobalUnlock(h);
        end
      end
      W32.CloseClipboard();
    end
    return result;
  end

  def set_clipboard(text, format = CF_TEXT)
    if (text == nil) || (text == "")
      return
    end
    if W32.OpenClipboard(0) != 0
      len = W32.lstrlenA(text);
      # GHND?
      hmem = W32.GlobalAlloc(GMEM_DDESHARE, len+1);
      pmem = W32.GlobalLockI(hmem);
      W32.lstrcpyIP(pmem, text);
      W32.SetClipboardData(format, hmem);
      W32.GlobalUnlock(hmem);
      W32.CloseClipboard();
    end
  end

  def encode_data(header, text, footer, src)
    header_len = header.length
    text_len = text.length
    prefix_len = 0
    # The format comes with a nice twist. The location of the pay load
    # is specified in byte offsets, which is written in plain decimal
    # numbers. The effect is that it's hard to know the byte offset
    # until you know the offset. Not so brilliant...
    #
    # Of course, one could make the format fixed in size, for example
    # by printing the numbers using leading zeros. However, that takes
    # the fun out of the challenge. The solution below iterates until
    # if finds a fix point where the offset and numbers match.
    begin
      old_prefix_len = prefix_len
      prefix = HTML_MARKER_BLOCK % [prefix_len,
                                    (  prefix_len
                                     + header_len
                                     + text_len
                                     + footer.length),
                                    prefix_len + header_len,
                                    prefix_len + header_len + text_len,
                                    src]
      prefix_len = prefix.length
    end while (old_prefix_len != prefix_len)
    return prefix + header + text + footer
  end

  def run(args)
    if args.length != 1
      puts "Usage: #{File.basename(__FILE__)} file.html"
      exit(0)
    end

    header =
      "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\r\n" \
      "<HTML><BODY><!--StartFragment-->"
    footer =
      "<!--EndFragment--></BODY></HTML>"

    # Note: There is a "binread" function, unfortunately it isn't
    # available on older Ruby versions like 1.8.6.
    content = nil
    File.open(args[0], "rb") do |fh|
      content = fh.read
    end

    s = encode_data(header, content, footer, "file://" + __FILE__)

    set_clipboard(s, W32.RegisterClipboardFormat("HTML Format"))
  end
end

AddToClipboard.new.run(ARGV)

exit(0)

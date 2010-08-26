###############################################################################
# Copyright (c) 2010, SugarCRM, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of SugarCRM, Inc. nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL SugarCRM, Inc. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###############################################################################

###############################################################################
# Needed Ruby libs:
###############################################################################
require 'rbconfig'
require 'time'
require 'rubygems'
require 'libxml'

###############################################################################
# SodaUtils -- Module
#     This module is to provide useful functions for soda that do not need
#     to create an object to use this functionality.  The whole point to this
#     module is to be fast, simple, and useful.
#
###############################################################################
module SodaUtils

###############################################################################
# Module global data:
###############################################################################
VERSION = "1.0"
LOG = 0
ERROR = 1
WARN = 2
EVENT = 3
FIREFOX_JS_ERROR_CHECK_SRC = <<JS
var aConsoleService = Components.classes["@mozilla.org/consoleservice;1"].getService(Components.interfaces.nsIConsoleService);
var msg = {};
var msg_count = {};
aConsoleService.getMessageArray(msg, {});
msg.value.forEach(function(m) {
if (m instanceof Components.interfaces.nsIScriptError) {
   m.QueryInterface(Components.interfaces.nsIScriptError);
   var txt = "--Error::" + m.errorMessage +
   "--Line::" + m.lineNumber +
   "--Col::" + m.columnNumber +
   "--Flags::" + m.flags +
   "--Cat::" + m.category+
   "--SrcName::" + m.sourceName;
   print("######" + txt);
} 
});

aConsoleService.reset();

JS

FIREFOX_JS_ERROR_CLEAR = <<JS
var aConsoleService = Components.classes["@mozilla.org/consoleservice;1"].getService(Components.interfaces.nsIConsoleService);

aConsoleService.reset();

JS

###############################################################################
# GetOsType --
#     This function checks the internal ruby config to see what os we are
#     running on.  We should never use the RUBY_PLATFORM as it will not aways
#     give us the info we need.
#
#     Currently this function only checks for supported OS's and will return
#     and error if run on an unsupported os.
#
# Params:
#     None.
#
# Results:
#     returns nil on error, or one of the supported os names in generic
#     format.  
#
#     Supported OS return values:
#     1.) WINDOWS
#     2.) LINUX
#     3.) OSX
#
###############################################################################
def SodaUtils.GetOsType
   os = ""

   if Config::CONFIG['host_os'] =~ /mswin/i
       os = "WINDOWS"
   elsif Config::CONFIG['host_os'] =~ /linux/i
      os = "LINUX"
   elsif Config::CONFIG['host_os'] =~ /darwin/i
      os = "OSX"
   else
      os = Config::CONFIG['host_os'];
      PrintSoda("Found unsupported OS: #{os}!\n", 1)
      os = nil
   end 
   
   return os
end

###############################################################################
# PrintSoda --
#     This is a print function that creates standard formatting when printing
#     Soda message.
#
# Params:
#     str: This is the user message that will be printed after being formatted.
#     
#     error: If set to 1 then all message will start "(!)" to note an error
#        is being reported.  Anything passed other then 1 will result in a
#        "(*)" being used for the message start.
#    
#     file: A valid open writable file handle.  If this isn't nil then all
#        this message will be writen to the file.  Passing nil will bypass
#        this and cause all message to go to STDOUT.
#
#     debug: This will print the caller stack before the message so you can
#        have more useful info for debugging.  Also a datetime stamp will be
#        added to the beginning of the message.
#
#     notime: Setting this to anything other then 0 will remove the datetime
#        stamp from the stdout message, but never from the file message.
#
# Results:
#     Always returns the message that is printed.
#
###############################################################################
def SodaUtils.PrintSoda (str, error = 0, file = nil, debug = 0, notime = 0,
      callback = nil)
   header = ""
   error_header = ""
   msg = nil
   datetime = nil
   stackmsg = ""
   now = nil

   now = Time.now().strftime("%m/%d/%Y-%H:%M:%S")
   header = "[#{now}]"
   
   if (debug != 0)
      cstak = caller()   
      stackmsg = "[Call Stack]:\n"
      cstak.each do |stack|
         stackmsg = stackmsg + "--#{stack}"
      end
      stackmsg = stackmsg + "\n"
   end

   case error
      when SodaUtils::LOG
         error_header = "(*)"
      when SodaUtils::ERROR
         error_header = "(!)"
      when SodaUtils::WARN
         error_header = "(W)"
      when SodaUtils::EVENT
         error_header = "(E)"
      else
         error_header = "(*)" 
   end

   if ( (debug != 1) && (error != 1) )
      msg = header + "#{error_header}#{str}"
   elsif (debug != 0)
      msg = header + "#{error_header}#{str}#{stackmsg}\n"
   else
      msg = "#{header}#{error_header}#{str}"
   end

   if (file)
      file.write(msg)
   else
      if (notime != 0)
         msg = msg.gsub("[#{now}]", "")
      end

      print "#{msg}"
   end

   if (callback != nil)
      callback.call("#{msg}")
   end

   return msg

end

###############################################################################
# DumpEvent -- Function
#     This function dumps a Soda event into a nice log format that can be
#     parsed by our friendly SodaLogReporter class into html.
# 
# Params:
#     event: This is the soda event to dump.  Really this can be an ruby hash.
#
# Results:
#     returns a formatted string on success, or an empty string when there is
#     no hash pairs.
#
# Notes:
#     The formatted string results will look like this:
#     str = "--do=>puts--text=>Closing browser"
#
###############################################################################
def SodaUtils.DumpEvent(event)
   str = ""

   if (event.length < 1)
      return str
   end

   event.each do |key, val|
      str << "--#{key}=>#{val}"
   end
   
   return str
end

###############################################################################
# Base64FileEncode - function
#     This function encodes a file in base64 encoding, without modifying the
#     source file.  So a new file is created that is the encoded version of
#     the source file.
#
# Params:
#     inputfile: The file to encode.
#     outputfile: The dest for the encoded file.
#     tostream: Setting this to true will cause this function to notw write to
#        a file, but to return an encoded stream of bytes insted.
#
# Results:
#     When tostream is set, will return a stream of encoded bytes.
#
###############################################################################
def SodaUtils.Base64FileEncode(inputfile, outputfile, tostream = false)
   buffer = ""
   stream = ""
   base64_stream = ""

   src_file = File.new(inputfile, "r")
   
   if (tostream != true)
      out_file = File.new(outputfile, "w+")
      out_file.binmode
      out_file.sync = true
   end

   src_file.sync = true
   src_file.binmode
  
   while (src_file.read(1024, buffer) != nil)
      stream << buffer
   end
   buffer = nil
   src_file.close

   base64_stream = [stream].pack('m')
   stream = nil
   
   if (tostream != true)
      out_file.write(base64_stream)
      base64_stream = nil
      out_file.close
      base64_stream = nil 
   end 
   
   return base64_stream

end

###############################################################################
# Base64FileDecode - function
#     This function decodes a file from base64 encoding, without modifying the
#     source file.  So a new file is created that is the decoded version of
#     the source file.
#
# Params:
#     inputfile: The file to decode.
#     outputfile: The dest for the decoded file.
#
# Results:
#     None.
#
###############################################################################
def SodaUtils.Base64FileDecode(inputfile, outputfile)
   src_file = File.new(inputfile, "r")
   out_file = File.new(outputfile, "w+")
   buffer = ""
   base64_stream = ""
   stream = ""

   src_file.sync = true
   out_file.sync = true
   src_file.binmode
   out_file.binmode

   while (src_file.read(1024, buffer) != nil)
      base64_stream << buffer
   end
   buffer = nil
   src_file.close

   stream = base64_stream.unpack('m')
   out_file.write(stream)
   stream = nil
   out_file.close

end

###############################################################################
# ParseBlockFile -- Function
#     This function parses Soda block xml files.
#
# Params:
#     block_file: The xml file with blocks
#
# Results:
#     returns an array of hashs.
#
###############################################################################
def SodaUtils.ParseBlockFile(block_file)
   parser = nil
   error = false
   data = []
   doc = nil

   begin
      parser = LibXML::XML::Parser.file(block_file)
      doc = parser.parse()
   rescue Exception => e
      error = true
      data = []
      print "Error: #{e.message}!\n"
      print "BackTrace: #{e.backtrace}!\n"
   ensure
      if (error != false)
         return data
      end
   end

   doc.root.each do |node|
      hash = Hash.new

      if (node.name != "block")
         next
      end

      for child in node.children()
         hash[child.name] = "#{child.content}"
      end

      if (hash['testfile'].empty?)
         next
      end

      data.push(hash)
   end

   return data
end

###############################################################################
# ParseWhiteFile -- Function
#     This function parses Soda white xml files.
#
# Params:
#     white_file: The xml file with white list.
#
# Results:
#     returns an array of hashs.
#
###############################################################################
def SodaUtils.ParseWhiteFile(white_file)
   parser = nil
   error = false
   data = []
   doc = nil

   begin
      parser = LibXML::XML::Parser.file(white_file)
      doc = parser.parse()
   rescue Exception => e
      error = true
      data = []
      print "Error: #{e.message}!\n"
      print "BackTrace: #{e.backtrace}!\n"
   ensure
      if (error != false)
         return data
      end
   end

   doc.root.each do |node|
      hash = Hash.new

      if (node.name != "white")
         next
      end

      for child in node.children()
         hash[child.name] = "#{child.content}"
      end

      data.push(hash)
   end

   return data
end

###############################################################################
# ParseOldBlockListFile -- Function
#     This function parses the old style txt blocklist files.
#
# Params:
#     block_file: This is the blocklist file to parse.
#
# Results:
#     Returns an array of all the files to block, or an empty array on error.
#
###############################################################################
def SodaUtils.ParseOldBlockListFile(block_file)
   result = [] 
   block_file = File.expand_path(block_file)

   if (FileTest.exist?(block_file))
      file_array = IO.readlines(block_file)
      file_array.each do |line|
         line = line.chomp
         bfiles = line.split(',')

         for bf in bfiles
            if (bf == "")
               next
            end
            result.push(bf) 
         end
      end
   else
      result = []
   end
   
   return result
end

###############################################################################
# ConvertOldBrowserClose -- Function
#     This function converts all the old style soda browser closes to the
#     new proper way to close the browser as an action.
#
# Params:
#     event: a soda event.
#     reportobj: The soda report object.
#     testfile: The file with the issue.
#
# Results:
#     Always returns a soda event.
#
###############################################################################
def SodaUtils.ConvertOldBrowserClose(event, reportobj, testfile)

   if (event.key?('close'))
      event['action'] = "close"
      event.delete('close')
      reportobj.log("You are using a deprecated Soda feature: <browser close" +
         "=\"true\" /> Test file: \"#{testfile}\", Line: "+
         "#{event['line_number']}!\n", 
         SodaUtils::WARN)
      reportobj.log("Use <browser action=\"close\" />.\n", SodaUtils::WARN)
   end

   return event
end

###############################################################################
# ConvertOldAssert -- function
#     This function is to handle all the old tests that use the old way to
#     assertnot, which was a total hack!  So this function just looks for the
#     old style assert & exist=false code and converts it to a proper
#     assertnot call.
#
# Params:
#     event: This is a soda event.
#     reportobj: This is soda's report object for logging.
#     testfile: This is the test file that the event came from.
#
# Results:
#     Always returns a soda event.
#
###############################################################################
def SodaUtils.ConvertOldAssert(event, reportobj, testfile)
   msg = nil

   if ( (event.key?('exist')) && (event.key?('assert')) )
      event['exist'] = getStringBool(event['exist'])

      if (event['exist'] == false)
         event['assertnot'] = event['assert']
      end

      msg = "You are using a deprecated Soda feature: " +
         "< assert=\"something\" exist=\"false\" />" +
         " Test file: \"#{testfile}\", Line: #{event['line_number']}\n."
      reportobj.log(msg, SodaUtils::WARN)
      
      msg = "Use: < assertnot=\"something\" />\n"
      reportobj.log(msg, SodaUtils::WARN)

      event.delete('exist')
      event.delete('assert')
   end

   return event
end

###############################################################################
# isRegex -- Function
#     This function checks to see if a string is a perl looking regex.
#
# Input:
#     str: The string to check.
#
# Output:
#     returns true if it is a regex, else false.
#
###############################################################################
   def SodaUtils.isRegex(str)
      result = false

      if ( (str =~  /^\//) && (str =~ /\/$|\/\w+$/) )
         result = true
      else
         result = false
      end

      return result
   end

###############################################################################
# CreateRegexFromStr -- Function
#     This function creates a regexp object from a string.
#
# Input:
#     str: This is the regex string.
#
# Output:
#     returns nil on error, or a Regexp object on success.
#
###############################################################################
   def SodaUtils.CreateRegexFromStr(str)
      options = 0
      items = ""

      return nil if (!isRegex(str))

      str = str.gsub(/^\//,"")
      str =~ /\/(\w+)$/
      items = $1
      str = str.gsub(/\/#{items}$/, "")

      if ((items != nil) && (!items.empty?))
         items = items.split(//)
         items.each do |i|
            case (i)
               when "i"
                  options = options | Regexp::IGNORECASE
               when "m"
                  options = options | Regexp::MULTILINE
               when "x"
                  options = options | Regexp::EXTENDED
            end
         end
      end

      reg = Regexp.new(str, options)

      return reg
   end

###############################################################################
# XmlSafeStr -- Function
#
#
###############################################################################
   def SodaUtils.XmlSafeStr(str)
      str = str.gsub(/&/, "&amp;")
      str = str.gsub(/"/, "&quot;")
      str = str.gsub(/'/, "&apos;")
      str = str.gsub(/</, "&lt;")
      str = str.gsub(/>/, "&gt;")
 
      return str
   end

###############################################################################
# getStringBool -- Function
#     This function checks to see of the value passed to it proves to be 
#     positive in most any way.
#
# Params:
#     value: This is a string that will prove something true or false.
#
# Results:
#     returns true if the value is a form of being 'positive', or false.
#     If the value isn't a string then the value is just returned....
#
# Notes:
#     This is a total hack, we should be throw an exception if the value is
#     something other then a string...  Will come back to this later...
# 
###############################################################################
   def SodaUtils.getStringBool(value)
      results = nil

      if (value.is_a?(String))
         value.downcase!

         if (value == 'true' or value == 'yes' or value == '1')
            results = true
         else
            results = false
         end 
      end

      return results
   end

###############################################################################
# ReadSodaConfig - function
#     This functions reads the soda config file into a hash.
#
# Params:
#     configfile: This is the config xml file to read.
#
# Results:
#     Returns a hash containing the config file parsed into sub hashes and
#     arrays.
#
###############################################################################
def SodaUtils.ReadSodaConfig(configfile)
   parser = nil
   doc = nil
   data = {
      "gvars" => {},
      "cmdopts" => [],
      "errorskip" => []
   }

   parser = LibXML::XML::Parser.file(configfile)
   doc = parser.parse()

   doc.root.each do |node|
      attrs = node.attributes()
      attrs = attrs.to_h()
      name = attrs['name']
      content = node.content()
      case node.name
         when "errorskip"
            data['errorskip'].push("#{attrs['type']}")
         when "gvar"
            data['gvars']["#{name}"] = "#{content}"
         when "cmdopt"
            data['cmdopts'].push({"#{name}" => "#{content}"})
         when "text"
            next
         else
            SodaUtils.PrintSoda("Found unknown xml tag: \"#{node.name}\"!\n", 
               SodaUtils::ERROR)
      end
   end
   
   return data
end


###############################################################################
# WaitSugarAjaxDone -- function
#     This function waits to make sure that sugar has finished all ajax
#     actions.
#
# Input:
#     browser: This is a watir browser object.
#     reportobj: This is an active SodaReporter object.
#
# Returns:
#     -1 on error else 0.
#
# Notes:
#     I had to split up how Windows OS finds the windows, because Watir's 
#     browser.url() method returns '' every time if there are more then
#     one window open.  This is not the cause it Linux, as linux seems to 
#     know what the current active browser is and returns the expected url.
#
###############################################################################
def SodaUtils.WaitSugarAjaxDone(browser, reportobj)
   done = false
   result = 0
   undef_count = 0
   url = browser.url()
   os = ""

   os = GetOsType()

   linux_js = <<JAVA
var windows = getWindows();
var win_count = windows.length -1;
var current_browser_id = -1;
var result = "undefined";

for (var i = 0; i <= win_count; i++) {
   var tmp_win = windows[i];
   var tmp_url = tmp_win.getBrowser().contentDocument.URL;

   if (tmp_url == "#{url}") {
      current_browser_id = i;
      break;
   }
}
JAVA

   other_js = <<JAVA
var current_browser_id = 0;
JAVA

   if (os =~ /linux/i)
      js = "#{linux_js}\n"
   else
      js = "#{other_js}\n"
   end

   js += <<JAVA
if (current_browser_id > -1) {
   var target = getWindows()[current_browser_id];
   var browser = target.getBrowser();
   var content = target.content;
   var doc = browser.contentDocument;
   var d = doc.createElement("script");
   var src = "if (typeof SUGAR == 'undefined') {\n";
   src += "   document.soda_sugar_done = 'undefined';\n";
   src += "} else {\n";
   src += "   document.soda_sugar_done = SUGAR.util.ajaxCallInProgress();\n";
   src += "}";

   d.innerHTML = src;
   doc.body.appendChild(d);
   print(doc.soda_sugar_done);
   result = doc.soda_sugar_done;
} else {
   result = "undefined";
}

print(result);
JAVA

   reportobj.log("Calling: SugarWait.\n")

   for i in 0..300
      tmp = browser.js_eval(js)
      tmp = tmp.chomp()

      case (tmp)
         when /false/i
            tmp = false
         when /true/i
            tmp = true
         when /undefined/i
            tmp = nil
            undef_count += 1
         else
            reportobj.log("WaitSugarAjaxDone: Unknown result: '#{tmp}'!\n",
               SodaUtils::WARN)
      end

      if (tmp == false)
         done = true
         break
      end

      if (undef_count > 30)
         msg = "WaitSugarAjaxDone: Can't find SUGAR object after 30 tries!\n"
         reportobj.ReportFailure(msg)
         done = false
         break
      end

      sleep(0.5)
   end

   if (done)
      result = 0
   else
      result = -1
   end

   return result
end


###############################################################################
###############################################################################
def SodaUtils.getSodaJS()
  return <<JSCode
(function() {
var Dom = YAHOO.util.Dom, DDM = YAHOO.util.DDM;
  
SUGAR.soda = {
  fakeDrag : function(fromEl, toEl)
  {
    if(typeof fromEl == "string") {
      fromEl = Dom.get(fromEl);
    }
    
    if(typeof toEl == "string") {
      toEl = Dom.get(toEl);
    }
    
    var dd = DDM.getDDById(fromEl.id);
    
    var startXY = Dom.getXY(fromEl);
    var endXY = Dom.getXY(toEl);
    
    var startEvent = {
      target : fromEl,
      pageX : startXY[0],
      pageY : startXY[1],
      clientX : startXY[0],
      clientY : startXY[1],
      button : 0
    };
    
    var enterEvent = {
      target : fromEl,
      pageX : endXY[0],
      pageY : endXY[1],
      clientX : endXY[0],
      clientY : endXY[1],
      button : 0
    };
   
    var endEvent = {
      target : fromEl,
      pageX : endXY[0] + 1,
      pageY : endXY[1] + 1,
      clientX : endXY[0] + 1,
      clientY : endXY[1] + 1,
      button : 0
    };
    
    DDM.handleMouseDown(startEvent, dd);
    DDM.handleMouseMove(enterEvent);
    DDM.handleMouseMove(endEvent);
    DDM.handleMouseUp(endEvent);
  }
};
})();
JSCode
end

end


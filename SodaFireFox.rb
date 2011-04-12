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
# Needed ruby libs:
###############################################################################
require 'rubygems'
gem 'commonwatir', '= 1.8.0'
gem 'firewatir', '= 1.8.0'
require 'watir'
require 'SodaUtils'

###############################################################################
# SodaFireFox -- MOdule
#     This module is for doing firefox things with soda.
###############################################################################
module SodaFireFox

###############################################################################
# CreateFireFoxBrowser -- Function
#     This function will create a new firewatir object.
#
# Params: 
#     options:  This is the same options that you would pass to a FireWatir.new
#
# Results:
#     A hash is always returned, if the 'browser' keys value is nil there
#     was an error and the eaception for that error is returned in the hash.
#
###############################################################################
def SodaFireFox.CreateFireFoxBrowser(options = nil)
   result = {
      "browser" => nil,
      "exception" => nil
   }

   Watir::Browser.default = "firefox"

   begin
      if (options != nil)
         result['browser'] = FireWatir::Firefox.new(options)
      else 
         result['browser'] = Watir::Browser.new()
      end

      result['browser'].maximize()
   rescue Exception => e
      result['exception'] = e
      result['browser'] = nil
   ensure
   end

   return result
end

###############################################################################
# CloseBrowser -- function
#     This function trys to close browsers, using this because of a lame
#     watir bug.
#
# Input:
#     watirobj: This is the watir object to use to execute js script.
#
# Output:
#     returns the result of the jsscript.
#
###############################################################################
def SodaFireFox.CloseBrowser(watirobj)
   result = 0
   jssh = <<JS
   var windows = getWindows();
   var len = windows.length -1;
   var closed = 0;

   for(var i = len; i >= len; i--) {
      windows[i].close();
      closed += 1;
   }
   
   closed;
JS

   begin
      result = watirobj.js_eval(jssh)
      result = result.to_i()
   rescue Exception => e
      $curSoda.rep.ReportException(e, true, false)
   ensure

   end

   return result

end

###############################################################################
# KillProcessWindows -- function
#     This function find all running firefox processes and then tries to 
#     kill them.
#
# Input:
#     None.
#
# Output:
#     returns -1 on error else 0 on success.
#
###############################################################################
def SodaFireFox.KillProcessWindows()
   firefox = []
   tmp = nil
   result = 0

   tmp = Kernel.open("| tasklist /NH")
   lines = tmp.readlines()
   tmp.close()

   lines.each do |l|
      l = l.chomp()
      if (l =~ /firefox/i)
         hash = {
            'pid' => nil,
            'name' => nil
         }
         data = l.split(/\s+/)
         hash['name'] = data[0]
         hash['pid'] = data[1].to_i()
         firefox.push(hash)
      end
   end

   if (firefox.length < 1)
      print "(*)No firefox processes to kill, browser closed clean.\n"
   end

   firefox.each do |hash|
      begin
         res = false
         print "Killing Process ID: #{hash['pid']}, Name:"+
            "#{hash['name']}\n"
         cmd = "taskkill /F /T /PID #{hash['pid']}"
         res = Kernel.system(cmd)

         if (res =! true)
            print "Failed calling command: #{cmd}!\n"
            result = -1
         end
      rescue Exception => e
         print "(!)Exception : #{e.message}\n"
         result = -1
      end
   end

   return result
end

###############################################################################
# KillProcessUnix -- function
#     This function find all running firefox processes and then tries to 
#     kill them.
#
# Input:
#     None.
#
# Output:
#     returns -1 on error else 0 on success.
#
###############################################################################
def SodaFireFox.KillProcessUnix()
   firefox = []
   tmp = nil
   result = 0

   tmp = Kernel.open("| ps -e")
   lines = tmp.readlines()
   tmp.close()

   lines.shift()
   lines.each do |l|
      l = l.chomp()
      l = l.gsub(/^\s+/, "")

      if (l =~ /firefox/i)
         print "(*)#{l}\n"
         hash = {
            'pid' => nil,
            'name' => nil
         }

         data = l.split(/\s+/)
         hash['pid'] = data[0].to_i()
         hash['name'] = data[3]
         firefox.push(hash)
      end
   end

   if (firefox.length < 1)
      print "No firefox processes to kill, browser closed clean.\n"
   end

   firefox.each do |hash|
      begin
         print "Killing Process ID: #{hash['pid']}, Name:"+
            "#{hash['name']}\n"
         Process.kill("KILL", hash['pid'])
      rescue Exception => e
         print "(!)Exception: #{e.message}!\n"
         result = -1
      end
   end

   return result
end

###############################################################################
# KillProcesses -- function
#     This function kills all firefox processes.
#
# Input:
#     None.
#
# Output:
#     returns -1 on error else 0 on success.
#
###############################################################################
def SodaFireFox.KillProcesses()
   os = nil
   err = 0

   os = SodaUtils.GetOsType()
   case (os)
      when /linux/i
         err = KillProcessUnix()
      when /windows/i
         err = KillProcessWindows()
   end

   return err

end

end # end module #


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
gem 'commonwatir', '= 1.7.1'
gem 'firewatir', '= 1.7.1'
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

end # end module #


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
# FieldUtils -- Module
#     This is a module that is for things that only have to deal with 
#     SodaFields.
###############################################################################
module FieldUtils

###############################################################################
# WatirFieldToStr -- function
#     This function creates a simple string from the inspect info for a
#     watir element.
#
# Input:
#     field: A watir element object.
#     reporter: A SodaReporter object.
#
# Output:
#     returns a string with inspect info in it, on nil on error.
#
###############################################################################
   def FieldUtils.WatirFieldToStr(field, reporter)
      info = nil
      msg = ""
      elm_type = nil

      begin
         info = field.inspect()
         info = info.chomp()
         info =~ /#\<\w+::(\w+):/
         elm_type = "#{$1}"
         msg << "#{elm_type}:"
         info =~ /how=(\{.*\})/i
         msg << " #{$1}"
      rescue Exception => e
         reporter.ReportException(e, true)
         msg = nil
      ensure
      end

      return msg
   end

###############################################################################
# CheckDisabled -- function
#     This function checks that a given elements disabled status matches the
#     expected status, and reports on the findings.
#
# Input:
#     field: this is the watir element object to check the status of.
#     expected: bool, this is the status that is expected.
#     reporter: A SodaReporter object.
#
# Output:
#     Always returns 0.
#
###############################################################################
   def FieldUtils.CheckDisabled(field, expected, reporter)
      element_status = field.disabled()
      tmp = FieldUtils.WatirFieldToStr(field, reporter)

      if (element_status != expected)
         msg = "Expected element: #{tmp} state to be disabled = "+
         "'#{expected}'"+
         ", but found element to be disabled = '#{element_status}'!\n"
         reporter.ReportFailure(msg)
      else
         msg = "Element: #{tmp} state is disabled = '#{element_status}' as "+
            "expected.\n"
         reporter.log(msg)
      end 

      return 0
   end

end

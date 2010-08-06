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
# SodaCheckBoxField -- Class
#     This is a simple class for dealing with Checkbox fields.
#
###############################################################################
class SodaCheckBoxField < SodaField
   
###############################################################################
# set -- Method
#     This sets the value for a given field.
#
# Params:
#     field: The field to set a value on.
#     value: The value to set.
#
# Results: 
#
###############################################################################
   def self.set(field, value)
      result = 0

      if (!field.enabled?)
         $curSoda.rep.ReportFailure(
            "Error: Trying to set a value for a disabled Element!\n")
      else
         value = self.getStringTrue(value)
         field.set(value)
         result = 0
      end

      return result
   end
   
###############################################################################
# assert -- Method
#     
#
#
###############################################################################
   def self.assert(field, value)
      result = nil

      if (value.kind_of? Regexp)
         $curSoda.rep.log("Warning: Regex does not work on checkbox fields\n")
      end
      
      value = self.getStringTrue(value)
      $curSoda.rep.log("Field Value: #{field.checked?()}\n")

      if (value)
         result = field.checked?()
      else
         result = !field.checked?() 
      end

      return result
   end   

end


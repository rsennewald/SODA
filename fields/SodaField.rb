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
# SodaField -- Class
#
#
#
#
###############################################################################
class SodaField

require 'FieldUtils'

###############################################################################
#
###############################################################################
   def self.assert(field, value)
      comp = (!field.value.empty?)? field.value: field.text
      $curSoda.rep.log("Field Value: #{field.value}\n")
      if value.kind_of? Regexp
         return value.match(comp)
      end
      return value == comp
   end
  
###############################################################################
# jsevent - Method
#     THis method fires a javascript event.
#
# Params:
#     field: The field to fire the event on.
#     jsevent: The event to fire: onmoseover...
#
# Results:
#     None.
#
###############################################################################
   def self.jsevent(field, jsevent, wait = true)
      info = nil
      elm_type = nil
      msg = "Firing JavaScript Event: '#{jsevent}' for Element: "

      print "Wait: #{wait}\n"

      begin
         tmp = FieldUtils.WatirFieldToStr(field, $curSoda.rep)
         tmp = "Unknown" if (tmp == nil)
         $curSoda.rep.log("#{msg}#{tmp}.\n")

         if (Watir::Browser.default !~ /ie/i)
            self.focus(field)
         end

         field.fire_event("#{jsevent}", wait)
      rescue Exception => e
         $curSoda.rep.ReportException(e, true)
      ensure
      end

      $curSoda.rep.log("JavaScript Event finished.\n") 
   end

###############################################################################
#
###############################################################################
   def self.uploadFile(fieldname, file)
      $curSoda.file_field(:value, fieldname).set(file)
   end

###############################################################################
# set -- Method
#     This method sets the value for the field.  Checks to make sure that the
#     field is enabled before trying to set.
#
# Params: 
#     field: this is the watir object for the field.
#     value: The vale to set the field to.
#
# Results:
#     returns 0 on success, or -1 on error
#
###############################################################################
   def self.set(field, value)
      result = 0
      msg = "Setting Element: "

      begin
         tmp = FieldUtils.WatirFieldToStr(field, $curSoda.rep)
         tmp = "Unknown" if (tmp == nil)
         $curSoda.rep.log("#{msg}#{tmp}: Value => '#{value}'.\n")

         if (!field.enabled?)
            $curSoda.rep.ReportFailure(
               "Error: Trying to set a value for a disabled Element!\n")
            result = -1
         else
            field.set(value)
            result = 0
         end
      rescue Exception => e
         $curSoda.rep.ReportException(e, true)
         result = -1
      ensure
      end

      return result 
   end

###############################################################################
# append -- Method:
#     This method appends a value to the existing value for a watir text
#     field.  Checks that the field is enabled before appending.
#
# Params:
#     field: this is the watir object for the field.
#     value: this is the vale to append to the field.
#
# Results:
#     returns -1 on error, or 0 on success.
#
###############################################################################
   def self.append(field, value)
      result = 0
      msg = "Appending to Element: "

      begin
         tmp = FieldUtils.WatirFieldToStr(field, $curSoda.rep)
         tmp = "Unknown" if (tmp == nil)
         $curSoda.rep.log("#{msg}#{tmp}: Value => '#{value}'.\n")

         if (!field.enabled?)
            $curSoda.rep.ReportFailure(
               "Error: Trying to set a value for a disabled Element!\n")
               result = -1
          else
            field.append(value)
            result = 0
          end
      rescue Exception => e
         $curSoda.rep.ReportException(e, true)
         result = -1
      ensure
      end

      $curSoda.rep.log("Append finished.\n")

      return result 
   end

###############################################################################
# alertHack -- Method
#     This method auto answers java alerts & confirms.
#
# Input: alert: true or false, to cancel or ok dialog.
#
# Output: always retutns true.
#     
###############################################################################
   def self.alertHack(alert = nil, modify = true)
      if (alert == nil) 
         return true
      end

      begin
         if (modify)
            if (Watir::Browser.default == 'firefox')
               alertConfirm = "var old_alert = browser.contentWindow.alert;"
               alertConfirm += "var old_confirm = browser.contentWindow."+
                  "confirm;"
               alertConfirm += "browser.contentWindow.alert = function()"+
                  "{return #{alert};};"
               alertConfirm += "browser.contentWindow.confirm = function()"+
                  "{return #{alert};};"
               if (alert)
                  alertConfirm += "browser.contentWindow.onbeforeunload = null;"
               end
               $jssh_socket.send(alertConfirm + "\n", 0)
               $curSoda.browser.read_socket();
            end

            if (Watir::Browser.default == 'ie')
               alertConfirm = "var old_alert = window.alert;"
               alertConfirm += "var old_confirm = window.confirm;"
               alertConfirm += "window.alert = function(){return #{alert};};"
               alertConfirm += "window.confirm = function(){return #{alert};};"
               if (alert)
                  alertConfirm += "window.onbeforeunload = null;"
               end
               $curSoda.browser.document.parentWindow.eval(alertConfirm + "\n")
            end
         else
            if (Watir::Browser.default == 'firefox')
               alertConfirm = "browser.contentWindow.alert = old_alert;"
               alertConfirm += "browser.contentWindow.confirm = old_confirm;"
               if (alert)
                  alertConfirm += "browser.contentWindow.onbeforeunload = null;"
               end
               $jssh_socket.send(alertConfirm + "\n", 0)
               $curSoda.browser.read_socket();
            end

            if (Watir::Browser.default == 'ie')
               alertConfirm = "var old_alert = window.alert;"
               alertConfirm += "var old_confirm = window.confirm;"
               alertConfirm += "window.alert = old_alert;"
               alertConfirm += "window.confirm = old_confirm;"
               if (alert)
                  alertConfirm += "window.onbeforeunload = null;"
               end
               $curSoda.browser.document.parentWindow.eval(alertConfirm + "\n")
            end
         end
      rescue Exception => e
         $curSoda.rep.ReportException(e, true)
      ensure
      end
   end
 
###############################################################################
# click -- Method
#     This method fires a watir element object's click method.
#
# Params:
#     field: This is the watir object to click.
#
# Results:
#     Always returns 0
#
###############################################################################
   def self.click(field, type = "")
      result = 0
      msg = "Clicking element: "
            
      begin
         self.focus(field)
      rescue Exception => e
         if (Watir::Browser.default !~ /ie/i)
            $curSoda.rep.ReportException(e, true)
         end
      ensure
      end
      
      begin
         tmp = FieldUtils.WatirFieldToStr(field, $curSoda.rep)
         tmp = "Unknown" if (tmp == nil) 

         $curSoda.rep.log("#{msg}#{tmp}.\n")
         field.click()
         $curSoda.browser.wait()
      rescue Exception => e
         result = -1
         $curSoda.rep.ReportException(e, true)
      ensure
      end

      $curSoda.rep.log("Click finished.\n")

      return result 
   end
   
###############################################################################
#
###############################################################################
   def self.focus(field)
      return field.focus
   end

###############################################################################
#
###############################################################################
   def self.clear(field)
      return field.clear
   end
   
###############################################################################
#
###############################################################################
   def self.getValue(field)
      return field.value
   end
           
###############################################################################
#
###############################################################################
   def self.getText(field)
      return field.text()
   end
  
###############################################################################
#
###############################################################################
   def self.enabled(field)
      return field.enabled?()
   end
  
###############################################################################
#
###############################################################################
   def self.disabled(field)
      return !(field.enabled?())
   end

###############################################################################
# return true or false based on a string value 
###############################################################################
   def self.getStringTrue(value)
      if value.is_a?(String)
         value.downcase!
         
         if value == 'true' or value == 'yes' or value == '1'
            return true
         else
            return false
         end 
      end

      return value    
   end

end

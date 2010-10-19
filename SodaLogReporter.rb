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
# Needed Ruby Libs:
###############################################################################
require 'strscan'

###############################################################################
# SodaLogReporter -- Class
#     This is a simple class to take a raw soda report file and turn it into
#     a more readable html report file.
#
# Params:
#     sodalog_file: This is the log file to be used to generate the html.
#     
#     output_file: This is the name of the html report file to create.
#
# Results:
#     None.
#
###############################################################################
class SodaLogReporter

   @SodaLogFile = nil
   @OutPutFile = nil
   @BackTraceID = nil
   @EventDumpID = nil

   def initialize (sodalog_file, output_file)

      if (!File.exist?(sodalog_file))
         raise(ArgumentError, "(!)Can't find file: #{sodalog_file}!\n", caller)
      end

      if (!output_file)
         raise(ArgumentError, "(!)Missing argument: output_file!\n", caller)
      end

      @SodaLogFile = sodalog_file
      @OutPutFile = output_file
      @BackTraceID = 0
      @EventDumpID = 0
   end

###############################################################################
# GenerateHtmlHeader -- Method
#     This function will create the proper html header for the report file that
#     we generate.
#
# Params:
#     title: This is to set the HTML <title>#{title}</title>
#
# Results:
#     returns a string containing HTML code.
#
###############################################################################
   def GenerateHtmlHeader (title = "Soda Test Report:")
      header = <<HTML
<html>
<script language=javascript type='text/javascript'>
function hidediv(name, href_id) {
   document.getElementById(name).style.display = 'none';
   document.getElementById(href_id).innerHTML="[ Expand Backtrace ]<b>+</b>";
   document.getElementById(href_id).href="javascript:showdiv('" + name +
      "', '" + href_id + "')";
}

function showdiv(name, href_id) {
   document.getElementById(name).style.display = 'inline';
   document.getElementById(href_id).innerHTML="[ Collapse Backtrace ]<b>-</b>";
   document.getElementById(href_id).href="javascript:hidediv('" + name +
      "', '" + href_id + "')";
}
</script>

<style type="text/css">
body 
{ 
   margin: 0px;
   font-family: Arial, Verdana, Helvetica, sans-serif;
}

fieldset, table, pre 
{
    margin-bottom:0;
}

p 
{
   margin-top: 0px;
   margin-bottom: 0px;
}

textarea
{
   font-family: Arial,Verdana,Helvetica,sans-serif;
}

td
{
   text-align: left;
   vertical-align: top;
}

.td_msgtype
{
   text-align: center;
   vertical-align: middle;
}

.tr_normal
{
   background: #e5eef3; 
}

.tr_header
{
   background: #a4a4a4;
   font-weight: bold;
}

.tr_module
{
   background: #3c78c8;
}

.tr_error
{
   background: #ff0000;
}

.tr_warning
{
   background: #eeff30;
}

.tr_assert_passed
{
   background: #7ff98a;
}

.highlight {
   background-color: #8888FF;
}

.highlight_report {
   background-color: #5dec6d;
}

table 
{
   background: #ffff;
   border: 1px solid black;
   border-bottom: 1px solid #0000;
   border-right: 1px solid #0000;
   color: #0000;
   padding: 4px;
   font-size: 11px;
}
</style>
<title>#{title}</title>
<body>
<table>
<tr class="tr_header">
   <td nowrap>
   Date Time:
   </td>
   <td nowrap>
   Message Type:
   </td>
   <td>
   Message:
   </td>
</tr>

HTML
      return header
   end


###############################################################################
# SafeHTMLStr -- Method
#     This method makes a string html safe by peforming proper escapes.
#
# Params:
#     str: The string to make safe.
#
# Result:
#     returns a safe html string.
#
###############################################################################
   def SafeHTMLStr(str)
      str = str.gsub("<", "&lt;")
      str = str.gsub(">", "&gt;")
      return str
   end

###############################################################################
# FormatTestResults -- Method
#     This method takes the results log file line and generates a nice and
#     happy html row.
#
# Prams:
#     line: This is the "Soda Test Report" line from the log file.
#
# Results:
#     returns a hash that is the expected format.
#
# Data: Hash format:
#     row_data['date']
#     row_data['msg_type']
#     row_data['msg']
#     row_data['error']
#
###############################################################################
   def FormatTestResults (line)
      row_data = Hash.new()
      table_html = "<table>\n"
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "Results"
      rpt_msg = "#{$3}"
      res_data = rpt_msg.split("--")
      res_data.shift()

      res_data.each do |dline|
         dline_data = dline.split(":")
         if ( (dline_data[1].nil?) || (dline_data[1].empty?) )
            dline_data[1] = ""
         end

         table_html << "<tr class=\"tr_normal\""+
            " \"onMouseOver=\"this.className='highlight_report'\" "+
            "onMouseOut=\"this.className='tr_normal'\">" +
            "\n\t<td><b>#{dline_data[0]}:</b></td>\n"

         case dline_data[0]
            when /test\s+failure\s+count/i
                if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n"
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end               
            when /assert\s+failures/i
               if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n"
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end 
            when /test\s+major\s+exceptions/i
               if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n"
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end
            when /test\s+exceptions/i
               if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n"
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end
            when /test\s+css\s+error\s+count/i
               if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n" 
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end
            when /test\s+javascript\s+error\s+count/i
               if (dline_data[1].to_i() > 0)
                  table_html << "\t<td><font color=\"#FF0000\">" +
                     "<b>#{dline_data[1]}</b>\n\t</td>\n" 
               else
                  table_html << "\t<td><b>#{dline_data[1]}</b>" +
                     "\n\t</td>\n"
               end
            else
               table_html << "\t<td><b>#{dline_data[1]}</b>" +
                  "\n\t</td>\n"
         end

         table_html << "</tr>\n"
      end
      table_html << "\n</table>\n"
      row_data['msg'] = table_html

      return row_data
   end

###############################################################################
# FormatHTMLSavedResults -- Method
#     This method takes the "HTML Saved" line from the Soda log file and 
#     generates a happy html table row from it. 
#
# Params: 
#     line: This is the "HTML Saved" line from the raw soda log file.
#
# Results:
#     returns a hash that is the expected format.
#
# Data: Hash format:
#     row_data['date']
#     row_data['msg_type']
#     row_data['msg']
#
###############################################################################
   def FormatHTMLSavedResults (line)
      row_data = Hash.new()

      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      sav_msg = "#{$3}" 
      sav_msg =~ /^(html\ssaved:\s+)(.*)/i
      base_name = File.basename($2)
      row_data['msg'] = "<b>#{$1}</b>" +
         "<a href=\"#{base_name}\" target=\"_blank\">#{$2}</a>"
   
      return row_data
   end

###############################################################################
# FormatExceptionBT -- Method
#     This method takes a exception bt from the soda log and makes a nicely
#     formatted html table row with it.
#
# Params:
#     line: The bt line from the raw soda log file.
#
# Results:
#     returns a hash that is the expected format.
#
# Data: Hash format:
#     row_data['date']
#     row_data['msg_type']
#     row_data['msg']     
#
###############################################################################
   def FormatExceptionBT (line)
      row_data = Hash.new()
      btid = "bt_div_#{@BackTraceID}"
      href_id = "href_div_#{@BackTraceID}"
      @BackTraceID += 1

      line =~ /(\w+\s+\w+:)/i
      row_data['msg_type'] = "bt"
      row_data['date'] = ""

      row_html = "\t<b>#{$1}</b>" +
         "\t<a id=\"#{href_id}\" href=\"javascript:showdiv('#{btid}',"+
         " '#{href_id}')\">[ Expand Backtrace ]<b>+</b><br>\n" +
         "</a><br>\t<div id=\"#{btid}\" style=\"display: none\">\n"
      
      line.gsub(/(\w+\s+\w+:)/i, "")
      e_data = line.split("--")
      e_data.each do |e|
         row_html << "\t\t#{e}<br>\n"
      end
      row_html << "\t<a href=\"javascript:hidediv('#{btid}', '#{href_id}')\">" +
         "[ Collaspe Backtrace ]<b>-</b></a>\t\t</div>\n\n"
      row_data['msg'] = row_html

      return row_data
   end

###############################################################################
# FormatMajorException -- Method
#  This method takes a major exception line from a raw soda log and craetes
#  a nice happy html row from it.
#
# Params:
#     line: the line from the soda log.
#
# Results:
#     returns a hash of formated html
#
###############################################################################
   def FormatMajorException(line)
      row_data = Hash.new()

      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      msg = "#{$3}"
      msg_data = msg.split("--")
      msg_data[0] = msg_data[0].gsub(/^major\sexception/i, 
            "<b>Major Exception:</b> ")
      msg_data[1] = msg_data[1].gsub(/^exception\smessage:/i,
            "<b>Exception Message:</b>")
      row_data['msg'] = "#{msg_data[0]}</br>#{msg_data[1]}"

      return row_data
   end

###############################################################################
# FormatAssertionFailed -- Method
#     This method takes an assertion failed line from the raw soda log and
#     creates a nice happy html row from it.
#
# Params:
#     line: This is the assertion failed line from the log file.
#
# Results:
#     returns a hash that is the expected format.
#
# Data: Hash format:
#     row_data['date']
#     row_data['msg_type']
#     row_data['msg']     
#    
###############################################################################
   def FormatAssertionFailed (line)
      row_data = Hash.new()
      
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      msg = "#{$3}"
      assert_data = msg.split("--")

      if ( (assert_data[3].nil?) || (assert_data[3].empty?))
         assert_data[3] = "No message found in log file."
      else
         assert_data[3] = assert_data[3].gsub(/^Assertion\s+Message:/i, "") 
      end

       if ( (assert_data[4].nil?) || (assert_data[4].empty?))
         assert_data[4] = "No line number found!"
      end

      url_html = "<a href=\"#{assert_data[1]}\">#{assert_data[1]}</a>"
      row_data['msg'] = "<b>#{assert_data[0]}</b><br>\n" +
         "<b>URL:</b> #{url_html}<br>\n" +
         "<b>Test File:</b> #{assert_data[2]}</br>\n" +
         "<b>Message:</b> #{assert_data[3]}<br>\n" + 
         "<b>Line Number:</b> #{assert_data[4]}<br>\n"

      return row_data
   end

###############################################################################
# FormatAssertionPassed -- Method
#     This method takes an assertion passed line from the raw soda log and
#     creates a nice happy html row from it.
#
# Params:
#     line: This is the assertion passed line from the log file.
#
# Results:
#     returns a hash that is the expected format.
#
# Data: Hash format:
#     row_data['date']
#     row_data['msg_type']
#     row_data['msg']     
#    
###############################################################################
   def FormatAssertionPassed (line)
      row_data = Hash.new()
      
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "AP"
      msg = "#{$3}"
      row_data['msg'] = "#{msg}"

      return row_data
   end

###############################################################################
# FormatEventDump -- Method
#     This method formats a soda event dump log message.
#
# Params:
#     line: This is the soda log line.
#
# Results:
#     returns a hash that is the expected format.
#
###############################################################################
   def FormatEventDump(line)
      ed_id = "ed_div_#{@EventDumpID}"
      href_id = "href_div_ed_#{@EventDumpID}"
      @EventDumpID += 1
      row_data = Hash.new()
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      msg = "#{$3}"
      
      msg =~ /^(.*:)\s+(--.*)/
      msg_data = "#{$2}"
      msg_text = "#{$1}"

      e_data = msg_data.chop()

      row_html = "\t<b>#{msg_text}:</b>" +
         "\t<a id=\"#{href_id}\" href=\"javascript:showdiv('#{ed_id}',"+
         " '#{href_id}')\">[ Expand Event Dump ]<b>+</b><br>\n" +
         "</a><br>\t<div id=\"#{ed_id}\" style=\"display: none\">\n"

      e_data = msg_data.split("--")
      e_data.each do |e|
         row_html << "\t\t#{e}<br>\n"
      end

      row_html << "\t<a href=\"javascript:hidediv('#{ed_id}'" +
      ", '#{href_id}')\">"
         "[ Collaspe Event Dump ]<b>-</b></a>\t\t</div>\n" 

      row_data['msg'] = row_html
      return row_data
   end
  
###############################################################################
# FormatJSError -- Method
#     This method takes a java script soda error line and formats it into
#     html.
#
# Params:
#     line: This is the js error line from a soda log.
#
# Results:
#     returns a hash that is the expected format.
#
###############################################################################
   def FormatJSError(line)
      row_data = Hash.new()
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      msg = "#{$3}"
      row_html = ""

      msg_data = msg.split(/--/)
      msg_data.each do |d|
         info = d.split(/::/)

         if (info.length < 2)
            row_html << "\t<b>#{info[0]}</b><br>\n"
         else
            row_html << "\t<b>#{info[0]}:</b> #{info[1]}<br>\n"
         end
      end

      row_data['msg'] = row_html
      return row_data
   end

###############################################################################
# FormatModuleLine -- Method
#     This method takes a module lines and formats it for html.
#
# Params:
#     line: The raw soda log line.
# 
# Results:
#     returns a hash that is the expected format.
#
###############################################################################
   def FormatModuleLine(type, line)
      row_data = Hash.new()
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "M"
      msg = "#{$3}"
      row_html = ""

      case type
         when /module/i
            msg = msg.gsub(/^module:/i, "<b>Module:</b>")
         when /test/i 
            msg = msg.gsub(/^test:/i, "<b>Test:</b>")
         when /lib/i
            msg = msg.gsub(/^lib:/i, "<b>Lib:</b>")
      end

      row_data['msg'] = msg 

      return row_data
   end

###############################################################################
# FormatReplacingString -- Method
#     This method finds the replace string message and reformats it a little.
#
# Input:
#     line: a soda log file line.
#
# Output:
#     a row_data hash.
#
###############################################################################
   def FormatReplacingString(line)
      row_data = Hash.new()
      msg = ""

      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      
      msg = $3
      data = msg.split(/'*'/)
      data.each do |d|
         next if (d =~ /with/i) || (d =~ /replacing\s+string/i)
         tmp = d
         tmp = Regexp.escape(tmp)
         msg = msg.gsub(/'#{tmp}'/, "<b>'#{d}'</b>")
      end
      
      row_data['msg'] = msg 

      return row_data
   end


###############################################################################
# FormatClickingElement -- Method
#     This method finds the replace string message and reformats it a little.
#
# Input:
#     line: a soda log file line.
#
# Output:
#     a row_data hash.
#
###############################################################################
   def FormatClickingElement(line)
      row_data = {}
      tmp = ""
      line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
      row_data['date'] = "#{$1}"
      row_data['msg_type'] = "#{$2}"
      tmp = "#{$3}"
      tmp = SafeHTMLStr("#{tmp}")
      tmp = tmp.gsub(/\{/, "<b>{")
      tmp = tmp.gsub(/\}/, "}</b>")
      row_data['msg'] = "#{tmp}"

      return row_data
   end

###############################################################################
# GenerateTableRow -- Method
#     This function generates a new html table row from a row log line.
#
# Params:
#     line: This is a line from a raw soda report file.
#
# Results:
#     returns a string of html that is a table row.
#
###############################################################################
   def GenerateTableRow(line)
      row_html = ""
      tr_style = "tr_normal"
      row_data = Hash.new()
      
      case line
         when /assertion:\s+passed/i
            row_data = FormatAssertionPassed(line)
         when /exception\s+backtrace/i
            row_data = FormatExceptionBT(line)
         when /assertion:\s+failed/i 
            row_data = FormatAssertionFailed(line)
         when /soda\s+test\s+report:/i 
            row_data = FormatTestResults(line)
         when /html\s+saved/i
            row_data = FormatHTMLSavedResults(line)
         when /\(E\)/
            row_data = FormatEventDump(line)
         when /major\sexception/i
            row_data = FormatMajorException(line)
         when /javascript\s+error:/i
            row_data = FormatJSError(line)
         when /css\s+error:/i
            row_data = FormatJSError(line)
         when /\(\*\)module:/i
            row_data = FormatModuleLine("module", line)
         when /\(\*\)test:/i
            row_data = FormatModuleLine("test", line)
         when /\(\*\)lib:/i
            row_data = FormatModuleLine("lib", line)
         when /replacing string/i
            row_data = FormatReplacingString(line)
         when /clicking\selement:/i
            row_data = FormatClickingElement(line)
         when /setting\selement:/i
            row_data = FormatClickingElement(line)
         when /expected element:/i
            row_data = FormatClickingElement(line)
         when /element:/i
            row_data = FormatClickingElement(line)
         else
            line =~ /\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\](\(.\))(.*)/
            row_data['date'] = "#{$1}"
            row_data['msg_type'] = "#{$2}"
            row_data['msg'] = SafeHTMLStr("#{$3}")
      end

      row_data['msg_type'] = row_data['msg_type'].gsub("(", "")
      row_data['msg_type'] = row_data['msg_type'].gsub(")", "")

      case row_data['msg_type'].to_s()
         when "!"
            row_data['msg_type'] = "Failure"
            tr_style = "tr_error"
         when "*"
            row_data['msg_type'] = "Log"
         when "W"
            row_data['msg_type'] = "Warning"
            tr_style = "tr_warning"
         when "E"
            row_data['msg_type'] = "Event Dump"
         when "bt"
            row_data['msg_type'] = "BackTrace"
         when "AP"
            row_data['msg_type'] = "Assertion Passed"
            tr_style = "tr_assert_passed"
         when "M"
            row_data['msg_type'] = "Un/Load"
            tr_style = "tr_module"
         else
            row_data['msg_type'] = "Log"
      end

      if ( (row_data['msg'].empty?) && (row_data['date'].empty?) )
         return ""
      end

      row_html = "<tr class=\"#{tr_style}\" "+
         "onMouseOver=\"this.className='highlight'\" " +
         "onMouseOut=\"this.className='#{tr_style}'\">\n" +
         "\t<td>" + row_data['date'] + "</td>\n" +
         "\t<td class=\"td_msgtype\">" + row_data['msg_type'] + "</td>\n" +
         "\t<td>" + row_data['msg'] + "</td>\n</tr>\n"

      return row_html
   end

###############################################################################
# GenerateReport -- Method
#     This function generates an html report file.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def GenerateReport
      html = GenerateHtmlHeader()
      rep_file = File.new(@OutPutFile, "w+")
      rep_file.write(html)
 
      log = File.open(@SodaLogFile, "r")
      log.each do |line|
         line = line.chomp()
         if (line.empty?)
            next
         end

         tmp = GenerateTableRow(line)
         if (!tmp.empty?)
            rep_file.write(tmp)
         end
      end

      rep_file.write("\n</table>\n</body>\n</html>\n")
      rep_file.close()
      log.close()
   end

end


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
require 'getoptlong'
require 'date'

class SodaReportSummery

###############################################################################
# initialize -- constructor
#     This is the class constructor.  Really this does all the needed work.
#
# Params:
#     dir: This is the dorectory with raw soda logs in it.
#     outfile: This is the new summery html file to create.
#     create_links: This will create links to the soda report files in the
#        summery.
#
# Results:
#     Creates a new class and html summery file.  Will raise and exception on
#     any errors.
#
###############################################################################
def initialize(dir ="", outfile = "", create_links = false)
   log_files = nil
   report_data = nil
   result = 0
   html_tmp_file = ""
   timout = true

   if (dir.empty?)
      raise "Empty 'dir' param!\n"
   elsif (outfile.empty?)
      raise "Empty 'outfile param!"
   end

   html_tmp_file = File.dirname(outfile)
   html_tmp_file += "/summery.tmp"

   for i in 0..120
      if (!File.exist?(html_tmp_file))
         timeout = false
         break
      end

      timeout = true
      sleep(1)
   end

#   if (timeout != false)
#      raise "Timed out waiting for lock to be released on file:"+
#         " \"#{html_tmp_file}\"!\n"
#   end

   log_files = GetLogFiles(dir)
   if ( (log_files == nil) || (log_files.length < 1) )
      raise "Failed calling: GetLogFiles(#{dir})!"
   end
   
   report_data = GenerateReportData(log_files)
   if (report_data.length < 1)
      raise "No report data found when calling: GenerateReportData()!"
   end

   result = GenHtmlReport(report_data, html_tmp_file, create_links)
   if (result != 0)
      raise "Failed calling: GenHtmlReport()!"
   end

   File.rename(html_tmp_file, outfile)

end

###############################################################################
# GetLogFiles -- method
#     This function gets all the log files in a given dir puts them in a list.
#
# Params:
#     dir: this is the directory that holds the log files.
#
# Results:
#     returns nil on error, else a list of all the log files in the dir.
#
###############################################################################
def GetLogFiles(dir)
   files = nil

   if (!File.directory?(dir))
      print "(!)Error: #{dir} is not a directory!\n"
      return nil
   end

   files = File.join("#{dir}", "*.log")
   files = Dir.glob(files)
   files = files.sort()
   return files
end

   private :GetLogFiles

###############################################################################
# GenerateReportData -- method
#     This function generates needed data from each file passed in.
#
# Params:
#     files: This is a list of files to read data from.
#
# Results:
#     returns an array of hashed data.
#
###############################################################################
def GenerateReportData(files)
   test_info = []

   files.each do |f|
      line = ""
      hash = Hash.new()
      hash['test_start_time'] = ""
      hash['test_end_time'] = ""
      hash['test_report_line'] = ""
      hash['test_file'] = ""
      hash['log_file'] = "#{f}"
      hash['report_hash'] = nil
      hash['total_tests'] = 0

      print "(*)Opening file: #{f}\n"
      logfd = File.open(f, "r")
      while ( (line = logfd.gets) != nil)
         line = line.chomp()
         case line
            when /\[new\s+test\]/i
               if (!hash['test_start_time'].empty?)
                  next
               end

               line =~ /^\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\]/
               hash['test_start_time'] = "#{$1}"
            when /starting\s+soda\s+test:/i
               if (!hash['test_file'].empty?)
                  next
               end

               data = line.split(/:/)
               test_file = "#{data[data.length() -1]}"
               test_file = test_file.gsub(/^\s+/, "")
               hash['test_file'] = "#{test_file}"
            when /\[end\s+test\]/i
               line =~ /^\[(\d+\/\d+\/\d+-\d+:\d+:\d+)\]/
               hash['test_end_time'] = "#{$1}"
           when /soda\s+test\s+report:/i
               report_hash = Hash.new()
               line = line.gsub(/^(\[\d+\/\d+\/\d+-\d+:\d+:\d+\])\(\*\)/, "")
               line = line.gsub(/^soda\s+test\s+report:/i, "")
               line_data = line.split("--")
               line_data.each do |data|
                  if (data.empty?)
                     next
                  end

                  data = data.split(/:/)
                  data[1] = data[1].gsub(/^\s+/, "")
                  report_hash["#{data[0]}"] = data[1]
               end
               hash['report_hash'] = report_hash
               test_info.push(hash)
         end # end case #
      end
      logfd.close()

   end

   return test_info
end
   private :GenerateReportData

###############################################################################
# GenHtmlReport -- method
#     This function generates an html report from an array of hashed data.
#
# Params:
#     data: An array of hashs
#     reportfile: This is the html file to create.
#
# Results:
#     Creates an html report file.  Retruns -1 on error, else 0 on success.
#
###############################################################################
def GenHtmlReport(data, reportfile, create_links = false)
   fd = nil
   result = 0
   totals = {}
   log_file_td = ""
   report_file = ""
   now = nil

   totals['Test Failure Count'] = 0 
   totals['Test CSS Error Count'] = 0 
   totals['Test JavaScript Error Count'] = 0 
   totals['Test Assert Failures'] = 0 
   totals['Test Event Count'] = 0
   totals['Test Assert Count'] = 0
   totals['Test Exceptions'] = 0
   totals['Test Major Exceptions'] = 0
   totals['Test Count'] = 0
   totals['Test Skip Count'] = 0
   totals['running_time'] = nil

   begin
      fd = File.new(reportfile, "w+")
   rescue Exception => e
      fd = nil
      result = -1
      print "Error: trying to open file!\n"
      print "Exception: #{e.message}\n"
      print "StackTrace: #{e.backtrace.join("\n")}\n"
   ensure
      if (result != 0)
         return -1
      end
   end

   now = Time.now.getlocal() 
   html_header = <<HTML
<html>
<style type="text/css">
body 
{ 
   margin: 0px;
   font-family: Arial, Verdana, Helvetica, sans-serif;
}

a:hover
{
   color: #24f938;
}

fieldset, table, pre 
{
    margin-bottom:0;
}

p 
{
   margin-top: 0px;
   margin-bottom: 0px;
   font-family: Arial, Verdana, Helvetica, sans-serif;
   font-size: 11px;
}

li 
{
   margin-top: 0px;
   margin-bottom: 0px;
   font-family: Arial, Verdana, Helvetica, sans-serif;
   font-size: 11px;
}

td
{
   text-align: center;
   vertical-align: middle;
}

.td_file
{
   text-align: left;
   vertical-align: middle;
   white-space: nowrap;
}

.tr_normal
{
   background: #e5eef3; 
}

.highlight {
   background-color: #8888FF;
}

.tr_header
{
   white-space: nowrap;
   background: #a4a4a4;
   font-weight: bold;
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
<title>Soda Global Report Summery: #{now}</title>
<body>
<li>#{now}</li>
<table>
<tr class="tr_header">
\t<td>Test File:<br>
\tClick link for full report</td>
\t<td>Test Failure Count:</td>
\t<td>CSS Error Count:</td>
\t<td>JavaScript Error Count:</td>
\t<td>Assert Failures:</td>
\t<td>Event Count:</td>
\t<td>Assert Count:</td>
\t<td>Exceptions:</td>
\t<td>Running Time:<br>(hh:mm:ss):</td>
</tr>
HTML

   fd.write(html_header)

   data.each do |rpt|
      totals['Test Failure Count'] += 
         rpt['report_hash']['Test Failure Count'].to_i()
      totals['Test CSS Error Count'] += 
         rpt['report_hash']['Test CSS Error Count'].to_i()
      totals['Test JavaScript Error Count'] += 
         rpt['report_hash']['Test JavaScript Error Count'].to_i()
      totals['Test Assert Failures'] += 
         rpt['report_hash']['Test Assert Failures'].to_i()
      totals['Test Event Count'] += 
         rpt['report_hash']['Test Event Count'].to_i()
      totals['Test Assert Count'] +=
         rpt['report_hash']['Test Assert Count'].to_i()
      totals['Test Exceptions'] += 
         rpt['report_hash']['Test Exceptions'].to_i()
      totals['Test Count'] += rpt['report_hash']['Test Count'].to_i()
      totals['Test Skip Count'] += rpt['report_hash']['Test Skip Count'].to_i()

      start_time = DateTime.strptime("#{rpt['test_start_time']}",
         "%m/%d/%Y-%H:%M:%S")
      stop_time = DateTime.strptime("#{rpt['test_end_time']}",
         "%m/%d/%Y-%H:%M:%S")
      time_diff = stop_time - start_time
            if (totals['running_time'] == nil)
         totals['running_time'] = time_diff
      else
         totals['running_time'] += time_diff
      end
      hours,minutes,seconds,frac = Date.day_fraction_to_time(time_diff)

      rpt['report_hash'].each do |k,v|
         if ( (v.to_i > 0) && (k !~ /test\s+assert\s+count/i) &&
               (k !~ /test\s+event\s+count/i) && 
               (k !~ /css\s+error\s+count/i) &&
               (k !~ /test\s+count/i))
            tmp = '<font color="#FF0000"><b>'
            tmp += "#{v}</b></font>"
            rpt['report_hash'][k] = tmp
         end
      end

      report_file = File.basename(rpt['log_file'], ".log")
      report_file = "Report-#{report_file}.html"

      if (create_links)
         rerun = ""
         if (report_file =~ /-SodaRerun/i)
            rerun = "<b> :Rerun</b>"
         end
         log_file_td = "<a href=\"#{report_file}\">#{rpt['test_file']}</a>"+
            "#{rerun}"
      else
         log_file_td = "#{rpt['test_file']}"
      end

      str = "<tr class=\"tr_normal\" "+
         "onMouseOver=\"this.className='highlight'\" "+
         "onMouseOut=\"this.className='tr_normal'\">\n" +
         "\t<td class=\"td_file\">#{log_file_td}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test Failure Count']}</td>\n"+
         "\t<td>#{rpt['report_hash']['Test CSS Error Count']}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test JavaScript Error Count']}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test Assert Failures']}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test Event Count']}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test Assert Count']}</td>\n" +
         "\t<td>#{rpt['report_hash']['Test Exceptions']}</td>\n" +
         "\t<td>#{hours}:#{minutes}:#{seconds}</td>\n</tr>\n"
         fd.write(str)
   end
 
   hours,minutes,seconds,frac = 
      Date.day_fraction_to_time(totals['running_time'])

   totals.each do |k,v|
      if ( (v.to_i > 0) && (k !~ /test\s+assert\s+count/i) &&
            (k !~ /test\s+event\s+count/i) && 
            (k !~ /css\s+error\s+count/i) &&
            (k !~ /test\s+count/i) )

         tmp = '<font color="#FF0000"><b>'
         tmp += "#{v}</b></font>"
         totals[k] = tmp
      end
   end

   totals['Test Skip Count'] = totals['Test Skip Count'].to_i()
   test_totals = totals['Test Count'] + totals['Test Skip Count']
   sub_totals = "<tr class=\"tr_header\">\n"+
      "\t<td>Totals:</td>\n"+
      "\t<td>#{totals['Test Failure Count']}</td>\n"+
      "\t<td>#{totals['Test CSS Error Count']}</td>\n"+
      "\t<td>#{totals['Test JavaScript Error Count']}</td>\n"+
      "\t<td>#{totals['Test Assert Failures']}</td>\n"+
      "\t<td>#{totals['Test Event Count']}</td>\n"+
      "\t<td>#{totals['Test Assert Count']}</td>\n"+
      "\t<td>#{totals['Test Exceptions']}</td>\n"+
      "\t<td>#{hours}:#{minutes}:#{seconds}</td>\n"+
      "</tr>\n"
#      "<tr class=\"tr_header\">\n"+
#      "\t<td>Total Test Count:</td>\n"+
#      "\t<td colspan=\"2\">#{test_totals}</td>\n</tr>\n"

   fd.write(sub_totals)
   fd.write("</table>\n</body>\n</html>\n")
   fd.close()

   return result

end
   private :GenHtmlReport

end



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
require 'rubygems'
require 'getoptlong'
require 'date'
require 'libxml'
require 'pp'
require 'SodaReportSummery'

class SodaSuiteSummary

###############################################################################
# initialize -- constructor
#     This is the class constructor.  Really this does all the needed work.
#
# Params:
#     dir: This is the directory with raw soda logs in it.
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

#  This should go back into production after moving away from our
#  internal nfs sever we are using for reporting...
#
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

   files = File.join("#{dir}", "*.xml")
   files = Dir.glob(files).sort_by{|f| File.stat(f).mtime}

   return files
end

   private :GetLogFiles

###############################################################################
# GetTestInfo -- method
#     This method reads the suite xml report and converts it into a hash.
#
# Input:
#     kids: The XML node for the <test> element.
#
# Output:
#     returns a hash of data.
#
###############################################################################
def GetTestInfo(kids)
   test_info = {}

   kids.each do |kid|
      next if (kid.name =~ /text/i)
      name = kid.name
      name = name.gsub("_", " ")
      test_info[name] = kid.content()
   end

   return test_info
end

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
   test_info = {}
   test_info_list = []

   files.each do |f|
      print "(*)Opening file: #{f}\n"

      begin
         parser = LibXML::XML::Parser.file(f)
         LibXML::XML::Error.set_handler(&LibXML::XML::Error::QUIET_HANDLER)
         doc = parser.parse()
      rescue Exception => e
         print "(!)Error: Failed trying to parse XML file: '#{f}'!\n"
         print "--)Exception: #{e.message}\n"
         print "--)Skipping file!\n"
         next
      ensure
      end

      suites = []
      doc.root.each do |suite|
         next if (suite.name !~ /suite/)
         suites.push(suite)
      end

      suites.each do |suite|
         tmp_hash = {'tests' => []}
         suite.children.each do |kid|
            case (kid.name)
               when "suitefile"
                  tmp_hash['suitefile'] = kid.content()
               when "test"
                  tmp_test_data = GetTestInfo(kid.children)
                  tmp_hash['tests'].push(tmp_test_data)
            end # end case #
         end
         
         base_name = File.basename(tmp_hash['suitefile'])
         test_info[base_name] = tmp_hash
         test_info_list.push(tmp_hash)
      end
   end

   return test_info
end

   private :GenerateReportData

###############################################################################
# GenHtmlReport -- method
#     This function generates an html report from an array of hashed data.
#
# Params:
#     data: A hash of suites, and their test info.
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
   suite_totals = {}
   total_failure_count = 0
   total_non_ran_count = 0

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

.highlight {
   background-color: #8888FF;
}

.unhighlight {
   background: #FFFFFF;
}

.td_header_master {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_header_sub {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 1px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_header_skipped {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 1px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_header_watchdog {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

table {
   width: 100%;
   border: 2px solid black;
   border-collapse: collapse;
   padding: 0px;
   background: #FFFFFF;
}

.td_file_data {
   whitw-space: nowrap;
   text-align: left;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_run_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_run_data_error {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_passed_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #00FF00;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_failed_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_blocked_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FFCF10;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_skipped_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #D9D9D9;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}

.td_watchdog_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_watchdog_error_data {
   whitw-space: nowrap;
   color: #FF0000;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_exceptions_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_exceptions_error_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_javascript_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_javascript_error_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_assert_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_assert_error_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_other_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_other_error_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_total_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}

.td_total_error_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}

.td_css_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}

.td_sodawarnings_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}

.td_time_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 1px solid black;
   border-bottom: 0px solid black;
}

.td_footer_run {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #000000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_footer_passed {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #00FF00;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_failed {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_footer_blocked {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FFCF10;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_skipped {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #D9D9D9;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_footer_watchdog {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_exceptions {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_javascript {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_assert {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_other {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_total {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF0000;
   border-top: 2px solid black;
   border-left: 2px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}

.td_footer_css {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #000000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_sodawarnings {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #000000;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}

.td_footer_times {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #000000;
   border-top: 2px solid black;
   border-left: 2px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
</style>
<body>
<table>
<tr>
   <td class="td_header_master" rowspan="2">Suite</br>
   (click link for full report)</td>
   <td class="td_header_master" colspan="5">Tests</td>
   <td class="td_header_master" colspan="6">Failures</td>
   <td class="td_header_master" colspan="2">Warnings</td>
   <td class="td_header_master" rowspan="2">Run Time</br>(hh:mm:ss)</td>
</tr>
<tr>
   <td class="td_header_sub">Run</td>
   <td class="td_header_sub">Passed</td>
   <td class="td_header_sub">Failed</td>
   <td class="td_header_sub">Blocked</td>
   <td class="td_header_skipped">Skipped</td>
   <td class="td_header_watchdog">Watchdogs</td>
   <td class="td_header_sub">Exceptions</td>
   <td class="td_header_sub">JavaScript</br>Errors</td>
   <td class="td_header_sub">Assert</br>Failures</td>
   <td class="td_header_sub">Other</br>Failures</td>
   <td class="td_header_skipped">Total</br>Failures</td>
   <td class="td_header_watchdog">CSS Errors</td>
   <td class="td_header_skipped">Soda</br>Warnings</td>  
</tr>
HTML

   fd.write(html_header)

   data.each do |suite, suite_hash|
      totals[suite] = Hash.new()
      totals[suite]['Test Failure Count'] = 0
      totals[suite]['Test Passed Count'] = 0
      totals[suite]['Total Time'] = nil

      suite_hash.each do |k, v|
         next if (k !~ /tests/)
         totals[suite]['Test Count'] = v.length()

         v.each do |test|
            time_set = false
            if (test['result'].to_i != 0)
               totals[suite]['Test Failure Count'] += 1
               total_failure_count += 1
            else
               totals[suite]['Test Passed Count'] += 1
            end

            if (!time_set)
               time_set = true
               stop = test['Test Stop Time']
               start = DateTime.strptime("#{test['Test Start Time']}",
                  "%m/%d/%Y-%H:%M:%S")
               stop = DateTime.strptime("#{test['Test Stop Time']}",
                  "%m/%d/%Y-%H:%M:%S")

               diff = (stop - start)
               if (totals[suite]['Total Time'] == nil)
                  totals[suite]['Total Time'] = diff
               else
                  totals[suite]['Total Time'] += diff
               end
            end

            test.each do |test_k, test_v|
               if (!totals[suite].key?(test_k))
                  totals[suite][test_k] = 0
               else
                  totals[suite][test_k] += test_v.to_i if (test_k !~ /time/i)
               end
            end   
         end
      end
   end
     
   totals.each do |suite, suite_hash|
      suite_hash.each do |k, v|
         if (!suite_totals.key?(k))
            suite_totals[k] = 0
         end

         if (k =~ /Total Time/)
            suite_totals[k] += v
         else
            suite_totals[k] += v.to_i()
         end
      end
   end

   row_id = 0
   totals.each do |suite_name, suite_hash|
      next if (suite_name =~ /Total\sFailure\sCount/i)
      row_id += 1
      report_file = "#{suite_name}"
      hours,minutes,seconds,frac = 
         Date.day_fraction_to_time(suite_hash['Total Time'])
      
      if (hours < 10)
         hours = "0#{hours}"
      end

      if (minutes < 10)
         minutes = "0#{minutes}"
      end

      if (seconds < 10)
         seconds = "0#{seconds}"
      end

      suite_hash['Test Other Failures'] = 0

      test_run_class = "td_run_data"
      if (suite_hash['Test Assert Failures'] > 0 ||
          suite_hash['Test Exceptions'] > 0)
         test_run_class = "td_run_data_error"
      end

      exceptions_td = "td_exceptions_data"
      if (suite_hash['Test Exceptions'] > 0)
         exceptions_td = "td_exceptions_error_data"
      end

      asserts_td = "td_assert_data"
      if (suite_hash['Test Assert Failures'] > 0)
         asserts_td = "td_assert_error_data"
      end

      watchdog_td = "td_watchdog_data"
      if (suite_hash['Test WatchDog Count'] > 0)
         watchdog_td = "td_watchdog_error_data"
      end

      jscript_td = "td_javascript_data"
      if (suite_hash['Test JavaScript Error Count'] > 0)
         jscript_td = "td_javascript_error_data"
      end

      t_passedcount = suite_hash['Test Count']
      t_passedcount -= suite_hash['Test Failure Count']
      total_failures = 0
#     total_failures += suite_hash['Test Failure Count']
      total_failures += suite_hash['Test WatchDog Count']
      total_failures += suite_hash['Test Assert Failures']
      total_failures += suite_hash['Test Other Failures']
      total_failures += suite_hash['Test JavaScript Error Count']
#      total_failure_count += total_failures

      ran_count = suite_hash['Test Count'].to_i()
      ran_count -= suite_hash['Test WatchDog Count']
      ran_count -= suite_hash['Test Blocked Count']

      total_non_ran_count += suite_hash['Test WatchDog Count']
      total_non_ran_count += suite_hash['Test Blocked Count']

      reportdir = File.dirname(reportfile)
      suite_mini_file = GenSuiteMiniSummary(data[suite_name], reportdir)

      str = "<tr id=\"#{row_id}\" class=\"unhighlight\" "+
         "onMouseOver=\"this.className='highlight'\" "+
         "onMouseOut=\"this.className='unhighlight'\">\n"+
         "\t<td class=\"td_file_data\"><a href=\"#{suite_mini_file}\">"+
         "#{suite_name}</a></td>\n"+
         "\t<td class=\"#{test_run_class}\">"+
            "#{ran_count}/#{suite_hash['Test Count']}</td>\n"+
         "\t<td class=\"td_passed_data\">"+
            "#{suite_hash['Test Passed Count']}</td>\n"+
         "\t<td class=\"td_failed_data\">"+
            "#{suite_hash['Test Failure Count']}</td>\n"+
         "\t<td class=\"td_blocked_data\">"+
            "#{suite_hash['Test Blocked Count']}</td>\n"+
         "\t<td class=\"td_skipped_data\">"+
            "#{suite_hash['Test Skip Count']}</td>\n"+
         "\t<td class=\"#{watchdog_td}\">"+
            "#{suite_hash['Test WatchDog Count']}</td>\n"+
         "\t<td class=\"#{exceptions_td}\">"+
            "#{suite_hash['Test Exceptions']}</td>\n"+
         "\t<td class=\"#{jscript_td}\">"+
            "#{suite_hash['Test JavaScript Error Count']}</td>\n"+
         "\t<td class=\"#{asserts_td}\">"+
            "#{suite_hash['Test Assert Failures']}</td>\n"+
         "\t<td class=\"td_other_data\">"+
            "0</td>\n"+
         "\t<td class=\"td_total_data\">#{total_failures}</td>\n"+
         "\t<td class=\"td_css_data\">"+
            "#{suite_hash['Test CSS Error Count']}</td>\n"+
         "\t<td class=\"td_sodawarnings_data\">"+
            "#{suite_hash['Test Warning Count']}</td>\n"+
         "\t<td class=\"td_time_data\">"+
            "#{hours}:#{minutes}:#{seconds}</td>\n</tr>\n"
      fd.write(str)
   end

   test_totals = suite_totals['Test Count'] 
   test_totals += suite_totals['Test Skip Count']
   test_totals += suite_totals['Test Blocked Count']

   hours,minutes,seconds,frac = 
      Date.day_fraction_to_time(suite_totals['Total Time'])
   if (hours < 10)
      hours = "0#{hours}"
   end

   if (minutes < 10)
      minutes = "0#{minutes}"
   end

   if (seconds < 10)
      seconds = "0#{seconds}"
   end

   sub_totals = "<tr id=\"totals\">\n"+
      "\t<td class=\"td_header_master\">Totals:</td>\n"+
      "\t<td class=\"td_footer_run\">#{suite_totals['Test Count']}"+
         "/#{test_totals}</td>\n"+
      "\t<td class=\"td_footer_passed\">#{suite_totals['Test Passed Count']}"+
         "</td>\n"+
      "\t<td class=\"td_footer_failed\">"+
         "#{suite_totals['Test Failure Count']}</td>\n"+ 
      "\t<td class=\"td_footer_blocked\">"+
         "#{suite_totals['Test Blocked Count']}</td>\n"+ 
      "\t<td class=\"td_footer_skipped\">"+
         "#{suite_totals['Test Skip Count']}</td>\n"+ 
      "\t<td class=\"td_footer_watchdog\">"+
         "#{suite_totals['Test WatchDog Count']}</td>\n"+   
      "\t<td class=\"td_footer_exceptions\">"+
         "#{suite_totals['Test Exceptions']}</td>\n"+
      "\t<td class=\"td_footer_javascript\">"+
         "#{suite_totals['Test JavaScript Error Count']}</td>\n"+
      "\t<td class=\"td_footer_assert\">"+
         "#{suite_totals['Test Assert Failures']}</td>\n"+
      "\t<td class=\"td_footer_other\">0</td>\n"+
      "\t<td class=\"td_footer_total\">"+
         "#{total_failure_count}</td>\n"+
      "\t<td class=\"td_footer_css\">"+
         "#{suite_totals['Test CSS Error Count']}</td>\n"+
      "\t<td class=\"td_footer_sodawarnings\">"+
         "#{suite_totals['Test Warning Count']}</td>\n"+
      "\t<td class=\"td_footer_times\">"+
         "#{hours}:#{minutes}:#{seconds}</td>\n"+
      "</tr>\n"
   fd.write(sub_totals)
   fd.write("</table>\n</body>\n</html>\n")
   fd.close()

   return 0

end
   private :GenHtmlReport

def GenSuiteMiniSummary(suite_hash, reportdir)
   suite_file = suite_hash['suitefile']
   suite_file = File.basename(suite_file, ".xml")
   suite_name = "#{suite_file}"
   suite_file << ".html"
   href = "#{suite_name}/#{suite_file}"
   suite_file = "#{reportdir}/#{suite_name}/#{suite_file}"

   html = <<HTML
<html>
<style type="text/css">
table {
   width: 100%;
   border: 2px solid black;
   border-collapse: collapse;
   padding: 0px;
   background: #FFFFFF;
}
.td_header_master {
   whitw-space: nowrap;
   background: #99CCFF;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_file_data {
   whitw-space: nowrap;
   text-align: left;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_passed_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #00FF00;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_failed_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_report_data {
   whitw-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 2px solid black;
   border-right: 1px solid black;
   border-bottom: 2px solid black;
}
.highlight {
   background-color: #8888FF;
}
.tr_normal {
   background-color: #FFFFFF;
}
</style>
<body>
<table id="tests">
<tr id="header">
   <td class="td_header_master" colspan="3">
   Suite: #{suite_hash['suitefile']} Test Results
   </td>
</tr>
<tr id="header_key">
   <td class="td_header_master">Test File</td>
   <td class="td_header_master">Status</td>
   <td class="td_header_master">Report Log</td>
</tr>
HTML

   fd = File.new(suite_file, "w+")
   fd.write(html)
   id = 0

   tr_css = "onMouseOver=\"this.className='highlight'\""+
      " onMouseOut=\"this.className='tr_normal'\" class=\"tr_normal\""

   suite_hash['tests'].sort_by { |h| h['Test Log File'] }.each do |test|
      id += 1
      test_report = test['Test Log File']
      test_report = File.basename(test_report, ".log")
      test_report = "Report-#{test_report}.html"

      str = "<tr id=\"#{id}\" #{tr_css} >\n"+
      "\t<td class=\"td_file_data\">#{test['testfile']}</td>\n"

      if (test['result'].to_i != 0)
         str << "\t<td class=\"td_failed_data\">Failed</td>\n"
      else
         str << "\t<td class=\"td_passed_data\">Passed</td>\n"
      end

      str << "\t<td class=\"td_report_data\">"
      str << "<a href=\"#{test_report}\">Report Log</a></td>\n"
      str << "</tr>\n"
      fd.write(str)
   end

   fd.write("</table>\n</body>\n</html>\n")
   fd.close()

   return href
end

end



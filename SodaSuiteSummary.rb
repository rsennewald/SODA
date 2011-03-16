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

$HTML_HEADER = <<HTML
<html>
<style type="text/css">
body {
   background: #e5eef3;
}
.highlight {
   background-color: #8888FF;
}
.unhighlight {
   background: #e5eef3;
}
.td_header_master {
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_header_sub {
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 1px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_header_skipped {
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 1px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_header_watchdog {
   white-space: nowrap;
   background: #b6dde8;
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
.td_failed_suite {
   white-space: nowrap;
   text-align: left;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 1px solid black;
   border-right: 1px solid black;
   border-bottom: 1px solid black;
   background-color: #fde9d9;
}
.td_file_data {
   white-space: nowrap;
   text-align: left;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_run_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_run_data_error {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #00cc00;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_failed_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_failed_data_zero {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   color: #000000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
._data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FFCF10;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_blocked_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF8200;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}
.td_blocked_data_zero {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   color: #000000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}
.td_watchdog_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_watchdog_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_exceptions_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_javascript_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_assert_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_other_error_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
   color: #FF0000;
}
.td_other_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}
.td_total_error_data {
   white-space: nowrap;
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
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 0px solid black;
}
.td_sodawarnings_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   color: #FF8200;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}
.td_sodawarnings_data_zero {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 0px solid black;
}
.td_time_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 1px solid black;
   border-bottom: 0px solid black;
}
.td_footer_run {
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #00cc00;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_footer_failed {
   white-space: nowrap;
   background: #b6dde8;
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
.td_footer_skipped {
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   color: #FF8200;
   border-top: 2px solid black;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_footer_watchdog {
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   white-space: nowrap;
   background: #b6dde8;
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
   <td class="td_header_master" colspan="4">Tests</td>
   <td class="td_header_master" colspan="6">Failures</td>
   <td class="td_header_master" colspan="2">Warnings</td>
   <td class="td_header_master" rowspan="2">Run Time</br>(hh:mm:ss)</td>
</tr>
<tr>
   <td class="td_header_sub">Run</td>
   <td class="td_header_sub">Passed</td>
   <td class="td_header_sub">Failed</td>
   <td class="td_header_skipped">Blocked</td>
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

   log_files = GetLogFiles(dir)
   if ( (log_files == nil) || (log_files.length < 1) )
      raise "Error: No log files found in directory: '#{dir}'!"
   end
   
   report_data = GenerateReportData(log_files)
   if (report_data.length < 1)
      raise "No report data found when calling: GenerateReportData()!"
   end

   result = GenHtmlReport2(report_data, html_tmp_file, create_links)
   if (result != 0)
      raise "Failed calling: GenHtmlReport2()!"
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
      print "(*)Reading XML file: #{f}\n"

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
               else
                  tmp_hash[kid.name] = kid.content()
            end # end case #
         end
         
         base_name = File.basename(tmp_hash['suitefile'])
         test_info[base_name] = tmp_hash
         test_info_list.push(tmp_hash)
      end

      print "(*)Finished.\n"
   end

   return test_info
end
   private :GenerateReportData


def SumSuiteTests(tests, suitename)
   lib_file_count = 0
   report = {
      'Total Time' => nil
   }
   summary_int_fields = [
      'Test JavaScript Error Count',
      'Test WatchDog Count',
      'Test Assert Failures',
      'Test CSS Error Count',
      'Test Blocked Count',
      'Test Assert Count',
      'Test Warning Count',
      'Test Skip Count',
      'Test Event Count',
      'Test Exceptions',
      'Test Pass Count',
      'Test Failed Count',
      'Test Ran Count',
      'Test Failure Count'
      ]

   print "(*)Summing #{suitename}..."

   # zero out all of the int keys, and make sure they are int's and not
   # strings.
   summary_int_fields.each do |key|
      report[key] = 0
   end

   tests.sort_by{|h| h['Test Order'].to_i}.each do |test|
      dir_name = File.dirname(test['testfile'])
      if (dir_name =~ /lib/i) 
         lib_file_count += 1
      else
         report['Test Ran Count'] += 1
      end

      summary_int_fields.each do |total_field|
         report[total_field] += test[total_field].to_i()   
      end
      
      if (dir_name !~ /lib/i)
         # count tests that pass and fail. #
         if (test['result'].to_i != 0)
            report['Test Failed Count'] += 1
         else
            report['Test Pass Count'] += 1
         end
      end

      # add up times #
      stop_time = test['Test Stop Time']
      start_time = DateTime.strptime("#{test['Test Start Time']}",
         "%m/%d/%Y-%H:%M:%S")
      stop_time = DateTime.strptime("#{test['Test Stop Time']}",
         "%m/%d/%Y-%H:%M:%S")

      diff = (stop_time - start_time)
      if (report['Total Time'] == nil)
         report['Total Time'] = diff
      else
         report['Total Time'] += diff
      end
   end

   # need to do away with tests that did not run for a good reason #
   report['Test Ran Count'] -= report['Test Blocked Count']
#   report['Test Ran Count'] -= report['Test Skip Count']
   report['Test Pass Count'] -= report['Test Blocked Count']
   report['Total Test Count'] = tests.length()

   if (lib_file_count > 0)
      report['Total Test Count'] -= lib_file_count
   end 

   print ":Done.\n"

   return report
end

###############################################################################
# GenHtmlReport2 -- method
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
def GenHtmlReport2(data, reportfile, create_links = false)
   suites_totals = {}
   summary_totals = {}
   suite_errors = []
   row_id = 0

   print "(*)Processing data...\n"

   # first sum up all of the test results for each suite #
   suites = data.keys.sort()
   suites.each do |suite_name|
      if (!data[suite_name].key?("Suite_Failure"))
         suites_totals[suite_name] = {} # new suite name for the totals #
         suite_data = data[suite_name]
         suites_totals[suite_name] = SumSuiteTests(suite_data['tests'], 
            suite_name)
      else
         suite_errors.push(data[suite_name])
      end
   end 

   # second sum up all of the suite sums for the totals for the summary #
   suites_totals.keys.each do |suite_name|
      suite_data = suites_totals[suite_name]
      suite_data.each do |suite_key, suite_val|
         # make sure it is set to an int if it doesn't exist #
         if (suite_key !~ /time/i && !summary_totals.key?(suite_key))
            summary_totals[suite_key] = 0
         end

         if (suite_key =~ /time/i && !summary_totals.key?(suite_key)) 
            summary_totals[suite_key] = suite_val
         else
            # we can see a nil time if the suite only ran modules, and not
            # any tests.  Once again this is because david doesn't want reports
            # on modules....  Lame... Lame...
            summary_totals[suite_key] += suite_val if (suite_val != nil)
         end
      end
   end

   # create a new summary file # 
   fd = File.new(reportfile, "w+")
   fd.write($HTML_HEADER)

   print "(*)Processing suite errors...\n"
   suite_errors.sort_by{|hash| hash['suitefile']}.each do |e_suite|
      row_id += 1

      str = "<tr id=\"#{row_id}\" class=\"unhighlight\" "+
         "onMouseOver=\"this.className='highlight'\" "+
         "onMouseOut=\"this.className='unhighlight'\">\n"+
         "\t<td class=\"td_file_data\">"+
         "#{e_suite['suitefile']}</td>\n"+
         "\t<td colspan=\"13\" class=\"td_failed_suite\">"+
         "#{e_suite['Suite_Error']}</td>\n"+
        "</tr>\n"
      fd.write(str)
   end
   print "(*)Finished.\n"
 
   suites_totals.sort.each do |suite_name, suite_data|
      row_id += 1
      report_file = "#{suite_name}"

      # again another hack to avoid lib files in the reports... #
      if (suite_data['Total Time'] != nil)
         hours,minutes,seconds,frac = 
            Date.day_fraction_to_time(suite_data['Total Time'])
        
         if (hours < 10)
            hours = "0#{hours}"
         end

         if (minutes < 10)
            minutes = "0#{minutes}"
         end

         if (seconds < 10)
            seconds = "0#{seconds}"
         end
      else
         hours = 0
         minutes = 0
         seconds = 0
      end

      exceptions_td = "td_exceptions_data"
      if (suite_data['Test Exceptions'] > 0)
         exceptions_td = "td_exceptions_error_data"
      end

      asserts_td = "td_assert_data"
      if (suite_data['Test Assert Failures'] > 0)
         asserts_td = "td_assert_error_data"
      end

      watchdog_td = "td_watchdog_data"
      if (suite_data['Test WatchDog Count'] > 0)
         watchdog_td = "td_watchdog_error_data"
      end

      jscript_td = "td_javascript_data"
      if (suite_data['Test JavaScript Error Count'] > 0)
         jscript_td = "td_javascript_error_data"
      end

      other_td = "td_other_data"
      if (suite_data['Test Failure Count'] > 0)
         other_td = "td_other_error_data"
      end

      total_failures = 0
      total_failures += suite_data['Test Failure Count']
      total_failures += suite_data['Test Exceptions']
      total_failures += suite_data['Test Assert Failures']
      total_failures += suite_data['Test JavaScript Error Count']

      total_failures_td = "td_total_data"
      if (total_failures > 0)
         total_failures_td = "td_total_error_data"
      end

      test_run_class = "td_run_data"
      if (suite_data['Test Ran Count'] != suite_data['Total Test Count'])
         test_run_class = "td_run_data_error"
      end

      td_failed = "td_failed_data_zero"
      if (suite_data['Test Failed Count'].to_i > 0)
         td_failed = "td_failed_data"
      end

      td_blocked = "td_blocked_data_zero"
      if (suite_data['Test Blocked Count'].to_i > 0)
         td_blocked = "td_blocked_data"
      end

      td_warnings = "td_sodawarnings_data_zero"
      if (suite_data['Test Warning Count'].to_i > 0)
         td_warnings = "td_sodawarnings_data"
      end

      reportdir = File.dirname(reportfile)
      suite_mini_file = GenSuiteMiniSummary(data[suite_name], reportdir)

      str = "<tr id=\"#{row_id}\" class=\"unhighlight\" "+
         "onMouseOver=\"this.className='highlight'\" "+
         "onMouseOut=\"this.className='unhighlight'\">\n"+
         "\t<td class=\"td_file_data\"><a href=\"#{suite_mini_file}\">"+
         "#{suite_name}</a></td>\n"+
         "\t<td class=\"#{test_run_class}\">"+
         "#{suite_data['Test Ran Count']}/"+
         "#{suite_data['Total Test Count']}</td>\n"+
         "\t<td class=\"td_passed_data\">"+
            "#{suite_data['Test Pass Count']}</td>\n"+
         "\t<td class=\"#{td_failed}\">"+
            "#{suite_data['Test Failed Count']}</td>\n"+
         "\t<td class=\"#{td_blocked}\">"+
            "#{suite_data['Test Blocked Count']}</td>\n"+
         "\t<td class=\"#{watchdog_td}\">"+
            "#{suite_data['Test WatchDog Count']}</td>\n"+
         "\t<td class=\"#{exceptions_td}\">"+
            "#{suite_data['Test Exceptions']}</td>\n"+
         "\t<td class=\"#{jscript_td}\">"+
            "#{suite_data['Test JavaScript Error Count']}</td>\n"+
         "\t<td class=\"#{asserts_td}\">"+
            "#{suite_data['Test Assert Failures']}</td>\n"+
         "\t<td class=\"#{other_td}\">"+
            "#{suite_data['Test Failure Count']}</td>\n"+
         "\t<td class=\"#{total_failures_td}\">#{total_failures}</td>\n"+
         "\t<td class=\"td_css_data\">"+
            "#{suite_data['Test CSS Error Count']}</td>\n"+
         "\t<td class=\"#{td_warnings}\">"+
            "#{suite_data['Test Warning Count']}</td>\n"+
         "\t<td class=\"td_time_data\">"+
            "#{hours}:#{minutes}:#{seconds}</td>\n</tr>\n"
      fd.write(str)
   end # end suites_totals loop #

   if (summary_totals['Total Time'] != nil)
      hours,minutes,seconds,frac = 
         Date.day_fraction_to_time(summary_totals['Total Time'])
   else
      hours = 0
      minutes = 0
      seconds = 0
   end

   if (hours < 10)
      hours = "0#{hours}"
   end

   if (minutes < 10)
      minutes = "0#{minutes}"
   end

   if (seconds < 10)
      seconds = "0#{seconds}"
   end

   test_totals = summary_totals['Total Test Count'] 
   test_totals += summary_totals['Test Skip Count']
   test_totals += summary_totals['Test Blocked Count']

   total_failures = 0
   total_failures += summary_totals['Test Failure Count']
   total_failures += summary_totals['Test Exceptions']
   total_failures += summary_totals['Test Assert Failures']
   total_failures += summary_totals['Test JavaScript Error Count']

   sub_totals = "<tr id=\"totals\">\n"+
      "\t<td class=\"td_header_master\">Totals:</td>\n"+
      "\t<td class=\"td_footer_run\">#{summary_totals['Total Test Count']}"+
         "/#{test_totals}</td>\n"+
      "\t<td class=\"td_footer_passed\">#{summary_totals['Test Pass Count']}"+
         "</td>\n"+
      "\t<td class=\"td_footer_failed\">"+
         "#{summary_totals['Test Failed Count']}</td>\n"+ 
      "\t<td class=\"td_footer_skipped\">"+
         "#{summary_totals['Test Blocked Count']}</td>\n"+ 
      "\t<td class=\"td_footer_watchdog\">"+
         "#{summary_totals['Test WatchDog Count']}</td>\n"+   
      "\t<td class=\"td_footer_exceptions\">"+
         "#{summary_totals['Test Exceptions']}</td>\n"+
      "\t<td class=\"td_footer_javascript\">"+
         "#{summary_totals['Test JavaScript Error Count']}</td>\n"+
      "\t<td class=\"td_footer_assert\">"+
         "#{summary_totals['Test Assert Failures']}</td>\n"+
      "\t<td class=\"td_footer_other\">"+
         "#{summary_totals['Test Failure Count']}</td>\n"+
      "\t<td class=\"td_footer_total\">"+
         "#{total_failures}</td>\n"+
      "\t<td class=\"td_footer_css\">"+
         "#{summary_totals['Test CSS Error Count']}</td>\n"+
      "\t<td class=\"td_footer_sodawarnings\">"+
         "#{summary_totals['Test Warning Count']}</td>\n"+
      "\t<td class=\"td_footer_times\">"+
         "#{hours}:#{minutes}:#{seconds}</td>\n"+
      "</tr>\n"
   fd.write(sub_totals)
   fd.write("</table>\n</body>\n</html>\n")
   fd.close()

   print "(*)Processing finished.\n"

   return 0
end
   private :GenHtmlReport2


def GenSuiteMiniSummary(suite_hash, reportdir)
   suite_file = suite_hash['suitefile']
   suite_dup_id = nil

   if (suite_file =~ /\.xml(-\d+)/i)
      suite_dup_id = "#{$1}"
      suite_file = suite_file.gsub(/\.xml#{$1}/, ".xml")
   end

   suite_file = File.basename(suite_file, ".xml")
   suite_name = "#{suite_file}"

   if (suite_dup_id != nil)
      suite_file << "#{suite_dup_id}"
   end

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
   white-space: nowrap;
   background: #b6dde8;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_file_data {
   white-space: nowrap;
   text-align: left;
   font-family: Arial;
   font-weight: bold;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 2px solid black;
   border-bottom: 2px solid black;
}
.td_passed_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #00cc00;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
._data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FFCF10;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_failed_data {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: bold;
   color: #FF0000;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_failed_data_zero {
   white-space: nowrap;
   text-align: center;
   font-family: Arial;
   font-weight: normal;
   color: #FFFFFF;
   font-size: 12px;
   border-left: 0px solid black;
   border-right: 0px solid black;
   border-bottom: 2px solid black;
}
.td_report_data {
   white-space: nowrap;
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
   background-color: #e5eef3;
}
</style>
<body>
<table id="tests">
<tr id="header">
   <td class="td_header_master" colspan="4">
   Suite: #{suite_hash['suitefile']} Test Results
   </td>
</tr>
<tr id="header_key">
   <td class="td_header_master"></td>
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

   suite_hash['tests'].sort_by { |h| h['Test Order'].to_i }.each do |test|
      id += 1
      result_str = ""
      test_report = test['Test Log File']
      test_report = File.basename(test_report, ".log")
      test_report = "Report-#{test_report}.html"

      str = "<tr id=\"#{id}\" #{tr_css} >\n"+
      "\t<td class=\"td_file_data\">#{id}</td>\n"+
      "\t<td class=\"td_file_data\">#{test['testfile']}</td>\n"

      if (test['result'].to_i != 0)
         result_str = "\t<td class=\"td_failed_data\">Failed</td>\n"
      else
         result_str = "\t<td class=\"td_passed_data\">Passed</td>\n"
      end

      # hack #
      if (test['Test Blocked Count'].to_i > 0)
         result_str = "\t<td class=\"_data\">Blocked</td>\n"
      end

      str << "#{result_str}"
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



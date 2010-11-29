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

	totals['Test Warning Count'] = 0
	totals['Test Other Failures'] = 0
	totals['Test WatchDog Count'] = 0
   totals['Test Failure Count'] = 0 
	totals['Test Passed Count'] = 0
   totals['Test CSS Error Count'] = 0 
   totals['Test JavaScript Error Count'] = 0 
   totals['Test Assert Failures'] = 0 
   totals['Test Event Count'] = 0
   totals['Test Assert Count'] = 0
   totals['Test Exceptions'] = 0
   totals['Test Major Exceptions'] = 0
   totals['Test Count'] = 0
   totals['Test Skip Count'] = 0
	totals['Test Blocked Count'] = 0
	totals['Total Failure Count'] = 0
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

   data.each do |rpt|
		totals['Test Warning Count'] +=
			rpt['report_hash']['Test Warning Count'].to_i()
		totals['Test Other Failures'] +=
			rpt['report_hash']['Test Other Failures'].to_i()
		totals['Test WatchDog Count'] +=
			rpt['report_hash']['Test WatchDog Count'].to_i()
		totals['Test Blocked Count'] +=
			rpt['report_hash']['Test Blocked Count'].to_i()
		totals['Test Passed Count'] += 
			rpt['report_hash']['Test Passed Count'].to_i()
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

		rpt['report_hash'].each do |k,v|
			rpt['report_hash'][k] = v.to_i()	
		end

		test_run_class = "td_run_data"
		if (rpt['report_hash']['Test Failure Count'] > 0)
			test_run_class = "td_run_data_error"
		end

		rpt['report_hash']['Test Other Failures'] = 0
		total_failures = 0
		total_failures += rpt['report_hash']['Test Failure Count']
		total_failures += rpt['report_hash']['Test WatchDog Count']
		total_failures += rpt['report_hash']['Test Assert Failures']
		total_failures += rpt['report_hash']['Test Other Failures']
		total_failures += rpt['report_hash']['Test JavaScript Error Count']
		totals['Total Failure Count'] += total_failures

		tcount = 0
		tcount += rpt['report_hash']['Test Count']
		tcount += rpt['report_hash']['Test Blocked Count']
		tcount += rpt['report_hash']['Test Skip Count']

		exceptions_td = "td_exceptions_data"
		if (rpt['report_hash']['Test Exceptions'] > 0)
			exceptions_td = "td_exceptions_error_data"
		end

		asserts_td = "td_assert_data"
		if (rpt['report_hash']['Test Assert Failures'] > 0)
			asserts_td = "td_assert_error_data"
		end

		watchdog_td = "td_watchdog_data"
		if (rpt['report_hash']['Test WatchDog Count'] > 0)
			watchdog_td = "td_watchdog_error_data"
		end

		jscript_td = "td_javascript_data"
		if (rpt['report_hash']['Test JavaScript Error Count'] > 0)
			jscript_td = "td_javascript_error_data"
		end

		t_passedcount = rpt['report_hash']['Test Count']
		t_passedcount -= rpt['report_hash']['Test Failure Count']

      str = "<tr class=\"unhighlight\" "+
         "onMouseOver=\"this.className='highlight'\" "+
         "onMouseOut=\"this.className='unhighlight'\">\n"+
         "\t<td class=\"td_file_data\">#{log_file_td}</td>\n"+
         "\t<td class=\"#{test_run_class}\">"+
				"#{t_passedcount}/#{tcount}</td>\n"+
			"\t<td class=\"td_passed_data\">"+
				"#{rpt['report_hash']['Test Passed Count']}</td>\n"+
         "\t<td class=\"td_failed_data\">"+
				"#{rpt['report_hash']['Test Failure Count']}</td>\n"+
         "\t<td class=\"td_blocked_data\">"+
				"#{rpt['report_hash']['Test Blocked Count']}</td>\n"+
         "\t<td class=\"td_skipped_data\">"+
				"#{rpt['report_hash']['Test Skip Count']}</td>\n"+
			"\t<td class=\"#{watchdog_td}\">"+
				"#{rpt['report_hash']['Test WatchDog Count']}</td>\n"+
			"\t<td class=\"#{exceptions_td}\">"+
				"#{rpt['report_hash']['Test Exceptions']}</td>\n"+
         "\t<td class=\"#{jscript_td}\">"+
				"#{rpt['report_hash']['Test JavaScript Error Count']}</td>\n"+
         "\t<td class=\"#{asserts_td}\">"+
				"#{rpt['report_hash']['Test Assert Failures']}</td>\n"+
			"\t<td class=\"td_other_data\">"+
				"#{rpt['report_hash']['Test Other Failures']}</td>\n"+
			"\t<td class=\"td_total_data\">#{total_failures}</td>\n"+
         "\t<td class=\"td_css_data\">"+
				"#{rpt['report_hash']['Test CSS Error Count']}</td>\n"+
			"\t<td class=\"td_sodawarnings_data\">"+
				"#{rpt['report_hash']['Test Warning Count']}</td>\n"+
         "\t<td class=\"td_time_data\">"+
				"#{hours}:#{minutes}:#{seconds}</td>\n</tr>\n"
         fd.write(str)
   end
 
   hours,minutes,seconds,frac = 
      Date.day_fraction_to_time(totals['running_time'])

   totals['Test Skip Count'] = totals['Test Skip Count'].to_i()
   test_totals = totals['Test Count'] 
	test_totals += totals['Test Skip Count']
	test_totals += totals['Test Blocked Count']


   sub_totals = "<tr>\n"+
      "\t<td class=\"td_header_master\">Totals:</td>\n"+
      "\t<td class=\"td_footer_run\">#{totals['Test Count']}"+
			"/#{test_totals}</td>\n"+
		"\t<td class=\"td_footer_passed\">#{totals['Test Passed Count']}"+
			"</td>\n"+
	   "\t<td class=\"td_footer_failed\">"+
			"#{totals['Test Failure Count']}</td>\n"+	
	   "\t<td class=\"td_footer_blocked\">"+
			"#{totals['Test Blocked Count']}</td>\n"+	
	   "\t<td class=\"td_footer_skipped\">"+
			"#{totals['Test Skip Count']}</td>\n"+	
	   "\t<td class=\"td_footer_watchdog\">"+
			"#{totals['Test WatchDog Count']}</td>\n"+	
		"\t<td class=\"td_footer_exceptions\">"+
			"#{totals['Test Exceptions']}</td>\n"+
      "\t<td class=\"td_footer_javascript\">"+
			"#{totals['Test JavaScript Error Count']}</td>\n"+
      "\t<td class=\"td_footer_assert\">"+
			"#{totals['Test Assert Failures']}</td>\n"+
      "\t<td class=\"td_footer_other\">"+
			"#{totals['Test Other Failures']}\n"+
      "\t<td class=\"td_footer_total\">"+
			"#{totals['Total Failure Count']}</td>\n"+
      "\t<td class=\"td_footer_css\">"+
			"#{totals['Test CSS Error Count']}</td>\n"+
		"\t<td class=\"td_footer_sodawarnings\">"+
			"#{totals['Test Warning Count']}</td>\n"+
		"\t<td class=\"td_footer_times\">"+
			"#{hours}:#{minutes}:#{seconds}</td>\n"+
      "</tr>\n"
   fd.write(sub_totals)
   fd.write("</table>\n</body>\n</html>\n")
   fd.close()

   return result

end
   private :GenHtmlReport

end



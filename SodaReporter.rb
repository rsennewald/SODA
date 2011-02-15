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
# Required Ruby libs:
###############################################################################
require 'SodaUtils'
require 'tmpdir'
require 'SodaLogReporter'

###############################################################################
# SodaReporter -- Class
#
# Params:
#     testfile: This is a soda XML test file.
#     savehtml: This tells Soda to save html files that caused an issue.
#     resultsdir: This is the directory where you want to store all results.
#     debug: Setting this to true will cause this class to print full debug 
#        messages.
#
# simple reporter class that tracks asserts, exceptions, and log messages
###############################################################################
class SodaReporter
   attr_accessor :asserts_count, :js_error_count, :css_error_count,
      :assertFails_count, :exception_count, :test_skip_count, 
      :test_blocked_count, :test_watchdog_count

	def initialize(testfile, savehtml = false, resultsdir = nil, debug = 0,
         callback = nil, rerun = false)
		@sodatest_file = testfile
      @saveHtmlFiles = savehtml
      @debug = debug
      @start_time = nil
      @end_time = nil
      @js_error_count = 0
      @css_error_count = 0
		@asserts_count = 0
		@assertFails_count = 0
		@exception_count = 0	
      @test_count = 0
      @test_skip_count = 0
		@test_blocked_count = 0
		@test_failed_count = 0
		@test_passed_count = 0
		@test_watchdog_count = 0
		@test_warning_count = 0
		@test_total_count = 0
		@fatals = 0
		@total = 0
      @failureCount = 0
		@savedPages = 0
      @ResultsDir = "#{Dir.pwd}"
      @path = nil
      @htmllog_filename = nil
      @log_filename = nil
      @print_callback = callback
      hostname = "#{ENV['HOSTNAME']}"

      if (resultsdir != nil)
         @ResultsDir = resultsdir
      end 

      if ( (hostname.empty?) || (hostname.length < 5) )
         hostname = `hostname`
         hostname = hostname.chomp()
      end

      SodaUtils.PrintSoda("Debugging: => #{debug}\n")
      SodaUtils.PrintSoda("Soda Test File: => #{@sodatest_file}\n")
		base_testfile_name = File.basename(@sodatest_file, '.xml')

      if (rerun)
         base_testfile_name << "-SodaRerun"
      end

      now = Time.now().strftime("%d-%m-%Y-%H-%M")
     
      if (resultsdir == nil)
         @ResultsDir = @ResultsDir + "/#{base_testfile_name}-#{now}-results"
      end

      FileUtils.mkdir_p(@ResultsDir)
      @path = "#{@ResultsDir}/#{base_testfile_name}"
      
      if (File.exist?("#{@path}.tmp") || File.exist?("#{@path}.log") )
         t = Time.now()
         t = t.strftime("%Y%m%d%H%M%S")
         base_testfile_name << "-#{t}"
         @path = "#{@ResultsDir}/#{base_testfile_name}"
      end

      if (@path =~ /sugarinit/i)
		   @log_filename = "#{@path}-#{hostname}.tmp"
         @htmllog_filename = "#{@ResultsDir}/Report-#{base_testfile_name}"+
            "-#{hostname}.html"
      else
         @htmllog_filename = "#{@ResultsDir}/Report-#{base_testfile_name}.html"
		   @log_filename = "#{@path}.tmp"
      end

		@logfile = File.new(@log_filename, 'w+')
      @logfile.sync = true # force buffers to write to disk asap! #
      SodaUtils.PrintSoda("Created log file: => #{@log_filename}\n")
      log("[New Test]\n")
      log("Starting soda test: #{@sodatest_file}\n")
      log("Saving HTML files => #{@saveHtmlFiles.to_s()}.\n")
      @start_time = Time.now().strftime("%m/%d/%Y-%H:%M:%S")
	end

###############################################################################
# GetRawResults -- Method
#     This method gets test results data.
#
# Input:
#     None.
#
# Output:
#     returns a hash of test report data.
#
###############################################################################
   def GetRawResults()

      @end_time = Time.now().strftime("%m/%d/%Y-%H:%M:%S") if (@end_time == nil)
      start = DateTime.strptime("#{@start_time}",
         "%m/%d/%Y-%H:%M:%S")
      stop = DateTime.strptime("#{@end_time}",
         "%m/%d/%Y-%H:%M:%S")
      total_time = (stop - start)

      results = {
         'Test Failure Count' => @failureCount,
         'Test Assert Count' => @asserts_count,
         'Test JavaScript Error Count' => @js_error_count,
         'Test CSS Error Count' => @css_error_count,
         'Test Assert Failures' => @assertFails_count,
         'Test Exceptions' => @exception_count,
         'Test Skip Count' => @test_skip_count,
         'Test Blocked Count' => @test_blocked_count,
         'Test WatchDog Count' => @test_watchdog_count,
         'Test Warning Count' => @test_warning_count,
         'Test Event Count' => @total,
         'Test Start Time' => @start_time,
         'Test Stop Time' => @end_time,
         'Test Log File' => @log_filename
      }

      return results
   end

###############################################################################
# ZeroTestResults -- Method
#     This method zero's out needed reported values for a test when running
#     a suite.  Really this is only needed until SugarCRM internally starts
#     using real suites and I can go back to undo the hack's put in place to
#     do suite reporting when using the --test option to run suites.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def ZeroTestResults()
         @asserts_count = 0
         @js_error_count = 0
         @css_error_count = 0
         @assertFails_count = 0
         @exception_count = 0
         @test_skip_count = 0
         @test_blocked_count = 0
         @test_watchdog_count = 0
         @test_warning_count = 0
         @total = 0
         @start_time = nil
         @end_time = nil
         @failureCount = 0
   end

###############################################################################
# GetResultDir -- Method
#		This method returns the current result dir.
#
# Input:
#		None.
#
# Output:
#		returns the current result directory.
#
###############################################################################
	def GetResultDir()
		return @ResultsDir
	end

###############################################################################
# IncSkippedTest -- Method
#     This method incerments the count by 1 for tests that were skipped.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncSkippedTest()
      @test_skip_count += 1
   end
   public :IncSkippedTest

###############################################################################
# IncTestTotalCount -- Method
#     This method incerments the count by 1 for tests that were skipped.
#
# Input:
#     n: the number to inc by, 1 is the default.
#
# Output:
#     None.
#
###############################################################################
   def IncTestTotalCount(n = 1)
      @test_total_count += 1
   end
   public :IncTestTotalCount

###############################################################################
# IncBlockedTest -- Method
#     This method incerments the count by 1 for tests that were blocked.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncBlockedTest()
      @test_blocked_count += 1
   end
   public :IncBlockedTest

###############################################################################
# IncFailedTest -- Method
#     This method incerments the count by 1 for tests that failed.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncFailedTest()
      @test_failed_count += 1
   end
   public :IncFailedTest

###############################################################################
# IncTestCount -- Method
#     This method incerments the count by 1 for tests that were ran
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncTestCount()
      @test_count += 1
   end
   public :IncTestCount

###############################################################################
# IncTestWarningCount -- Method
#     This method incerments the count by 1 for tests that were ran
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncTestWarningCount()
      @test_warning_count += 1
   end
   public :IncTestWarningCount

###############################################################################
# IncTestPassedCount -- Method
#     This method incerments the count by 1 for tests that passed.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncTestPassedCount()
      @test_passed_count += 1
   end
   public :IncTestPassedCount

###############################################################################
# IncTestWatchDogCount -- Method
#     This method incerments the count by 1 for tests that watchdog'd.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def IncTestWatchDogCount()
      @test_watchdog_count += 1
   end
   public :IncTestWatchDogCount

###############################################################################
# ReportHTML -- Method
#     This function will generate an html report from the raw soda log file.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def ReportHTML
      slr = SodaLogReporter.new(@log_filename, @htmllog_filename)
      slr.GenerateReport()
      msg = "Created new html report: #{@htmllog_filename}\n"
      SodaUtils.PrintSoda(msg)

      if (@print_callback != nil)
         @print_callback.call(msg)
      end
   end

###############################################################################
# ReportFailure -- Method
#     This function reports and counts general Soda failures.
#
# Params:
#     msg: This is the string failure message to be reported. 
#
# Results:
#     None.
#
###############################################################################
   def ReportFailure(msg)
      @failureCount += 1
      log("#{msg}", SodaUtils::ERROR)
   end

###############################################################################
# ReportJavaScriptError -- Method
#     This function reports and counts javascript failures.
#
# Params:
#     msg: This is the string failure message to be reported. 
#     skipcssreport: This skipps reporting CSS errors.
#
# Results:
#     Always returns 0.
#
###############################################################################
   def ReportJavaScriptError(msg, skipcssreport = false)

      if ( (msg =~ /Cat::CSS\s+Parser/i) && (skipcssreport != true) )
         msg = msg.gsub(/javascript\s+error:/i, "Css Error:")
         log("#{msg}", SodaUtils::WARN)
         @css_error_count += 1
      elsif ( (msg =~ /Cat::CSS\s+Parser/i) && (skipcssreport != false) )
         @css_error_count += 1
         return 0
      else
         log("#{msg}", SodaUtils::ERROR)
         @js_error_count += 1
      end

      return 0
   end

###############################################################################
# SavePage -- Method
#     This method saves an given HTML page from the browser for later use.
#
# Params:
#     reason:  Just a string so when this methos is called the caller can
#        give a reason in the log file.  I'd hope this is used to report
#        errors.
#
# Results:
#     always returns 0.
#
###############################################################################
	def SavePage(reason = "")
      if (@saveHtmlFiles != true)
         return 0
      end

      @savedPages += 1
      save_file_name = "#{@path}page#{@savedPages}.html"
      page = File.new(save_file_name, 'w+')
      page.write($curSoda.browser.url + "\n<br>#{reason}\n<br>" + 
            $curSoda.browser.html)
      page.close()

      log("HTML Saved: #{save_file_name}\n")

      return 0
	end

###############################################################################
# AddEventCount -- Method
#     This function incerments the internal event counter.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
	def AddEventCount
      @total += 1
	end

###############################################################################
# EndTestReport -- Method
#     This function is to be called after a test finishes running, so that the
#     proper formatting is do to allow for an easy to parse raw log file.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def EndTestReport 
      log("Soda test: #{@sodatest_file} finished.\n")
      log("[End Test]\n")
      @logfile.close()

      tmp_logfile = File.dirname(@log_filename)
      tmp_logfile += "/" 
      tmp_logfile += File.basename("#{@log_filename}", ".tmp")
      tmp_logfile += ".log"
#      File.rename(@log_filename, tmp_logfile) # put back after hack!!!
		NFSRenameHack(@log_filename, tmp_logfile)

      @log_filename = tmp_logfile
      @end_time = Time.now().strftime("%m/%d/%Y-%H:%M:%S")
   end

###############################################################################
# NFSRenameHack -- hack!!!
#
#	This is a total hack because of the very lame ass way hudson was setup
#	to run soda tests using an nfs mount as a writing point for test
#	results!!!  This hack will be taken out as soon as hudson is updated.
#
###############################################################################
	def NFSRenameHack(old_file, new_file)
		err = false
		count = 0

		while (err != true)
			err = @logfile.closed?()
			count += 1
			sleep(1)
			break if (count > 20)
		end

		tmp_log = File.open(old_file, "r")
		new_log = File.new(new_file, "w+")
		line = nil
		while (line = tmp_log.gets)
			new_log.write(line)
		end
		tmp_log.close()
		new_log.close()

		sleep(1)
		
		is_deleted = false
		for i in 0..30
			begin
				File.unlink(old_file)
				is_deleted = true
			rescue Exception => e
				print "(!)Failed calling delete on file: '#{old_file}'!\n"
				is_deleted = false
			ensure
			end

			break if (is_deleted)
			sleep(1)
		end
	end

###############################################################################
# log -- Method
#     This method will log soda message to both stdout & the report's log file.
#
# Params:
#     msg: This is a string message to log.
#  
#     error: Default is false, setting to true will format the message as an
#        error.
#
# Results:
#     None.
#
###############################################################################
   def log(msg, error = 0)
      SodaUtils.PrintSoda(msg, error, @logfile, @debug)
      SodaUtils.PrintSoda(msg, error, nil, @debug, 1, @print_callback)
	end

###############################################################################
# ReportException -- Method
#     This method reports an Soda Exceptions from the Soda class.
#
# Params:
#     sodaException: This is the exception that is passed from Soda.
#     file: The soda test file that the exception was raised by durring the
#        test.
#
# Results:
#     None.
#
# Notes:
#     The major param seems totally useless and was left over from the org
#     code from this file.  Soda.rb only ever calls this method with major.
#     So I will be killer this param soon...
#
###############################################################################
   def ReportException(sodaException, file = false)
      msg = nil
      @exception_count += 1
	
      if (sodaException.message.empty?)
         msg = "No exception message found!"
      else
         msg = sodaException.message
      end

      if (file)
         log("Exception raised for file: #{file}\n", SodaUtils::ERROR)
      else
         log("Exception raised: #{msg}\n", SodaUtils::ERROR)
      end

		bt = "--Exception Backtrace: " + sodaException.backtrace.join("--") +
			"\n"
		btm = "--Exception Message: #{msg}\n"
		log("Exception raised for file: #{file}" + btm + bt, 
			SodaUtils::ERROR)
	end

###############################################################################
# Assert -- Method 
#     This method assert that the exp is equal to TRUE, and reports the results
#
# Params:
#     exp: The expression to evaulate.
#     msg: The message to report about the assertion.
#
#
# Results:
#     returns -1 on assert failed, or 0 on success.
#
###############################################################################
   def Assert(exp, msg = "", file = "", line_number = "")
      result = 0
		@asserts_count += 1
      url = nil

      url = "#{$curSoda.browser.url}"
      if ( (url.empty?) || (url.length < 1) || (url == "") )
         url = "Unknown URL casued this Assert!"
      end

      if (file.empty?)
         file = "No file provided."
      end

      if (msg.empty?)
         msg = "No Assert message provided!"
      end 

      if ( (line_number == nil) || (line_number.empty?))
         line_number = "Unknown line number"
      end

		if (!exp)
         ass_msg = "Assertion: Failed!:--#{url}--#{file}" +
         "--Assertion Message: #{msg}--Line: #{line_number}"
         ass_msg = ass_msg.sub(/\n/,"")
         ass_msg << "\n"

         log(ass_msg, 1)
			SavePage(msg)
			@assertFails_count += 1
         result = -1
		else
         if (msg.empty?)
   			log("Assertion: Passed.\n")
         else
   			log("Assertion: Passed: #{msg}.\n")
         end
         result = 0
		end

      return result
	end

###############################################################################
# AssertNot -- Method
#     This method asserts if the exp is equal to FALSE, and reports the results
#
# Params:
#     exp: The expression to evaulate.
#     msg: The message to report with the assert.
#
#
###############################################################################
   def AssertNot(exp, msg = "", file = "")
		Assert(!exp, msg, file)
	end

###############################################################################
# SodaPrintCurrentReport -- Method
#     This method is used for printing out the current results of the report.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def SodaPrintCurrentReport()
      msg = "Soda Test Report:" + 
         "--Test File:#{@sodatest_file}" +
         "--Test Failure Count:#{@failureCount}" +
         "--Test CSS Error Count:#{@css_error_count}" +
         "--Test JavaScript Error Count:#{@js_error_count}" +
         "--Test Assert Failures:#{@assertFails_count}" +
         "--Test Event Count:#{@total}" +
         "--Test Assert Count:#{@asserts_count}" +
         "--Test Exceptions:#{@exception_count}\n"
         log(msg)
	end

end


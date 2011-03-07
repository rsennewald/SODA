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

module Soda

###############################################################################
# Module Global Info:
###############################################################################
SODA_VERSION = 1.1
SODA_WATIR_VERSION = "1.8.0"

###############################################################################
# Needed Ruby libs:
###############################################################################
require 'rubygems'
require 'rbconfig'
require 'pathname'
gem 'commonwatir', '= 1.8.0'
gem 'firewatir', '= 1.8.0'
require "watir"
require 'SodaUtils'
require "SodaReporter"
require "SodaCSV"
require "SodaXML"
require 'SodaFireFox'
require 'SodaTestCheck'
require 'SodaScreenShot'
require "utils/sodalookups"
require "fields/SodaField"
require "fields/TextField"
require "fields/CheckBoxField"
require "fields/SelectField"
require "fields/RadioField"
require "fields/FileField"
require "fields/LiField"
require 'thread'
require 'date'
require 'pp'

###############################################################################
# Soda -- Class
#     This class that converts Soda Meta Data into Ruby Watir Commands and 
# executes them.
#
# Params:
#     browser: For setting the default browser. IE/FireFox/...
#     sugarflavor: This is the type of sugar flavor we are testing: ent,pro...
#     savehtml: Setting this saves off failed html pages o disk.
#     hijacks: This is a hash of keys to overwrite csv file values.
#
###############################################################################
class Soda
   attr_accessor :rep, :browser

   def initialize(params)
      $curSoda = self;
      @params = nil
      @debug = params['debug']
      @browser = nil
      @saveHtml = params['savehtml']
      @blocked_files = []
      @fileStack = [] # used for keeping track of which file we are in # 
      @curEl = nil # current element being used #    
      $link_not_assert = false 
      $skip_css_errors = false
      @newCSV = [] 
      $SodaHome = Dir.getwd()
      @current_os = SodaUtils.GetOsType()
      @sugarFlavor = {}
      @resultsDir = {} 
      @globalVars = {}
      @SIGNAL_STOP = false
      @hiJacks = nil
      @breakExit = false
      @currentTestFile = "" 
      @exceptionExit = false
      @ieHwnd = 0
      @nonzippytext = false
      $global_time = Time.now()
      $mutex = Mutex.new()
      @whiteList = []
      @white_list_file = ""
      @restart_test = nil
      @restart_count = 0
      @non_lib_test_count = 0
      @last_test = ""
      @SugarWait = false
      @restart_test_running = false
      @FAILEDTESTS = []
      @vars = Hash.new
      blocked_file_list = "tests/modules/blockScriptList.xml"
      whitelist_file = "tests/modules/whitelist.xml"
      result = nil
      sigs = [
         "INT",
         "ABRT",
         "KILL"
      ]
      err = 0
    
      @sugarFlavor = params['flavor'] if (params.key?('flavor'))
      @resultsDir = params['resultsdir'] if (params.key?('resultsdir'))
      @globalVars = params['gvars'] if (params.key?('gvars'))
      @nonzippytext = params['nonzippytext'] if (params.key?('nonzippytext'))

      if (@globalVars.key?('scriptsdir'))
         blocked_file_list = "#{@globalVars['scriptsdir']}/modules/" +
            "blockScriptList.xml"
         whitelist_file = "#{@globalVars['scriptsdir']}/modules/whitelist.xml" 
      end

      if (File.exist?(blocked_file_list))
         @blocked_files = SodaUtils.ParseBlockFile(blocked_file_list)
      end

      if (File.exist?(whitelist_file))
         @whiteList = SodaUtils.ParseWhiteFile(whitelist_file)
      end

      @sugarFlavor = @sugarFlavor.downcase()

      if (params.key?('restart_count'))
         @restart_count = params['restart_count'].to_i()
         if (params.key?('restart_test'))
            @restart_test = params['restart_test']
         end
      end

      if (params['hijacks'] != nil)
         @hiJacks = params['hijacks']
      end

      if (params.key?('sugarwait'))
         @SugarWait = params['sugarwait']
      end

      # stack of elements allowing for parent child hierchy
      # <form id='myform'><textfield name='myfield'/></form> 
      @parentEl = [] 

      sigs.each do |s|
         Signal.trap(s, proc { @SIGNAL_STOP = true } )
      end

      if (@current_os =~ /windows/i)
         $win_only = true
      end

      @autoClick = { 
         "button" => true, 
         "link" => true, 
         "radio" => true
      }
     
      @params = params
      err = NewBrowser()
      if (err != 0)
         exit(-1)
      end

      # this is setup to allow other skips, but there should never really
      # be any other type of error to skip.  The only reason why I added
      # this skip is because a manager requested it.  In genernal skipping
      # reporting errors is not a good thing and should never ever be done!
      @params['errorskip'].each do |error|
         case error
            when /css/i
               $skip_css_errors = true
         end
      end

      @vars['stamp'] = getStamp()
      @vars['currentdate'] = getDate()
   end

###############################################################################
# RestartGlobalTime -- Method
#     This method reset the global time, for the watchdog timer.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def RestartGlobalTime()
      $mutex.synchronize {
         $global_time = Time.now()
      }
   end

###############################################################################
###############################################################################
   def NewBrowser()
      err = 0

      RestartGlobalTime()

      if ( @current_os =~ /WINDOWS/i && 
         @params['browser'] =~ /ie|firefox/i ) 
         require 'win32ole'
         @autoit = WIN32OLE.new("AutoItX3.Control")
      end

      if (@params['browser']) 
         Watir::Browser.default = @params['browser']
      end

      if (@params['browser'] =~ /firefox/i)
         for i in 0..2 do
            if (@params['profile'] != nil)
               result = SodaFireFox.CreateFireFoxBrowser(
                  {:profile => "#{@params['profile']}"})
            else
               result = SodaFireFox.CreateFireFoxBrowser()
            end
            
            if (result['browser'] != nil)
               @browser = result['browser']
               break
            end

            sleep(2)
         end

         if (@browser == nil)
            SodaUtils.PrintSoda("Failed to create new firefox browser!\n",
               SodaUtils::ERROR)
            SodaUtils.PrintSoda("Exception Message: " +
               "#{result['exception'].message}\n", SodaUtils::ERROR)
            SodaUtils.PrintSoda("BackTrace: #{result['exception'].backtrace}"+
               "\n", SodaUtils::ERROR)
            err = -1
         end

         @browser.execute_script(SodaUtils::FIREFOX_JS_ERROR_CLEAR)
      else
         @browser = Watir::Browser.new()
      end

      return err
   end

###############################################################################
# GetFailedTests -- Method
#     This method returns a list of failed tests.
#
# Input:
#     None.
#
# Output:
#     returns a list of failed tests.  The list can be empty of no tests 
#     failed.
#
###############################################################################
   def GetFailedTests()
      @FAILEDTESTS.uniq!()

      return @FAILEDTESTS
   end
   public :GetFailedTests

###############################################################################
# SetGlobalVars - Method
#     This method reads all the vars passed to the constructor and sets them
#     up for use for all soda tests.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def SetGlobalVars()
      @globalVars.each do |k,v|
         name = "global.#{k}"
         setScriptVar(name, v)
      end
   end

###############################################################################
# PrintDebug -- Method
#     This method only logs a message to the soda log if the debug flag is set.
#
# Params:
#     str: The message to debug.
#     level: The debug level to report.
#
# Results:
#     Always returns 0.
#
###############################################################################
   def PrintDebug(str, level = SodaUtils::LOG)
      if (@debug != false)
         @rep.log(str, level)
      end

      return 0
   end

###############################################################################
# send_keys --
#     This function sends keyboard keys to firefox(IE has support this method)
#
# Params:
#     key_string: A string of keys to send.
#
# Results:
#   
###############################################################################
   def send_keys(key_string)      
      case Watir::Browser.default
         when /ie|firefox/i
            @autoit.WinActivate(@browser.title())
            @autoit.Send(key_string)
         else
            PrintDebug("Send_keys: Unknown Browser!", SodaUtils::ERROR)
      end          
   end
 
###############################################################################
# MouseClick -- Method
#     This method stimulates a mouse click operation.
#
# Params:
#     x: The x cord position.
#     y: The y cord position.
#
# Results:
#     None.
#
###############################################################################
   def MouseClick(x_pos,y_pos)
      @autoit.MouseClick("left", x, y)
   end
 
###############################################################################
# getStamp -- Method
#     This method creates a new formated datetime string from the current time.
#
# Params:
#     None.
#
# Results:
#     reutrns a formated string with the current datetime.
#
###############################################################################
   def getStamp()
      return Time.now().strftime("%y%m%d_%H%M%S")
   end
       
###############################################################################
# getDate -- Method
#     This method returns a new formated date string from the current time.
#
# Params:
#     None.
#
# Results:
#     returns a string with the current date.
#
###############################################################################
   def getDate()
      return Time.now().strftime("%m/%d/%Y")
   end   
       
###############################################################################
# setScriptVar -- Method 
#     This method sets variables used during script execution by the scripts
#     themselves.
#
# Params:
#     name: The key in the @vars to set.
#     value: The new value to the for the given key.
#
# Results:
#     None.
#
###############################################################################
   def setScriptVar(name, value)
      @vars[name] = value
      msg = "Setting key: \"#{name}\" =>"

      if (value.instance_of?(Hash))
         msg << " Hash:{"
         value.each do |k ,v|
            tmp_k = k.gsub("\n", '\n')
            tmp_v = v.gsub("\n", '\n')
            msg << "'#{tmp_k}'=>'#{tmp_v}',"
         end
         msg = msg.chop()
         msg << "}\n" 
      else
         tmp_value = "#{value}"
         tmp_value = tmp_value.gsub("\n", '\n')
         msg << " \"#{tmp_value}\"\n"
      end

      PrintDebug(msg)
   end

###############################################################################
# getScriptVar -- Method   
#     This method retrieves variables used during script execution if the 
#     variable is not set then the default value is returned variables are 
#     specified in a script as {@myvar} to set this variable use var='myvar'
#     for CSV variables it would be {@record.csvvar}
#     The following attribues may have variables used within them 
#     *assert
#     *accessor attributes (href, id, value ...)
#     *contains
#
# Params:
#     name: The name of the var to get the value from.
#     default: If the value isn't already set then it is set to this value.
#
# Results:
#     returns the value for the given name.
#
# Notes:
#     This method will also overwrite any csv value of the key for that value
#     is in the @hiJacks hash for this class.
#
###############################################################################
   def getScriptVar(name, default='')
      val = default
      names = nil
      is_csv = false
      org_name = name
      tmp_name = org_name.gsub(/^\./, "")

      # if it contains a '.' it must be a CSV variable so it is stored as a 
      # hash
      if ( (name.index('.')) && (name !~ /^global/) )
         names = name.split('.')
         name = names[0]
         is_csv = true
      end

      # make sure we have a variable set
      if (@vars.key?(name))
         # if we have an array for names it means it was a CSV variable
         if (names)
            val =  @vars[name][names[1]]
         else
            val =  @vars[name]
         end
      else
         begin
            val = "Soda unknown script key: \"#{tmp_name}\"!"
            msg = "Failed to find script variable by name: \"#{tmp_name}\"!\n"
            @rep.ReportFailure(msg)
            raise(msg)
         rescue Exception => e
            @rep.ReportException(e)
         ensure

         end
      end
    
      if (@hiJacks.key?(org_name))
         PrintDebug("High Jacking CSV variable: \"#{org_name}\" from value:" +
            " \"#{val}\" to \"#{@hiJacks["#{org_name}"]}\"\n")
         val = @hiJacks["#{org_name}"]
      else
         tmp_val = "#{val}"
         tmp_val = tmp_val.gsub("\n", '\n')
         PrintDebug("Value for \"#{tmp_name}\" => \"#{tmp_val}\".\n")
      end

      val = "" if (val == nil) # default it to be an empty string. #

      return val
   end
   
###############################################################################
# getField -- Method
#     This method gets the field based on the event from the page.
#
# Params:
#     event: This is the event to use to get the field.
#     flag: If true will cause this function to wait for the event.
#
# Results:
#
###############################################################################
   def getField(event, flag = true)
      str = nil
      field = nil

      # this is to handle how the IE dom accesses links #
      if ( (Watir::Browser.default =~ /ie/i) && (event.key?('href')) )
         tmp_href = event['href']
         event = SodaUtils.IEConvertHref(event, @browser.url())
         @rep.log("Converted Soda test href: '#{tmp_href}' to IE href:"+
            " '#{event['href']}'.\n")
         end
      str = generateWatirObjectStr(event)

      # if the timeout is set use the specified timeout for accessing the 
      # field otherwise allow 15 seconds
      timeout = (event.key?('timeout'))? Integer(event['timeout']): 15
      required = (event.key?('required'))? SodaField.getStringTrue(event['required']): true

      event['required'] = required

      if (event.key?('exist'))
         event['exists'] = event['exist']
      end

      if (event.key?('exists'))
         exists = getStringBool(event['exists'])

         if (exists == true)
            field = waitFor(eval(str), event['do'], timeout, true)
         
            if (field != nil)
               @rep.Assert(true, "#{event['do']} element exists.", 
                  @currentTestFile)
            else
               @rep.Assert(false, "Failed to find #{event['do']} element!", 
                  @currentTestFile, "#{event['line_number']}")
               @FAILEDTESTS.push(@currentTestFile)
            end
         else
            field = waitFor(eval(str), event['do'], timeout, false)      
            if (field == nil)
               @rep.Assert(true, "#{event['do']} element does not exist as "+
                  "expected.", @currentTestFile)
            else
               @rep.Assert(false, "#{event['do']} exists when it is not "+
                  "expected to!", @currentTestFile, "#{event['line_number']}")
               @FAILEDTESTS.push(@currentTestFile)
            end
         end
      else
         # use for wait tag
         if (flag == false)
            field = waitFor(eval(str), event['do'], timeout, required, false)
         else
            # get the field
            field = waitFor(eval(str), event['do'], timeout, required)
         end
      end

      if ( (required != true) && (field == nil) )
         @rep.log("Element not found, but was tagged as: required ="+
            " \"#{required}\".\n")
      end

      return field
   end
     
###############################################################################
# generateWatirObjectStr -- Method
#     This function generates ruby watir code on the fly based on the event.
# 
# Params:
#     event: A soda event.
#
# Results:
#     returns a string of ruby/watir code.
#
###############################################################################
   def generateWatirObjectStr(event)
      str = ""

      # the 'do' is the field to access at this point
      fun = event['do'];

      # if there is a parent Element we are going to use that #
      if (@parentEl.length > 0)
         str = '@parentEl[@parentEl.length - 1]'
      else 
      # otherwise the browser is the parent
         str = '@browser'
      end
      
      str += ".send(:#{fun} "

      # sodalookups contains how each field may be accessed
      $sodalookups[fun].each do |how, avail|
         if (!avail)
            next
         end
         
         if (event.key?(how))
            # replace any variables in how we are going to use it 
            # (useful for dynamic links)
            event[how] = replaceVars(event[how])
            regex = stringToRegex(event[how])
            quote = true
            
            if (regex != event[how])
               quote = false
            end
            
            curhow = event[how]
            if (quote)
               curhow = "'#{event[how]}'"
            end
            
            # despite documentation forms don't support multiple attributes
            if (fun == 'form')
               str += ",:#{how}, #{curhow}"
               break
            end
               
            # support for accessing elements by multiple attributes
            str += ",:#{how}=>#{curhow}"
         end
            # if we have an index which specifies which one to return if there 
            # are more than one
            # if event.key?('index') 
            #  str += ",:index=>#{event['index']}" 
            # end
      end # end each #

      str += ")"

      return str
   end

###############################################################################
# waitFor -- Method
#     Waits for a field to be present this ensures that a field is on the page
#     when we expect it to *field is the field we want *name is a human 
#     readable name for the field *timeout is the number of seconds we are 
#     willing to wait for the field if timeout is set to 0 or -1 then we 
#     won't raise an exception if we can't find the field and we consider the 
#     field optional.
#
# Params:
#     field: This is the name of the field on the page.
#     name: The human readable field name.
#     timeout: Number of seconds to wait for the field.
#     required: 
#     flag:
#
# Results:
#     returns nil on error, or field on success.
#
###############################################################################
   def waitFor(field, name, timeout = 15, required = true, flag = true)
      start_time = Time.now
      result = nil
      found_field = false
      
      until (found_field = field.exists?) do
         sleep(0.5)
         # if the timeout is > 0 then we really wanted the field to be there 
         # so raise an exception otherwise the field is considered optional
         # used for "wait" tag

         if ( (Time.now - start_time > timeout) && (found_field != true))
            if (flag == false)
               msg = "waitFor: Element not found: \"#{name}\"!\n"
               @rep.log(msg)
               break
            end

            if ($link_not_assert)         
               @rep.log("Assertion Passed\n");
               $link_not_assert = false
               break
            elsif (required && (found_field != true))
               @rep.log("waitFor: Element not found: \"#{name}\""+
                  " Timedout after #{timeout} seconds!\n")
               @FAILEDTESTS.push(@currentTestFile)
               break
            else
               break
            end
         end
      end
      
      if (flag == false)
         @rep.log("waitFor found Element: \"#{name}\".\n");
      end

      result = field if (found_field)

      return result
   end   

###############################################################################
# waitByMultipleCondition -- Method 
#     This method waits until the multiple condition is matchedv.
#
# Params:
#     event: The event to check.
#     timeout: The number of seconds to wait.
#
# Results:
#     None.
#
# Notes:
#     This method looks like a total hack, need to revist this later.
#
###############################################################################
   def waitByMultipleCondition(event, timeout = 10)            
      case event['do']
         when "textfield"
            event['do'] = 'text_field'
         when "textarea"
            event['do'] = 'text_field'
         when "select"
            event['do'] = 'select_list'
         when "filefield"
            event['do'] = 'file_field'
      end            
      
      event['timeout'] = timeout 
      @curEl = getField(event, false)           
      
      if (event.key?('children'))
         @parentEl.push(@curEl)  
         event['children'].each do |sub_event|
            waitByMultipleCondition(sub_event, event['timeout'])
         end
      end

      @parentEl.pop()
   end
  
###############################################################################
# getScript -- Method
#     This method loads and soda XML script and parses it and returns the 
#     Soda Meta Data.
#
# Params:
#     file: A soda xml test file.
#     is_restart: true/false, tells us that this is a restart test.
#
# Results:
#     on success returns a LibXML::Parser Document, or nil on error.
#
###############################################################################
   def getScript(file, is_restart = false)
      script = nil
      valid_xml = true
      script_check = false
      err = 0

      if (!File.extname(file) == '.xml')
          msg = "Failed trying to parse file: \"#{file}\": Not a valid " +
            " XML file!\n"
         @rep.ReportFailure(msg)
         script = nil
         valid_xml = false
      end

      if (valid_xml)
         $run_script = file
         PrintDebug("Parsing Soda test file: \"#{file}\".\n")
         begin
            checker = SodaTestCheck.new(file, @rep)
            script_check = checker.Check()

            if (!script_check)
               script = nil
               @rep.IncSkippedTest()
            else
               script = SodaXML.new.parse(file)
            end
         rescue Exception => e
            @rep.ReportException(e, file)
         ensure
         end
      end

      return script
   end
              
###############################################################################
# RestartBrowserTest -- Method
#     This method checks to see if the browser needs to be restarted.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def RestartBrowserTest(suitename)
     
      begin 
         @browser.close()
         sleep(1)
      rescue Exception => e
      end

      RestartGlobalTime()

      @rep = SodaReporter.new(@restart_test, @saveHtml, @resultsDir, 
         0, nil, false);
      @rep.log("Restarting browser.\n")
      
      if (@params['browser'] =~ /firefox/i)
         SodaFireFox.KillProcesses()
      end
      
      err = NewBrowser()
      if (err != 0)
         @rep.ReportFailure("Failed to restart browser!\n")
      end

      if (!@restart_test.empty?)
         restart_script = getScript(@restart_test)
         handleEvents(restart_script)
      end

      RestartGlobalTime()     
      @rep.log("Finished: Browser restart.\n")
      @rep.EndTestReport()
   end

###############################################################################
# getDirScript -- Method
#     This method goes into directory and load xml scripts.
#
# Params:
#     file: This is the file to open.
#
# Results:
#     None.
#
# Notes:
#     Using recursion...  This should be revisited for a better way.
#
###############################################################################
   def getDirScript(file)
      test_count = 0
      results = 0

      file = File.expand_path(file)

      if (File.directory?(file))
         files = []
         fd = Dir.open(file)
         fd.each do |f|
            files.push("#{file}/#{f}") if (f =~ /\.xml$/i)
#           @rep.IncTestTotalCount() if (f !~ /lib/i)
         end
         fd.close()

         if (files.empty?)
            @rep.log("No tests found in directory: '#{file}'!\n",
               SodaUtils::WARN)
            @rep.IncTestWarningCount()
            return nil
         end   

         test_count = files.length()
         @rep.log("Fileset: '#{file}' contains #{test_count} files.\n")

         files.each do |f|
            getDirScript(f)
         end
      elsif (File.file?(file))
         if (!(remBlockScript(file)) && 
            ((file !~ /^setup/) || (file !~ /^cleanup/) ) )
            @rep.log("Starting new soda test file: \"#{file}\".\n")

            script = getScript(file)
            if (script != nil)
               parent_test_file = @currentTestFile
               @currentTestFile = file
               results = handleEvents(script)
               if (results != 0)
                  @FAILEDTESTS.push(@currentTestFile)
                  @rep.IncFailedTest()
               else
                  @rep.IncTestPassedCount() if (file !~ /lib/i)
               end
               @currentTestFile = parent_test_file
            else
               msg = "Failed opening script file: \"#{file}\"!\n"
               @rep.ReportFailure(msg)
            end
         end
      end
   end
 
###############################################################################
# remBlockScript -- Method
#     This method checks to see of the test file is in the 
#     blockScriptsList.txt to decide if the test can be ran.
#
# Params:
#     file: This is the soda test file that were are checking to see of we can
#        run or not.
#
# Results:
#     returns true if the file is to be blocked, else false.
#
###############################################################################
   def remBlockScript(test_file)
      result = false 

      @blocked_files.each do |bhash|
         tmp_file = File.basename(test_file)
         if (tmp_file =~ /#{bhash['testfile']}/)
            @rep.log("Blocklist: blocking file: \"#{test_file}\".\n")
            @rep.IncBlockedTest()
            result = true
            break
         end
      end

      return result
   end
     
###############################################################################
# getRightCSV -- Method 
#     This method replaces the default csv with specified event.
#
# Params:
#     event: This is the event to replace the csv with.
#
# Results:
#     None.
#
###############################################################################
   def getRightCSV(event)   
      for csv in @newCSV
         csv.each do |runfile, runcsv|
            if (@fileStack[@fileStack.length - 1] == runfile)
               event['file'] = runcsv
               @newCSV.delete(runfile)  
            end
         end
      end
   end
       
###############################################################################
# getEvents -- Method
#     This methos returns a list of events.   Certain events may need to be 
#     expanded into multiple events.
#
# Params:
#     event: This event to get...
#
# Results:
#     returns  a hash of events.
#
###############################################################################
   def getEvents(event)
      events  = []
      seed = nil

      # expand lists into multiple events #
      if (event.key?('list'))
         seed = Hash.new()

         event.each do |k,v|
            if (k == 'list' || k == 'by')
               next
            end
            seed[k] = v
         end

         event['list'].each do |k,v|
            cur = seed.dup
            cur[event['by']] = k
            cur['set'] = v
            events.push(cur)
         end
      else
         events.push(event)
      end

      return events
   end
  
###############################################################################
# replaceVars -- Method
#     This method replaces a {@varname} with the appropriate variable.
#
# Params:
#     str: The string to replace words in.
#     default: The default to replace with.
#
# Results:
#     returns an empty string if the var is the csv file is nothing, else a 
#     new string with the vars replaced.
#
###############################################################################
   def replaceVars(str, default='')
      org_str = str
      vars_hash = Hash.new()
      result = "#{str}".scan(/\{@[\w\.]+\}/i)

      result.each do |var|
         next if ( (var == nil) or (var.empty?) ) 
         var = var.gsub(/^\{@/, "")
         var = var.gsub(/\}$/, "")
         tmp = getScriptVar(var, default)
         
         if (tmp == nil)
            tmp = "Unknown Var: '#{var}'"
            @rep.ReportFailure("Error trying to access an unknown script var:"+
               " '#{var}'!\n")
         end

         vars_hash[var] = tmp
      end

      vars_hash.each do |k, v|
         str = str.gsub(/\{@#{k}\}/, v)
      end

      if (org_str != str)
         tmp_org_str = "#{org_str}"
         tmp_org_str = tmp_org_str.gsub("\n", '\n')
         tmp_str = "#{str}"
         tmp_str = tmp_str.gsub("\n", '\n')
         PrintDebug("Replacing string '#{tmp_org_str}' with '#{tmp_str}'\n")
      end

      return str  
   end
        
###############################################################################
# stringToRegex -- Method
#     This method creates a Regexp object from a string.
#
# Params:
#     str: The string to convert to a regex.
#
# Results:
#     returns the passed string if it is not a regex str, else a new regex
#     object is returned.
#
###############################################################################
   def stringToRegex(str)
      result = nil

      if (SodaUtils.isRegex(str))
         result = SodaUtils.CreateRegexFromStr(str)
         if (result == nil)
            @rep.ReportFailure("Failed trying to convert string to regex:"+
               " String: '#{str}'!\n") 
         end
      else
         result = str
      end

      return result
   end
  
###############################################################################
# assertPage -- Method
#     This method checks to see of the browser contains any text for known
#     errors.  It also looks to make sure anything in the whitelist isn't
#     reported as a error.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def assertPage()
      data = []
      found_error = false
      page_strs_to_replace = [
         'Expiration Notice:', 'Notice: Your license expires',
         'Warning: Please upgrade', 
         '(Fatal|Error): Your license expired|',
         'isError', 'errors' ,'ErrorLink'
         ]
      page_strs_to_replace2 = [
         'Warning: Your email settings are not configured to send email',
         'Warning: Missing username and password',
         'Warning: You are modifying your automatic',
         'Warning: Auto import must be enabled when automatically'+
             ' creating cases'
         ]

      crazyEvilIETabHack()
      @browser.wait()

      begin
         text = @browser.text
      rescue Exception => e
         @rep.ReportException(e)
         text = ""
      ensure

      end
  
      text = text.gsub(/^\n/, "")

      page_strs_to_replace.each do |reg|
         text = text.gsub(/#{reg}/i, '')
      end
      
      page_strs_to_replace2.each do |reg|
         text = text.gsub(/#{reg}/, '')
      end

      @whiteList.each do |hash|
         text = text.gsub(/#{hash['data']}/, '')
      end

      data = text.split(/\n/)
      data.each do |line|
         case (line)
            when /(Notice:.*line.*)/i
               @rep.ReportFailure("Found error in page HTML: '#{$1}'\n")
               found_error = true
            when /(Warning:)/i
               @rep.ReportFailure("Found error in page HTML: '#{$1}'\n")
               found_error = true
            when /(.*Error:.*line.*)/i
               @rep.ReportFailure("Found error in page HTML: '#{$1}'\n")
               found_error = true
            when/(Error retrieving)/i
               @rep.ReportFailure("Found error in page HTML: '#{$1}'\n") 
               found_error = true
            when /(SQL Error)/i
               @rep.ReportFailure("Found error in page HTML: '#{$1}'\n") 
               found_error = true
         end
      end

      if (found_error)
         @FAILEDTESTS.push(@currentTestFile)
      end

   end
   
############################################################################## 
# kindsOfBrowserAssert -- Method
#     This method does an assert on the text contained in the web browser.
#     The assert can be either a regexp or a string.
#
# Input:
#     event: This is a soda event.
#     flag: true or false, for an assert or an assertnot
#
# Output:
#     returns -1 on error else 0 on success.
#
###############################################################################
   def kindsOfBrowserAssert(event, flag = true)
      msg = "Unknown Browser Assert!"
      match = nil
      ass = nil
      contains = ""
      is_regex = false
      result = 0

      if (event['assert'].kind_of? Regexp)
         is_regex = true
         contains = event['assert'].to_s()

         if (event['assert'] != nil)
            match = event['assert'].match(@browser.text)
            if (match != nil)
               ass = true
            else
               ass = false
            end
         else
            @rep.ReportFailure("Failed to create regex!\n")
            e_dump = SodaUtils.DumpEvent(event)
            @rep.log("Event Dump: #{e_dump}!\n", SodaUtils::EVENT)
            ass = false
            result = -1
         end
      else
         contains = replaceVars(event['assert'] )
         # assert the text in specified area
         if (@parentEl.length > 0)
            ass = @parentEl[@parentEl.length-1].text.include?(contains)
         else
            ass = @browser.text.include?(contains)
         end
      end

      if (flag)
         if (!is_regex)
            msg = "Checking that the Browser does contain the text: "+
               "\"#{contains}\""
         else
             msg = "Checking that the Browser does match regex: "+
               "\"#{contains}\""     
         end

         result = @rep.Assert(ass, msg, @currentTestFile, 
               "#{event['line_number']}")
         if (result != 0)
            @FAILEDTESTS.push(@currentTestFile)
         end
      else
         if (!is_regex)
            msg = "Checking that browser does not contain text:"+
               " \"#{contains}\" in page."
         else
            msg = "Checking that browser regex doesn not match: "+
               " \"#{contains}\" in page."
         end

         result = @rep.Assert(!ass, msg, @currentTestFile, 
               "#{event['line_number']}")
         if (result != 0)
            @FAILEDTESTS.push(@currentTestFile)
         end
      end

      return result
  end
 
###############################################################################
# getStringBool -- Method
#     This method checks to see of the value passed to it proves to be positive
#     in most any way.
#
# Params:
#     value: This is a string that will prove something true or false.
#
# Results:
#     returns true if the value is a form of being 'positive', or false.
#     If the value isn't a string then the value is just returned....
#
# Notes:
#     This is a total hack, we should be throw an exception if the value is
#     something other then a string...  Will come back to this later...
# 
###############################################################################
   def getStringBool(value)
      if (value.is_a?(String))
         value.downcase!

         if (value == 'true' or value == 'yes' or value == '1')
            return true
         else
            return false
         end 
      end

      return value
   end
   
###############################################################################
# checkSelectList -- Method
#     This method checks to see if a string exisits in a list of some kind.
#
# Params:
#     list: ???
#     str: A string to check for in the list.
#
# Results:
#     returns true of the string is found or false if it is not.
#
###############################################################################
   def checkSelectList(list, str)
      list.each do |i|
         if (i == str)
            return true
         end
      end

      return false          
   end
 
############################################################################### 
# cloneEvent -- Method
#     This method does a deep clone of events Arrays in Ruby are objects and
#      we ocassionally need to preserve the state of the arrays.
#
# Params:
#     event: ???
#
# Results:
#     returns the event data after it as been marshaled into a byte stream.
#
############################################################################### 
   def cloneEvent(event)
      return Marshal.load(Marshal.dump(event))
   end

############################################################################### 
# FlavorMatch -- Method
#     This method checks that all the test requirements meet the current
#     testing env.
#
# Params:
#     events: The soda events array.
#
# Results:
#     returns true if this test can be ran, else false.  Will also return true
#     if the test has no requires info at all, but a warning message will be
#     logged.
#
############################################################################### 
   def FlavorMatch(flavor)
      match = false
      flavor = flavor.downcase()

      if (flavor =~ /,/)
         flavors = flavor.split(",")
         flavors.each do |sugflav|
            if (sugflav == @sugarFlavor)
               match = true
               break
            end
         end
      else
         if (flavor == @sugarFlavor)
            match = true
         end
      end

      return match
   end

###############################################################################
# CloseBrowser -- Method
#     This method closes browsers.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def CloseBrowser()
      result = 0
   
      if (Watir::Browser.default =~ /firefox/i)
         result = SodaFireFox.CloseBrowser(@browser)
      else
         @browser.close()
         result = 1
      end

      if (result < 1)
         @rep.ReportFailure("Failed trying to close browser: '#{result}'!\n")
      end

      @browser = nil
   end

###############################################################################
# eventBrowser -- Method
#     This method handles all Soda browser events.
#
# Params:
#     event: This is the event to handle.
#
# Results:
#     returns a hash with keys: browser_close & error.
#
###############################################################################
   def eventBrowser(event)
      result = {
         'browser_closed' => false,
         'error' => 0 
      }

      event = SodaUtils.ConvertOldBrowserClose(event, @rep, @currentTestFile)

      if (event.key?('action'))
         action = replaceVars(event['action'])
         @rep.log("Firing browser action: \"#{action}\"\n")

         case action
            when "back"
               @browser.back
            when "forward"
               @browser.forward
            when "close"
               if (@browser != nil)
                  CloseBrowser()
                  result['browser_closed'] = true
               else
                  PrintDebug("For some reason I got a nill @browser object!",
                     SodaUtils::WARN)
                  @rep.IncTestWarningCount()
                  result['browser_closed'] = true
               end
            when "refresh"
               @browser.refresh
            else
               @rep.ReportFailure("Unknown browser action:"+
                  " \"#{action}\".\n")
               result['error'] = -1
         end
      end

      if (event.key?('url'))
         event['url']  = replaceVars(event['url'])
         @browser.goto(event['url'])
         @browser.wait()
         if (event['assertPage'] == nil || event['assertPage'] != "false")
             assertPage()
         end
      end
   
      if (event.key?('assert'))
         PrintDebug("Asserting Browser Contains: #{event['assert']}\n");
         result['error'] = kindsOfBrowserAssert(event)
      end

      if (event.key?('assertnot'))
         @rep.log("Asserting browser does not Contain: " +
            " #{event['assertnot']}\n");
         event['assert'] = event['assertnot'] # hack #
         result['error'] = kindsOfBrowserAssert(event, false)
         event.delete('assert') # clean up hack #
      end

      if event.key?('send_keys')
         if ($win_only == true)
            case event['send_keys']
               when 'Ctrl+W'
                  send_keys("^{w}")
               when 'BACKSPACE'
                  send_keys("{BACKSPACE}")
               when 'ENTER'
                  send_keys("{ENTER}")
               else
                  send_keys(event['send_keys'])
                  #@rep.log("eventBrowser: Unknown send_key: " +
                  #   "\"#{event['send_keys']}.\n", SodaUtils::WARN)
            end
         else
            msg = "Failed: This method Windows support only!\n"
            @rep.ReportFailure(msg)
            result['error'] = -1
         end
      end

      return result
   end

############################################################################### 
# eventCSV -- Method
#     This method handles the csv file events.
#
# Params:
#     event: This is the event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventCSV(event)

      event['file'] = replaceVars(event['file'])
      getRightCSV(event) 
      csv = SodaCSV.new(event['file'])

      while (record = csv.nextRecord())
         setScriptVar(event['var'], record)
         
         if (event.key?('children'))
            handleEvents(cloneEvent(event['children']))
         end
      end
   end

############################################################################### 
# eventAttach - Method
#     This method attaches to a new browser window and then preforms the
#     all child in the new window.
#
# Params:
#     event: This is the soda <attach> event.
#
# Results:
#     None.
#
############################################################################### 
   def eventAttach(event)
      title = nil
      url = nil
      new_browser = nil
      old_browser = @browser

      PrintDebug("eventAttach: Starting.\n")
     
      begin
         if (event.key?('title'))
            title = replaceVars(event['title'])
            title = stringToRegex(title) 
            new_browser = @browser.attach(:title, title)
         elsif (event.key?('url'))
            url = replaceVars(event['url'])
            url = stringToRegex(url)
            new_browser = @browser.attach(:url, url)
         end
      rescue Exception=>e
         @rep.ReportException(e, @currentTestFile);

         e_dump = SodaUtils.DumpEvent(event)
         @rep.log("Event Dump From Exception: #{e_dump}!\n", 
            SodaUtils::EVENT)

         new_browser = nil
      end
      
      if (new_browser != nil)
         @browser = new_browser
         if (event.key?('children'))
            handleEvents(cloneEvent(event['children']))
         end

         @browser = old_browser
      end

      PrintDebug("eventAttach: Finished.\n")
   end

############################################################################### 
# eventRequires -- Method
#     This method handles the requires events.
#
# Params:
#     event: This is the event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventRequires(event)
      flav = nil

      flav = replaceVars(event['sugarflavor'])
      PrintDebug("Flavor: #{flav}\n")
 
      if (FlavorMatch(flav) == true)
         if (event.key?('children')) 
            handleEvents(cloneEvent(event['children']))
         else
            @rep.log("Found requires event without any children!\n", 
               SodaUtils::WARN)
            @rep.IncTestWarningCount()
         end 
      end
   end

   def eventCondition(event)
      
   end

############################################################################### 
# eventWhiteList -- Method
#     This method handles the whitelist soda event, by adding or deleting a
#     item to the whitelist at runtime.
#
# Input:
#     event: A soda whitelist event.
#
# Output:
#     None.
#
############################################################################### 
   def eventWhiteList(event)
      err = 0

      if (!event.key?('name'))
         @rep.ReportFailure("Missing 'name' attribute for whitelist tag!"+
            "  Line number: #{event['line_number']}!\n")
         err = -1
      elsif (!event.key?('action'))
         @rep.ReportFailure("Missing 'action' attribute for whitelist tag!"+
            "  Line number: #{event['line_number']}!\n")
         err = -1
      elsif (!event.key?('content') && event['action'] =~ /add/i)
          @rep.ReportFailure("Missing 'content' for whitelist tag!"+
            "  Line number: #{event['line_number']}!\n")
          err = -1
      end

      return if (err != 0)

      case (event['action'])
         when /add/i
            found_key = false

            @whiteList.each do |hash|
               next if (!hash.key?(event['name']))
               if (hash.key?(event['name']))
                  found_key = true
                  break
               end
            end      
            
            if (found_key)
               @rep.ReportFailure("Trying to add whitelist that already"+
                  " exists: '#{event['name']}'!\n")
            else
               new_white = {
                  'name' => event['name'],
                  'data' => event['content']
               }

               @whiteList.push(new_white)
               @rep.log("Adding data to whitelist: '#{new_white['name']}'.\n")
            end
         when /delete/i
            index = -1
            found_key = false

            @whiteList.each do |hash|
               index += 1
               next if (!hash.key?('name'))
               if (hash['name'] == event['name'])
                  found_key = true
                  break
               end
            end

            if (found_key)
               @whiteList.delete_at(index)
            else
               @rep.ReportFailure("Failed to find whitelist name: "+
                  "'#{event['name']}'!\n")
            end
      end
   end

############################################################################### 
############################################################################### 
   def eventDialog(event)
      win_handle = nil

      if (@current_os !~ /windows/i)
         @rep.ReportFailure("Using SODA dialog command on unsupported os:"+
            " '#{@current_os}'!\n")
         return -1
      end

      if (!event.key?('title'))
         @rep.ReportFailure("SODA: dialog command is missing the 'title' "+
            "attribute!\n")
         return -1
      end

      PrintDebug("Trying to connect to dialog: title => '#{event['title']}'.\n")
      for i in 0..10 do
         win_handle = @autoit.WinGetHandle(event['title'])
         if (win_handle.empty? || win_handle.length < 1)
            win_handle = nil
            sleep(1)
         else
            PrintDebug("Found dialog window handle: '#{win_handle}'.\n")
            break   
         end
      end

      if (win_handle == nil)
         @rep.ReportFailure("Failed to find dialog by title => "+
            "'#{event['title']}'!\n")
         return -1
      end

      if (!event.key?('children'))
         return 0
      end

      event['children'].each do |child|
         case (child['do'])
            when "sendkey"
               @autoit.WinActivate(event['title'], nil)
               sleep(1)
               @autoit.Send(child['key'])
            when "assert"
               sleep(1)
               @autoit.WinActivate(event['title'], nil)
               sleep(1)
               @autoit.Send("^a")
               sleep(1)
               @autoit.Send("^c")
               sleep(1)
               tmp = @autoit.ClipGet()
               if (tmp.empty? || tmp.length < 1)
                  @rep.ReportFailure("Failed to get text from dialog!\n")
                  next
               end

               if (SodaUtils.isRegex(child['value']))
                  child['value'] = stringToRegex(child['value'])
                  match = child['value'].match(tmp)
                  if (match == nil)
                     @rep.ReportFailure("Falied to match regex: "+
                        "'#{child['value']}' to dialog text '#{tmp}'"+
                        "!\n")
                     next
                  else
                     @rep.Assert(true, "Matched Regex: '#{child['value']}'"+
                        " to dialog text.\n") 
                  end
               else
                  @rep.Assert(child['value'] == tmp, "Checking that dialog"+
                     " matches value: '#{child['value']}'.\n")
               end
         end
      end
   end


############################################################################### 
############################################################################### 
   def eventRuby(event)
      result = 0

      if (event['content'].empty?)
         return 0
      end
      
      eresult = eval(event['content'])
      eresult = "#{eresult}"

      if (eresult != event['assert'])
         result = false
      else
         result = true
      end

      @rep.Assert(result, "Evaling ruby code results: Expecting:"+
         " \"#{event['assert']}\" found: \"#{eresult}\".\n", 
         @currentTestFile, "#{event['line_number']}")

   end

############################################################################### 
# eventScript -- Method
#     This method handles all script events.
#
# Params:
#     event: This is the event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventScript(event)
      results = 0

      if (event.key?('file'))
         # specified a new csv to file
         if (event.key?('csv'))
            event['csv'] = replaceVars(event['csv'])
            @newCSV.push({"#{event['file']}"=>"#{event['csv']}"})
         end
                                                 
         event['file'] = replaceVars(event['file'])
         @fileStack.push(event['file'])
         script = getScript(event['file'])
         if (script != nil)
            parent_script = @currentTestFile
            @currentTestFile = event['file']
            results = handleEvents(script)
            if (@currentTestFile !~ /lib/i && results != 0)
               @rep.IncFailedTest()
            else
               @rep.IncTestPassedCount() if (@currentTestFile !~ /lib/i)
            end
            @currentTestFile = parent_script
         else
            msg = "Failed opening script file: \"#{event['file']}\"!\n"
            @rep.ReportFailure(msg)
         end

         @fileStack.pop()
      end

      if (event.key?('fileset'))
         event['fileset'] = replaceVars(event['fileset'])
         @rep.log("Starting New Soda Fileset: #{event['fileset']}\n")
         getDirScript(event['fileset'])
         @rep.log("Fileset: #{event['fileset']} finished.\n")
      end  
   end

############################################################################### 
# CheckJavaScriptErrors -- Method
#     This function checks the current page for all javascript errors.
#
# Params:
#     None.
#
# Results:
#     Always returns 0.
#
############################################################################### 
   def CheckJavaScriptErrors()
      result = nil
      data = nil

      if (Watir::Browser.default == "firefox")
         result = @browser.execute_script(
            "#{SodaUtils::FIREFOX_JS_ERROR_CHECK_SRC}")
         data = result.split(/######/)
         data.each do |line|
            if ( (line != "") && 
               (line !~ /chrome:\/\/browser\/content\/tabbrowser\.xm/) &&
               (line !~ /SShStarter.js/i ))
               @rep.ReportJavaScriptError("Javascript Error:#{line}\n", 
                  $skip_css_errors)
               
            end
         end
      end

      return 0
   end 

############################################################################### 
# eventJavascript -- Method
#     This method handles all script events.
#
# Params:
#     event: This is the event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventJavascript(event)
      result = nil

      if (event['content'].length > 0)
        if (Watir::Browser.default == 'firefox')
         # Executing javascript from within the firefox window context 
         # (injection) requires firebug, for now.
          toExec = "";
          if (event.key?('addUtils') && (getStringBool(event['addUtils'])))
            event['content'] = SodaUtils::getSodaJS() + event['content'];
          end
          
          escapedContent = event['content'].gsub(/\\/, '\\').gsub(/"/, '\"');
          
          toExec = <<JSCode
if (typeof window.Firebug != "undefined") { 
   window.TabWatcher.watchBrowser(window.FirebugChrome.getCurrentBrowser());
   window.Firebug.minimizeBar();
   window.Firebug.CommandLine.evaluateInWebPage("#{escapedContent}", browser.contentDocument.defaultView);
   window.Firebug.closeFirebug();
}
JSCode
      
          result = @browser.execute_script(toExec)
        else
          escapedContent = event['content'].gsub(/\\/, '\\').gsub(/"/, '\"')
          toExec = 'browser.document.parentWindow.execScript("' + escapedContent + '")'
          result = @browser.execute_script(event['content'])
        end
         result = result.to_s()
         PrintDebug("JavaScript Results: \"#{result}\"\n")
      else
         @rep.log("No javascript source content found!", SodaUtils::ERROR)
         return -1
      end
      
      CheckJavaScriptErrors()
   end

############################################################################### 
# eventLink -- Method
#     This method handles the Link event.
#
# Params:
#     event: This is the soda event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventLink(event)
      field = nil

      field = getField(event) 
      return field
   end

############################################################################### 
# eventWait -- Method
#
#
# Results:
#     return true if a next should be called, else false.
#
#
############################################################################### 
   def eventWait(event)
      result = false

      RestartGlobalTime()

      if ( event.key?('condition') && 
           getStringBool(event['condition']) && 
           event.key?('children') )
                                               
         event['children'].each do |sub_event|
            @rep.log("Waiting Page Load: \n") 
            waitByMultipleCondition(sub_event, event['timeout'])
         end
         
         result = true
      elsif (event.key?('timeout'))
         @rep.log("Waiting Page Load: #{event['timeout']}s\n")
         sleep(Integer(event['timeout']))
         @rep.log("Page Load Finished.\n")
         result = true
      else
         @rep.log("Waiting Page Load: 10s\n")
         sleep(10)
         PrintDebug("Page Load Finished.\n")
         result = true
      end

      RestartGlobalTime()

      return result
   end

############################################################################### 
# eventVar -- Method
#     This method handles the var event.
#
# Params:
#     event: This is the event to handle.
#
############################################################################### 
   def eventVar(event)

      if (event['set'] == '#stamp#')
         event['set'] = Soda.getStamp()
      end

      if (event['set'] == '#rand#')
         event['set'] = rand(999999)
      end

      setScriptVar(event['var'], event['set']);

   end

############################################################################### 
# eventFileField -- Method:
#     This method handles the FileField event.
#
# Params:
#     event: THis is the soda event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventFileField(event)
      os = nil
      abs = nil
      upload_file = nil
      path = nil
      what = nil

      event['do'] = 'file_field'
      if (event.key?('set'))
         upload_file = event['set']
      else
         @rep.Assert(false, "eventFileField: 'set' is empty!\n",
            @currentTestFile)
         return -1
      end

      path = Pathname.new(upload_file)

      if (!path.absolute?)
         upload_file = "#{$SodaHome}/#{upload_file}"
      end

      os = SodaUtils.GetOsType
      if (os =~ /windows/i)
         upload_file = upload_file.gsub("/", "\\")
      end

      PrintDebug("Uploading file: \"#{upload_file}\"\n")

      if (event.key?("id"))
         what = replaceVars(event['id'])
         @browser.file_field(:id, "#{what}").set(upload_file)
      elsif (event.key?("value"))
         what = replaceVars(event['value'])
         @browser.file_field(:value, "#{what}").set(upload_file)
      elsif (event.key?("name"))
         what = replaceVars(event['name'])
         @browser.file_field(:name, "#{what}").set(upload_file)
      else
         @rep.log("Unable to find control accessor for FileField!\n",
            SodaUtils::ERROR)
      end
   end

############################################################################### 
# eventPuts -- Method
#     This method handles the puts event.
#
# Params:
#     event: The soda puts event.
#
# Results:
#     None.
#
############################################################################### 
   def eventPuts(event)
      if (event.key?('text'))
         temp = replaceVars(event['text'])
         @rep.log("#{temp}\n" )
      elsif (event.key?('var'))
         var = replaceVars(event['var']) 
         @rep.log("#{var}\n")        
      end
   end

############################################################################### 
# eventMouseClick -- Method
#     This method handles soda mouseclick events.  Currently this is only
#     supported on windows.
#
# Params:
#     event: This is the soda event to handle.
#
# Results:
#     None.
#
############################################################################### 
   def eventMouseClick(event)
      PrintDebug("eventMouseClick: Starting.\n")
      if ($win_only == true)
         if (event.key?('xpos') && event.key?('ypos'))
            MouseClick(event['xpos'],event['ypos']);
         end                                          
       else 
         msg = "eventMouseClick Failed: This method Windows support only!\n"
         @rep.ReportFailure(msg)
       end

      PrintDebug("eventMouseClick: Finished.\n")
   end

############################################################################### 
# eventFieldAction -- Method
#  
#
# returns true of jsevent was fired.
############################################################################### 
   def eventFieldAction(event, fieldType)
      js = nil
      js_fired = false
      result = nil
      foundaction = nil
      foundvalue = nil
      fieldactions = [
         'clear',
         'focus',
         'click',
         'set',
         'assert',
         'assertnot',
         'include',
         'noninclude',
         'var',
         'vartext',
         'children',
         'button',
         'exists',
         'link',
         'append',
         'disabled',
         'jscriptevent'
         ]
   
      if (@SIGNAL_STOP != false)
         exit(-1)
      end

      fieldactions.each do |action|
         if (event.key?(action))
            foundaction = action
            break
         end
      end

      if (foundaction == nil)
         foundaction = event['do']
      end

      if (event.key?("alert"))
       if (event['alert'] =~ /true/i)
          @rep.log("Enabling Alert Hack\n")
          fieldType.alertHack(true, true) 
       else
          fieldType.alertHack(false, false)
          @rep.log("Disabeling alert!\n")
          PrintDebug("eventFieldAction: Finished.\n")
          return
       end
      end

      if (event.key?("jscriptevent"))
         js = replaceVars(event['jscriptevent'])
      end

      case (foundaction)
         when "jscriptevent"
            fieldType.jsevent(@curEl, js, true)
            js_fired = true
         when "append"
            result = fieldType.append(@curEl, replaceVars(event['append']))
            if (result != 0)
               event['current_test_file'] = @currentTestFile
               e_dump = SodaUtils.DumpEvent(event)
               @rep.log("Event Dump: #{e_dump}\n", SodaUtils::EVENT)     
            end
         when "button"
            fieldType.click(@curEl, @SugarWait)
            @browser.wait()
            if (event['assertPage'] == nil || event['assertPage'] != "false")
               assertPage()
            end
         when "link"
            if ( (js != nil) && (js =~ /onmouseover/i) )
               jswait = true
               if (event.key?('jswait'))
                  jswait = false if (event['jswait'] =~ /false/i)
               end
               fieldType.jsevent(@curEl, js, jswait)
            end
            fieldType.click(@curEl, @SugarWait)
            @browser.wait()
            if (event['assertPage'] == nil || event['assertPage'] != "false")
               assertPage()
            end
         when "clear"
            if(event['clear'])
               event['clear'] = replaceVars(event['clear'])
               case event['clear']
                  when /true/i
                     PrintDebug("Clearing field\n")
                     fieldType.clear(@curEl)
                  when /false/i
                     PrintDebug("Skipping field clearing event as its value" +
                        " was: \"#{event['clear']}\".\n")
                  else
                     @rep.log("Found unsupported value for <textfield clear" +
                        "=\"true/false\" />!\n", SodaUtils::WARN)
                     @rep.IncTestWarningCount()
                     @rep.log("Unsupported clear value =>" +
                        " \"#{event['clear']}\".\n", SodaUtils::WARN)
                     @rep.IncTestWarningCount()
               end
            end
         when "focus"
            if (event['focus'])
               PrintDebug("Setting focus\n")
               fieldType.focus(@curEl)
            end
         when "radio"
            if (!fieldType.getStringTrue(event['set']) && 
                  @autoClick[event['do']])
               fieldType.click(@curEl, @SugarWait)
               @browser.wait()
            end
         when "click"
            if ( (fieldType.getStringTrue(event['click'])) ||
                  (!event.key?('click') && @autoClick[event['do']]) )

               PrintDebug("Performing click\n")
               fieldType.click(@curEl, @SugarWait)
               @browser.wait()
               if (event['assertPage'] == nil || event['assertPage'] != "false")
                  assertPage()
               end
            end
         when "set"
            if (@curEl.class.to_s =~ /textfield/i)
               result = fieldType.set(@curEl, event['set'], @nonzippytext)
            else
               result = fieldType.set(@curEl, event['set'])
            end

            if (result != 0)
               event['current_test_file'] = @currentTestFile
               e_dump = SodaUtils.DumpEvent(event)
               @rep.log("Event Dump: #{e_dump}\n", SodaUtils::EVENT)
            end
         when "assert"
            fieldEventAssert(event, fieldType)
         when "assertnot"
            fieldEventAssert(event, fieldType)
         when "include"
            event['include'] = stringToRegex(event['include'])
            event['include'] = replaceVars(event['include'])
            @rep.log("Asserting Exist Option: #{event['include']}\n")
            @contents = SodaSelectField.getAllContents(@curEl)
            @rep.Assert(checkSelectList(@contents, event['include']),
               @currentTestFile)
         when "noninclude"
            event['noninclude'] = stringToRegex(event['noninclude'])
            event['noninclude'] = replaceVars(event['noninclude'])
            @rep.log("Asserting Not Exist Option: " +
               "#{event['noninclude']}", SodaUtils::ERROR)
            @contents = SodaSelectField.getAllContents(@curEl)
            @rep.Assert(!(checkSelectList(@contents, event['noninclude'])),
               @currentTestFile)
         when "var"
            setScriptVar(event['var'], fieldType.getValue(@curEl))
         when "vartext"
            setScriptVar(event['vartext'], fieldType.getText(@curEl))
         when "children"
            @parentEl.push(@curEl)
            handleEvents(event['children'])
            @parentEl.pop()
         when "disabled"
            event['disabled'] = getStringBool(event['disabled'])
            FieldUtils.CheckDisabled(@curEl, event['disabled'], @rep)
         when "exists"
            # do nothing #
         else
            msg = "Failed to find supported field action.\n"
            @rep.log(msg, SodaUtils::WARN)
            @rep.IncTestWarningCount()
            e_dump = SodaUtils.DumpEvent(event)
            @rep.log("Event Dump: #{e_dump}\n", SodaUtils::EVENT)
      end

      return js_fired
   end

############################################################################### 
# fieldEventAssert -- Method
#     This method handles the field action 'assert'.
#
# Params:
#     event: The soda event with the field action 'assert'.
#
# Results:
#     None.
#
############################################################################### 
   def fieldEventAssert(event, fieldType)
      msg = ""
      assert_type = ""
      result = 0

      if (event.key?('assertnot'))
         assert_type = 'assertnot'
      else
         assert_type = event['assert']
      end

      case assert_type
         when /assertnot/i
            contains = replaceVars(event['assertnot'] )
            msg = "Asserting that value doesn't exist: \"#{contains}\""
            @rep.log("#{msg}\n")
            result = @rep.Assert(!(fieldType.assert(@curEl, contains)), msg,
               @currentTestFile, "#{event['line_number']}")
         when /enabled/i
            msg = "Asserting that Element is enabled."
            @rep.log("#{msg}\n")
            result = @rep.Assert(fieldType.enabled(@curEl), msg, 
                  @currentTestFile, "#{event['line_number']}")
         when /disabled/i
            msg = "Asserting that Element is disabled."
            @rep.log("#{msg}\n")
            result = @rep.Assert(fieldType.disabled(@curEl), msg, 
                  @currentTestFile, "#{event['line_number']}")
         else
            contains = replaceVars(event['assert'])
            @rep.log("Asserting value: #{contains}\n")
            msg = "Asserting that value: \"#{contains}\" exists."
            result = @rep.Assert(fieldType.assert(@curEl, contains), msg,
               @currentTestFile, "#{event['line_number']}")
      end

      if (result != 0)
         @FAILEDTESTS.push(@currentTestFile)
      end

   end

###############################################################################
# crazyEvilIETabHack -- Method
#     This method make ie's tab pages act like firefox's in the since that,
#     when a new tab is opened in ie and that new tab has focus watir doesn't 
#     notice and keeps working on the browser tab that isn't in focus anymore.
#     Yes this is totally lame, but here is the hack to make it work.
#
# Note:
#     Because the window handle is the same for the tabbed window I really
#     didn't need to go through all of the trouble, I could have just 
#     reattached to the same hwnd and this would have all worked, but then
#     this code would not be able to support when we are going to no be using
#     tab's.  Really we should not be using tabs anymore anyway!
#
# Params:
#     None.
#
# Results:
#     Always returns 0.
#
###############################################################################
   def crazyEvilIETabHack()
      if(Watir::Browser.default !~ /ie/i)
         return 0
      end

      if (@ieHwnd != 0)
         ie_count = 0
         
         Watir::IE.each do |tab|
            ie_count += 1
         end

         if ((ie_count == 1) && (@ieHwnd != 0))
            @browser = Watir::Browser.attach(:hwnd, @ieHwnd)
            PrintDebug("IE hack: switching back to parent window handle:" +
               " \"#{@ieHwnd}\".\n")
            @ieHwnd = 0
        end
      end
     
      Watir::IE.each do |tab|
         url = tab.url
         if ( (url =~ /popup/i) && (@ieHwnd == 0))
            @ieHwnd = @browser.hwnd()
            @browser = Watir::Browser.attach(:hwnd, tab.hwnd)
            tmp_hwnd = @browser.hwnd()
            PrintDebug("IE hack: found popup window switching from parent"+
               " handle: \"#{@ieHwnd}\" to popup handle: \"#{tab.hwnd}\".\n")
            break
         end
      end

     return 0
   end

############################################################################### 
# handleEvents -- Method
#     This is the heart of event handling used as a switch statement instand
#     of classes  to keep it simple for QA to modify.
#
# Params:
#     events: The result of the getScript method, really all the xml events. 
#
# Results:
#     A big flip'n sloppy mess!
#
# Notes:
#     Total hack!  This needs to be redone from the ground up it is a total
#     sloppy mess!
#
############################################################################### 
   def handleEvents(events)
      browser_closed = false
      result = 0
      jswait = true
      result = 0
      js_fired = false
      exception_event = nil 

      for next_event in events
         if (@exceptionExit != false)
            @rep.log("Exception occured, now exiting...\n")
            @exceptionExit = false
            return -1
         end

         events = getEvents(next_event)

         for event in events
         begin
            @rep.AddEventCount()
            @curEl = nil
            fieldType = nil
    
            event = SodaUtils.ConvertOldAssert(event, @rep, @currentTestFile)
            RestartGlobalTime()
            crazyEvilIETabHack() 

            if (event.key?('set') && event['set'].is_a?(String) && 
               event['set'].index('{@') != nil)

               default = event.key?('default')?event['default']: ''
               var_temp = replaceVars(event['set'], default)

               # if set nil to object, nothing to do just skip
               if (var_temp == nil)
                  break
               end

               event['set'] = var_temp
            end

            if (event.key?('assert')) 
               event['assert'] = replaceVars(event['assert'])
               event['assert'] = stringToRegex(event['assert'])
            elsif (event.key?('assertnot'))
               event['assertnot'] = replaceVars(event['assertnot'])
               event['assertnot'] = stringToRegex(event['assertnot'])
            end 
           
            case event['do']
               when "exception"
                  PrintDebug("Found Exception Handler.\n")
                  exception_event = event
                  next
               when "breakexit"
                  @breakExit = true
                  next
               when "dialog"
                  eventDialog(event)
                  next
               when "whitelist"
                  eventWhiteList(event)
                  next
               when "sugarwait"
                  SodaUtils.WaitSugarAjaxDone(@browser, @rep)
                  next
               when "condition"
                  eventCondition(event)
                  next
               when "ruby"
                  eventRuby(event)
                  next
               when "wait"
                  if (eventWait(event) == true) 
                     next
                  end
               when "browser" 
                  err = eventBrowser(event)
                  if (err['error'] != 0)
                     result = -1
                  end

                  next 
               when "requires"
                  eventRequires(event)
                  next 
               when "attach"
                  eventAttach(event)
                  next
               when "csv"
                  eventCSV(event) 
                  next
               when "comment"
                  next
               when "timestamp"
                  @vars['stamp'] = Time.now().strftime("%y%m%d_%H%M%S")
                  next
               when "script"
                  eventScript(event)
                  next
               when "var"
                  eventVar(event)
                  next
               when "javascript"
                  eventJavascript(event)
                  next
               when "puts"
                  eventPuts(event)
                  next 
               when "mouseclick" 
                  eventMouseClick(event)
                  next
               when "filefield"
                  fieldType = SodaFileField
                  eventFileField(event)
                  next 
               when "textfield"
                  fieldType = SodaField
                  event['do'] = 'text_field'
                  @curEl = getField(event)
               when "textarea" 
                  fieldType = SodaField
                  event['do'] = 'text_field'
                  @curEl = getField(event)
               when "checkbox"
                  fieldType = SodaCheckBoxField
                  event['do'] = 'checkbox'
                  @curEl = getField(event)
               when "select"
                  fieldType = SodaSelectField
                  event['do'] = 'select_list'
                  @curEl = getField(event)
              when "radio"
                  fieldType = SodaRadioField
                  event['do'] = 'radio'
                  @curEl = getField(event)
               when "link"
                  fieldType = SodaField 
                  @curEl = eventLink(event)
               when "td"
                  fieldType = SodaField
                  event['do'] = 'cell'
                  @curEl = getField(event)
               when "tr"
                  fieldType = SodaField
                  event['do'] = 'row'
                  @curEl = getField(event)
               when "div"
                  fieldType = SodaField
                  @curEl = getField(event)
               when "hidden"
                  fieldType = SodaField
                  @curEl = getField(event)
               when "li"
                  fieldType = SodaLiField
                  @curEl = getField(event)
               else
                  if (@SIGNAL_STOP != false)
                     exit(-1)
                  end
                 
                  # if its none of the above assume it is a field
                  fieldType = SodaField
                  @curEl = getField(event)
            end # end case #

            if ( (@curEl == nil) && (event['required'] == false) )
               next
            end

            if (@curEl == nil)
               if (event.key?("exists"))
                  exists = getStringBool(event['exists'])
                 
                  if (exists != false)
                     e_dump = SodaUtils.DumpEvent(event)
                     @rep.log("No Element found for event!\n", 
                        SodaUtils::ERROR)
                     @rep.rep
                     @rep.log("Event Dump for unfound element: #{e_dump}!\n", 
                        SodaUtils::EVENT)
                  end
               else
                  e_dump = SodaUtils.DumpEvent(event)
                  @rep.ReportFailure("No Element found for event!\n")
                  @rep.log("Event Dump for unfound element: #{e_dump}!\n", 
                     SodaUtils::EVENT)
               end

               next
            end

            # If we have a field here is the default actions 
            # that can be done on it 
            if (@curEl)
               js_fired = eventFieldAction(event, fieldType)
            end

            jswait = true
            if (event.key?("jscriptevent") && (js_fired != true) && 
               (replaceVars(event['jscriptevent']) == "onkeyup"))
               if (event.key?('jswait'))
                  jswait = false if (event['jswait'] =~ /false/i)
               end

               js = replaceVars(event['jscriptevent'])
               fieldType.jsevent(@curEl, js, jswait)
            elsif (event.key?("jscriptevent") && (js_fired != true))
               if (event.key?('jswait'))
                  jswait = false if (event['jswait'] =~ /false/i)
               end
               js = replaceVars(event['jscriptevent'])
               fieldType.jsevent(@curEl, js, jswait)
            end

            if (browser_closed != true && jswait != false)
               CheckJavaScriptErrors()
            end

            rescue Exception=>e
               @FAILEDTESTS.push(@currentTestFile)
               @exceptionExit = true
               @rep.log("Exception in test: \"#{@currentTestFile}\", Line: " +
                  "#{event['line_number']}!\n", SodaUtils::ERROR)
               @rep.ReportException(e, @fileStack[@fileStack.length - 1]);
               e_dump = SodaUtils.DumpEvent(event)
               @rep.log("Event Dump From Exception: #{e_dump}!\n", 
                  SodaUtils::EVENT)

               if (exception_event != nil)
                  @rep.log("Running Exception Handler.\n", SodaUtils::WARN)
                  @rep.IncTestWarningCount()
                  @exceptionExit = false
                  handleEvents(exception_event['children'])
                  @rep.log("Finished Exception Handler.\n", SodaUtils::WARN)
                  @rep.IncTestWarningCount()
                  @exceptionExit = true
               end

               result = -1
            ensure
               if (@exceptionExit)
                  @exceptionExit = false
                  return -1
               end
            end # end rescue & ensure #
         end # end event's for loop #
      end # end top most for loop #


      if (exception_event != nil)
         if (exception_event.key?('alwaysrun'))
            run = getStringBool(exception_event['alwaysrun'])
            if (run)
               PrintDebug("Exception Handler: alwaysrun = '#{run}'.\n")
               PrintDebug("Running Exception Handler.\n")
               result  = handleEvents(exception_event['children'])
               PrintDebug("Exception Handler: Finished.\n")
            end
         end
      end

      return result
   end

############################################################################### 
# SetReporter -- method
#     This method sets the reporter object for soda.  Really only used for
#     sodamachine.
#
# Input:
#     reporter: This is the reporter object for soda to use.
#
# Results:
#     None.
#
############################################################################### 
   def SetReporter(reporter)
      @rep = reporter
   end

############################################################################### 
# run -- Method
#     This method executes a test file.
#
# Params:
#     file: The Soda test file.
#     rerun: true/false, this tells soda that this tests is a rerun of a
#        failed test.
#     suitename: The name of the suite to group the results into.
#
# Results:
#     returns a SodaReport object.
#
############################################################################### 
   def run(file, rerun = false, genhtml = true, suitename = nil)
      result = 0
      master_result = 0
      thread_soda = nil
      thread_timeout = (60 * 10) # 10 minutes #
      time_check = nil
      resultsdir = nil
      blocked = false

      if (suitename != nil)
         resultsdir = "#{@resultsDir}/#{suitename}"
      else
         resultsdir = @resultsDir
      end

      @currentTestFile = file
      @exceptionExit = false      
      @fileStack.push(file)

      if (@browser == nil)
         NewBrowser()
      end

      @rep = SodaReporter.new(file, @saveHtml, resultsdir, 0, nil, rerun);
      SetGlobalVars()
      blocked = remBlockScript(file)
      
      if (!blocked)
         script = getScript(file)
      else 
         script = nil
      end

      if (script != nil) 
         @currentTestFile = file
         thread_soda = Thread.new {
            result = handleEvents(script)
         }

         while (thread_soda.alive?)
            $mutex.synchronize {
               time_check = Time.now()
               time_diff = time_check - $global_time
               time_diff = Integer(time_diff)

               if (time_diff >= thread_timeout)
                  msg = "Soda watchdog timed out after #{time_diff} seconds!\n"
                  @rep.ReportFailure(msg)
                  PrintDebug("Global Time was: #{$global_time}\n")
                  PrintDebug("Timeout Time was: #{time_check}\n")
                  @rep.IncTestWatchDogCount()
                  begin
                     result_dir = @rep.GetResultDir()
                     shooter = SodaScreenShot.new(result_dir)
                     image_file = shooter.GetOutputFile()
                     @rep.log("ScreenShot taken: #{image_file}\n")
                  rescue  Exception => e
                     @rep.ReportException(e)
                  ensure
                  end

                  result = -1
                  thread_soda.exit()
                  break
               end
            }
            sleep(10)
         end

         if (result != -1)
            thread_soda.join()
         end

         if (result != 0)
            master_result = -1
         else
            @rep.IncTestPassedCount()
         end
      else
         if (!blocked)
            msg = "Failed trying to run soda test: \"#{@currentTestFile}\"!\n"
            @rep.IncFailedTest()
            @rep.ReportFailure(msg)
         end
      end

      @rep.SodaPrintCurrentReport()
      @rep.EndTestReport()
      @rep.ReportHTML() if (genhtml)

      return master_result
   end

############################################################################### 
# RunAllSuites -- Method
#     This function run a list of suite files as suites, not as tests.
#
# Input:
#     suites: An array of Soda suite files to be ran.
#
# Output:
#     returns a hash with the results from the ran suites.
#
###############################################################################
   def RunAllSuites(suites)
      results = {}
      err = 0
      indent = " " * 2
      indent2 = "#{indent}" * 2
      indent3 = "#{indent}" * 4
      hostname = `hostname`
      hostname = hostname.chomp()

      suites.each do |s|
         base_suite_name = File.basename(s)
         RestartGlobalTime()
         results[base_suite_name] = RunSuite(s)
         RestartGlobalTime()
      end

      time = Time.now()
      time = "#{time.to_i}-#{time.usec}"
      suite_report = "#{@resultsDir}/#{hostname}-#{time}-suite.xml"
      fd = File.new(suite_report, "w+")
      fd.write("<data>\n")

      RestartGlobalTime()

      results.each do |k,v|
         fd.write("\t<suite>\n")
         fd.write("\t#{indent}<suitefile>#{k}</suitefile>\n")
         v.each do |testname, testhash|
            fd.write("\t#{indent2}<test>\n")
            fd.write("\t#{indent3}<testfile>#{testname}</testfile>\n")
            testhash.each do |tname, tvalue|
               if (tname == "result")
                  err = -1 if (tvalue.to_i != 0)
               end
               new_name = "#{tname}"
               new_name = new_name.gsub(" ", "_")
               fd.write("\t#{indent3}<#{new_name}>#{tvalue}</#{new_name}>\n")
            end
            fd.write("\t#{indent2}</test>\n")
         end
         fd.write("\t</suite>\n")
      end
      fd.write("</data>\n")
      fd.close()

      RestartGlobalTime()

      return err
   end

############################################################################### 
#
############################################################################### 
   def RunSuite(suitefile)
      parser = nil
      doc = nil
      test_order = 0
      test_since_restart = 0
      result = {}
      tests = []
      suite_name = File.basename(suitefile, ".xml")
      
      begin
         parser = LibXML::XML::Parser.file(suitefile)
         doc = parser.parse()
         doc = doc.root()

         doc.each do |node|
            next if (node.name !~ /script/)
            attrs = node.attributes()
            attrs = attrs.to_h()

            if (attrs.key?('file'))
               tests.push(attrs['file'])
            elsif (attrs.key?('fileset'))
               files = File.join(attrs['fileset'], "*.xml")
               files = Dir.glob(files).sort_by{|f| File.stat(f).mtime}
               files.each do |f|
                  tests.push(f)
               end
            end
         end
      rescue Exception => e
         print "ERROR: #{e.message}!\n"
         print e.backtrace.join("\n")
         result = nil
      ensure
      end   

      tests.each do |test|
         if ((@restart_count > 0) && (test_since_restart >= @restart_count))
            RestartBrowserTest(suite_name)
            test_since_restart = 0
            print "(*)Restarted browser.\n"
         end

         test_order += 1
         tmp_result = {}
         tmp_result['result'] = run(test, false, true, suite_name)
         tmp_result['Test_Order'] = test_order
         tmp_result.merge!(@rep.GetRawResults)
         
         if (tmp_result['Test Failure Count'].to_i != 0)
            tmp_result['result'] = -1
         elsif (tmp_result['Test JavaScript Error Count'].to_i != 0)
            tmp_result['result'] = -1
         elsif (tmp_result['Test Assert Failures'].to_i != 0)
            tmp_result['result'] = -1
         elsif (tmp_result['Test Exceptions'].to_i != 0)
            tmp_result['result'] = -1
         end

         tmp_result['Real_Test_Name'] = test
         test_basename = File.basename(test, ".xml")
         logfile = tmp_result['Test Log File']
         if (logfile =~ /#{test_basename}-\d+/)
            test =~ /(.*\/)#{test_basename}/
            ran_test_name = $1
            ran_test_name << File.basename(logfile, ".log")
            ran_test_name << ".xml"
         else
            ran_test_name = test
         end

         result[ran_test_name] = tmp_result
         @rep.ZeroTestResults()

         test_dir = File.dirname(test)
         if (test_dir !~ /lib/i)
            test_since_restart += 1
         end
      end

      return result
   end

############################################################################### 
# GetCurrentBrowser -- Method
#     This method get the current Watir browser object.
#
# Input:
#     None.
#
# Output:
#     Returns the current watir browser object.
#
############################################################################### 
   def GetBrowser()
      return @browser
   end

end

end


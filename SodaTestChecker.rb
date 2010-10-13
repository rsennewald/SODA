#!/usr/bin/env ruby
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
# Need Ruby Libs:
###############################################################################
require 'rubygems'
require 'getoptlong'
require 'digest/md5'
require 'libxml'
require 'SodaXML'

###############################################################################
# Global Data:
###############################################################################
$SODA_ELEMENTS_FILE = "SodaElements.xml"
$ERROR_COUNT = 0

###############################################################################
# ParseSodaElementsXML -- function
#     This finction parses the SodaElements.xml file.
#
# Input:
#     None.
#
# Output:
#     returns the doc.root from the XML parser.
#
###############################################################################
def ParseSodaElementsXML()
   parser = nil
   doc = nil
   kids = nil

   begin
      LibXML::XML.default_line_numbers = true
      parser = LibXML::XML::Parser.file($SODA_ELEMENTS_FILE)
      doc = parser.parse()
   rescue Exception => e
      print "Error: #{e.message}!\n"
      $ERROR_COUNT += 1
   end

   return doc.root

end

###############################################################################
# ElementsXMLToData -- function
#     This function generates a hash of the SodaElements.xml file.
#
# Input:
#     node: this is the root node from the xml parser.
#
# Output:
#    returns a hash of the xml node. 
#
###############################################################################
def ElementsXMLToData(node)
   elements = {}
   kids = nil

   if (!node.children?)
      return {}
   end

   kids = node.children()
   kids.each do |kid|
      next if ( (kid.name == "text") || (!kid.children?) )

      elements[kid.name] = Hash.new()
      elements[kid.name]['accessor_attributes'] = []
      elements[kid.name]['soda_attributes'] = []
      
      elems = kid.children()
      elems.each do |e|
         case (e.name)
            when "accessor_attributes"
               access_kids = e.children()
               access_kids.each do |access|
                  next if (access.name == "text")
                  elements[kid.name]["accessor_attributes"].push(access.content)
               end
            when "soda_attributes"
               access_kids = e.children()
               access_kids.each do |access|
                  next if (access.name == "text")

                  if (access.name =~ /accessor/)
                     elements[kid.name]["soda_attributes"].push(access.content)
                  end

                  if (access.children?)
                     access_kids = access.children()
                     tmp_hash = {}
                     tmp_hash[access.name] = [] 
                     access_kids.each do |access_kid|
                        next if (access_kid.name == "text")
                        tmp_hash[access.name].push(access_kid.content)
                     end
                     elements[kid.name]["soda_attributes"].push(tmp_hash)
                  else
                     print "Content!\n"
                     elements[kid.name]["soda_attributes"].push(access.content)
                  end
               end
         end
      end
   end

   return elements

end

###############################################################################
# ProcessSodaTestFile -- function
#     This function parses a soda test into an array of hashes, using the
#     same SodaXML class that Soda uses, so there is a 1 to 1 on all data.
#
# Input:
#     file: this is a soda test file.
#
# Output:
#     returns an array of hashes, or nil on error.
#
###############################################################################
def ProcessSodaTestFile(file)
   data = nil

   begin
      data = SodaXML.new.parse(file)
   rescue Exception => e
      $ERROR_COUNT += 1
      print "(!)Error: parsing file: '#{file}'!\n"
      print "(!)Exception: #{e.message}!\n"
      data = nil
   ensure

   end

   return data
end

###############################################################################
# CheckTest -- function
#     This function checks a soda test against the SodaElements.xml file to
#     ensure that the tests is not using unsupported XML.
#
# Input:
#     sodadata: This is an array of hashes from ProcessSodaTestFile().
#     supported: This is the hash of the SodaElements.xml file.
#
# Results:
#     None.
#
###############################################################################
def CheckTest(sodadata, supported)
 
   sodadata.each do |test_hash|
      if (!test_hash.key?('do'))
         print "(!)Error: Failed to find expected test do element for test:"+
            " #{file}, line: #{test_hash['line_number']}!\n"
         next
      end

      test_element = test_hash['do']
      next if (test_element == "comment")
      test_hash.delete('do')

      if (!supported.key?("#{test_element}"))
         print "(!)Error: Failed to find a supported Soda element for:"+
            " '#{test_element}', line: #{test_hash['line_number']}!\n"
            $ERROR_COUNT += 1
         next
      end

      if (test_hash.key?('children'))
         result = CheckTest(test_hash['children'], supported)
         test_hash.delete('children')
      end

      test_hash.each do |test_key, test_value|
         found_accessor = false
         found_soda_accrssor = false

         next if (test_key =~ /line_number/)
         
         supported[test_element]['accessor_attributes'].each do |acc|
            if (test_key == acc)
               found_accessor = true
               break
            end
         end

         supported[test_element]['soda_attributes'].each do |acc|
            if (acc.kind_of?(String))
               if (test_key == acc)
                  found_soda_accrssor = true
                  break
               end
            elsif (acc.kind_of?(Hash))
               if (acc.key?("#{test_key}"))
                  acc[test_key].each do |action|
                     if (test_value == action)
                        found_soda_accrssor = true
                        break
                     end
                  end

                  if (!found_soda_accrssor)
                     print "(!)Error: Faild to find supported action for "+
                        "Soda element: '#{test_element}', attribte: "+
                        "'#{test_key}', action: '#{test_value}', line:"+
                        " #{test_hash['line_number']}!\n"

                        $ERROR_COUNT += 1
                     break
                  end
               end
            end
         end

         if ( (found_accessor != true) && (found_soda_accrssor != true) )
            print "(!)Error: Failed to find supported accessor: '#{test_key}'"+
               " for Soda element: '#{test_element}', line: "+
               "#{test_hash['line_number']}!\n"

            $ERROR_COUNT += 1
         end
         
      end
   end
end

###############################################################################
# PrintHelp -- function
#     This function prints the help message for this script.
#
# Input:
#     None.
#
# Output:
#     always returns 0.
#
###############################################################################
def PrintHelp()
   msg = <<HELP
Usage:
#{$0} --test=mysodatest.xml

Flags:
   --test: This sets a soda test file to be checked, this flag can be used
      more then once.

   --help: Prints this message.\n\n
HELP

   print msg

   return 0
end

###############################################################################
# CheckFileformat -- function
#     This function checks to make sure that the test file format is not DOS.
#
# Input:
#     file: the file to check.
#
# Output:
#     Always returns 0.
#
###############################################################################
def CheckFileformat(file)

   begin 
      fd = File.open(file, "r")
      line = fd.readline()
      fd.close()

      if (line =~ /\r\n$/)
         print "(!)Error: File is in DOS format!\n"
         $ERROR_COUNT += 1
      end
   rescue Exception => e
      print "(!)Error with file: '#{file}'!\n"
      print "(!)Exception: #{e.message}!\n"
      $ERROR_COUNT += 1
   ensure

   end

   return 0
end

###############################################################################
# CreateMD5Sum -- function
#     This function creates an md5 hex sum string for a given file.
#
# Input:
#     file: this is the test file sum.
#
# Output:
#     returns a string of hex chars: aka an md5sum.
#
###############################################################################
def CreateMD5Sum(file)
   digest = nil

   digest = Digest::MD5.hexdigest(File.read(file))

   return digest
end

###############################################################################
# Main -- function
#     This is a C like main function for easy debugging and script execution.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
def Main()
   opts = nil
   tests = []
   elements_root = nil
   elements_data = nil
   break_line = "#" * 80
   skip = false

   $stderr.reopen($stdout) # because I'm evil.... #

   begin
      opts = GetoptLong.new(
            [ '--test', '-t', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--help', '-h', GetoptLong::OPTIONAL_ARGUMENT ],
            [ '--skipgood', '-s', GetoptLong::OPTIONAL_ARGUMENT]
         )

      opts.quiet = true
      opts.each do |opt, arg|
         case (opt)
            when "--skipgood"
               skip = true
            when "--test"
               tests.push(arg)
            when "--help"
               PrintHelp()
               exit(0)
         end
      end
   rescue Exception => e
      print "Error: #{e.message}!\n"
      exit(-1)
   end

   if (tests.length < 1)
      print "Error: Missing --test flag!\n\n"
      PrintHelp()
      exit(-1)
   end

   if (!File.exist?($SODA_ELEMENTS_FILE))
      print "Error: can't find needed file: '#{$SODA_ELEMENTS_FILE}'!\n"
      exit(-1)
   end

   elements_root = ParseSodaElementsXML()
   elements_data = ElementsXMLToData(elements_root)

   tests.each do |test_file|
      $ERROR_COUNT = 0
      good_parse = false

      print "#{break_line}\n" if(!skip)
      print "(*)Checking File: #{test_file}\n" if (skip != true)
      CheckFileformat(test_file)
      sodadata = ProcessSodaTestFile(test_file)
      if (sodadata == nil)
         print "(!)Error: Failed to parse soda test file!\n"
         $ERROR_COUNT += 1
         good_parse = false
      else
         good_parse = true
      end

      if (good_parse)
         CheckTest(sodadata, elements_data)
      end

      print "(*)Error Count: #{$ERROR_COUNT}\n" if (skip != true)
      if ($ERROR_COUNT == 0)
         if (skip != true)
            print "(*)Test Status: GOOD.\n"
            md5 = CreateMD5Sum(test_file)
            print "(*)MD5: #{md5}\n"
         end
      else
         print "(*)Test Status: BAD!\n"
      end
      t = Time.now()
      if (skip != true)
         print "(*)Check Time: #{t}\n"
         print "(*)Finished check.\n"
         print "#{break_line}\n\n"
      end
   end
  
   if ($ERROR_COUNT > 0)
      exit(-1)
   end

end

###############################################################################
# Start Executing code here -->
###############################################################################
   Main()
   exit(0)


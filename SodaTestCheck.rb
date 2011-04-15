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
require 'SodaXML'
require 'SodaUtils'

###############################################################################
###############################################################################
class SodaTestCheck

   CONFIG_FILE = File.dirname(__FILE__)

   def initialize(sodatest, reportobj)
      err = 0
      sodadata = nil
      @SODA_ELEMENTS_FILE = "#{CONFIG_FILE}/SodaElements.xml"
      $ERROR_COUNT = 0
      @report = reportobj
      @sodatest = sodatest
   end

###############################################################################
###############################################################################
   def Check()
      err = 0
      elements_root = nil
      elements_data = nil
      sodadata = nil
      msg = ""
      
      if (!File.exist?(@SODA_ELEMENTS_FILE))
         msg = "Error: can't find needed file: '#{@SODA_ELEMENTS_FILE}'!\n"
         @report.ReportFailure(msg)
         return false
      end
   
      elements_root = ParseSodaElementsXML()
      if (elements_root == nil)
         return false
      end

      elements_data = ElementsXMLToData(elements_root)
      if (elements_data.empty?)
         msg = "Error: XML element data is empty!\n"
         @report.ReportFailure(msg)
         return false
      end

      err = CheckFileformat(@sodatest)
      if (err != 0)
         return false
      end

      sodadata = ProcessSodaTestFile(@sodatest)
      if (sodadata == nil)
         return false
      end

      CheckTest(sodadata, elements_data)
      if ($ERROR_COUNT > 0) 
         return false
      else
         return true
      end
   end
   public :Check

###############################################################################
# ParseSodaElementsXML -- method
#     This finction parses the SodaElements.xml file.
#
# Input:
#     None.
#
# Output:
#     returns the doc.root from the XML parser, or nil on error.
#
###############################################################################
   def ParseSodaElementsXML()
      parser = nil
      doc = nil
      kids = nil
      fd = nil

      begin
         fd = File.new(@SODA_ELEMENTS_FILE)
         doc = REXML::Document.new(fd)
         doc = doc.root
      rescue Exception => e
         doc = nil
         @report.ReportException(e, @sodatest)
      ensure
      end

      return nil if (doc == nil)
      return doc
   end
###############################################################################
# ElementsXMLToData -- method
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

      if (!node.has_elements?)
         return {}
      end

      kids = node.elements()
      kids.each do |kid|
         next if ( (kid.name == "text") )
         elements[kid.name] = Hash.new()
         elements[kid.name]['accessor_attributes'] = []
         elements[kid.name]['soda_attributes'] = []
         
         elems = kid.elements()
         elems.each do |e|
            case (e.name)
               when "accessor_attributes"
                  access_kids = e.elements()
                  access_kids.each do |access|
                     next if (access.name == "text")
                  elements[kid.name]["accessor_attributes"].push(access.text)
                  end
               when "soda_attributes"
                  access_kids = e.elements()
                  access_kids.each do |access|
                     next if (access.name == "text")

                     if (access.name =~ /accessor/)
                        elements[kid.name]["soda_attributes"].push(
                              access.text)
                     end

                     if (access.has_elements?)
                        access_kids = access.elements()
                        tmp_hash = {}
                        tmp_hash[access.name] = [] 
                        access_kids.each do |access_kid|
                           next if (access_kid.name == "text")
                           tmp_hash[access.name].push(access_kid.text)
                        end
                        elements[kid.name]["soda_attributes"].push(tmp_hash)
                     else
                        elements[kid.name]["soda_attributes"].push(
                              access.text)
                     end
                  end
            end
         end
      end

      return elements
   end
   private :ElementsXMLToData

###############################################################################
# ProcessSodaTestFile -- method
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
         @report.ReportException(e, @sodatest)
         data = nil
      ensure
      end

      return data
   end
   private :ProcessSodaTestFile

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
            @report.ReportFailure("Failed to find expected test do "+
               "element for test: #{file}, line: #{test_hash['line_number']}"+
               "!\n")
            next
         end

         test_element = test_hash['do']
         next if (test_element == "comment")
         test_hash.delete('do')

         if (!supported.key?("#{test_element}"))
            @report.ReportFailure("Failed to find a supported Soda"+
               " element for: '#{test_element}', line: "+
               "#{test_hash['line_number']}!\n")
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
                        @report.ReportFailure("Faild to find supported action"+
                        " for Soda element: '#{test_element}', attribte: "+
                           "'#{test_key}', action: '#{test_value}', line:"+
                           " #{test_hash['line_number']}!\n")

                           $ERROR_COUNT += 1
                        break
                     end
                  end
               end
            end

            if ( (found_accessor != true) && (found_soda_accrssor != true) )
               @report.ReportFailure("(!)Error: Failed to find supported "+
                  "accessor: '#{test_key}'"+
                  " for Soda element: '#{test_element}', line: "+
                  "#{test_hash['line_number']}!\n")

               $ERROR_COUNT += 1
            end
            
         end
      end

      return $ERROR_COUNT

   end
   private :CheckTest

###############################################################################
# CheckFileformat -- method
#     This function checks to make sure that the test file format is not DOS.
#
# Input:
#     file: the file to check.
#
# Output:
#     returns -1 on error, else 0 on success.
#
###############################################################################
   def CheckFileformat(file)
      err = 0

      begin 
         fd = File.open(file, "r")
         line = fd.readline()
         fd.close()

         if (line =~ /\r\n$/)
            @report.ReportFailure("File is in DOS format!\n")
            err += 1
         end
      rescue Exception => e
         @report.ReportException(e, @sodatest)
         err += 1
      ensure
      end

      err = -1 if (err > 0)

      return err
   end

end



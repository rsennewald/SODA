#!/usr/bin/ruby

require 'rubygems'
require 'getoptlong'
require 'fileutils'
require 'rbconfig'

###############################################################################
#
###############################################################################
def CreateNewTest(testfile, testtitle)
   fd = nil
   fd = File.open(testfile, "w+")
   
   fd.write("<soda>\n")
   fd.write("\t<puts text=\"Test: #{testtitle} starting.\" />\n")
   fd.write("\t<puts text=\"Test: #{testtitle} finished.\" />\n")
   fd.write("</soda>\n")
   fd.close()
end

###############################################################################
#
###############################################################################
def Main()
   test_count = 20
   output_dir = "/tmp/soda-tests"

   if (Config::CONFIG['host_os'] =~ /ms/i)
      output_dir = "c:/tmp/soda-tests"
   end

   output_tests_dir = "#{output_dir}/tests"
   master_test = "#{output_dir}/test-master.xml"

   if (!File.exists?(output_dir))
      print "(*)Found existing directory: #{output_dir}.\n"
      FileUtils.rm_rf(output_dir)
      print "(*)Finished.\n"
   end

   print "(*)Creating new output directory: #{output_dir}...\n"
   FileUtils.mkdir_p(output_tests_dir)
   print "(*)Finished.\n"

   print "(*)Making test-master file...\n"
   fd = File.open(master_test, "w+")
   fd.write("<soda>\n\t<script fileset=\"#{output_tests_dir}\" />\n")
   fd.write("\t<browser action=\"close\" />\n")
   fd.write("</soda>\n")
   fd.close()
   print "(*)Finished.\n"

   print "(*)Starting test creation process...\n"
   for i in 0..test_count
      print "(*)Creating Test #{i} of #{test_count}\n"
      CreateNewTest("#{output_tests_dir}/test-#{i}.xml", "test-#{i}")
      print "(*)Finsihed.\n"
   end

   print "(*)Done.\n\n"
end

###############################################################################
# Start executing code here --->
###############################################################################
   Main()
   exit(0)

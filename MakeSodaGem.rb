#!/usr/bin/ruby

require 'fileutils'

TMP_DIR = "/tmp/Soda"

SODA_EXES = [
   "bin/SodaSuite"
]

SODA_FILES = [
      "SodaElements.xml",
      "FieldUtils.rb",
      "SodaCSV.rb",
      "SodaFireFox.rb",
      "SodaLogReporter.rb",
      "Soda.rb",
      "SodaReporter.rb",
      "SodaReportSummery.rb",
      "SodaTestCheck.rb",
      "SodaUtils.rb",
      "SodaXML.rb",
      "utils/sodalookups.rb",
      "fields/CheckBoxField.rb",
      "fields/FileField.rb",
      "fields/LiField.rb",
      "fields/RadioField.rb",
      "fields/SelectField.rb",
      "fields/SodaField.rb",
      "fields/TextField.rb"
   ]

SODA_DIRS = [
   "utils",
   "fields",
   "bin"
]

   if (!File.exist?(TMP_DIR))
      print "(*)Failed to find tmp directory: #{TMP_DIR}.\n"
      print "(*)Creating directory: #{TMP_DIR}\n"
      FileUtils.mkdir_p("#{TMP_DIR}")
   end

   print "(*)Make needed SODA directories...\n"
   FileUtils.mkdir_p("#{TMP_DIR}/bin")
   SODA_DIRS.each do |d|
      print "(*)Creating directory: #{TMP_DIR}.\n"
      FileUtils.mkdir_p("#{TMP_DIR}/lib/#{d}")
   end

   print "Copying Soda Files...\n"
   SODA_FILES.each do |f|
      cmd = "cp #{f} #{TMP_DIR}/lib/#{f}"
      print "(*)Copying file: #{f}\n"
      Kernel.system(cmd)
   end

   SODA_EXES.each do |f|
      cmd = "cp #{f} #{TMP_DIR}/#{f}"
      print "(*)Copying file: #{f}\n"
      Kernel.system(cmd)
   end

LIB_FILE = <<RUBY
require 'Soda'\n
RUBY

   fd = File.new("#{TMP_DIR}/lib/soda.rb", "w+")
   fd.write(LIB_FILE)
   fd.close()

SPEC = <<RUBY
spec = Gem::Specification.new do |s|
   s.name = 'soda'
   s.version = '0.0.3'
   s.summary = "SODA is an XML based testing framework leveraging Watir."
   s.description = %{This is a wrapper around the watir api for web testing.}
   s.files = Dir['lib/*.rb',
      'lib/*.xml', 
      'bin/*',
      'lib/utils/*.rb', 
      'lib/fields/*.rb',
      '*.rb']
   s.executables = ['SodaSuite']
   s.require_path = 'lib'
   s.has_rdoc = false
   s.extra_rdoc_files = nil
   s.rdoc_options = nil
   s.author = "Trampus Richmond"
   s.email = "trichmond@sugarcrm.com"
   s.homepage = "http://www.github.com/sugarcrm/SODA"
   s.rubyforge_project = "Soda"
   s.add_dependency 'firewatir', '=1.6.7'
   s.add_dependency 'libxml-ruby'
end
RUBY

   print "(*)Writing ruby gem spec file...\n"
   fd = File.new("#{TMP_DIR}/soda.gemspec", "w+")
   fd.write(SPEC)
   fd.close()
   print "(*)Finished making Soda gem...\n"

   print "(*)Building SodaSuite gem...\n"





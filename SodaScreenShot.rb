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

require 'SodaUtils'

###############################################################################
# SodaScreenShot -- Class
#		This class is for taking desktop screen shots of the current running os.
#  	Currently only Winows & Linux are supported.  Really any unix platform
#		running X11 is supported, they just have to be added to the case.
#
# Input:
#		dir: This is the directory to store the snapshots in.
#
###############################################################################
class SodaScreenShot

	LINUX_XWD_BIN = "xwd"
	LINUX_CONVERT_BIN = "convert"
	OUTPUT_FILE = "screenshot-"

	def initialize(dir)
		os = nil
		err = nil
		time = Time.now()
		time = time.to_i()
		hostname = "#{ENV['HOSTNAME']}"
		@outputfile = nil

		if (!File.exist?(dir))
			raise "Failed to find needed diectory: '#{dir}!'\n"
		end

      if ( (hostname.empty?) || (hostname.length < 5) )
         hostname = `hostname`
         hostname = hostname.chomp()
      end

		os = SodaUtils.GetOsType()
		case (os)
			when /linux/i
				xwd = FindLinuxXwd()
				if (xwd == nil)
					raise "Failed to find needed program: 'xwd'!\n"
				end
				
				@outputfile = "#{dir}/#{OUTPUT_FILE}#{time}-#{hostname}.xwd"
				cmd = "#{xwd} -root -out #{@outputfile}"
				err = Kernel.system(cmd)
				if (!err)
					raise "Failed trying to take screenshot!\n"
				end

				convert = FindLinuxConvert()
				if (convert != nil)
					old_outfile = @outputfile
					ext = File.extname(old_outfile)
					@outputfile = @outputfile.gsub(/#{ext}$/, "")
					@outputfile << ".png"
					cmd = "#{convert} #{old_outfile} #{@outputfile}"
					err = Kernel.system(cmd)
					if (!err)
						@outputfile = old_outfile
					else
						File.unlink(old_outfile)
					end
				end
			when /windows/i
				require 'win32/screenshot'
				@outputfile = "#{dir}/#{OUTPUT_FILE}#{time}-#{hostname}.bmp"
            begin
               img = Win32::Screenshot::Take.of(:desktop)
               img.write(@outputfile)
            rescue Exception => e
            end
		end
	end

###############################################################################
# GetOutputFile -- Method
#		This is a getter for getting the newly created snapshot file.
#
# Input:
#		None.
#
# Output:
#		retutns a string with the full path and filename to the new file.
#
###############################################################################
	def GetOutputFile()
		return @outputfile
	end

###############################################################################
# FindLinuxXwd -- Method
#		This method trys to find the xwd X11 util in you current path.
#
# Input:
#		None.
#
# Output:
#		Returns the full path and exe name on success or nil on failure.
#
###############################################################################
	def FindLinuxXwd()
		tmp = nil
		found = nil

		tmp = ENV['PATH'].split(/:/)
		tmp.each do |p|
			path = "#{p}/#{LINUX_XWD_BIN}"
			if (File.exist?(path))
				found = path
				break
			end
		end

		return found
	end
	private :FindLinuxXwd

###############################################################################
# FindLinuxConvert -- Method
#		This method trys to find the linux convert util in you current path.
#
# Input:
#		None.
#
# Output:
#		Returns the full path and exe name on success or nil on failure.
#
###############################################################################
	def FindLinuxConvert()
		tmp = nil
		found = nil

		tmp = ENV['PATH'].split(/:/)
		tmp.each do |p|
			path = "#{p}/#{LINUX_CONVERT_BIN}"
			if (File.exist?(path))
				found = path
				break
			end
		end

		return found
	end
	private :FindLinuxConvert

end

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
require 'libxml'
require 'SodaUtils'

###############################################################################
# SodaXML -- Class
#     This class converts XML documents into Soda Meta Data.
#     A valid Soda XML file always should start with <soda> and end with </soda>
#
###############################################################################
class SodaXML
	attr_accessor :doc

###############################################################################
# processChildren -- Method
#     This method walks through the node and converts it into Soda Markup
#     *Tag(node) names indicate what action to take
#     *attributes are mapped directly over
#     *child nodes map to the children attribute
#
# Params:
#     node: This is the root doc from the XML parser from a soda file.
#
# Results:
#     retutns an array of hashes.
#
###############################################################################
	def processChildren(node)
		children = []
	
      for child in node.children()
			if (child.name == 'text')
				next
			end
			
			cur = Hash.new()
         cur['line_number'] = "#{child.line_num}"
			cur['do'] = "#{child.name}"
        
         case child.name 
            when /javascript/i
               cur['content'] = child.content
            when /ruby/i
               cur['content'] = child.content
            when /comment/i
               cur['content'] = child.content
         end

			child.attributes.each do | attribute |
				cur[attribute.name] = "#{attribute.value}"
			end

			if child.children?()
				cur['children'] = self.processChildren(child)
			end

			children.push(cur)
		end

		return children
	end
	
###############################################################################
# parse -- Method 
#     This methos parses the XML document and returns Soda markup.
#
# Params:
#     file: The soda XML file to parse into soda meta data.
#
# Results:
#     returns an array of hashes from the processChildren method.
#
###############################################################################
	def parse(file)
      data = nil
      parser = nil
      doc = nil

      begin
         LibXML::XML.default_line_numbers = true
         parser = LibXML::XML::Parser.file(file)
         doc = parser.parse()
         data = processChildren(doc.root) 
      rescue Exception => e
         $curSoda.rep.log("Failed to parse XML file: \"#{file}\"!\n",
            SodaUtils::ERROR)
         $curSoda.rep.ReportException(e, true, file)

         data = nil
      ensure
         # make sure this exception doesn't make it up to the soda level #
      end

      return data
	end
end


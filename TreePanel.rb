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

require 'rubygems'
require 'wx'
include Wx

class TreePanel < Wx::Panel

   $TREE_IMAGES = [
      'icons/tree-add.png',
      'icons/tree-del.png'
   ]
   @TREE = nil
   @IMAGE_LIST = nil
   @TREE_BUTTONS = nil

   def initialize(parent, imagelist)
      super(parent, -1, DEFAULT_POSITION, DEFAULT_SIZE, SIMPLE_BORDER, 
            "treepanel")

      @IMAGE_LIST = imagelist
      if (@IMAGE_LIST != nil)
         @TREE_BUTTONS = ImageList.new(16, 16) 
         $TREE_IMAGES.each do |img|
            bmp = Bitmap.new()
            bmp.load_file(img, BITMAP_TYPE_PNG)
            @TREE_BUTTONS.add(bmp)
         end
      end

      BuildTreePanel()

   end

###############################################################################
# BuildTreePanel -- Method
#     This method builds a new tree control to display a soda test.
#
# Input:
#     none.
#
# Output:
#     none.
#
###############################################################################
   def BuildTreePanel()

      @TREE = TreeCtrl.new(self, -1, Point.new(0,0), Size.new(-1,-1),
           TR_HAS_BUTTONS | TR_LINES_AT_ROOT | TR_ROW_LINES | TR_SINGLE)
      @TREE.set_image_list(@IMAGE_LIST)
#      @TREE.set_buttons_image_list(@TREE_BUTTONS)
      tree_root = @TREE.add_root("Soda-Test", 0)
      grid_sizer = BoxSizer.new(Wx::VERTICAL)
      grid_sizer.add(@TREE, 1, Wx::EXPAND | Wx::ALL, 1)
      grid_sizer.set_size_hints(self)
      self.set_sizer(grid_sizer)

   end
   private :BuildTreePanel

   def GetTree()
      return @TREE
   end

end


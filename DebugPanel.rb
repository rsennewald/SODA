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
require 'EditPanel'
include Wx

###############################################################################
#
###############################################################################
class DebugPanel < Wx::Panel

   def initialize(parent)
      @TREE = nil
      @TEXT = nil
      @TREE_PANEL = nil
      @GRID_PANEL = nil
      @SPLITTER = nil

      super(parent, -1, DEFAULT_POSITION, DEFAULT_SIZE, SIMPLE_BORDER, 
            "debugpanel")
      BuildPanel()
   end

###############################################################################
#
###############################################################################
   def BuildPanel()
      grid_sizer = nil
      text_sizer = nil
      panel_sizer = nil
      tree_size = Size.new(220, 100)

      panel_sizer = BoxSizer.new(Wx::VERTICAL)
      @TREE_PANEL = Panel.new(self, -1, DEFAULT_POSITION, DEFAULT_SIZE,
            SIMPLE_BORDER, "debugtreepanel")

      @SPLITTER = SplitterWindow.new(@TREE_PANEL, -1, Point.new(0, 0),
            DEFAULT_SIZE, SP_3DBORDER, "debugsplitter")
      @SPLITTER.set_sash_gravity(0.0)
      panel_sizer.add(@SPLITTER, 1, Wx::ALL | Wx::EXPAND, 1)
      panel_sizer.set_size_hints(@TREE_PANEL)
      @TREE_PANEL.set_sizer(panel_sizer)

      @GRID_PANEL = EditPanel.new(@SPLITTER, false)

      @TEXT = TextCtrl.new(self, -1, "Debug Info:", DEFAULT_POSITION, 
            DEFAULT_SIZE, TE_MULTILINE | TE_RICH2 | HSCROLL)
      @TEXT.set_editable(false)

      @TREE = TreeCtrl.new(@SPLITTER, -1, DEFAULT_POSITION, tree_size,
            TR_HAS_BUTTONS | TR_LINES_AT_ROOT | TR_ROW_LINES | TR_SINGLE)
      @TREE.add_root("Borwser-Debug-Info", 0)

      @SPLITTER.split_vertically(@TREE, @GRID_PANEL, 0)

      grid_sizer = BoxSizer.new(Wx::VERTICAL)
      text_sizer = BoxSizer.new(Wx::VERTICAL)
      grid_sizer.add(@TREE_PANEL, 1, Wx::ALL | Wx::EXPAND, 1)
      grid_sizer.add(@TEXT, 1, Wx::ALL | Wx::EXPAND, 1)
      grid_sizer.set_size_hints(self)
      self.set_sizer(grid_sizer)
   end

###############################################################################
#
###############################################################################
   def DeleteGridData()
      grid = GetGrid()
      row_count = grid.get_number_rows()
      grid.delete_rows(0, row_count +1)
   end

###############################################################################
#
###############################################################################
   def SetGridData(hash)
      row_count = 0
      grid = nil
      current_row = 0

      DeleteGridData()

      grid = GetGrid()

      hash.each do |k ,v|
         grid.append_rows(1)
         grid.set_read_only(current_row, 0)
         grid.set_read_only(current_row, 1)
         grid.set_cell_value(current_row, 0, k)
         grid.set_cell_value(current_row, 1, v) 
         grid.auto_size_column(0)
         grid.auto_size_column(1)
         current_row += 1
      end

   end

###############################################################################
#
###############################################################################
   def GetTreeCtrl()
      return @TREE
   end

###############################################################################
#
###############################################################################
   def GetTextCtrl()
      return @TEXT
   end

###############################################################################
#
###############################################################################
   def GetGrid()
      return @GRID_PANEL.GetGrid()
   end

end

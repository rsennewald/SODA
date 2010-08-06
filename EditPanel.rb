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

class EditPanel < Wx::Panel

   @GRID = nil
   @PANEL = nil
   @ADD_BTN = nil
   @REMOVE_BTN = nil
   @DSP_LINE_NUMS = false
   @BUTTONS = true

   def initialize(parent, buttons = true)
      super(parent, -1, DEFAULT_POSITION, DEFAULT_SIZE, SIMPLE_BORDER, 
            "editpanel")

      @DSP_LINE_NUMS = false
      @BUTTONS = buttons

      BuildEditPanel()

   end

###############################################################################
#
###############################################################################
   def SetDisplayLineNumbers(dsp = false)
      @DSP_LINE_NUMS = dsp
   end

###############################################################################
# GetGrid -- Method
#     This method gets this classes wxgrid.
#
# Input:
#     None.
#
# Output:
#     returns this classes Wxgrid object
#
###############################################################################
   def GetGrid()
      return @GRID
   end

###############################################################################
# GetPanel -- Method
#     This method gets this classes wxpanel.
#
# Input:
#     None.
#
# Output:
#     returns this classes WxPanel object
#
###############################################################################
   def GetPanel()
      return @PANEL
   end

###############################################################################
# BuildEditPanel -- Method
#     This method builds the edit panel..
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def BuildEditPanel()
      panel = nil
      grid_sizer = nil
      button_sizer = nil
      @ADD_BTN = nil
      @REMOVE_BTN = nil

      BuildGrid()

      grid_sizer = BoxSizer.new(Wx::VERTICAL)
      grid_sizer.add(@GRID, 1, Wx::EXPAND | Wx::ALL, 1)
      grid_sizer.set_size_hints(self)
      self.set_sizer(grid_sizer)
      
      if (@BUTTONS)
         button_sizer = BoxSizer.new(Wx::HORIZONTAL)
         @ADD_BTN = Button.new(self, ID_ANY, "&Add", DEFAULT_POSITION,
               DEFAULT_SIZE)
         @REMOVE_BTN = Button.new(self, ID_ANY, "&Remove", DEFAULT_POSITION,
               DEFAULT_SIZE)

         @ADD_BTN.enable(false)
         @REMOVE_BTN.enable(false)
         button_sizer = BoxSizer.new(Wx::HORIZONTAL)
         button_sizer.add(@ADD_BTN, Wx::ALL, 1)
         button_sizer.add(@REMOVE_BTN, Wx::ALL, 1)
         grid_sizer.add(button_sizer)
      end
   end
   private :BuildEditPanel

###############################################################################
#
###############################################################################
   def BuildGrid()
      @GRID = Grid.new(self, -1, DEFAULT_POSITION, DEFAULT_SIZE, 0, "grid")
      @GRID.create_grid(0,2)
      @GRID.set_row_label_size(0)
      @GRID.set_col_label_value(0, "Name:")
      @GRID.set_col_label_value(1, "Value:")
      @GRID.set_label_background_colour(Wx::BLACK)
      @GRID.set_label_text_colour(Wx::GREEN)
      @GRID.set_col_label_alignment(ALIGN_LEFT, ALIGN_CENTER)
      @GRID.set_label_font(Wx::SMALL_FONT)
      @GRID.set_default_cell_font(Wx::SMALL_FONT)
#      @GRID.auto_size()
      @GRID.auto_size_rows(true)
#      @GRID.auto_size_columns(true)
      @GRID.set_grid_line_colour(Wx::BLACK)
      @GRID.set_selection_mode(Wx::Grid::GridSelectRows)
      @GRID.set_default_col_size(200)
   end
   private :BuildGrid

   def GetAddButton()
      return @ADD_BTN
   end

   def GetRemoveButton()
      return @REMOVE_BTN
   end

###############################################################################
#
###############################################################################
   def EnableButtons(btns = false)
      @ADD_BTN.enable(btns)
      @REMOVE_BTN.enable(btns)
   end
   private :EnableButtons

###############################################################################
#  BuildDataPanel -- Method
#     This method updates the displat table with new data.
#
# Input:
#     soda_data: a soda test hash.
#
# Output:
#     None.
#
###############################################################################
   def BuildDataPanel(soda_data)
      data = nil
      current = 0
      row_count = nil
      line_number = 0

      EnableButtons(false)

      data = Marshal.load(Marshal.dump(soda_data))
      line_number = data['line_number']

      data.delete('line_number') 
    
      data.delete('children') if (data.key?('children'))

      data.delete('do')
      row_count = data.keys.length()
      current_rows = @GRID.get_number_rows()
      @GRID.delete_rows(0, current_rows+1)

      data.each do |k, v|
         @GRID.append_rows(1)
         @GRID.set_cell_value(current, 0, "#{k}")
         @GRID.auto_size_column(0)
         @GRID.set_cell_value(current, 1, "#{v}")
         @GRID.auto_size_column(1)
         current += 1
      end
   
      if (@DSP_LINE_NUMS) 
      # save the line number for last always # 
         @GRID.append_rows(1)
         @GRID.set_read_only(current, 0)
         @GRID.set_read_only(current, 1)
         @GRID.set_cell_background_colour(current, 0, Wx::LIGHT_GREY)
         @GRID.set_cell_background_colour(current, 1, Wx::LIGHT_GREY)
         @GRID.set_cell_value(current, 0, "Line Number:")
         @GRID.set_cell_value(current, 1, "#{line_number}")
         @GRID.auto_size_column(0)
         @GRID.auto_size_column(1)
      end

      EnableButtons(true)
   end

###############################################################################
#
###############################################################################
   def AddRow()
      @GRID.append_rows(1)
   end

###############################################################################
#
###############################################################################
   def DeleteCurrentRow()
      cur = nil
      cur = @GRID.get_grid_cursor_row()
      @GRID.delete_rows(cur, 1)
   end
   
end


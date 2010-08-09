#!/usr/bin/ruby
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
require 'SodaMachineInfo'
require 'SodaUtils'
require 'SodaXML.rb'
require 'SodaUtils'
require 'wx'
include Wx
require 'EditPanel'
require 'TreePanel'
require 'Soda'
require 'DebugPanel'
require 'SodaReporter'
require 'SodaOptions'
require 'watir'
require 'pp'

###############################################################################
# SodaMachine -- Class
#     This class creates a gui to allow for creating, editing, and debugging
#     Soda tests.
#
###############################################################################
class SodaMachine < App


###############################################################################
# OnOpenFile: method
#     This method gets called when the file open menu item is selected.  It
#     opens the file selected by the user and processes the Soda test.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def OnOpenFile()
      result = nil
      file_dialog = nil
      file_name = ""

      begin
         SetStatusMessage("Opening soda test file...")
         file_dialog = FileDialog.new(@FRAME_HANDLE, "Open Soda Test File",
            "", "", "*.xml", FD_OPEN, Point.new(20,20), 
            Size.new(10,10), "filedlg" )
      rescue Exception => e
         print "Error: #{e.message}!\n"
      ensure

      end

      result = file_dialog.show_modal()
      if (result == Wx::ID_OK)
         @SODA_TEST_FILE = file_dialog.get_path()
         SetStatusMessage("Opened Soda test: #{@SODA_TEST_FILE}")
         SetStatusMessage("Parsing Soda test file: #{@SODA_TEST_FILE}")
         soda_test = SodaXML.new.parse(@SODA_TEST_FILE)
         SetStatusMessage("Finished Parsing soda test: #{@SODA_TEST_FILE}")
         ProcessSodaTest(soda_test, @TREE.get_root_item())
         @TREE.expand(@TREE.get_root_item())
      end
   end

###############################################################################
# SaveGridData -- Method
#     This method saves the current grid data into the tree item's data 
#     area to be used later.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def SaveGridData()
      root_id = @TREE.get_root_item()
      root = @TREE.get_root_item()
      item = @TREE.get_selection()
      text = @TREE.get_item_text(item)

      if (item != root && item > 0)
         data = @TREE.get_item_data(item)
         table = @GRID.get_table()
         row_count = table.get_number_rows() -1
         data['do'] = text
         for i in (0..row_count)
            key = table.get_value(i, 0)
            val = table.get_value(i, 1)
            next if (key.empty?)
            data[key] = val
         end
      
         @TREE.set_item_data(item, data)
      end
   end
   private :SaveGridData
   
###############################################################################
# OnSaveFile -- Event Method
#     This method creates a save dialog box to allow the users to save off
#     the current state of the @TREE to and xml file.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def OnSaveFile()
      result = nil
      save_dialog = nil
      file_name = nil
      write_file = false
      root_id = nil

      begin
         save_dialog = FileDialog.new(@FRAME_HANDLE, "Save Soda Test As...",
            "", "", "*.xml", FD_SAVE, Point.new(20, 20), Size.new(10, 10),
            "savedlg")
      rescue Exception => e
         print "Error: #{e.message}\n"
      ensure

      end

      result = save_dialog.show_modal()
      if (result == Wx::ID_OK)
         file_name = save_dialog.get_path()

         if (File.exist?(file_name))
            overwrite = MessageDialog.new(@FRAME_HANDLE,
               "File Already Exists: #{file_name}, Over Write File?",
               "Over Write File?", YES_NO)
            result = overwrite.show_modal()
            if (result == ID_YES)
               write_file = true
            end
         else
            write_file = true
         end

         if (write_file)
            print "Save File: #{file_name}\n"
            SaveTreeToXML(file_name)
         end
      end
   end
   private :OnSaveFile

###############################################################################
# SodaHashToXML -- Method
#  
# Input:
#     soda_hash: a soda test hash.
#     parent: This is an int that notes how many parents this hash has.
#
# Output:
#     returns a string of XML code.
#
# Notes:
#     This needs a non-hackie way to not exceed 80 chars....
#
###############################################################################
   def SodaHashToXML(soda_hash, parent = 0)
      tabs = "\t" * parent
      tab_width = (parent * 8)
      str = "#{tabs}<#{soda_hash['do']}"
      has_kids = false
      do_action = soda_hash['do']
      attribute_count = 0

      @CURRENT_PROCESS_NUM += 1

      @PROCESS_DLG.update(@CURRENT_PROCESS_NUM, "Processing: #{do_action}")

      has_kids = true if (soda_hash.key?('children'))
      soda_hash.delete('line_number') if (soda_hash.key?('line_number'))

      if (do_action =~ /comment/i)
         str = "#{tabs}<!-- #{soda_hash['content']} -->\n"
         return str
      end

      soda_hash.delete('do')
      attribute_count = soda_hash.length()
      soda_hash.each do |k, v|
         next if (k =~ /children/i)
         
         safe_str = SodaUtils.XmlSafeStr(v)

         if (k =~ /comment/i)
            str << "#{tabs}<!-- #{v} -->\n"
         else
            if ( (attribute_count > 1) && (safe_str.length > 10))
               str << "\n#{tabs}\t#{k}=\"#{safe_str}\""
            else
               if (str !~ /\s$/)
                  str << " #{k}=\"#{safe_str}\" "
               else
                  str << "#{k}=\"#{safe_str}\" "
               end
            end
         end
      end
      
      if (has_kids)
         str << ">\n"
         soda_hash['children'].each do |kid|
            str << SodaHashToXML(kid, parent+1)
            print "Processed Child!:: #{str}\n"
         end
         str << "#{tabs}</#{do_action}>\n"
      else
         str << "/>\n"
      end
      
      return str
   end
   private :SodaHashToXML

###############################################################################
# SaveTreeToXML -- Method
#     This method saves the current @TREE to an xml file.
#
# Input:
#     save_file: The XML file to create.
#
# Output:
#     None.
#
###############################################################################
   def SaveTreeToXML(save_file)
      fd = nil
      dlg = nil
      tree_count = @TREE.get_count() -1
      root_id = nil
      root_kids = nil

      tmp = TreeToArray(@TREE.get_root_item())

      @CURRENT_PROCESS_NUM = 0
      fd = File.new(save_file, "w+")
      fd.write("<soda>\n")

      @PROCESS_DLG = ProgressDialog.new("Processing...", 
            "Foobar", tree_count, @FRAME_HANDLE, 
            PD_SMOOTH | PD_ELAPSED_TIME |PD_REMAINING_TIME | PD_AUTO_HIDE)

      tmp.each do |data|
         next if (data['do'] =~ /breakpoint/i)
         str = SodaHashToXML(data, 1)
         fd.write(str)
      end

      fd.write("</soda>\n\n")
      fd.close()
   end
   private :SaveTreeToXML

###############################################################################
# TreeToArray -- Method
#     This method converts a tree node into an array, starting from the tree
#     item passed in.
#
# Input:
#     id: this is the @TREE id to convert to an array of hashs.
#
# Output:
#     returns an array.
#
###############################################################################
   def TreeToArray(id = 0)
      list = []
      
      if (id <= 0)
         id = @TREE.get_root_item()
      end
   
      kids = @TREE.get_children(id)
      kids.each do |kid|
         data = @TREE.get_item_data(kid)
         next if (data['do'] =~ /breakpoint/i)

         if (@TREE.item_has_children(kid))
            data['children'] = TreeToArray(kid)
         end
         list.push(data)
      end     

      return list
   end
   private :TreeToArray

###############################################################################
#  ProcessSodaTest -- Method
#     This method creates an entry into the tree control for each soda
#     test XML element.
#
# Input:
#     test: The soda test element hash.
#     parent: The parent tree item to append too.
#
# Output:
#     None.
#
###############################################################################
   def ProcessSodaTest(test, parent)
   
      root_id = @TREE.get_root_item()
      if (parent == root_id)
         @TREE.delete_children(root_id)
      end

      test.each do |t|
         icon_index = 0
         item = nil

         if (!$SODA_INFO.key?(t['do']))
            icon_index = -1
         else
            icon_index = $SODA_INFO[t['do']]['image_index']
         end

         if (t.key?('children'))
            kids = Marshal.dump(t['children'])
            kids = Marshal.load(kids)
            t.delete('children')
            item = @TREE.append_item(parent, "#{t['do']}", 
               icon_index, -1, t)
            ProcessSodaTest(kids, item)
         else
            item = @TREE.append_item(parent, "#{t['do']}", 
               icon_index, -1, t)
         end
      end
   end
   private :ProcessSodaTest

###############################################################################
# OnTreePopUpMenu -- Event Method
#     This method brings up the proper popup menu for a tree item.
#
# Input:
#     event: This the the event fromt he @TREE control.
#
# Output:
#     None.
#
###############################################################################
   def OnTreePopUpMenu(event)
      root = @TREE.get_root_item()
      item = event.get_item()
      name = ""
      
      if (item != root)
         data = @TREE.get_item_data(item)
         if (data['do'] =~ /breakpoint/i)
            @FRAME_HANDLE.popup_menu(@TREE_POPUP_MENU_DELETE, DEFAULT_POSITION)
         elsif ($SODA_INFO[data['do']]['allow_kids'])
            @FRAME_HANDLE.popup_menu(@TREE_POPUP_MENU, DEFAULT_POSITION)
         else
            @FRAME_HANDLE.popup_menu(@TREE_POPUP_MENU_NO_CHILD, 
               DEFAULT_POSITION)
         end
      else
         @FRAME_HANDLE.popup_menu(@TREE_POPUP_MENU_ROOT, DEFAULT_POSITION)
      end
   end
   private :OnTreePopUpMenu

###############################################################################
# SetStatusMessage -- Method
#     This method sets the main apps status message.
#
# Input:
#     msg: a string to display in the status bar
#
# Output:
#     None.
#
###############################################################################
   def SetStatusMessage(msg)
      status = nil
      status = @FRAME_HANDLE.get_status_bar()
      status.set_status_text(msg)
   end
   private :SetStatusMessage

###############################################################################
# OnTreeChanged -- Event Method
#     This method gets the data for the newly selected tree item, and then
#     builds the data into the display table.
#
# Input:
#     event: This is the event passed to use from the tree.
#
# Output:
#     None.
#
###############################################################################
   def OnTreeChanged(event)
      data = nil
      item = nil

      @CURRENT_TREE_ITEM = event.get_item()

      root = @TREE.get_root_item()
      item = event.get_item()
      if (item != root)
         data = @TREE.get_item_data(item)
         @EDITPANEL.BuildDataPanel(data)
      end

      if (@TREE.item_has_children(item))
         tmp = @TREE.get_item_data(item)
      end

   end
   private :OnTreeChanged

###############################################################################
# GenerateDeleteItemMenu -- Method
#     This method generates the delete menu item.
#
# Input:
#     None.
#
# Ouput:
#     returns a new menu.
#
###############################################################################
   def GenerateDeleteItemMenu()
      menu = Menu.new()
      tmp = MenuItem.new(menu, $TREE_MENU_EVENT_APPEND['delete'],
         "Delete")
      if (!@NO_ICONS)
         bmap = Bitmap.new()
         bmap.load_file($IMAGES[$IMAGE_INDEX['delete']], BITMAP_TYPE_PNG)
         tmp.set_bitmap(bmap)
      end
      menu.append_item(tmp)
      evt_menu(tmp, :OnTreeMenuItem)

      return menu
   end
   private :GenerateDeleteItemMenu

###############################################################################
# GenerateTreeItemMenu -- Method
#     This method creates a new menu for a tree item.
#
# Input:
#     child: true/false, weather to create a child menu or not.
#     append: true/false, weather to create a append menu or not.
#     isroot: true/false, weather is this for the root of the tree.
#
# Output:
#     returns a new menu
#
###############################################################################
   def GenerateTreeItemMenu(child, append, isroot = false)
      menu = nil
      submenu_append = nil
      submenu_child = nil

      menu = Menu.new()
      submenu_append = Menu.new() if (append)
      submenu_child = Menu.new() if (child)

      $SODA_INFO.each do |k, v|
         next if (k =~ /root/i)
         
         if (!@NO_ICONS)
            bmap = Bitmap.new()
            bmap.load_file($IMAGES[v['image_index']], BITMAP_TYPE_PNG)
         end

         if (append)
            tmp_append = MenuItem.new(menu, v['append_menu_id'], k)
            tmp_append.set_bitmap(bmap) if (!@NO_ICONS)
            submenu_append.append_item(tmp_append)
            evt_menu(tmp_append, :OnTreeMenuItem)
         end

         if (child)
            tmp_child = MenuItem.new(menu, v['child_menu_id'], k)
            tmp_child.set_bitmap(bmap) if (!@NO_ICONS)
            submenu_child.append_item(tmp_child)
            evt_menu(tmp_child, :OnTreeMenuItem)
         end
      end

      if (child)
         menu.append_menu($APPEND_MENU_ID, "Add Child", submenu_child)
      end

      if (append)
         menu.append_menu($CHILD_MENU_ID, "Append Item", submenu_append)
      end

      if (!isroot)
         tmp = MenuItem.new(menu, $TREE_MENU_EVENT_APPEND['delete'],
            "Delete")
         if (!@NO_ICONS)
            bmap = Bitmap.new()
            bmap.load_file($IMAGES[$IMAGE_INDEX['delete']], BITMAP_TYPE_PNG)
            tmp.set_bitmap(bmap)
         end
         menu.append_item(tmp)
         evt_menu(tmp, :OnTreeMenuItem)
      end
      
      tmp = MenuItem.new(menu, $TREE_MENU_EVENT_APPEND['breakpoint'],
         "BreakPoint")
      if (!@NO_ICONS)
         bmap = Bitmap.new()
         bmap.load_file($IMAGES[$IMAGE_INDEX['breakpoint']], BITMAP_TYPE_PNG)
         tmp.set_bitmap(bmap)
      end
      menu.append_item(tmp)
      evt_menu(tmp, :OnTreeMenuItem)

      tmp = MenuItem.new(menu, $BREAK_POINT_UNSET_MENU_ID,
         "Delete BreakPoint")

      if (!@NO_ICONS)
         bmap = Bitmap.new()
         bmap.load_file($IMAGES[$IMAGE_INDEX['breakpoint']], BITMAP_TYPE_PNG)
         tmp.set_bitmap(bmap)
      end
      menu.append_item(tmp)
      evt_menu(tmp, :OnTreeMenuItem)

      return menu
   end
   private :GenerateTreeItemMenu

###############################################################################
# OnTreeMenuItem -- Event Method
#     This method handles what happens when a tree popup menu item is selected.
#
# Input:
#     event: The @TREE menu item event.
#
# Output:
#     None.
#
###############################################################################
   def OnTreeMenuItem(event)
      id = event.get_id()
      select_id = @TREE.get_selection()
      select_prev = nil
      root_id = @TREE.get_root_item()

      if (id >= 600 && id < 700)
         soda_id = @SODA_INFO_NUMS["#{id}"]
         test = {'do' => "#{soda_id}"}
         next_item = @TREE.get_next_sibling(select_id)
         parent = @TREE.get_item_parent(select_id)

         if (parent <= 0)
            parent = root_id
         end

         icon_index = $SODA_INFO[soda_id]['image_index']
         @TREE.insert_item(parent, select_id, soda_id, icon_index,
            -1, test)
      elsif (id >= 700 && id < 800)
         soda_id = @SODA_INFO_NUMS["#{id}"]
         test = {'do' => "#{soda_id}"}
         icon_index = $SODA_INFO[soda_id]['image_index']
         @TREE.append_item(select_id, soda_id, icon_index, -1, test)
      elsif (id == $DELETE_MENU_ID)
         print "DELETE: ITEM ID: #{select_id}\n"
         next_item = @TREE.get_prev_sibling(select_id)
         next_item = root_id if (next_item <= 0)
         @TREE.select_item(next_item, false)
         print "sib: #{next_item}\n"
         @TREE.delete(select_id)
      elsif (id == $BREAK_POINT_MENU_ID)
         @TREE.set_item_background_colour(select_id, Wx::RED)
         @BREAK_POINTS.push(select_id)
         print "Set BP for item: #{select_id}\n"
      elsif (id == $BREAK_POINT_UNSET_MENU_ID)
         @TREE.set_item_background_colour(select_id, Wx::WHITE)
         @BREAK_POINTS.delete(select_id)
      else
         print "UNKNOWN ITEM: #{id}!!!\n"
      end 
   end
   private :OnTreeMenuItem

###############################################################################
# OnGridAddButton -- Event Method
#     This method is called when the grid's add button is clicked.
#
# Input:
#     event: this is the event from the grid.
#
# Output:
#     None.
#
###############################################################################
   def OnGridAddButton(event)
      @EDITPANEL.AddRow() 
   end
   private :OnGridAddButton

###############################################################################
# OnGridRemoveButton -- Event Method
#     This method is called with the grid's remove button is clicked.
#
# Input:
#     event: this is the event from the grid.
#
# Output:
#     None.
#
###############################################################################
   def OnGridRemoveButton(event)
      @EDITPANEL.DeleteCurrentRow()
   end
   private :OnGridRemoveButton

###############################################################################
# OnTreeSelChanging -- Event Method
#     This event is called when the tree's selection is called, it saves off
#     all the current data in the grid to the selected tree item's data store.
#
# Input:
#     event: this is the event info from the control.
#        
# Output:
#     None.
#
###############################################################################
   def OnTreeSelChanging(event)
      data = nil
      item = nil
      cur_row = nil
      cur_grid_hash = Hash.new()
      old_grid_data = Hash.new()
      do_action = nil

      root = @TREE.get_root_item()
      item = event.get_item()
      item = @CURRENT_TREE_ITEM

      if (item != root)
         cur_row = @GRID.get_grid_cursor_row()
         old_grid_data = @TREE.get_item_data(item)

         if (old_grid_data.key?('do'))
            do_action = old_grid_data['do']
         end

         if (old_grid_data == nil)
            print "NIL!!!!\n"
         end

         table = @GRID.get_table()
         row_count = table.get_number_rows() -1

         for i in (0..row_count)
            key = table.get_value(i, 0)
            val = table.get_value(i, 1)
            cur_grid_hash[key] = val
         end

         if (!cur_grid_hash.empty?)
            cur_grid_hash['do'] = do_action
            @TREE.set_item_data(item, cur_grid_hash)
         elsif (!old_grid_data.empty?)
            @TREE.set_item_data(item, old_grid_data)
         end
      end
   end
   private :OnTreeSelChanging

###############################################################################
# RunTreeTest -- Method
#     This method runs tree items as a soda test. 
#
# Input:
#     parent: this is the tree item to start running the test from.
#
# Output:
#     None.
# 
###############################################################################
   def RunTreeTest(parent_id = 0)
      params = {
         'browser' => "firefox",
         'printcallback' => @PRINT_PROC,
         'savehtml' => false,
         'debug' => false,
         'gvars' => {},
         'flavor' => "any",
         'errorskip' => [],
         'hijacks' => {}
      }
      
      params = params.merge(@SODA_OPTIONS)

      test_file = nil

      if (@SODA_TEST_FILE == nil || @SODA_TEST_FILE.empty?)
         t = Time.now()
         t = t.to_i()
         test_file = "Unknown-Test-Name-#{t}"
      else
         test_file = @SODA_TEST_FILE
      end

      @RUN_MENU_ITEM.enable(false)
     
      if (@SODA_DEBUG == nil) 
         rep = SodaReporter.new(test_file, false, nil,
               0, @PRINT_PROC);
         @SODA_DEBUG = Soda::Soda.new(params)
         @SODA_DEBUG.SetReporter(rep)
      end

      root_id = @TREE.get_root_item()

      if ( (parent_id != 0) && (parent_id != root_id)) 
         root_id = parent_id
      else
         root_id = @TREE.get_root_item()
      end

      root_kids = @TREE.get_children(root_id)

      root_kids.each do |kid|
         data = @TREE.get_item_data(kid)
         next if (data.key?('comment'))

         events = [ data ]
         @SODA_DEBUG.handleEvents(events)

         if (@TREE.item_has_children(kid))
            RunTreeTest(kid)
         end 
      end
   
      tmp = @TREE.get_root_item()
      if (tmp == root_id)
         @TIMER.stop()
         @SODA_DEBUG.rep.SodaPrintCurrentReport()
         @SODA_DEBUG.rep.EndTestReport()
         @SODA_DEBUG.rep.ReportHTML()
         @RUN_MENU_ITEM.enable(true)
      end
   end
   private :RunTreeTest

###############################################################################
# OnRunSodaTest -- Event Method
#     This is the menu event that starts running the tree as a soda test.
#
# Input:
#     event: The tree control's event info.
#
# Output:
#     None.
#
###############################################################################
   def OnRunSodaTest(event)
      id = event.get_id()
      @RUN_MENU_ITEM.enable(false)
      
      @TIMER = Wx::Timer.new(self, 55)
      evt_timer(55) {     
            RunTreeTest()
      }
      @TIMER.start(20)

   end
   private :OnRunSodaTest

###############################################################################
# DebugSodaTest -- Method
#     This method runs the tree as a soda test in debug mode, so it wacthes for
#     break points and stops when one is found.
#
# Input:
#     parent_id: the tree item to start running from.
#
# Output:
#     returns true if a break point is hit, else false.
# 
###############################################################################
   def DebugSodaTest(parent_id = 0)
      soda = nil
      params = {
         'browser' => "firefox",
         'printcallback' => @PRINT_PROC,
         'savehtml' => false,
         'debug' => false,
         'gvars' => {},
         'flavor' => "any",
         'errorskip' => [],
         'hijacks' => {}
      }
      test_file = nil
      breakp = false
      end_soda_debug_id = nil

      params = params.merge(@SODA_OPTIONS)

      if (@SODA_TEST_FILE == nil || @SODA_TEST_FILE.empty?)
         t = Time.now()
         t = t.to_i()
         test_file = "Unknown-Test-Name-#{t}"
      else
         test_file = @SODA_TEST_FILE
      end

      if (@SODA_DEBUG == nil) 
         rep = SodaReporter.new(test_file, false, nil,
               0, @PRINT_PROC);
         @SODA_DEBUG = Soda::Soda.new(params)
         @SODA_DEBUG.SetReporter(rep)
      end

      root_id = @TREE.get_root_item()
      if ( (parent_id != 0) && (parent_id != root_id)) 
         root_id = parent_id
      else
         root_id = @TREE.get_root_item()
      end

      root_kids = @TREE.get_children(root_id)
      end_soda_debug_id = @TREE.get_last_child(@TREE.get_root_item())

      root_kids.each do |kid|
         data = @TREE.get_item_data(kid)
         next if (data.key?('comment'))
        
         if (@BREAK_POINTS.include?(kid))
            @HIT_BREAK_POINTS.push(kid)
            @CURRENT_TREE_BP_ID = kid
            SetStatusMessage("Stopping at break point...")
            @TREE.set_item_background_colour(kid, Wx::RED)
            GetBrowserDebugInfo()
            breakp = true
            break
         end

         events = [ data ]
         @SODA_DEBUG.handleEvents(events)
         
         if (@TREE.item_has_children(kid))
            breakp = DebugSodaTest(kid)
            break if (breakp)
         end

      end

      @TIMER.stop()
      
      if (@CURRENT_TREE_BP_ID == end_soda_debug_id)
         EndSodaDebug()
      end

      return breakp
   end
   private :DebugSodaTest

###############################################################################
# EndSodaDebug -- Method
#     This method ends the soda debug instance and reports test results.
#
# Input:
#     None.
#
# Output:
#     None.
#
###############################################################################
   def EndSodaDebug()
      @SODA_DEBUG.rep.SodaPrintCurrentReport()
      @SODA_DEBUG.rep.EndTestReport()
      @SODA_DEBUG.rep.ReportHTML()
      @DEBUG_MENU_ITEM.enable(true)
      @CONTINUE_MENU_ITEM.enable(false)
   end
   private :EndSodaDebug

###############################################################################
# DebugInfoAdd -- Method
#     This method adds debug info to the debug info tree.
#
# Input:
#     name: The name of the elements being added.
#     list: the list of info about each element.
#
# Output:
#     None.
#
###############################################################################
   def DebugInfoAdd(name, list)
      root = @DEBUG_TREE.get_root_item()
      new_node = nil
      sub_name = name
      
      sub_name = sub_name.gsub(/'s|s$/,"")

      msg = "Collecting info for: #{name}\n"
      @DEBUG_TEXT.append_text(msg)
      @DEBUG_TEXT.update()

      new_node = @DEBUG_TREE.append_item(root, name)
      list.each do |i|
         @DEBUG_DLG.pulse("Collecting: #{name}\n")
         data = Hash.new()
         s = i.to_s()
         s = s.split(/\n/)
         s.each do |line|
            tmp = line.split(/:\s+/)
            if (tmp.length > 1)
               tmp[1] = tmp[1].gsub(/^\s+/, "")
               tmp[1] = tmp[1].gsub(/\s+$/, "")
               data[tmp[0]] = tmp[1]
            end
         end
         new_item = @DEBUG_TREE.append_item(new_node, sub_name)
         @DEBUG_TREE.set_item_data(new_item, data)
      end
   end
   private :DebugInfoAdd

###############################################################################
# GetBrowserDebugInfo -- Method
#     This method gets all the browser info for given html elements.
#
# Input:
#     None.
#
# Output:
#     None.
#
# Notes:
#     all commented out code is due to an issue with watir.
###############################################################################
   def GetBrowserDebugInfo()
      browser = @SODA_DEBUG.GetBrowser()
      root_id = @DEBUG_TREE.get_root_item()
      
      if (root_id > 0)
         @DEBUG_TREE.delete_children(root_id)
      end

      @DEBUG_TREE.add_root("Browser Debug Info:")

      @DEBUG_DLG = ProgressDialog.new("Debug Info", 
            "Collecting Browser Info...", 100, $FRAME_HANDLE, PD_APP_MODAL )

      DebugInfoAdd("Buttons", browser.buttons())
      DebugInfoAdd("Areas", browser.areas())
      DebugInfoAdd("CheckBoxes", browser.checkboxes())
#      DebugInfoAdd("Dd's", browser.dds())
#      DebugInfoAdd("Div's", browser.divs())
#      DebugInfoAdd("Dl's", browser.dls())
#      DebugInfoAdd("Dt's", browser.dts())
#      DebugInfoAdd("Em's", browser.ems())
      DebugInfoAdd("FileFields", browser.file_fields())
      DebugInfoAdd("Hidden's", browser.hiddens())
      DebugInfoAdd("Label's", browser.labels())
      DebugInfoAdd("Links", browser.links())
      DebugInfoAdd("Maps", browser.maps())
      DebugInfoAdd("Pre's", browser.pres())
#      DebugInfoAdd("P's", browser.ps())
      DebugInfoAdd("Radio's", browser.radios())
      DebugInfoAdd("SelectLists", browser.select_lists())
#      DebugInfoAdd("Span's", browser.spans())
#      DebugInfoAdd("Strong's", browser.strongs())
#      DebugInfoAdd("Tables", browser.tables())
      DebugInfoAdd("TextFields", browser.text_fields())
#      DebugInfoAdd("UL's", browser.uls())
#      DebugInfoAdd("Forms", browser.forms())
      DebugInfoAdd("Images", browser.images())
#      DebugInfoAdd("Li's", browser.lis())
#      DebugInfoAdd("Table Cells", browser.cells())
#      DebugInfoAdd("Table Rows", browser.rows())
       @DEBUG_DLG.destroy()
       @DEBUG_TEXT.append_text("Finished Collecting Debug info.\n")
       @DEBUG_TEXT.update()
       @DEBUG_TREE.expand(@DEBUG_TREE.get_root_item())
   end
   private :GetBrowserDebugInfo

###############################################################################
# DebugItem -- Method
#     This method runs a tree item in debug mode, stopping at break points.
#
# Input:
#     item_data: This is the data that the tree item is holding.
#     item_id: This is the id of the tree node.
#
# Output:
#     returns true if a break point is hit, else false.
# 
###############################################################################
   def DebugItem(item_data, item_id)
      bp = false  

      if ( (@BREAK_POINTS.include?(item_id)) && 
            (!@HIT_BREAK_POINTS.include?(item_id)))

         @HIT_BREAK_POINTS.push(item_id)
         @CURRENT_TREE_BP_ID = item_id
         @TREE.set_item_background_colour(item_id, Wx::RED)
         GetBrowserDebugInfo()
         bp = true
         print "Hit BP.\n"
      end

#      item_data.delete('line_numner') if (item_data.key?('line_number'))
      events = [ item_data ]
      @SODA_DEBUG.handleEvents(events)

      return bp
   end
   private :DebugItem

###############################################################################
# DebugContinue -- Method
#     This method starts debugging the current tests after the debugger has 
#     been stopped by hitting a break point.
#
# Input:
#     item_id: the id of the tree item to start debugging at.
#
# Output:
#     None.
# 
###############################################################################
   def DebugContinue(item_id)
      has_kids = false
      kids = nil
      bp = false
      data = nil
      parent = nil
      last_item = nil

      # always execute the first item, as it was the one the bp stopped on. #
      data = @TREE.get_item_data(item_id)
      DebugItem(data, item_id)

      has_kids = @TREE.item_has_children(item_id)
      if (has_kids)
         print "DB-C: Has kids.\n"
         kids = @TREE.get_children(item_id)
         kids.each do |kid|
            data = @TREE.get_item_data(kid)
            next if (data.key?('comment'))
            bp = DebugItem(data, kid)
            return bp if (bp)
         end
      end
     
      root_id = @TREE.get_root_item()
      last_root_id = @TREE.get_last_child(root_id)
      next_item = item_id

      while (next_item != last_root_id)
         last_item = next_item
         next_item = @TREE.get_next_sibling(last_item)

         if (next_item == nil || next_item <= 0)
            parent = @TREE.get_item_parent(last_item)
            print "Last  : #{last_item}\n"
            print "Parent: #{parent}\n"
            next_item = @TREE.get_next_sibling(parent)
         else
            #next_item = @TREE.get_next_sibling(last_item)
         end
         
         data = @TREE.get_item_data(next_item)
         bp = DebugItem(data, next_item)
         return bp if (bp) 
      end

      if (next_item == last_root_id)
         @HIT_BREAK_POINTS = Array.new()
         EndSodaDebug()
      end
   end
   private :DebugContinue

###############################################################################
# OnDebugContinue -- Event Method
#     This method is called when the contine debug menu item is clicked.
#
# Input:
#     None.
#
# Output:
#     None.
# 
###############################################################################
   def OnDebugContinue()
      DebugContinue(@CURRENT_TREE_BP_ID)
   end
   private :OnDebugContinue

###############################################################################
# PrintItemInfo -- Method
#     This method does s dumper print for a given tree item's data store.
#
# Input:
#     item: the tree item to print.
#
# Output:
#     None.
#
###############################################################################
   def PrintItemInfo(item)
      data = @TREE.get_item_data(item)
      print "Item Info: #{item}:\n"
      pp(data)
      print "\n"
   end
   private :PrintItemInfo

###############################################################################
# OnDebugTreeSelChanged -- Event Meethod
#     This method is called when the selected item in the debug tree changes.
#
# Input:
#     event: The event from the debug tree control.
#
# Output:
#     None.
#
###############################################################################
   def OnDebugTreeSelChanged(event)
      item = event.get_item()
      current_row = 0

      data = @DEBUG_TREE.get_item_data(item)
      if (data == nil)
         @DEBUG_PANEL.DeleteGridData()
      else   
         @DEBUG_PANEL.SetGridData(data)
      end
   end
   private :OnDebugTreeSelChanged

###############################################################################
# OnDebugSodaTest -- Event Method
#     This method starts a soda debug instance when the menu item is clicked.
#
# Input:
#     event: This is the event from the menu control.
#
# Output:
#     None.
# 
###############################################################################
   def OnDebugSodaTest(event)
      id = event.get_id()
      @DEBUG_MENU_ITEM.enable(false)
      
      @TIMER = Wx::Timer.new(self, 55)
      evt_timer(55) {
            @CONTINUE_MENU_ITEM.enable(true)
            DebugSodaTest()
      }
      @TIMER.start(15)

   end
   private :OnDebugSodaTest

###############################################################################
# OnSodaMachineConfig -- Event Method.
#     This method is called with a config menu item is clicked.  It sets the
#     soda config options.
#
# Input:
#     event: this event fromt he menu control.
#
# Output:
#     None.
#
###############################################################################
   def OnSodaMachineConfig(event)
      dlg = SodaOptions.new(@SODA_OPTIONS)
      dlg.show_modal()
      result = dlg.get_return_code()
   
      if (result > 0)
         @SODA_OPTIONS = dlg.getSettings()
         pp(@SODA_OPTIONS)
         print "\n"
      end   

      dlg.destroy()
   end
   private :OnSodaMachineConfig

###############################################################################
# OnCloseTest -- Event Method
#     This method is called with close test menu item is clicked.
#
# Input:
#     event: this is the event from the menu control.
#
# Output:
#     None.
# 
###############################################################################
   def OnCloseTest(event)
      print "Closing...\n"
      dlg = nil
      result = nil

      dlg = MessageDialog.new(@FRAME_HANDLE, "Save test before closing?",
            "Save Test?", YES_NO)
      result = dlg.show_modal()

      if (result == ID_YES)
         OnSaveFile()
      end

      @TREE.delete_children(@TREE.get_root_item())
   end
   private :OnCloseTest

###############################################################################
# OnKillFocus -- Event Method
#     This method is called when the focus from the edit grid is changed, and
#     will save off all changes in the grid.
#
# Input:
#     event: this is the event info from the FRAME.
#
# Output:
#     None.
#
###############################################################################
   def OnKillFocus(event)
      SaveGridData()
   end
   private :OnKillFocus

   def GenerateImageList()
      @APPIMAGE_LIST = ImageList.new(16, 16)

      $IMAGES.each do |img|
         bmp = Bitmap.new()
         bmp.load_file(img, BITMAP_TYPE_PNG)
         @APPIMAGE_LIST.add(bmp)
      end
   end

###############################################################################
# on_init --  Event Method
#     This is the method that gets called when the wxapp is started.
#
# Input:
#     None.
#
#  Output:
#     None.
#
###############################################################################
   def on_init
      @SODA_CONFIG_FILE = "soda-config.xml"
      @NO_ICONS = false
      @SODA_INFO_NUMS = {}
      @MAIN_SPLITTER = nil
      @DEBUG_PANEL = nil
      @RUN_MENU_ITEM = nil
      @DEBUG_MENU_ITEM = nil
      @TIMER = nil
      @SODA_TEST_FILE = nil
      @DEBUG_GRID = nil
      @DEBUG_DLG = nil
      @SODA_INFO_NUMS = {}
      @GRID = nil
      @EDITPANEL = nil
      @TREEPANEL = nil
      @APPIMAGE_LIST = nil
      @EDIT_SPLITTER = nil
      @TREE_POPUP_MENU = nil
      @TREE_POPUP_MENU_NO_CHILD = nil
      @TREE_POPUP_MENU_ROOT = nil
      @CURRENT_TREE_ITEM = nil
      @PROCESS_DLG = nil
      @CURRENT_PROCESS_NUM = 0
      @DEBUG_TEXT = nil
      @DEBUG_TREE = nil
      @FRAME_HANDLE = nil
      @APP_NAME = "SodaMachine"
      @APP_SIZE = nil
      @APP_POSITION = nil
      @TREE = nil
      @SODA_DEBUG = nil
      @SODA_OPTIONS = nil
      @CURRENT_TREE_BP_ID
      @BREAK_POINTS = []
      @HIT_BREAK_POINTS = []
      menu_bar = nil
      menu_s = nil
      left_box = BoxSizer.new(Wx::HORIZONTAL)
      os = SodaUtils.GetOsType()

      if (os =~ /osx/i)
         @NO_ICONS = true
      end
      
      @NO_ICONS = true if (!File.exist?($ICON_DIR))

      $SODA_INFO.each do |k, v|
         v['append_menu_id'] = (600 + v['image_index'])
         v['child_menu_id'] = (700 + v['image_index'])
         @SODA_INFO_NUMS["#{v['append_menu_id']}"] = k
         @SODA_INFO_NUMS["#{v['child_menu_id']}"] = k

         $TREE_MENU_EVENT_APPEND[k] = (600 + v['image_index'])
         $TREE_MENU_EVENT_APPEND['delete'] = $DELETE_MENU_ID
         $TREE_MENU_EVENT_APPEND['breakpoint'] = $BREAK_POINT_MENU_ID
         $TREE_MENU_EVENT_APPEND_CHILD[k] = (700 + v['image_index'])
      end

      @TREE_POPUP_MENU = GenerateTreeItemMenu(true, true, false)
      @TREE_POPUP_MENU_NO_CHILD = GenerateTreeItemMenu(false, true, false)
      @TREE_POPUP_MENU_ROOT = GenerateTreeItemMenu(false, true, true)
      @TREE_POPUP_MENU_DELETE = GenerateDeleteItemMenu()

      @APP_SIZE = Size.new(700, 750)
      @APP_POSITION = Point.new(20, 20)

      @FRAME_HANDLE = Frame.new(nil, -1, "SodaMachine", @APP_POSITION, 
            @APP_SIZE)
 
      if (!@NO_ICONS) 
         GenerateImageList()
      end

      menu_s = Menu.new()
      menu_f = Menu.new()
      menu_debug = Menu.new()
      menu_settings = Menu.new()

      @RUN_MENU_ITEM = menu_f.append($RUN_MENU_ID,
            "&Run Soda Test", "Run Curent Soda Test")

      @DEBUG_MENU_ITEM = menu_debug.append($DEBUG_MENU_ID,
            "&Debug Soda Test", "Debug Current Soda Test")
      @CONTINUE_MENU_ITEM = menu_debug.append(Wx::ID_ANY, "Continue")
      @CONTINUE_MENU_ITEM.enable(false)
      
      options_menu_item = menu_settings.append(Wx::ID_ANY,
            "&SodaMahcine Config...")

      open_menu_item = menu_s.append(Wx::ID_OPEN, 
            '&Open Soda Test', 'Open a Soda Test')
      save_as_menu_item = menu_s.append(Wx::ID_SAVEAS,
            "Save &As...", "Save Soda Test")
      close_test_menu_item = menu_s.append(Wx::ID_ANY, "&Close Test")

      evt_menu(close_test_menu_item, :OnCloseTest)
      evt_menu(options_menu_item, :OnSodaMachineConfig)
      evt_menu(@CONTINUE_MENU_ITEM, :OnDebugContinue)
      evt_menu(@RUN_MENU_ITEM, :OnRunSodaTest)
      evt_menu(@DEBUG_MENU_ITEM, :OnDebugSodaTest)
      evt_menu(open_menu_item, :OnOpenFile)
      evt_menu(save_as_menu_item, :OnSaveFile)

      menu_bar = MenuBar.new()
      menu_bar.append(menu_s, "&File")
      menu_bar.append(menu_f, "&Run")
      menu_bar.append(menu_debug, "&Debug")
      menu_bar.append(menu_settings, "&Settings")
   
      @FRAME_HANDLE.set_menu_bar(menu_bar)
      @FRAME_HANDLE.create_tool_bar(TB_FLAT, -1, "toolbar") 
      @FRAME_HANDLE.create_status_bar(1, ST_SIZEGRIP, -1, "statusbar")

      @MAIN_SPLITTER = SplitterWindow.new(@FRAME_HANDLE, -1, Point.new(0,0),
            DEFAULT_SIZE, SP_3DBORDER, "mainsplitter")
      @MAIN_SPLITTER.set_sash_gravity(0.0)

      @EDIT_SPLITTER = SplitterWindow.new(@MAIN_SPLITTER, -1, Point.new(0,0), 
            @APP_SIZE,SP_3DBORDER, "editsplitter")

      @DEBUG_PANEL = DebugPanel.new(@MAIN_SPLITTER)
      @EDITPANEL = EditPanel.new(@EDIT_SPLITTER)
      @TREEPANEL = TreePanel.new(@EDIT_SPLITTER, @APPIMAGE_LIST)
      @TREE = @TREEPANEL.GetTree()
      @GRID = @EDITPANEL.GetGrid()
      evt_tree_item_menu(@TREE, :OnTreePopUpMenu)
      evt_tree_sel_changed(@TREE, :OnTreeChanged)
      evt_tree_sel_changing(@TREE, :OnTreeSelChanging)
      evt_button(@EDITPANEL.GetAddButton(), :OnGridAddButton)
      evt_button(@EDITPANEL.GetRemoveButton(), :OnGridRemoveButton)

      @DEBUG_TEXT = @DEBUG_PANEL.GetTextCtrl()
      @DEBUG_TREE = @DEBUG_PANEL.GetTreeCtrl()
      @DEBUG_GRID = @DEBUG_PANEL.GetGrid()
      evt_tree_sel_changed(@DEBUG_TREE, :OnDebugTreeSelChanged)

      @PRINT_PROC = Proc.new { |msg|
         start_ap = @DEBUG_TEXT.get_insertion_point()

         @DEBUG_TEXT.append_text(msg)
         ap = @DEBUG_TEXT.get_insertion_point()
         
         if (msg =~ /^\(!\)/)
            txt = TextAttr.new(Wx::RED)
            @DEBUG_TEXT.set_style(start_ap, ap, txt)
         end
         @DEBUG_TEXT.update()
      }

      @CURRENT_TREE_ITEM = @TREE.get_root_item()
      @TREE.expand(@CURRENT_TREE_ITEM)
      @EDIT_SPLITTER.split_vertically(@TREEPANEL, @EDITPANEL, 50) 
      @MAIN_SPLITTER.split_horizontally(@EDIT_SPLITTER, @DEBUG_PANEL)

      evt_kill_focus(:OnKillFocus)

      if (File.exist?(@SODA_CONFIG_FILE))
         @SODA_OPTIONS = Hash.new()
         config_data = SodaUtils.ReadSodaConfig(@SODA_CONFIG_FILE)
         
         if (config_data.key?('gvars'))
            @SODA_OPTIONS['gvars'] = config_data['gvars']
         end

         if (config_data.key?('cmdopts'))
            config_data['cmdopts'].each do |cmd|
               if (cmd.key?('browser'))
                  @SODA_OPTIONS['browser'] = cmd['browser']
                  break
               end
            end
         end
      end

      @FRAME_HANDLE.show()
   end

end

###############################################################################
# Start executing code here -->
###############################################################################

   SodaMachine.new.main_loop()
 

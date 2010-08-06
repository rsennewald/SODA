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
module SodaMachineInfo

   $TREE_MENU_EVENT_APPEND = {}
   $TREE_MENU_EVENT_APPEND_CHILD = {}
   $APPEND_MENU_ID = 900
   $CHILD_MENU_ID = 901
   $DELETE_MENU_ID = 902
   $RUN_MENU_ID = 903
   $BREAK_POINT_MENU_ID = 904
   $DEBUG_MENU_ID = 905
   $BREAK_POINT_UNSET_MENU_ID = 906
   $IMAGES = [
      'icons/root.png',
      'icons/mozicon16.png',
      'icons/textfield.png',
      'icons/puts.png',
      'icons/button.png',
      'icons/wait.png',
      'icons/table.png',
      'icons/form.png',
      'icons/checkbox.png',
      'icons/radio.png',
      'icons/csv.png',
      'icons/script.png',
      'icons/select.png',
      'icons/link.png',
      'icons/div.png',
      'icons/hidden.png',
      'icons/var.png',
      'icons/comment.png',
      'icons/delete.png',
      'icons/append.png',
      'icons/breakpoint.png'
   ]
   $IMAGE_INDEX = {
      'delete' => 18,
      'append' => 19,
      'breakpoint' => 20
   }

   $SODA_INFO = {
      'root' => {
         'allow_kids' => true,
         'image_index' => 0
      },
      'browser' => {
         'allow_kids' => false,
         'image_index' => 1
      },
      'textfield' => {
         'allow_kids' => false,
         'image_index' => 2
      },
      'puts' => {
         'allow_kids' => false,
         'image_index' => 3
      },
      'button' => {
         'allow_kids' => false,
         'image_index' => 4
      },
      'wait' => {
         'allow_kids' => true,
         'image_index' => 5
      },
      'table' => {
         'allow_kids' => true,
         'image_index' => 6
      },
      'form' => {
         'allow_kids' => true,
         'image_index' => 7
      },
      'checkbox' => {
         'allow_kids' => false,
         'image_index' => 8
      },
      'radio' => {
         'allow_kids' => false,
         'image_index' => 9
      },
      'csv' => {
         'allow_kids' => true,
         'image_index' => 10
      },
      'script' => {
         'allow_kids' => true,
         'image_index' => 11
      },
      'select' => {
         'allow_kids' => false,
         'image_index' => 12
      },
      'link' => {
         'allow_kids' => false,
         'image_index' => 13
      },
      'div' => {
         'allow_kids' => true,
         'image_index' => 14
      },
      'hidden' => {
         'allow_kids' => false,
         'image_index' => 15
      },
      'var' => {
         'allow_kids' => false,
         'image_index' => 16
      },
      'comment' => {
         'allow_kids' => false,
         'image_index' => 17
      }
   }
   
end



# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  ImportAIFForms.tcl
#
#  Tcl based Mentor Graphics Automation solution to Import an AIF file and
#  generate Pad, Padstack, Cell, and PDB to be used in a IC Package design.
#  This script should be run with "wish" or "tclsh" - it cannot be dragged
#  onto LM.
#
#  This script requires Tcl 8.4.20.  Tcl 8.5.x and 8.6.x are not supported
#  by the Mentor Graphics COM API interface.  You can download Tcl 8.4.20
#  from ActiveState.com:
#
#    http://www.activestate.com/activetcl/downloads
#
#
#  (c) July 2014 - Mentor Graphics Corporation
#
#  Mike Walsh - mike_walsh@mentor.com
#
#  Mentor Graphics Corporation
#  1001 Winstead Drive, Suite 380
#  Cary, North Carolina 27513
#
#  This software is NOT officially supported by Mentor Graphics.
#
#  ####################################################################
#  ####################################################################
#  ## The following  software  is  "freeware" which  Mentor Graphics ##
#  ## Corporation  provides as a courtesy  to our users.  "freeware" ##
#  ## is provided  "as is" and  Mentor  Graphics makes no warranties ##
#  ## with  respect  to "freeware",  either  expressed  or  implied, ##
#  ## including any implied warranties of merchantability or fitness ##
#  ## for a particular purpose.                                      ##
#  ####################################################################
#  ####################################################################
#
#  Change Log:
#
#    07/20/2014 - Initial version.  Moved all forms support code to a
#                 separate file and namespace to ease code maintenance.
#

namespace eval AIFForms {
    variable widgets
    variable lblist [list]
    variable rv
    variable selectmode multiple

    array set widgets {
        lb .aifListBox
    }

    ##  Select From List
    proc SelectFromList { { p "Select From List" } { l [list] } } {
        variable rv
        variable lblist
        variable selectmode

        set lblist $l
        set selectmode multiple
        set rv [list]
        SelectFromListBoxDialog $p
        return $rv
    }

    ##  Select One From List
    proc SelectOneFromList { { p "Select One From List" } { l [list] } } {
        variable rv
        variable lblist
        variable selectmode

        set lblist $l
        set selectmode single
        SelectFromListBoxDialog $p
        return $rv
    }

    ##  Select From List Box
    proc SelectFromListBox {} {
        variable rv
        variable widgets

        set dlg $widgets(lb)

        ##  If there is a selection, capture value and index
        if { [$dlg.f.sf.list curselection] != "" } {
            foreach i [$dlg.f.sf.list curselection] {
                lappend rv [list $i [$dlg.f.sf.list get $i]]
            }
        }

        ##  Clean up and return
        destroy $dlg
        return $rv
    }

    #
    #  Select From List Box Dialog
    #
    proc SelectFromListBoxDialog { { p "Select From List Box" } } {
        variable lblist
        variable widgets
        variable selectmode

        set dlg $widgets(lb)
    
        #  Create the top level window and withdraw it
        toplevel  $dlg
        wm withdraw $dlg
    
        #  Create the frame
        ttk::frame $dlg.f -relief flat
    
        #  Create a sub-frame to hold all the pieces
        ttk::labelframe $dlg.f.sf -text $p
        listbox $dlg.f.sf.list -relief raised -borderwidth 2 -selectmode $selectmode \
            -yscrollcommand "$dlg.f.sf.scroll set" -listvariable AIFForms::lblist
        ttk::scrollbar $dlg.f.sf.scroll -command "$dlg.f.sf.list yview"
        pack $dlg.f.sf.list $dlg.f.sf.scroll \
            -side left -fill both -expand 1 -in $dlg.f.sf
        grid rowconfigure $dlg.f.sf 0 -weight 1
        grid columnconfigure $dlg.f.sf 0 -weight 1
    
        #  Layout the dialog box
        grid config $dlg.f.sf.list -row 0 -column 0 -sticky wnse
        grid config $dlg.f.sf.scroll -row 0 -column 1 -sticky ns
        pack $dlg.f.sf -padx 25 -pady 25 -fill both -in $dlg.f -expand 1
    
        #  Action buttons
    
        ttk::frame $dlg.f.buttons -relief flat
    
        ttk::button $dlg.f.buttons.ok -text "Ok" -command { AIFForms::SelectFromListBox }
        ttk::button $dlg.f.buttons.cancel -text "Cancel" -command { destroy $AIFForms::widgets(lb) }
        
        pack $dlg.f.buttons.ok -side left
        pack $dlg.f.buttons.cancel -side right
        pack $dlg.f.buttons -padx 5 -pady 10 -ipadx 10
    
        pack $dlg.f.buttons -in $dlg.f -expand 1
    
        grid rowconfigure $dlg.f 0 -weight 1
        grid rowconfigure $dlg.f 1 -weight 0
    
        pack $dlg.f -fill x -expand 1
    
        #  Window manager settings for dialog
        wm title $dlg $p
        wm protocol $dlg WM_DELETE_WINDOW {
            $widgets(lb).f.buttons.cancel invoke
        }
        wm transient $dlg
    
        #  Ready to display the dialog
        wm deiconify $dlg
    
        #  Make this a modal dialog
        catch { tk visibility $dlg }
        #focus $dlg.f.sf.namet
        catch { grab set $dlg }
        catch { tkwait window $dlg }
    }
}

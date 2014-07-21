# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  MGC.tcl
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
#    07/21/2014 - Initial version.  Moved interaction with Mentor tools
#                 to separate file and namespace to ease code maintenance.
#

##
##  Define the MGC namespace and procedure supporting operations
##
namespace eval MGC {

    #
    #  Open Expedition, open the database, handle licensing.
    #
    proc OpenExpedition {} {
        #  Crank up Expedition
    
        if { $::ediu(connectMode) } {
            Transcript $::ediu(MsgNote) "Connecting to existing Expedition session."
            set ::ediu(pcbApp) [::tcom::ref getactiveobject "MGCPCB.ExpeditionPCBApplication"]
    
            #  Use the active PCB document object
            set errorCode [catch {set ::ediu(pcbDoc) [$::ediu(pcbApp) ActiveDocument] } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        } else {
            Transcript $::ediu(MsgNote) "Opening Expedition."
            set ::ediu(pcbApp) [::tcom::ref createobject "MGCPCB.ExpeditionPCBApplication"]
    
            # Open the database
            Transcript $::ediu(MsgNote) "Opening database for Expedition."
    
            #  Create a PCB document object
            set errorCode [catch {set ::ediu(pcbDoc) [$::ediu(pcbApp) \
                OpenDocument $::ediu(targetPath)] } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        }
    
        #  Turn off trivial dialog boxes - makes batch operations smoother
        [$::ediu(pcbApp) Gui] SuppressTrivialDialogs True
    
        #  Set application visibility
        $::ediu(pcbApp) Visible $::ediu(appVisible)
    
        #  Ask Expedition document for the key
        set key [$::ediu(pcbDoc) Validate "0" ] 
    
        #  Get token from license server
        set licenseServer [::tcom::ref createobject "MGCPCBAutomationLicensing.Application"]
    
        set licenseToken [ $licenseServer GetToken $key ] 
    
        #  Ask the document to validate the license token
        $::ediu(pcbDoc) Validate $licenseToken  
        #$pcbApp LockServer False
        #  Suppress trivial dialog boxes
        #[$::ediu(pcbDoc) Gui] SuppressTrivialDialogs True
    }

    #
    #  Open the Padstack Editor
    #
    proc OpenPadstackEditor { { mode "-opendatabase" } } {
        #  Crank up the Padstack Editor once per sessions
    
        Transcript $::ediu(MsgNote) [format "Opening Padstack Editor in %s mode." $::ediu(mode)]
    
        ##  Which mode?  Design or Library?
        if { $::ediu(mode) == $::ediu(designMode) } {
            ##  Invoke Expedition on the design so the Padstack Editor can be started
            ##  Catch any exceptions raised by opening the database
    
            ##  Is Expedition already open?  It will be if the Padstack Editor
            ##  is called as part of building a Cell.  In this case, there is no
            ##  reason to reopen Expedition as it will end up in read-only mode.
    
            if { $mode == "-opendatabase" } {
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    ediuUpdateStatus $::ediu(ready)
                    return
                }
            } else {
                Transcript $::ediu(MsgNote) "Reusing previously opened instance of Expedition."
            }
            set ::ediu(pdstkEdtr) [$::ediu(pcbDoc) PadstackEditor]
            set ::ediu(pdstkEdtrDb) [$::ediu(pdstkEdtr) ActiveDatabase]
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            set ::ediu(pdstkEdtr) [::tcom::ref createobject "MGCPCBLibraries.PadstackEditorDlg"]
            # Open the database
            set errorCode [catch {set ::ediu(pdstkEdtrDb) [$::ediu(pdstkEdtr) \
                OpenDatabaseEx $::ediu(targetPath) false] } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
    
        # Lock the server
        set errorCode [catch { $::ediu(pdstkEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }
    
        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $::ediu(pdstkEdtr) Visible $::ediu(appVisible)
    }
    
    #
    #  Close Padstack Editor Lib
    #
    proc ClosePadstackEditor { { mode "-closedatabase" } } {
        ##  Which mode?  Design or Library?
    
        if { $::ediu(mode) == $::ediu(designMode) } {
            Transcript $::ediu(MsgNote) "Closing database for Padstack Editor."
            set errorCode [catch { $::ediu(pdstkEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            Transcript $::ediu(MsgNote) "Closing Padstack Editor."
            ##  Close Padstack Editor
            $::ediu(pdstkEdtr) SaveActiveDatabase
            $::ediu(pdstkEdtr) Quit
            ##  Close the Expedition Database
    
            ##  May want to leave Expedition and the database open ...
            #if { $mode == "-closedatabase" } {
            #    $::ediu(pcbDoc) Save
            #    $::ediu(pcbDoc) Close
            #    ##  Close Expedition
            #    $::ediu(pcbApp) Quit
            #}
            if { !$::ediu(connectMode) } {
                ##  Close the Expedition Database and terminate Expedition
                $::ediu(pcbDoc) Close
                ##  Close Expedition
                $::ediu(pcbApp) Quit
            }
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            Transcript $::ediu(MsgNote) "Closing database for Padstack Editor."
            set errorCode [catch { $::ediu(pdstkEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $::ediu(pdstkEdtr) CloseActiveDatabase True
            Transcript $::ediu(MsgNote) "Closing Padstack Editor."
            $::ediu(pdstkEdtr) Quit
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
    }

    #
    #  Open the Cell Editor
    #
    proc OpenCellEditor { } {
        ##  Which mode?  Design or Library?
        if { $::ediu(mode) == $::ediu(designMode) } {
            ##  Invoke Expedition on the design so the Cell Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenExpedition } errorMessage]
            if {$errorCode != 0} {
                ediuUpdateStatus $::ediu(ready)
                return
            }
            set ::ediu(cellEdtr) [$::ediu(pcbDoc) CellEditor]
            Transcript $::ediu(MsgNote) "Using design database for Cell Editor."
            set ::ediu(cellEdtrDb) [$::ediu(cellEdtr) ActiveDatabase]
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            set ::ediu(cellEdtr) [::tcom::ref createobject "CellEditorAddin.CellEditorDlg"]
            set ::ediu(pdstkEdtr) [::tcom::ref createobject "MGCPCBLibraries.PadstackEditorDlg"]
            # Open the database
            Transcript $::ediu(MsgNote) "Opening library database for Cell Editor."
    
            set errorCode [catch {set ::ediu(cellEdtrDb) [$::ediu(cellEdtr) \
                OpenDatabase $::ediu(targetPath) false] } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
    
        #set ::ediu(cellEdtrDb) [$::ediu(cellEdtr) OpenDatabase $::ediu(targetPath) false]
        set errorCode [catch { $::ediu(cellEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }
    
        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $::ediu(cellEdtr) Visible $::ediu(appVisible)
    }
    
    #
    #  Close Cell Editor Lib
    #
    proc CloseCellEditor {} {
        #ediuCloseCellEditorDb
        #Transcript $::ediu(MsgNote) "Closing Cell Editor."
        #$::ediu(cellEdtr) Quit
        ##  Which mode?  Design or Library?
    
        if { $::ediu(mode) == $::ediu(designMode) } {
            Transcript $::ediu(MsgNote) "Closing database for Cell Editor."
            set errorCode [catch { $::ediu(cellEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            Transcript $::ediu(MsgNote) "Closing Cell Editor."
            ##  Close Padstack Editor
            set errorCode [catch { $::ediu(cellEdtr) SaveActiveDatabase } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            #$::ediu(cellEdtr) SaveActiveDatabase
            $::ediu(cellEdtr) Quit
    
            ##  Save the Expedition Database
            $::ediu(pcbDoc) Save
    
            if { !$::ediu(connectMode) } {
                ##  Close the Expedition Database and terminate Expedition
                $::ediu(pcbDoc) Close
                ##  Close Expedition
                $::ediu(pcbApp) Quit
            }
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            Transcript $::ediu(MsgNote) "Closing database for Cell Editor."
            set errorCode [catch { $::ediu(cellEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $::ediu(cellEdtr) CloseActiveDatabase True
            Transcript $::ediu(MsgNote) "Closing Cell Editor."
            $::ediu(cellEdtr) Quit
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
    }
    
    #
    #  Open the PDB Editor
    #
    proc OpenPDBEditor {} {
        ##  Which mode?  Design or Library?
        if { $::ediu(mode) == $::ediu(designMode) } {
            ##  Invoke Expedition on the design so the PDB Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenExpedition } errorMessage]
            if {$errorCode != 0} {
                ediuUpdateStatus $::ediu(ready)
                return
            }
            set ::ediu(partEdtr) [$::ediu(pcbDoc) PartEditor]
            Transcript $::ediu(MsgNote) "Using design database for PDB Editor."
            set ::ediu(partEdtrDb) [$::ediu(partEdtr) ActiveDatabase]
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            set ::ediu(partEdtr) [::tcom::ref createobject "MGCPCBLibraries.PartsEditorDlg"]
            # Open the database
            Transcript $::ediu(MsgNote) "Opening library database for PDB Editor."
    
            set errorCode [catch {set ::ediu(partEdtrDb) [$::ediu(partEdtr) \
                OpenDatabaseEx $::ediu(targetPath) false] } errorMessage]
                puts $errorCode
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            puts "22->  $errorCode"
            puts "33->  $errorMessage"
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
                puts "OpenPDBEdtr - 1"
    
        #set ::ediu(partEdtrDb) [$::ediu(partEdtr) OpenDatabase $::ediu(targetPath) false]
        set errorCode [catch { $::ediu(partEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }
            puts "44->  $errorCode"
            puts "55->  $errorMessage"
    
        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $::ediu(partEdtr) Visible $::ediu(appVisible)
    
        #return -code return 0
    }
    
    #
    #  Close PDB Editor Lib
    #
    proc ClosePDBEditor { } {
        ##  Which mode?  Design or Library?
    
        if { $::ediu(mode) == $::ediu(designMode) } {
            Transcript $::ediu(MsgNote) "Closing database for PDB Editor."
            set errorCode [catch { $::ediu(partEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            Transcript $::ediu(MsgNote) "Closing PDB Editor."
            ##  Close Padstack Editor
            $::ediu(partEdtr) SaveActiveDatabase
            $::ediu(partEdtr) Quit
            ##  Close the Expedition Database
            ##  Need to save?
            if { [$::ediu(pcbDoc) IsSaved] == "False" } {
                $::ediu(pcbDOc) Save
            }
            #$::ediu(pcbDoc) Save
            #$::ediu(pcbDoc) Close
            ##  Close Expedition
            #$::ediu(pcbApp) Quit
    
            if { !$::ediu(connectMode) } {
                ##  Close the Expedition Database and terminate Expedition
                $::ediu(pcbDoc) Close
                ##  Close Expedition
                $::ediu(pcbApp) Quit
            }
        } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
            Transcript $::ediu(MsgNote) "Closing database for PDB Editor."
            set errorCode [catch { $::ediu(partEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $::ediu(partEdtr) CloseActiveDatabase True
            Transcript $::ediu(MsgNote) "Closing PDB Editor."
            $::ediu(partEdtr) Quit
        } else {
            Transcript $::ediu(MsgError) "Mode not set, build aborted."
            return -code return 1
        }
    }

}

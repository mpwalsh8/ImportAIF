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

        if { [string is true $xAIF::Settings(connectMode)] } {
            GUI::Transcript -severity note -msg "Connecting to existing Expedition session."
            #  Need to make sure Xpedition is actually running ...
            set errorCode [catch { set xAIF::Settings(pcbApp) [::tcom::ref getactiveobject "MGCPCB.ExpeditionPCBApplication"] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                set xAIF::Settings(connectMode) off
                return -code return 1
            }

            #  Use the active PCB document object
            set errorCode [catch {set xAIF::Settings(pcbDoc) [$xAIF::Settings(pcbApp) ActiveDocument] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }

            #  Make sure API returned an active database - no error code which is odd ...
            if { [string equal $xAIF::Settings(pcbDoc) ""] } {
                GUI::Transcript -severity error -msg "Unable to connect to Xpedition design, is Xpedition database open?"
                set xAIF::Settings(connectMode) off
                return -code return 1
            }
        } else {
            set xAIF::Settings(targetPath) $GUI::Dashboard::DesignPath
            GUI::Transcript -severity note -msg "Opening Expedition."
            set xAIF::Settings(pcbApp) [::tcom::ref createobject "MGCPCB.ExpeditionPCBApplication"]
            $xAIF::Settings(pcbApp) Visible $xAIF::Settings(appVisible)

            # Open the database
            GUI::Transcript -severity note -msg "Opening database for Expedition."

            #  Create a PCB document object
            set errorCode [catch {set xAIF::Settings(pcbDoc) [$xAIF::Settings(pcbApp) \
                OpenDocument $xAIF::Settings(targetPath)] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        }

        #  Turn off trivial dialog boxes - makes batch operations smoother
        [$xAIF::Settings(pcbApp) Gui] SuppressTrivialDialogs True

        #  Set application visibility
        $xAIF::Settings(pcbApp) Visible $xAIF::Settings(appVisible)

        #  Ask Expedition document for the key
        set key [$xAIF::Settings(pcbDoc) Validate "0" ] 

        #  Get token from license server
        set licenseServer [::tcom::ref createobject "MGCPCBAutomationLicensing.Application"]

        set licenseToken [ $licenseServer GetToken $key ] 

        #  Ask the document to validate the license token
        $xAIF::Settings(pcbDoc) Validate $licenseToken  
        #$pcbApp LockServer False
        #  Suppress trivial dialog boxes
        #[$xAIF::Settings(pcbDoc) Gui] SuppressTrivialDialogs True

        set xAIF::Settings(targetPath) [$xAIF::Settings(pcbDoc) Path][$xAIF::Settings(pcbDoc) Name]
        set GUI::Dashboard::DesignPath [$xAIF::Settings(pcbDoc) Path][$xAIF::Settings(pcbDoc) Name]
        #puts [$xAIF::Settings(pcbDoc) Path][$xAIF::Settings(pcbDoc) Name]
        GUI::Transcript -severity note -msg [format "Connected to design database:  %s%s" \
            [$xAIF::Settings(pcbDoc) Path] [$xAIF::Settings(pcbDoc) Name]]
    }

    #
    #  Open Library Manager, open the database
    #
    proc OpenLibraryManager {} {
puts "X0"
        #  Crank up Library Manager

        if { [string is true $xAIF::Settings(connectMode)] } {
            GUI::Transcript -severity note -msg "Connecting to existing Library Manager session."
            #  Need to make sure Xpedition is actually running ...
            set errorCode [catch { set xAIF::Settings(libApp) [::tcom::ref getactiveobject "LibraryManager.Application"] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg "Unable to connect to Library Manager, is Library Manager running?"
                set xAIF::Settings(connectMode) off
                return -code return 1
            }

            #  Use the active LMC library object
            set errorCode [catch {set xAIF::Settings(libLib) [$xAIF::Settings(libApp) ActiveLibrary] } errorMessage]
puts "X1"
puts $xAIF::Settings(libLib)
            if {$errorCode != 0} {
puts "X2"
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }

            #  Make sure API returned an active database - no error code which is odd ...
            if { [string equal $xAIF::Settings(libLib) ""] } {
                GUI::Transcript -severity error -msg "Unable to connect to Library Manager library, is Library Manager library open?"
                return -code return 1
            }
puts "X3"
        } else {
            GUI::Transcript -severity note -msg "Opening Library Manager."
            set xAIF::Settings(libApp) [::tcom::ref createobject "LibraryManager.Application"]
            $xAIF::Settings(libApp) Visible $xAIF::Settings(appVisible)

            # Open the database
            GUI::Transcript -severity note -msg "Opening library database for Library Manager."

            #  Create a LMC library object
            set errorCode [catch {set xAIF::Settings(linLib) [$xAIF::Settings(libApp) \
                OpenLibrary $xAIF::Settings(targetPath)] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        }
puts "X4"

        #  Turn off trivial dialog boxes - makes batch operations smoother
        #[$xAIF::Settings(libApp) Gui] SuppressTrivialDialogs True

        #  Set application visibility
        #$xAIF::Settings(libApp) Visible $xAIF::Settings(appVisible)

        set GUI::Dashboard::LibraryPath [$xAIF::Settings(libLib) FullName]
        set xAIF::Settings(targetPath) $GUI::Dashboard::LibraryPath

        #  Close the library so the other editors can operate on it.
        $xAIF::Settings(libLib) Close
        GUI::Transcript -severity note -msg [format "Connected to Central Library database:  %s" \
            $GUI::Dashboard::LibraryPath]
    }

    #
    #  Open the Padstack Editor
    #
    proc OpenPadstackEditor { { mode "-opendatabase" } } {
        #  Crank up the Padstack Editor once per sessions

        GUI::Transcript -severity note -msg [format "Opening Padstack Editor in %s mode." $GUI::Dashboard::Mode]

        ##  Which mode?  Design or Library?
        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            ##  Invoke Expedition on the design so the Padstack Editor can be started
            ##  Catch any exceptions raised by opening the database

            ##  Is Expedition already open?  It will be if the Padstack Editor
            ##  is called as part of building a Cell.  In this case, there is no
            ##  reason to reopen Expedition as it will end up in read-only mode.

            if { $mode == "-opendatabase" } {
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return -code return 1
                }
            } else {
                GUI::Transcript -severity note -msg "Reusing previously opened instance of Expedition."
            }
            set xAIF::Settings(pdstkEdtr) [$xAIF::Settings(pcbDoc) PadstackEditor]
            set xAIF::Settings(pdstkEdtrDb) [$xAIF::Settings(pdstkEdtr) ActiveDatabase]
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            set xAIF::Settings(pdstkEdtr) [::tcom::ref createobject "MGCPCBLibraries.PadstackEditorDlg"]
            # Open the database
            set errorCode [catch {set xAIF::Settings(pdstkEdtrDb) [$xAIF::Settings(pdstkEdtr) \
                OpenDatabaseEx $xAIF::Settings(targetPath) false] } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }

        # Lock the server
        set errorCode [catch { $xAIF::Settings(pdstkEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }

        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $xAIF::Settings(pdstkEdtr) Visible $xAIF::Settings(appVisible)
    }

    #
    #  Close Padstack Editor Lib
    #
    proc ClosePadstackEditor { { mode "-closedatabase" } } {
        ##  Which mode?  Design or Library?

        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            GUI::Transcript -severity note -msg "Closing database for Padstack Editor."
            set errorCode [catch { $xAIF::Settings(pdstkEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            GUI::Transcript -severity note -msg "Closing Padstack Editor."
            ##  Close Padstack Editor
            $xAIF::Settings(pdstkEdtr) SaveActiveDatabase
            $xAIF::Settings(pdstkEdtr) Quit
            ##  Close the Expedition Database

            ##  May want to leave Expedition and the database open ...
            #if { $mode == "-closedatabase" } {
            #    $xAIF::Settings(pcbDoc) Save
            #    $xAIF::Settings(pcbDoc) Close
            #    ##  Close Expedition
            #    $xAIF::Settings(pcbApp) Quit
            #}
            if { [string is false $xAIF::Settings(connectMode)] } {
                ##  Close the Expedition Database and terminate Expedition
                $xAIF::Settings(pcbDoc) Close
                ##  Close Expedition
                $xAIF::Settings(pcbApp) Quit
            }
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            GUI::Transcript -severity note -msg "Closing database for Padstack Editor."
            set errorCode [catch { $xAIF::Settings(pdstkEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $xAIF::Settings(pdstkEdtr) CloseActiveDatabase True
            GUI::Transcript -severity note -msg "Closing Padstack Editor."
            $xAIF::Settings(pdstkEdtr) Quit
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }
    }

    #
    #  MGC::OpenCellEditor - open the Cell Editor
    #
    proc OpenCellEditor { } {
        ##  Which mode?  Design or Library?
        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            set xAIF::Settings(targetPath) $GUI::Dashboard::DesignPath
            ##  Invoke Expedition on the design so the Cell Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenExpedition } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                GUI::StatusBar::UpdateStatus -busy off
                return
            }
            set xAIF::Settings(cellEdtr) [$xAIF::Settings(pcbDoc) CellEditor]
            GUI::Transcript -severity note -msg "Using design database for Cell Editor."
            set xAIF::Settings(cellEdtrDb) [$xAIF::Settings(cellEdtr) ActiveDatabase]
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            set xAIF::Settings(targetPath) $GUI::Dashboard::LibraryPath
puts "Z1"
            set xAIF::Settings(cellEdtr) [::tcom::ref createobject "CellEditorAddin.CellEditorDlg"]
puts "Z2"
            set xAIF::Settings(pdstkEdtr) [::tcom::ref createobject "MGCPCBLibraries.PadstackEditorDlg"]
puts "Z3"
flush stdout
            # Open the database
            GUI::Transcript -severity note -msg "Opening library database for Cell Editor."
puts "Z4"
flush stdout

set sTime [clock format [clock seconds] -format "%m/%d/%Y %T"]
            set errorCode [catch {set xAIF::Settings(cellEdtrDb) [$xAIF::Settings(cellEdtr) \
                OpenDatabase $xAIF::Settings(targetPath) false] } errorMessage]
set cTime [clock format [clock seconds] -format "%m/%d/%Y %T"]
GUI::Transcript -severity note -msg [format "Start Time:  %s" $sTime]
GUI::Transcript -severity note -msg [format "Completion Time:  %s" $cTime]

puts "Z5"
flush stdout
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }
puts "Z6"

        #set xAIF::Settings(cellEdtrDb) [$xAIF::Settings(cellEdtr) OpenDatabase $xAIF::Settings(targetPath) false]
        set errorCode [catch { $xAIF::Settings(cellEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }

        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $xAIF::Settings(cellEdtr) Visible $xAIF::Settings(appVisible)
    }

    #
    #  Close Cell Editor Lib
    #
    proc CloseCellEditor {} {
        ##  Which mode?  Design or Library?

        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            GUI::Transcript -severity note -msg "Closing database for Cell Editor."
            set errorCode [catch { $xAIF::Settings(cellEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            GUI::Transcript -severity note -msg "Closing Cell Editor."
            ##  Close Padstack Editor
            set errorCode [catch { $xAIF::Settings(cellEdtr) SaveActiveDatabase } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            #$xAIF::Settings(cellEdtr) SaveActiveDatabase
            $xAIF::Settings(cellEdtr) Quit

            ##  Save the Expedition Database
            $xAIF::Settings(pcbDoc) Save

            if { [string is false $xAIF::Settings(connectMode)] } {
                ##  Close the Expedition Database and terminate Expedition
                $xAIF::Settings(pcbDoc) Close
                ##  Close Expedition
                $xAIF::Settings(pcbApp) Quit
            }
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            GUI::Transcript -severity note -msg "Closing database for Cell Editor."
            set errorCode [catch { $xAIF::Settings(cellEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $xAIF::Settings(cellEdtr) CloseActiveDatabase True
            GUI::Transcript -severity note -msg "Closing Cell Editor."
            $xAIF::Settings(cellEdtr) Quit
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }
    }

    #
    #  Open the PDB Editor
    #
    proc OpenPDBEditor {} {
puts "P1"
        ##  Which mode?  Design or Library?
        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            set xAIF::Settings(targetPath) $GUI::Dashboard::DesignPath
            ##  Invoke Expedition on the design so the PDB Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenExpedition } errorMessage]
            if {$errorCode != 0} {
puts "P2"
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                GUI::StatusBar::UpdateStatus -busy off
                return -code return 1
            }
puts "P3"
            set xAIF::Settings(partEdtr) [$xAIF::Settings(pcbDoc) PartEditor]
            GUI::Transcript -severity note -msg "Using design database for PDB Editor."
            set xAIF::Settings(partEdtrDb) [$xAIF::Settings(partEdtr) ActiveDatabase]
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            set xAIF::Settings(targetPath) $GUI::Dashboard::LibraryPath
puts "P4"
            set xAIF::Settings(partEdtr) [::tcom::ref createobject "MGCPCBLibraries.PartsEditorDlg"]
            # Open the database
            GUI::Transcript -severity note -msg "Opening library database for PDB Editor."
puts $xAIF::Settings(partEdtr)
puts $xAIF::Settings(targetPath)
            set errorCode [catch {set xAIF::Settings(partEdtrDb) [$xAIF::Settings(partEdtr) \
                OpenDatabaseEx $xAIF::Settings(targetPath) false] } errorMessage]
            if {$errorCode != 0} {
puts "P5"
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            puts "22->  $errorCode"
            puts "33->  $errorMessage"
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }
puts "P6"
puts "OpenPDBEdtr - 1"

        #set xAIF::Settings(partEdtrDb) [$xAIF::Settings(partEdtr) OpenDatabase $xAIF::Settings(targetPath) false]
        set errorCode [catch { $xAIF::Settings(partEdtr) LockServer } errorMessage]
        if {$errorCode != 0} {
            GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
            return -code return 1
        }
            puts "44->  $errorCode"
            puts "55->  $errorMessage"

        # Display the dialog box?  Note this isn't necessary
        # but done for clarity and useful for debugging purposes.
        $xAIF::Settings(partEdtr) Visible $xAIF::Settings(appVisible)

        #return -code return 0
    }

    #
    #  Close PDB Editor Lib
    #
    proc ClosePDBEditor { } {
        ##  Which mode?  Design or Library?

        if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
            GUI::Transcript -severity note -msg "Closing database for PDB Editor."
            set errorCode [catch { $xAIF::Settings(partEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            GUI::Transcript -severity note -msg "Closing PDB Editor."
            ##  Close Padstack Editor
            $xAIF::Settings(partEdtr) SaveActiveDatabase
            $xAIF::Settings(partEdtr) Quit
            ##  Close the Expedition Database
            ##  Need to save?
            if { [$xAIF::Settings(pcbDoc) IsSaved] == "False" } {
                $xAIF::Settings(pcbDOc) Save
            }
            #$xAIF::Settings(pcbDoc) Save
            #$xAIF::Settings(pcbDoc) Close
            ##  Close Expedition
            #$xAIF::Settings(pcbApp) Quit

            if { [string is false $xAIF::Settings(connectMode)] } {
                ##  Close the Expedition Database and terminate Expedition
                $xAIF::Settings(pcbDoc) Close
                ##  Close Expedition
                $xAIF::Settings(pcbApp) Quit
            }
        } elseif { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
            GUI::Transcript -severity note -msg "Closing database for PDB Editor."
            set errorCode [catch { $xAIF::Settings(partEdtr) UnlockServer } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                return -code return 1
            }
            $xAIF::Settings(partEdtr) CloseActiveDatabase True
            GUI::Transcript -severity note -msg "Closing PDB Editor."
            $xAIF::Settings(partEdtr) Quit
        } else {
            GUI::Transcript -severity error -msg "Mode not set, build aborted."
            return -code return 1
        }
    }

    ##
    ##  MGC::SetupLMC
    ##
    proc SetupLMC { { f "" } } {
        GUI::StatusBar::UpdateStatus -busy on

        ##  Prompt the user for a Central Library database if not supplied

        if { [string equal $f ""] } {
            set $GUI::Dashboard::LibraryPath [tk_getOpenFile -filetypes {{LMC .lmc}}]
        } else {
            set $GUI::Dashboard::LibraryPath $f
        }

        ##  Set the Library Path to the target
        set xAIF::Settings(targetPath) $f

        if {$xAIF::Settings(targetPath) == "" } {
            GUI::Transcript -severity warning -msg "No Central Library selected."
            return
        } else {
            GUI::Transcript -severity note -msg [format "Central Library \"%s\" set as library target." $xAIF::Settings(targetPath)]
        }

        set xAIF::Settings(targetPath) $GUI::Dashboard::LibraryPath

        ##  Invoke the Cell Editor and open the LMC
        ##  Catch any exceptions raised by opening the database

        set errorCode [catch { MGC::OpenCellEditor } errorMessage]
        if {$errorCode != 0} {
            #set xAIF::Settings(targetPath) ""
            GUI::StatusBar::UpdateStatus -busy off
            return -code return 1
        }

        ##  Need to prompt for Cell partition

        #puts "cellEdtrDb:  ------>$xAIF::Settings(cellEdtrDb)<-----"
        ##  Can't list partitions when application is visible so if it is,
        ##  hide it temporarily while the list of partitions is queried.

        set visbility $xAIF::Settings(appVisible)

        $xAIF::Settings(cellEdtr) Visible False
        set partitions [$xAIF::Settings(cellEdtrDb) Partitions]
        $xAIF::Settings(cellEdtr) Visible $visbility

        GUI::Transcript -severity note -msg [format "Found %s cell %s." [$partitions Count] \
            [xAIF::Utility::Plural [$partitions Count] "partition"]]

        set xAIF::Settings(cellEdtrPrtnNames) {}
        for {set i 1} {$i <= [$partitions Count]} {incr i} {
            set partition [$partitions Item $i]
            lappend xAIF::Settings(cellEdtrPrtnNames) [$partition Name]
            GUI::Transcript -severity note -msg [format "Found cell partition \"%s.\"" [$partition Name]]
        }
    
        MGC::CloseCellEditor

        ##  Invoke the PDB Editor and open the database
        ##  Catch any exceptions raised by opening the database

        set errorCode [catch { MGC::OpenPDBEditor } errorMessage]
        if {$errorCode != 0} {
            #set xAIF::Settings(targetPath) ""
            GUI::StatusBar::UpdateStatus -busy off
            return -code return 1
        }

        ##  Need to prompt for PDB partition

        set partitions [$xAIF::Settings(partEdtrDb) Partitions]

        GUI::Transcript -severity note -msg [format "Found %s part %s." [$partitions Count] \
            [xAIF::Utility::Plural [$partitions Count] "partition"]]

        set xAIF::Settings(partEdtrPrtnNames) {}
        for {set i 1} {$i <= [$partitions Count]} {incr i} {
            set partition [$partitions Item $i]
            lappend xAIF::Settings(partEdtrPrtnNames) [$partition Name]
            GUI::Transcript -severity note -msg [format "Found part partition \"%s.\"" [$partition Name]]
        }

        MGC::ClosePDBEditor

        GUI::StatusBar::UpdateStatus -busy off
    }


    ##
    ##  Define the Generate namespace and procedure supporting operations
    ##
    namespace eval Generate {
        #
        #  MGC::Generate::Pad
        #
        #  Pads are interesting in that can't simply be updated.  To change a pad
        #  it must be deleted and then replaced.  A pad can't be deleted if it is
        #  referenced by a padstack so that scenario must be handled.
        #
        proc Pad { { mode "-replace" } } {
            GUI::StatusBar::UpdateStatus -busy on
            set xAIF::Settings(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined

            if { [string equal $xAIF::Settings(targetPath) ""] && [ string is true $xAIF::Settings(connectMode)] } {
                if {$GUI::Dashboard::Mode == $xAIF::Settings(designMode)} {
                    GUI::Transcript -severity error -msg "No Design (PCB) specified, build aborted."
                } elseif {$GUI::Dashboard::Mode == $xAIF::Settings(libraryMode)} {
                    GUI::Transcript -severity error -msg "No Central Library (LMC) specified, build aborted."
                } else {
                    GUI::Transcript -severity error -msg "Mode not set, build aborted."
                }

                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Rudimentary error checking - need a name, shape, height, and width!

            if { $::padGeom(name) == "" || $::padGeom(shape) == "" || \
                $::padGeom(height) == "" || $::padGeom(width) == "" } {
                GUI::Transcript -severity error -msg "Incomplete pad definition, build aborted."
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Map the shape to something we can pass through the API

            set shape [MapEnum::Shape $::padGeom(shape)]

            if { $shape == $xAIF::Settings(Nothing) } {
                GUI::Transcript -severity error -msg "Unsupported pad shape, build aborted."
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Define a pad name based on the shape, height and width
            #set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(height) $::padGeom(width)]
            set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(width) $::padGeom(height)]

            ##  Invoke the Padstack Editor and open the target
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenPadstackEditor } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            #  Does the pad exist?

            set oldPadName [$xAIF::Settings(pdstkEdtrDb) FindPad $padName]
            #puts "Old Pad Name:  ----->$oldPadName<>$padName<-------"

            #  Echo some information about what will happen.

            if {$oldPadName == $xAIF::Settings(Nothing)} {
                GUI::Transcript -severity note -msg [format "Pad \"%s\" does not exist." $padName]
            } elseif {$mode == "-replace" } {
                GUI::Transcript -severity warning -msg [format "Pad \"%s\" already exists and will be replaced." $padName]

                ##  Can't delete a pad that is referenced by a padstack so
                ##  need to catch the error if it is raised by the API.
                set errorCode [catch { $oldPadName Delete } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePadstackEditor
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
            } else {
                GUI::Transcript -severity warning -msg [format "Pad \"%s\" already exists and will not be replaced." $padName]
                MGC::ClosePadstackEditor
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Ready to build a new pad
            set newPad [$xAIF::Settings(pdstkEdtrDb) NewPad]

            $newPad -set Name $padName
            #puts "------>$padName<----------"
            $newPad -set Shape [expr $shape]
            $newPad -set Width \
                [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(width)]
            $newPad -set Height \
                [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(height)]
            $newPad -set OriginOffsetX \
                [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsetx)]
            $newPad -set OriginOffsetY \
                [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsety)]

            GUI::Transcript -severity note -msg [format "Committing pad:  %s" $padName]
            $newPad Commit

            MGC::ClosePadstackEditor

            ##  Report some time statistics
            set xAIF::Settings(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "Start Time:  %s" $xAIF::Settings(sTime)]
            GUI::Transcript -severity note -msg [format "Completion Time:  %s" $xAIF::Settings(cTime)]

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  MGC::Generate::Padstack
        #
        proc Padstack { { mode "-replace" } } {
            GUI::StatusBar::UpdateStatus -busy on
            set xAIF::Settings(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Extract pad details from AIF file

            ##  Make sure a Target library or design has been defined

            if {$xAIF::Settings(targetPath) == $xAIF::Settings(Nothing) && [string is false $xAIF::Settings(connectMode)] } {
                if {$GUI::Dashboard::Mode == $xAIF::Settings(designMode)} {
                    GUI::Transcript -severity error -msg "No Design (PCB) specified, build aborted."
                } elseif {$GUI::Dashboard::Mode == $xAIF::Settings(libraryMode)} {
                    GUI::Transcript -severity error -msg "No Central Library (LMC) specified, build aborted."
                } else {
                    GUI::Transcript -severity error -msg "Mode not set, build aborted."
                }

                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Rudimentary error checking - need a name, shape, height, and width!

            if { $::padGeom(name) == "" || $::padGeom(shape) == "" || \
                $::padGeom(height) == "" || $::padGeom(width) == "" } {
                GUI::Transcript -severity error -msg "Incomplete pad definition, build aborted."
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Define a pad name based on the shape, height and width
            #set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(height) $::padGeom(width)]
            set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(width) $::padGeom(height)]

            ##  Invoke the Padstack Editor and open the target
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenPadstackEditor } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            #  Look for the pad that the AIF references
            set pad [$xAIF::Settings(pdstkEdtrDb) FindPad $padName]

            if {$pad == $xAIF::Settings(Nothing)} {
                GUI::Transcript -severity error -msg [format "Pad \"%s\" is not defined, padstack \"%s\" build aborted." $padName $::padGeom(name)]
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            #  Does the pad exist?

            set oldPadstackName [$xAIF::Settings(pdstkEdtrDb) FindPadstack $::padGeom(name)]

            #  Echo some information about what will happen.

            if {$oldPadstackName == $xAIF::Settings(Nothing)} {
                GUI::Transcript -severity note -msg [format "Padstack \"%s\" does not exist." $padName]
            } elseif {$mode == "-replace" } {
                GUI::Transcript -severity warning -msg [format "Padstack \"%s\" already exists and will be replaced." $::padGeom(name)]
                ##  Can't delete a padstack that is referenced by a padstack
                ##  so need to catch the error if it is raised by the API.
                set errorCode [catch { $oldPadstackName Delete } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePadstackEditor
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
            } else {
                GUI::Transcript -severity warning -msg [format "Padstack \"%s\" already exists and will not be replaced." $::padGeom(name)]
                MGC::ClosePadstackEditor
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Ready to build the new padstack
            set newPadstack [$xAIF::Settings(pdstkEdtrDb) NewPadstack]

            $newPadstack -set Name $::padGeom(name)

            ##  Need to handle various pad types which are inferred while processing
            ##  the netlist.  If for some reason the pad doesn't appear in the netlist

            if { [lsearch [array names ::padtypes] $::padGeom(name)] == -1 } {
                set ::padtypes($::padGeom(name)) "smdpad"
            }

            switch -exact $::padtypes($::padGeom(name)) {
                "bondpad" {
                    $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypeBondPin)
                }
                "ballpad" {
                    $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypePinSMD)
                }
                "diepad" {
                    $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypePartStackPin)
                }
                "smdpad" -
                default {
                    $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypePinSMD)
                }
            }

            #$newPadstack -set PinClass $::MGCPCB::EPcbPinClassType(epcbPinClassDie)

            $newPadstack -set Pad \
                [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerTopMount)] $pad
            $newPadstack -set Pad \
                [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerBottomMount)] $pad

            $newPadstack Commit

            MGC::ClosePadstackEditor

            ##  Report some time statistics
            set xAIF::Settings(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "Start Time:  %s" $xAIF::Settings(sTime)]
            GUI::Transcript -severity note -msg [format "Completion Time:  %s" $xAIF::Settings(cTime)]

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  MGC::Generate::Cell
        #
        proc Cell { device args } {
puts "Y1"
            ##  Process command arguments
            array set V [list -partition $GUI::Dashboard::CellPartition -mirror none] ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {error "unknown option $a"}
                if {$value == {}} {error "value of \"$a\" missing"}
                if { [string compare $a -mirror] } {
                    set V($a) [string tolower $value]
                } else {
                    set V($a) $value
                }
            }
puts "Y2"

            set xAIF::Settings(cellEdtrPrtnName) $V(-partition)

            ##  Check mirror option, make sure it is valid
            if { [lsearch [list none x y xy] $V(-mirror)] == -1 } {
                GUI::Transcript -severity error -msg "Illegal seeting for -mirror switch, must be one of none, x, y, or xy."
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

puts "Y3"
            ##  Set the target cell name based on the mirror switch
            switch -exact $V(-mirror) {
                x {
                    set target [format "%s-mirror-x" $device]
                }
                y {
                    set target [format "%s-mirror-y" $device]
                }
                xy {
                    set target [format "%s-mirror-xy" $device]
                }
                none -
                default {
                    set target $device
                }
            }

            GUI::StatusBar::UpdateStatus -busy on
            set xAIF::Settings(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined
puts "Y4"

            if {$xAIF::Settings(targetPath) == $xAIF::Settings(Nothing) && [string is false $xAIF::Settings(connectMode)] } {
                if {$GUI::Dashboard::Mode == $xAIF::Settings(designMode)} {
                    GUI::Transcript -severity error -msg "No Design (PCB) specified, build aborted."
                } elseif {$GUI::Dashboard::Mode == $xAIF::Settings(libraryMode)} {
                    GUI::Transcript -severity error -msg "No Central Library (LMC) specified, build aborted."
                } else {
                    puts $GUI::Dashboard::Mode
                    GUI::Transcript -severity error -msg "Mode not set, build aborted."
                }

                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Invoke the Cell Editor and open the LMC or PCB
            ##  Catch any exceptions raised by opening the database

puts "Y5"
            set errorCode [catch { MGC::OpenCellEditor } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                MGC::CloseCellEditor
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Handling existing cells is much different for library
            ##  mode than it is for design mode.  In design mode there
            ##  isn't a "partition" so none of the partition logic applies.

puts "Y6"
            if { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {

                #  Prompt for the Partition if not supplied with -partition

                if { [string equal $V(-partition) ""] } {
                    set xAIF::Settings(cellEdtrPrtnName) \
                        [AIFForms::ListBox::SelectOneFromList "Select Target Cell Partition" $xAIF::Settings(cellEdtrPrtnNames)]

                    if { [string equal $xAIF::Settings(cellEdtrPrtnName) ""] } {
                        GUI::Transcript -severity error -msg "No Cell Partition selected, build aborted."
                        MGC::CloseCellEditor
                        GUI::StatusBar::UpdateStatus -busy off
                        return
                    } else {
                        set xAIF::Settings(cellEdtrPrtnName) [lindex $xAIF::Settings(cellEdtrPrtnName) 1]
                    }
                } else {
                    set xAIF::Settings(cellEdtrPrtnName) $V(-partition)
                }

                #  Does the cell exist?  Before we can check, we need a
                #  partition.  There isn't a clear name as to what the
                #  partition name should be so we'll use the name of the
                #  cell as the name of the partition as well.

                #  Cannot access partition list when application is
                #  visible so if it is, hide it temporarily.
                set visibility $xAIF::Settings(appVisible)

puts "Y7"
                $xAIF::Settings(cellEdtr) Visible False
                set partitions [$xAIF::Settings(cellEdtrDb) Partitions]
                $xAIF::Settings(cellEdtr) Visible $visibility

                GUI::Transcript -severity note -msg [format "Found %s cell %s." [$partitions Count] \
                    [xAIF::Utility::Plural [$partitions Count] "partition"]]

                set pNames {}
                for {set i 1} {$i <= [$partitions Count]} {incr i} {
                    set partition [$partitions Item $i]
                    lappend pNames [$partition Name]
                }

                #  Does the partition exist?

                if { [lsearch $pNames $xAIF::Settings(cellEdtrPrtnName)] == -1 } {
                    GUI::Transcript -severity note -msg [format "Creating partition \"%s\" for cell \"%s\"." \
                        $::die(partition) $target]

                    set partition [$xAIF::Settings(cellEdtrDb) NewPartition $xAIF::Settings(cellEdtrPrtnName)]
                } else {
                    GUI::Transcript -severity note -msg [format "Using existing partition \"%s\" for cell \"%s\"." \
                        $xAIF::Settings(cellEdtrPrtnName) $target]
                    set partition [$partitions Item [expr [lsearch $pNames $xAIF::Settings(cellEdtrPrtnName)] +1]]
                }

                #  Now that the partition work is doene, does the cell exist?

                set cells [$partition Cells]
            } else {
                if { [expr { $V(-partition) ne "" }] } {
                    GUI::Transcript -severity warning -msg "-partition switch is ignored in Design Mode."
                }
                set partition [$xAIF::Settings(cellEdtrDb) ActivePartition]
                set cells [$partition Cells]
            }

            GUI::Transcript -severity note -msg [format "Found %s %s." [$cells Count] \
                [xAIF::Utility::Plural [$cells Count] "cell"]]

            set cNames {}
            for {set i 1} {$i <= [$cells Count]} {incr i} {
                set cell [$cells Item $i]
                lappend cNames [$cell Name]
            }

            #  Does the cell exist?  Are we using Name suffixes?

            if { [string equal $GUI::Dashboard::CellSuffix numeric] } {
                set suffixes [lsearch -all -inline -regexp  $cNames $target-\[0-9\]+]
                if { [string equal $suffixes ""] } {
                    set suffix "-1"
                } else {
                    ##  Get the suffix with the highest number
                    set suffix [string trim [string trimleft \
                        [lindex [lsort -increasing -integer $suffixes] end] $target] -]
                    incr suffix
                }
                ##  Add the suffix to the target
                append target $suffix
            } elseif { [string equal $GUI::Dashboard::CellSuffix alpha] } {
                ##  This is limited to 26 matches for now ...
                set suffixes [lsearch -all -inline -regexp  $cNames $target-\[A-Z\]+]
                if { [string equal $suffixes ""] } {
                    set suffix "-A"
                } else {
                    ##  Get the suffix with the highest letter
                    set suffix [string trim [string trimleft \
                        [lindex [lsort -increasing -ascii $suffixes] end] $target] -]

                    ##  Make sure the end of the alphabet hasn't been reached
                    if { [string equal $suffix Z] } {
                        GUI::Transcript -severity note -msg [format "Cell suffixes (\"%s\") exhausted, aborted." $suffix]
                        MGC::CloseCellEditor
                        return
                    }

                    ##  Increment the suffix
                    set suffix [format "-%c" [expr [scan $suffix %c] +1]]
                }
                ##  Add the suffix to the target
                append target $suffix
            } elseif { [string equal $GUI::Dashboard::CellSuffix datestamp] } {
                set suffix [clock format [clock seconds] -format {-%Y-%m-%d}]
                append target $suffix
            } elseif { [string equal $GUI::Dashboard::CellSuffix timestamp] } {
                set suffix [clock format [clock seconds] -format {-%Y-%m-%d-%H-%M-%S}]
                append target $suffix
            } else {
            }

            ##  If cell already exists, try and delete it.
            ##  This can fail if the cell is being referenced by the design.

            if { [lsearch $cNames $target] == -1 } {
                GUI::Transcript -severity note -msg [format "Creating new cell \"%s\"." $target]
            } else {
                GUI::Transcript -severity note -msg [format "Replacing existing cell \"%s.\"" $target]
                set cell [$cells Item [expr [lsearch $cNames $target] +1]]

                ##  Delete the cell and save the database.  The delete
                ##  isn't committed until the database is actually saved.

                set errorCode [catch { $cell Delete } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::CloseCellEditor
                    return
                }

                $xAIF::Settings(cellEdtr) SaveActiveDatabase
            }

            ##  Build a new cell.  The first part of this is done in
            ##  in the Cell Editor which is part of the Library Manager.
            ##  The graphics and pins are then added using the Cell Editor
            ##  AddIn which sort of looks like a mini version of Expedititon.

            set devicePinCount [llength $::devices($device)]

            set newCell [$partition NewCell [expr $::CellEditorAddinLib::ECellDBCellType(ecelldbCellTypePackage)]]

            $newCell -set Name $target
            $newCell -set Description $target
            puts [expr $GUI::Dashboard::DefaultCellHeight]
            $newCell -set Height [expr $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)] [expr $GUI::Dashboard::DefaultCellHeight]

            #  Need to support Mount Side Opposite for APD compatibility
            #  For Mount Side Opposite use ecelldbMountTypeMixed?
            if { 0 } {
                $newCell -set MountType [expr $::CellEditorAddinLib::ECellDBMountType(ecelldbMountTypeMixed)]
            } else {
                $newCell -set MountType [expr $::CellEditorAddinLib::ECellDBMountType(ecelldbMountTypeSurface)]
            }

            #$newCell -set LayerCount [expr 2]
            $newCell -set PinCount [expr $devicePinCount]
            #puts [format "--->  devicePinCount:  %s" $devicePinCount]
            $newCell -set Units [expr [MapEnum::Units $::database(units) "cell"]]

            ##  Set the package group to Bare Die unless this is the BGA device
            if { [string equal $::bga(name) $device] } {
                $newCell -set PackageGroup [expr $::CellEditorAddinLib::ECellDBPackageGroup(ecelldbPackageBGA)]
            } else {
                $newCell -set PackageGroup  [expr $::CellEditorAddinLib::ECellDBPackageGroup(ecelldbPackageBareDie)]
            }

            ##  Commit the cell to the database so it can
            ##  be edited using the Cell Editor AddIn.

            $newCell Commit

            ##  Put the Cell in "Graphical Edit" mode
            ##  to add the pins and graphics.

            ##  Invoke the Padstack Editor and open the target
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenPadstackEditor -dontopendatabase } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Open the Cell Editor and turn off prompting

            set cellEditor [$newCell Edit]
            set cellEditorDoc [$cellEditor Application]
            [$cellEditorDoc Gui] SuppressTrivialDialogs True


            ##  Need the Component Document to it can be edited.
            ##  When using the Cell Editor Addin, the component will
            ##  always be the first Item.

            set components [$cellEditor Components]
            set component [$components Item 1]

            ##  Add the pins

            #  Doe the pads exist?

            set pads [Netlist::GetPads]

            foreach pad $pads {
                set padstack($pad) [$xAIF::Settings(pdstkEdtrDb) FindPadstack $pad]

                #  Echo some information about what will happen.

                if {$padstack($pad) == $xAIF::Settings(Nothing)} {
                    GUI::Transcript -severity error -msg \
                        [format "Reference Padstack \"%s\" does not exist, build aborted." $pad]
                    $cellEditor Close False

                    if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                        MGC::ClosePadstackEditor -dontclosedatabase
                    } else {
                        MGC::ClosePadstackEditor
                    }
                    MGC::CloseCellEditor

                    GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }
            }
puts "K1"

            ##  To fix Tcom bug?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                MGC::ClosePadstackEditor -dontclosedatabase
            } else {
                MGC::ClosePadstackEditor
            }

            ##  Need to "Put" the padstack so it can be
            ##  referenced by the Cell Editor Add Pin process.

            #foreach pad $pads {
            #    set padstack($pad) [$cellEditor PutPadstack [expr 1] [expr 1] $pad]
            #}

            set i 0
            unset padstack

            set pins [$cellEditor Pins]
#puts [format "-->  Array Size of pins:  %s" [$pins Count]]

            ##  Need to adjust X and Y locations based placement of Die on BGA
            set ctr "0,0"

            if { $xAIF::Settings(MCMAIF) == 1 } {
#puts "Q1"
                ##  Device might be the BGA ... need to account
                ##  for that possibility before trying to extract the
                ##  Center X and Center Y from a non-existant section

                foreach d [array names ::mcmdie] {
                    if { [string equal $::mcmdie($d) $device] } {
#puts "Q2"
                        set section [format "MCM_%s_%s" $::mcmdie($d) $d]
                        puts "-->  Section:  $section"
                    }
                }

                if { [lsearch [AIF::Sections] $section] != -1 } {
#puts "Q3"
                    set ctr [AIF::GetVar CENTER $section]
                }
            } 

            ##  Split the CENTER keyword into an X and Y, handle space or comma
            if { [string first , $ctr] != -1 } {
#puts "Q4"
                set diePadFields(centerx) [string trim [lindex [split $ctr ,] 0]]
                set diePadFields(centery) [string trim [lindex [split $ctr ,] 1]]
            } else {
#puts "Q5"
                set diePadFields(centerx) [string trim [lindex [split $ctr] 0]]
                set diePadFields(centery) [string trim [lindex [split $ctr] 1]]
            }

            ##  Start Transations for performance reasons
            $cellEditor TransactionStart [expr $::MGCPCB::EPcbDRCMode(epcbDRCModeDRC)]

            ##  Loop over the collection of pins
            ::tcom::foreach pin $pins {
                ##  Split of the fields extracted from the die file

                set padDefinition [lindex $::devices($device) $i]

                set diePadFields(padname) [lindex $padDefinition 0]
                set diePadFields(pinnum) [lindex $padDefinition 1]

                switch -exact $V(-mirror) {
                    x {
                        set diePadFields(padx) [expr - [lindex $padDefinition 2]]
                        set diePadFields(pady) [lindex $padDefinition 3]
                    }
                    y {
                        set diePadFields(padx) [lindex $padDefinition 2]
                        set diePadFields(pady) [expr - [lindex $padDefinition 3]]
                    }
                    xy {
                        set diePadFields(padx) [expr - [lindex $padDefinition 2]]
                        set diePadFields(pady) [expr - [lindex $padDefinition 3]]
                    }
                    none -
                    default {
                        set diePadFields(padx) [lindex $padDefinition 2]
                        set diePadFields(pady) [lindex $padDefinition 3]
                    }
                }


                #set diePadFields(net) [Netlist::GetNetName $i]

                #printArray diePadFields

                ## Need to handle sparse mode?

                set skip False

        if { 0 } {
                if { $xAIF::Settings(sparseMode) } {
                    if { [lsearch $xAIF::Settings(sparsepinnames) $diePadFields(pinnum)] == -1 } {
                        set skip True
                    }
                }
        }

                if { $skip  == False } {
                    GUI::Transcript -severity note -msg [format "Placing pin \"%s\" using padstack \"%s\"." \
                        $diePadFields(pinnum) $diePadFields(padname)]

                    ##  Need to "Put" the padstack so it can be
                    ##  referenced by the Cell Editor Add Pin process.

                    set padstack [$cellEditor PutPadstack [expr 1] [expr 1] $diePadFields(padname)]

                    $pin CurrentPadstack $padstack
                    $pin SetName $diePadFields(pinnum)

                    ##  Automation Defect:  dts0101097939
                    ##  Defect prevents the ability for Pin.Side to operate as documented.
                    ##  Fixed in VX.2
                    ##  Support for Mount Side Opposite
                    if { 0 } {
puts [$pin Side]
puts [expr $::MGCPCB::EPcbSide(epcbSideOpposite)]
                        $pin Side [expr $::MGCPCB::EPcbSide(epcbSideOpposite)]
puts [$pin Side]
                    }
#puts [format "X: %s, O: %s  / Y: %s, O: %s" $diePadFields(padx), $diePadFields(centerx) $diePadFields(pady), $diePadFields(centery)]

                    set errorCode [catch { $pin Place \
                        [expr $diePadFields(padx) - $diePadFields(centerx)] \
                        [expr $diePadFields(pady) - $diePadFields(centery)] [expr 0] } errorMessage]
                    if {$errorCode != 0} {
                        GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                        puts [format "Error:  %s  Pin:  %d  Handle:  %s" $errorMessage $i $pin]

                        puts [$pin IsValid]
                        puts [$pin Name]
                        puts [format "-->  Array Size of pins:  %s" [$pins Count]]
                        puts [$cellEditor Name]
                        break
                    }
                } else {
                    GUI::Transcript -severity note -msg [format "Skipping pin \"%s\" using padstack \"%s\", not in Sparse Pin list." \
                        $diePadFields(pinnum) $diePadFields(padname)]
                }

                ##  Support for Mount Side Opposite
                if { 0 } {
                    $pin Side [expr $::MGCPCB::EPcbSide(epcbSideOpposite)]
puts [expr $::MGCPCB::EPcbSide(epcbSideOpposite)]
                }
                set pin ::tcom::null

                incr i
            }

            ## Define the placement outline

            if { $xAIF::Settings(MCMAIF) == 1 } {
                ##  Device might be the BGA ... need to account
                ##  for that possibility before trying to extract
                ##  the height and width from a non-existant section

                foreach i [array names ::mcmdie] {
                    if { [string equal $::mcmdie($i) $device] } {
                        set section [format "MCM_%s_%s" $::mcmdie($i) $i]
                        puts "-->  Section:  $section"
                    }
                }

                if { [lsearch [AIF::Sections] $section] == -1 } {
                    set width [AIF::GetVar WIDTH BGA]
                    set height [AIF::GetVar HEIGHT BGA]
                } else {
                    set width [AIF::GetVar WIDTH $section]
                    set height [AIF::GetVar HEIGHT $section]
                }
            } elseif { $device == "BGA" } {
                set width [AIF::GetVar WIDTH BGA]
                set height [AIF::GetVar HEIGHT BGA]
            } else {
                set width [AIF::GetVar WIDTH DIE]
                set height [AIF::GetVar HEIGHT DIE]
            }

            set x2 [expr $width / 2]
            set x1 [expr -1 * $x2]
            set y2 [expr $height / 2]
            set y1 [expr -1 * $y2]

            ##  PutPlacementOutline expects a Points Array which isn't easily
            ##  passed via Tcl.  Use the Utility object to create a Points Array
            ##  Object Rectangle.  A rectangle will have 5 points in the points
            ##  array - 5 is passed as the number of points to PutPlacemetOutline.

            set ptsArrayNumPts 5
            set ptsArray [[$cellEditorDoc Utility] CreateRectXYR $x1 $y1 $x2 $y2]

            ##  If the device is the BGA, need to see if it has a polygon outline

#            if { $device == "BGA" } {
#                if {} {
#                }
#            }

            ##  Need some sort of a thickness value - there isn't one in the AIF file
            ##  We'll assume 1 micron for now, may offer user ability to define later.

            set th [[$cellEditorDoc Utility] ConvertUnit [expr 1.0] \
                [expr $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)] \
                [expr [MapEnum::Units $::database(units) "cell"]]]

            ##  Add the Placment Outline
            $cellEditor PutPlacementOutline [expr $::MGCPCB::EPcbSide(epcbSideMount)] [expr $ptsArrayNumPts] \
                $ptsArray [expr $th] [expr 0] $component [expr [MapEnum::Units $::database(units) "cell"]]
#puts "-------------->"
#puts $ptsArray
#puts "-------------->"

            ##  Terminate transactions
            $cellEditor TransactionEnd True

            ##  Save edits and close the Cell Editor
            set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "Saving new cell \"%s\" (%s)." $target $time]
            GUI::Transcript -severity note -msg "Starting Save!"
            $cellEditor Save
            GUI::Transcript -severity note -msg "Save Done!"
            set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "New cell \"%s\" (%s) saved." $target $time]
            $cellEditor Close False

        ##    if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
        ##        MGC::ClosePadstackEditor -dontclosedatabase
        ##    } else {
        ##        MGC::ClosePadstackEditor
        ##    }
            MGC::CloseCellEditor

            ##  Report some time statistics
            set xAIF::Settings(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "Start Time:  %s" $xAIF::Settings(sTime)]
            GUI::Transcript -severity note -msg [format "Completion Time:  %s" $xAIF::Settings(cTime)]

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  MGC::Generate::PDB
        #
        proc PDB { device args } {
            ##  Process command arguments
            array set V [list {-partition} $GUI::Dashboard::PartPartition] ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {error "unknown option $a"}
                if {$value == {}} {error "value of \"$a\" missing"}
                set V($a) $value
            }

            set xAIF::Settings(partEdtrPrtnName) $V(-partition)

            GUI::StatusBar::UpdateStatus -busy on
            set xAIF::Settings(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined

            if {$xAIF::Settings(targetPath) == $xAIF::Settings(Nothing) && [string is false $xAIF::Settings(connectMode)] } {
                if {$GUI::Dashboard::Mode == $xAIF::Settings(designMode)} {
                    GUI::Transcript -severity error -msg "No Design (PCB) specified, build aborted."
                } elseif {$GUI::Dashboard::Mode == $xAIF::Settings(libraryMode)} {
                    GUI::Transcript -severity error -msg "No Central Library (LMC) specified, build aborted."
                } else {
                    GUI::Transcript -severity error -msg "Mode not set, build aborted."
                }

                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Invoke the PDB Editor and open the database
            ##  Catch any exceptions raised by opening the database

            set errorCode [catch { MGC::OpenPDBEditor } errorMessage]
            if {$errorCode != 0} {
                GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                GUI::StatusBar::UpdateStatus -busy off
                return
            }

            ##  Handling existing parts is much different for library
            ##  mode than it is for design mode.  In design mode there
            ##  isn't a "partition" so none of the partition logic applies.

            if { $GUI::Dashboard::Mode == $xAIF::Settings(libraryMode) } {
                #  Does the part exist?  Before we can check, we need a
                #  partition.  There isn't a clear name as to what the
                #  partition name should be so we'll use the name of the
                #  part as the name of the partition as well.

                #  Prompt for the Partition if not supplied with -partition

                if { [string equal $V(-partition) ""] } {
                    set xAIF::Settings(partEdtrPrtnName) \
                        [AIFForms::ListBox::SelectOneFromList "Select Target Part Partition" $xAIF::Settings(partEdtrPrtnNames)]

                    if { [string equal $xAIF::Settings(partEdtrPrtnName) ""] } {
                        GUI::Transcript -severity error -msg "No Part Partition selected, build aborted."
                        MGC::CloseCellEditor
                        GUI::StatusBar::UpdateStatus -busy off
                        return
                    } else {
                        set xAIF::Settings(partEdtrPrtnName) [lindex $xAIF::Settings(partEdtrPrtnName) 1]
                    }
                } else {
                    set xAIF::Settings(partEdtrPrtnName) $V(-partition)
                }


                set partitions [$xAIF::Settings(partEdtrDb) Partitions]

                GUI::Transcript -severity note -msg [format "Found %s part %s." [$partitions Count] \
                    [xAIF::Utility::Plural [$partitions Count] "partition"]]

                set pNames {}
                for {set i 1} {$i <= [$partitions Count]} {incr i} {
                    set partition [$partitions Item $i]
                    lappend pNames [$partition Name]
                }

                #  Does the partition exist?

                if { [lsearch $pNames $xAIF::Settings(partEdtrPrtnName)] == -1 } {
                    GUI::Transcript -severity note -msg [format "Creating partition \"%s\" for part \"%s\"." \
                        $xAIF::Settings(partEdtrPrtnName) $device]

                    set partition [$xAIF::Settings(partEdtrDb) NewPartition $xAIF::Settings(partEdtrPrtnName)]
                } else {
                    GUI::Transcript -severity note -msg [format "Using existing partition \"%s\" for part \"%s\"." \
                        $xAIF::Settings(partEdtrPrtnName) $device]
                    set partition [$partitions Item [expr [lsearch $pNames $xAIF::Settings(partEdtrPrtnName)] +1]]
                }

                #  Now that the partition work is doene, does the part exist?

                set parts [$partition Parts]
            } else {
                if { [expr { $V(-partition) ne "" }] } {
                    GUI::Transcript -severity warning -msg "-partition switch is ignored in Design Mode."
                }
                set partition [$xAIF::Settings(partEdtrDb) ActivePartition]
                set parts [$partition Parts]
            }

            GUI::Transcript -severity note -msg [format "Found %s %s." [$parts Count] \
                [xAIF::Utility::Plural [$parts Count] "part"]]

            set cNames {}
            for {set i 1} {$i <= [$parts Count]} {incr i} {
                set part [$parts Item $i]
                lappend cNames [$part Name]
            }

            #  Does the part exist?

            if { [lsearch $cNames $device] == -1 } {
                GUI::Transcript -severity note -msg [format "Creating new part \"%s\"." $device]

            } else {
                GUI::Transcript -severity note -msg [format "Replacing existing part \"%s.\"" $device]
                set part [$parts Item [expr [lsearch $cNames $device] +1]]

                ##  Delete the part and save the database.  The delete
                ##  isn't committed until the database is actually saved.

                ##  First delete the Symbol Reference

                set errorCode [catch { $part Delete } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePDBEditor
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
            }

            $xAIF::Settings(partEdtr) SaveActiveDatabase

            ##  Generate a new part.  The first part of this is done in
            ##  in the PDB Editor which is part of the Library Manager.
            ##  The graphics and pins are then added using the PDB Editor
            ##  AddIn which sort of looks like a mini version of Expediiton.

            set newPart [$partition NewPart]

            $newPart -set Name $device
            $newPart -set Number $device
            $newPart -set Type [expr $::MGCPCBPartsEditor::EPDBPartType(epdbPartIC)]
            $newPart -set RefDesPrefix "U"
            $newPart -set Description "IC"

            #  Commit the Part so it can be mapped.
            $newPart Commit

            #  Start doing the pin mapping
            set mapping [$newPart PinMapping]

            #  Does the part have any symbol references?
            #  Need to remove existing reference before adding a symbol reference
            set symRef [$mapping PutSymbolReference $device]

            if { [[$mapping SymbolReferences] Count] > 0 } {
                GUI::Transcript -severity warning -msg \
                    [format "Mapping has %d preexisting Symbol Reference(s)." \
                        [[$mapping SymbolReferences] Count]]

                for { set i 1 } {$i <= [[$mapping SymbolReferences] Count] } {incr i} {
                    GUI::Transcript -severity note -msg \
                        [format "Removing prexisting symbol reference #%d" $i]
                    [$mapping SymbolReferences] Remove $i
                }
            }

            #  Need to add a cell reference
            set cellRef [$mapping PutCellReference $device \
                $::MGCPCBPartsEditor::EPDBCellReferenceType(epdbCellRefTop) $device]

            set devicePinCount [llength $::devices($device)]

            ##  Define the gate - what to do about swap code?
            set gate [$mapping PutGate "gate_1" $devicePinCount \
                $::MGCPCBPartsEditor::EPDBGateType(epdbGateTypeLogical)]

            ##  Add a pin defintition for each pin to the gate
            ##  The swap code for all of the pins is set to "1"
            ##  which ensures the pins are swappable within Expedition.

            set pi 1
            foreach p $::devices($device) {
                set sc [lindex $p 1]
                GUI::Transcript -severity note -msg [format "Adding Pin Definition %d \"%s\" %d \"Unknown\"" \
                    $pi $sc [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)]]
                $gate PutPinDefinition [expr $pi] "1" \
                    [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)] "Unknown"
                incr pi
            }

            ##  Report symbol reference count.  Not sure this is needed ...

            if { [[$mapping SymbolReferences] Count] != 0 } {
                GUI::Transcript -severity warning -msg \
                    [format "Symbol Reference \"%s\" is already defined." $device]

                #set i 1
                #set pinNames [$symRef PinNames]
                #puts "----------->$pinNames"
                #foreach pn $pinNames {
                    #puts "2-$i -->  Symbol Pin Name:  $pn"
                    #incr i
                #}
            }

            ##  Define the slot
            set slot [$mapping PutSlot $gate $symRef]

            ##  Add a pin defintition for each pin to the slot
            set pi 1
            foreach p $::devices($device) {
                ##  Get the pin name
                set sc [lindex $p 1]


                ## Need to handle sparse mode?
                if { $xAIF::Settings(sparseMode) } {
                    #if { $i in xAIF::Settings(sparsepinnumbers) $i } {
                    #    $slot PutPin [expr $i] [format "%s" $i]
                    #}
                } else {
                    GUI::Transcript -severity note -msg [format "Adding pin %d (\"%s\") to slot." $pi $sc]
                    $slot PutPin [expr $pi] [format "%s" $sc] [format "%s" $pi]
                }
                incr pi
            }

            ##  Commit mapping and close the PDB editor

            GUI::Transcript -severity note -msg [format "Saving PDB \"%s\"." $device]
            $mapping Commit
            GUI::Transcript -severity note -msg [format "New PDB \"%s\" saved." $device]
            MGC::ClosePDBEditor

            ##  Report some time statistics
            set xAIF::Settings(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            GUI::Transcript -severity note -msg [format "Start Time:  %s" $xAIF::Settings(sTime)]
            GUI::Transcript -severity note -msg [format "Completion Time:  %s" $xAIF::Settings(cTime)]
            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  MGC::Generate::Pads
        #
        #  This subroutine will create die pads based on the "PADS" section
        #  found in the AIF file.  It can optionally replace an existing pad
        #  based on the second argument.
        #

        proc Pads { } {
            foreach i [AIFForms::ListBox::SelectFromList "Select Pad(s)" [AIF::Pad::GetAllPads]] {
                set p [lindex $i 1]
                set ::padGeom(name) $p
                set ::padGeom(shape) [AIF::Pad::GetShape $p]
                set ::padGeom(width) [AIF::Pad::GetWidth $p]
                set ::padGeom(height) [AIF::Pad::GetHeight $p]
                set ::padGeom(offsetx) 0.0
                set ::padGeom(offsety) 0.0

                MGC::Generate::Pad
            }
        }

        #
        #  MGC::GenerateMGC::Padstacks
        #
        #  This subroutine will create die pads based on the "PADS" section
        #  found in the AIF file.  It can optionally replace an existing pad
        #  based on the second argument.
        #

        proc Padstacks { } {
            foreach i [AIFForms::ListBox::SelectFromList "Select Pad(s)" [AIF::Pad::GetAllPads]] {
                set p [lindex $i 1]
                set ::padGeom(name) $p
                set ::padGeom(shape) [AIF::Pad::GetShape $p]
                set ::padGeom(width) [AIF::Pad::GetWidth $p]
                set ::padGeom(height) [AIF::Pad::GetHeight $p]
                set ::padGeom(offsetx) 0.0
                set ::padGeom(offsety) 0.0

                MGC::Generate::Padstack
            }
        }

        #
        #  MGC::Generate::Cells
        #
        #  This subroutine will create die pads based on the "PADS" section
        #  found in the AIF file.  It can optionally replace an existing pad
        #  based on the second argument.
        #

        proc Cells { } {
            foreach i [AIFForms::ListBox::SelectFromList "Select Cell(s)" [array names ::devices]] {
                foreach j [array names GUI::Dashboard::CellGeneration] {
                    if { [string is true $GUI::Dashboard::CellGeneration($j)] } {
                        MGC::Generate::Cell [lindex $i 1] -mirror [string tolower [string trimleft $j Mirror]]
                    }
                }
            }
        }

        #
        #  MGC::Generate::PDBs
        #
        #  This subroutine will create die pads based on the "PADS" section
        #  found in the AIF file.  It can optionally replace an existing pad
        #  based on the second argument.
        #

        proc PDBs { } {
            foreach i [AIFForms::ListBox::SelectFromList "Select PDB(s)" [array names ::devices]] {
                MGC::Generate::PDB [lindex $i 1]
            }
        }

        #
        #  MGC::Generate::DesignStub
        #
        #  This procedure will create (if they don't exist) several folders under
        #  the specified folder that are used when building up a design.  These
        #  folders hold things like the netlist, placement, and wire bond information.
        #
        proc DesignStub { { d "" } } {
            GUI::StatusBar::UpdateStatus -busy on

            ##  Prompt the user for a Diectory if not supplied

            if { [string equal $d ""] } {
                set rootstub [tk_chooseDirectory]
            } else {
                set rootstub $d
            }

            if { [string equal stub ""] } {
                GUI::Transcript -severity warning -msg "No target directory selected."
                return
            } else {
                GUI::Transcript -severity note -msg [format "Design Stub \"%s\" will be populated." $rootstub]
            }

            ##  Try and create the Logic directory (netlist lives here ...)
            set stubs { Config Layout Logic }

            foreach stub $stubs {
                if { ! [ file isdirectory $rootstub/$stub ] } {
                    file mkdir $rootstub/$stub
                    if { [ file isdirectory $rootstub/$stub ] } {
                        GUI::Transcript -severity note -msg [format "Design Stub \"%s\" was created." $rootstub/$stub]
                    } else {
                        GUI::Transcript -severity warning -msg [format "Design Stub \"%s\" was not created." $rootstub/$stub]
                    }
                } else {
                        GUI::Transcript -severity note -msg [format "Design Stub \"%s\" alreasy exists." $rootstub/$stub]
                }
            }
        }
    }

    ##
    ##  Define the Generate namespace and procedure supporting operations
    ##
    namespace eval Design {
        #
        #  MGC::Design::SetPackageOutline
        #
        proc DrawOutline { args } {
            ##  Process command arguments
            array set V { {-mode} packageoutline } ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {
                    error "unknown option $a"
                } elseif {$value == {}} {
                    error "value of \"$a\" missing"
                } else {
                    set V($a) $value
                }
            }

            ##  Make sure what we received makes sense

            if { [lsearch [list packageoutline routeborder manufacturingoutline testfixtureoutline] $V(-mode)] == -1 } {
                error "value of \"$a\" must be one of packageoutline, routeborder, manufacturingoutline, or testfixtureoutline"
            }

            ##  Which mode?  Design or Library?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                ##  Invoke Expedition on the design so the Units can be set
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }

                set width [AIF::GetVar WIDTH BGA]
                set height [AIF::GetVar HEIGHT BGA]

                set x2 [expr $width / 2]
                set x1 [expr -1 * $x2]
                set y2 [expr $height / 2]
                set y1 [expr -1 * $y2]

                ##  PutBoardOutline expects a Points Array which isn't easily
                ##  passed via Tcl.  Use the Utility object to create a Points Array
                ##  Object Rectangle.  A rectangle will have 5 points in the points
                ##  array - 5 is passed as the number of points to PutPlacemetOutline.

                set ptsArrayNumPts 5
                set ptsArray [[$xAIF::Settings(pcbApp) Utility] CreateRectXYR $x1 $y1 $x2 $y2]

                ##  Need some sort of a thickness value - there isn't one in the AIF file
                ##  We'll assume 1 micron for now, may offer user ability to define later.

                set th [[$xAIF::Settings(pcbApp) Utility] ConvertUnit [expr 1.0] \
                    [expr $::MGCPCB::EPcbUnit(epcbUnitUM)] \
                    [expr [MapEnum::Units $::database(units) "pcb"]]]

                switch -exact $V(-mode) {
                    routeborder {
                        ##  Add the Route Border
                        $xAIF::Settings(pcbDoc) PutRouteBorder [expr $ptsArrayNumPts] \
                            $ptsArray [expr $th] [expr [MapEnum::Units $::database(units) "pcb"]]
                    }
                    manufacturingoutline {
                        ##  Add the Manufacturing Outline
                        $xAIF::Settings(pcbDoc) PutManufacturingOutline [expr $ptsArrayNumPts] \
                            $ptsArray [expr [MapEnum::Units $::database(units) "pcb"]]
                    }
                    testfixtureoutline {
                        ##  Add the Testfixture Outline
                        $xAIF::Settings(pcbDoc) PutTestFixtureOutline [expr $ptsArrayNumPts] \
                            $ptsArray [expr [MapEnum::Units $::database(units) "pcb"]]
                    }
                    packageoutline -
                    default {
                        ##  Add the Board Outline
                        $xAIF::Settings(pcbDoc) PutBoardOutline [expr $ptsArrayNumPts] \
                            $ptsArray [expr $th] [expr [MapEnum::Units $::database(units) "pcb"]]
                    }
                }

            } else {
                GUI::Transcript -severity error -msg "Setting Package Outline is only available in design mode."
            }

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  MGC::Design::SetPackageOutline
        #
        proc SetPackageOutline {} {
            GUI::Transcript -severity note -msg "Setting Package Outline."
            DrawOutline -mode packageoutline
        }

        #
        #  MGC::Design::SetRouteBorder
        #
        proc SetRouteBorder {} {
            GUI::Transcript -severity note -msg "Setting Route Border."
            DrawOutline -mode routeborder
        }
        #
        #  MGC::Design::SetManufacturingOutline
        #
        proc SetManufacturingOutline {} {
            GUI::Transcript -severity note -msg "Setting Manufacturing Outline."
            DrawOutline -mode manufacturingoutline
        }
        #
        #  MGC::Design::SetTestFixtureOutline
        #
        proc SetTestFixtureOutline {} {
            GUI::Transcript -severity note -msg "Setting Test Fixture Outline."
            DrawOutline -mode testfixtureoutline
        }

        #
        #  MGC::Design::CheckDatabaseUnits
        #
        proc CheckDatabaseUnits {} {
            ##  Which mode?  Design or Library?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                ##  Invoke Expedition on the design so the Units can be set
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }

                ##  Check design database units to see if they match AIF database units

                set dbu [[$xAIF::Settings(pcbDoc) SetupParameter] Unit]
                if { $dbu == [expr [MapEnum::Units $::database(units) "pcb"]] } {
                    GUI::Transcript -severity note -msg [format "Design database units (%s) match AIF file units (%s)." [MapEnum::ToUnits $dbu ] $::database(units)]
                } else {
                    #GUI::Transcript -severity warning -msg [format "Design database units (%s) do not match AIF file units (%s)." [MapEnum::ToUnits $dbu ] $::database(units)]
                    #GUI::Transcript -severity note -msg "Resolve this problem within XpeditionPCB using the  \"Setup > Setup Parameters...\" menu."
                    GUI::Transcript -severity warning -msg [format "Design database units (%s) do not match AIF file units (%s).  Resolve in Xpedition using \"Setup Parameters...\" menu." [MapEnum::ToUnits $dbu ] $::database(units)]
                }

                ##  Assign the PCB database units to the units found in the AIF file
##                set errorCode [catch { $xAIF::Settings(pcbDoc) CurrentUnit [expr [MapEnum::Units $::database(units) "pcb"]] } errorMessage]
##                if {$errorCode != 0} {
##                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
##                } else {
##                    GUI::Transcript -severity note -msg [format "Setting Database Units to %s." $::database(units)]
##                }
            } else {
                GUI::Transcript -severity error -msg "Checking database units is only available in design mode."
            }

            GUI::StatusBar::UpdateStatus -busy off
        }
    }


    ##
    ##  Define the Bond Wire namespace and procedures supporting bond wire and pad operations
    ##
    ##  These parameters, provided by Frank Bader, are fairly generic and general purpose.
    ##
    namespace eval WireBond {

        variable WBParameters
        variable WBDRCProperty
        variable WBRule
        variable Units um
        variable Angle deg

        array set WBParameters {
            Model DefaultWireModel
            Padstack ""
            XStart 0
            YStart 0
            XEnd 0
            YEnd 0
        }

        array set WBDRCProperty {
            WB2WB 0
            WB2Part 4
            WB2Metal 0
            WB2DieEdge 4
            WB2DieSurface 0
            WB2Cavity 0
            WBAngle 360
            BondSiteMargin 0
            WBMin 100
            WBMax 3000
        }

        array set WBRule {
            Name DefaultWireModel
            BWW 25
            Template {[Name=[DefaultWireModel]][IsMod=[No]][Cs=[[[X=[0]][Y=[0]][Z=[(BWH)]][R=[0]][CT=[Ball]]][[X=[0]][Y=[0]][Z=[(BWH)*1.5]][R=[100um]][CT=[Round]]][[X=[(BWD)/3*2]][Y=[0]][Z=[(BWH)*1.5]][R=[200um]][CT=[Round]]][[X=[(BWD)]][Y=[0]][Z=[(IH)]][R=[0]][CT=[Wedge]]]]][Vs=[[BD=[BWW+15um]][BH=[15um]][BWD=[3000um]][BWH=[300um]][BWW=[%s%s]][IH=[30um]][WL=[30um]]]]}
            Value ""
        }

        set WBRule(Value) [format $WBRule(Template) $WBRule(BWW) $Units]

        ##
        ##  MGC::WireBond::UpdateParameters
        ##
        proc UpdateParameters {} {
            variable Units
            variable WBParameters
            set GUI::Dashboard::WBParameters [format \
                {[Model=[%s]][Padstack=[%s]][XStart=[%s%s]][YStart=[%s%s]][XEnd=[%s%s]][YEnd=[%s%s]]} \
                $WBParameters(Model) $WBParameters(Padstack) \
                $WBParameters(XStart) $Units $WBParameters(YStart) $Units \
                $WBParameters(XEnd) $Units $WBParameters(YEnd) $Units]
        }

        ##
        ##  MGC::WireBond::UpdateDRCProperty
        ##
        proc UpdateDRCProperty {} {
            variable Angle
            variable Units
            variable WBDRCProperty
            set GUI::Dashboard::WBDRCProperty [format \
                {[WB2WB=[%s%s]][WB2Part=[%s%s]][WB2Metal=[%s%s]][WB2DieEdge=[%s%s]][WB2DieSurface=[%s%s]][WB2Cavity=[%s%s]][WBAngle=[%s%s]][BondSiteMargin=[%s%s]][Rows=[[[WBMin=[%s%s]][WBMax=[%s%s]]]]]} \
                    $WBDRCProperty(WB2WB) $Units $WBDRCProperty(WB2Part) $Units $WBDRCProperty(WB2Metal) $Units \
                    $WBDRCProperty(WB2DieEdge) $Units $WBDRCProperty(WB2DieSurface) $Units $WBDRCProperty(WB2Cavity) $Units \
                    $WBDRCProperty(WBAngle) $Angle $WBDRCProperty(BondSiteMargin) $Units $WBDRCProperty(WBMin) $Units \
                    $WBDRCProperty(WBMax) $Units]
        }

        ##
        ##  MGC::WireBond::SelectBondPad
        ##
        proc SelectBondPad {} {
            set bondpads [list]

            foreach i [array names ::padtypes] {
                set type $::padtypes($i)

                if { [string equal bondpad $type] } {
                    lappend bondpads $i
                }
            }

            set MGC::WireBond::WBParameters(Padstack) \
                [AIFForms::ListBox::SelectOneFromList "Select Bond Pad" $bondpads]
            if { [string equal $MGC::WireBond::WBParameters(Padstack) ""] } {
                GUI::Transcript -severity error -msg "No bond pad selected."
                return
            } else {
                set MGC::WireBond::WBParameters(Padstack) [lindex $MGC::WireBond::WBParameters(Padstack) 1]
            }
        }

        ##
        ##  MGC::WireBond::Setup
        ##
        proc Setup {} {
            variable WBParameters
            xAIF::Utility::PrintArray WBParameters
            puts "MGC::WireBond::Setup"
            $GUI::widgets(notebook) select $GUI::widgets(wirebondparams)
        }

        ##
        ##  MGC::WireBond::ApplyProperies
        ##
        proc ApplyProperies {} {
            puts "MGC::WireBond::ApplyProperies"
            ##  Which mode?  Design or Library?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                ##  Invoke Expedition on the design so the Cell Editor can be started
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
                set xAIF::Settings(cellEdtr) [$xAIF::Settings(pcbDoc) CellEditor]
            } else {
                GUI::Transcript -severity error -msg "Bond Pad placement is only available in design mode."
                return
            }

            ##  Check the property values and make sure they are set.
            if { [string equal $GUI::Dashboard::WBParameters ""] } {
                GUI::Transcript -severity error -msg "Wire Bond Parameters property has not been set."
                return
            }

            if { [string equal $GUI::Dashboard::WBDRCProperty ""] } {
                GUI::Transcript -severity error -msg "Wire Bond DRC property has not been set."
                return
            }

            ##  Apply the properties to the PCB Doc
            $xAIF::Settings(pcbDoc) PutProperty "WBParameters" $GUI::Dashboard::WBParameters
            GUI::Transcript -severity note -msg "Wire Bond property \"WBParameters\" applied to design."
            $xAIF::Settings(pcbDoc) PutProperty "WBDRCProperty" $GUI::Dashboard::WBDRCProperty
            GUI::Transcript -severity note -msg "Wire Bond property \"WBDRCProperty\" applied to design."

            ##  Apply default wire model to all components
            set comps [$xAIF::Settings(pcbDoc) Components]
            ::tcom::foreach comp $comps {
                $comp PutProperty "WBParameters" {[Model=[DefaultWireModel]][PADS=[]]}
                GUI::Transcript -severity note -msg [format "Wire Bond property \"WBParameters\" applied to component \"%s\"." [$comp RefDes]]
            }
        }

        ##
        ##  MGC::WireBond::PlaceBondPads
        ##
        proc PlaceBondPads {} {
            puts "MGC::WireBond::PlaceBondPads"

            ##  Which mode?  Design or Library?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                ##  Invoke Expedition on the design so the Cell Editor can be started
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
            } else {
                GUI::Transcript -severity error -msg "Bond Pad placement is only available in design mode."
                return
            }

            ##  Start a transaction with DRC to get Bond Pads placed ...
            $xAIF::Settings(pcbDoc) TransactionStart [expr $::MGCPCB::EPcbDRCMode(epcbDRCModeNone)]
            
            foreach i $::bondpads {

                set bondpad(NETNAME) [lindex $i 0]
                set bondpad(FINNAME) [lindex $i 1]
                set bondpad(FIN_X) [lindex $i 2]
                set bondpad(FIN_Y) [lindex $i 3]
                set bondpad(ANGLE) [lindex $i 4]

                ##  Need to find the padstack ...
                ##  Make sure the Bond Pad exists and is defined as a Bond Pad
                set padstacks [$xAIF::Settings(pcbDoc) PadstackNames \
                    [expr $::MGCPCB::EPcbPadstackObjectType(epcbPadstackObjectBondPad)]]

                if { [lsearch $padstacks $bondpad(FINNAME)] == -1} {
                    GUI::Transcript -severity error -msg [format \
                        "Bond Pad \"%s\" does not appear in the design or is not defined as a Bond Pad." \
                        $bondpad(FINNAME)]
                    $xAIF::Settings(pcbDoc) TransactionEnd True
                    return
                } else {
                    GUI::Transcript -severity note -msg [format \
                    "Bond Pad \"%s\" found in design, will be placed." $bondpad(FINNAME)]
                }

                ##  Activate the Bond Pad padstack
                set padstack [$xAIF::Settings(pcbDoc) \
                    PutPadstack [expr 1] [expr 1] $bondpad(FINNAME)]

                set net [$xAIF::Settings(pcbDoc) FindNet $bondpad(NETNAME)]

                if { [string equal $net ""] } {
                    GUI::Transcript -severity warning -msg [format "Net \"%s\" was not found, may be a No Connect, using \"(Net0)\" as net." $bondpad(NETNAME)]
                    set net [$xAIF::Settings(pcbDoc) FindNet "(Net0)"]
                } else {
                    GUI::Transcript -severity note -msg [format "Net \"%s\" was found." $bondpad(NETNAME)]
                }

                ##  Place the Bond Pad
                GUI::Transcript -severity note -msg \
                    [format "Placing Bond Pad \"%s\" for Net \"%s\" (X: %s  Y: %s  R: %s)." \
                    $bondpad(FINNAME) $bondpad(NETNAME) $bondpad(FIN_X) $bondpad(FIN_Y) $bondpad(ANGLE)]
                set bpo [$xAIF::Settings(pcbDoc) PutBondPad \
                    [expr $bondpad(FIN_X)] [expr $bondpad(FIN_Y)] $padstack $net]
                $bpo -set Orientation \
                    [expr $::MGCPCB::EPcbAngleUnit(epcbAngleUnitDegrees)] [expr $bondpad(ANGLE)]

                puts [format "---------->  %s" [$bpo Name]]
                puts [format "Orientation:  %s" [$bpo -get Orientation]]
            }
            $xAIF::Settings(pcbDoc) TransactionEnd True
        }

        ##
        ##  MGC::BondWire::PlaceBondWires
        ##
        proc PlaceBondWires {} {
            puts "MGC::WireBond::PlaceBondWires"

            ##  Which mode?  Design or Library?
            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                ##  Invoke Expedition on the design so the Cell Editor can be started
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                    return
                }
            } else {
                GUI::Transcript -severity error -msg "Bond Pad placement is only available in design mode."
                return
            }

            GUI::StatusBar::UpdateStatus -busy on

            ##  Start a transaction with DRC to get Bond Pads placed ...
            $xAIF::Settings(pcbDoc) TransactionStart [expr $::MGCPCB::EPcbDRCMode(epcbDRCModeNone)]

            ##  Place each bond wire based on From XY and To XY
            foreach i $::bondwires {
                set bondwire(NETNAME) [lindex $i 0]
                set bondwire(FROM_X) [lindex $i 1]
                set bondwire(FROM_Y) [lindex $i 2]
                set bondwire(TO_X) [lindex $i 3]
                set bondwire(TO_Y) [lindex $i 4]

                ##  Try and "pick" the "FROM" Die Pin at the XY location.
                $xAIF::Settings(pcbDoc) UnSelectAll
                #puts "Picking FROM at X:  $bondwire(FROM_X)  Y:  $bondwire(FROM_Y)"
                set objs [$xAIF::Settings(pcbDoc) Pick \
                    [expr double($bondwire(FROM_X))] [expr double($bondwire(FROM_Y))] \
                    [expr double($bondwire(FROM_X))] [expr double($bondwire(FROM_Y))] \
                    [expr $::MGCPCB::EPcbObjectClassType(epcbObjectClassPadstackObject)] \
                    [$xAIF::Settings(pcbDoc) LayerStack]]

                ##  Making sure exactly "one" object was picked isn't possible - too many
                ##  things can be stacked on top of one another on different layers.  Need
                ##  to iterate through the selected objects and identify the Die Pin we're
                ##  actually looking for.

                set dpFound False

                if { [$objs Count] > 0 } {
                    ::tcom::foreach obj $objs {
                        set diepin [$obj CurrentPadstack]
                        if { [$diepin PinClass] == [expr $::MGCPCB::EPcbPinClassType(epcbPinClassDie)] } {
                            set dpFound True
                            set DiePin [[$diepin Pins] Item 1]
                            break
                        }
                    }
                }

                if { [string is false $dpFound] } {
                    GUI::Transcript -severity error -msg \
                        [format "Unable to pick die pad at bond wire origin (X: %f  Y: %f), bond wire skipped (Net: %s  From (%f, %f) To (%f, %f)." \
                        $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(NETNAME) \
                        $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(TO_X) $bondwire(TO_Y)]
$xAIF::Settings(pcbDoc) TransactionEnd True
break
                        continue
                } else {
                    GUI::Transcript -severity note -msg \
                        [format "Found Die Pin at bond wire origin (X: %f  Y: %f) for net \"%s\"." \
                            $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(NETNAME)]
                }

                ##  Validated it is correct type, now need just the object selected
                ## Need to select the Pin Object as PutBondWire requires a Pin Object
                #$DiePin Selected True

                ##  Try and "pick" the "TO" Bond Pad at the XY location.

                $xAIF::Settings(pcbDoc) UnSelectAll

                #puts "Picking TO at X:  $bondwire(TO_X)  Y:  $bondwire(TO_Y)"
                set objs [$xAIF::Settings(pcbDoc) Pick \
                    [expr double($bondwire(TO_X))] [expr double($bondwire(TO_Y))] \
                    [expr double($bondwire(TO_X))] [expr double($bondwire(TO_Y))] \
                    [expr $::MGCPCB::EPcbObjectClassType(epcbObjectClassPadstackObject)] \
                    [$xAIF::Settings(pcbDoc) LayerStack]]

                ##  Making sure exactly "one" object was picked isn't possible - too many
                ##  things can be stacked on top of one another on different layers.  Need
                ##  to iterate through the selected objects and identify the Bond Pad we're
                ##  actually looking for.

                set bpFound False

                if { [$objs Count] > 0 } {
                    ::tcom::foreach obj $objs {
                        set bondpad [$obj CurrentPadstack]
                        if {([$bondpad PinClass] == [expr $::MGCPCB::EPcbPinClassType(epcbPinClassSMD)]) && \
                            ([$bondpad Type] == [expr $::MGCPCB::EPcbPadstackObjectType(epcbPadstackObjectBondPad)])} {
                            set bpFound True
                            set BondPad $obj
                            break
                        }
                    }
                }

                if { [string is false $bpFound] } {
                    GUI::Transcript -severity error -msg \
                        [format "Unable to pick bond pad at bond wire termination (X: %f  Y: %f), bond wire skipped (Net: %s  From (%f, %f) To (%f, %f)." \
                        $bondwire(TO_X) $bondwire(TO_Y) $bondwire(NETNAME) \
                        $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(TO_X) $bondwire(TO_Y)]
                        continue
                } else {
                    GUI::Transcript -severity note -msg \
                        [format "Found Bond Pad at bond wire termination (X: %f  Y: %f) for net \"%s\"." \
                            $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(NETNAME)]
                }

                ##  Validated it is correct type, now need just the object selected
                $BondPad Selected True

                ##  A die pin and bond pad pair have been identified, time to drop a bond wire
                set dpX [$DiePin PositionX]
                set dpY [$DiePin PositionY]
                set bpX [$BondPad PositionX]
                set bpY [$BondPad PositionY]

                set bw [$xAIF::Settings(pcbDoc) PutBondWire $DiePin $dpX $dpY $BondPad $bpX $bpY]
                GUI::Transcript -severity note -msg [format "Bond Wire successfully placed for net \"%s\" from (%f,%f) to (%f,%f)." \
                    $bondwire(NETNAME) $bondwire(FROM_X) $bondwire(FROM_Y) $bondwire(TO_X) $bondwire(TO_Y)]

                ##  Assign the BondWire model to ensure propert behavior
                
                GUI::Transcript -severity note -msg [format "Bond Wire Model \"%s\" assigned to net \"%s\"." \
                    $MGC::WireBond::WBParameters(Model) [[$bw Net] Name]]
                $bw -set WireModelName $MGC::WireBond::WBParameters(Model)
            }

            $xAIF::Settings(pcbDoc) TransactionEnd True
            GUI::StatusBar::UpdateStatus -busy off
        }

        ##
        ##  MGC::WireBond::ExportWireModel
        ##
        proc ExportWireModel { { wb "" } } {
            variable Units
            variable WBRule

            if { $wb == "" } {
                set wb [tk_getSaveFile -filetypes {{WB .wb} {All *}} \
                    -initialfile [format "%s.wb" $WBRule(Name)] -defaultextension ".wb"]
            }

            if { $wb == "" } {
                GUI::Transcript -severity warning -msg "No Placement file specified, Export aborted."
                return
            }
        
            #  Write the wire model to the file

            set f [open $wb "w+"]
            puts $f $WBRule(Value)
            close $f

            GUI::Transcript -severity note -msg [format "Wire Model successfully exported to file \"%s\"." $wb]

            return
        }
    }
}

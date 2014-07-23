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

        set ::ediu(targetPath) [$::ediu(pcbDoc) Path][$::ediu(pcbDoc) Name]
        #puts [$::ediu(pcbDoc) Path][$::ediu(pcbDoc) Name]
        Transcript $::ediu(MsgNote) [format "Connected to design database:  %s%s" \
            [$::ediu(pcbDoc) Path] [$::ediu(pcbDoc) Name]]
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
                    Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
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
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
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
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
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
            ediuUpdateStatus $::ediu(busy)
            set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined

            if {$::ediu(targetPath) == $::ediu(Nothing) && $::ediu(connectMode) != True } {
                if {$::ediu(mode) == $::ediu(designMode)} {
                    Transcript $::ediu(MsgError) "No Design (PCB) specified, build aborted."
                } elseif {$::ediu(mode) == $::ediu(libraryMode)} {
                    Transcript $::ediu(MsgError) "No Central Library (LMC) specified, build aborted."
                } else {
                    Transcript $::ediu(MsgError) "Mode not set, build aborted."
                }

                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Rudimentary error checking - need a name, shape, height, and width!

            if { $::padGeom(name) == "" || $::padGeom(shape) == "" || \
                $::padGeom(height) == "" || $::padGeom(width) == "" } {
                Transcript $::ediu(MsgError) "Incomplete pad definition, build aborted."
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Map the shape to something we can pass through the API

            set shape [MapEnum::Shape $::padGeom(shape)]

            if { $shape == $::ediu(Nothing) } {
                Transcript $::ediu(MsgError) "Unsupported pad shape, build aborted."
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Define a pad name based on the shape, height and width
            set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(height) $::padGeom(width)]

            ##  Invoke the Padstack Editor and open the target
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenPadstackEditor } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                ediuUpdateStatus $::ediu(ready)
                return
            }

            #  Does the pad exist?

            set oldPadName [$::ediu(pdstkEdtrDb) FindPad $padName]
            #puts "Old Pad Name:  ----->$oldPadName<>$padName<-------"

            #  Echo some information about what will happen.

            if {$oldPadName == $::ediu(Nothing)} {
                Transcript $::ediu(MsgNote) [format "Pad \"%s\" does not exist." $padName]
            } elseif {$mode == "-replace" } {
                Transcript $::ediu(MsgWarning) [format "Pad \"%s\" already exists and will be replaced." $padName]

                ##  Can't delete a pad that is referenced by a padstack so
                ##  need to catch the error if it is raised by the API.
                set errorCode [catch { $oldPadName Delete } errorMessage]
                if {$errorCode != 0} {
                    Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePadstackEditor
                    ediuUpdateStatus $::ediu(ready)
                    return
                }
            } else {
                Transcript $::ediu(MsgWarning) [format "Pad \"%s\" already exists and will not be replaced." $padName]
                MGC::ClosePadstackEditor
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Ready to build a new pad
            set newPad [$::ediu(pdstkEdtrDb) NewPad]

            $newPad -set Name $padName
            #puts "------>$padName<----------"
            $newPad -set Shape [expr $shape]
            $newPad -set Width \
                [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(width)]
            $newPad -set Heigh\
                t [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(height)]
            $newPad -set OriginOffset\
                X [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsetx)]
            $newPad -set OriginOffset\
                Y [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsety)]

            Transcript $::ediu(MsgNote) [format "Committing pad:  %s" $padName]
            $newPad Commit

            MGC::ClosePadstackEditor

            ##  Report some time statistics
            set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
            Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

            ediuUpdateStatus $::ediu(ready)
        }

        #
        #  MGC::Generate::Padstack
        #
        proc Padstack { { mode "-replace" } } {
            ediuUpdateStatus $::ediu(busy)
            set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Extract pad details from AIF file
            #ediuPadGeomName
            #ediuPadGeomShape

            ##  Make sure a Target library or design has been defined

            if {$::ediu(targetPath) == $::ediu(Nothing) && $::ediu(connectMode) != True } {
                if {$::ediu(mode) == $::ediu(designMode)} {
                    Transcript $::ediu(MsgError) "No Design (PCB) specified, build aborted."
                } elseif {$::ediu(mode) == $::ediu(libraryMode)} {
                    Transcript $::ediu(MsgError) "No Central Library (LMC) specified, build aborted."
                } else {
                    Transcript $::ediu(MsgError) "Mode not set, build aborted."
                }

                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Rudimentary error checking - need a name, shape, height, and width!

            if { $::padGeom(name) == "" || $::padGeom(shape) == "" || \
                $::padGeom(height) == "" || $::padGeom(width) == "" } {
                Transcript $::ediu(MsgError) "Incomplete pad definition, build aborted."
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Define a pad name based on the shape, height and width
            set padName [format "%s %sx%s" $::padGeom(shape) $::padGeom(height) $::padGeom(width)]

            ##  Invoke the Padstack Editor and open the target
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenPadstackEditor } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                ediuUpdateStatus $::ediu(ready)
                return
            }

            #  Look for the pad that the AIF references
            set pad [$::ediu(pdstkEdtrDb) FindPad $padName]

            if {$pad == $::ediu(Nothing)} {
                Transcript $::ediu(MsgError) [format "Pad \"%s\" is not defined, padstack \"%s\" build aborted." $padName $::padGeom(name)]
                ediuUpdateStatus $::ediu(ready)
                return
            }

            #  Does the pad exist?

            set oldPadstackName [$::ediu(pdstkEdtrDb) FindPadstack $::padGeom(name)]

            #  Echo some information about what will happen.

            if {$oldPadstackName == $::ediu(Nothing)} {
                Transcript $::ediu(MsgNote) [format "Padstack \"%s\" does not exist." $padName]
            } elseif {$mode == "-replace" } {
                Transcript $::ediu(MsgWarning) [format "Padstack \"%s\" already exists and will be replaced." $::padGeom(name)]
                ##  Can't delete a padstack that is referenced by a padstack
                ##  so need to catch the error if it is raised by the API.
                set errorCode [catch { $oldPadstackName Delete } errorMessage]
                if {$errorCode != 0} {
                    Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePadstackEditor
                    ediuUpdateStatus $::ediu(ready)
                    return
                }
            } else {
                Transcript $::ediu(MsgWarning) [format "Padstack \"%s\" already exists and will not be replaced." $::padGeom(name)]
                MGC::ClosePadstackEditor
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Ready to build the new padstack
            set newPadstack [$::ediu(pdstkEdtrDb) NewPadstack]

            $newPadstack -set Name $::padGeom(name)
            $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypePinSMD)

            $newPadstack -set Pad \
                [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerTopMount)] $pad
            $newPadstack -set Pad \
                [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerBottomMount)] $pad

            $newPadstack Commit

            MGC::ClosePadstackEditor

            ##  Report some time statistics
            set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
            Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

            ediuUpdateStatus $::ediu(ready)
        }

        #
        #  MGC::Generate::Cell
        #
        proc Cell { device args } {
            ##  Process command arguments
            array set V { -partition "" } ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {error "unknown option $a"}
                if {$value == {}} {error "value of \"$a\" missing"}
                set V($a) $value
            }

            ediuUpdateStatus $::ediu(busy)
            set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined

            if {$::ediu(targetPath) == $::ediu(Nothing) && $::ediu(connectMode) != True } {
                if {$::ediu(mode) == $::ediu(designMode)} {
                    Transcript $::ediu(MsgError) "No Design (PCB) specified, build aborted."
                } elseif {$::ediu(mode) == $::ediu(libraryMode)} {
                    Transcript $::ediu(MsgError) "No Central Library (LMC) specified, build aborted."
                } else {
                    puts $::ediu(mode)
                    Transcript $::ediu(MsgError) "Mode not set, build aborted."
                }

                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Invoke the Cell Editor and open the LMC or PCB
            ##  Catch any exceptions raised by opening the database

            set errorCode [catch { MGC::OpenCellEditor } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                MGC::CloseCellEditor
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Handling existing cells is much different for library
            ##  mode than it is for design mode.  In design mode there
            ##  isn't a "partition" so none of the partition logic applies.

            if { $::ediu(mode) == $::ediu(libraryMode) } {

                #  Prompt for the Partition if not supplied with -partition

                if { [string equal $V(-partition) ""] } {
                    set ::ediu(cellEdtrPrtnName) \
                        [AIFForms::SelectOneFromList "Select Target Cell Partition" $::ediu(cellEdtrPrtnNames)]

                    if { [string equal $::ediu(cellEdtrPrtnName) ""] } {
                        Transcript $::ediu(MsgError) "No Cell Partition selected, build aborted."
                        MGC::CloseCellEditor
                        ediuUpdateStatus $::ediu(ready)
                        return
                    } else {
                        set ::ediu(cellEdtrPrtnName) [lindex $::ediu(cellEdtrPrtnName) 1]
                    }
                } else {
                    set ::ediu(cellEdtrPrtnName) $V(-partition)
                }

                #  Does the cell exist?  Before we can check, we need a
                #  partition.  There isn't a clear name as to what the
                #  partition name should be so we'll use the name of the
                #  cell as the name of the partition as well.

                #  Cannot access partition list when application is
                #  visible so if it is, hide it temporarily.
                set visibility $::ediu(appVisible)

                $::ediu(cellEdtr) Visible False
                set partitions [$::ediu(cellEdtrDb) Partitions]
                $::ediu(cellEdtr) Visible $visibility

                Transcript $::ediu(MsgNote) [format "Found %s cell %s." [$partitions Count] \
                    [ediuPlural [$partitions Count] "partition"]]

                set pNames {}
                for {set i 1} {$i <= [$partitions Count]} {incr i} {
                    set partition [$partitions Item $i]
                    lappend pNames [$partition Name]
                }

                #  Does the partition exist?

                if { [lsearch $pNames $::ediu(cellEdtrPrtnName)] == -1 } {
                    Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for cell \"%s\"." \
                        $::die(partition) $device]

                    set partition [$::ediu(cellEdtrDb) NewPartition $::ediu(cellEdtrPrtnName)]
                } else {
                    Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for cell \"%s\"." \
                        $::ediu(cellEdtrPrtnName) $device]
                    set partition [$partitions Item [expr [lsearch $pNames $::ediu(cellEdtrPrtnName)] +1]]
                }

                #  Now that the partition work is doene, does the cell exist?

                set cells [$partition Cells]
            } else {
                if { [expr { $V(-partition) ne "" }] } {
                    Transcript $::ediu(MsgWarning) "-partition switch is ignored in Design Mode."
                }
                set partition [$::ediu(cellEdtrDb) ActivePartition]
                set cells [$partition Cells]
            }

            Transcript $::ediu(MsgNote) [format "Found %s %s." [$cells Count] \
                [ediuPlural [$cells Count] "cell"]]

            set cNames {}
            for {set i 1} {$i <= [$cells Count]} {incr i} {
                set cell [$cells Item $i]
                lappend cNames [$cell Name]
            }

            #  Does the cell exist?

            if { [lsearch $cNames $device] == -1 } {
                Transcript $::ediu(MsgNote) [format "Creating new cell \"%s\"." $device]

            } else {
                Transcript $::ediu(MsgNote) [format "Replacing existing cell \"%s.\"" $device]
                set cell [$cells Item [expr [lsearch $cNames $device] +1]]

                ##  Delete the cell and save the database.  The delete
                ##  isn't committed until the database is actually saved.

                $cell Delete
                $::ediu(cellEdtr) SaveActiveDatabase
            }

            ##  Build a new cell.  The first part of this is done in
            ##  in the Cell Editor which is part of the Library Manager.
            ##  The graphics and pins are then added using the Cell Editor
            ##  AddIn which sort of looks like a mini version of Expedititon.

            set devicePinCount [llength $::devices($device)]

            set newCell [$partition NewCell [expr $::CellEditorAddinLib::ECellDBCellType(ecelldbCellTypePackage)]]

            $newCell -set Name $device
            $newCell -set Description $device
            $newCell -set MountType [expr $::CellEditorAddinLib::ECellDBMountType(ecelldbMountTypeSurface)]
            #$newCell -set LayerCount [expr 2]
            $newCell -set PinCount [expr $devicePinCount]
            #puts [format "--->  devicePinCount:  %s" $devicePinCount]
            #$newCell -set Units [expr $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)]
            $newCell -set Units [expr [MapEnum::Units $::database(units) "cell"]]
            #$newCell -set PackageGroup [expr $::CellEditorAddinLib::ECellDBPackageGroup(ecelldbPackageGeneral)]

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
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                ediuUpdateStatus $::ediu(ready)
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
                set padstack($pad) [$::ediu(pdstkEdtrDb) FindPadstack $pad]

                #  Echo some information about what will happen.

                if {$padstack($pad) == $::ediu(Nothing)} {
                    Transcript $::ediu(MsgError) \
                        [format "Reference Padstack \"%s\" does not exist, build aborted." $pad]
                    $cellEditor Close False

                    if { $::ediu(mode) == $::ediu(designMode) } {
                        MGC::ClosePadstackEditor -dontclosedatabase
                    } else {
                        MGC::ClosePadstackEditor
                    }
                    MGC::CloseCellEditor

                    ediuUpdateStatus $::ediu(ready)
                    return -1
                }
            }

            ##  To fix Tcom bug?
            if { $::ediu(mode) == $::ediu(designMode) } {
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

            ##  Start Transations for performance reasons
            $cellEditor TransactionStart [expr $::MGCPCB::EPcbDRCMode(epcbDRCModeDRC)]

            ##  Loop over the collection of pins
            ::tcom::foreach pin $pins {
                ##  Split of the fields extracted from the die file

                set padDefinition [lindex $::devices($device) $i]

                set diePadFields(padname) [lindex $padDefinition 0]
                set diePadFields(pinnum) [lindex $padDefinition 1]
                set diePadFields(padx) [lindex $padDefinition 2]
                set diePadFields(pady) [lindex $padDefinition 3]
                #set diePadFields(net) [Netlist::GetNetName $i]

                #printArray diePadFields

                ## Need to handle sparse mode?

                set skip False

        if { 0 } {
                if { $::ediu(sparseMode) } {
                    if { [lsearch $::ediu(sparsepinnames) $diePadFields(pinnum)] == -1 } {
                        set skip True
                    }
                }
        }

                if { $skip  == False } {
                    Transcript $::ediu(MsgNote) [format "Placing pin \"%s\" using padstack \"%s\"." \
                        $diePadFields(pinnum) $diePadFields(padname)]

                    ##  Need to "Put" the padstack so it can be
                    ##  referenced by the Cell Editor Add Pin process.

                    set padstack [$cellEditor PutPadstack [expr 1] [expr 1] $diePadFields(padname)]

                    $pin CurrentPadstack $padstack
                    $pin SetName $diePadFields(pinnum)

                    set errorCode [catch { $pin Place \
                        [expr $diePadFields(padx)] [expr $diePadFields(pady)] [expr 0] } errorMessage]
                    if {$errorCode != 0} {
                        Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                        #puts [format "Error:  %s  Pin:  %d  Handle:  %s" $errorMessage $i $pin]

                        #puts [$pin IsValid]
                        #puts [$pin Name]
                        #puts [format "-->  Array Size of pins:  %s" [$pins Count]]
                        #puts [$cellEditor Name]
                        break
                    }
                } else {
                    Transcript $::ediu(MsgNote) [format "Skipping pin \"%s\" using padstack \"%s\", not in Sparse Pin list." \
                        $diePadFields(pinnum) $diePadFields(padname)]
                }

                set pin ::tcom::null

                incr i
            }

            ## Define the placement outline

            if { $::ediu(MCMAIF) == 1 } {
                ##  Device might be the BGA ... need to account
                ##  for that possibility before trying to extract
                ##  the height and width from a non-existant section

                if { [lsearch [dict keys $::mcmdie] $device] == -1 } {
                    set width [AIF::GetVar WIDTH BGA]
                    set height [AIF::GetVar HEIGHT BGA]
                } else {
                    set section [format "MCM_%s_%s" [dict get $::mcmdie $device] $device]
                    set width [AIF::GetVar WIDTH $section]
                    set height [AIF::GetVar HEIGHT $section]
                }
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

            set ptsArray [[$cellEditorDoc Utility] CreateRectXYR $x1 $y1 $x2 $y2]

            ##  Add the Placment Outline
            $cellEditor PutPlacementOutline [expr $::MGCPCB::EPcbSide(epcbSideMount)] 5 $ptsArray \
                [expr 0] [expr 0] $component [expr [MapEnum::Units $::database(units) "cell"]]

            ##  Terminate transactions
            $cellEditor TransactionEnd True

            ##  Save edits and close the Cell Editor
            set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "Saving new cell \"%s\" (%s)." $device $time]
            $cellEditor Save
            set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "New cell \"%s\" (%s) saved." $device $time]
            $cellEditor Close False

        ##    if { $::ediu(mode) == $::ediu(designMode) } {
        ##        MGC::ClosePadstackEditor -dontclosedatabase
        ##    } else {
        ##        MGC::ClosePadstackEditor
        ##    }
            MGC::CloseCellEditor

            ##  Report some time statistics
            set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
            Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

            ediuUpdateStatus $::ediu(ready)
        }

        #
        #  MGC::Generate::PDB
        #
        proc PDB { device args } {
            ##  Process command arguments
            array set V { -partition "" } ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {error "unknown option $a"}
                if {$value == {}} {error "value of \"$a\" missing"}
                set V($a) $value
            }

            ediuUpdateStatus $::ediu(busy)
            set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

            ##  Make sure a Target library or design has been defined

            if {$::ediu(targetPath) == $::ediu(Nothing) && $::ediu(connectMode) != True } {
                if {$::ediu(mode) == $::ediu(designMode)} {
                    Transcript $::ediu(MsgError) "No Design (PCB) specified, build aborted."
                } elseif {$::ediu(mode) == $::ediu(libraryMode)} {
                    Transcript $::ediu(MsgError) "No Central Library (LMC) specified, build aborted."
                } else {
                    Transcript $::ediu(MsgError) "Mode not set, build aborted."
                }

                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Invoke the PDB Editor and open the database
            ##  Catch any exceptions raised by opening the database

            set errorCode [catch { MGC::OpenPDBEditor } errorMessage]
            if {$errorCode != 0} {
                Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                ediuUpdateStatus $::ediu(ready)
                return
            }

            ##  Handling existing parts is much different for library
            ##  mode than it is for design mode.  In design mode there
            ##  isn't a "partition" so none of the partition logic applies.

            if { $::ediu(mode) == $::ediu(libraryMode) } {
                #  Does the part exist?  Before we can check, we need a
                #  partition.  There isn't a clear name as to what the
                #  partition name should be so we'll use the name of the
                #  part as the name of the partition as well.

                #  Prompt for the Partition if not supplied with -partition

                if { [string equal $V(-partition) ""] } {
                    set ::ediu(partEdtrPrtnName) \
                        [AIFForms::SelectOneFromList "Select Target Part Partition" $::ediu(partEdtrPrtnNames)]

                    if { [string equal $::ediu(partEdtrPrtnName) ""] } {
                        Transcript $::ediu(MsgError) "No Part Partition selected, build aborted."
                        MGC::CloseCellEditor
                        ediuUpdateStatus $::ediu(ready)
                        return
                    } else {
                        set ::ediu(partEdtrPrtnName) [lindex $::ediu(partEdtrPrtnName) 1]
                    }
                } else {
                    set ::ediu(partEdtrPrtnName) $V(-partition)
                }


                set partitions [$::ediu(partEdtrDb) Partitions]

                Transcript $::ediu(MsgNote) [format "Found %s part %s." [$partitions Count] \
                    [ediuPlural [$partitions Count] "partition"]]

                set pNames {}
                for {set i 1} {$i <= [$partitions Count]} {incr i} {
                    set partition [$partitions Item $i]
                    lappend pNames [$partition Name]
                }

                #  Does the partition exist?

                if { [lsearch $pNames $::ediu(partEdtrPrtnName)] == -1 } {
                    Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for part \"%s\"." \
                        $::ediu(partEdtrPrtnName) $device]

                    set partition [$::ediu(partEdtrDb) NewPartition $::ediu(partEdtrPrtnName)]
                } else {
                    Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for part \"%s\"." \
                        $::ediu(partEdtrPrtnName) $device]
                    set partition [$partitions Item [expr [lsearch $pNames $::ediu(partEdtrPrtnName)] +1]]
                }

                #  Now that the partition work is doene, does the part exist?

                set parts [$partition Parts]
            } else {
                if { [expr { $V(-partition) ne "" }] } {
                    Transcript $::ediu(MsgWarning) "-partition switch is ignored in Design Mode."
                }
                set partition [$::ediu(partEdtrDb) ActivePartition]
                set parts [$partition Parts]
            }

            Transcript $::ediu(MsgNote) [format "Found %s %s." [$parts Count] \
                [ediuPlural [$parts Count] "part"]]

            set cNames {}
            for {set i 1} {$i <= [$parts Count]} {incr i} {
                set part [$parts Item $i]
                lappend cNames [$part Name]
            }

            #  Does the part exist?

            if { [lsearch $cNames $device] == -1 } {
                Transcript $::ediu(MsgNote) [format "Creating new part \"%s\"." $device]

            } else {
                Transcript $::ediu(MsgNote) [format "Replacing existing part \"%s.\"" $device]
                set part [$parts Item [expr [lsearch $cNames $device] +1]]

                ##  Delete the part and save the database.  The delete
                ##  isn't committed until the database is actually saved.

                ##  First delete the Symbol Reference

                set errorCode [catch { $part Delete } errorMessage]
                if {$errorCode != 0} {
                    Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
                    MGC::ClosePDBEditor
                    ediuUpdateStatus $::ediu(ready)
                    return
                }
            }

            $::ediu(partEdtr) SaveActiveDatabase

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
                Transcript $::ediu(MsgWarning) \
                    [format "Mapping has %d preexisting Symbol Reference(s)." \
                        [[$mapping SymbolReferences] Count]]

                for { set i 1 } {$i <= [[$mapping SymbolReferences] Count] } {incr i} {
                    Transcript $::ediu(MsgNote) \
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
                Transcript $::ediu(MsgNote) [format "Adding Pin Definition %d \"%s\" %d \"Unknown\"" \
                    $pi $sc [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)]]
                $gate PutPinDefinition [expr $pi] "1" \
                    [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)] "Unknown"
                incr pi
            }

            ##  Report symbol reference count.  Not sure this is needed ...

            if { [[$mapping SymbolReferences] Count] != 0 } {
                Transcript $::ediu(MsgWarning) \
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
                if { $::ediu(sparseMode) } {
                    #if { $i in ::ediu(sparsepinnumbers) $i } {
                    #    $slot PutPin [expr $i] [format "%s" $i]
                    #}
                } else {
                    Transcript $::ediu(MsgNote) [format "Adding pin %d (\"%s\") to slot." $pi $sc]
                    $slot PutPin [expr $pi] [format "%s" $sc] [format "%s" $pi]
                }
                incr pi
            }

            ##  Commit mapping and close the PDB editor

            Transcript $::ediu(MsgNote) [format "Saving PDB \"%s\"." $device]
            $mapping Commit
            Transcript $::ediu(MsgNote) [format "New PDB \"%s\" saved." $device]
            MGC::ClosePDBEditor

            ##  Report some time statistics
            set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
            Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
            Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]
            ediuUpdateStatus $::ediu(ready)
        }

        #
        #  MGC::Generate::Pads
        #
        #  This subroutine will create die pads based on the "PADS" section
        #  found in the AIF file.  It can optionally replace an existing pad
        #  based on the second argument.
        #

        proc Pads { } {
            foreach i [AIFForms::SelectFromList "Select Pad(s)" [AIF::Pad::GetAllPads]] {
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
            foreach i [AIFForms::SelectFromList "Select Pad(s)" [AIF::Pad::GetAllPads]] {
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
            foreach i [AIFForms::SelectFromList "Select Cell(s)" [array names ::devices]] {
                MGC::Generate::Cell [lindex $i 1]
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
            foreach i [AIFForms::SelectFromList "Select PDB(s)" [array names ::devices]] {
                MGC::Generate::PDB [lindex $i 1]
            }
        }
    }
}

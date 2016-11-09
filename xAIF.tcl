# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  ImportAIF.tcl
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
#  (c) November 2010 - Mentor Graphics Corporation
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
#    10/29/2010 - Initial version.
#    11/14/2010 - Added error checking and handling for access
#                 to Parts Editor database.
#    11/15/2010 - Added Cell Placement Outline.
#    11/18/2010 - Improved error checking and handling to enable
#                 support for both Central Library and PCB Design
#                 as a target.
#    11/19/2010 - Added intial support for PCB database support.
#    11/22/2010 - Added ability to build pads and padstacks in
#                 design mode.
#    11/23/2010 - Added ability to build cell in design mode.
#    12/01/2010 - Added ability to generate a PDB in design mode.
#                 PDB still suffers from symbol reference bug.
#                 Cleaned up debug code and added some error
#                 checking.
#    12/02/2010 - Cleaned up debug code and fixed some error checking.
#    03/25/2011 - Added transactions to cell generation and run time
#                 reporting.
#    03/30/2011 - Added dialog boxes to prompt for Cell and PDB
#                 partition when running in Central Library mode.
#                 This replaces the creation of a new partitions
#                 based on the name of the source die.
#    08/10/2011 - Added "Sparse" mode to allow generation of a sparse
#                 Cell and PDB.  A sparse Cell and PDB allow Expedition
#                 to run more efficiently with extremely large devices.
#    04/10/2014 - Adapted ImportDie.tcl to support AIF
#    05/16/2014 - Basic AIF import working with support for square and
#                 rectangular pads.
#    05/29/2014 - Added sclable zooming and pin tex handling.  Adapted
#                 from example found at:  http://wiki.tcl.tk/4844
#    06/02/2014 - Fixed scroll bars on all ctext widgets and canvas.
#    06/20/2014 - Added balls and bond fingers from AIF netlist.
#    06/24/2014 - Add support for oblong shaped pads.
#    06/25/2014 - Separated pad and refdes text from the object list
#                 so they couldbe managed individually.  Add support
#                 rotation of rectangular and oblong pads.
#    06/26/2014 - Oblong pads are displayed correctly and support rotation.
#    07/14/2014 - New view of AIF netlist implemented using TableList widget.
#    07/18/2014 - New Viewing models, bond wire connections, and net line
#                 connections all added and working.
#    07/20/2014 - Moved large chunks of code into separate files and 
#                 namespaces to make ease of maintenance/development easier.
#    08/05/2014 - Major re-write of primary Tcl file to include namespace
#                 and elimination of plethora of global variables.
#
#    10/05/2016 - Major re-write to eliminate dependency on ActiveTcl which
#                 only supports 32 bit Xpedition running on Windows.  The Tcl
#                 build supplied with Xpedition will be used which supports
#                 both 32 and 64 bit versions of Xpedition running on Windows
#                 and Linux.  The Mentor supplied version of Tcl includes COM
#                 bindings which work with MainWin on Linux however it does
#                 not include many of the optional Tcl packages that are in
#                 ActiveTcl and were utilized.
#
#                 Only ackages from TclLib, TkLib, and BWidget will be used to
#                 build the new GUI as they are all implemented in Tcl and will
#                 work across platforms.
#                 
#    10/22/2016 - Basic BWidget MainFrame GUI implemented with new menu structure.
#                 Dashboard removed and replaced with Setup menus.
#
#    10/24/2016 - AIF processing all reconnected to new GUI.  Added Zoom Fit to
#                 reset the view.  It isn't foolproof though, sometimes it needs
#                 to be run a couple times.
#
#    Useful links:
#      Drawing rounded polygons:    http://wiki.tcl.tk/8590
#      Drawing regular polygons:    http://wiki.tcl.tk/8398
#      Drawing rounded rectangles:  http://wiki.tcl.tk/1416
#

##  The Mentor SDD supplied Tcl Shell (tclsh8.4) has limited built in
##  package support.  Need to load Tcllib, Tklib, and BWidget in order
##  to have access to the various packages required in this utility.

set xAIFLibPath [file dirname [file normalize [info script]]]

set auto_path [linsert $auto_path 0 [file join $xAIFLibPath lib bwidget-1.9.10 ]]
set auto_path [linsert $auto_path 0 [file join $xAIFLibPath lib tklib-0.6 modules]]
set auto_path [linsert $auto_path 0 [file join $xAIFLibPath lib tcllib-1.18 modules]]

package require tcom
#package require csv
package require ctext
#package require cmdline
#package require struct::matrix
package require tablelist
package require BWidget

##
##  Top level xAIF namespace
##
namespace eval xAIF {

    ##  Tcl doesn't technical support constants so this is the next best thing ...

    namespace eval Const {
        set XAIF_NOTHING                      ""
        set XAIF_MODE_DESIGN                  design
        set XAIF_MODE_LIBRARY                 library
        set XAIF_STATUS_CONNECTED             connected
        set XAIF_STATUS_DISCONNECTED          disconnected
        set CELL_GEN_SUFFIX_NONE_KEY          none
        set CELL_GEN_SUFFIX_NONE_VALUE        "None"
        set CELL_GEN_SUFFIX_NUMERIC_KEY       numeric
        set CELL_GEN_SUFFIX_NUMERIC_VALUE     "Numeric (-1, -2, -3, etc.)"
        set CELL_GEN_SUFFIX_ALPHA_KEY         alpha
        set CELL_GEN_SUFFIX_ALPHA_VALUE       "Alpha (-A, -B, -C, etc.)"
        set CELL_GEN_SUFFIX_DATESTAMP_KEY     datestamp
        set CELL_GEN_SUFFIX_DATESTAMP_VALUE   "Date Stamp (YYYY-MM-DD)"
        set CELL_GEN_SUFFIX_TIMESTAMP_KEY     timestamp
        set CELL_GEN_SUFFIX_TIMESTAMP_VALUE   "Time Stamp (YYYY-MM-DD-HH:MM:SS)"
        set CELL_GEN_BGA_NORMAL_KEY           normal
        set CELL_GEN_BGA_NORMAL_VALUE         "Normal"
        set CELL_GEN_BGA_MSO_KEY              mso
        set CELL_GEN_BGA_MSO_VALUE            "Mount Side Opposite"
        set XAIF_RING_PROCESSING_IGNORE       ignore
        set XAIF_RING_PROCESSING_DISCARD      discard
        set XAIF_LEFTBRACKET                  "\["
        set XAIF_RIGHTBRACKET                 "\]"
        set XAIF_BACKSLASH                    "\\"
        set XAIF_WINDOWSIZEX                  800
        set XAIF_WINDOWSIZEY                  600
        set XAIF_SCALEFACTOR                  1

        set PKG_TYPE_GBL                  OperatingMode
        set USE_TIME_STAMP                UseTimeStamp
        set PKG_TYPE_INFO_S               info_s
        set PKG_TYPE_INFO_POP             info_pop
        set XAIF_DEFAULT_CFG_FILE         xAIF.cfg
        set XAIF_DEFAULT_TXT_FILE         xAIF.txt
    }

    variable sections
    variable ignored
    variable widgets
    variable units
    variable padshapes

    set Widgets(mainframe) {}
    variable View

    set View(XYAxes) on
    set View(Dimensions) on
    set View(PadNumbers) on
    set View(RefDesignators) on

    variable Settings

    ##  Define Settings and default values
    set Settings(name) "Xpedition AIF Utility (xAIF)"
    set Settings(version) "2.0-beta-1"
    set Settings(date) "Thu Nov 03 14:00:05 EDT 2016"
    set Settings(workdir) [pwd]
    set Settings(status) "Ready"
    set Settings(progress) 0
    set Settings(connection) off
    set Settings(DesignPath) {}
    set Settings(LibraryPath) {}
    set Settings(TargetPath) {}
    set Settings(SparseMode) off

    set Settings(BGA) 0
    set Settings(MCMAIF) 0
    set Settings(DIEREF) "U1"
    set Settings(BGAREF) "A1"

    array set pads {}
    array set padgeom {}
    array set padtypes {}

    set bondpads {}
    set bondwires {}
    set bondpadsubst {}

    set netlist {}
    set netnames {}
    set netlines {}

    array set die {}
    array set bga {}
    array set devices {}
    array set mcmdie {}
    array set database {}

    set Settings(workdir) [pwd]

    set Settings(MirrorNone) on
    set Settings(MirrorX) off
    set Settings(MirrorY) off
    set Settings(MirrorXY) off

    set Settings(DefaultCellHeight) 50
    set Settings(CellNameSuffix) $xAIF::Const::CELL_GEN_SUFFIX_NONE_KEY
    set Settings(BGACellGeneration) $xAIF::Const::CELL_GEN_BGA_NORMAL_KEY

    set Settings(operatingmode) $xAIF::Const::XAIF_MODE_DESIGN
    set Settings(connectionstatus) $xAIF::Const::XAIF_STATUS_DISCONNECTED

    set Settings(ShowConsole) on
    set Settings(ConsoleEcho) off
    set Settings(debugmsgs) off

    set Settings(verbosemsgs) on

    set Settings(pdstkEdtr) ""
    set Settings(pdstkEdtrDb) ""

    set Settings(cellEdtr) ""
    set Settings(cellEdtrDb) ""
    set Settings(cellEdtrPrtn) "xAIF-Work"
    set Settings(cellEdtrPrtnName) ""
    set Settings(cellEdtrPrtnNames) {}

    set Settings(partEdtr) ""
    set Settings(partEdtrDb) ""
    set Settings(partEdtrPrtn) "xAIF-Work"
    set Settings(partEdtrPrtnName) ""
    set Settings(partEdtrPrtnNames) {}

    ##  Tool command lines

    set Settings(xpeditionpcb) ""
    set Settings(xpeditionpcbopts) ""

    set Settings(librarymanager) ""
    set Settings(librarymanageropts) ""

    set Settings(appConnect) on
    set Settings(appVisible) on

    ##  Supported units
    set xAIF::units [list um mm cm inch mil]

    ##  Supported pad shapes
    set xAIF::padshapes [list circle round oblong obround rectangle rect square sq poly]

    ##  Keywords to scan for in AIF file
    array unset xAIF::sections
    #array set xAIF::sections {
    #    die "die_name"
    #    padGeomName "pad_geom_name"
    #    padGeomShape "pad_geom_shape"
    #    dieActiveSize "die_active_size"
    #    dieSize "die_size"
    #    diePads "die_pads"
    #}

    ##  Sections within the AIF file
    array set xAIF::sections {
        database "DATABASE"
        die "DIE"
        diePads "PADS"
        netlist "NETLIST"
        bga "BGA"
        mcm_die "MCM_DIE"
    }

    array set xAIF::ignored {
        rings "RINGS"
        bondable_ring_area "BONDABLE_RING_AREA"
        wire "WIRE"
        fiducials "FIDUCIALS"
        die_logo "DIE_LOGO"
    }

    ##  Database Details
    array set xAIF::database {
        type ""
        version ""
        units "um"
        mcm "FALSE"
    }

    ##  Die Details
    array set xAIF::die {
        name ""
        refdes "U1"
        width 0
        height 0
        center { 0 0 }
        partition ""
    }

    ##  BGA Details
    array set xAIF::bga {
        name ""
        refdes "A1"
        width 0
        height 0
    }

    ##
    ##  xAIF::Init
    ##
    proc Init {} {
        variable Settings

        ##  define variables in the xAIF namespace
        #array unset Settings
        if { 0 } {
        array set Settings {
            busy "Busy"
            ready "Ready"
            Nothing ""
            mode ""
            designMode "Design"
            libraryMode "Central Library"
            sparseMode 0
            AIFFile ""
            #sparsePinsFile ""
            TargetPath ""
            PCBDesign ""
            CentralLibrary ""
    	    filename ""
            #sparsepinsfile ""
            statusLine ""
            notebook ""
            dashboard ""
            transcript ""
            sourceview ""
            layoutview ""
            netlistview ""
            #sparsepinsview ""
            xAIF "Xpedition xAIF - AIF Import Utility"
            xAIFVersion "1.0-beta-3"
            MsgNote 0
            MsgWarning 1
            MsgError 2
            pdstkEdtr ""
            pdstkEdtrDb ""
            cellEdtr ""
            cellEdtrDb ""
            cellEdtrPrtn "xAIF-Work"
            cellEdtrPrtnName ""
            cellEdtrPrtnNames {}
            partEdtr ""
            partEdtrDb ""
            partEdtrPrtn "xAIF-Work"
            partEdtrPrtnName ""
            partEdtrPrtnNames {}
            pcbApp ""
            pcbDoc ""
            libApp ""
            libLib ""
            appVisible True
            connectMode on
            sTime ""
            cTime ""
            consoleEcho "True"
            #sparsepinnames {}
            #sparsepinnumbers {}
            LeftBracket "\["
            RightBracket "\]"
            BackSlash "\\"
            ScaleFactor 1
            BGA 0
            MCMAIF 0
            DIEREF "U1"
            BGAREF "A1"
            name "Xpedition AIF Utility (xAIF)"
            version "2.0-beta-1"
            date "Thu Oct 05 14:23:05 EDT 2016"
            workdir [pwd]
            status "Ready"
            connection off
            RingProcessing $xAIF::Const::XAIF_RING_PROCESSING_DISCARD
            progress 0
        }
        }

        ##  Keywords to scan for in AIF file
        array unset xAIF::sections
        #array set xAIF::sections {
        #    die "die_name"
        #    padGeomName "pad_geom_name"
        #    padGeomShape "pad_geom_shape"
        #    dieActiveSize "die_active_size"
        #    dieSize "die_size"
        #    diePads "die_pads"
        #}

        ##  Sections within the AIF file
        array set xAIF::sections {
            database "DATABASE"
            die "DIE"
            diePads "PADS"
            netlist "NETLIST"
            bga "BGA"
            mcm_die "MCM_DIE"
        }

        array set xAIF::ignored {
            rings "RINGS"
            bondable_ring_area "BONDABLE_RING_AREA"
            wire "WIRE"
            fiducials "FIDUCIALS"
            die_logo "DIE_LOGO"
        }

        ##  Namespace array to store widgets
        array unset xAIF::widgets
        array set xAIF::widgets {
            setupmenu ""
            viewmenu ""
            transcript ""
            sourceview ""
            layoutview ""
            netlistview ""
            kynnetlistview ""
            #sparsepinsview ""
            statuslight ""
            progressbar ".ProgressBar"
            design ""
            library ""
            windowSizeX 800
            windowSizeY 600
            mode ""
            AIFFile ""
            AIFType "File Type:"
            TargetPath ""
            CellPartnDlg ".chooseCellPartitionDialog"
            PartPartnDlg ".choosePartPartitionDialog"
        }

        ##  Default to design mode
        set xAIF::Settings(mode) $xAIF::Settings(designMode)

        ##  Supported units
        set xAIF::units [list um mm cm inch mil]

        ##  Supported pad shapes
        set xAIF::padshapes [list circle round oblong obround rectangle rect square sq poly]

        ##  Initialize the AIF data structures
        GUI::File::Init
    }

    #
    #  xAIF::Utility
    #
    namespace eval Utility {
        #
        #  xAIF::Utility::Plural
        #
        proc Plural { count txt } {
            if { $count == 1 } {
                return $txt
            } else {
                return [format "%ss" $txt]
            }
        }

        ##  xAIF::Utility::PrintArray
        proc PrintArray { name } {
            upvar $name a
            foreach el [lsort [array names a]] {
                puts "$el = $a($el)"
            }
        }
    }
}

##  Load additional xAIF modules
##  Load various pieces which comprise the application
foreach script { AIF.tcl Forms.tcl GUI.tcl MapEnum.tcl MGC.tcl Netlist.tcl } {
    puts [format "//  Note:  Loading %s ..." $script]
    source [file join $xAIFLibPath $script]
}

##  Platform?

if { [string equal $::tcl_platform(platform) windows] } {
    ##  Load the Mentor DLL for Xpedition and the requisite editors

    set DLLs [list \
        [file join $::env(SDD_HOME) wg     $::env(SDD_PLATFORM) bin ExpeditionPCB.exe] \
        [file join $::env(SDD_HOME) wg     $::env(SDD_PLATFORM) lib CellEditorAddin.dll] \
        [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) lib PDBEditor.dll] \
        [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) lib PadstackEditor.dll] \
    ]

    #set DLL [file join $::env(SDD_HOME) wg $::env(SDD_PLATFORM) bin ExpeditionPCB.exe]
    foreach DLL $DLLs {
        if { [file exists $DLL] } {
            puts stdout [format "//  Note:  Loading API from \"%s\"." $DLL]
            ::tcom::import $DLL
        } else {
            puts stderr [format "//  Error:  Unable to load API from \"%s\"." $DLL]
            exit 1
        }
    }

    ##  Setup Executables
    set xPCB::Settings(xpeditionpcb) [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) bin ExpeditionPCB.exe]
    set xLM::Settings(librarymanager) [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) bin LibraryManager.exe]
} elseif { [string equal $::tcl_platform(platform) unix] } {
    ##  Load the Mentor TLB for Xpedition
    set TLB [file join $::env(SDD_HOME) wg $::env(SDD_PLATFORM) bin ExpeditionPCB.tlb]
    if { [file exists $TLB] } {
        ::tcom::import $TLB
        puts stdout [format "//  Note:  Importing Xpedition API: %s" $TLB]
    } else {
        puts stderr [format "//  Error:  Unable to load Xpedition API from \"%s\"." $TLB]
        exit 1
    }

    ##  Setup Executables
    set xPCB::Settings(xpeditionpcb) [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) bin ExpeditionPCB]
    set xLM::Settings(librarymanager) [file join $::env(SDD_HOME) common $::env(SDD_PLATFORM) bin LibraryManager]
} else {
    ##  Unsupported platform
    puts [format "//  Error:  Platform \"%s\" is unsupported." $tcl_platform(platform)]
    exit 1
}

#parray tcl_platform

#xPCB::Connect
#xPCB::getOpenDocumentPaths $xPCB::Settings(pcbApp)
#xAIF::Init
xAIF::GUI::Build

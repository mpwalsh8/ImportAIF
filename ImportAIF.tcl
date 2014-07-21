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
#  This script requres Tcl 8.4.19.  Tcl 8.5.x and 8.6.x are not supported
#  by the Mentor Graphics COM API interface.  You can download Tcl 8.4.19
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
#
#
#    Useful links:
#      Drawing rounded polygons:  http://wiki.tcl.tk/8590
#      Drawing rounded rectangles:  http://wiki.tcl.tk/1416
#      Drawing regular polygons:  http://wiki.tcl.tk/8398
#

package require tile
package require tcom
package require ctext
package require csv
package require inifile
package require tablelist
package require Tk 8.4
#package require math::bigfloat

##  Load the Mentor DLLs.
::tcom::import "$env(SDD_HOME)/wg/$env(SDD_PLATFORM)/bin/ExpeditionPCB.exe"
::tcom::import "$env(SDD_HOME)/wg/$env(SDD_PLATFORM)/lib/CellEditorAddin.dll"
::tcom::import "$env(SDD_HOME)/common/$env(SDD_PLATFORM)/lib/PDBEditor.dll"
::tcom::import "$env(SDD_HOME)/common/$env(SDD_PLATFORM)/lib/PadstackEditor.dll"

#
#  Initialize the ediu namespace
#
proc ediuInit {} {

    ##  define variables in the ediu namespace
    array unset ::ediu
    array set ::ediu {
        busy "Busy"
        ready "Ready"
        Nothing ""
        mode ""
        designMode "Design"
        libraryMode "Central Library"
        sparseMode 0
        AIFFile ""
        #sparsePinsFile ""
        targetPath ""
        PCBDesign ""
        CentralLibrary ""
	    filename ""
        #sparsepinsfile ""
        statusLine ""
        notebook ""
        transcript ""
        sourceview ""
        graphicview ""
        netlistview ""
        #sparsepinsview ""
        EDIU "Expedition AIF Import Utility"
        MsgNote 0
        MsgWarning 1
        MsgError 2
        pdstkEdtr ""
        pdstkEdtrDb ""
        cellEdtr ""
        cellEdtrDb ""
        cellEdtrPrtn ""
        cellEdtrPrtnName ""
        cellEdtrPrtnNames {}
        partEdtr ""
        partEdtrDb ""
        partEdtrPrtn ""
        partEdtrPrtnName ""
        partEdtrPrtnNames {}
        pcbApp ""
        pcbDoc ""
        appVisible True
        connectMode True
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
    }

    ##  Keywords to scan for in AIF file
    array unset ::sections
    #array set ::sections {
    #    die "die_name"
    #    padGeomName "pad_geom_name"
    #    padGeomShape "pad_geom_shape"
    #    dieActiveSize "die_active_size"
    #    dieSize "die_size"
    #    diePads "die_pads"
    #}

    ##  Sections within the AIF file
    array set ::sections {
        database "DATABASE"
        die "DIE"
        diePads "PADS"
        netlist "NETLIST"
        bga "BGA"
        mcm_die "MCM_DIE"
    }

    array set ::ignored {
        rings "RINGS"
        bondable_ring_area "BONDABLE_RING_AREA"
        wire "WIRE"
        fiducials "FIDUCIALS"
        die_logo "DIE_LOGO"
    }

    ##  Namespace array to store widgets
    array unset ::widgets
    array set ::widgets {
        setupmenu ""
        viewmenu ""
        transcript ""
        sourceview ""
        graphicview ""
        netlistview ""
        kynnetlistview ""
        #sparsepinsview ""
        statuslight ""
        design ""
        library ""
        windowSizeX 800
        windowSizeY 600
        mode ""
        AIFFile ""
        AIFType "File Type:"
        targetPath ""
        CellPartnDlg ".chooseCellPartitionDialog"
        PartPartnDlg ".choosePartPartitionDialog"
    }

    ##  Default to design mode
    set ::ediu(mode) $::ediu(designMode)

    ##  Supported units
    set ::units [list um mm cm inch mil]

    ##  Supported pad shapes
    set ::padshapes [list circle round oblong obround rectangle rect square sq poly]

    ##  Initialize the AIF data structures
    ediuAIFFileInit
}

##
##  ediuAIFFileInit
##
proc ediuAIFFileInit { } {

    ##  Database Details
    array set ::database {
        type ""
        version ""
        units "um"
        mcm "FALSE"
    }

    ##  Die Details
    array set ::die {
        name ""
        refdes "U1"
        width 0
        height 0
        center { 0 0 }
        partition ""
    }

    ##  BGA Details
    array set ::bga {
        name ""
        refdes "A1"
        width 0
        height 0
    }

    ##  Store devices in a Tcl list
    array set ::devices {}

    ##  Store mcm die in a Tcl dictionary
    set ::mcmdie [dict create]

    ##  Store pads in a Tcl dictionary
    set ::pads [dict create]
    set ::padtypes [dict create]

    ##  Store net names in a Tcl list
    set ::netnames [list]

    ##  Store netlist in a Tcl list
    set ::netlist [list]
    set ::netlines [list]

    ##  Store bondpad connections in a Tcl list
    set ::bondwires [list]
}

#
#  Transcript a message with a severity level
#
proc Transcript {severity messagetext} {
    #  Create a message based on severity, default to Note.
    if {$severity == $::ediu(MsgNote)} {
        set msg [format "# Note:  %s" $messagetext]
    } elseif {$severity == $::ediu(MsgWarning)} {
        set msg [format "# Warning:  %s" $messagetext]
    } elseif {$severity == $::ediu(MsgError)} {
        set msg [format "# Error:  %s" $messagetext]
    } else  {
        set msg [format "# Note:  %s" $messagetext]
    }

    set txt $::widgets(transcript)
    $txt configure -state normal
    $txt insert end "$msg\n"
    $txt see end
    $txt configure -state disabled
    update idletasks

    if { $::ediu(consoleEcho) } {
        puts $msg
    }
}

#
#  Build GUI
#
proc BuildGUI {} {

    #  Create the main menu bar
    set mb [menu .menubar]

    #  Define the File menu
    set fm [menu $mb.file -tearoff 0]
    $mb add cascade -label "File" -menu $mb.file -underline 0
    $fm add command -label "Open AIF ..." \
         -accelerator "F5" -underline 0 \
         -command ediuAIFFileOpen
    $fm add command -label "Close AIF" \
         -accelerator "F6" -underline 0 \
         -command ediuAIFFileClose
    $fm add command -label "Export KYN ..." \
         -underline 7 -command ediuFileExportKYN
    #$fm add separator
    #$fm add command -label "Open Sparse Pins ..." \
         -underline 1 -command ediuSparsePinsFileOpen
    #$fm add command -label "Close Sparse Pins " \
         #-underline 1 -command ediuSparsePinsFileClose
    if {[llength [info commands console]]} {
        $fm add separator
	    $fm add command -label "Show Console" \
            -underline 0 \
            -command { console show }
    }

    $fm add separator
    $fm add command -label "Exit" \
         -underline 0 \
         -command exit

    #  Define the Setup menu
    set sm [menu $mb.setup -tearoff 0]
    set ::widgets(setupmenu) $sm
    $mb add cascade -label "Setup" -menu $sm -underline 0
    $sm add radiobutton -label "Design Mode" -underline 0 \
        -variable ::ediu(mode) -value $::ediu(designMode) \
        -command { $::widgets(setupmenu) entryconfigure  3 -state normal ; \
            $::widgets(setupmenu) entryconfigure 4 -state disabled ; \
            set ::ediu(targetPath) $::ediu(Nothing) ; \
            ediuUpdateStatus $::ediu(ready) }
    $sm add radiobutton -label "Central Library Mode" -underline 0 \
        -variable ::ediu(mode) -value $::ediu(libraryMode) \
        -command { $::widgets(setupmenu) entryconfigure  3 -state disabled ; \
            $::widgets(setupmenu) entryconfigure 4 -state normal ; \
            set ::ediu(targetPath) $::ediu(Nothing) ; \
            ediuUpdateStatus $::ediu(ready) }
    $sm add separator
    $sm add command \
        -label "Target Design ..." -state normal \
        -underline 1 -command ediuSetupOpenPCB
    $sm add command \
        -label "Target Central Library ..." -state disabled \
         -underline 2 -command ediuSetupOpenLMC
    #$sm add separator
    #$sm add checkbutton -label "Sparse Mode" -underline 0 \
        #-variable ::ediu(sparseMode) -command ediuToggleSparseMode
    $sm add separator
    $sm add checkbutton -label "Application Visibility" \
        -variable ::ediu(appVisible) -onvalue True -offvalue False \
        -command  {Transcript MsgNote [format "Application visibility is now %s." \
        [expr $::ediu(appVisible) ? "on" : "off"]] }
    $sm add checkbutton -label "Connect to Running Application" \
        -variable ::ediu(connectMode) -onvalue True -offvalue False \
        -command  {Transcript MsgNote [format "Application Connect mode is now %s." \
        [expr $::ediu(connectMode) ? "on" : "off"]] }

    #  Define the Generate menu
    set bm [menu $mb.build -tearoff 0]
    $mb add cascade -label "Generate" -menu $mb.build -underline 0
    #$bm add command -label "Pad ..." \
         #-underline 0 \
         #-command ediuGenerateAIFPad
    $bm add command -label "Pads ..." \
         -underline 0 \
         -command ediuGenerateAIFPads
    $bm add command -label "Padstacks ..." \
         -underline 0 \
         -command ediuGenerateAIFPadstacks
    $bm add command -label "Cells ..." \
         -underline 0 \
         -command ediuGenerateAIFCells
    $bm add command -label "PDBs ..." \
         -underline 1 \
         -command ediuGenerateAIFPDB

    #  Define the View menu
    set vm [menu $mb.zoom -tearoff 0]
    set ::widgets(viewmenu) $vm

    $mb add cascade -label "View" -menu $vm -underline 0
    $vm add cascade -label "Zoom In" \
         -underline 5 -menu $vm.in
    menu $vm.in -tearoff 0
    $vm.in add cascade -label "2x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 2.0}
    $vm.in add command -label "5x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 5.0}
    $vm.in add command -label "10x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 10.0}
    $vm add cascade -label "Zoom Out" \
         -underline 5 -menu $vm.out
    menu $vm.out -tearoff 0
    $vm.out add cascade -label "2x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.5}
    $vm.out add command -label "5x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.2}
    $vm.out add command -label "10x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.1}

    $vm add separator

    if { 0 } {
    $vm add cascade -label "Objects" \
         -underline 1 -menu $vm.objects
    menu $vm.objects -tearoff 0
    $vm.objects add cascade -label "All On" -underline 5 -command { gui::VisibleObject -all on }
    $vm.objects add cascade -label "All Off" -underline 5 -command { gui::VisibleObject -all off }
    $vm.objects add separator
    $vm.objects add checkbutton -label "Pads" -underline 0 \
        -variable gui::objects(diepads) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "Balls" -underline 0 \
        -variable gui::objects(balls) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "Fingers" -underline 0 \
        -variable gui::objects(fingers) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "Die Outline" -underline 0 \
        -variable gui::objects(dieoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "BGA Outline" -underline 0 \
        -variable gui::objects(bgaoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "Part Outlines" -underline 5 \
        -variable gui::objects(partoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    $vm.objects add checkbutton -label "Rings" -underline 0 \
        -variable gui::objects(rings) -onvalue 1 -offvalue 0 -command gui::VisibleObject
    }

    $vm add cascade -label "Text" \
         -underline 1 -menu $vm.text
    menu $vm.text -tearoff 0
    $vm.text add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility "text" -all true -mode on ; \
        foreach t [array names GUI::text] { set GUI::text([lindex $t 0]) on }  }
    $vm.text add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility "text" -all true -mode off ; \
        foreach t [array names GUI::text] { set GUI::text([lindex $t 0]) off }  }
    $vm.text add separator
    $vm.text add checkbutton -label "Pad Numbers" -underline 0 \
        -variable GUI::text(padnumber) -onvalue on -offvalue off \
        -command  "GUI::Visibility padnumber -mode toggle"
    $vm.text add checkbutton -label "Ref Designators" -underline 5 \
        -variable GUI::text(refdes) -onvalue on -offvalue off \
        -command  "GUI::Visibility refdes -mode toggle"

    $vm add cascade -label "Devices" \
         -underline 0 -menu $vm.devices
    menu $vm.devices -tearoff 0
    $vm.devices add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility {bga device} -mode on ; \
        foreach d $::mcmdie { set GUI::devices($d) on } }
    $vm.devices add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility {bga device} -mode off ; \
        foreach d $::mcmdie { set GUI::devices($d) off } }
    $vm.devices add separator

    $vm add cascade -label "Bond Wires" \
         -underline 0 -menu $vm.bondwires
    menu $vm.bondwires -tearoff 0
    $vm.bondwires add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility "bondwire" -all true -mode on ; \
        foreach bw $::bondwires { set GUI::bondwires([lindex $bw 0]) on }  }
    $vm.bondwires add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility "bondwire" -all true -mode off ; \
        foreach bw $::bondwires { set GUI::bondwires([lindex $bw 0]) off }  }
    $vm.bondwires add separator

    $vm add cascade -label "Net Lines" \
         -underline 0 -menu $vm.netlines
    menu $vm.netlines -tearoff 0
    $vm.netlines add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility "netline" -all true -mode on ; \
        foreach nl $::netlines { set GUI::netlines([lindex $nl 0]) on }  }
    $vm.netlines add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility "netline" -all true -mode off ; \
        foreach nl $::netlines { set GUI::netlines([lindex $nl 0]) off }  }
    $vm.netlines add separator

    $vm add cascade -label "Pads" \
         -underline 0 -menu $vm.pads
    menu $vm.pads -tearoff 0
    $vm.pads add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility "pad" -all true -mode on ; \
        foreach p $::pads { set GUI::pads([lindex $p 0]) on }  }
    $vm.pads add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility "pad" -all true -mode off ; \
        foreach p $::pads { set GUI::pads([lindex $p 0]) off }  }
    $vm.pads add separator


    $vm add separator

    $vm add cascade -label "Guides" \
         -underline 0 -menu $vm.guides
    menu $vm.guides -tearoff 0
    $vm.guides add cascade -label "All On" -underline 5 \
        -command { GUI::Visibility "guides" -all true -mode on ; \
        foreach g [array names GUI::guides] { set GUI::guides($g) on }  }
    $vm.guides add cascade -label "All Off" -underline 5 \
        -command { GUI::Visibility "guides" -all true -mode off ; \
        foreach g [array names GUI::guides] { set GUI::guides($g) off }  }
    $vm.guides add separator
    $vm.guides add checkbutton -label "XY Axis" \
        -variable GUI::guides(xyaxis) -onvalue on -offvalue off \
        -command  "GUI::Visibility xyaxis -mode toggle"
    $vm.guides add checkbutton -label "Dimensions" \
        -variable GUI::guides(dimension) -onvalue on -offvalue off \
        -command  "GUI::Visibility dimension -mode toggle"

    # Define the Help menu
    set hm [menu .menubar.help -tearoff 0]
    $mb add cascade -label "Help" -menu $mb.help -underline 0
    $hm add command -label "About ..." \
         -accelerator "F1" -underline 0 \
         -command ediuHelpAbout
    $hm add command -label "Version ..." \
         -underline 0 \
         -command ediuHelpVersion

    ##  Build the notebook UI
    set nb [ttk::notebook .notebook]
    set ::ediu(notebook) $nb

    set tf [ttk::frame $nb.transcript]
    set ::ediu(transcript) $tf
    set sf [ttk::frame $nb.sourceview]
    set ::ediu(sourceview) $sf
    set gf [ttk::frame $nb.graphicview]
    set ::ediu(graphicview) $gf
    set nf [ttk::frame $nb.netlistview]
    set ::ediu(netlistview) $nf
    #set ssf [ttk::frame $nb.sparsepinsview]
    #set ::ediu(sparsepinsview) $ssf
    set nltf [ttk::frame $nb.netlisttable]
    set ::ediu(netlisttable) $nltf
    set knltf [ttk::frame $nb.kynnetlist]
    set ::ediu(kynnetlist) $knltf

    $nb add $gf -text "Graphic View" -padding 4
    $nb add $tf -text "Transcript" -padding 4
    $nb add $sf -text "AIF Source File" -padding 4
    $nb add $nf -text "Netlist" -padding 4
    #$nb add $ssf -text "Sparse Pins" -padding 4
    $nb add $nltf -text "AIF Netlist" -padding 4
    $nb add $knltf -text "KYN Netlist" -padding 4

    #  Hide the netlist tab, it is used but shouldn't be visible
    $nb hide $nf

    #  Define fixed with font used for displaying text
    font create EDIUFont -family Courier -size 10 -weight bold

    #  Text frame for Transcript

    set tftext [ctext $tf.text -wrap none \
        -xscrollcommand [list $tf.tftextscrollx set] \
        -yscrollcommand [list $tf.tftextscrolly set]]
    $tftext configure -font EDIUFont -state disabled
    set ::widgets(transcript) $tftext
    ttk::scrollbar $tf.tftextscrolly -orient vertical -command [list $tftext yview]
    ttk::scrollbar $tf.tftextscrollx -orient horizontal -command [list $tftext xview]
    grid $tftext -row 0 -column 0 -in $tf -sticky nsew
    grid $tf.tftextscrolly -row 0 -column 1 -in $tf -sticky ns
    grid $tf.tftextscrollx x -row 1 -column 0 -in $tf -sticky ew
    grid columnconfigure $tf 0 -weight 1
    grid    rowconfigure $tf 0 -weight 1

    #  Text frame for Source View

    set sftext [ctext $sf.text -wrap none \
        -xscrollcommand [list $sf.sftextscrollx set] \
        -yscrollcommand [list $sf.sftextscrolly set]]
    $sftext configure -font EDIUFont -state disabled
    set ::widgets(sourceview) $sftext
    ttk::scrollbar $sf.sftextscrolly -orient vertical -command [list $sftext yview]
    ttk::scrollbar $sf.sftextscrollx -orient horizontal -command [list $sftext xview]
    grid $sftext -row 0 -column 0 -in $sf -sticky nsew
    grid $sf.sftextscrolly -row 0 -column 1 -in $sf -sticky ns
    grid $sf.sftextscrollx x -row 1 -column 0 -in $sf -sticky ew
    grid columnconfigure $sf 0 -weight 1
    grid    rowconfigure $sf 0 -weight 1

    #  Canvas frame for Graphic View
    set gfcanvas [canvas $gf.canvas -bg black \
        -xscrollcommand [list $gf.gfcanvasscrollx set] \
        -yscrollcommand [list $gf.gfcanvasscrolly set]]
    set ::widgets(graphicview) $gfcanvas
    #$gfcanvas configure -background black
    #$gfcanvas configure -fg white
    ttk::scrollbar $gf.gfcanvasscrolly -orient v -command [list $gfcanvas yview]
    ttk::scrollbar $gf.gfcanvasscrollx -orient h -command [list $gfcanvas xview]
    grid $gfcanvas -row 0 -column 0 -in $gf -sticky nsew
    grid $gf.gfcanvasscrolly -row 0 -column 1 -in $gf -sticky ns -columnspan 1
    grid $gf.gfcanvasscrollx -row 1 -column 0 -in $gf -sticky ew -columnspan 1

    #  Add a couple of zooming buttons
    set bf [frame .buttonframe]
    button $bf.zoomin  -text "Zoom In"  -command "zoom $gfcanvas 1.25" -relief groove -padx 3
    button $bf.zoomout -text "Zoom Out" -command "zoom $gfcanvas 0.80" -relief groove -padx 3
    #button $bf.zoomfit -text "Zoom Fit" -command "zoom $gfcanvas 1" -relief groove -padx 3
    button $bf.zoomin5x  -text "Zoom In 5x"  -command "zoom $gfcanvas 5.00" -relief groove -padx 3
    button $bf.zoomout5x -text "Zoom Out 5x" -command "zoom $gfcanvas 0.20" -relief groove -padx 3
    #grid $bf.zoomin $bf.zoomout -sticky ew -columnspan 1
    #grid $bf.zoomin $bf.zoomout $bf.zoomfit
    grid $bf.zoomin $bf.zoomout $bf.zoomin5x $bf.zoomout5x
    grid $bf -in $gf -sticky w

    grid columnconfigure $gf 0 -weight 1
    grid    rowconfigure $gf 0 -weight 1

    # Set up event bindings for canvas:
    bind $gfcanvas <3> "zoomMark $gfcanvas %x %y"
    bind $gfcanvas <B3-Motion> "zoomStroke $gfcanvas %x %y"
    bind $gfcanvas <ButtonRelease-3> "zoomArea $gfcanvas %x %y"

    #  Text frame for Netlist View

    set nftext [ctext $nf.text -wrap none \
        -xscrollcommand [list $nf.nftextscrollx set] \
        -yscrollcommand [list $nf.nftextscrolly set]]
        
    $nftext configure -font EDIUFont -state disabled
    set ::widgets(netlistview) $nftext
    ttk::scrollbar $nf.nftextscrolly -orient vertical -command [list $nftext yview]
    ttk::scrollbar $nf.nftextscrollx -orient horizontal -command [list $nftext xview]
    grid $nftext -row 0 -column 0 -in $nf -sticky nsew
    grid $nf.nftextscrolly -row 0 -column 1 -in $nf -sticky ns
    grid $nf.nftextscrollx x -row 1 -column 0 -in $nf -sticky ew
    grid columnconfigure $nf 0 -weight 1
    grid    rowconfigure $nf 0 -weight 1

    #  Text frame for Sparse Pins View

    #set ssftext [ctext $ssf.text -wrap none \
        #-xscrollcommand [list $ssf.ssftextscrollx set] \
        #-yscrollcommand [list $ssf.ssftextscrolly set]]
    #$ssftext configure -font EDIUFont -state disabled
    #set ::widgets(sparsepinsview) $ssftext
    #ttk::scrollbar $ssf.ssftextscrolly -orient vertical -command [list $ssftext yview]
    #ttk::scrollbar $ssf.ssftextscrollx -orient horizontal -command [list $ssftext xview]
    #grid $ssftext -row 0 -column 0 -in $ssf -sticky nsew
    #grid $ssf.ssftextscrolly -row 0 -column 1 -in $ssf -sticky ns
    #grid $ssf.ssftextscrollx x -row 1 -column 0 -in $ssf -sticky ew
    #grid columnconfigure $ssf 0 -weight 1
    #grid    rowconfigure $ssf 0 -weight 1

    #  Table frame for Netlist Table View

    set nltable [tablelist::tablelist $nltf.tl -stretch all -background white \
        -xscrollcommand [list $nltf.nltablescrollx set] \
        -yscrollcommand [list $nltf.nltablescrolly set] \
        -fullseparators true -stripebackground "#ddd" -showseparators true -columns { \
        0 "NETNAME" 0 "PADNUM" 0 "PADNAME" 0 "PAD_X" 0 "PAD_Y" 0 "BALLNUM" 0 "BALLNAME" \
        0 "BALL_X" 0 "BALL_Y" 0 "FINNUM" 0 "FINNAME" 0 "FIN_X" 0 "FIN_Y" 0 "ANGLE" }]
    $nltable columnconfigure 0 -sortmode ascii
    $nltable columnconfigure 1 -sortmode ascii
    $nltable columnconfigure 2 -sortmode ascii

    #$nltable configure -font courier-bold -state disabled
    set ::widgets(netlisttable) $nltable
    ttk::scrollbar $nltf.nltablescrolly -orient vertical -command [list $nltable yview]
    ttk::scrollbar $nltf.nltablescrollx -orient horizontal -command [list $nltable xview]
    grid $nltable -row 0 -column 0 -in $nltf -sticky nsew
    grid $nltf.nltablescrolly -row 0 -column 1 -in $nltf -sticky ns
    grid $nltf.nltablescrollx x -row 1 -column 0 -in $nltf -sticky ew
    grid columnconfigure $nltf 0 -weight 1
    grid    rowconfigure $nltf 0 -weight 1

    #  Text frame for Key-in Netlist View

    set knltftext [ctext $knltf.text -wrap none \
        -xscrollcommand [list $knltf.nftextscrollx set] \
        -yscrollcommand [list $knltf.nftextscrolly set]]
        
    $knltftext configure -font EDIUFont -state disabled
    set ::widgets(kynnetlistview) $knltftext
    ttk::scrollbar $knltf.nftextscrolly -orient vertical -command [list $knltftext yview]
    ttk::scrollbar $knltf.nftextscrollx -orient horizontal -command [list $knltftext xview]
    grid $knltftext -row 0 -column 0 -in $knltf -sticky nsew
    grid $knltf.nftextscrolly -row 0 -column 1 -in $knltf -sticky ns
    grid $knltf.nftextscrollx x -row 1 -column 0 -in $knltf -sticky ew
    grid columnconfigure $knltf 0 -weight 1
    grid    rowconfigure $knltf 0 -weight 1

    ##  Build the status bar

    set sf [ttk::frame .status -borderwidth 5 -relief sunken]
    set slf [ttk::frame .statuslightframe -width 20 -borderwidth 3 -relief raised]
    set sl [frame $slf.statuslight -width 15 -background green]
    set ::widgets(statuslight) $sl
    pack $sl -in $slf -fill both -expand yes
    $sl configure -background green
    set mode [ttk::label .mode \
        -padding 5 -textvariable ::widgets(mode)]
    set AIFfile [ttk::label .aifFile \
        -padding 5 -textvariable ::widgets(AIFFile)]
    set AIFType [ttk::label .aifType \
        -padding 5 -textvariable ::widgets(AIFType)]
    set targetpath [ttk::label .targetPath \
        -padding 5 -textvariable ::widgets(targetPath)]

    pack $slf -side left -in $sf -fill both
    pack $mode $AIFfile $AIFType $targetpath -side left -in $sf -fill both -padx 10

    grid $nb -sticky nsew -padx 4 -pady 4
    grid $sf -sticky sew -padx 4 -pady 4

    grid columnconfigure . 0 -weight 1
    grid    rowconfigure . 0 -weight 1

    #  Configure the main window
    wm title . $::ediu(EDIU).
    wm geometry . 1024x768
    . configure -menu .menubar -width 200 -height 150

    #  Bind some function keys
    bind . "<Key F1>" { ediuHelpAbout }
    bind . "<Key F5>" { ediuAIFFileOpen }
    bind . "<Key F6>" { ediuAIFFileClose }

    ## Update the status fields
    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuChooseCellPartition
#
proc ediuChooseCellPartition {} {
    set dlg $::widgets(CellPartnDlg)

    puts [$dlg.f.cellpartition.list curselection]
    puts [$dlg.f.cellpartition.list get [$dlg.f.cellpartition.list curselection]]

    Transcript $::ediu(MsgNote) [format "Cell Partition \"%s\" selected." $::ediu(cellEdtrPrtnName)]

    #destroy $dlg
}

#
#  ediuChooseCellPartitionDialog
#
#  When running in Central Library mode the cell
#  partition must be specified by the user.  The
#  the list of existing partitions is presented to
#  the user to select from.
#

proc ediuChooseCellPartitionDialog {} {
    set dlg $::widgets(CellPartnDlg)

    #  Create the top level window and withdraw it
    toplevel  $dlg
    wm withdraw $dlg

    #  Create the frame
    ttk::frame $dlg.f -relief flat

    #  Central Library Cell Partition
    ttk::labelframe $dlg.f.cellpartition -text "Cell Partitions"
    listbox $dlg.f.cellpartition.list -relief raised -borderwidth 2 \
        -yscrollcommand "$dlg.f.cellpartition.scroll set" \
        -listvariable ::ediu(cellEdtrPrtnNames)
    ttk::scrollbar $dlg.f.cellpartition.scroll -command "$dlg.f.cellpartition.list yview"
    pack $dlg.f.cellpartition.list $dlg.f.cellpartition.scroll \
        -side left -fill both -expand 1 -in $dlg.f.cellpartition
    grid rowconfigure $dlg.f.cellpartition 0 -weight 1
    grid columnconfigure $dlg.f.cellpartition 0 -weight 1

    #pack $dlg.f.cellpartition -fill both
    #ttk::label $dlg.f.cellpartition.namel -text "Partition:"
    #ttk::entry $dlg.f.cellpartition.namet -textvariable ::ediu(cellEdtrPrtnName)

    #  Layout the dialog box
    #pack $dlg.f.cellpartition.list $dlg.f.cellpartition.scroll -side left -fill both
    grid config $dlg.f.cellpartition.list -row 0 -column 0 -sticky wnse
    grid config $dlg.f.cellpartition.scroll -row 0 -column 1 -sticky ns
    #grid config $dlg.f.cellpartition.namel -column 0 -row 1 -sticky e
    #grid config $dlg.f.cellpartition.namet -column 1 -row 1 -sticky snew


    #grid config $dlg.f.cellpartition -sticky ns
    pack $dlg.f.cellpartition -padx 25 -pady 25 -fill both -in $dlg.f -expand 1
    # grid rowconfigure $dlg.f.cellpartition -columnspan 2

    #  Action buttons

    ttk::frame $dlg.f.buttons -relief flat

    ttk::button $dlg.f.buttons.ok -text "Ok" -command { ediuChooseCellPartition }
    ttk::button $dlg.f.buttons.cancel -text "Cancel" -command { destroy $::widgets(CellPartnDlg) }
    
    pack $dlg.f.buttons.ok -side left
    pack $dlg.f.buttons.cancel -side right
    pack $dlg.f.buttons -padx 5 -pady 10 -ipadx 10

    pack $dlg.f.buttons -in $dlg.f -expand 1

    grid rowconfigure $dlg.f 0 -weight 1
    grid rowconfigure $dlg.f 1 -weight 0

    pack $dlg.f -fill x -expand 1

    #  Window manager settings for dialog
    wm title $dlg "Select Cell Partition"
    wm protocol $dlg WM_DELETE_WINDOW {
        $::widgets(CellPartnDlg).f.buttons.cancel invoke
    }
    wm transient $dlg

    #  Ready to display the dialog
    wm deiconify $dlg

    #  Make this a modal dialog
    catch { tk visibility $dlg }
    #focus $dlg.f.cellpartition.namet
    catch { grab set $dlg }
    catch { tkwait window $dlg }
}

#
#  ediuGraphicViewBuild
#
proc ediuGraphicViewBuild {} {
    set rv 0
    set line_no 0
    set vm $::widgets(viewmenu)
    $vm.devices add separator

    set cnvs $::widgets(graphicview)
    set txt $::widgets(netlistview)
    set nlt $::widgets(netlisttable)
    set kyn $::widgets(kynnetlistview)
    
    $cnvs delete all

    ##  Add the outline
    #ediuGraphicViewAddOutline

    ##  Draw the BGA outline (if it exists)
    if { $::ediu(BGA) == 1 } {
        ediuDrawBGAOutline
        set ::devices($::bga(name)) [list]

        #  Add BGA to the View Devices menu and make it visible
        set GUI::devices($::bga(name)) on
        $vm.devices add checkbutton -label "$::bga(name)" -underline 0 \
            -variable GUI::devices($::bga(name)) -onvalue on -offvalue off \
            -command  "GUI::Visibility $::bga(name) -mode toggle"
            
        $vm.devices add separator
    }

    ##  Is this an MCM-AIF?

    if { $::ediu(MCMAIF) == 1 } {
        foreach i [Die::GetAllDie] {
            #set section [format "MCM_%s_%s" [string toupper $i] [dict get $::mcmdie $i]]
            set section [format "MCM_%s_%s" [dict get $::mcmdie $i] $i]
            if { [lsearch -exact [AIF::Sections] $section] != -1 } {
                array set part {
                    REF ""
                    NAME ""
                    WIDTH 0.0
                    HEIGHT 0.0
                    CENTER [list 0.0 0.0]
                    X 0.0
                    Y 0.0
                }

                #  Extract each of the expected keywords from the section
                foreach key [array names part] {
                    if { [lsearch -exact [AIF::Variables $section] $key] != -1 } {
                        set part($key) [AIF::GetVar $key $section]
                    }
                }

                #  Need the REF designator for later

                set part(REF) $i
                puts "\n\n->$i<-\n\n"
                set ::devices($i) [list]
                puts "\n\n<-$i->\n\n"

                #  Split the CENTER keyword into X and Y components
                #
                #  The AIF specification and sample file have the X and Y separated by
                #  both a space and comma character so we'll plan to handle either situation.
                if { [llength [split $part(CENTER) ,]] == 2 } {
                    set part(X) [lindex [split $part(CENTER) ,] 0]
                    set part(Y) [lindex [split $part(CENTER) ,] 1]
                } else {
                    set part(X) [lindex [split $part(CENTER)] 0]
                    set part(Y) [lindex [split $part(CENTER)] 1]
                }

                #  Draw the Part Outline
                ediuDrawPartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)

                #  Add part to the View Devices menu and make it visible
                set GUI::devices($part(REF)) on
                $vm.devices add checkbutton -label "$part(REF)" -underline 0 \
                    -variable GUI::devices($part(REF)) -onvalue on -offvalue off \
                    -command  "GUI::Visibility device-$part(REF) -mode toggle"
            }
        }
    } else {
        if { [lsearch -exact [AIF::Sections] DIE] != -1 } {
            array set part {
                REF ""
                NAME ""
                WIDTH 0.0
                HEIGHT 0.0
                CENTER { 0.0 0.0 }
                X 0.0
                Y 0.0
            }

            #  Extract each of the expected keywords from the section
            foreach key [array names part] {
                if { [lsearch -exact [AIF::Variables DIE] $key] != -1 } {
                    set part($key) [AIF::GetVar $key DIE]
                }
            }

            #  Need the REF designator for later

            set part(REF) $::ediu(DIEREF)
            set ::devices($::ediu(DIEREF)) [list]

            #  Split the CENTER keyword into X and Y components
            #
            #  The AIF specification and sample file have the X and Y separated by
            #  both a space and comma character so we'll plan to handle either situation.
            if { [llength [split $part(CENTER) ,]] == 2 } {
                set part(X) [lindex [split $part(CENTER) ,] 0]
                set part(Y) [lindex [split $part(CENTER) ,] 1]
            } else {
                set part(X) [lindex [split $part(CENTER)] 0]
                set part(Y) [lindex [split $part(CENTER)] 1]
            }

            #  Draw the Part Outline
            ediuDrawPartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)

            #  Add part to the View Devices menu and make it visible
            set GUI::devices($part(REF)) on
            $vm.devices add checkbutton -label "$part(REF)" -underline 0 \
                -variable GUI::devices($part(REF)) -onvalue on -offvalue off \
                -command  "GUI::Visibility device-$part(REF) -mode toggle"
        }
    }

    ##  Load the NETLIST section

    set nl [$txt get 1.0 end]

    ##  Clean up netlist table
    #$nlt configure -state normal
    $nlt delete 0 end

    ##  Process the netlist looking for the pads

    foreach n [split $nl '\n'] {
        puts "==>  $n"
        incr line_no
        ##  Skip blank or empty lines
        if { [string length $n] == 0 } { continue }

        set net [regexp -inline -all -- {\S+} $n]
        set netname [lindex [regexp -inline -all -- {\S+} $n] 0]

        ##  Put netlist into table for easy review

        $nlt insert end $net

        ##  Initialize array to store netlist fields

        array set nlr {
            NETNAME "-"
            PADNUM "-"
            PADNAME "-"
            PAD_X "-"
            PAD_Y "-"
            BALLNUM "-"
            BALLNAME "-"
            BALL_X "-"
            BALL_Y "-"
            FINNUM "-"
            FINNAME "-"
            FIN_X "-"
            FIN_Y "-"
            ANGLE "-"
        }

        #  A simple netlist has 5 fields

        set nlr(NETNAME) [lindex $net 0]
        set nlr(PADNUM) [lindex $net 1]
        set nlr(PADNAME) [lindex $net 2]
        set nlr(PAD_X) [lindex $net 3]
        set nlr(PAD_Y) [lindex $net 4]

        #  A simple netlist with ball assignment has 6 fields
        if { [llength [split $net]] > 5 } {
            set nlr(BALLNUM) [lindex $net 5]
        }

        #  A complex netlist with ball and rings assignments has 14 fields
        if { [llength [split $net]] > 6 } {
            set nlr(BALLNAME) [lindex $net 6]
            set nlr(BALL_X) [lindex $net 7]
            set nlr(BALL_Y) [lindex $net 8]
            set nlr(FINNUM [lindex $net 9]
            set nlr(FINNAME) [lindex $net 10]
            set nlr(FIN_X) [lindex $net 11]
            set nlr(FIN_Y) [lindex $net 12]
            set nlr(ANGLE) [lindex $net 13]
        }

        #printArray nlr

        #  Check the netname and store it for later use
        if { [ regexp {^[[:alpha:][:alnum:]_]*\w} $netname ] == 0 } {
            Transcript $::ediu(MsgError) [format "Net name \"%s\" is not supported AIF syntax." $netname]
            set rv -1
        } else {
            if { [lsearch -exact $::netlist $netname ] == -1 } {
                #lappend ::netlist $netname
                Transcript $::ediu(MsgNote) [format "Found net name \"%s\"." $netname]
            }
        }

        ##  Can the die pad be placed?

        if { $nlr(PADNAME) != "-" } {
            set ref [lindex [split $nlr(PADNUM) "."] 0]
            if { $ref == $nlr(PADNUM) } {
                set padnum $nlr(PADNUM)
                set ref $::ediu(DIEREF)
            } else {
                set padnum [lindex [split $nlr(PADNUM) "."] 1]
            }

            puts "---------------------> Die Pad:  $ref-$padnum"

            ##  Record the pad and location in the device list
            lappend ::devices($ref) [list $nlr(PADNAME) $padnum $nlr(PAD_X) $nlr(PAD_Y)]

            ediuGraphicViewAddPin $nlr(PAD_X) $nlr(PAD_Y) $nlr(PADNUM) $nlr(NETNAME) $nlr(PADNAME) $line_no "diepad pad pad-$nlr(PADNAME) $ref"
            dict lappend ::padtypes $nlr(PADNAME) "diepad"
        } else {
            Transcript $::ediu(MsgWarning) [format "Skipping die pad for net \"%s\" on line %d, no pad assignment." $netname, $line_no]
        }

        ##  Can the BALL pad be placed?

        if { $nlr(BALLNAME) != "-" } {
            puts "---------------------> Ball"

            ##  Record the pad and location in the device list
            lappend ::devices($::bga(name)) [list $nlr(BALLNAME) $nlr(BALLNUM) $nlr(BALL_X) $nlr(BALL_Y)]

            ediuGraphicViewAddPin $nlr(BALL_X) $nlr(BALL_Y) $nlr(BALLNUM) $nlr(NETNAME) $nlr(BALLNAME) $line_no "ballpad pad pad-$nlr(BALLNAME)" "white" "red"
            puts "---------------------> Ball Middle"
            dict lappend ::padtypes $nlr(PADNAME) "ballpad"
            puts "---------------------> Ball End"
        } else {
            Transcript $::ediu(MsgWarning) [format "Skipping ball pad for net \"%s\" on line %d, no ball assignment." $netname, $line_no]
        }

        ##  Can the Finger pad be placed?

        if { $nlr(FINNAME) != "-" } {
            puts "---------------------> Finger"
            ediuGraphicViewAddPin $nlr(FIN_X) $nlr(FIN_Y) $nlr(FINNUM) $nlr(NETNAME) $nlr(FINNAME) $line_no "bondpad pad pad-$nlr(FINNAME)" "purple" "white" $nlr(ANGLE)
            dict lappend ::padtypes $nlr(PADNAME) "bondpad"
        } else {
            Transcript $::ediu(MsgWarning) [format "Skipping finger for net \"%s\" on line %d, no finger assignment." $netname, $line_no]
        }

        ##  Need to detect connections - there are two types:
        ##
        ##  1)  Bond Pad connections
        ##  2)  Any other connection (Die to Die,  Die to BGA, etc.)
        ##

        ##  Look for bond wire connections

        if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(FIN_X) != "-"  && $nlr(FIN_Y) != "-" } {
            lappend ::bondwires [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(FIN_X) $nlr(FIN_Y)]
        }

        ##  Look for net line connections (which are different than netlist connections)

        if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
            lappend ::netlines [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(BALL_X) $nlr(BALL_Y)]
        }

        ##  Add any connections to the netlist

        $nlt insert end $net
        if { $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
            if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-" } {
                lappend ::netlist [list $nlr(NETNAME) $nlr(PADNUM) [format "%s.%s" $::bga(refdes) $nlr(BALLNUM)]]
            } else {
                lappend ::netlist [list $nlr(NETNAME) [format "%s.%s" $::bga(refdes) $nlr(BALLNUM)]]
            }
        }
    }

    #  Generate KYN Netlist
    $kyn configure -state normal

    ##  Netlist file header 
    $kyn insert end ";; V4.1.0\n"
    $kyn insert end "%net\n"
    $kyn insert end "%Prior=1\n\n"
    $kyn insert end "%page=0\n"

    ##  Netlist content
    set p ""
    foreach n $::netlist {
        set c ""
        foreach i $n {
            if { [lsearch $n $i] == 0 } {
                set c $i
                if { $c == $p } {
                    $kyn insert end "*  "
                } else {
                    $kyn insert end "\\$i\\  "
                }
            } else {
                set p [split $i "."]
                if { [llength $p] > 1 } {
                    $kyn insert end [format " \\%s\\-\\%s\\" [lindex $p 0] [lindex $p 1]]
                } else {
                    $kyn insert end [format " \\%s\\-\\%s\\" $::ediu(DIEREF) [lindex $p 0]]
                }
            }
            puts "$i"
        }

        set p $c
        $kyn insert end "\n"
        puts "$n"
    }

    ##  Output the part list
    $kyn insert end "\n%Part\n"
    foreach i [Die::GetAllDie] {
        $kyn insert end [format "\\%s\\   \\%s\\\n" [dict get $::mcmdie $i] $i]
    }
    
    ##  If there is a BGA, make sure to put it in the part list
    if { $::ediu(BGA) == 1 } {
        $kyn insert end [format "\\%s\\   \\%s\\\n" $::bga(name) $::bga(refdes)]
    }

    $kyn configure -state disabled

    #  Draw Bond Wires
    foreach bw $::bondwires {
        foreach {net x1 y1 x2 y2} $bw {
            puts [format "Wire (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
            $cnvs create line $x1 $y1 $x2 $y2 -tags "bondwire bondwire-$net" -fill "orange" -width 1

            #  Add bond wire to the View Bond Wires menu and make it visible
            #  Because a net can have more than one bond wire, need to ensure
            #  already hasn't been added or it will result in redundant menus.

            if { [array size GUI::bondwires] == 0 || \
                 [lsearch [array names GUI::bondwires] $net] == -1 } {
                set GUI::bondwires($net) on
                $vm.bondwires add checkbutton -label "$net" \
                    -variable GUI::bondwires($net) -onvalue on -offvalue off \
                    -command  "GUI::Visibility bondwire-$net -mode toggle"
            }
        }
    }

    #  Draw Net Lines
    foreach nl $::netlines {
        foreach {net x1 y1 x2 y2} $nl {
            puts [format "Net Line (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
            $cnvs create line $x1 $y1 $x2 $y2 -tags "netline netline-$net" -fill "cyan" -width 1

            #  Add bond wire to the View Bond Wires menu and make it visible
            #  Because a net can have more than one bond wire, need to ensure
            #  already hasn't been added or it will result in redundant menus.

            if { [array size GUI::netlines] == 0 || \
                 [lsearch [array names GUI::netlines] $net] == -1 } {
                set GUI::netlines($net) on
                $vm.netlines add checkbutton -label "$net" \
                    -variable GUI::netlines($net) -onvalue on -offvalue off \
                    -command  "GUI::Visibility netline-$net -mode toggle"
            }
        }
    }

    #$nlt configure -state disabled

    ##  Set an initial scale so the die is visible
    ##  This is an estimate based on trying a couple of
    ##  die files.

    set scaleX [expr ($::widgets(windowSizeX) / (2*$::die(width)) * $::ediu(ScaleFactor))]
    puts [format "A:  %s  B:  %s  C:  %s" $scaleX $::widgets(windowSizeX) $::die(width)]
    if { $scaleX > 0 } {
        #ediuGraphicViewZoom $scaleX
        #ediuGraphicViewZoom 1
        #zoom 1 0 0 
        set extents [$cnvs bbox all]
        puts $extents
        #$cnvs create rectangle $extents -outline green
        #$cnvs create oval \
        #    [expr [lindex $extents 0]-2] [expr [lindex $extents 1]-2] \
        #    [expr [lindex $extents 0]+2] [expr [lindex $extents 1]+2] \
        #    -fill green
        #$cnvs create oval \
        #    [expr [lindex $extents 2]-2] [expr [lindex $extents 3]-2] \
        #    [expr [lindex $extents 2]+2] [expr [lindex $extents 3]+2] \
        #    -fill green
        #zoomMark $cnvs [lindex $extents 2] [lindex $extents 3]
        #zoomStroke $cnvs [lindex $extents 0] [lindex $extents 1]
        #zoomArea $cnvs [lindex $extents 0] [lindex $extents 1]

        #  Set the initial view
        zoom $cnvs 25
    }

    return $rv
}

#
#  ediuGraphicViewAddPin
#
proc ediuGraphicViewAddPin { x y pin net pad line_no { tags "diepad" } { color "yellow" } { outline "red" } { angle 0 } } {
    set cnvs $::widgets(graphicview)
    set padtxt [expr {$pin == "-" ? $pad : $pin}]
    puts [format "Pad Text:  %s (Pin:  %s  Pad:  %s" $padtxt $pin $pad]

    ##  Figure out the pad shape
    set shape [Pad::getShape $pad]

    switch -regexp -- $shape {
        "SQ" -
        "SQUARE" {
            set pw [Pad::getWidth $pad]
            $cnvs create rectangle [expr {$x-($pw/2.0)}] [expr {$y-($pw/2.0)}] \
                [expr {$x + ($pw/2.0)}] [expr {$y + ($pw/2.0)}] -outline $outline \
                -fill $color -tags "$tags" 

            #  Add text: Use pin number if it was supplied, otherwise pad name
            $cnvs create text $x $y -text $padtxt -fill $outline \
                -anchor center -font [list arial] -justify center \
                -tags "text padnumber padnumber-$pin $tags"
        }
        "CIRCLE" -
        "ROUND" {
            set pw [Pad::getWidth $pad]
            $cnvs create oval [expr {$x-($pw/2.0)}] [expr {$y-($pw/2.0)}] \
                [expr {$x + ($pw/2.0)}] [expr {$y + ($pw/2.0)}] -outline $outline \
                -fill $color -tags "$tags" 

            #  Add text: Use pin number if it was supplied, otherwise pad name
            $cnvs create text $x $y -text $padtxt -fill $outline \
                -anchor center -font [list arial] -justify center \
                -tags "text padnumber padnumber-$pin $tags"
        }
        "OBLONG" -
        "OBROUND" {
            puts [format "OBLONG PAD on line:  %d" $line_no]
            set pw [Pad::getWidth $pad]
            set ph [Pad::getHeight $pad]

            set x1 [expr $x-($pw/2.0)]
            set y1 [expr $y-($ph/2.0)]
            set x2 [expr $x+($pw/2.0)]
            set y2 [expr $y+($ph/2.0)]
            #set xx1 $x1
            #set yy1 $y1
            #set xx2 $x2
            #set yy2 $y2

            ##  An "oblong" pad is a rectangular pad with rounded ends.  The rounded
            ##  end is circular based on the width of the pad.  Ideally we'd draw this
            ##  as a single polygon but for now the pad is drawn with two round pads
            ##  connected by a rectangular pad.
            ##
            ##  @todo:  Draw it as a single object which will also support rotation.

            #puts [format "Pad extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

            #$cnvs create poly [list $xx1 $yy1  $xx1 $yy2 $xx2 $yy2 $xx2 $yy1] -outline $outline -fill "pink" -tags "dummy"
            #set id [$cnvs create poly [list $x1 $y1  $x1 $y2 $x2 $y2 $x2 $y1] -outline $outline -fill $color -tags "$tags $pad"]

            #  Compose the pad - it is four pieces:  Arc, Segment, Arc, Segment

            set padxy {}

            #  Top arc
            set arc [GUI::ArcPath [expr {$x-($pw/2.0)}] $y1 [expr {$x + ($pw/2.0)}] [expr {$y1+$pw}] -start 180 -extent 180 -sides 20]
            foreach e $arc { lappend padxy $e }

            #  Bottom Arc
            set arc [GUI::ArcPath [expr {$x-($pw/2.0)}] [expr {$y2-$pw}] [expr {$x + ($pw/2.0)}] $y2 -start 0 -extent 180 -sides 20]
            foreach e $arc { lappend padxy $e }

            set id [$cnvs create poly $padxy -outline $outline -fill $color -tags "$tags"]

            #  Add text: Use pin number if it was supplied, otherwise pad name
            $cnvs create text $x $y -text $padtxt -fill $outline \
                -anchor center -font [list arial] -justify center \
                -tags "text padnumber padnumber-$pin $tags"

            #  Handle any angle ajustment

            if { $angle != 0 } {
                set Ox $x
                set Oy $y

                set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
                set xy {}
                foreach {x y} [$cnvs coords $id] {
                    # rotates vector (Ox,Oy)->(x,y) by angle clockwise

                    # Shift the object to the origin
                    set x [expr {$x - $Ox}]
                    set y [expr {$y - $Oy}]

                    #  Rotate the object
                    set xx [expr {$x * cos($radians) - $y * sin($radians)}]
                    set yy [expr {$x * sin($radians) + $y * cos($radians)}]

                    # Shift the object back to the original XY location
                    set xx [expr {$xx + $Ox}]
                    set yy [expr {$yy + $Oy}]

                    lappend xy $xx $yy
                }
                $cnvs coords $id $xy
            }
            
        }
        "RECT" -
        "RECTANGLE" {
            set pw [Pad::getWidth $pad]
            set ph [Pad::getHeight $pad]

            set x1 [expr $x-($pw/2.0)]
            set y1 [expr $y-($ph/2.0)]
            set x2 [expr $x+($pw/2.0)]
            set y2 [expr $y+($ph/2.0)]

            puts [format "Pad extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

            $cnvs create rectangle $x1 $y1 $x2 $y2 -outline $outline -fill $color -tags "$tags $pad"

            #  Add text: Use pin number if it was supplied, otherwise pad name
            $cnvs create text $x $y -text $padtxt -fill $outline \
                -anchor center -font [list arial] -justify center \
                -tags "text padnumber padnumber-$pin $tags"
        }
        default {
            #error "Error parsing $filename (line: $line_no): $line"
            Transcript $::ediu(MsgWarning) [format "Skipping line %d in AIF file \"%s\"." $line_no $::ediu(filename)]
            #puts $line
        }
    }

    #$cnvs scale "pads" 0 0 100 100

    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuGraphicViewAddOutline
#
proc ediuGraphicViewAddOutline {} {
    set x2 [expr ($::die(width) / 2) * $::ediu(ScaleFactor)]
    set x1 [expr (-1 * $x2) * $::ediu(ScaleFactor)]
    set y2 [expr ($::die(height) / 2) * $::ediu(ScaleFactor)]
    set y1 [expr (-1 * $y2) * $::ediu(ScaleFactor)]

    set cnvs $::widgets(graphicview)
    $cnvs create rectangle $x1 $y1 $x2 $y2 -outline blue -tags "outline"

    puts [format "Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]:w

    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuDrawPartOutline
#
proc ediuDrawPartOutline { name height width x y { color "green" } { tags "partoutline" } } {
    #puts [format "Part Outline input:  Name:  %s H:  %s  W:  %s  X:  %s  Y:  %s  C:  %s" $name $height $width $x $y $color]

    set x1 [expr $x-($width/2.0)]
    set x2 [expr $x+($width/2.0)]
    set y1 [expr $y-($height/2.0)]
    set y2 [expr $y+($height/2.0)]

    set cnvs $::widgets(graphicview)
    $cnvs create rectangle $x1 $y1 $x2 $y2 -outline $color -tags "device device-$name $tags"
    $cnvs create text $x2 $y2 -text $name -fill $color \
        -anchor sw -font [list arial] -justify right -tags "text device device-$name refdes refdes-$name"

    #puts [format "Part Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuDrawBGAOutline
#
proc ediuDrawBGAOutline { { color "white" } } {
    set cnvs $::widgets(graphicview)

    set x1 [expr -($::bga(width) / 2)]
    set x2 [expr +($::bga(width) / 2)]
    set y1 [expr -($::bga(height) / 2)]
    set y2 [expr +($::bga(height) / 2)]
    #puts [format "BGA Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

    #  Does BGA section contain POLYGON outline?  If not, use the height and width
    if { [lsearch -exact [AIF::Variables BGA] OUTLINE] != -1 } {
        set poly [split [AIF::GetVar OUTLINE BGA]]
        set pw [lindex $poly 2]
        puts $poly
        if { [lindex $poly 1] == 1 } {
            set points [lreplace $poly  0 3 ]
            puts $points 
        } else {
            Transcript $::ediu(MsgWarning) "Only one polygon supported for BGA outline, reverting to derived outline."
            set x1 [expr -($::bga(width) / 2)]
            set x2 [expr +($::bga(width) / 2)]
            set y1 [expr -($::bga(height) / 2)]
            set y2 [expr +($::bga(height) / 2)]

            set points { $x1 $y1 $x2 $y2 }
        }


    } else {
        set points { $x1 $y1 $x2 $y2 }
    }

    $cnvs create polygon $points -outline $color -tags "$::bga(name) bga bgaoutline"
    $cnvs create text $x2 $y2 -text $::bga(name) -fill $color \
        -anchor sw -font [list arial] -justify right -tags "$::bga(name) bga text refdes"

    #  Add some text to note the corner XY coordinates - visual reference only
    $cnvs create text $x1 $y1 -text [format "X: %.2f  Y: %.2f" $x1 $y1] -fill $color \
        -anchor sw -font [list arial] -justify left -tags "guides dimension text"
    $cnvs create text $x1 $y2 -text [format "X: %.2f  Y: %.2f" $x1 $y2] -fill $color \
        -anchor nw -font [list arial] -justify left -tags "guides dimension text"
    $cnvs create text $x2 $y1 -text [format "X: %.2f  Y: %.2f" $x2 $y1] -fill $color \
        -anchor se -font [list arial] -justify left -tags "guides dimension text"
    $cnvs create text $x2 $y2 -text [format "X: %.2f  Y: %.2f" $x2 $y2] -fill $color \
        -anchor ne -font [list arial] -justify left -tags "guides dimension text"

    #  Add cross hairs through the origin - visual reference only
    $cnvs create line [expr $x1 - $::bga(width) / 4] 0 [expr $x2 +$::bga(width) / 4] 0 \
        -fill $color -dash . -tags "guides xyaxis"
    $cnvs create line 0 [expr $y1 - $::bga(height) / 4] 0 [expr $y2 +$::bga(height) / 4] \
        -fill $color -dash . -tags "guides xyaxis"

    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuGraphicViewZoom
#
#  Adapted from code found here:
#    http://www.tek-tips.com/viewthread.cfm?qid=815783&page=42
#
proc ediuGraphicViewZoom {scale} {
    set cnvs $::widgets(graphicview)

    $cnvs scale all 0 0 $scale $scale

    foreach item [$cnvs find all] {
        if {[$cnvs type $item] == "text"} {
            set font [font actual [$cnvs itemcget $item -font]]
            set index [lsearch -exact $font -size]
            incr index
            set size [lindex $font $index]
            set size [expr {round($size * $scale)}]
            set font [lreplace $font $index $index $size]
            $cnvs itemconfigure $item -font $font
        }
    }
  
    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuAIFFileOpen
#
#  Open a AIF file, read the contents into the
#  Source View and update the appropriate status.
#
proc ediuAIFFileOpen { { f "" } } {
    ediuUpdateStatus $::ediu(busy)
    ediuAIFInitialState

    ##  Set up the sections so they can be highlighted in the AIF source

    set sections {}
    set sectionRegExp ""
    foreach i [array names ::sections] {
        lappend sections $::sections($i)
        puts $::sections($i)
        set sectionRegExp [format "%s%s%s%s%s%s%s" $sectionRegExp \
            [expr {$sectionRegExp == "" ? "(" : "|" }] \
            $::ediu(BackSlash) $::ediu(LeftBracket) $::sections($i) $::ediu(BackSlash) $::ediu(RightBracket) ]
    }

    set sectionRegExp [format "%s)" $sectionRegExp]

    set ignored {}
    set ignoreRegExp ""
    foreach i [array names ::ignored] {
        lappend ignored $::ignored($i)
        puts $::ignored($i)
        set ignoreRegExp [format "%s%s%s%s%s%s%s" $ignoreRegExp \
            [expr {$ignoreRegExp == "" ? "(" : "|" }] \
            $::ediu(BackSlash) $::ediu(LeftBracket) $::ignored($i) $::ediu(BackSlash) $::ediu(RightBracket) ]
    }

    set ignoreRegExp [format "%s)" $ignoreRegExp]

    ##  Prompt the user for a file if not supplied

    if { $f != $::ediu(Nothing) } {
        set ::ediu(filename) $f
    } else {
        set ::ediu(filename) [tk_getOpenFile -filetypes {{AIF .aif} {Txt .txt} {All *}}]
    }

    ##  Process the user supplied file
    if {$::ediu(filename) != $::ediu(Nothing) } {
        Transcript $::ediu(MsgNote) [format "Loading AIF file \"%s\"." $::ediu(filename)]
        set txt $::widgets(sourceview)
        $txt configure -state normal
        $txt delete 1.0 end

        set f [open $::ediu(filename)]
        $txt insert end [read $f]
        Transcript $::ediu(MsgNote) [format "Scanning AIF file \"%s\" for sections." $::ediu(filename)]
        #ctext::addHighlightClass $txt diesections blue $sections
        ctext::addHighlightClassForRegexp $txt diesections blue $sectionRegExp
        ctext::addHighlightClassForRegexp $txt ignoredsections red $ignoreRegExp
        $txt highlight 1.0 end
        $txt configure -state disabled
        close $f
        Transcript $::ediu(MsgNote) [format "Loaded AIF file \"%s\"." $::ediu(filename)]

        ##  Parse AIF file

        AIF::Parse $::ediu(filename)
        Transcript $::ediu(MsgNote) [format "Parsed AIF file \"%s\"." $::ediu(filename)]

        ##  Load the DATABASE section ...

        if { [ ediuAIFDatabaseSection ] == -1 } {
            ediuUpdateStatus $::ediu(ready)
            return -1
        }

        ##  If the file a MCM-AIF file?

        if { $::ediu(MCMAIF) == 1 } {
            if { [ Die::MCMDieSection ] == -1 } {
                ediuUpdateStatus $::ediu(ready)
                return -1
            }
        }

        ##  Load the DIE section ...

        if { [ Die::DieSection ] == -1 } {
            ediuUpdateStatus $::ediu(ready)
            return -1
        }

        ##  Load the optional BGA section ...

        if { $::ediu(BGA) == 1 } {
            if { [ ediuAIFBGASection ] == -1 } {
                ediuUpdateStatus $::ediu(ready)
                return -1
            }
        }

        ##  Load the PADS section ...

        if { [ ediuAIFPadsSection ] == -1 } {
            ediuUpdateStatus $::ediu(ready)
            return -1
        }

        ##  Load the NETLIST section ...

        if { [ ediuAIFNetlistSection ] == -1 } {
            ediuUpdateStatus $::ediu(ready)
            return -1
        }

        ##  Draw the Graphic View

        ediuGraphicViewBuild
    } else {
        Transcript $::ediu(MsgWarning) "No AIF file selected."
    }

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuAIFFileClose
#
#  Close the AIF file and flush anything stored in
#  EDIU memory.  Clear the text widget for the source
#  view and the canvas widget for the graphic view.
#
proc ediuAIFFileClose {} {
    ediuUpdateStatus $::ediu(busy)
    Transcript $::ediu(MsgNote) [format "AIF file \"%s\" closed." $::ediu(filename)]
    ediuAIFInitialState
    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuFileExportKYN
#
proc ediuFileExportKYN { { kyn "" } } {

    set txt $::widgets(kynnetlistview)

    if { $kyn == "" } {
        set kyn [tk_getSaveFile -filetypes {{KYN .kyn} {Txt .txt} {All *}}]
    }

    if { $kyn == "" } {
        Transcript $::ediu(MsgWarning) "No KYN file specified, Export aborted."
        return
    }
        
    #  Write the KYN netlist content to the file
    set f [open $kyn "w+"]
    puts $f [$txt get 1.0 end]
    close $f

    Transcript $::ediu(MsgNote) [format "KYN netlist successfully exported to file \"%s\"." $kyn]

    return
}

#
#  ediuAIFInitialState
#
proc ediuAIFInitialState {} {

    ##  Put everything back into an initial state
    ediuAIFFileInit
    set ::ediu(filename) $::ediu(Nothing)

    ##  Remove all content from the AIF source view
    set txt $::widgets(sourceview)
    $txt configure -state normal
    $txt delete 1.0 end
    $txt configure -state disabled

    ##  Remove all content from the (hidden) netlist text view
    set txt $::widgets(netlistview)
    $txt configure -state normal
    $txt delete 1.0 end
    $txt configure -state disabled

    ##  Remove all content from the keyin netlist text view
    set txt $::widgets(kynnetlistview)
    $txt configure -state normal
    $txt delete 1.0 end
    $txt configure -state disabled

    ##  Remove all content from the source graphic view
    set cnvs $::widgets(graphicview)
    $cnvs delete all

    ##  Remove all content from the AIF Netlist table
    set nlt $::widgets(netlisttable)
    $nlt delete 0 end

    ##  Clean up menus, remove dynamic content
    set vm $::widgets(viewmenu)
    $vm.devices delete 3 end
    $vm.pads delete 3 end
}


#
#  ediuSparsePinsFileOpen
#
#  Open a Text file, read the contents into the
#  Source View and update the appropriate status.
#
proc ediuSparsePinsFileOpen {} {
    ediuUpdateStatus $::ediu(busy)

    ##  Prompt the user for a file
    ##set ::ediu(sparsepinsfile) [tk_getOpenFile -filetypes {{TXT .txt} {CSV .csv} {All *}}]
    set ::ediu(sparsepinsfile) [tk_getOpenFile -filetypes {{TXT .txt} {All *}}]

    ##  Process the user supplied file
    if {$::ediu(sparsepinsfile) == "" } {
        Transcript $::ediu(MsgWarning) "No Sparse Pins file selected."
    } else {
        Transcript $::ediu(MsgNote) [format "Loading Sparse Pins file \"%s\"." $::ediu(sparsepinsfile)]
        set txt $::widgets(sparsepinsview)
        $txt configure -state normal
        $txt delete 1.0 end

        set f [open $::ediu(sparsepinsfile)]
        $txt insert end [read $f]
        Transcript $::ediu(MsgNote) [format "Scanning Sparse List \"%s\" for pin numbers." $::ediu(sparsepinsfile)]
        ctext::addHighlightClassForRegexp $txt sparsepinlist blue {[\t ]*[0-9][0-9]*[\t ]*$}
        $txt highlight 1.0 end
        $txt configure -state disabled
        close $f
        Transcript $::ediu(MsgNote) [format "Loaded Sparse Pins file \"%s\"." $::ediu(sparsepinsfile)]
        Transcript $::ediu(MsgNote) [format "Extracting Pin Numbers from Sparse Pins file \"%s\"." $::ediu(sparsepinsfile)]
        
        #set pins [split $::widgets(sparsepinsview) \n]
        set txt $::widgets(sparsepinsview)
        set pins [split [$txt get 1.0 end] \n]

        set lc 1
        set ::ediu(sparsepinnames) {}
        set ::ediu(sparsepinnumbers) {}
 
        ##  Loop through the pin data and extract the pin names and numbers

        foreach i $pins {
            set pindata [regexp -inline -all -- {\S+} $i]
            if { [llength $pindata] == 0 } {
                continue
            } elseif { [llength $pindata] != 2 } {
                Transcript $::ediu(MsgWarning) [format "Skipping line %s, incorrect number of fields." $lc]
            } else {
                Transcript $::ediu(MsgNote) [format "Found Sparse Pin Number:  \"%s\" on line %s" [lindex $pindata 1] $lc]
                lappend ::ediu(sparsepinnames) [lindex $pindata 1]
                lappend ::ediu(sparsepinnumbers) [lindex $pindata 1]
                ##if { [incr lc] > 100 } { break }
            }

            incr lc
        }
    }

    # Force the scroll to the top of the sparse pins view
    $txt yview moveto 0
    $txt xview moveto 0

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuSparsePinsFileClose
#
#  Close the sparse rules file and flush anything stored
#  in EDIU memory.  Clear the text widget for the sparse
#  rules.
#
proc ediuSparsePinsFileClose {} {
    ediuUpdateStatus $::ediu(busy)
    Transcript $::ediu(MsgNote) [format "Sparse Pins file \"%s\" closed." $::ediu(sparsepinsfile)]
    set ::ediu(sparsepinsfile) $::ediu(Nothing)
    set txt $::widgets(sparsepinsview)
    $txt configure -state normal
    $txt delete 1.0 end
    $txt configure -state disabled
    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuSetupOpenPCB
#
proc ediuSetupOpenPCB { { f "" } } {
    ediuUpdateStatus $::ediu(busy)

    ##  Prompt the user for an Xpedition database

    if { $f != $::ediu(Nothing) } {
        set ::ediu(targetPath) $f
    } else {
        set ::ediu(targetPath) [tk_getOpenFile -filetypes {{PCB .pcb}}]
    }

    if {$::ediu(targetPath) == "" } {
        Transcript $::ediu(MsgWarning) "No Design File selected."
    } else {
        Transcript $::ediu(MsgNote) [format "Design File \"%s\" set as design target." $::ediu(targetPath)]
    }

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuSetupOpenLMC
#
proc ediuSetupOpenLMC { { f "" } } {
    ediuUpdateStatus $::ediu(busy)

    ##  Prompt the user for a Central Library database if not supplied

    if { $f != $::ediu(Nothing) } {
        set ::ediu(targetPath) $f
    } else {
        set ::ediu(targetPath) [tk_getOpenFile -filetypes {{LMC .lmc}}]
    }

    if {$::ediu(targetPath) == "" } {
        Transcript $::ediu(MsgWarning) "No Central Library selected."
    } else {
        Transcript $::ediu(MsgNote) [format "Central Library \"%s\" set as library target." $::ediu(targetPath)]
    }

    ##  Invoke the Cell Editor and open the LMC
    ##  Catch any exceptions raised by opening the database

    set errorCode [catch { ediuOpenCellEditor } errorMessage]
    if {$errorCode != 0} {
        set ::ediu(targetPath) ""
        ediuUpdateStatus $::ediu(ready)
        return -code return 1
    }

    ##  Need to prompt for Cell partition

    puts "cellEdtrDb:  ------>$::ediu(cellEdtrDb)<-----"
    ##  Can't list partitions when application is visible so if it is,
    ##  hide it temporarily while the list of partitions is queried.

    set visbility $::ediu(appVisible)

    $::ediu(cellEdtr) Visible False
    set partitions [$::ediu(cellEdtrDb) Partitions]
    $::ediu(cellEdtr) Visible $visbility

    Transcript $::ediu(MsgNote) [format "Found %s cell %s." [$partitions Count] \
        [ediuPlural [$partitions Count] "partition"]]

    set ::ediu(cellEdtrPrtnNames) {}
    for {set i 1} {$i <= [$partitions Count]} {incr i} {
        set partition [$partitions Item $i]
        lappend ::ediu(cellEdtrPrtnNames) [$partition Name]
        Transcript $::ediu(MsgNote) [format "Found cell partition \"%s.\"" [$partition Name]]
    }
    
    ediuCloseCellEditor

    ##  Invoke the PDB Editor and open the database
    ##  Catch any exceptions raised by opening the database

    set errorCode [catch { ediuOpenPDBEditor } errorMessage]
    if {$errorCode != 0} {
        set ::ediu(targetPath) ""
        ediuUpdateStatus $::ediu(ready)
        return -code return 1
    }

    ##  Need to prompt for PDB partition

    set partitions [$::ediu(partEdtrDb) Partitions]

    Transcript $::ediu(MsgNote) [format "Found %s part %s." [$partitions Count] \
        [ediuPlural [$partitions Count] "partition"]]

    set ::ediu(partEdtrPrtnNames) {}
    for {set i 1} {$i <= [$partitions Count]} {incr i} {
        set partition [$partitions Item $i]
        lappend ::ediu(partEdtrPrtnNames) [$partition Name]
        Transcript $::ediu(MsgNote) [format "Found part partition \"%s.\"" [$partition Name]]
    }

    ediuClosePDBEditor

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuHelpAbout
#
proc ediuHelpAbout {} {
    tk_messageBox -type ok -message "$::ediu(EDIU)\nVersion 1.0" \
        -icon info -title "About"
}

#
#  ediuHelpVersion
#
proc ediuHelpVersion {} {
    tk_messageBox -type ok -message "$::ediu(EDIU)\nVersion 1.0" \
        -icon info -title "Version"
}

#
#  ediuNotImplemented
#
#  Stub procedure for GUI development to prevent Tcl and Tk errors.
#
proc ediuNotImplemented {} {
    tk_messageBox -type ok -icon info -message "This operation has not been implemented."
}

#
#  ediuUpdateStatus
#
#  Update the status panes with relevant informaiton.
#
proc ediuUpdateStatus {mode} {
    set ::widgets(mode) [format "Mode:  %s" $::ediu(mode)]
    set ::widgets(AIFFile) [format "AIF File:  %-50s" $::ediu(filename)]

    ##  Need to determine what mode to update the target path widget
    if { $::ediu(mode) == $::ediu(designMode) } {
        set ::widgets(targetPath) [format "Design Path:  %-40s" $::ediu(targetPath)]
    } elseif { $::ediu(mode) == $::ediu(libraryMode) } {
        set ::widgets(targetPath) [format "Library Path:  %-40s" $::ediu(targetPath)]
    } else {
        set ::widgets(targetPath) [format "%-40s" "N/A"]
    }

    ##  Set the color of the status light
    set slf $::widgets(statuslight)
    if { $mode == $::ediu(busy) } {
        $slf configure -background red
    } else {
        $slf configure -background green
    }

}

#
#  Open the Padstack Editor
#
proc ediuOpenPadstackEditor { { mode "-opendatabase" } } {
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
            set errorCode [catch { ediuOpenExpedition } errorMessage]
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
proc ediuClosePadstackEditor { { mode "-closedatabase" } } {
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
#  ediuPadGeomName
#
#  Scan the AIF source file for the "pad_geom_shape" section
#
proc ediuPadGeomName {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(padGeomName)]

    set txt $::widgets(sourceview)
    set pgn [$txt search $::sections(padGeomName) 1.0 end]

    ##  Was the padGeomName found?

    if { $pgn != $::ediu(Nothing)} {
        set pgnl [lindex [split $pgn .] 0]
        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(padGeomName) $pgnl]

        ##  Need the text from the padGeomName line, drop the terminating semicolon
        set pgnlt [$txt get $pgnl.0 "$pgnl.end - 1 chars"]

        ##  Extract the shape, height, and width from the padGeomShape
        set ::padGeom(name) [lindex [split $pgnlt] 1]
        Transcript $::ediu(MsgNote) [format "Extracted pad name (%s)." $::padGeom(name)]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\"." $::sections(padGeomShape)]
    }
}

#
#  ediuPadGeomShape
#
#  Scan the AIF source file for the "pad_geom_shape" section
#
proc ediuPadGeomShape {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(padGeomShape)]

    set txt $::widgets(sourceview)
    set pgs [$txt search $::sections(padGeomShape) 1.0 end]

    ##  Was the padGeomShape found?

    if { $pgs != $::ediu(Nothing)} {
        set pgsl [lindex [split $pgs .] 0]
        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(padGeomShape) $pgsl]

        ##  Need the text from the padGeomShape line, drop the terminating semicolon
        set pgslt [$txt get $pgsl.0 "$pgsl.end - 1 chars"]

        ##  Extract the shape, height, and width from the padGeomShape
        set ::padGeom(shape) [lindex [split $pgslt] 1]
        set ::padGeom(height) [lindex [split $pgslt] 2]
        set ::padGeom(width) [lindex [split $pgslt] 3]
        set ::padGeom(offsetx) 0.0
        set ::padGeom(offsety) 0.0
        Transcript $::ediu(MsgNote) [format "Extracting pad shape (%s), height (%s), and width (%s)." \
            $::padGeom(shape) $::padGeom(height) $::padGeom(width)]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\"." $::sections(padGeomShape)]
    }
}

#
#  ediuGenerateAIFPads
#
#  This subroutine will create die pads based on the "PADS" section
#  found in the AIF file.  It can optionally replace an existing pad
#  based on the second argument.
#

proc ediuGenerateAIFPads { } {
    foreach i [AIFForms::SelectFromList "Select Pad(s)" [padGetAllPads]] {
        set p [lindex $i 1]
        set ::padGeom(name) $p
        set ::padGeom(shape) [Pad::getShape $p]
        set ::padGeom(width) [Pad::getWidth $p]
        set ::padGeom(height) [Pad::getHeight $p]
        set ::padGeom(offsetx) 0.0
        set ::padGeom(offsety) 0.0

        ediuGenerateAIFPad
    }
}

#
#  ediuGenerateAIFPad
#
#  Pads are interesting in that can't simply be updated.  To change a pad
#  it must be deleted and then replaced.  A pad can't be deleted if it is
#  referenced by a padstack so that scenario must be handled.
#
proc ediuGenerateAIFPad { { mode "-replace" } } {
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
    set errorCode [catch { ediuOpenPadstackEditor } errorMessage]
    if {$errorCode != 0} {
        ediuUpdateStatus $::ediu(ready)
        return
    }

    #  Does the pad exist?

    set oldPadName [$::ediu(pdstkEdtrDb) FindPad $padName]
    puts "Old Pad Name:  ----->$oldPadName<>$padName<-------"

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
            ediuClosePadstackEditor
            ediuUpdateStatus $::ediu(ready)
            return
        }
    } else {
        Transcript $::ediu(MsgWarning) [format "Pad \"%s\" already exists and will not be replaced." $padName]
        ediuClosePadstackEditor
        ediuUpdateStatus $::ediu(ready)
        return
    }

    ##  Ready to build a new pad
    set newPad [$::ediu(pdstkEdtrDb) NewPad]

    $newPad -set Name $padName
puts "------>$padName<----------"
    $newPad -set Shape [expr $shape]
    $newPad -set Width [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(width)]
    $newPad -set Height [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(height)]
    $newPad -set OriginOffsetX [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsetx)]
    $newPad -set OriginOffsetY [expr [MapEnum::Units $::database(units) "pad"]] [expr $::padGeom(offsety)]

    Transcript $::ediu(MsgNote) [format "Committing pad:  %s" $padName]
    $newPad Commit

    ediuClosePadstackEditor

    ##  Report some time statistics
    set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
    Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuGenerateAIFPadstacks
#
#  This subroutine will create die pads based on the "PADS" section
#  found in the AIF file.  It can optionally replace an existing pad
#  based on the second argument.
#

proc ediuGenerateAIFPadstacks { } {
    foreach i [AIFForms::SelectFromList "Select Pad(s)" [padGetAllPads]] {
        set p [lindex $i 1]
        set ::padGeom(name) $p
        set ::padGeom(shape) [Pad::getShape $p]
        set ::padGeom(width) [Pad::getWidth $p]
        set ::padGeom(height) [Pad::getHeight $p]
        set ::padGeom(offsetx) 0.0
        set ::padGeom(offsety) 0.0

        ediuGenerateAIFPadstack
    }
}

#
#  ediuGenerateAIFPadstack
#
proc ediuGenerateAIFPadstack { { mode "-replace" } } {
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
    set errorCode [catch { ediuOpenPadstackEditor } errorMessage]
    if {$errorCode != 0} {
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
            ediuClosePadstackEditor
            ediuUpdateStatus $::ediu(ready)
            return
        }
    } else {
        Transcript $::ediu(MsgWarning) [format "Padstack \"%s\" already exists and will not be replaced." $::padGeom(name)]
        ediuClosePadstackEditor
        ediuUpdateStatus $::ediu(ready)
        return
    }

    ##  Ready to build the new padstack
    set newPadstack [$::ediu(pdstkEdtrDb) NewPadstack]

    $newPadstack -set Name $::padGeom(name)
    $newPadstack -set Type $::PadstackEditorLib::EPsDBPadstackType(epsdbPadstackTypePinSMD)
    
    $newPadstack -set Pad [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerTopMount)] $pad
    $newPadstack -set Pad [expr $::PadstackEditorLib::EPsDBPadLayer(epsdbPadLayerBottomMount)] $pad

    $newPadstack Commit

    ediuClosePadstackEditor

    ##  Report some time statistics
    set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
    Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuGenerateAIFCells
#
#  This subroutine will create die pads based on the "PADS" section
#  found in the AIF file.  It can optionally replace an existing pad
#  based on the second argument.
#

proc ediuGenerateAIFCells { } {
    foreach i [AIFForms::SelectFromList "Select Cell(s)" [array names ::devices]] {
        ediuGenerateAIFCell [lindex $i 1]
    }
}

#
#  Open the Cell Editor
#
proc ediuOpenCellEditor { } {
    ##  Which mode?  Design or Library?
    if { $::ediu(mode) == $::ediu(designMode) } {
        ##  Invoke Expedition on the design so the Cell Editor can be started
        ##  Catch any exceptions raised by opening the database
        set errorCode [catch { ediuOpenExpedition } errorMessage]
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
proc ediuCloseCellEditor {} {
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
proc ediuOpenPDBEditor {} {
    ##  Which mode?  Design or Library?
    if { $::ediu(mode) == $::ediu(designMode) } {
        ##  Invoke Expedition on the design so the PDB Editor can be started
        ##  Catch any exceptions raised by opening the database
        set errorCode [catch { ediuOpenExpedition } errorMessage]
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
proc ediuClosePDBEditor { } {
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

#
#  ediuOpenExpedition
#
#  Open Expedition, open the database, handle licensing.
#
proc ediuOpenExpedition {} {
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
#  ediuAIFName
#
#  Scan the AIF source file for the "die_name" section
#
proc ediuAIFName {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(die)]

    set txt $::widgets(sourceview)
    set dn [$txt search $::sections(die) 1.0 end]

    ##  Was the die found?

    if { $dn != $::ediu(Nothing)} {
        set dnl [lindex [split $dn .] 0]
        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(die) $dnl]

        ##  Need the text from the die line, drop the terminating semicolon
        set dnlt [$txt get $dnl.0 "$dnl.end - 1 chars"]

        ##  Extract the shape, height, and width from the dieShape
        set ::die(name) [lindex [split $dnlt] 1]
        set ::die(partition) [format "%s_die" $::die(name)]
        Transcript $::ediu(MsgNote) [format "Extracted die name (%s)." $::die(name)]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\"." $::sections(die)]
    }
}

#
#  ediuAIFDatabaseSection
#
#  Scan the AIF source file for the "DATABASE" section
#
proc ediuAIFDatabaseSection {} {
    set rv 0

    ##  Make sure we have a DATABASE section!

    if { [lsearch -exact $::AIF::sections DATABASE] != -1 } {
        ##  Load the DATABASE section
        set vars [AIF::Variables DATABASE]

        foreach v $vars {
            #puts [format "-->  %s" $v]
            set ::database([string tolower $v]) [AIF::GetVar $v DATABASE]
        }

        ##  Make sure file format is AIF!

        if { $::database(type) != "AIF" } {
            Transcript $::ediu(MsgError) [format "File \"%s\" is not an AIF file." $::ediu(filename)]
            set rv -1
        }

        if { ([lsearch [AIF::Variables "DATABASE"] "MCM"] != -1) && ($::database(mcm) == "TRUE") } {
            Transcript $::ediu(MsgError) [format "File \"%s\" is an MCM-AIF file." $::ediu(filename)]
            set ::ediu(MCMAIF) 1
            set ::widgets(AIFType) "File Type:  MCM-AIF"
        } else {
            Transcript $::ediu(MsgError) [format "File \"%s\" is an AIF file." $::ediu(filename)]
            set ::ediu(MCMAIF) 0
            set ::widgets(AIFType) "File Type:  AIF"
        }

        ##  Does the AIF file contain a BGA section?
        set ::ediu(BGA) [expr [lsearch [AIF::Sections] "BGA"] != -1 ? 1 : 0]
 
        ##  Check units for legal option - AIF supports UM, MM, CM, INCH, MIL

        if { [lsearch -exact $::units [string tolower $::database(units)]] == -1 } {
            Transcript $::ediu(MsgError) [format "Units \"%s\" are not supported AIF syntax." $::database(units)]
            set rv -1
        }

        foreach i [array names ::database] {
            Transcript $::ediu(MsgNote) [format "Database \"%s\":  %s" [string toupper $i] $::database($i)]
        }
    } else {
        Transcript $::ediu(MsgError) [format "AIF file \"%s\" does not contain a DATABASE section." $::ediu(filename)]
        set rv -1
    }

    return $rv
}

#
#  ediuAIFBGASection
#
#  Scan the AIF source file for the "DIE" section
#
proc ediuAIFBGASection {} {
    ##  Make sure we have a BGA section!
    if { [lsearch -exact $::AIF::sections BGA] != -1 } {
        ##  Load the DIE section
        set vars [AIF::Variables BGA]

        foreach v $vars {
            #puts [format "-->  %s" $v]
            set ::bga([string tolower $v]) [AIF::GetVar $v BGA]
        }

        foreach i [array names ::bga] {
            Transcript $::ediu(MsgNote) [format "BGA \"%s\":  %s" [string toupper $i] $::bga($i)]
        }
    } else {
        Transcript $::ediu(MsgError) [format "AIF file \"%s\" does not contain a BGA section." $::ediu(filename)]
        return -1
    }
}

#
#  ediuAIFPadsSection
#
#  Scan the AIF source file for the "PADS" section
#
proc ediuAIFPadsSection {} {

    set rv 0
    set vm $::widgets(viewmenu)
    $vm.pads add separator

    ##  Make sure we have a PADS section!
    if { [lsearch -exact $::AIF::sections PADS] != -1 } {
        ##  Load the PADS section
        set vars [AIF::Variables PADS]

        ##  Flush the pads dictionary

        set ::pads [dict create]
        set ::padtypes [dict create]

        ##  Populate the pads dictionary

        foreach v $vars {
            dict lappend ::pads $v [AIF::GetVar $v PADS]
            
            #  Add pad to the View Devices menu and make it visible
            set GUI::pads($v) on
            #$vm.pads add checkbutton -label "$v" -underline 0 \
            #    -variable GUI::pads($v) -onvalue on -offvalue off -command GUI::VisiblePad
            $vm.pads add checkbutton -label "$v" \
                -variable GUI::pads($v) -onvalue on -offvalue off \
                -command  "GUI::Visibility pad-$v -mode toggle"
        }

        foreach i [dict keys $::pads] {
            
            set padshape [lindex [regexp -inline -all -- {\S+} [lindex [dict get $::pads $i] 0]] 0]

            ##  Check units for legal option - AIF supports UM, MM, CM, INCH, MIL

            if { [lsearch -exact $::padshapes [string tolower $padshape]] == -1 } {
                Transcript $::ediu(MsgError) [format "Pad shape \"%s\" is not supported AIF syntax." $padshape]
                set rv -1
            } else {
                Transcript $::ediu(MsgNote) [format "Found pad \"%s\" with shape \"%s\"." [string toupper $i] $padshape]
            }
        }

        Transcript $::ediu(MsgNote) [format "AIF source file contains %d %s." [llength [dict keys $::pads]] [ediuPlural [llength [dict keys $::pads]] "pad"]]
    } else {
        Transcript $::ediu(MsgError) [format "AIF file \"%s\" does not contain a PADS section." $::ediu(filename)]
        set rv -1
    }

    return rv
}

#
#  ediuAIFNetlistSection
#
#  Scan the AIF source file for the "NETLIST" section
#
proc ediuAIFNetlistSection {} {
    set rv 0
    set txt $::widgets(netlistview)

    ##  Make sure we have a NETLIST section!
    if { [lsearch -exact $::AIF::sections NETLIST] != -1 } {
        ##  Load the NETLIST section which was previously stored in the netlist text widget

        netlist::load

        Transcript $::ediu(MsgNote) [format "AIF source file contains %d net %s." [ netlist::getConnectionCount ] [ediuPlural [netlist::getConnectionCount] "connection"]]
        Transcript $::ediu(MsgNote) [format "AIF source file contains %d unique %s." [netlist::getNetCount] [ediuPlural [netlist::getNetCount] "net"]]
        
    } else {
        Transcript $::ediu(MsgError) [format "AIF file \"%s\" does not contain a NETLIST section." $::ediu(filename)]
        set rv -1
    }

    return rv
}

#
#  ediuGenerateAIFCell
#
proc ediuGenerateAIFCell { device } {
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

    set errorCode [catch { ediuOpenCellEditor } errorMessage]
    if {$errorCode != 0} {
        ediuUpdateStatus $::ediu(ready)
        return
    }

    ##  Handling existing cells is much different for library
    ##  mode than it is for design mode.  In design mode there
    ##  isn't a "partition" so none of the partition logic applies.

    if { $::ediu(mode) == $::ediu(libraryMode) } {

        #  Prompt for the Partition

        set ::ediu(cellEdtrPrtnName) $::die(partition)
        ediuChooseCellPartitionDialog
        #return

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

        if { [lsearch $pNames $::die(partition)] == -1 } {
            Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for cell \"%s\"." \
                $::die(partition) $::die(name)]

            set partition [$::ediu(cellEdtrDb) NewPartition $::die(partition)]
        } else {
            Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for cell \"%s\"." \
                $::die(partition) $::die(name)]
            set partition [$partitions Item [expr [lsearch $pNames $::die(partition)] +1]]
        }

        #  Now that the partition work is doene, does the cell exist?

        set cells [$partition Cells]
    } else {
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

    if { [lsearch $cNames $::die(name)] == -1 } {
        Transcript $::ediu(MsgNote) [format "Creating new cell \"%s\"." $::die(name)]

    } else {
        Transcript $::ediu(MsgNote) [format "Replacing existing cell \"%s.\"" $::die(name)]
        set cell [$cells Item [expr [lsearch $cNames $::die(name)] +1]]

        ##  Delete the cell and save the database.  The delete
        ##  isn't committed until the database is actually saved.

        $cell Delete
        $::ediu(cellEdtr) SaveActiveDatabase
    }


    ##  Build a new cell.  The first part of this is done in
    ##  in the Cell Editor which is part of the Library Manager.
    ##  The graphics and pins are then added using the Cell Editor
    ##  AddIn which sort of looks like a mini version of Expedititon.

    #set txt $::widgets(netlistview)
    #set devicePinCount [expr {[lindex [split [$txt index end] .] 0] - 1} - 1]
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
    $newCell -set PackageGroup [expr $::CellEditorAddinLib::ECellDBPackageGroup(ecelldbPackageGeneral)]
    ##  Commit the cell to the database so it can
    ##  be edited using the Cell Editor AddIn.
    
    $newCell Commit

    ##  Put the Cell in "Graphical Edit" mode
    ##  to add the pins and graphics.

    ##  Invoke the Padstack Editor and open the target
    ##  Catch any exceptions raised by opening the database
    set errorCode [catch { ediuOpenPadstackEditor -dontopendatabase } errorMessage]
    if {$errorCode != 0} {
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
    
    set pads [netlist::getPads]

    foreach pad $pads {
        set padstack($pad) [$::ediu(pdstkEdtrDb) FindPadstack $pad]
    
        #  Echo some information about what will happen.
    
        if {$padstack($pad) == $::ediu(Nothing)} {
            Transcript $::ediu(MsgError) \
                [format "Reference Padstack \"%s\" does not exist, build aborted." $pad]
            $cellEditor Close False

            if { $::ediu(mode) == $::ediu(designMode) } {
                ediuClosePadstackEditor -dontclosedatabase
            } else {
                ediuClosePadstackEditor
            }
            ediuCloseCellEditor

            ediuUpdateStatus $::ediu(ready)
            return -1
        }
    }

    ##  To fix Tcom bug?
    if { $::ediu(mode) == $::ediu(designMode) } {
        ediuClosePadstackEditor -dontclosedatabase
    } else {
        ediuClosePadstackEditor
    }
    
    ##  Need to "Put" the padstack so it can be
    ##  referenced by the Cell Editor Add Pin process.

    #foreach pad $pads {
    #    set padstack($pad) [$cellEditor PutPadstack [expr 1] [expr 1] $pad]
    #}
        
    set i 0
    unset padstack

    set pins [$cellEditor Pins]
    puts [format "-->  Array Size of pins:  %s" [$pins Count]]

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
        #set diePadFields(net) [netlist::getNetName $i]

        printArray diePadFields
    
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

            set errorCode [catch {
            $pin Place [expr $diePadFields(padx)] [expr $diePadFields(pady)] [expr 0]
                } errorMessage]
            if {$errorCode != 0} {
                puts [format "Error:  %sPin:  %d  Handle:  %s" $errorMessage $i $pin]
    
                puts [$pin IsValid]
                puts [$pin Name]
                puts [format "-->  Array Size of pins:  %s" [$pins Count]]
                puts [$cellEditor Name]
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
    
    set x2 [expr $::die(width) / 2]
    set x1 [expr -1 * $x2]
    set y2 [expr $::die(height) / 2]
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
    Transcript $::ediu(MsgNote) [format "Saving new cell \"%s\" (%s)." $::die(name) $time]
    $cellEditor Save
    set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "New cell \"%s\" (%s) saved." $::die(name) $time]
    $cellEditor Close False

##    if { $::ediu(mode) == $::ediu(designMode) } {
##        ediuClosePadstackEditor -dontclosedatabase
##    } else {
##        ediuClosePadstackEditor
##    }
    ediuCloseCellEditor

    ##  Report some time statistics
    set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
    Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]

    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuGenerateAIFPDBs
#
#  This subroutine will create die pads based on the "PADS" section
#  found in the AIF file.  It can optionally replace an existing pad
#  based on the second argument.
#

proc ediuGenerateAIFPDBs { } {
    foreach i [AIFForms::SelectFromList "Select PDB(s)" [array names ::devices]] {
        ediuGenerateAIFPDB [lindex $i 1]
    }
}


#
#  ediuGenerateAIFPDB
#
proc ediuGenerateAIFPDB { device } {
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

    set errorCode [catch { ediuOpenPDBEditor } errorMessage]
    if {$errorCode != 0} {
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

        set partitions [$::ediu(partEdtrDb) Partitions]

        Transcript $::ediu(MsgNote) [format "Found %s part %s." [$partitions Count] \
            [ediuPlural [$partitions Count] "partition"]]

        set pNames {}
        for {set i 1} {$i <= [$partitions Count]} {incr i} {
            set partition [$partitions Item $i]
            lappend pNames [$partition Name]
        }

        #  Does the partition exist?

        if { [lsearch $pNames $::die(partition)] == -1 } {
            Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for part \"%s\"." \
                $::die(partition) $::die(name)]

            set partition [$::ediu(partEdtrDb) NewPartition $::die(partition)]
        } else {
            Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for part \"%s\"." \
                $::die(partition) $::die(name)]
            set partition [$partitions Item [expr [lsearch $pNames $::die(partition)] +1]]
        }

        #  Now that the partition work is doene, does the part exist?

        set parts [$partition Parts]
    } else {
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

    if { [lsearch $cNames $::die(name)] == -1 } {
        Transcript $::ediu(MsgNote) [format "Creating new part \"%s\"." $::die(name)]

    } else {
        Transcript $::ediu(MsgNote) [format "Replacing existing part \"%s.\"" $::die(name)]
        set part [$parts Item [expr [lsearch $cNames $::die(name)] +1]]

        ##  Delete the part and save the database.  The delete
        ##  isn't committed until the database is actually saved.

        ##  First delete the Symbol Reference

        #$part
        puts "----> Part Sym Refs:  [[$part SymbolReferences] Count]"

        set errorCode [catch { $part Delete } errorMessage]
        if {$errorCode != 0} {
            Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
            ediuClosePDBEditor
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

    puts "----> Mapping Sym Refs:  [[$mapping SymbolReferences] Count]"

    #  Need to add a symbol reference
    set symRef [$mapping PutSymbolReference $device]

    puts "----> Mapping Sym Refs:  [[$mapping SymbolReferences] Count]"

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

    ##  Define the gate - what to do about swap code?
    set gate [$mapping PutGate "gate_1" $devicePinCount \
        $::MGCPCBPartsEditor::EPDBGateType(epdbGateTypeLogical)]

    ##  Add a pin defintition for each pin to the gate
    for {set i 1} {$i <= $devicePinCount} {incr i} {
        Transcript $::ediu(MsgNote) [format "Adding Pin Definition %d \"P%s\" %d \"Unknown\"" \
            $i $i [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)]]
        ##$gate PutPinDefinition [expr $i] [format "P%s" $i] \
        ##    [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)] "Unknown"
        $gate PutPinDefinition [expr $i] "P" \
            [expr $::MGCPCBPartsEditor::EPDBPinPropertyType(epdbPinPropertyPinType)] "Unknown"
    }

    ##

    puts "--->[[$mapping SymbolReferences] Count]<--"

    if { [[$mapping SymbolReferences] Count] != 0 } {
        Transcript $::ediu(MsgWarning) \
            [format "Symbol Reference \"%s\" is already defined." $device]

        set i 1
        set pinNames [$symRef PinNames]
        foreach pn $pinNames {
            puts "2-$i -->  Symbol Pin Name:  $pn"
            incr i
        }
    }


    ##  Define the slot
    set slot [$mapping PutSlot $gate $symRef]

    ##  Add a pin defintition for each pin to the slot
    for { set i 1 } { $i <= $devicePinCount } { incr i } {
        ##  Split of the fields extracted from the die file

        Transcript $::ediu(MsgNote) [format "Adding pin \"%s\" to slot." $i]

        #$slot PutPin [expr $i] [format "%s" $i] [format "P%s" $diePadFields(pinnum)]
        #$slot PutPin [expr $i] [format "%s" $i] [format "%s" $i]

        ## Need to handle sparse mode?
        if { $::ediu(sparseMode) } {
            #if { $i in ::ediu(sparsepinnumbers) $i } {
            #    $slot PutPin [expr $i] [format "%s" $i]
            #}
        } else {
            $slot PutPin [expr $i] [format "%s" $i]
        }
    }

    ##  Commit mapping and close the PDB editor

    Transcript $::ediu(MsgNote) [format "Saving PDB \"%s\"." $::die(name)]
    $mapping Commit
    Transcript $::ediu(MsgNote) [format "New PDB \"%s\" saved." $::die(name)]
    ediuClosePDBEditor

    ##  Report some time statistics
    set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
    Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]
    ediuUpdateStatus $::ediu(ready)
}

##
##  Define the netlist namespace and procedure supporting netlist operations
##  Because net names in the netlist are not guaranteed to be unique (e.g. VSS,
##  GND, etc.), nets are looked up by index.  The netlist can be traversed with
##  a traditional FOR loop.
##
namespace eval netlist {
    variable nl [list]
    variable pads [list]
    variable connections 0
}

#  Load the netlist from the text widget
proc netlist::load { } {
    variable nl
    variable pads
    variable connections

    set txt $::widgets(netlistview)
    
    ##  Clean up list, the text widget may
    ##  return empty stuff we don't want

    foreach n [split [$txt get 1.0 end] '\n'] {
        if { $n == "" } { continue }

        ##  Extract the net name from the first field (col 1)
        set netname [lindex [regexp -inline -all -- {\S+} $n] 0]
        set padname [lindex [regexp -inline -all -- {\S+} $n] 2]

        ##  Check net name for legal syntax, add it to the list
        ##  of nets if it is valid.  The list contains just unique
        ##  netnames.  The netlist text widget contains the netlist.

        if { [ regexp {^[[:alpha:][:alnum:]_]*\w} $netname ] == 0 } {
            Transcript $::ediu(MsgError) [format "Net name \"%s\" is not supported AIF syntax." $netname]
            set rv -1
        } else {
            incr connections

            if { [lsearch -exact $nl $netname ] == -1 } {
                lappend nl $netname
                Transcript $::ediu(MsgNote) [format "Found net name \"%s\"." $netname]
            }

            if { [lsearch -exact $pads $padname ] == -1 && $padname != "-" } {
                lappend pads $padname
                Transcript $::ediu(MsgNote) [format "Found reference to pad \"%s\"." $padname]
            }
        }
    }
}

#  Return all of the parameters for a net
proc netlist::getParams { index } {
    set txt $::widgets(netlistview)
    return [regexp -inline -all -- {\S+} [$txt get [expr $index +1].0 [expr $index +1].end]]
}

#  Return a specific parameter for a pad (default to first parameter)
proc netlist::getParam { index { param  0 } } {
    return [lindex [netlist::getParams $index] $param]
}

#  Return the shape of the pad
proc netlist::getNetName { index } {
    return [netlist::getParam $index]
}

proc netlist::getNetCount {} {
    variable nl
    return [llength $netlist::nl]
}

proc netlist::getConnectionCount {} {
    variable connections
    return $netlist::connections
}

proc netlist::netParams {} {
}

proc netlist::getAllNetNames {} {
    variable nl
    return $netlist::nl
}

proc netlist::getPads { } {
    variable pads
    return $netlist::pads
}

proc netlist::getPinNumber { index } {
    return [netlist::getParam $index 1]
}

proc netlist::getPadName { index } {
    return [netlist::getParam $index 2]
}

proc netlist::getDiePadX { index } {
    return [netlist::getParam $index 3]
}

proc netlist::getDiePadY { index } {
    return [netlist::getParam $index 4]
}

#
#  ediuPlural
#
proc ediuPlural { count txt } {
    if { $count == 1 } {
        return $txt
    } else {
        return [format "%ss" $txt]
    }
}

#
# ediuToggleSparseMode
#
proc ediuToggleSparseMode {} {
    Transcript $::ediu(MsgNote) [format "Sparse Mode:  %s" [expr {$::ediu(sparseMode) ? "On" : "Off"}]]
}

#
# ediuToggle
#
proc ediuToggle {varName} {
    upvar 1 $varName var
    set var [expr {$var ? 0 : 1}]
}

#
# ediuNamedArgs
#
#  Extract named arguments from a command
#  @see:  http://wiki.tcl.tk/10702
#
proc ediuNamedArgs {args defaults} {
    upvar 1 "" ""
    array set "" $defaults
    foreach {key value} $args {
        if {![info exists ($key)]} {
            error "bad option '$key', should be one of: [lsort [array names {}]]"
        }
        set ($key) $value
    }
}


#--------------------------------------------------------
#
#  zoomMark
#
#  Mark the first (x,y) coordinate for zooming.
#
#--------------------------------------------------------
proc zoomMark {c x y} {
    global zoomArea
    set zoomArea(x0) [$c canvasx $x]
    set zoomArea(y0) [$c canvasy $y]
    $c create rectangle $x $y $x $y -outline white -tag zoomArea
    #puts "zoomMark:  $x $y"
}

#--------------------------------------------------------
#
#  zoomStroke
#
#  Zoom in to the area selected by itemMark and
#  itemStroke.
#
#--------------------------------------------------------
proc zoomStroke {c x y} {
    global zoomArea
    set zoomArea(x1) [$c canvasx $x]
    set zoomArea(y1) [$c canvasy $y]
    $c coords zoomArea $zoomArea(x0) $zoomArea(y0) $zoomArea(x1) $zoomArea(y1)
    #puts "zoomStroke:  $x $y"
}

#--------------------------------------------------------
#
#  zoomArea
#
#  Zoom in to the area selected by itemMark and
#  itemStroke.
#
#--------------------------------------------------------
proc zoomArea {c x y} {
    global zoomArea

    #--------------------------------------------------------
    #  Get the final coordinates.
    #  Remove area selection rectangle
    #--------------------------------------------------------
    set zoomArea(x1) [$c canvasx $x]
    set zoomArea(y1) [$c canvasy $y]
    $c delete zoomArea

    #--------------------------------------------------------
    #  Check for zero-size area
    #--------------------------------------------------------
    if {($zoomArea(x0)==$zoomArea(x1)) || ($zoomArea(y0)==$zoomArea(y1))} {
        return
    }

    #--------------------------------------------------------
    #  Determine size and center of selected area
    #--------------------------------------------------------
    set areaxlength [expr {abs($zoomArea(x1)-$zoomArea(x0))}]
    set areaylength [expr {abs($zoomArea(y1)-$zoomArea(y0))}]
    set xcenter [expr {($zoomArea(x0)+$zoomArea(x1))/2.0}]
    set ycenter [expr {($zoomArea(y0)+$zoomArea(y1))/2.0}]

    #--------------------------------------------------------
    #  Determine size of current window view
    #  Note that canvas scaling always changes the coordinates
    #  into pixel coordinates, so the size of the current
    #  viewport is always the canvas size in pixels.
    #  Since the canvas may have been resized, ask the
    #  window manager for the canvas dimensions.
    #--------------------------------------------------------
    set winxlength [winfo width $c]
    set winylength [winfo height $c]

    #--------------------------------------------------------
    #  Calculate scale factors, and choose smaller
    #--------------------------------------------------------
    set xscale [expr {$winxlength/$areaxlength}]
    set yscale [expr {$winylength/$areaylength}]
    if { $xscale > $yscale } {
        set factor $yscale
    } else {
        set factor $xscale
    }

    #--------------------------------------------------------
    #  Perform zoom operation
    #--------------------------------------------------------
    zoom $c $factor $xcenter $ycenter $winxlength $winylength
    #puts "zoomArea:  $x $y"
}


#--------------------------------------------------------
#
#  zoom
#
#  Zoom the canvas view, based on scale factor 
#  and centerpoint and size of new viewport.  
#  If the center point is not provided, zoom 
#  in/out on the current window center point.
#
#  This procedure uses the canvas scale function to
#  change coordinates of all objects in the canvas.
#
#--------------------------------------------------------
proc zoom { canvas factor \
        {xcenter ""} {ycenter ""} \
        {winxlength ""} {winylength ""} } {

    #--------------------------------------------------------
    #  If (xcenter,ycenter) were not supplied,
    #  get the canvas coordinates of the center
    #  of the current view.  Note that canvas
    #  size may have changed, so ask the window 
    #  manager for its size
    #--------------------------------------------------------
    set winxlength [winfo width $canvas]; # Always calculate [ljl]
    set winylength [winfo height $canvas]
    if { [string equal $xcenter ""] } {
        set xcenter [$canvas canvasx [expr {$winxlength/2.0}]]
        set ycenter [$canvas canvasy [expr {$winylength/2.0}]]
    }

    #--------------------------------------------------------
    #  Scale all objects in the canvas
    #  Adjust our viewport center point
    #--------------------------------------------------------
    $canvas scale all 0 0 $factor $factor
    set xcenter [expr {$xcenter * $factor}]
    set ycenter [expr {$ycenter * $factor}]

    #--------------------------------------------------------
    #  Get the size of all the items on the canvas.
    #
    #  This is *really easy* using 
    #      $canvas bbox all
    #  but it is also wrong.  Non-scalable canvas
    #  items like text and windows now have a different
    #  relative size when compared to all the lines and
    #  rectangles that were uniformly scaled with the 
    #  [$canvas scale] command.  
    #
    #  It would be better to tag all scalable items,
    #  and make a single call to [bbox].
    #  Instead, we iterate through all canvas items and
    #  their coordinates to compute our own bbox.
    #--------------------------------------------------------
    set x0 1.0e30; set x1 -1.0e30 ;
    set y0 1.0e30; set y1 -1.0e30 ;
    foreach item [$canvas find all] {
        switch -exact [$canvas type $item] {
            "arc" -
            "line" -
            "oval" -
            "polygon" -
            "rectangle" {
                set coords [$canvas coords $item]
                foreach {x y} $coords {
                    if { $x < $x0 } {set x0 $x}
                    if { $x > $x1 } {set x1 $x}
                    if { $y < $y0 } {set y0 $y}
                    if { $y > $y0 } {set y1 $y}
                }
            }
        }
    }

    #--------------------------------------------------------
    #  Now figure the size of the bounding box
    #--------------------------------------------------------
    set xlength [expr {$x1-$x0}]
    set ylength [expr {$y1-$y0}]

    #--------------------------------------------------------
    #  But ... if we set the scrollregion and xview/yview 
    #  based on only the scalable items, then it is not 
    #  possible to zoom in on one of the non-scalable items
    #  that is outside of the boundary of the scalable items.
    #
    #  So expand the [bbox] of scaled items until it is
    #  larger than [bbox all], but do so uniformly.
    #--------------------------------------------------------
    foreach {ax0 ay0 ax1 ay1} [$canvas bbox all] {break}

    while { ($ax0<$x0) || ($ay0<$y0) || ($ax1>$x1) || ($ay1>$y1) } {
        # triple the scalable area size
        set x0 [expr {$x0-$xlength}]
        set x1 [expr {$x1+$xlength}]
        set y0 [expr {$y0-$ylength}]
        set y1 [expr {$y1+$ylength}]
        set xlength [expr {$xlength*3.0}]
        set ylength [expr {$ylength*3.0}]
    }

    #--------------------------------------------------------
    #  Now that we've finally got a region defined with
    #  the proper aspect ratio (of only the scalable items)
    #  but large enough to include all items, we can compute
    #  the xview/yview fractions and set our new viewport
    #  correctly.
    #--------------------------------------------------------
    set newxleft [expr {($xcenter-$x0-($winxlength/2.0))/$xlength}]
    set newytop  [expr {($ycenter-$y0-($winylength/2.0))/$ylength}]
    $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
    $canvas xview moveto $newxleft 
    $canvas yview moveto $newytop 

    #--------------------------------------------------------
    #  Change the scroll region one last time, to fit the
    #  items on the canvas.
    #--------------------------------------------------------
    $canvas configure -scrollregion [$canvas bbox all]
}

proc printArray { name } {
    upvar $name a
    foreach el [lsort [array names a]] {
        puts "$el = $a($el)"
    }
}

##  Main application

##  Figure out where the script lives
set pwd [pwd]
cd [file dirname [info script]]
variable IMPORTAIF [pwd]
cd $pwd

##  Load various pieces which comprise the application
foreach script { AIF.tcl Forms.tcl GUI.tcl MapEnum.tcl } {
    source $IMPORTAIF/$script
}

console show
ediuInit
BuildGUI
ediuUpdateStatus $::ediu(ready)
Transcript $::ediu(MsgNote) "$::ediu(EDIU) ready."
#ediuChooseCellPartitionDialog
#puts $retString
#set ::ediu(mode) $::ediu(libraryMode)
#ediuSetupOpenLMC "C:/Users/mike/Documents/Sandbox/Sandbox.lmc"
#set ::ediu(mode) $::ediu(designMode)
#ediuSetupOpenPCB "C:/Users/mike/Documents/a_simple_design_ee794/a_simple_design.pcb"
#catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/Demo1.aif" } retString
#catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/Demo4.aif" } retString
#catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/MCMSampleC.aif" } retString
#catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/BGA_w2_Dies.aif" } retString
##catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/BGA_w2_Dies-2.aif" } retString
#catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/BGA_w2_Dies-3.aif" } retString
catch { ediuAIFFileOpen "c:/users/mike/desktop/ImportAIF/data/Test2.aif" } retString
GUI::Visibility text -all true -mode off
#set ::ediu(cellEdtrPrtnNames) { a b c d e f }
#ediuAIFFileOpen

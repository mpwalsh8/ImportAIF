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
#

package require tile
package require tcom
package require ctext
package require csv
package require inifile
package require Tk 8.4

##  Load the Mentor DLLs.
#::tcom::import "$env(SDD_HOME)/wg/$env(SDD_PLATFORM)/bin/ExpeditionPCB.exe"
#::tcom::import "$env(SDD_HOME)/wg/$env(SDD_PLATFORM)/lib/CellEditorAddin.dll"
#::tcom::import "$env(SDD_HOME)/common/$env(SDD_PLATFORM)/lib/PDBEditor.dll"
#::tcom::import "$env(SDD_HOME)/common/$env(SDD_PLATFORM)/lib/PadstackEditor.dll"

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
        sparsePinsFile ""
        targetPath ""
        PCBDesign ""
        CentralLibrary ""
	    filename ""
        sparsepinsfile ""
        statusLine ""
        notebook ""
        transcript ""
        sourceview ""
        graphicview ""
        sparsepinsview ""
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
        appVisible "True"
        sTime ""
        cTime ""
        consoleEcho "True"
        sparsepinnames {}
        sparsepinnumbers {}
        LeftBracket "\["
        RightBracket "\]"
        BackSlash "\\"
    }

    ##  Keywords to scan for in AIF file
    array unset ::sections
    #array set ::sections {
    #    dieName "die_name"
    #    padGeomName "pad_geom_name"
    #    padGeomShape "pad_geom_shape"
    #    dieActiveSize "die_active_size"
    #    dieSize "die_size"
    #    diePads "die_pads"
    #}
    array set ::sections {
        database "DATABASE"
        dieName "DIE"
        diePads "PADS"
        netlist "NETLIST"
    }

    ##  Namespace array to store widgets
    array unset ::widgets
    array set ::widgets {
        transcript ""
        sourceview ""
        graphicview ""
        sparsepinsview ""
        statuslight ""
        design ""
        library ""
        windowSizeX 800
        windowSizeY 600
        mode ""
        AIFFile ""
        targetPath ""
        CellPartnDlg ".chooseCellPartitionDialog"
        PartPartnDlg ".choosePartPartitionDialog"
    }

    ##  Default to design mode
    set ::ediu(mode) $::ediu(designMode)

    ##  Die Details
    array set ::die {
        type "type"
        version ""
        units "um"
        width 0
        height 0
        name ""
        center { 0 0 }
    }
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
    $fm add command -label "Close AIF " \
         -accelerator "F6" -underline 0 \
         -command ediuAIFFileClose
    $fm add separator
    $fm add command -label "Open Sparse Pins ..." \
         -underline 1 -command ediuSparsePinsFileOpen
    $fm add command -label "Close Sparse Pins " \
         -underline 1 -command ediuSparsePinsFileClose
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
    set ::widgets(setup) $sm
    $mb add cascade -label "Setup" -menu $sm -underline 0
    $sm add radiobutton -label "Design Mode" -underline 0 \
        -variable ::ediu(mode) -value $::ediu(designMode) \
        -command { $::widgets(setup) entryconfigure  3 -state normal ; \
            $::widgets(setup) entryconfigure 4 -state disabled ; \
            set ::ediu(targetPath) $::ediu(Nothing) ; \
            ediuUpdateStatus $::ediu(ready) }
    $sm add radiobutton -label "Central Library Mode" -underline 0 \
        -variable ::ediu(mode) -value $::ediu(libraryMode) \
        -command { $::widgets(setup) entryconfigure  3 -state disabled ; \
            $::widgets(setup) entryconfigure 4 -state normal ; \
            set ::ediu(targetPath) $::ediu(Nothing) ; \
            ediuUpdateStatus $::ediu(ready) }
    $sm add separator
    $sm add command \
        -label "Target Design ..." \
        -underline 1 -command ediuSetupOpenPCB
    $sm add command \
        -label "Target Central Library ..." -state disabled \
         -underline 2 -command ediuSetupOpenLMC
    $sm add separator
    $sm add checkbutton -label "Sparse Mode" -underline 0 \
        -variable ::ediu(sparseMode) -command ediuToggleSparseMode
    $sm add separator
    $sm add radiobutton -label "Application Visibility On" -underline 0 \
        -variable ::ediu(appVisible) -value "True"
    $sm add radiobutton -label "Application Visibility Off" -underline 0 \
        -variable ::ediu(appVisible) -value "False"

    #  Define the Build menu
    set bm [menu $mb.build -tearoff 0]
    $mb add cascade -label "Build" -menu $mb.build -underline 0
    $bm add command -label "AIF Pad ..." \
         -underline 0 \
         -command ediuBuildAIFPad
    $bm add command -label "AIF Padstack ..." \
         -underline 0 \
         -command ediuBuildAIFPadstack
    $bm add command -label "AIF Cell ..." \
         -underline 0 \
         -command ediuBuildAIFCell
    $bm add command -label "AIF PDB ..." \
         -underline 1 \
         -command ediuBuildAIFPDB

    #  Define the Zoom menu
    set zm [menu $mb.zoom -tearoff 0]
    $mb add cascade -label "Zoom" -menu $zm -underline 0
    $zm add cascade -label "In" \
         -underline 0 -menu $zm.in
    menu $zm.in -tearoff 0
    $zm.in add cascade -label "2x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 2.0}
    $zm.in add command -label "5x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 5.0}
    $zm.in add command -label "10x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 10.0}
    $zm add cascade -label "Out" \
         -underline 0 -menu $zm.out
    menu $zm.out -tearoff 0
    $zm.out add cascade -label "2x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.5}
    $zm.out add command -label "5x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.2}
    $zm.out add command -label "10x" \
         -underline 0 \
         -command {ediuGraphicViewZoom 0.1}

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
    set ssf [ttk::frame $nb.sparsepinsview]
    set ::ediu(sparsepinsview) $ssf

    $nb add $nb.transcript -text "Transcript" -padding 4
    $nb add $nb.sourceview -text "Source View" -padding 4
    $nb add $nb.graphicview -text "Graphic View" -padding 4
    $nb add $nb.sparsepinsview -text "Sparse Pins View" -padding 4

    #  Text frame for Transcript
    set tftext [ctext $tf.text]
    $tftext configure -font courier-bold -state disabled
    set ::widgets(transcript) $tftext
    scrollbar .tftextscrolly -orient vertical \
        -command { .notebook.transcript.text yview }
        #-command { $::widgets(transcript) yview }
    scrollbar .tftextscrollx -orient horizontal \
        -command { .notebook.transcript.text xview }
        #-command { $::widgets(transcript) xview }
    grid $tftext -row 0 -column 0 -in $tf -sticky nsew
    grid .tftextscrolly -row 0 -column 1 -in $tf -sticky ns
    grid .tftextscrollx x -row 1 -column 0 -in $tf -sticky ew
    grid columnconfigure $tf 0 -weight 1
    grid    rowconfigure $tf 0 -weight 1

    #  Text frame for Source View
    set sftext [ctext $sf.text -wrap none]
    set ::widgets(sourceview) $sftext
    $sftext configure -font courier-bold -state disabled
    scrollbar .sftextscrolly -orient vertical \
        -command { .notebook.sourceview.text yview }
        #-command { $::widgets(sourceview) yview }
    scrollbar .sftextscrollx -orient horizontal \
        -command { .notebook.sourceview.text xview }
        #-command { $::widgets(sourceview) xview }
    grid $sftext -row 0 -column 0 -in $sf -sticky nsew
    grid .sftextscrolly -row 0 -column 1 -in $sf -sticky ns
    grid .sftextscrollx x -row 1 -column 0 -in $sf -sticky ew
    grid columnconfigure $sf 0 -weight 1
    grid    rowconfigure $sf 0 -weight 1

    #  Canvas frame for Grid View
    set gfcanvas [canvas $gf.canvas]
    set ::widgets(graphicview) $gfcanvas
    $gfcanvas configure -background black
    scrollbar .gfcanvasscrolly -orient vertical \
        -command { .notebook.graphicview.canvas yview }
        #-command { $::widgets(sourceview) yview }
    scrollbar .gfcanvasscrollx -orient horizontal \
        -command { .notebook.graphicview.canvas xview }
        #-command { $::widgets(sourceview) xview }
    grid $gfcanvas -row 0 -column 0 -in $gf -sticky nsew
    grid .gfcanvasscrolly -row 0 -column 1 -in $gf -sticky ns
    grid .gfcanvasscrollx x -row 1 -column 0 -in $gf -sticky ew
    grid columnconfigure $gf 0 -weight 1
    grid    rowconfigure $gf 0 -weight 1

    #  Text frame for Sparse Pins View
    set ssftext [ctext $ssf.text -wrap none]
    set ::widgets(sparsepinsview) $ssftext
    $ssftext configure -font courier-bold -state disabled
    scrollbar .ssftextscrolly -orient vertical \
        -command { .notebook.sparsepinsview.text yview }
        #-command { $::widgets(sparsepinsview) yview }
    scrollbar .ssftextscrollx -orient horizontal \
        -command { .notebook.sparsepinsview.text xview }
        #-command { $::widgets(sparsepinsview) xview }
    grid $ssftext -row 0 -column 0 -in $ssf -sticky nsew
    grid .ssftextscrolly -row 0 -column 1 -in $ssf -sticky ns
    grid .ssftextscrollx x -row 1 -column 0 -in $ssf -sticky ew
    grid columnconfigure $ssf 0 -weight 1
    grid    rowconfigure $ssf 0 -weight 1

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
    set targetpath [ttk::label .targetPath \
        -padding 5 -textvariable ::widgets(targetPath)]

    pack $slf -side left -in $sf -fill both
    pack $mode $AIFfile $targetpath -side left -in $sf -fill both -padx 10

    grid $nb -sticky nsew -padx 4 -pady 4
    grid $sf -sticky sew -padx 4 -pady 4

    grid columnconfigure . 0 -weight 1
    grid    rowconfigure . 0 -weight 1

    #  Configure the main window
    wm title . $::ediu(EDIU).
    wm geometry . 800x600
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

    Transcript $::ediu(MsgNote) [format "Cell Partition \"%s\" selected." $::ediu(cellEdtrPrtnName)]

    destroy $dlg
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
    scrollbar $dlg.f.cellpartition.scroll -command "$dlg.f.cellpartition.list yview"
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
    set cnvs $::widgets(graphicview)
    $cnvs delete all

    for {set i 1} {$i <= $::diePads(count)} {incr i} {
        set dpltf [split $::diePads($i)]
        set AIFPadFields(pinnum) [lindex $dpltf 0]
        set AIFPadFields(padname) [lindex $dpltf 1]
        set AIFPadFields(padx) [expr -1 * [lindex $dpltf 2]]
        set AIFPadFields(pady) [lindex $dpltf 3]
        set AIFPadFields(net) [lindex [split [lindex $dpltf 6] ,] 0]

        ediuGraphicViewAddPin $AIFPadFields(padx) \
            $AIFPadFields(pady) $AIFPadFields(pinnum) $AIFPadFields(net)
    }

    ediuGraphicViewAddOutline

    ##  Set an initial scale so the die is visible
    ##  This is an estimate based on trying a couple of
    ##  die files.

    set scaleX [expr $::widgets(windowSizeX) / (2*$::dieSize(width))]
    ediuGraphicViewZoom $scaleX
}

#
#  ediuGraphicViewAddPin
#
proc ediuGraphicViewAddPin {x y pin net} {
    set cnvs $::widgets(graphicview)
    $cnvs create rectangle [expr {$x-10}] [expr {$y-10}] \
        [expr {$x + 10}] [expr {$y + 10}] -outline red \
        -fill yellow -tags $pin
    $cnvs configure -scrollregion [$cnvs bbox all]
}

#
#  ediuGraphicViewAddOutline
#
proc ediuGraphicViewAddOutline {} {
    set x2 [expr $::dieSize(width) / 2]
    set x1 [expr -1 * $x2]
    set y2 [expr $::dieSize(height) / 2]
    set y1 [expr -1 * $y2]

    set cnvs $::widgets(graphicview)
    $cnvs create rectangle $x1 $y1 $x2 $y2 -outline blue

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
proc ediuAIFFileOpen {} {
    ediuUpdateStatus $::ediu(busy)

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

    ##  Prompt the user for a file
    set ::ediu(filename) [tk_getOpenFile -filetypes {{AIF .aif} {Txt .txt} {All *}}]

    ##  Process the user supplied file
    if {$::ediu(filename) == "" } {
        Transcript $::ediu(MsgWarning) "No AIF file selected."
    } else {
        Transcript $::ediu(MsgNote) [format "Loading AIF file \"%s\"." $::ediu(filename)]
        set txt $::widgets(sourceview)
        $txt configure -state normal
        $txt delete 1.0 end

        set f [open $::ediu(filename)]
        $txt insert end [read $f]
        Transcript $::ediu(MsgNote) [format "Scanning AIF file \"%s\" for sections." $::ediu(filename)]
        #ctext::addHighlightClass $txt diesections blue $sections
        ctext::addHighlightClassForRegexp $txt diesections blue $sectionRegExp
        $txt highlight 1.0 end
        $txt configure -state disabled
        close $f
        Transcript $::ediu(MsgNote) [format "Loaded AIF file \"%s\"." $::ediu(filename)]

        ##  Parse AIF file

        aif::parse $::ediu(filename)
        Transcript $::ediu(MsgNote) [format "Parsed AIF file \"%s\"." $::ediu(filename)]

        foreach i $aif::sections {
            puts [format "Section:  %s" $i]
            foreach j [aif::variables $i] {
                puts [format "  Variable:  %s" $j]
                puts [format "     Value:  %s" [aif::getvar $j $i]]
            }
        }

        ##  Load the DATABASE section
        set section [aif::variables DATABASE]

        foreach i $section {
            puts [format "-->  %s" $i]
            set ::die([string tolower $i]) [aif::getvar $i DATABASE]
        }

        ##  Make sure file format is AIF!

        if { $::die(type) != "AIF" } {
            Transcript $::ediu(MsgError) [format "File \"%s\" is not an AIF file." $::ediu(filename)]
            return
        }

        ##  Load the DIE section
        set section [aif::variables DIE]

        foreach i $section {
            set ::die([string tolower $i]) [aif::getvar $i DIE]
        }

        foreach {key, value} ::die {
            Transcript $::ediu(MsgNote) [format "Die \"%s\":  %s" [string toupper $key] $value]
        }
        
        ##  Extract die pad details from AIF file
#        ediuAIFPad
#        ediuAIFName
        ediuAIFSize

        ##  Extract pad details from AIF file
#        ediuPadGeomName
#        ediuPadGeomShape

        ##  Draw the Graphic View

#        ediuGraphicViewBuild
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
    set ::ediu(filename) $::ediu(Nothing)
    set txt $::widgets(sourceview)
    $txt configure -state normal
    $txt delete 1.0 end
    $txt configure -state disabled
    set cnvs $::widgets(graphicview)
    $cnvs delete all
    ediuUpdateStatus $::ediu(ready)
}

#
#  ediuSparsePinsFileOpen
#
#  Open a AIF file, read the contents into the
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
proc ediuSetupOpenPCB {} {
    ediuUpdateStatus $::ediu(busy)
    ##  Prompt the user for an Expedition database
    set ::ediu(targetPath) [tk_getOpenFile -filetypes {{PCB .pcb}}]

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
proc ediuSetupOpenLMC {} {
    ediuUpdateStatus $::ediu(busy)
    ##  Prompt the user for a Central Library database
    set ::ediu(targetPath) [tk_getOpenFile -filetypes {{LMC .lmc}}]

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
        if { $mode == "-closedatabase" } {
            $::ediu(pcbDoc) Save
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
#  ediuMapShapeToEnum
#
proc ediuMapShapeToEnum { shape } {
    if { $shape == "round" } {
        return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeRound)
    } elseif { $shape == "rectangle" } {
        return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeRectangle)
    }
    else {
        return $::ediu(Nothing)
    }
}

#
#  ediuBuildAIFPad
#
#  This subroutine will create a die pad based on the "pad_geom_shape"
#  section found in the AIF file.  It can optionally replace an existing
#  pad based on the second argument.
#
#  Pads are interesting in that can't simply be updated.  To change a pad
#  it must be deleted and then replaced.  A pad can't be deleted if it is
#  referenced by a padstack to that scenario must be handled.
#
proc ediuBuildAIFPad { { mode "-replace" } } {
    ediuUpdateStatus $::ediu(busy)
    set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

    ##  Make sure a Target library or design has been defined

    if {$::ediu(targetPath) == $::ediu(Nothing)} {
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

    set shape [ediuMapShapeToEnum $::padGeom(shape)]

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
    $newPad -set Width [expr $::PadstackEditorLib::EPsDBUnit(epsdbUnitUM)] [expr $::padGeom(width)]
    $newPad -set Height [expr $::PadstackEditorLib::EPsDBUnit(epsdbUnitUM)] [expr $::padGeom(height)]
    $newPad -set OriginOffsetX [expr $::PadstackEditorLib::EPsDBUnit(epsdbUnitUM)] [expr $::padGeom(offsetx)]
    $newPad -set OriginOffsetY [expr $::PadstackEditorLib::EPsDBUnit(epsdbUnitUM)] [expr $::padGeom(offsety)]

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
#  ediuBuildAIFPadstack
#
proc ediuBuildAIFPadstack { { mode "-replace" } } {
    ediuUpdateStatus $::ediu(busy)
    set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

    ##  Extract pad details from AIF file
    ediuPadGeomName
    ediuPadGeomShape

    ##  Make sure a Target library or design has been defined

    if {$::ediu(targetPath) == $::ediu(Nothing)} {
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
        $::ediu(cellEdtr) SaveActiveDatabase
        $::ediu(cellEdtr) Quit
        ##  Close the Expedition Database
        $::ediu(pcbDoc) Save
        $::ediu(pcbDoc) Close
        ##  Close Expedition
        $::ediu(pcbApp) Quit
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
        $::ediu(pcbDoc) Save
        $::ediu(pcbDoc) Close
        ##  Close Expedition
        $::ediu(pcbApp) Quit
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
    Transcript $::ediu(MsgNote) "Opening Expedition."

    set ::ediu(pcbApp) [::tcom::ref createobject "MGCPCB.ExpeditionPCBApplication"]
    [$::ediu(pcbApp) Gui] SuppressTrivialDialogs True

    #  Create a PCB document object
    $::ediu(pcbApp) Visible $::ediu(appVisible)

    # Open the database
    Transcript $::ediu(MsgNote) "Opening database for Expedition."

    set errorCode [catch {set ::ediu(pcbDoc) [$::ediu(pcbApp) \
        OpenDocument $::ediu(targetPath)] } errorMessage]
    if {$errorCode != 0} {
        Transcript $::ediu(MsgError) [format "API error \"%s\", build aborted." $errorMessage]
        return -code return 1
    }

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

#    set pads [aif::variables PADS]


#  ediuAIFName
#
#  Scan the AIF source file for the "die_name" section
#
proc ediuAIFName {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(dieName)]

    set txt $::widgets(sourceview)
    set dn [$txt search $::sections(dieName) 1.0 end]

    ##  Was the dieName found?

    if { $dn != $::ediu(Nothing)} {
        set dnl [lindex [split $dn .] 0]
        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(dieName) $dnl]

        ##  Need the text from the dieName line, drop the terminating semicolon
        set dnlt [$txt get $dnl.0 "$dnl.end - 1 chars"]

        ##  Extract the shape, height, and width from the dieNameShape
        set ::dieName(name) [lindex [split $dnlt] 1]
        set ::dieName(partition) [format "%s_die" $::dieName(name)]
        Transcript $::ediu(MsgNote) [format "Extracted die name (%s)." $::dieName(name)]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\"." $::sections(dieName)]
    }
}

#
#  ediuAIFSize
#
#  Scan the AIF source file for the "die_size" section
#
proc ediuAIFSize {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(dieSize)]

    set pads [aif::variables PADS]

    set txt $::widgets(sourceview)
    set ds [$txt search $::sections(dieSize) 1.0 end]

    ##  Was the dieSize section found?

    if { $ds != $::ediu(Nothing)} {
        set dsl [lindex [split $ds .] 0]
        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(dieSize) $dsl]

        ##  Need the text from the dieSize line, drop the terminating semicolon
        set dslt [$txt get $dsl.0 "$dsl.end - 1 chars"]

        ##  Extract the shape, height, and width from the dieSize
        set ::dieSize(width) [lindex [split $dslt] 1]
        set ::dieSize(height) [lindex [split $dslt] 2]
        Transcript $::ediu(MsgNote) [format "Extracted die size (height:  %s  width:  %s)." \
            $::dieSize(height) $::dieSize(width)]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\"." $::sections(dieName)]
    }
}

#
#  ediuAIFPad
#
#  Scan the AIF source file for the "die_pads" section
#  and extract all of the relevant die pad information.
#
proc ediuAIFPad {} {

    Transcript $::ediu(MsgNote) [format "Scanning AIF source for \"%s\"." $::sections(diePads)]

#    set txt $::widgets(sourceview)
#    set dp [$txt search $::sections(diePads) 1.0 end]
#
#    ##  Was the diePads section found?
#
#    if {$dp != $::ediu(Nothing)} {
#        set dpl [lindex [split $dp .] 0]
#        Transcript $::ediu(MsgNote) [format "Found section \"%s\" in AIF on line %s." $::sections(diePads) $dpl]
#
#        ##  Need the text from the padGeomName line, drop the terminating semicolon
#        set dplt [$txt get $dpl.0 "$dpl.end"]
#
#        ##  Extract the shape, height, and width from the padGeomShape
#        set ::diePads(count) [lindex [split $dplt] 1]
#        #set ::diePads(count) 25
#        Transcript $::ediu(MsgNote) [format "AIF has %s pads." $::diePads(count)]
#    } else {
#        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\", build aborted." $::sections(diePads)]
#        return
#    }
#
##    if { $::diePads(count) > 1000 } {
##        set ::diePads(count) 1000
##        Transcript $::ediu(MsgNote) [format "AIF now has %s pads." $::diePads(count)]
##    }

    set pads [aif::variables PADS]

    set ::diePads(count) [llength $pads]

    if {$::diePads(count) > 0} {
        Transcript $::ediu(MsgNote) [format "AIF contains %s %s." $::diePads(count) [ediuPlural $::diePads(count) "pad"]]
    } else {
        Transcript $::ediu(MsgError) [format "AIF does not contain section \"%s\", build aborted." $::sections(diePads)]
        return
    }

    foreach pad $pads {
        puts $pad
    }
    return

    ##  Need to extract pad information for the number of pads in the AIF file

    for {set i [expr $dpl + 1]} {$i <= [expr $dpl + $::diePads(count) + 1]} {incr i} {
        set dplt [$txt get $i.0 "$i.end"]
        #puts "$i-->  \"$dplt\""
        set dpltf [split $dplt]
        set pin [lindex $dpltf 0]
        set ::diePads($pin) $dplt
    }
}

#
#  ediuBuildAIFCell
#
proc ediuBuildAIFCell {} {
    ediuUpdateStatus $::ediu(busy)
    set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

    ##  Make sure a Target library or design has been defined

    if {$::ediu(targetPath) == $::ediu(Nothing)} {
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

        set ::ediu(cellEdtrPrtnName) $::dieName(partition)
        ediuChooseCellPartitionDialog
        #return

        #  Does the cell exist?  Before we can check, we need a
        #  partition.  There isn't a clear name as to what the
        #  partition name should be so we'll use the name of the
        #  cell as the name of the partition as well.

        #  Cannot access partition list when application is
        #  visible so if it is, hide it temporarily.
        set visbility $::ediu(appVisible)

        $::ediu(cellEdtr) Visible False
        set partitions [$::ediu(cellEdtrDb) Partitions]
        $::ediu(cellEdtr) Visible $visbility

        Transcript $::ediu(MsgNote) [format "Found %s cell %s." [$partitions Count] \
            [ediuPlural [$partitions Count] "partition"]]

        set pNames {}
        for {set i 1} {$i <= [$partitions Count]} {incr i} {
            set partition [$partitions Item $i]
            lappend pNames [$partition Name]
        }

        #  Does the partition exist?

        if { [lsearch $pNames $::dieName(partition)] == -1 } {
            Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for cell \"%s\"." \
                $::dieName(partition) $::dieName(name)]

            set partition [$::ediu(cellEdtrDb) NewPartition $::dieName(partition)]
        } else {
            Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for cell \"%s\"." \
                $::dieName(partition) $::dieName(name)]
            set partition [$partitions Item [expr [lsearch $pNames $::dieName(partition)] +1]]
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

    if { [lsearch $cNames $::dieName(name)] == -1 } {
        Transcript $::ediu(MsgNote) [format "Creating new cell \"%s\"." $::dieName(name)]

    } else {
        Transcript $::ediu(MsgNote) [format "Replacing existing cell \"%s.\"" $::dieName(name)]
        set cell [$cells Item [expr [lsearch $cNames $::dieName(name)] +1]]

        ##  Delete the cell and save the database.  The delete
        ##  isn't committed until the database is actually saved.

        $cell Delete
        $::ediu(cellEdtr) SaveActiveDatabase
    }


    ##  Build a new cell.  The first part of this is done in
    ##  in the Cell Editor which is part of the Library Manager.
    ##  The graphics and pins are then added using the Cell Editor
    ##  AddIn which sort of looks like a mini version of Expediiton.

    set newCell [$partition NewCell [expr $::CellEditorAddinLib::ECellDBCellType(ecelldbCellTypePackage)]]

    $newCell -set Name $::dieName(name)
    $newCell -set Description $::dieName(name)
    $newCell -set MountType [expr $::CellEditorAddinLib::ECellDBMountType(ecelldbMountTypeSurface)]
    #$newCell -set LayerCount [expr 2]
    $newCell -set PinCount [expr $::diePads(count)]
    puts [format "--->  ::diePads(count):  %s" $::diePads(count)]
    $newCell -set Units [expr $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)]
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
    
    #  Does the pad exist?
    
    set padstack [$::ediu(pdstkEdtrDb) FindPadstack $::padGeom(name)]
    
    #  Echo some information about what will happen.
    
    if {$padstack == $::ediu(Nothing)} {
        Transcript $::ediu(MsgError) \
            [format "Reference Padstack \"%s\" does not exist, build aborted." $::padGeom(name)]
        $cellEditor Close False

        if { $::ediu(mode) == $::ediu(designMode) } {
            ediuClosePadstackEditor -dontclosedatabase
        } else {
            ediuClosePadstackEditor
        }
        ediuCloseCellEditor

        ediuUpdateStatus $::ediu(ready)
        return
    }

    ##  To fix Tcom bug?
    if { $::ediu(mode) == $::ediu(designMode) } {
        ediuClosePadstackEditor -dontclosedatabase
    } else {
        ediuClosePadstackEditor
    }
    
    ##  Need to "Put" the padstack so it can be
    ##  referenced by the Cell Editor Add Pin process.

    set padstack [$cellEditor PutPadstack [expr 1] [expr 1] $::padGeom(name)]
        
    set i 1

    set pins [$cellEditor Pins]
    puts [format "-->  Array Size of pins:  %s" [$pins Count]]

    ##  Start Transations for performance reasons
    $cellEditor TransactionStart [expr $::MGCPCB::EPcbDRCMode(epcbDRCModeDRC)]

    ##  Loop over the collection of pins
    ::tcom::foreach pin $pins {
        ##  Split of the fields extracted from the die file

        set dpltf [split $::diePads($i)]
        set diePadFields(pinnum) [lindex $dpltf 0]
        set diePadFields(padname) [lindex $dpltf 1]
        set diePadFields(padx) [expr -1 * [lindex $dpltf 2]]
        set diePadFields(pady) [lindex $dpltf 3]
        set diePadFields(net) [lindex [split [lindex $dpltf 6] ,] 0]
    
        ## Need to handle sparse mode?

        set skip False

        if { $::ediu(sparseMode) } {
            if { [lsearch $::ediu(sparsepinnames) $diePadFields(pinnum)] == -1 } {
                set skip True
            }
        }

        if { $skip  == False } {
            Transcript $::ediu(MsgNote) [format "Placing pin \"%s\" using padstack \"%s\"." \
                $diePadFields(pinnum) $diePadFields(padname)]

            $pin CurrentPadstack $padstack

            set errorCode [catch {
            $pin Place [expr $diePadFields(padx)] [expr $diePadFields(pady)] [expr 0]
                } errorMessage]
            if {$errorCode != 0} {
                puts [format "Error:  %sPin:  %d  Hanldle:  %s" $errorMessage $i $pin]
    
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
    
    set x2 [expr $::dieSize(width) / 2]
    set x1 [expr -1 * $x2]
    set y2 [expr $::dieSize(height) / 2]
    set y1 [expr -1 * $y2]

    ##  PutPlacementOutline expects a Points Array which isn't easily
    ##  passed via Tcl.  Use the Utility object to create a Points Array
    ##  Object Rectangle.  A rectangle will have 5 points in the points
    ##  array - 5 is passed as the number of points to PutPlacemetOutline.

    set ptsArray [[$cellEditorDoc Utility] CreateRectXYR $x1 $y1 $x2 $y2]

    ##  Add the Placment Outline
    $cellEditor PutPlacementOutline [expr $::MGCPCB::EPcbSide(epcbSideMount)] 5 $ptsArray \
        [expr 0] [expr 0] $component [expr $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)]

    ##  Terminate transactions
    $cellEditor TransactionEnd True

    ##  Save edits and close the Cell Editor
    set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Saving new cell \"%s\" (%s)." $::dieName(name) $time]
    $cellEditor Save
    set time [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "New cell \"%s\" (%s) saved." $::dieName(name) $time]
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
#  ediuBuildAIFPDB
#
proc ediuBuildAIFPDB {} {
    ediuUpdateStatus $::ediu(busy)
    set ::ediu(sTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]

    ##  Make sure a Target library or design has been defined

    if {$::ediu(targetPath) == $::ediu(Nothing)} {
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

        if { [lsearch $pNames $::dieName(partition)] == -1 } {
            Transcript $::ediu(MsgNote) [format "Creating partition \"%s\" for part \"%s\"." \
                $::dieName(partition) $::dieName(name)]

            set partition [$::ediu(partEdtrDb) NewPartition $::dieName(partition)]
        } else {
            Transcript $::ediu(MsgNote) [format "Using existing partition \"%s\" for part \"%s\"." \
                $::dieName(partition) $::dieName(name)]
            set partition [$partitions Item [expr [lsearch $pNames $::dieName(partition)] +1]]
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

    if { [lsearch $cNames $::dieName(name)] == -1 } {
        Transcript $::ediu(MsgNote) [format "Creating new part \"%s\"." $::dieName(name)]

    } else {
        Transcript $::ediu(MsgNote) [format "Replacing existing part \"%s.\"" $::dieName(name)]
        set part [$parts Item [expr [lsearch $cNames $::dieName(name)] +1]]

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

    ##  Build a new part.  The first part of this is done in
    ##  in the PDB Editor which is part of the Library Manager.
    ##  The graphics and pins are then added using the PDB Editor
    ##  AddIn which sort of looks like a mini version of Expediiton.

    set newPart [$partition NewPart]

    $newPart -set Name $::dieName(name)
    $newPart -set Number $::dieName(name)
    $newPart -set Type [expr $::MGCPCBPartsEditor::EPDBPartType(epdbPartIC)]
    $newPart -set RefDesPrefix "U"
    $newPart -set Description "IC"

    #  Commit the Cell so it can be mapped.
    $newPart Commit

    #  Start doing the pin mapping
    set mapping [$newPart PinMapping]

    #  Does the part have any symbol references?

    puts "----> Mapping Sym Refs:  [[$mapping SymbolReferences] Count]"

    #  Need to add a symbol reference
    set symRef [$mapping PutSymbolReference $::dieName(name)]

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
    set cellRef [$mapping PutCellReference $::dieName(name) \
        $::MGCPCBPartsEditor::EPDBCellReferenceType(epdbCellRefTop) $::dieName(name)]

    ##  Define the gate - what to do about swap code?
    set gate [$mapping PutGate "gate_1" $::diePads(count) \
        $::MGCPCBPartsEditor::EPDBGateType(epdbGateTypeLogical)]

    ##  Add a pin defintition for each pin to the gate
    for {set i 1} {$i <= $::diePads(count)} {incr i} {
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
            [format "Symbol Reference \"%s\" is already defined." $::dieName(name)]

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
    for {set i 1} {$i <= $::diePads(count)} {incr i} {
        ##  Split of the fields extracted from the die file

        #set dpltf [split $::diePads($i)]
        #set diePadFields(pinnum) [lindex $dpltf 0]

        #Transcript $::ediu(MsgNote) [format "Adding pin \"%s\" to slot." $diePadFields(pinnum)]
        Transcript $::ediu(MsgNote) [format "Adding pin \"%s\" to slot." $i]

        #$slot PutPin [expr $i] [format "%s" $i] [format "P%s" $diePadFields(pinnum)]
        #$slot PutPin [expr $i] [format "%s" $i] [format "%s" $i]

        ## Need to handle sparse mode?
        if { ::ediu(sparseMode) } {
            if { $i in ::ediu(sparsepinnumbers) $i } {
                $slot PutPin [expr $i] [format "%s" $i]
            }
        } else {
            $slot PutPin [expr $i] [format "%s" $i]
        }
    }

    ##  Commit mapping and close the PDB editor

    Transcript $::ediu(MsgNote) [format "Saving PDB \"%s\"." $::dieName(name)]
    $mapping Commit
    Transcript $::ediu(MsgNote) [format "New PDB \"%s\" saved." $::dieName(name)]
    ediuClosePDBEditor

    ##  Report some time statistics
    set ::ediu(cTime) [clock format [clock seconds] -format "%m/%d/%Y %T"]
    Transcript $::ediu(MsgNote) [format "Start Time:  %s" $::ediu(sTime)]
    Transcript $::ediu(MsgNote) [format "Completion Time:  %s" $::ediu(cTime)]
http://www.apexcougarclub.org/2014/04/24/order-state-championship-spirit-wear/
    ediuUpdateStatus $::ediu(ready)
}

namespace eval aif {
    variable version 1.0

    variable sections [list DEFAULT]

    variable cursection DEFAULT
    variable DEFAULT;   # DEFAULT section
}

proc aif::sections {} {
    return $aif::sections
}

proc aif::variables {{section DEFAULT}} {
    return [array names ::aif::$section]
}

proc aif::add_section {str} {
    variable sections
    variable cursection

    set cursection [string trim $str \[\]]
    if {[lsearch -exact $sections $cursection] == -1} {
        lappend sections $cursection
        variable ::aif::${cursection}
    }
}

proc aif::setvar {varname value {section DEFAULT}} {
    variable sections
    if {[lsearch -exact $sections $section] == -1} {
      aif::add_section $section
    }
    set ::aif::${section}($varname) $value
}

proc aif::getvar {varname {section DEFAULT}} {
    variable sections
    if {[lsearch -exact $sections $section] == -1} {
        error "No such section: $section"
    }
    return [set ::aif::${section}($varname)]
}


proc aif::parse {filename} {
    variable sections
    variable cursection
    set line_no 0
    set fd [open $filename r]
    while {![eof $fd]} {
        set line [string trim [gets $fd] " "]
        incr line_no
        if {$line == ""} continue

        ##  Handle [NETLIST] section special case
        ##
        ##  Need to insert the "=" character into the net definitions
        ##  so the standard parser will pick each of them up.
        ##

        if { $cursection == "NETLIST" && [ regexp {^[[:alpha:][:alnum:]_]*\w} $line net ] } {
            puts [format "Net?  %s" $net]

            set line [format "%s=%s" [string trim $net] [string trimleft $line [string length $net]]]

        }

        ##  Look at each line and process sections versus section variables

        switch -regexp -- $line {
            ^;.* { }
            ^\\[.*\\]$ {
                aif::add_section $line
            }
            .*=.* {
                set pair [split $line =]
                set name [string trim [lindex $pair 0] " "]
                set value [string trim [lindex $pair 1] " "]
                aif::setvar $name $value $cursection
            } 
            default {
                #error "Error parsing $filename (line: $line_no): $line"
                Transcript $::ediu(MsgWarning) [format "Skipping line %d in AIF file \"%s\"." $line_no $::ediu(filename)]
                puts $line
            }
        }
    }
    close $fd
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

proc printArray { name } {
    upvar $name a
    foreach el [lsort [array names a]] {
        puts "$el = $a($el)"
    }
}

##  Main applicationhttp://codex.wordpress.org/HTTP_API
ediuInit
BuildGUI
ediuUpdateStatus $::ediu(ready)
Transcript $::ediu(MsgNote) "$::ediu(EDIU) ready."
#ediuChooseCellPartitionDialog

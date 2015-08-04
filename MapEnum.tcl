# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  MapEnum.tcl
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
#    07/20/2014 - Initial version.  Moved enumeration mapping to a
#                 separate file and namespace to ease code maintenance.
#

namespace eval MapEnum {
    #
    #  MapEnum::Shape
    #
    proc Shape { shape } {
        switch -exact -- [string toupper $shape] {
            "CIRCLE" -
            "ROUND" {
                return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeRound)
            }
            "SQ" -
            "SQUARE" {
                return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeSquare)
            }
            "RECT" -
            "RECTANGLE" {
                return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeRectangle)
            }
            "OBLONG" -
            "OBROUND" {
                return $::PadstackEditorLib::EPsDBPadShape(epsdbPadShapeOblong)
            }
            default {
                return $xAIF::Settings(Nothing)
            }
        }
    }
    
    #
    #  MapEnum::Units
    #
    proc Units { units { type "pad" } } {
        if { $type == "pad" } {
            switch -exact -- [string toupper $units] {
                "UM" {
                    return $::PadstackEditorLib::EPsDBUnit(epsdbUnitUM)
                }
                "MM" {
                    return $::PadstackEditorLib::EPsDBUnit(epsdbUnitMM)
                }
                "INCH" {
                    return $::PadstackEditorLib::EPsDBUnit(epsdbUnitInch)
                }
                "MIL" {
                    return $::PadstackEditorLib::EPsDBUnit(epsdbUnitMils)
                }
                default {
                    return $xAIF::Settings(Nothing)
                }
            }
        } elseif { $type == "cell" } {
            switch -exact -- [string toupper $units] {
                "UM" {
                    return $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitUM)
                }
                "MM" {
                    return $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitMM)
                }
                "INCH" {
                    return $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitInch)
                }
                "MIL" {
                    return $::CellEditorAddinLib::ECellDBUnit(ecelldbUnitMils)
                }
                default {
                    return $xAIF::Settings(Nothing)
                }
            }
        } elseif { $type == "pcb" } {
            switch -exact -- [string toupper $units] {
                "UM" {
                    return $::MGCPCB::EPcbUnit(epcbUnitUM)
                }
                "MM" {
                    return $::MGCPCB::EPcbUnit(epcbUnitMM)
                }
                "INCH" {
                    return $::MGCPCB::EPcbUnit(epcbUnitInch)
                }
                "MIL" {
                    return $::MGCPCB::EPcbUnit(epcbUnitMils)
                }
                default {
                    return $xAIF::Settings(Nothing)
                }
            }
        } else {
            return $xAIF::Settings(Nothing)
        }
    }

    #
    #  MapEnum::ToUnits
    #
    proc ToUnits { enum } {
        if { $enum == [expr $::MGCPCB::EPcbUnit(epcbUnitUM)] } {
            return "UM"
        } elseif { $enum == [expr $::MGCPCB::EPcbUnit(epcbUnitMM)] } {
            return "MM"
        } elseif { [expr $::MGCPCB::EPcbUnit(epcbUnitInch)] } {
            return "INCH"
        } elseif { [expr $::MGCPCB::EPcbUnit(epcbUnitMils)] } {
            return "MIL"
        } else {
            puts $::MGCPCB::EPcbUnit(epcbUnitInch)
            GUI::Transcript -severity warning -msg [format "Unknown units (%s)." $enum]

            return $xAIF::Settings(Nothing)
        }
    }
}

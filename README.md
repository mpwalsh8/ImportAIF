Xpedition xAIF
=========

Xpedition xAIF is a utility, written in [Tcl/Tk](http://www.tcl.tk/about/ "Tcl/Tk"), to import AIF files into Mentor Graphics Xpedition xPCB layout tool.

Xpedition xAIF works in conjunction with Library Manager and Xpedition xPCB to process the information contained in an AIF file and generate the necessary library and design elements necessary to implement an IC Package design.

The [AIF Format](http://artwork.com/package/aif/index.htm "Die and Package Database Format") is a pseudo industry standard ASCII file format created by [Artwork Conversion Services](http://www.artwork.com "Artwork Conversion Services") which is used for sharing package design and implementation tools.

The AIF specification is documented on the ACS web site:
What's in an AIF File?
Multi Die AIF

Examples
-
Unfortunately there are not many example AIF files to use as a reference.  In fact, there is [only one on the ACS web site](http://artwork.com/package/aif/sample_aif_files.htm "Sample AIF File")!  Here are a few  which have been used for development and testing:
- [Demo1.aif](https://github.com/mpwalsh8/xAIF/blob/master/data/Demo1.aif "Demo AIF #1")
- [Demo2.aif](https://github.com/mpwalsh8/xAIF/blob/master/data/Demo2.aif "Demo AIF #2")
- [Demo3.aif](https://github.com/mpwalsh8/xAIF/blob/master/data/Demo3.aif "Demo AIF #3")

Requirements
-
Mentor Graphics only supports Tcl 8.4.x with Xpedition xPCB and Library Manager.  Xpedition xAIF is developed on Windows using [ActiveTcl](http://www.activestate.com/activetcl/downloads) 8.4.20.0.  The ActiveTcl distribution includes many optional Tcl/Tk modules so no additional installation and/or configuration work is required.

Installation and Operation
-
Xpedition xAIF is currently a work-in-progress.  Download (or clone) Xpedition xAIF from GitHub.  Invoke the application using Wish to open xAIF.tcl (the main entry point). 

The full AIF specification has not been implemented.  Unsupported keywords in the AIF file are noted in red text when viewing the source.

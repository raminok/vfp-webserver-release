*=========================================================
* build_demo.prg - builds demo.app from demo_main.prg + demo_handlers.prg
* Run in the VFP IDE:   DO Apps\AppDemo\build_demo.prg
*=========================================================
LOCAL cOldDir
cOldDir = SET("DEFAULT") + CURDIR()
CD (JUSTPATH(SYS(16)))

* The first file becomes the MAIN program of the project.
IF FILE("demo.pjx")
    ERASE demo.pjx
    ERASE demo.pjt
ENDIF
IF FILE("demo.app")
    ERASE demo.app          && fails if a running server still uses it: Exit it first
ENDIF
IF FILE("demo.err")
    ERASE demo.err
ENDIF
BUILD PROJECT demo FROM demo_main, demo_handlers
BUILD APP demo FROM demo RECOMPILE

IF FILE("demo.app")
    ? "demo.app built in " + FULLPATH("demo.app")
ELSE
    ? "Build failed - see demo.err"
ENDIF
CD (cOldDir)

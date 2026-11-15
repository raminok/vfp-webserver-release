*=========================================================
* demo_handlers.prg - second file of demo.app
*=========================================================

DEFINE CLASS DemoAppHandler AS VFPWSHandler

    PROCEDURE Ping
        LOCAL lo
        lo = THIS.MakeObject("pong,source,time")
        lo.pong = .T.
        lo.source = "demo_handlers.prg inside demo.app"
        lo.time = DATETIME()
        RETURN lo
    ENDPROC

    PROCEDURE Info
        LOCAL lo
        lo = THIS.MakeObject("app_file,app_folder,data_example,helper")
        lo.app_file = THIS.oApp.cAppFile
        lo.app_folder = THIS.oApp.cAppFolder
        lo.data_example = AppPath("Data\example.dbf")
        lo.helper = Demo_Helper()
        RETURN lo
    ENDPROC

ENDDEFINE


PROCEDURE Demo_Helper
    * A plain procedure from the second file.
    RETURN "Demo_Helper() from demo_handlers.prg"
ENDPROC

*=========================================================
* demo_main.prg - MAIN program of demo.app (two-file .app example)
*
* Build:  DO build_demo.prg   (in this folder, in the VFP IDE)
* Use:    Settings > Application:  Apps\AppDemo\demo.app
*         Stop / Start the server, open /docs
*
*   GET /demo-app/ping          answered by a class in demo_handlers.prg
*   GET /demo-app/info          where the application runs from
*=========================================================

* The server runs:  DO demo.app WITH toApp
LPARAMETERS toApp
IF VARTYPE(toApp) <> "O"
    RETURN
ENDIF
* Every file of the .app that holds classes or procedures:
SET PROCEDURE TO demo_main, demo_handlers ADDITIVE
ConfigureApp(toApp)
RETURN


PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loRoute

    toApp.RequireVersion("0.3")
    toApp.cTitle = "Demo .app"
    toApp.cDescription = "Two source files built into one demo.app."

    loRoute = toApp.Get("/demo-app/ping", "DemoAppHandler.Ping")
    loRoute.Summary("Handler class from demo_handlers.prg")
    loRoute.Tags("Demo app")

    loRoute = toApp.Get("/demo-app/info", "DemoAppHandler.Info")
    loRoute.Summary("Application file and folder")
    loRoute.Tags("Demo app")
ENDPROC

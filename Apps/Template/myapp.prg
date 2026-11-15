*=========================================================
* myapp.prg - TEMPLATE for a VFPWebServer application
*
* Copy this folder (Apps\Template) to Apps\<YourApp>, rename the file,
* and write your routes and handlers below.
*
* The server runs only COMPILED applications:
*
*   A) One file (.fxp)
*        COMPILE myapp.prg                     ->  myapp.fxp
*        Settings > Application:  Apps\<YourApp>\myapp.fxp
*
*   B) Several files (.app)
*        Put myapp.prg and your other .prg files in a project,
*        set myapp.prg as MAIN, Build > Application (.app)
*        Settings > Application:  Apps\<YourApp>\myapp.app
*        List your other files in the SET PROCEDURE line below.
*
* After every change: compile (or build) again, then Stop / Start the
* server. The application is loaded each time the server starts.
*
* Data files: AppPath("Data\mytable.dbf") = this application's folder.
* Full guide: README_FRAMEWORK.md
*=========================================================

*---------------------------------------------------------
* Used only when this file is the MAIN program of an .app
* (the server runs:  DO myapp.app WITH toApp).
* For an .fxp the server calls ConfigureApp directly.
*---------------------------------------------------------
LPARAMETERS toApp
IF VARTYPE(toApp) <> "O"
    RETURN          && not started by VFPWebServer
ENDIF
* This file + every other .prg of the .app that has classes or procedures:
SET PROCEDURE TO myapp ADDITIVE
ConfigureApp(toApp)
RETURN


*---------------------------------------------------------
* Declarations: models and routes
*---------------------------------------------------------
PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loModel, loRoute

    toApp.RequireVersion("0.3")          && minimum VFPWebServer version
    toApp.cTitle = "My API"
    toApp.cDescription = "Describe your API here (shown in /docs)."

    * A model = the shape of a JSON body
    * loModel = toApp.Model("ThingIn")
    * loModel.Field("name", "str", .T., .NULL., "min_length=1;max_length=50")

    * GET /hello/{name}
    loRoute = toApp.Get("/hello/{name}", "MyHandler.Hello")
    loRoute.Summary("Say hello")
    loRoute.Path("name", "str", "max_length=30")
ENDPROC


*---------------------------------------------------------
* Handlers: parameters arrive as LPARAMETERS in declaration order
*---------------------------------------------------------
DEFINE CLASS MyHandler AS VFPWSHandler

    PROCEDURE Hello
        LPARAMETERS tcName
        LOCAL loAnswer
        loAnswer = THIS.MakeObject("message")
        loAnswer.message = "Hello " + tcName
        RETURN loAnswer
    ENDPROC

ENDDEFINE


*---------------------------------------------------------
* Helpers: give them a prefix to avoid name clashes (My_...)
*---------------------------------------------------------

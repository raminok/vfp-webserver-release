*=========================================================
* parts_app.prg - BACK END: parts lookup API for VFPWebServer
*
*   GET /parts/{code}               one part by its code (404 when missing)
*   GET /parts?search=bolt&limit=20 parts whose name contains the text
*
* Setup:
*   1. Change the three #DEFINE lines to your table and field names.
*      PARTS_TABLE: relative to this file's folder, or a full path.
*   2. COMPILE parts_app.prg   ->   parts_app.fxp
*      (#DEFINE values are fixed at compile time: compile after changes)
*   3. Settings > Application: Apps\Samples\parts_app.fxp
*   4. Stop / Start the server, open http://localhost:8080/docs
*=========================================================

* These are NOT request values: they tell the program where the data is.
#DEFINE PARTS_TABLE        "Data\parts.dbf"   && your table
#DEFINE PARTS_FIELD_CODE   "code"             && COLUMN that holds the part code
#DEFINE PARTS_FIELD_NAME   "name"             && COLUMN searched by ?search=


PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loRoute

    toApp.cTitle = "Parts API"
    toApp.cDescription = "Find parts in " + PARTS_TABLE

    * GET /parts/A100
    loRoute = toApp.Get("/parts/{code}", "PartsHandler.GetPart")
    loRoute.Summary("Find one part by its code")
    loRoute.Tags("Parts")
    loRoute.Path("code", "str", "min_length=1;max_length=30;description=Part code")

    * GET /parts?search=bolt&limit=20
    loRoute = toApp.Get("/parts", "PartsHandler.SearchParts")
    loRoute.Summary("Search parts by name")
    loRoute.Tags("Parts")
    loRoute.Query("search", "str", .F., "", "max_length=50;description=Text in the name")
    loRoute.Query("limit", "int", .F., 20, "ge=1;le=200;description=Maximum rows")
ENDPROC


DEFINE CLASS PartsHandler AS VFPWSHandler

    PROCEDURE GetPart
        LPARAMETERS tcCode
        LOCAL cField, loPart
        Parts_Open()
        cField = PARTS_FIELD_CODE
        * tcCode = the VALUE from the URL (/parts/A100), cField = the COLUMN.
        * TRANSFORM lets the code column be Character or Numeric.
        SELECT * FROM parts ;
            WHERE UPPER(ALLTRIM(TRANSFORM(&cField))) == UPPER(ALLTRIM(tcCode)) ;
            INTO CURSOR curPart
        IF _TALLY = 0
            USE IN curPart
            THROW HTTPException(404, "Part " + ALLTRIM(tcCode) + " not found")
        ENDIF
        loPart = THIS.Row("curPart")       && record -> JSON object
        USE IN curPart
        RETURN loPart
    ENDPROC

    PROCEDURE SearchParts
        LPARAMETERS tcSearch, tnLimit
        LOCAL cField, loList
        Parts_Open()
        cField = PARTS_FIELD_NAME
        IF EMPTY(tcSearch)
            SELECT * FROM parts ORDER BY &cField INTO CURSOR curParts
        ELSE
            SELECT * FROM parts ;
                WHERE ATC(ALLTRIM(tcSearch), &cField) > 0 ;
                ORDER BY &cField INTO CURSOR curParts
        ENDIF
        loList = CREATEOBJECT("Collection")
        SELECT curParts
        SCAN WHILE loList.Count < tnLimit
            loList.Add(THIS.Row("curParts"))
        ENDSCAN
        USE IN curParts
        RETURN loList                      && Collection -> JSON array
    ENDPROC
ENDDEFINE


PROCEDURE Parts_Open
    LOCAL cTable
    IF USED("parts")
        RETURN
    ENDIF
    cTable = AppPath(PARTS_TABLE)
    IF NOT FILE(cTable)
        THROW HTTPException(503, "Parts table not found on the server")
    ENDIF
    * SHARED AGAIN: your desktop program can keep using the table
    USE (cTable) IN 0 SHARED AGAIN ALIAS parts
ENDPROC

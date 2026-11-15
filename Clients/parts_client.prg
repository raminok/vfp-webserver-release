*=========================================================
* parts_client.prg - front end example: a VFP program that calls the
* Parts API (Apps\Samples\parts_app) with VFPWSClient.prg.
*
*   DO parts_client WITH "A100"           && one part by code
*   DO parts_client WITH "", "bolt"       && search, result in a cursor
*=========================================================

LPARAMETERS tcCode, tcSearch

#DEFINE API_URL  "http://localhost:8080"
#DEFINE API_KEY  ""          && "vfpws_..." when the server requires a key

LOCAL loApi, loPart, loList, loQuery

SET PROCEDURE TO VFPWSClient ADDITIVE
ACTIVATE SCREEN
CLEAR

loApi = CREATEOBJECT("VFPWSHttpClient", API_URL, API_KEY)

*--- One part:  GET /parts/{code} --------------------------
IF NOT EMPTY(tcCode)
    loPart = loApi.Get("/parts/" + VFPWS_UrlEncode(ALLTRIM(tcCode)))
    IF loApi.lOk
        ? "Part found:"
        ShowObject(loPart)
    ELSE
        ? "Error " + TRANSFORM(loApi.nStatus) + ": " + loApi.cError
    ENDIF
ENDIF

*--- Search:  GET /parts?search=...&limit=20 -----------------
IF NOT EMPTY(tcSearch)
    loQuery = CREATEOBJECT("Empty")
    ADDPROPERTY(loQuery, "search", tcSearch)
    ADDPROPERTY(loQuery, "limit", 20)
    loList = loApi.Get("/parts", loQuery)
    IF loApi.lOk
        ? TRANSFORM(VFPWS_ToCursor(loList, "curParts")) + " part(s) in cursor curParts"
        BROWSE NOWAIT
    ELSE
        ? "Error " + TRANSFORM(loApi.nStatus) + ": " + loApi.cError
    ENDIF
ENDIF
RETURN


PROCEDURE ShowObject
    * Prints every field of an object received from the API.
    LPARAMETERS toObj
    LOCAL cOrder, i, cName
    cOrder = toObj._vfpws_order
    FOR i = 1 TO GETWORDCOUNT(cOrder, ",")
        cName = GETWORDNUM(cOrder, i, ",")
        ? PADR(cName, 15) + ": " + TRANSFORM(EVALUATE("toObj." + cName))
    ENDFOR
ENDPROC

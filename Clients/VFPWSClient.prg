*=========================================================
* VFPWSClient.prg - VFPWebServer Client Library 0.3.0
* Copyright (c) 2026 Ramin Orak, Aryana Software
*
* HTTP + JSON for Visual FoxPro 9 applications that call
* a VFPWebServer API (or any JSON web API).
*
*   SET PROCEDURE TO VFPWSClient ADDITIVE
*
*   loApi = CREATEOBJECT("VFPWSHttpClient", "http://192.168.1.10:8080", "vfpws_...")
*   loPart = loApi.Get("/parts/A100")
*   IF loApi.lOk
*       ? loPart.name
*   ELSE
*       ? loApi.nStatus, loApi.cError
*   ENDIF
*
* Contents
*   VFPWSHttpClient   Get, Post, Put, Patch, Delete, PostForm, Download
*   VFPWSJson         Parse (JSON -> objects / Collections), Stringify
*   VFPWS_ToCursor    Collection of objects -> cursor (for grids, reports)
*   VFPWS_ToUtf8, VFPWS_FromUtf8, VFPWS_UrlEncode
*
* Requirements: Visual FoxPro 9, Windows (WinHttp). Persian / Arabic text
* needs the matching Windows code page (1256).
*=========================================================

#DEFINE VFPWS_MAX_DEPTH 64
#DEFINE VFPWS_CLIENT_VERSION "0.3.0"


*=========================================================
* HTTP client
*=========================================================

DEFINE CLASS VFPWSHttpClient AS Custom
    * Settings
    cBaseUrl = ""          && "http://server:8080" (no trailing "/")
    cApiKey = ""           && sent as X-Api-Key when not empty
    nTimeout = 30          && seconds for sending / receiving
    lRaiseErrors = .F.     && .T.: THROW on failure instead of returning .NULL.

    * Result of the last call
    lOk = .F.              && .T. for status 200-299
    nStatus = 0            && HTTP status (0 = server not reached)
    cError = ""            && error text when lOk = .F.
    cResponse = ""         && answer as text (code page of this computer)
    cContentType = ""      && Content-Type of the answer
    uResult = .NULL.       && same value the method returned

    oHeaders = .NULL.      && extra request headers (SetHeader)

    PROCEDURE Init
        LPARAMETERS tcBaseUrl, tcApiKey
        THIS.oHeaders = CREATEOBJECT("Collection")
        IF VARTYPE(tcBaseUrl) = "C"
            THIS.cBaseUrl = ALLTRIM(tcBaseUrl)
            DO WHILE RIGHT(THIS.cBaseUrl, 1) == "/"
                THIS.cBaseUrl = LEFT(THIS.cBaseUrl, LEN(THIS.cBaseUrl) - 1)
            ENDDO
        ENDIF
        IF VARTYPE(tcApiKey) = "C"
            THIS.cApiKey = ALLTRIM(tcApiKey)
        ENDIF
    ENDPROC

    PROCEDURE SetHeader
        * Extra header for every following request; empty value removes it.
        LPARAMETERS tcName, tcValue
        LOCAL cKey
        cKey = LOWER(ALLTRIM(tcName))
        IF THIS.oHeaders.GetKey(cKey) > 0
            THIS.oHeaders.Remove(cKey)
        ENDIF
        IF NOT EMPTY(tcValue)
            THIS.oHeaders.Add(ALLTRIM(tcName) + ": " + TRANSFORM(tcValue), cKey)
        ENDIF
    ENDPROC

    *-----------------------------------------------------
    * Requests. toQuery (optional): object or keyed Collection
    * -> ?name=value&... ; tuBody: object / Collection (sent as
    * JSON) or a JSON string.
    *-----------------------------------------------------

    PROCEDURE Get
        LPARAMETERS tcPath, toQuery
        RETURN THIS.Send("GET", THIS.BuildUrl(tcPath, toQuery), "", "")
    ENDPROC

    PROCEDURE Delete
        LPARAMETERS tcPath, toQuery
        RETURN THIS.Send("DELETE", THIS.BuildUrl(tcPath, toQuery), "", "")
    ENDPROC

    PROCEDURE Post
        LPARAMETERS tcPath, tuBody
        RETURN THIS.Send("POST", THIS.BuildUrl(tcPath), THIS.BodyText(tuBody), ;
            "application/json; charset=utf-8")
    ENDPROC

    PROCEDURE Put
        LPARAMETERS tcPath, tuBody
        RETURN THIS.Send("PUT", THIS.BuildUrl(tcPath), THIS.BodyText(tuBody), ;
            "application/json; charset=utf-8")
    ENDPROC

    PROCEDURE Patch
        LPARAMETERS tcPath, tuBody
        RETURN THIS.Send("PATCH", THIS.BuildUrl(tcPath), THIS.BodyText(tuBody), ;
            "application/json; charset=utf-8")
    ENDPROC

    PROCEDURE PostForm
        * HTML form fields (application/x-www-form-urlencoded).
        LPARAMETERS tcPath, toFields
        RETURN THIS.Send("POST", THIS.BuildUrl(tcPath), THIS.EncodePairs(toFields), ;
            "application/x-www-form-urlencoded")
    ENDPROC

    PROCEDURE Download
        * Saves the answer (CSV, PDF, image ...) to a file. Returns .T./.F.
        LPARAMETERS tcPath, tcLocalFile, toQuery
        LOCAL cRaw, loError, loJson
        cRaw = THIS.Execute("GET", THIS.BuildUrl(tcPath, toQuery), "", "")
        IF NOT THIS.lOk AND THIS.nStatus > 0
            THIS.cResponse = VFPWS_FromUtf8(cRaw)
            loJson = CREATEOBJECT("VFPWSJson")
            THIS.cError = THIS.ErrorText(IIF("json" $ LOWER(THIS.cContentType), ;
                loJson.Parse(THIS.cResponse), THIS.cResponse))
        ENDIF
        IF THIS.lOk
            TRY
                STRTOFILE(cRaw, tcLocalFile)
            CATCH TO loError
                THIS.lOk = .F.
                THIS.cError = "Cannot write " + tcLocalFile + ": " + loError.Message
            ENDTRY
        ENDIF
        THIS.uResult = THIS.lOk
        THIS.Finish()
        RETURN THIS.lOk
    ENDPROC

    *-----------------------------------------------------
    * Core
    *-----------------------------------------------------

    PROCEDURE Send
        * Returns the parsed JSON (object / Collection / value), the text
        * of a non-JSON answer, or .NULL. on failure (see lOk, cError).
        * 204 No Content: .NULL. with lOk = .T.
        LPARAMETERS tcMethod, tcUrl, tcBody, tcContentType
        LOCAL cRaw, loJson, luAnswer
        cRaw = THIS.Execute(tcMethod, tcUrl, tcBody, tcContentType)
        THIS.uResult = .NULL.
        IF THIS.nStatus = 0
            THIS.Finish()
            RETURN .NULL.
        ENDIF

        THIS.cResponse = VFPWS_FromUtf8(cRaw)
        luAnswer = .NULL.
        IF NOT EMPTY(THIS.cResponse)
            IF "json" $ LOWER(THIS.cContentType)
                loJson = CREATEOBJECT("VFPWSJson")
                luAnswer = loJson.Parse(THIS.cResponse)
                IF THIS.lOk AND NOT EMPTY(loJson.cError)
                    THIS.lOk = .F.
                    THIS.cError = "Invalid JSON in the answer: " + loJson.cError
                ENDIF
            ELSE
                luAnswer = THIS.cResponse
            ENDIF
        ENDIF

        IF THIS.lOk
            THIS.uResult = luAnswer
        ELSE
            IF EMPTY(THIS.cError)
                THIS.cError = THIS.ErrorText(luAnswer)
            ENDIF
        ENDIF
        THIS.Finish()
        RETURN THIS.uResult
    ENDPROC

    PROCEDURE Execute
        * Sends the request; returns the raw answer bytes.
        LPARAMETERS tcMethod, tcUrl, tcBody, tcContentType
        LOCAL loHttp, loError, cRaw, i, cHeader, nMs
        THIS.lOk = .F.
        THIS.nStatus = 0
        THIS.cError = ""
        THIS.cResponse = ""
        THIS.cContentType = ""
        cRaw = ""
        nMs = MAX(1, THIS.nTimeout) * 1000

        TRY
            loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
            loHttp.SetTimeouts(5000, 5000, nMs, nMs)
            loHttp.Open(tcMethod, tcUrl, .F.)
            loHttp.SetRequestHeader("Accept", "application/json, */*")
            IF NOT EMPTY(THIS.cApiKey)
                loHttp.SetRequestHeader("X-Api-Key", THIS.cApiKey)
            ENDIF
            FOR i = 1 TO THIS.oHeaders.Count
                cHeader = THIS.oHeaders.Item(i)
                loHttp.SetRequestHeader(GETWORDNUM(cHeader, 1, ":"), ;
                    ALLTRIM(SUBSTR(cHeader, AT(":", cHeader) + 1)))
            ENDFOR
            IF EMPTY(tcBody)
                loHttp.Send()
            ELSE
                loHttp.SetRequestHeader("Content-Type", tcContentType)
                loHttp.Send(VFPWS_ToUtf8(tcBody))
            ENDIF
            THIS.nStatus = loHttp.Status
            cRaw = loHttp.ResponseBody
            IF VARTYPE(cRaw) <> "C"
                cRaw = ""
            ENDIF
            THIS.cContentType = loHttp.GetResponseHeader("Content-Type")
        CATCH TO loError
            IF THIS.nStatus = 0
                THIS.cError = "Server not reachable (" + tcUrl + "): " + loError.Message
            ENDIF
        ENDTRY
        loHttp = .NULL.

        THIS.lOk = BETWEEN(THIS.nStatus, 200, 299)
        RETURN cRaw
    ENDPROC

    PROCEDURE Finish
        LOCAL cMessage
        IF NOT THIS.lOk AND THIS.lRaiseErrors
            cMessage = "HTTP " + TRANSFORM(THIS.nStatus) + ": " + THIS.cError
            ERROR (cMessage)
        ENDIF
    ENDPROC

    PROCEDURE ErrorText
        * {"detail":"..."}  or  422 {"detail":[{"loc":[...],"msg":"..."}]}
        LPARAMETERS tuAnswer
        LOCAL luDetail, loFirst, cWhere, luPart
        IF VARTYPE(tuAnswer) <> "O" OR NOT PEMSTATUS(tuAnswer, "detail", 5)
            RETURN "HTTP " + TRANSFORM(THIS.nStatus) + ;
                IIF(VARTYPE(tuAnswer) = "C" AND NOT EMPTY(tuAnswer), ": " + LEFT(tuAnswer, 200), "")
        ENDIF
        luDetail = tuAnswer.detail
        IF VARTYPE(luDetail) = "C"
            RETURN luDetail
        ENDIF
        IF VARTYPE(luDetail) = "O" AND VFPWS_BaseClass(luDetail) == "COLLECTION" AND luDetail.Count > 0
            loFirst = luDetail.Item(1)
            cWhere = ""
            IF PEMSTATUS(loFirst, "loc", 5) AND VARTYPE(loFirst.loc) = "O"
                FOR EACH luPart IN loFirst.loc
                    cWhere = cWhere + IIF(EMPTY(cWhere), "", ".") + TRANSFORM(luPart)
                ENDFOR
            ENDIF
            RETURN IIF(PEMSTATUS(loFirst, "msg", 5), TRANSFORM(loFirst.msg), "Invalid request") + ;
                IIF(EMPTY(cWhere), "", " (" + cWhere + ")") + ;
                IIF(luDetail.Count > 1, " and " + TRANSFORM(luDetail.Count - 1) + " more", "")
        ENDIF
        RETURN "HTTP " + TRANSFORM(THIS.nStatus)
    ENDPROC

    *-----------------------------------------------------
    * Helpers
    *-----------------------------------------------------

    PROCEDURE BuildUrl
        LPARAMETERS tcPath, toQuery
        LOCAL cUrl, cQuery
        cUrl = ALLTRIM(TRANSFORM(tcPath))
        IF NOT LOWER(LEFT(cUrl, 4)) == "http"
            cUrl = THIS.cBaseUrl + IIF(LEFT(cUrl, 1) == "/", "", "/") + cUrl
        ENDIF
        IF VARTYPE(toQuery) = "O"
            cQuery = THIS.EncodePairs(toQuery)
            IF NOT EMPTY(cQuery)
                cUrl = cUrl + IIF("?" $ cUrl, "&", "?") + cQuery
            ENDIF
        ENDIF
        RETURN cUrl
    ENDPROC

    PROCEDURE BodyText
        LPARAMETERS tuBody
        LOCAL loJson
        DO CASE
            CASE VARTYPE(tuBody) = "O"
                loJson = CREATEOBJECT("VFPWSJson")
                RETURN loJson.Stringify(tuBody)
            CASE VARTYPE(tuBody) = "C"
                RETURN tuBody
        ENDCASE
        RETURN ""
    ENDPROC

    PROCEDURE EncodePairs
        * Object or keyed Collection -> name=value&name=value (.NULL. skipped)
        LPARAMETERS toPairs
        LOCAL cOut, i, cNames, nCount, cName, loJson
        LOCAL ARRAY laNames[1]
        cOut = ""
        IF VARTYPE(toPairs) <> "O"
            RETURN ""
        ENDIF
        IF VFPWS_BaseClass(toPairs) == "COLLECTION"
            FOR i = 1 TO toPairs.Count
                IF NOT ISNULL(toPairs.Item(i))
                    cOut = cOut + IIF(EMPTY(cOut), "", "&") + VFPWS_UrlEncode(toPairs.GetKey(i)) + ;
                        "=" + VFPWS_UrlEncode(THIS.PairValue(toPairs.Item(i)))
                ENDIF
            ENDFOR
            RETURN cOut
        ENDIF
        loJson = CREATEOBJECT("VFPWSJson")
        cNames = loJson.PropertyNames(toPairs)
        nCount = ALINES(laNames, CHRTRAN(cNames, ",", CHR(13)), 1 + 4, CHR(13))
        FOR i = 1 TO nCount
            cName = laNames[i]
            IF PEMSTATUS(toPairs, cName, 5) AND NOT ISNULL(EVALUATE("toPairs." + cName))
                cOut = cOut + IIF(EMPTY(cOut), "", "&") + VFPWS_UrlEncode(LOWER(cName)) + ;
                    "=" + VFPWS_UrlEncode(THIS.PairValue(EVALUATE("toPairs." + cName)))
            ENDIF
        ENDFOR
        RETURN cOut
    ENDPROC

    PROCEDURE PairValue
        LPARAMETERS tuValue
        DO CASE
            CASE VARTYPE(tuValue) = "L"
                RETURN IIF(tuValue, "true", "false")
            CASE VARTYPE(tuValue) = "D"
                RETURN TRANSFORM(DTOS(tuValue), "@R 9999-99-99")
            CASE VARTYPE(tuValue) = "T"
                RETURN TTOC(tuValue, 3)
            CASE INLIST(VARTYPE(tuValue), "N", "Y")
                RETURN CHRTRAN(ALLTRIM(TRANSFORM(tuValue)), SET("POINT"), ".")
        ENDCASE
        RETURN ALLTRIM(TRANSFORM(tuValue))
    ENDPROC
ENDDEFINE


*=========================================================
* Collection of objects -> cursor
*=========================================================

PROCEDURE VFPWS_ToCursor
    * Builds a cursor from a list returned by the API (or one object):
    *   loList = loApi.Get("/parts", loQuery)
    *   VFPWS_ToCursor(loList, "curParts")
    *   THISFORM.grdParts.RecordSource = "curParts"
    * Column types follow the values: L, I (whole numbers), B (decimals),
    * C (text, up to 254) or M (longer text). Nested objects and lists are
    * stored as JSON text. Returns the number of rows, -1 on error.
    LPARAMETERS toList, tcAlias
    LOCAL loRows, loRow, loJson, cNames, nFields, i, j, cName, luValue, cType
    LOCAL cFields, nOldArea
    LOCAL ARRAY laNames[1], laType[1], laLen[1]

    IF VARTYPE(toList) <> "O" OR VARTYPE(tcAlias) <> "C" OR EMPTY(tcAlias)
        RETURN -1
    ENDIF
    loJson = CREATEOBJECT("VFPWSJson")
    IF VFPWS_BaseClass(toList) == "COLLECTION"
        loRows = toList
    ELSE
        loRows = CREATEOBJECT("Collection")
        loRows.Add(toList)
    ENDIF

    * Columns: names of the first object, types from all rows
    cNames = ""
    FOR i = 1 TO loRows.Count
        IF VARTYPE(loRows.Item(i)) = "O"
            cNames = loJson.PropertyNames(loRows.Item(i))
            EXIT
        ENDIF
    ENDFOR
    nFields = ALINES(laNames, CHRTRAN(cNames, ",", CHR(13)), 1 + 4, CHR(13))
    IF nFields = 0
        nFields = 1
        laNames[1] = "value"
    ENDIF
    DIMENSION laType[nFields], laLen[nFields]
    FOR j = 1 TO nFields
        laType[j] = ""
        laLen[j] = 1
    ENDFOR

    FOR i = 1 TO loRows.Count
        loRow = loRows.Item(i)
        FOR j = 1 TO nFields
            luValue = VFPWS_RowValue(loRow, laNames[j])
            IF ISNULL(luValue)
                LOOP
            ENDIF
            DO CASE
                CASE VARTYPE(luValue) = "L"
                    cType = "L"
                CASE INLIST(VARTYPE(luValue), "N", "Y")
                    cType = IIF(luValue = INT(luValue) AND ABS(luValue) < 2147483647, "I", "B")
                OTHERWISE
                    cType = "C"
                    IF VARTYPE(luValue) = "O"
                        luValue = loJson.Stringify(luValue)
                    ENDIF
                    laLen[j] = MAX(laLen[j], LEN(TRANSFORM(luValue)))
            ENDCASE
            DO CASE
                CASE EMPTY(laType[j]) OR laType[j] == cType
                    laType[j] = cType
                CASE INLIST(laType[j], "I", "B") AND INLIST(cType, "I", "B")
                    laType[j] = "B"
                OTHERWISE
                    laType[j] = "C"
                    laLen[j] = MAX(laLen[j], 20)
            ENDCASE
        ENDFOR
    ENDFOR

    cFields = ""
    FOR j = 1 TO nFields
        DO CASE
            CASE EMPTY(laType[j])
                cType = "C(1)"
            CASE laType[j] == "C"
                cType = IIF(laLen[j] > 254, "M", "C(" + TRANSFORM(laLen[j]) + ")")
            CASE laType[j] == "B"
                cType = "B(6)"
            OTHERWISE
                cType = laType[j]
        ENDCASE
        cFields = cFields + IIF(j = 1, "", ", ") + laNames[j] + " " + cType + " NULL"
        laType[j] = LEFT(cType, 1)
    ENDFOR

    nOldArea = SELECT()
    TRY
        IF USED(tcAlias)
            USE IN (tcAlias)
        ENDIF
        CREATE CURSOR (tcAlias) (&cFields)
    CATCH
        cFields = ""
    ENDTRY
    IF EMPTY(cFields)
        SELECT (nOldArea)
        RETURN -1
    ENDIF

    FOR i = 1 TO loRows.Count
        loRow = loRows.Item(i)
        APPEND BLANK
        FOR j = 1 TO nFields
            luValue = VFPWS_RowValue(loRow, laNames[j])
            IF NOT ISNULL(luValue) AND INLIST(laType[j], "C", "M")
                luValue = IIF(VARTYPE(luValue) = "O", loJson.Stringify(luValue), ;
                    IIF(VARTYPE(luValue) = "C", luValue, TRANSFORM(luValue)))
            ENDIF
            REPLACE (laNames[j]) WITH luValue
        ENDFOR
    ENDFOR
    GO TOP
    RETURN loRows.Count
ENDPROC

PROCEDURE VFPWS_RowValue
    LPARAMETERS toRow, tcName
    IF VARTYPE(toRow) <> "O"
        RETURN IIF(tcName == "value", toRow, .NULL.)
    ENDIF
    IF NOT PEMSTATUS(toRow, tcName, 5)
        RETURN .NULL.
    ENDIF
    RETURN EVALUATE("toRow." + tcName)
ENDPROC


*=========================================================
* Text helpers
*=========================================================

PROCEDURE VFPWS_ToUtf8
    * ANSI text of this computer's code page -> UTF-8 bytes.
    LPARAMETERS tcText
    IF EMPTY(tcText)
        RETURN ""
    ENDIF
    RETURN STRCONV(tcText, 9, CPCURRENT(), 1)
ENDPROC

PROCEDURE VFPWS_FromUtf8
    * UTF-8 bytes -> ANSI text of this computer's code page.
    LPARAMETERS tcBytes
    IF EMPTY(tcBytes)
        RETURN ""
    ENDIF
    RETURN STRCONV(tcBytes, 11, CPCURRENT(), 1)
ENDPROC

PROCEDURE VFPWS_UrlEncode
    * Text -> safe URL part (UTF-8, RFC 3986 unreserved characters kept).
    LPARAMETERS tcText
    LOCAL cBytes, cOut, i, cCh
    cBytes = VFPWS_ToUtf8(TRANSFORM(tcText))
    cOut = ""
    FOR i = 1 TO LEN(cBytes)
        cCh = SUBSTR(cBytes, i, 1)
        IF cCh $ "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
            cOut = cOut + cCh
        ELSE
            cOut = cOut + "%" + RIGHT(TRANSFORM(ASC(cCh), "@0"), 2)
        ENDIF
    ENDFOR
    RETURN cOut
ENDPROC

PROCEDURE VFPWS_Val
    * VAL() that always uses "." as decimal point (JSON / URLs).
    LPARAMETERS tcText
    RETURN VAL(CHRTRAN(ALLTRIM(TRANSFORM(tcText)), ".", SET("POINT")))
ENDPROC

PROCEDURE VFPWS_BaseClass
    * Objects of the Empty class have no properties at all (not even
    * BaseClass/Class), so they must never be read directly.
    LPARAMETERS toObj
    IF VARTYPE(toObj) <> "O"
        RETURN ""
    ENDIF
    IF PEMSTATUS(toObj, "BaseClass", 5)
        RETURN UPPER(toObj.BaseClass)
    ENDIF
    RETURN "EMPTY"
ENDPROC


*=========================================================
* JSON
*=========================================================

DEFINE CLASS VFPWSJson AS Custom
    cText = ""
    nPos = 1
    nLen = 0
    cError = ""

    *-----------------------------------------------------
    * Encoding (VFP value -> JSON text, ANSI; sent as UTF-8)
    *-----------------------------------------------------

    PROCEDURE Stringify
        LPARAMETERS tuValue
        RETURN THIS.ValueToJson(tuValue, 0)
    ENDPROC

    PROCEDURE ValueToJson
        LPARAMETERS tuValue, tnDepth
        IF tnDepth > VFPWS_MAX_DEPTH
            RETURN "null"
        ENDIF
        DO CASE
            CASE ISNULL(tuValue)
                RETURN "null"
            CASE VARTYPE(tuValue) = "C"
                RETURN THIS.Quote(RTRIM(tuValue))
            CASE INLIST(VARTYPE(tuValue), "N", "Y")
                RETURN THIS.NumToJson(IIF(VARTYPE(tuValue) = "Y", MTON(tuValue), tuValue))
            CASE VARTYPE(tuValue) = "L"
                RETURN IIF(tuValue, "true", "false")
            CASE VARTYPE(tuValue) = "D"
                RETURN IIF(EMPTY(tuValue), "null", ;
                    '"' + TRANSFORM(DTOS(tuValue), "@R 9999-99-99") + '"')
            CASE VARTYPE(tuValue) = "T"
                RETURN IIF(EMPTY(tuValue), "null", '"' + TTOC(tuValue, 3) + '"')
            CASE VARTYPE(tuValue) = "O"
                IF VFPWS_BaseClass(tuValue) == "COLLECTION"
                    RETURN THIS.CollectionToJson(tuValue, tnDepth)
                ENDIF
                RETURN THIS.ObjectToJson(tuValue, tnDepth)
        ENDCASE
        RETURN "null"
    ENDPROC

    PROCEDURE Quote
        LPARAMETERS tcText
        LOCAL cOut, i, nCode
        cOut = STRTRAN(tcText, "\", "\\")
        cOut = STRTRAN(cOut, ["], [\"])
        cOut = STRTRAN(cOut, CHR(13), "\r")
        cOut = STRTRAN(cOut, CHR(10), "\n")
        cOut = STRTRAN(cOut, CHR(9), "\t")
        cOut = STRTRAN(cOut, CHR(8), "\b")
        cOut = STRTRAN(cOut, CHR(12), "\f")
        * Remaining control characters
        FOR nCode = 0 TO 31
            IF CHR(nCode) $ cOut
                cOut = STRTRAN(cOut, CHR(nCode), "\u00" + RIGHT(TRANSFORM(nCode, "@0"), 2))
            ENDIF
        ENDFOR
        RETURN '"' + cOut + '"'
    ENDPROC

    PROCEDURE NumToJson
        LPARAMETERS tnValue
        LOCAL cText
        IF tnValue = INT(tnValue) AND ABS(tnValue) < 1e15
            RETURN LTRIM(STR(tnValue, 20, 0))
        ENDIF
        cText = ALLTRIM(STR(tnValue, 30, 10))
        cText = CHRTRAN(cText, SET("POINT"), ".")
        IF "." $ cText
            DO WHILE RIGHT(cText, 1) == "0"
                cText = LEFT(cText, LEN(cText) - 1)
            ENDDO
            IF RIGHT(cText, 1) == "."
                cText = LEFT(cText, LEN(cText) - 1)
            ENDIF
        ENDIF
        RETURN cText
    ENDPROC

    PROCEDURE PropertyNames
        * Property names in output order: "_vfpws_order" when present
        * (rows, parsed JSON, models), otherwise user-defined properties.
        LPARAMETERS toObj
        LOCAL cNames, nCount, i, cName
        LOCAL ARRAY laMembers[1]
        IF PEMSTATUS(toObj, "_vfpws_order", 5)
            RETURN toObj._vfpws_order
        ENDIF
        cNames = ""
        nCount = AMEMBERS(laMembers, toObj, 0)
        FOR i = 1 TO nCount
            cName = laMembers[i]
            IF VFPWS_BaseClass(toObj) == "EMPTY" OR PEMSTATUS(toObj, cName, 4)
                cNames = cNames + IIF(EMPTY(cNames), "", ",") + LOWER(cName)
            ENDIF
        ENDFOR
        RETURN cNames
    ENDPROC

    PROCEDURE ObjectToJson
        LPARAMETERS toObj, tnDepth
        LOCAL cOut, cNames, nCount, i, cName
        LOCAL ARRAY laNames[1]
        cNames = THIS.PropertyNames(toObj)
        cOut = ""
        nCount = ALINES(laNames, CHRTRAN(cNames, ",", CHR(13)), 1 + 4, CHR(13))
        FOR i = 1 TO nCount
            cName = laNames[i]
            IF NOT PEMSTATUS(toObj, cName, 5)
                LOOP
            ENDIF
            cOut = cOut + IIF(EMPTY(cOut), "", ",") + THIS.Quote(cName) + ":" + ;
                THIS.ValueToJson(EVALUATE("toObj." + cName), tnDepth + 1)
        ENDFOR
        RETURN "{" + cOut + "}"
    ENDPROC

    PROCEDURE CollectionToJson
        LPARAMETERS toCol, tnDepth
        LOCAL cOut, i, lKeyed
        IF toCol.Count = 0
            RETURN "[]"
        ENDIF
        lKeyed = NOT EMPTY(toCol.GetKey(1))
        cOut = ""
        FOR i = 1 TO toCol.Count
            cOut = cOut + IIF(i = 1, "", ",") + ;
                IIF(lKeyed, THIS.Quote(toCol.GetKey(i)) + ":", "") + ;
                THIS.ValueToJson(toCol.Item(i), tnDepth + 1)
        ENDFOR
        RETURN IIF(lKeyed, "{" + cOut + "}", "[" + cOut + "]")
    ENDPROC

    *-----------------------------------------------------
    * Decoding (JSON text, already ANSI -> VFP values)
    * objects -> Empty objects, arrays -> Collections
    *-----------------------------------------------------

    PROCEDURE Parse
        * Returns the value; on error .NULL. with cError set.
        LPARAMETERS tcJson
        LOCAL luValue
        THIS.cText = TRANSFORM(tcJson)
        THIS.nPos = 1
        THIS.nLen = LEN(THIS.cText)
        THIS.cError = ""
        THIS.SkipSpace()
        luValue = THIS.ParseValue(0)
        IF EMPTY(THIS.cError)
            THIS.SkipSpace()
            IF THIS.nPos <= THIS.nLen
                THIS.Fail("Extra data")
            ENDIF
        ENDIF
        IF NOT EMPTY(THIS.cError)
            RETURN .NULL.
        ENDIF
        RETURN luValue
    ENDPROC

    PROCEDURE Fail
        LPARAMETERS tcMessage
        IF EMPTY(THIS.cError)
            THIS.cError = tcMessage + " at position " + TRANSFORM(THIS.nPos)
        ENDIF
    ENDPROC

    PROCEDURE SkipSpace
        DO WHILE THIS.nPos <= THIS.nLen AND ;
                INLIST(SUBSTR(THIS.cText, THIS.nPos, 1), " ", CHR(9), CHR(10), CHR(13))
            THIS.nPos = THIS.nPos + 1
        ENDDO
    ENDPROC

    PROCEDURE ParseValue
        LPARAMETERS tnDepth
        LOCAL cCh
        IF tnDepth > VFPWS_MAX_DEPTH
            THIS.Fail("Nesting too deep")
            RETURN .NULL.
        ENDIF
        IF THIS.nPos > THIS.nLen
            THIS.Fail("Unexpected end of data")
            RETURN .NULL.
        ENDIF
        cCh = SUBSTR(THIS.cText, THIS.nPos, 1)
        DO CASE
            CASE cCh == "{"
                RETURN THIS.ParseObject(tnDepth)
            CASE cCh == "["
                RETURN THIS.ParseArray(tnDepth)
            CASE cCh == ["]
                RETURN THIS.ParseString()
            CASE SUBSTR(THIS.cText, THIS.nPos, 4) == "true"
                THIS.nPos = THIS.nPos + 4
                RETURN .T.
            CASE SUBSTR(THIS.cText, THIS.nPos, 5) == "false"
                THIS.nPos = THIS.nPos + 5
                RETURN .F.
            CASE SUBSTR(THIS.cText, THIS.nPos, 4) == "null"
                THIS.nPos = THIS.nPos + 4
                RETURN .NULL.
            CASE cCh == "-" OR ISDIGIT(cCh)
                RETURN THIS.ParseNumber()
        ENDCASE
        THIS.Fail("Expecting value")
        RETURN .NULL.
    ENDPROC

    PROCEDURE SafeName
        * JSON key -> valid VFP property name.
        LPARAMETERS tcKey
        LOCAL cName, i, cCh
        cName = ""
        FOR i = 1 TO LEN(tcKey)
            cCh = SUBSTR(tcKey, i, 1)
            * ASCII letters, digits and "_" only (valid VFP names)
            cName = cName + IIF(cCh $ "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_", ;
                cCh, "_")
        ENDFOR
        IF EMPTY(cName) OR ISDIGIT(LEFT(cName, 1))
            cName = "_" + cName
        ENDIF
        RETURN LEFT(cName, 128)
    ENDPROC

    PROCEDURE ParseObject
        LPARAMETERS tnDepth
        LOCAL loObj, cKey, cName, luValue, cOrder
        loObj = CREATEOBJECT("Empty")
        cOrder = ""
        THIS.nPos = THIS.nPos + 1
        THIS.SkipSpace()
        IF SUBSTR(THIS.cText, THIS.nPos, 1) == "}"
            THIS.nPos = THIS.nPos + 1
            ADDPROPERTY(loObj, "_vfpws_order", "")
            RETURN loObj
        ENDIF
        DO WHILE EMPTY(THIS.cError)
            THIS.SkipSpace()
            IF NOT SUBSTR(THIS.cText, THIS.nPos, 1) == ["]
                THIS.Fail("Expecting property name enclosed in double quotes")
                EXIT
            ENDIF
            cKey = THIS.ParseString()
            THIS.SkipSpace()
            IF NOT SUBSTR(THIS.cText, THIS.nPos, 1) == ":"
                THIS.Fail("Expecting ':' delimiter")
                EXIT
            ENDIF
            THIS.nPos = THIS.nPos + 1
            THIS.SkipSpace()
            luValue = THIS.ParseValue(tnDepth + 1)
            IF NOT EMPTY(THIS.cError)
                EXIT
            ENDIF
            cName = THIS.SafeName(cKey)
            IF NOT PEMSTATUS(loObj, cName, 5)
                cOrder = cOrder + IIF(EMPTY(cOrder), "", ",") + cName
            ENDIF
            ADDPROPERTY(loObj, cName, luValue)
            THIS.SkipSpace()
            DO CASE
                CASE SUBSTR(THIS.cText, THIS.nPos, 1) == ","
                    THIS.nPos = THIS.nPos + 1
                CASE SUBSTR(THIS.cText, THIS.nPos, 1) == "}"
                    THIS.nPos = THIS.nPos + 1
                    EXIT
                OTHERWISE
                    THIS.Fail("Expecting ',' delimiter")
            ENDCASE
        ENDDO
        ADDPROPERTY(loObj, "_vfpws_order", cOrder)
        RETURN loObj
    ENDPROC

    PROCEDURE ParseArray
        LPARAMETERS tnDepth
        LOCAL loCol, luValue
        loCol = CREATEOBJECT("Collection")
        THIS.nPos = THIS.nPos + 1
        THIS.SkipSpace()
        IF SUBSTR(THIS.cText, THIS.nPos, 1) == "]"
            THIS.nPos = THIS.nPos + 1
            RETURN loCol
        ENDIF
        DO WHILE EMPTY(THIS.cError)
            THIS.SkipSpace()
            luValue = THIS.ParseValue(tnDepth + 1)
            IF NOT EMPTY(THIS.cError)
                EXIT
            ENDIF
            loCol.Add(luValue)
            THIS.SkipSpace()
            DO CASE
                CASE SUBSTR(THIS.cText, THIS.nPos, 1) == ","
                    THIS.nPos = THIS.nPos + 1
                CASE SUBSTR(THIS.cText, THIS.nPos, 1) == "]"
                    THIS.nPos = THIS.nPos + 1
                    EXIT
                OTHERWISE
                    THIS.Fail("Expecting ',' delimiter")
            ENDCASE
        ENDDO
        RETURN loCol
    ENDPROC

    PROCEDURE ParseString
        LOCAL cOut, cCh, cEsc, nCode, lClosed
        cOut = ""
        lClosed = .F.
        THIS.nPos = THIS.nPos + 1
        DO WHILE THIS.nPos <= THIS.nLen
            cCh = SUBSTR(THIS.cText, THIS.nPos, 1)
            DO CASE
                CASE cCh == ["]
                    THIS.nPos = THIS.nPos + 1
                    lClosed = .T.
                    EXIT
                CASE cCh == "\"
                    cEsc = SUBSTR(THIS.cText, THIS.nPos + 1, 1)
                    THIS.nPos = THIS.nPos + 2
                    DO CASE
                        CASE cEsc == "n"
                            cOut = cOut + CHR(10)
                        CASE cEsc == "r"
                            cOut = cOut + CHR(13)
                        CASE cEsc == "t"
                            cOut = cOut + CHR(9)
                        CASE cEsc == "b"
                            cOut = cOut + CHR(8)
                        CASE cEsc == "f"
                            cOut = cOut + CHR(12)
                        CASE cEsc == "u"
                            IF LEN(SUBSTR(THIS.cText, THIS.nPos, 4)) = 4 AND EMPTY(CHRTRAN(UPPER( ;
                                    SUBSTR(THIS.cText, THIS.nPos, 4)), "0123456789ABCDEF", ""))
                                nCode = EVALUATE("0x" + SUBSTR(THIS.cText, THIS.nPos, 4))
                                THIS.nPos = THIS.nPos + 4
                                cOut = cOut + THIS.CodePointToAnsi(nCode)
                            ELSE
                                THIS.Fail("Invalid unicode escape")
                                EXIT
                            ENDIF
                        OTHERWISE
                            * \" \\ \/
                            cOut = cOut + cEsc
                    ENDCASE
                OTHERWISE
                    cOut = cOut + cCh
                    THIS.nPos = THIS.nPos + 1
            ENDCASE
        ENDDO
        IF NOT lClosed
            THIS.Fail("Unterminated string")
        ENDIF
        RETURN cOut
    ENDPROC

    PROCEDURE CodePointToAnsi
        * \uXXXX -> character of this computer's code page.
        LPARAMETERS tnCode
        LOCAL cUtf8
        DO CASE
            CASE tnCode < 128
                RETURN CHR(tnCode)
            CASE tnCode < 2048
                cUtf8 = CHR(192 + INT(tnCode / 64)) + CHR(128 + MOD(tnCode, 64))
            OTHERWISE
                cUtf8 = CHR(224 + INT(tnCode / 4096)) + ;
                    CHR(128 + MOD(INT(tnCode / 64), 64)) + CHR(128 + MOD(tnCode, 64))
        ENDCASE
        RETURN VFPWS_FromUtf8(cUtf8)
    ENDPROC

    PROCEDURE ParseNumber
        LOCAL nStart, cNum
        nStart = THIS.nPos
        DO WHILE THIS.nPos <= THIS.nLen AND ;
                SUBSTR(THIS.cText, THIS.nPos, 1) $ "+-0123456789.eE"
            THIS.nPos = THIS.nPos + 1
        ENDDO
        cNum = SUBSTR(THIS.cText, nStart, THIS.nPos - nStart)
        IF NOT ISDIGIT(RIGHT(cNum, 1))
            THIS.Fail("Invalid number")
            RETURN .NULL.
        ENDIF
        RETURN VFPWS_Val(cNum)
    ENDPROC
ENDDEFINE

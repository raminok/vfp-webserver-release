*=========================================================
* app.prg - sample application for VFPWebServer
*
* This is the developer's file: routes, models and handlers.
* The framework calls PROCEDURE ConfigureApp(toApp) each time the
* server starts. The server loads the COMPILED file:
*   COMPILE app.prg   ->   app.fxp
*   server.ini: [App] Program=Apps\Samples\app.fxp
* Data: Data\items.dbf next to app.fxp (AppPath).
*
* Endpoints:
*   GET    /items                  list (skip, limit, q)
*   GET    /items/{item_id}        one item (404 when missing)
*   POST   /items                  create (JSON body, 201)
*   PUT    /items/{item_id}        update
*   DELETE /items/{item_id}        delete (204)
*   GET    /items/{item_id}/html   HTMLResponse
*   GET    /demo/hello/{name}      PlainTextResponse
*   POST   /demo/contact           form fields
*   GET    /demo/whoami            header parameters
*   GET    /demo/report.csv        CSV download
*
* Handlers receive the declared parameters as LPARAMETERS in the order
* they were declared (the LPARAMETERS names are free VFP names).
*=========================================================

PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loModel, loRouter, loRoute

    toApp.cTitle = "VFPWebServer Sample API"
    toApp.cDescription = "Items example: path, query, header, form and JSON body " + ;
        "parameters, models, 422 validation and HTTPException."

    App_EnsureSampleData()

    *-----------------------------------------------------
    * Models (like Pydantic BaseModel)
    *-----------------------------------------------------

    * Input: what clients send
    loModel = toApp.Model("ItemIn")
    loModel.Field("name", "str", .T., .NULL., "min_length=1;max_length=60;description=Item name")
    loModel.Field("price", "float", .T., .NULL., "ge=0;description=Unit price")
    loModel.Field("in_stock", "bool", .F., .T., "description=Available for sale")
    loModel.Field("category", "str", .F., "general", "enum=general|food|drink")

    * Output: what the API returns (response_model)
    loModel = toApp.Model("Item")
    loModel.Field("id", "int", .T.)
    loModel.Field("name", "str", .T.)
    loModel.Field("price", "float", .T.)
    loModel.Field("in_stock", "bool", .T.)
    loModel.Field("category", "str", .T.)
    loModel.Field("created", "datetime", .T.)

    *-----------------------------------------------------
    * /items  (APIRouter with prefix and tag)
    *-----------------------------------------------------

    loRouter = toApp.APIRouter("/items", "Items")

    loRoute = loRouter.Get("/", "ItemsHandler.ListItems")
    loRoute.Summary("List items")
    loRoute.Query("skip", "int", .F., 0, "ge=0;description=Number of items to skip")
    loRoute.Query("limit", "int", .F., 10, "ge=1;le=100;description=Maximum number of items")
    loRoute.Query("q", "str", .F., .NULL., "max_length=50;description=Search in the name")
    loRoute.ResponseModel("Item[]")

    loRoute = loRouter.Get("/{item_id}", "ItemsHandler.ReadItem")
    loRoute.Summary("Read one item")
    loRoute.Path("item_id", "int", "ge=1")
    loRoute.ResponseModel("Item")

    loRoute = loRouter.Post("/", "ItemsHandler.CreateItem")
    loRoute.Summary("Create an item")
    loRoute.Body("item", "ItemIn")
    loRoute.StatusCode(201)
    loRoute.ResponseModel("Item")

    loRoute = loRouter.Put("/{item_id}", "ItemsHandler.UpdateItem")
    loRoute.Summary("Update an item")
    loRoute.Path("item_id", "int", "ge=1")
    loRoute.Body("item", "ItemIn")
    loRoute.ResponseModel("Item")

    loRoute = loRouter.Delete("/{item_id}", "ItemsHandler.DeleteItem")
    loRoute.Summary("Delete an item")
    loRoute.Path("item_id", "int", "ge=1")
    loRoute.StatusCode(204)

    loRoute = loRouter.Get("/{item_id}/html", "ItemsHandler.ItemPage")
    loRoute.Summary("Item as an HTML page")
    loRoute.Path("item_id", "int", "ge=1")

    *-----------------------------------------------------
    * /demo  (other parameter sources and response types)
    *-----------------------------------------------------

    loRouter = toApp.APIRouter("/demo", "Demo")

    loRoute = loRouter.Get("/hello/{name}", "DemoHandler.Hello")
    loRoute.Summary("Plain text answer")
    loRoute.Path("name", "str", "max_length=40")

    loRoute = loRouter.Post("/contact", "DemoHandler.Contact")
    loRoute.Summary("HTML form fields")
    loRoute.Form("email", "str", .T., .NULL., "max_length=100")
    loRoute.Form("message", "str", .T., .NULL., "min_length=1;max_length=500")

    loRoute = loRouter.Get("/whoami", "DemoHandler.WhoAmI")
    loRoute.Summary("Header parameters")
    * x_client_name reads the header X-Client-Name (like FastAPI)
    loRoute.Header("x_client_name", "str", .F., "unknown")
    loRoute.Header("user_agent", "str", .F., "")

    loRoute = loRouter.Get("/report.csv", "DemoHandler.ReportCsv")
    loRoute.Summary("Items as a CSV download")
ENDPROC


*=========================================================
* Sample data: Data\items.dbf (created on first start)
*=========================================================

PROCEDURE App_EnsureSampleData
    LOCAL cTable, nOldArea, tNow
    cTable = AppPath("Data\items.dbf")
    IF FILE(cTable)
        RETURN
    ENDIF
    IF NOT DIRECTORY(JUSTPATH(cTable))
        MD (JUSTPATH(cTable))
    ENDIF
    nOldArea = SELECT()
    SELECT 0
    CREATE TABLE (cTable) FREE ( ;
        id I, name C(60), price N(12, 2), in_stock L, category C(20), created T)
    tNow = DATETIME()
    INSERT INTO items (id, name, price, in_stock, category, created) ;
        VALUES (1, "Espresso", 2.50, .T., "drink", tNow)
    INSERT INTO items (id, name, price, in_stock, category, created) ;
        VALUES (2, "Cappuccino", 3.20, .T., "drink", tNow)
    INSERT INTO items (id, name, price, in_stock, category, created) ;
        VALUES (3, "Cheesecake", 4.75, .F., "food", tNow)
    USE
    SELECT (nOldArea)
ENDPROC

PROCEDURE App_OpenItems
    IF NOT USED("items")
        USE (AppPath("Data\items.dbf")) IN 0 SHARED ALIAS items
    ENDIF
ENDPROC

PROCEDURE App_NextItemId
    * Highest id including deleted rows, so ids are never reused.
    LOCAL nMax, cOldDeleted
    App_OpenItems()
    cOldDeleted = SET("DELETED")
    SET DELETED OFF
    nMax = 0
    CALCULATE MAX(id) TO nMax IN items
    SET DELETED &cOldDeleted
    RETURN NVL(nMax, 0) + 1
ENDPROC


*=========================================================
* Handlers
*=========================================================

DEFINE CLASS ItemsHandler AS VFPWSHandler

    PROCEDURE ListItems
        * Query parameters, in declaration order: skip, limit, q
        LPARAMETERS tnSkip, tnLimit, tcQuery
        LOCAL loList, nRow
        App_OpenItems()
        IF ISNULL(tcQuery) OR EMPTY(tcQuery)
            SELECT * FROM items ORDER BY id INTO CURSOR curItems
        ELSE
            SELECT * FROM items WHERE ATC(ALLTRIM(tcQuery), name) > 0 ;
                ORDER BY id INTO CURSOR curItems
        ENDIF
        loList = CREATEOBJECT("Collection")
        nRow = 0
        SELECT curItems
        SCAN
            nRow = nRow + 1
            IF nRow > tnSkip AND loList.Count < tnLimit
                loList.Add(THIS.Row("curItems"))
            ENDIF
        ENDSCAN
        USE IN curItems
        RETURN loList
    ENDPROC

    PROCEDURE ReadItem
        LPARAMETERS tnItemId
        LOCAL loItem
        App_OpenItems()
        SELECT * FROM items WHERE id = tnItemId INTO CURSOR curItem
        IF _TALLY = 0
            USE IN curItem
            THROW HTTPException(404, "Item not found")
        ENDIF
        loItem = THIS.Row("curItem")
        USE IN curItem
        RETURN loItem
    ENDPROC

    PROCEDURE CreateItem
        * toItem was validated against the ItemIn model (422 otherwise).
        LPARAMETERS toItem
        LOCAL nId
        nId = App_NextItemId()
        INSERT INTO items (id, name, price, in_stock, category, created) ;
            VALUES (nId, toItem.name, toItem.price, NVL(toItem.in_stock, .T.), ;
            NVL(toItem.category, "general"), DATETIME())
        RETURN THIS.ReadItem(nId)
    ENDPROC

    PROCEDURE UpdateItem
        LPARAMETERS tnItemId, toItem
        App_OpenItems()
        SELECT items
        LOCATE FOR id = tnItemId
        IF NOT FOUND()
            THROW HTTPException(404, "Item not found")
        ENDIF
        IF NOT RLOCK()
            THROW HTTPException(409, "Item is being changed by another user")
        ENDIF
        REPLACE name WITH toItem.name, price WITH toItem.price, ;
            in_stock WITH NVL(toItem.in_stock, .T.), ;
            category WITH NVL(toItem.category, "general")
        UNLOCK
        RETURN THIS.ReadItem(tnItemId)
    ENDPROC

    PROCEDURE DeleteItem
        LPARAMETERS tnItemId
        App_OpenItems()
        SELECT items
        LOCATE FOR id = tnItemId
        IF NOT FOUND()
            THROW HTTPException(404, "Item not found")
        ENDIF
        IF NOT RLOCK()
            THROW HTTPException(409, "Item is being changed by another user")
        ENDIF
        DELETE
        UNLOCK
        * 204 No Content: nothing to return
        RETURN .NULL.
    ENDPROC

    PROCEDURE ItemPage
        LPARAMETERS tnItemId
        LOCAL loItem, cHtml
        loItem = THIS.ReadItem(tnItemId)
        cHtml = "<!DOCTYPE html><html><head><meta charset='utf-8'>" + ;
            "<title>" + VFPWS_HtmlEncode(ALLTRIM(loItem.name)) + "</title></head>" + ;
            "<body style='font-family:Segoe UI,sans-serif;margin:40px'>" + ;
            "<h1>" + VFPWS_HtmlEncode(ALLTRIM(loItem.name)) + "</h1>" + ;
            "<p>Price: " + TRANSFORM(loItem.price) + "</p>" + ;
            "<p>Category: " + VFPWS_HtmlEncode(ALLTRIM(loItem.category)) + "</p>" + ;
            "<p>In stock: " + IIF(loItem.in_stock, "yes", "no") + "</p>" + ;
            "</body></html>"
        RETURN HTMLResponse(cHtml)
    ENDPROC
ENDDEFINE


DEFINE CLASS DemoHandler AS VFPWSHandler

    PROCEDURE Hello
        LPARAMETERS tcName
        RETURN PlainTextResponse("Hello, " + tcName + "!")
    ENDPROC

    PROCEDURE Contact
        LPARAMETERS tcEmail, tcMessage
        LOCAL loResult
        loResult = THIS.MakeObject("received,email,message_length")
        loResult.received = .T.
        loResult.email = tcEmail
        loResult.message_length = LEN(tcMessage)
        RETURN loResult
    ENDPROC

    PROCEDURE WhoAmI
        LPARAMETERS tcClientName, tcUserAgent
        LOCAL loResult
        loResult = THIS.MakeObject("client_name,user_agent,ip")
        loResult.client_name = tcClientName
        loResult.user_agent = tcUserAgent
        loResult.ip = THIS.oRequest.cClientIP
        RETURN loResult
    ENDPROC

    PROCEDURE ReportCsv
        LOCAL cCsv
        App_OpenItems()
        cCsv = "id,name,price,in_stock,category" + CHR(13) + CHR(10)
        SELECT * FROM items ORDER BY id INTO CURSOR curReport
        SCAN
            cCsv = cCsv + TRANSFORM(curReport.id) + "," + ;
                '"' + STRTRAN(ALLTRIM(curReport.name), '"', '""') + '",' + ;
                TRANSFORM(curReport.price) + "," + ;
                IIF(curReport.in_stock, "true", "false") + "," + ;
                ALLTRIM(curReport.category) + CHR(13) + CHR(10)
        ENDSCAN
        USE IN curReport
        RETURN Response(cCsv, "text/csv", 200, ;
            'Content-Disposition: attachment; filename="items.csv"' + CHR(13) + CHR(10))
    ENDPROC
ENDDEFINE

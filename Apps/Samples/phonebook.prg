*=========================================================
* phonebook.prg - a first, minimal VFPWebServer application
*
* A small phone book stored in Data\contacts.dbf (next to the .fxp).
*
*   GET    /hello/{name}       a greeting (JSON)
*   GET    /contacts           all contacts (optional ?search=)
*   GET    /contacts/{id}      one contact (404 when missing)
*   POST   /contacts           add a contact (JSON body, 201)
*   DELETE /contacts/{id}      delete a contact (204)
*
* To use it:
*   1. COMPILE phonebook.prg   ->   phonebook.fxp
*   2. Settings > Application: Apps\Samples\phonebook.fxp
*   3. Stop / Start the server (the application is loaded on Start).
*=========================================================

*---------------------------------------------------------
* 1. ConfigureApp: the framework calls it once at start.
*    Here you only DECLARE models and routes.
*---------------------------------------------------------
PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loModel, loRoute

    toApp.cTitle = "Phone Book API"
    toApp.cDescription = "My first VFPWebServer application."

    Pb_CreateTable()

    * The JSON a client sends to POST /contacts
    loModel = toApp.Model("ContactIn")
    loModel.Field("name",  "str", .T., .NULL., "min_length=2;max_length=50")
    loModel.Field("phone", "str", .T., .NULL., "min_length=3;max_length=20")
    loModel.Field("city",  "str", .F., "")

    * GET /hello/{name}
    loRoute = toApp.Get("/hello/{name}", "PhoneBook.Hello")
    loRoute.Summary("Say hello")
    loRoute.Path("name", "str", "max_length=30")

    * GET /contacts?search=ali
    loRoute = toApp.Get("/contacts", "PhoneBook.ListContacts")
    loRoute.Summary("List contacts")
    loRoute.Query("search", "str", .F., "", "max_length=30")

    * GET /contacts/5
    loRoute = toApp.Get("/contacts/{id}", "PhoneBook.GetContact")
    loRoute.Summary("Read one contact")
    loRoute.Path("id", "int", "ge=1")

    * POST /contacts   {"name":"Ali","phone":"0912..."}
    loRoute = toApp.Post("/contacts", "PhoneBook.AddContact")
    loRoute.Summary("Add a contact")
    loRoute.Body("contact", "ContactIn")
    loRoute.StatusCode(201)

    * DELETE /contacts/5
    loRoute = toApp.Delete("/contacts/{id}", "PhoneBook.DeleteContact")
    loRoute.Summary("Delete a contact")
    loRoute.Path("id", "int", "ge=1")
    loRoute.StatusCode(204)
ENDPROC


*---------------------------------------------------------
* 2. The handler class: the code that runs for each route.
*    Parameters arrive as LPARAMETERS in the order declared.
*---------------------------------------------------------
DEFINE CLASS PhoneBook AS VFPWSHandler

    PROCEDURE Hello
        LPARAMETERS tcName
        LOCAL loAnswer
        loAnswer = THIS.MakeObject("message,time")
        loAnswer.message = "Hello " + tcName
        loAnswer.time = DATETIME()
        RETURN loAnswer          && {"message":"Hello Ali","time":"..."}
    ENDPROC

    PROCEDURE ListContacts
        LPARAMETERS tcSearch
        LOCAL loList
        Pb_Open()
        SELECT * FROM contacts ;
            WHERE EMPTY(tcSearch) OR ATC(ALLTRIM(tcSearch), name) > 0 ;
            ORDER BY name INTO CURSOR curList
        loList = THIS.Rows("curList")      && Collection -> JSON array
        USE IN curList
        RETURN loList
    ENDPROC

    PROCEDURE GetContact
        LPARAMETERS tnId
        LOCAL loContact
        Pb_Open()
        SELECT * FROM contacts WHERE id = tnId INTO CURSOR curOne
        IF _TALLY = 0
            USE IN curOne
            THROW HTTPException(404, "Contact not found")
        ENDIF
        loContact = THIS.Row("curOne")     && one record -> JSON object
        USE IN curOne
        RETURN loContact
    ENDPROC

    PROCEDURE AddContact
        * toContact is already validated against ContactIn (422 otherwise)
        LPARAMETERS toContact
        LOCAL nId
        Pb_Open()
        CALCULATE MAX(id) TO nId IN contacts
        nId = NVL(nId, 0) + 1
        INSERT INTO contacts (id, name, phone, city, created) ;
            VALUES (nId, toContact.name, toContact.phone, ;
            NVL(toContact.city, ""), DATETIME())
        RETURN THIS.GetContact(nId)
    ENDPROC

    PROCEDURE DeleteContact
        LPARAMETERS tnId
        Pb_Open()
        SELECT contacts
        LOCATE FOR id = tnId
        IF NOT FOUND()
            THROW HTTPException(404, "Contact not found")
        ENDIF
        IF NOT RLOCK()
            THROW HTTPException(409, "Contact is being changed by another user")
        ENDIF
        DELETE
        UNLOCK
        RETURN .NULL.                      && 204: no content
    ENDPROC
ENDDEFINE


*---------------------------------------------------------
* 3. Helpers (prefix them to avoid name clashes)
*---------------------------------------------------------
PROCEDURE Pb_CreateTable
    LOCAL cTable, nOldArea
    cTable = AppPath("Data\contacts.dbf")
    IF FILE(cTable)
        RETURN
    ENDIF
    IF NOT DIRECTORY(JUSTPATH(cTable))
        MD (JUSTPATH(cTable))
    ENDIF
    nOldArea = SELECT()
    SELECT 0
    CREATE TABLE (cTable) FREE ( ;
        id I, name C(50), phone C(20), city C(30), created T)
    INSERT INTO contacts (id, name, phone, city, created) ;
        VALUES (1, "Sample Contact", "021-0000000", "Tehran", DATETIME())
    USE
    SELECT (nOldArea)
ENDPROC

PROCEDURE Pb_Open
    IF NOT USED("contacts")
        USE (AppPath("Data\contacts.dbf")) IN 0 SHARED ALIAS contacts
    ENDIF
ENDPROC

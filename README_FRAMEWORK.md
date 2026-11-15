# VFPWebServer - FastAPI-style framework for Visual FoxPro 9

Write HTTP APIs in Visual FoxPro the way you would in FastAPI: declare routes,
typed parameters and models; the framework validates requests (422), converts
results to JSON and generates `/docs`, `/redoc` and `/openapi.json`.

## Files

| File | Purpose |
|---|---|
| `VFPWebServer.exe` | The server with the framework built in (from Releases) |
| `Apps\Template\myapp.prg` | Empty template for **your** application |
| `Apps\Samples\` | `app.prg` (items CRUD), `phonebook.prg`, `parts_app.prg` |
| `Apps\AppDemo\` | Two-file application built as `demo.app` |
| `Clients\VFPWSClient.prg` | Client library for VFP front ends (guide: `Clients\README_CLIENT.md`) |
| `Clients\parts_client.prg` | A VFP program that calls the API (front end) |
| `test_api.ps1` | Automatic test of the sample `app.prg` |

The server is a finished EXE that nobody rebuilds. Your application is a
separate, **compiled** file (`.fxp` or `.app`) in its own folder, chosen in
*Settings > Application* (`Config\server.ini`: `[App] Program=...`).
Source files (`.prg`) are refused: the VFP runtime cannot compile them.

## Your application in 5 steps

A detailed walkthrough with a complete example is in `README.md`, section
"Your own application, step by step".

1. Copy `Apps\Template` to `Apps\MyApp` and rename `myapp.prg`.
2. Write routes in `ConfigureApp` and handlers in your classes.
3. In the VFP IDE: `COMPILE Apps\MyApp\myapp.prg` (creates `myapp.fxp`).
4. *Settings > Application*: `Apps\MyApp\myapp.fxp`, Save.
5. *Start Server* and open `http://localhost:8080/docs`.

After each change: compile again, then **Stop / Start** the server. The
application is loaded every time the server starts; there is no need to
close the program. The first line of the *API Endpoints* tab and the tray
notification show the result, for example `myapp.fxp - 3 routes loaded`,
the error, or `myapp.prg is newer than myapp.fxp - run COMPILE again`.
If the application cannot be loaded, the server still starts with the
System routes (`/api/health` ...), so the network can still be checked.

## Quick start

```foxpro
PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loRoute
    loRoute = toApp.Get("/hello/{name}", "HelloHandler.SayHello")
    loRoute.Path("name", "str", "max_length=40")
ENDPROC

DEFINE CLASS HelloHandler AS VFPWSHandler
    PROCEDURE SayHello
        LPARAMETERS tcName
        LOCAL lo
        lo = THIS.MakeObject("message")
        lo.message = "Hello " + tcName
        RETURN lo            && -> {"message":"Hello Ali"}
    ENDPROC
ENDDEFINE
```

Start the server and open `http://localhost:8080/docs`.

## FastAPI and VFPWebServer side by side

| FastAPI | VFPWebServer |
|---|---|
| `@app.get("/items")` | `toApp.Get("/items", "Class.Method")` (also `Post`, `Put`, `Patch`, `Delete`) |
| `APIRouter(prefix="/items", tags=["Items"])` | `loRouter = toApp.APIRouter("/items", "Items")` |
| `item_id: int` (path) | `loRoute.Path("item_id", "int")` |
| `q: str \| None = Query(None, max_length=50)` | `loRoute.Query("q", "str", .F., .NULL., "max_length=50")` |
| `x_token: str = Header()` | `loRoute.Header("x_token", "str", .T.)` (reads `X-Token`) |
| `email: str = Form()` | `loRoute.Form("email", "str", .T.)` |
| `item: Item` (JSON body) | `loRoute.Body("item", "Item")` |
| `class Item(BaseModel)` | `loModel = toApp.Model("Item")` + `loModel.Field(...)` |
| `response_model=Item` / `list[Item]` | `loRoute.ResponseModel("Item")` / `("Item[]")` |
| `status_code=201` | `loRoute.StatusCode(201)` |
| `raise HTTPException(404, "...")` | `THROW HTTPException(404, "...")` |
| `return {...}` / `return [...]` | `RETURN` object, Collection, `THIS.Row()`, `THIS.Rows()` |
| `HTMLResponse`, `PlainTextResponse`, `JSONResponse`, `FileResponse`, `RedirectResponse`, `Response` | same names, called as functions |
| validation error 422 `{"detail":[...]}` | identical format |

## Parameters

```foxpro
loRoute.Path(cName, cType [, cOptions])                        && always required
loRoute.Query(cName, cType [, lRequired [, uDefault [, cOptions]]])
loRoute.Header(cName, cType [, lRequired [, uDefault [, cOptions]]])
loRoute.Form(cName, cType [, lRequired [, uDefault [, cOptions]]])
loRoute.Body(cName, cModelName)
```

**Handlers receive the parameters as `LPARAMETERS`, in the order they were
declared.** The VFP names may differ from the API names (e.g. API `skip`,
VFP `tnSkip`). The request is also available as `THIS.oRequest`
(`cMethod`, `cPath`, `cClientIP`, `cBody`, `Header("name")`, `Query("name")`).

**Types:** `str`, `int`, `float`, `bool`, `date` (`YYYY-MM-DD` to VFP Date),
`datetime` (`YYYY-MM-DDTHH:MM:SS` to VFP DateTime).

**Options** (`"key=value;key=value"`): `min_length`, `max_length`, `ge`, `le`,
`gt`, `lt`, `enum` (`a|b|c`), `description`.

A missing optional parameter is its default, or `.NULL.` when it has none.

## Models

```foxpro
loModel = toApp.Model("ItemIn")
loModel.Field("name",     "str",   .T., .NULL., "min_length=1;max_length=60")
loModel.Field("price",    "float", .T., .NULL., "ge=0")
loModel.Field("in_stock", "bool",  .F., .T.)
```

The handler receives an object with exactly these fields (validated and
converted). Extra fields sent by the client are ignored.

`ResponseModel("Item")` keeps only the model fields in the answer, in model
order - useful to hide internal columns.

## Results and JSON

| VFP | JSON |
|---|---|
| Character / Memo | string (trailing spaces removed) |
| Numeric, Integer, Currency | number |
| Logical | `true` / `false` |
| Date / DateTime | `"2026-11-09"` / `"2026-11-09T14:35:10"` (empty: `null`) |
| `.NULL.` | `null` |
| Object (Empty, `SCATTER NAME`, `THIS.Row()`, `THIS.MakeObject()`) | object |
| Collection without keys / with keys | array / object |

`THIS.Row("alias")` returns the current record as an object;
`THIS.Rows("alias")` returns all records as a Collection;
`THIS.MakeObject("id,name")` returns an empty object with those properties.
Text is sent as UTF-8; Persian text needs the Windows code page 1256.

## Errors

```foxpro
THROW HTTPException(404, "Item not found")      && {"detail":"Item not found"}
```

Any other error in a handler returns `500 {"detail":"Internal Server Error",
"error_id":"..."}`; the details (message, line, procedure) are written to the
log with the same `error_id`.

## API keys

When *Settings > Require an API key* is on, every route needs a valid
`X-Api-Key` header, except routes marked `loRoute.Public()` and the docs.
Keys are created in the **API Keys** window (tray > Settings > API Keys).

## Admin password (server PC)

*Settings > Set Password...* protects Stop Server, Exit, Settings, API Keys
and updates on the server computer (viewing the dashboard and Start Server
stay free). After a correct password these actions stay unlocked for
5 minutes; 5 wrong passwords lock the prompt for 60 seconds.

Only a PBKDF2-SHA256 hash (600,000 iterations, random salt) is stored, in
`Config\server.ini` (`[Security] AdminPassword`). Forgotten password: delete
that line. Protect the `Config` folder with NTFS permissions.

## Application files: .fxp or .app

| | `.fxp` | `.app` |
|---|---|---|
| For | one source file | several source files |
| Create | `COMPILE myapp.prg` | project, `myapp.prg` as **Main**, Build > Application |
| Server calls | `ConfigureApp(toApp)` in the file | `DO myapp.app WITH toApp` (the main program) |

The main program of an `.app` receives `toApp`, opens the files that hold
its classes and procedures, and calls `ConfigureApp` - the template already
contains these lines:

```foxpro
LPARAMETERS toApp
IF VARTYPE(toApp) <> "O"
    RETURN
ENDIF
SET PROCEDURE TO myapp, myhandlers ADDITIVE
ConfigureApp(toApp)
RETURN
```

`Apps\AppDemo` is a working two-file example: `DO Apps\AppDemo\build_demo.prg`
builds `demo.app`. If Windows reports the `.app` file in use while you build,
exit the server first.

## Folders and data

`AppPath("Data\menu.dbf")` returns the path inside your application folder
(the folder of the `.fxp` / `.app`); a full path is returned unchanged.
`THIS.oApp.cAppFolder` and `THIS.oApp.cAppFile` are available in handlers.
Do not use `FULLPATH()` or the current directory for your data.

```
VFPWebServer\
  VFPWebServer.exe
  Config\server.ini            [App] Program=Apps\Restaurant\restaurant.fxp
  Apps\Restaurant\restaurant.fxp
  Apps\Restaurant\Data\menu.dbf
```

## Required server version

```foxpro
toApp.RequireVersion("0.3")
```

On an older server the application is not loaded and the message says which
version is needed.

## Limitations

* Single-threaded: a slow handler delays all other requests. Keep queries fast.
* One application per server folder. For a second application, copy the
  server folder and use another port.
* Prefix your helper procedures (`Rst_...`) to avoid clashes with the server.
* HTTP only. Put the server behind IIS / nginx / Caddy for HTTPS.
* Not yet available: file uploads (`multipart`), `Depends`, middleware,
  CORS, background tasks, nested models.

## Testing the sample application

1. Start the server with the default settings: the sample application
   (`Apps\Samples\app.fxp`, written by the EXE on its first run) is
   loaded and creates `Apps\Samples\Data\items.dbf`.
2. Run:

   ```
   powershell -ExecutionPolicy Bypass -File .\test_api.ps1
   ```

   With *Require an API key* on: `.\test_api.ps1 -ApiKey vfpws_...`
3. Every check prints PASS / FAIL; the last line is the summary.
4. Try the same endpoints by hand in `http://localhost:8080/docs`
   ("Try it out").

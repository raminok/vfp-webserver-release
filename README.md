# VFPWebServer

An HTTP API server for Visual FoxPro 9 with a FastAPI-style framework.

Write web APIs in Visual FoxPro: declare routes, parameters and models; the
server validates requests, converts results to JSON and publishes interactive
documentation at `/docs`. Front-end VFP applications call the API with the
included client library.

Version 0.3.0-preview - Copyright (c) 2026 Ramin Orak, Aryana Software - [raminorak.com](https://raminorak.com)

Persian guide: `README_FA.md`

## Download

Get the latest version from the [Releases](https://github.com/raminok/vfp-webserver-release/releases) page:

| File | For |
|---|---|
| `VFPWebServer-0.3.0-Setup.exe` | Installer (recommended) |
| `VFPWebServer-0.3.0.zip` | The server without installation: unzip and run `VFPWebServer.exe` |
| `VFPWSClient-0.3.0.zip` | Client library for front-end VFP programs |

Windows may show "Windows protected your PC" for a new download: choose
*More info* > *Run anyway*.

## In this repository

| Path | Content |
|---|---|
| `Apps\Template\` | Starting point for your own application |
| `Apps\Samples\` | Sample applications (items, phone book, parts) |
| `Apps\AppDemo\` | Application built from two files as an `.app` |
| `Clients\` | Client library `VFPWSClient.prg`, its guide and an example |
| `README_FRAMEWORK.md` | Complete framework reference |
| `test_api.ps1` | Automatic test of the sample application |

The server itself is distributed as a compiled program; its source code is
not published. Questions and bug reports: [Issues](https://github.com/raminok/vfp-webserver-release/issues).

## Features

- Native Winsock HTTP server, runs in the Windows tray with a live dashboard
  (connections, traffic, endpoints, request inspector, log)
- Routes with path, query, header, form and JSON body parameters
- Models with validation; `422` errors in the FastAPI format
- Automatic OpenAPI 3.0, Swagger UI (`/docs`) and ReDoc (`/redoc`)
- JSON, HTML, text, file and redirect responses
- API keys per client application (stored as SHA-256 hashes)
- Optional administrator password for server settings (PBKDF2-SHA256)
- Developer applications loaded as compiled `.fxp` / `.app` files and
  reloaded on every server start
- Client library for VFP front ends: HTTP, JSON, lists to cursors

## Quick start

1. Run `VFPWebServer.exe` and press *Start Server*.
2. Open `http://localhost:8080/docs`: the sample application is ready.
3. Your own application: copy `Apps\Template`, write your routes,
   `COMPILE` it and select the `.fxp` in *Settings > Application*.

## Your own application, step by step

The sample in `Apps\Samples` shows how everything works. Your own API is a
separate program that you write, compile and point the server to. The
server EXE itself never changes.

### 1. Create your folder

Copy `Apps\Template` to a new folder and rename the program, for example:

```
Apps\Orders\orders.prg
```

Any folder works (also outside `Apps`); keep one folder per application.
Your data files go in a `Data` folder inside it.

### 2. Declare your routes in `ConfigureApp`

Open `orders.prg`. `ConfigureApp` lists what the API offers: models (the
shape of JSON bodies) and routes (address + handler + parameters).

```foxpro
PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loModel, loRoute

    toApp.RequireVersion("0.3")
    toApp.cTitle = "Orders API"

    loModel = toApp.Model("OrderIn")
    loModel.Field("customer", "str", .T., .NULL., "min_length=1;max_length=50")
    loModel.Field("amount", "float", .T., .NULL., "ge=0")

    loRoute = toApp.Get("/orders/{id}", "OrdersHandler.GetOrder")
    loRoute.Path("id", "int")

    loRoute = toApp.Get("/orders", "OrdersHandler.ListOrders")
    loRoute.Query("customer", "str", .F., "")

    loRoute = toApp.Post("/orders", "OrdersHandler.AddOrder")
    loRoute.Body("order", "OrderIn")
    loRoute.StatusCode(201)
ENDPROC
```

Which kind of parameter: the record the call is about goes in the
**path** (`/orders/15`); data that is saved goes in the **body** (JSON);
search, filter and paging values go in the **query** (`?customer=ali`).

### 3. Write the handlers

Each route calls a method of your handler class. The parameters arrive as
`LPARAMETERS`, in the order they were declared; what you `RETURN` is sent
as JSON.

```foxpro
DEFINE CLASS OrdersHandler AS VFPWSHandler

    PROCEDURE GetOrder
        LPARAMETERS tnId
        LOCAL loOrder
        Ord_Open()
        SELECT * FROM orders WHERE id = tnId INTO CURSOR curOrder
        IF _TALLY = 0
            THROW HTTPException(404, "Order not found")
        ENDIF
        loOrder = THIS.Row("curOrder")
        USE IN curOrder
        RETURN loOrder
    ENDPROC

ENDDEFINE

PROCEDURE Ord_Open
    IF NOT USED("orders")
        USE (AppPath("Data\orders.dbf")) IN 0 SHARED AGAIN ALIAS orders
    ENDIF
ENDPROC
```

- `AppPath("Data\orders.dbf")` is your application folder; do not rely on
  the current directory.
- Open tables `SHARED`, so your desktop programs can keep working.
- Give helper procedures a prefix (`Ord_...`) to avoid name clashes.
- Keep handlers fast: the server answers one request at a time.

### 4. Compile

The server runs compiled programs only. In the VFP IDE:

```foxpro
COMPILE Apps\Orders\orders.prg
```

This creates `orders.fxp`. If an `orders.err` file appears, it contains the
compile errors; fix them and compile again. An application made of several
`.prg` files is built as an `.app` instead (see `README_FRAMEWORK.md`,
"Application files: .fxp or .app").

### 5. Point the server to your program

*Settings > Application > Browse...*, select `Apps\Orders\orders.fxp`,
*Save*. The same setting in `Config\server.ini`:

```ini
[App]
Program=Apps\Orders\orders.fxp
```

From now on your program is loaded instead of the sample. To go back to
the sample, select `Apps\Samples\app.fxp` again.

### 6. Start and check

Press *Start Server* (or *Stop*, then *Start* when it is running). The tray
notification and the first line of the *API Endpoints* tab show the result:

| Message | Meaning |
|---|---|
| `loaded Apps\Orders\orders.fxp (3 routes)` | Ready |
| `WARNING: orders.prg is newer than orders.fxp` | You changed the source and did not compile it |
| `NOT LOADED - file not found` | Wrong path in *Settings > Application* |
| `NOT LOADED - ... is source code` | A `.prg` was selected; select the `.fxp` |
| `NOT LOADED - error ...` | An error in `ConfigureApp`: message, line and procedure |

When the program cannot be loaded, the server still starts with the system
routes (`/api/health` ...), so the network can still be checked.

### 7. Test

Open `http://localhost:8080/docs`. Every route you declared is there with
its parameters; *Try it out* sends a real request. Invalid input is
answered with `422` and the field that is wrong, without any code of yours.

### 8. Change and repeat

Edit `orders.prg`, `COMPILE` it, then *Stop* / *Start* the server. There is
no need to close the program or to rebuild the server.

### 9. Secure it

- *Settings > Require an API key*, then create one key per client program
  in *API Keys*. Clients send it in the `X-Api-Key` header.
- *Settings > Set Password...* protects the server settings on the server
  computer.

### 10. Deliver

Give your customer `VFPWebServer.exe` and your application folder
(`Apps\Orders` with `orders.fxp` and `Data`), and set *Settings >
Application* once on their computer. The `.prg` source does not need to be
delivered.

Front-end programs call your API with `Clients\VFPWSClient.prg` (guide:
`Clients\README_CLIENT.md`).

## License

| Part | License |
|---|---|
| VFPWebServer program, installer and documentation | Freeware for non-commercial use, provided "as is" - see `LICENSE.txt`. Commercial use requires a license: sales@aryanasoftware.ca |
| `Clients\` (client library) | MIT - see `Clients\LICENSE.txt` |
| `Apps\` (template and samples) | MIT - see `Apps\LICENSE.txt` |

Applications you build and run with VFPWebServer remain yours.

## Requirements

- Windows 7 or later
- The VFP 9 runtime to run the server (included in the installer and the zip)
- Visual FoxPro 9 SP2 to compile your own applications
- Persian and Arabic text: Windows code page 1256 (*Language for
  non-Unicode programs*)

# VFPWSClient - HTTP and JSON for Visual FoxPro 9

`VFPWSClient.prg` lets a Visual FoxPro 9 application call a VFPWebServer API
(or any JSON web API) with a few lines of code. It sends the request, reads
the answer, converts JSON to VFP objects and collections, and reports errors
without stopping the program.

Version 0.3.0 - Copyright (c) 2026 Ramin Orak, Aryana Software

## Contents

1. [Installation](#installation)
2. [Quick start](#quick-start)
3. [Connecting to the server](#connecting-to-the-server)
4. [Sending requests](#sending-requests)
5. [Reading the result](#reading-the-result)
6. [JSON and VFP values](#json-and-vfp-values)
7. [Errors](#errors)
8. [Lists in a grid](#lists-in-a-grid)
9. [Downloading files](#downloading-files)
10. [JSON without HTTP](#json-without-http)
11. [Persian and other languages](#persian-and-other-languages)
12. [A complete form](#a-complete-form)
13. [Reference](#reference)

## Installation

Copy `VFPWSClient.prg` (or the compiled `VFPWSClient.fxp`) into your project
folder and load it once when your application starts:

```foxpro
SET PROCEDURE TO VFPWSClient ADDITIVE
```

In the Project Manager, add the file to the *Code* tab so it is built into
your EXE. Nothing has to be installed or registered: the library uses
WinHttp, which is part of Windows.

## Quick start

```foxpro
SET PROCEDURE TO VFPWSClient ADDITIVE

loApi = CREATEOBJECT("VFPWSHttpClient", "http://192.168.1.10:8080")

loPart = loApi.Get("/parts/A100")
IF loApi.lOk
    ? loPart.name, loPart.price
ELSE
    MESSAGEBOX(loApi.cError, 48, "Parts")
ENDIF
```

Every method works the same way: it returns the answer, and `lOk` tells you
whether the call succeeded.

## Connecting to the server

```foxpro
loApi = CREATEOBJECT("VFPWSHttpClient", "http://192.168.1.10:8080", "vfpws_ab12cd34_...")
```

| Setting | Default | Meaning |
|---|---|---|
| `cBaseUrl` | (first parameter) | Server address, without a trailing `/` |
| `cApiKey` | (second parameter) | Sent as the `X-Api-Key` header when not empty |
| `nTimeout` | `30` | Seconds to wait for sending and receiving |
| `lRaiseErrors` | `.F.` | `.T.` raises a VFP error on failure instead of returning `.NULL.` |

Additional headers are kept for all following requests:

```foxpro
loApi.SetHeader("X-Device", "Kitchen-1")
loApi.SetHeader("X-Device", "")          && removes it
```

Keep one `VFPWSHttpClient` object for the whole application (for example as
a property of your main form or application object) instead of creating one
per call.

## Sending requests

| Method | HTTP | Use |
|---|---|---|
| `Get(cPath [, oQuery])` | GET | Read one record or a list |
| `Post(cPath, uBody)` | POST | Create |
| `Put(cPath, uBody)` | PUT | Replace / update |
| `Patch(cPath, uBody)` | PATCH | Partial update |
| `Delete(cPath [, oQuery])` | DELETE | Delete |
| `PostForm(cPath, oFields)` | POST | HTML form fields |
| `Download(cPath, cFile [, oQuery])` | GET | Save the answer to a file |

### Path values

Values inside the path must be encoded, because a code can contain spaces,
`/` or non-English letters:

```foxpro
loPart = loApi.Get("/parts/" + VFPWS_UrlEncode(ALLTRIM(THISFORM.txtCode.Value)))
```

### Query values

Pass an object; each property becomes `name=value`. `.NULL.` properties are
left out, logical values become `true` / `false`, dates `YYYY-MM-DD`.

```foxpro
loQuery = CREATEOBJECT("Empty")
ADDPROPERTY(loQuery, "search", "bolt")
ADDPROPERTY(loQuery, "limit", 20)

loList = loApi.Get("/parts", loQuery)      && GET /parts?search=bolt&limit=20
```

### Request body

The body can be an object, a collection, or a JSON string. Objects are
converted to JSON automatically, so a record can be sent directly:

```foxpro
* From variables
loCustomer = CREATEOBJECT("Empty")
ADDPROPERTY(loCustomer, "name", "Ali Rezaei")
ADDPROPERTY(loCustomer, "phone", "0912-1234567")
loNew = loApi.Post("/contacts", loCustomer)

* From the current record of a table or cursor
SELECT customers
SCATTER NAME loCustomer MEMO
loApi.Put("/contacts/" + TRANSFORM(customers.id), loCustomer)

* As text
loApi.Post("/contacts", '{"name":"Ali Rezaei","phone":"0912-1234567"}')
```

Property names become JSON field names in lower case. Character values are
sent without trailing spaces.

## Reading the result

After every call:

| Property | Content |
|---|---|
| `lOk` | `.T.` for HTTP status 200 - 299 |
| `nStatus` | HTTP status code; `0` when the server could not be reached |
| `cError` | Error text when `lOk` is `.F.` |
| `uResult` | The value the method returned |
| `cResponse` | The answer as text |
| `cContentType` | Content type of the answer |

The returned value depends on the answer:

| Answer | Returned value |
|---|---|
| JSON object `{...}` | Object, fields as properties: `loPart.name` |
| JSON array `[...]` | Collection: `loList.Count`, `loList.Item(1)`, `FOR EACH` |
| Text, HTML, CSV | Character string |
| Empty (for example `204 No Content`) | `.NULL.` with `lOk = .T.` |
| Error | `.NULL.` with `lOk = .F.` |

Always check `lOk`, not the returned value, because `.NULL.` is also a
correct answer for a successful delete.

```foxpro
loList = loApi.Get("/parts", loQuery)
IF loApi.lOk
    FOR EACH loPart IN loList
        ? loPart.code, loPart.name
    ENDFOR
ENDIF
```

## JSON and VFP values

| JSON | VFP |
|---|---|
| `"text"` | Character |
| `12`, `12.5` | Numeric |
| `true` / `false` | Logical |
| `null` | `.NULL.` |
| `{...}` | Object (class `Empty`) |
| `[...]` | Collection |

Dates arrive as text (`"2026-11-14"`, `"2026-11-14T10:30:00"`), exactly as
JSON sends them. Convert them where you need a date:

```foxpro
dDate = EVALUATE("{^" + loOrder.order_date + "}")          && Date
tTime = EVALUATE("{^" + STRTRAN(loOrder.created, "T", " ") + "}")   && DateTime
```

When sending, Date and DateTime values are converted to these formats
automatically.

Field names that are not valid VFP names are adjusted: `"unit-price"`
becomes `unit_price`, `"2nd"` becomes `_2nd`. The original field order is
kept in the property `_vfpws_order` (a comma-separated list).

To check whether an optional field is present:

```foxpro
IF PEMSTATUS(loPart, "discount", 5)
    ? loPart.discount
ENDIF
```

## Errors

A failed call never stops the program. `lOk` is `.F.`, `nStatus` holds the
HTTP status and `cError` a readable message taken from the server's answer.

| `nStatus` | Meaning | Typical `cError` |
|---|---|---|
| `0` | Server not reached (off, wrong address, firewall, timeout) | `Server not reachable (...)` |
| `401` | API key missing or wrong | `Not authenticated` / `Invalid API key` |
| `404` | Record or address not found | `Part A100 not found` |
| `409` | Record locked by another user | message of the server |
| `422` | Invalid input | `Field required (body.phone)` |
| `500` | Error in the server program | `Internal Server Error` |
| `503` | Server data not available | message of the server |

```foxpro
loPart = loApi.Get("/parts/" + VFPWS_UrlEncode(lcCode))
DO CASE
    CASE loApi.lOk
        THISFORM.ShowPart(loPart)
    CASE loApi.nStatus = 404
        MESSAGEBOX("No part with this code.", 64, "Parts")
    CASE loApi.nStatus = 0
        MESSAGEBOX("The server is not available. Please try again.", 48, "Parts")
    OTHERWISE
        MESSAGEBOX(loApi.cError, 48, "Parts")
ENDCASE
```

To work with `TRY ... CATCH` instead, set `lRaiseErrors = .T.`; a failed call
then raises an error whose message starts with `HTTP <status>:`.

## Lists in a grid

`VFPWS_ToCursor()` turns a list into a cursor, ready for a grid, a report or
SQL:

```foxpro
loList = loApi.Get("/parts", loQuery)
IF loApi.lOk
    VFPWS_ToCursor(loList, "curParts")
    THISFORM.grdParts.RecordSource = "curParts"
ENDIF
```

Column types follow the values: logical (`L`), whole numbers (`I`), decimal
numbers (`B`), text (`C`, or `M` above 254 characters). All columns accept
`.NULL.`. Nested objects or lists are stored as JSON text. The function
returns the number of rows (`-1` on error) and leaves the cursor selected.
An existing cursor with the same alias is replaced.

## Downloading files

```foxpro
IF loApi.Download("/reports/sales.csv", "C:\Temp\sales.csv")
    ? "Saved"
ELSE
    ? loApi.cError
ENDIF
```

## JSON without HTTP

The JSON class can be used on its own, for example for files or for data
from other sources:

```foxpro
loJson = CREATEOBJECT("VFPWSJson")

* Read
loData = loJson.Parse(FILETOSTR("settings.json"))
IF ISNULL(loData) AND NOT EMPTY(loJson.cError)
    ? loJson.cError              && "Expecting ',' delimiter at position 57"
ENDIF

* Write
lcText = loJson.Stringify(loData)
```

`Parse` expects text in the computer's code page. For a UTF-8 file, convert
it first: `loJson.Parse(VFPWS_FromUtf8(FILETOSTR("data.json")))`.
`VFPWSHttpClient` does this automatically.

## Persian and other languages

The server sends UTF-8; the library converts it to the code page of the
computer. Persian and Arabic text is shown correctly when the Windows
setting *Language for non-Unicode programs* is Persian or Arabic (code page
1256). Text sent to the server is converted to UTF-8 the same way.

## A complete form

A search form with a text box, a button and a grid:

```foxpro
* Form.Init
SET PROCEDURE TO VFPWSClient ADDITIVE
THISFORM.AddProperty("oApi", ;
    CREATEOBJECT("VFPWSHttpClient", "http://192.168.1.10:8080", "vfpws_..."))

* cmdSearch.Click
LOCAL loQuery, loList
loQuery = CREATEOBJECT("Empty")
ADDPROPERTY(loQuery, "search", ALLTRIM(THISFORM.txtSearch.Value))
ADDPROPERTY(loQuery, "limit", 100)

loList = THISFORM.oApi.Get("/parts", loQuery)
IF NOT THISFORM.oApi.lOk
    MESSAGEBOX(THISFORM.oApi.cError, 48, "Parts")
    RETURN
ENDIF
THISFORM.grdParts.RecordSource = ""
VFPWS_ToCursor(loList, "curParts")
THISFORM.grdParts.RecordSource = "curParts"
THISFORM.grdParts.Refresh()
```

Clearing `RecordSource` before the cursor is rebuilt keeps the grid's
columns intact.

## Reference

### VFPWSHttpClient

| Member | Description |
|---|---|
| `Init(cBaseUrl [, cApiKey])` | Server address and API key |
| `Get(cPath [, oQuery])` | GET request |
| `Post(cPath, uBody)` | POST with a JSON body |
| `Put(cPath, uBody)` | PUT with a JSON body |
| `Patch(cPath, uBody)` | PATCH with a JSON body |
| `Delete(cPath [, oQuery])` | DELETE request |
| `PostForm(cPath, oFields)` | POST as `application/x-www-form-urlencoded` |
| `Download(cPath, cFile [, oQuery])` | Saves the answer to a file; returns `.T.` / `.F.` |
| `Send(cMethod, cUrl, cBody, cContentType)` | Any other request (full URL) |
| `SetHeader(cName, cValue)` | Extra header for all following requests |
| `BuildUrl(cPath [, oQuery])` | Full address that would be called |
| `cBaseUrl`, `cApiKey`, `nTimeout`, `lRaiseErrors` | Settings |
| `lOk`, `nStatus`, `cError`, `uResult`, `cResponse`, `cContentType` | Result of the last call |

### VFPWSJson

| Member | Description |
|---|---|
| `Parse(cJson)` | JSON text to VFP values; `.NULL.` and `cError` on invalid JSON |
| `Stringify(uValue)` | VFP value (object, collection, record, value) to JSON text |
| `PropertyNames(oObject)` | Field names of an object, in order |
| `cError` | Error of the last `Parse` |

### Functions

| Function | Description |
|---|---|
| `VFPWS_ToCursor(oList, cAlias)` | List (or one object) to a cursor |
| `VFPWS_UrlEncode(cText)` | Text for a URL path or query |
| `VFPWS_ToUtf8(cText)` | Code page text to UTF-8 |
| `VFPWS_FromUtf8(cBytes)` | UTF-8 to code page text |

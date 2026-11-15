<#
  VFPWebServer - automatic API test (sample app.prg)

  Usage (PowerShell 5.1 or 7):
    powershell -ExecutionPolicy Bypass -File .\test_api.ps1
    powershell -ExecutionPolicy Bypass -File .\test_api.ps1 -BaseUrl http://localhost:8080
    powershell -ExecutionPolicy Bypass -File .\test_api.ps1 -ApiKey vfpws_XXXXXXXX_...

  Start the server first (Start Server). When "Require an API key" is on,
  pass a key created in the API Keys window with -ApiKey.
  Every check prints PASS or FAIL; a summary is shown at the end.
#>
param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$ApiKey = ""
)

$script:Passed = 0
$script:Failed = 0
$script:Warned = 0

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = $null,
        [string]$ContentType = "application/json",
        [hashtable]$Headers = @{},
        [switch]$NoKey
    )
    $h = @{}
    foreach ($k in $Headers.Keys) { $h[$k] = $Headers[$k] }
    if ($ApiKey -and -not $NoKey -and -not $h.ContainsKey("X-Api-Key")) { $h["X-Api-Key"] = $ApiKey }

    $req = @{ Uri = "$BaseUrl$Path"; Method = $Method; Headers = $h; UseBasicParsing = $true }
    if ($null -ne $Body -and $Body -ne "") {
        # Send UTF-8 bytes (PowerShell 5.1 would otherwise use ISO-8859-1)
        $req["Body"] = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $req["ContentType"] = $ContentType
    }
    try {
        $r = Invoke-WebRequest @req
        $text = ""
        if ($r.RawContentStream) { $text = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) }
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Content = $text; Type = [string]$r.Headers["Content-Type"] }
    }
    catch {
        $resp = $_.Exception.Response
        if ($null -eq $resp) {
            return [pscustomobject]@{ Status = 0; Content = $_.Exception.Message; Type = "" }
        }
        $text = ""
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
        return [pscustomobject]@{ Status = [int]$resp.StatusCode; Content = $text; Type = "" }
    }
}

function Get-Json($res) {
    if (-not $res.Content) { return $null }
    try { return ($res.Content | ConvertFrom-Json) } catch { return $null }
}

function Test-Case {
    param([string]$Name, $Res, [int]$Expect, [scriptblock]$Check = $null)
    $json = Get-Json $Res
    $ok = ($Res.Status -eq $Expect)
    if ($ok -and $Check) {
        try { $ok = [bool](& $Check $json $Res) } catch { $ok = $false }
    }
    if ($ok) {
        $script:Passed++
        Write-Host ("PASS  " + $Name) -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host ("FAIL  " + $Name) -ForegroundColor Red
        $snippet = $Res.Content
        if ($snippet.Length -gt 300) { $snippet = $snippet.Substring(0, 300) + "..." }
        Write-Host ("      expected $Expect, got " + $Res.Status + "  " + $snippet) -ForegroundColor DarkGray
    }
}

function Test-Error422 {
    param([string]$Name, $Res, [string]$Type, [string[]]$Loc)
    Test-Case $Name $Res 422 {
        param($j)
        $e = @($j.detail)[0]
        ($e.type -eq $Type) -and ((@($e.loc) -join ".") -eq ($Loc -join "."))
    }
}

Write-Host ""
Write-Host "VFPWebServer API test  -  $BaseUrl" -ForegroundColor Cyan
Write-Host ""

# --- Server reachable? ------------------------------------------------
$health = Invoke-Api GET "/api/health"
if ($health.Status -eq 0) {
    Write-Host "The server is not reachable at $BaseUrl. Start the server first." -ForegroundColor Red
    exit 1
}

# --- API key mode -----------------------------------------------------
$probe = Invoke-Api GET "/items" -NoKey
$keysRequired = ($probe.Status -eq 401)
if ($keysRequired -and -not $ApiKey) {
    Write-Host "'Require an API key' is ON. Create a key in the API Keys window and run:" -ForegroundColor Yellow
    Write-Host "   .\test_api.ps1 -ApiKey vfpws_..." -ForegroundColor Yellow
    exit 1
}

Write-Host "-- System" -ForegroundColor Cyan
Test-Case "GET /api/health returns status=running" $health 200 { param($j) $j.status -eq "running" }
Test-Case "GET / (server banner)" (Invoke-Api GET "/") 200 { param($j) $j.server -eq "VFPWebServer" }
Test-Case "GET /unknown -> 404 {detail: Not Found}" (Invoke-Api GET "/no/such/path") 404 { param($j) $j.detail -eq "Not Found" }
Test-Case "DELETE /api/health -> 405 Method Not Allowed" (Invoke-Api DELETE "/api/health") 405 { param($j) $j.detail -eq "Method Not Allowed" }

Write-Host "-- Query parameters" -ForegroundColor Cyan
Test-Case "GET /items returns a list" (Invoke-Api GET "/items") 200 { param($j) @($j).Count -ge 1 }
Test-Case "GET /items?limit=2 returns at most 2" (Invoke-Api GET "/items?limit=2") 200 { param($j) @($j).Count -le 2 }
Test-Case "GET /items?q=capp finds Cappuccino" (Invoke-Api GET "/items?q=capp") 200 { param($j) (@($j).Count -ge 1) -and (@($j)[0].name -like "Cappuccino*") }
Test-Error422 "GET /items?limit=abc -> 422 int_parsing" (Invoke-Api GET "/items?limit=abc") "int_parsing" @("query", "limit")
Test-Error422 "GET /items?limit=500 -> 422 less_than_equal" (Invoke-Api GET "/items?limit=500") "less_than_equal" @("query", "limit")

Write-Host "-- Path parameters" -ForegroundColor Cyan
Test-Case "GET /items/1 returns item 1" (Invoke-Api GET "/items/1") 200 { param($j) $j.id -eq 1 }
Test-Case "GET /items/99999 -> 404 Item not found" (Invoke-Api GET "/items/99999") 404 { param($j) $j.detail -eq "Item not found" }
Test-Error422 "GET /items/abc -> 422 int_parsing" (Invoke-Api GET "/items/abc") "int_parsing" @("path", "item_id")

Write-Host "-- JSON body and model validation" -ForegroundColor Cyan
$created = Invoke-Api POST "/items" '{"name":"Test item","price":12.5}'
Test-Case "POST /items -> 201 with defaults (in_stock=true, category=general)" $created 201 {
    param($j) ($j.id -gt 0) -and ($j.in_stock -eq $true) -and ($j.category -eq "general") -and ($j.price -eq 12.5)
}
$newId = (Get-Json $created).id

Test-Error422 "POST without name -> 422 missing" (Invoke-Api POST "/items" '{"price":1}') "missing" @("body", "name")
Test-Error422 "POST name longer than 60 -> 422 string_too_long" (Invoke-Api POST "/items" ('{"name":"' + ("x" * 61) + '","price":1}')) "string_too_long" @("body", "name")
Test-Error422 "POST price 'abc' -> 422 float_parsing" (Invoke-Api POST "/items" '{"name":"A","price":"abc"}') "float_parsing" @("body", "price")
Test-Error422 "POST price -1 -> 422 greater_than_equal" (Invoke-Api POST "/items" '{"name":"A","price":-1}') "greater_than_equal" @("body", "price")
Test-Error422 "POST category 'toys' -> 422 enum" (Invoke-Api POST "/items" '{"name":"A","price":1,"category":"toys"}') "enum" @("body", "category")
Test-Error422 "POST invalid JSON -> 422 json_invalid" (Invoke-Api POST "/items" '{"name": ') "json_invalid" @("body")

# Persian text round trip (needs code page 1256 for non-Unicode programs)
$persian = "پیتزا مخصوص"
$fa = Invoke-Api POST "/items" ('{"name":"' + $persian + '","price":9}')
$faJson = Get-Json $fa
if ($fa.Status -eq 201 -and $faJson.name -eq $persian) {
    $script:Passed++
    Write-Host "PASS  Persian name is stored and returned as UTF-8" -ForegroundColor Green
}
else {
    $script:Warned++
    Write-Host "WARN  Persian name round trip failed (Windows 'language for non-Unicode programs' must be Persian, code page 1256)" -ForegroundColor Yellow
}
if ($fa.Status -eq 201) { [void](Invoke-Api DELETE ("/items/" + $faJson.id)) }

Write-Host "-- Update / delete / other responses" -ForegroundColor Cyan
if ($newId) {
    Test-Case "PUT /items/$newId updates the item" (Invoke-Api PUT "/items/$newId" '{"name":"Updated item","price":15,"category":"food"}') 200 {
        param($j) ($j.name -eq "Updated item") -and ($j.category -eq "food")
    }
    Test-Case "GET /items/$newId/html -> HTMLResponse" (Invoke-Api GET "/items/$newId/html") 200 {
        param($j, $r) $r.Type -like "text/html*"
    }
    Test-Case "DELETE /items/$newId -> 204 No Content" (Invoke-Api DELETE "/items/$newId") 204
    Test-Case "GET /items/$newId after delete -> 404" (Invoke-Api GET "/items/$newId") 404
}
else {
    $script:Failed++
    Write-Host "FAIL  update/delete tests skipped (POST did not return an id)" -ForegroundColor Red
}

Write-Host "-- Form, header, text and file responses" -ForegroundColor Cyan
Test-Case "GET /demo/hello/Ali -> PlainTextResponse" (Invoke-Api GET "/demo/hello/Ali") 200 {
    param($j, $r) ($r.Content -eq "Hello, Ali!") -and ($r.Type -like "text/plain*")
}
Test-Case "POST /demo/contact (form) reads the fields" (Invoke-Api POST "/demo/contact" "email=ali%40example.com&message=Hello" "application/x-www-form-urlencoded") 200 {
    param($j) ($j.email -eq "ali@example.com") -and ($j.message_length -eq 5)
}
Test-Error422 "POST /demo/contact without message -> 422 missing" (Invoke-Api POST "/demo/contact" "email=a%40b.c" "application/x-www-form-urlencoded") "missing" @("body", "message")
Test-Case "GET /demo/whoami reads the X-Client-Name header" (Invoke-Api GET "/demo/whoami" -Headers @{ "X-Client-Name" = "TestScript" }) 200 {
    param($j) $j.client_name -eq "TestScript"
}
Test-Case "GET /demo/report.csv -> text/csv download" (Invoke-Api GET "/demo/report.csv") 200 {
    param($j, $r) ($r.Type -like "text/csv*") -and ($r.Content -like "id,name,price*")
}

Write-Host "-- Documentation" -ForegroundColor Cyan
Test-Case "GET /openapi.json contains the declared routes and models" (Invoke-Api GET "/openapi.json") 200 {
    param($j) ($null -ne $j.paths."/items/{item_id}") -and ($null -ne $j.components.schemas.ItemIn)
}
Test-Case "GET /docs (Swagger UI)" (Invoke-Api GET "/docs") 200 { param($j, $r) $r.Content -like "*swagger-ui*" }
Test-Case "GET /redoc (ReDoc)" (Invoke-Api GET "/redoc") 200 { param($j, $r) $r.Content -like "*redoc*" }

if ($keysRequired) {
    Write-Host "-- API keys (Require an API key is ON)" -ForegroundColor Cyan
    Test-Case "GET /items without a key -> 401" $probe 401 { param($j) $j.detail -eq "Not authenticated" }
    Test-Case "GET /items with a wrong key -> 401" (Invoke-Api GET "/items" -Headers @{ "X-Api-Key" = "vfpws_AAAAAAAA_wrongwrongwrongwrongwrongwrongwrongwrongwro" }) 401
    Test-Case "GET /api/health is public (no key)" (Invoke-Api GET "/api/health" -NoKey) 200
}
else {
    Write-Host ""
    Write-Host "Note: 'Require an API key' is OFF - key checks were not tested." -ForegroundColor DarkGray
}

Write-Host ""
$color = "Green"
if ($script:Failed -gt 0) { $color = "Red" }
Write-Host ("Passed: " + $script:Passed + "   Failed: " + $script:Failed + "   Warnings: " + $script:Warned) -ForegroundColor $color
if ($script:Failed -gt 0) { exit 1 }
exit 0

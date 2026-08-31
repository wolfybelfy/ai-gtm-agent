# lib.ps1 - shared helpers for trigger-system scripts (PowerShell 5.1).
# Dot-source from sibling scripts:  . (Join-Path $PSScriptRoot 'lib.ps1')
# Design rules: atomic writes (temp + rename), no BOM in machine-read files,
# big-JSON safe parsing (PS 5.1 ConvertFrom-Json chokes on multi-MB payloads).

Set-StrictMode -Version 2.0

function Get-TriggerSystemRoot {
    # scripts\ lives directly under the repo root
    Split-Path -Parent $PSScriptRoot
}

function Write-AtomicText {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $tmp = "$Path.tmp"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmp, $Content, $utf8NoBom)
    Move-Item -Force -Path $tmp -Destination $Path
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLower()
}

function ConvertFrom-JsonBig {
    # PS 5.1's ConvertFrom-Json fails on large payloads (JavaScriptSerializer default cap).
    # Returns Dictionary/object[] shapes from JavaScriptSerializer on the fallback path,
    # so consumers MUST use Get-JsonProp/Get-JsonCount instead of naked property access.
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Text)
    $t = $Text
    if ($t.Length -gt 0 -and [int]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }  # strip BOM
    try {
        return ($t | ConvertFrom-Json)
    } catch {
        Add-Type -AssemblyName System.Web.Extensions
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int]::MaxValue
        $ser.RecursionLimit = 1000
        return $ser.DeserializeObject($t)
    }
}

function Get-JsonProp {
    # Property access that works for both PSCustomObject and IDictionary shapes.
    param($Obj, [Parameter(Mandatory=$true)][string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [System.Collections.IDictionary]) {
        if ($Obj.Contains($Name)) { return $Obj[$Name] } else { return $null }
    }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -ne $p) { return $p.Value } else { return $null }
}

function Get-JsonCount {
    # Count for arrays/collections regardless of parser shape. $null -> 0, scalar -> 1.
    param($Obj)
    if ($null -eq $Obj) { return 0 }
    if ($Obj -is [System.Collections.ICollection]) { return $Obj.Count }
    return 1
}

function Use-Tls12 {
    # PS 5.1 may default to an older protocol; ADD Tls12 without clobbering existing flags.
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
}

function Get-HttpResponseText {
    # Decode a response body CORRECTLY.
    #
    # BUG THIS FIXES (found 2026-07-29, present in every capture since 2026-07-28): PS 5.1's
    # Invoke-WebRequest decodes the body with the charset declared in the Content-Type header and
    # falls back to ISO-8859-1 when none is declared. Most JSON APIs declare none - and JSON is
    # UTF-8 by specification - so "Sao Paulo" with a tilde came back as double-encoded mojibake
    # and was then written to disk as UTF-8, permanently corrupting it. 291 occurrences across 24
    # account/day pairs, including thomson-reuters and autodesk.
    #
    # So: honour an explicitly declared charset, otherwise decode as UTF-8, never Latin-1.
    param($Response)
    $bytes = $null
    try { $bytes = $Response.RawContentStream.ToArray() } catch { $bytes = $null }
    if ($null -eq $bytes -or $bytes.Length -eq 0) { return [string]$Response.Content }

    $enc = [System.Text.Encoding]::UTF8
    $ct = ''
    try { if ($Response.Headers.ContainsKey('Content-Type')) { $ct = [string]$Response.Headers['Content-Type'] } } catch { $ct = '' }
    if ($ct -match 'charset\s*=\s*"?([^;",\s]+)') {
        try { $enc = [System.Text.Encoding]::GetEncoding($Matches[1]) } catch { $enc = [System.Text.Encoding]::UTF8 }
    }
    $text = $enc.GetString($bytes)
    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Invoke-HttpGetRaw {
    # GET a URL; returns @{ ok; status; content; err }. Never throws.
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [int]$TimeoutSec = 60,
        [string]$UserAgent = 'trigger-system-snapshot/1.0'
    )
    try {
        $r = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec $TimeoutSec -UserAgent $UserAgent
        return @{ ok = $true; status = [int]$r.StatusCode; content = (Get-HttpResponseText -Response $r); err = '' }
    } catch [System.Net.WebException] {
        $status = 0
        if ($null -ne $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $status; content = ''; err = $_.Exception.Message }
    } catch {
        return @{ ok = $false; status = 0; content = ''; err = $_.Exception.Message }
    }
}

function Invoke-HttpPostJsonRaw {
    # POST a JSON body; same contract as Invoke-HttpGetRaw.
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$BodyJson,
        [int]$TimeoutSec = 60,
        [string]$UserAgent = 'trigger-system-snapshot/1.0'
    )
    try {
        $r = Invoke-WebRequest -Uri $Url -Method Post -Body $BodyJson -ContentType 'application/json' `
             -UseBasicParsing -TimeoutSec $TimeoutSec -UserAgent $UserAgent
        return @{ ok = $true; status = [int]$r.StatusCode; content = (Get-HttpResponseText -Response $r); err = '' }
    } catch [System.Net.WebException] {
        $status = 0
        if ($null -ne $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; status = $status; content = ''; err = $_.Exception.Message }
    } catch {
        return @{ ok = $false; status = 0; content = ''; err = $_.Exception.Message }
    }
}

function New-RunId {
    param([Parameter(Mandatory=$true)][string]$DateStamp)
    "$DateStamp-" + [guid]::NewGuid().ToString('N').Substring(0, 8)
}

function Invoke-HubSpotApi {
    # Minimal HubSpot v3 caller. Token comes from the caller (env var) and is NEVER logged.
    # Returns @{ ok; status; data; err }. Never throws.
    param(
        [Parameter(Mandatory=$true)][ValidateSet('GET','POST','PATCH','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,     # e.g. /crm/v3/properties/companies/groups
        $Body = $null,
        [Parameter(Mandatory=$true)][string]$Token
    )
    Use-Tls12
    $uri = 'https://api.hubapi.com' + $Path
    $headers = @{ Authorization = "Bearer $Token" }
    try {
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 10
            # PS 5.1 encodes STRING bodies as Latin-1 on the wire, so any non-ASCII char became
            # an invalid UTF-8 byte (live HubSpot 400 "Invalid UTF-8 start byte 0xa7",
            # 2026-08-26). BYTE bodies are sent verbatim - encode UTF-8 here, once, for every caller.
            $bytes = [Text.Encoding]::UTF8.GetBytes($json)
            $r = Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $bytes -ContentType 'application/json; charset=utf-8'
        } else {
            $r = Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }
        return @{ ok = $true; status = 200; data = $r; err = '' }
    } catch [System.Net.WebException] {
        $status = 0; $detail = $_.Exception.Message
        if ($null -ne $_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            # $_.ErrorDetails already holds the error body PS drained; re-reading the response
            # stream returns '' (this blanked every 400 during the 2026-08-26 push and hid the
            # root cause). Prefer ErrorDetails; the stream read stays as fallback.
            if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message)) {
                $detail = $_.ErrorDetails.Message
            } else {
                try {
                    $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $detail = $sr.ReadToEnd(); $sr.Close()
                } catch {}
            }
        }
        return @{ ok = $false; status = $status; data = $null; err = $detail }
    } catch {
        return @{ ok = $false; status = 0; data = $null; err = $_.Exception.Message }
    }
}

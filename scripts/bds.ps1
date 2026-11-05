<#
.SYNOPSIS
  Oeffnen, Speichern und Pruefen von baramundi-Automation-Studio-Skripten (.bds).
.DESCRIPTION
  .bds-Dateien sind XML in ISO-8859-1 mit CRLF. Bearbeitet wird eine UTF-8-Arbeitskopie
  (Write/Edit); 'save' prueft sie wie 'check' und schreibt erst dann die .bds.

    bds.ps1 open  <Datei.bds> <Arbeitskopie.xml> [-Normalize]
    bds.ps1 save  <Arbeitskopie.xml> <Datei.bds> [-Backup]
    bds.ps1 check <Datei.bds>

  Exitcodes: 0 = in Ordnung (Hinweise moeglich), 1 = Fehler gefunden, 2 = Aufruf- oder Dateifehler.
  Die Regeln (Aktionstypen, Elementreihenfolge ...) stehen in schema.json; bds.py nutzt dieselben.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][ValidateSet('open', 'save', 'check')][string]$Command,
    [Parameter(Mandatory = $true, Position = 1)][string]$Path,
    [Parameter(Position = 2)][string]$Target,
    [switch]$Normalize,   # open: Skripte im UTF-8+BOM-Altformat nach Latin-1 umstellen
    [switch]$Backup       # save: vorhandene Zieldatei vorher als .bak sichern
)
$ErrorActionPreference = 'Stop'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
$Utf8 = New-Object Text.UTF8Encoding $false
$Bom = [string][char]0xEF + [char]0xBB + [char]0xBF   # UTF-8-BOM, so wie er in Latin-1 gelesen aussieht
$VarRe = '\{(%?[A-Za-z_][A-Za-z0-9_.]*%?)\}'
$Schema = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'schema.json'), $Utf8) | ConvertFrom-Json
$Errors = New-Object Collections.Generic.List[string]
$Hints = New-Object Collections.Generic.List[string]

function Get-Val($Node, [string]$Name) {
    $n = $Node.SelectSingleNode($Name)
    if ($n) { $n.InnerText } else { '' }
}

function Get-Prop($Obj, [string]$Name) {
    # Eigenschaft aus schema.json mit exakter Schreibweise
    $Obj.PSObject.Properties | Where-Object { $_.Name -ceq $Name } | Select-Object -First 1
}

function Test-Bds([string]$Text) {
    if (-not $Text.StartsWith('<?xml version="1.0" encoding="ISO-8859-1"?>')) { $Errors.Add('Erste Zeile muss <?xml version="1.0" encoding="ISO-8859-1"?> sein.') }
    $doc = New-Object Xml.XmlDocument
    try { $doc.LoadXml($Text) } catch { $Errors.Add("XML nicht wohlgeformt: $($_.Exception.Message)"); return }
    $root = $doc.DocumentElement
    # Elementnamen immer ueber LocalName lesen: .Name liefert bei einem Kindelement <NAME> dieses Kind
    if ($root.LocalName -cne 'baramundiDeployScript') { $Errors.Add("Wurzelelement <$($root.LocalName)> statt <baramundiDeployScript>."); return }
    if ($root.GetAttribute('Version') -ne $Schema.version) { $Hints.Add("Version=""$($root.GetAttribute('Version'))"", erwartet $($Schema.version).") }
    if ($root.GetAttribute('LastChange') -notmatch '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}$') { $Errors.Add('LastChange fehlt oder ist nicht TT.MM.JJJJ hh:mm:ss.') }
    if (-not $root.SelectSingleNode('META/INFO') -or -not $root.SelectSingleNode('META/STATICVARS/BMSVars')) { $Errors.Add('META/INFO oder META/STATICVARS/BMSVars fehlt.') }
    if (-not $root.SelectSingleNode('ACTIONS')) { $Errors.Add('ACTIONS fehlt.'); return }
    $actions = @($root.SelectNodes('ACTIONS/ACTION'))
    if ($actions.Count -eq 0) { $Errors.Add('Keine Aktionen.'); return }

    $defined = @{}; $condVars = @{}; $exitVars = [ordered]@{}   # Hashtables: Gross-/Kleinschreibung egal wie bei baramundi
    $labels = @{}; $subs = @{}
    $jumps = New-Object Collections.Generic.List[object]
    $refs = New-Object Collections.Generic.List[object]
    $x64 = $false; $stack = @{}; $prevLevel = -1; $lastTop = $null; $i = 0

    foreach ($a in $actions) {
        $i++
        $t = $a.GetAttribute('type'); $id = "#$i $t"

        # Attribute und Einrueckung (level)
        foreach ($att in 'level', 'breakpoint', 'ignore_error', 'comment', 'is_included', 'logging_enabled') {
            if (-not $a.HasAttribute($att)) { $Errors.Add("${id}: Attribut $att fehlt.") }
            elseif ($att -ne 'level' -and $a.GetAttribute($att) -notmatch '^[01]$') { $Errors.Add("${id}: $att muss 0 oder 1 sein.") }
        }
        $lvl = 0
        if (-not [int]::TryParse($a.GetAttribute('level'), [ref]$lvl)) { $Errors.Add("${id}: level ist keine Zahl."); $lvl = [Math]::Max($prevLevel, 0) }
        if ($i -eq 1) { if ($lvl -ne 0) { $Errors.Add("${id}: die erste Aktion braucht level 0.") } }
        elseif ($lvl -gt $prevLevel + 1) { $Errors.Add("${id}: level springt von $prevLevel auf $lvl.") }
        elseif ($lvl -eq $prevLevel + 1 -and $Schema.containers -notcontains $stack[$prevLevel]) { $Errors.Add("${id}: einruecken geht nur unter Comment, Conditional oder Subroutine (darueber steht $($stack[$prevLevel])).") }
        $inBody = $false
        for ($l = 0; $l -lt $lvl; $l++) { if ($stack[$l] -in 'Conditional', 'Subroutine') { $inBody = $true } }
        $stack[$lvl] = $t; $prevLevel = $lvl
        if (-not $inBody -and $t -notin 'Subroutine', 'Comment') { $lastTop = $a }

        # Typ, DATA-Aufbau, CONDITION
        $sig = Get-Prop $Schema.actions $t
        if (-not $sig) { $Errors.Add("${id}: unbekannter Aktionstyp (erlaubt sind nur die Typen aus schema.json)."); continue }
        $elems = @($a.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
        if ($elems.Count -eq 0 -or $elems[0].LocalName -cne 'DATA') { $Errors.Add("${id}: erstes Kindelement muss DATA sein."); continue }
        $data = $elems[0]
        $rest = @($elems | Select-Object -Skip 1)
        if ($rest.Count -gt 1 -or ($rest.Count -eq 1 -and $rest[0].LocalName -cne 'CONDITION')) { $Errors.Add("${id}: nach DATA ist nur ein CONDITION-Element erlaubt.") }
        $have = @($data.ChildNodes | Where-Object { $_.NodeType -eq 'Element' } | ForEach-Object { $_.LocalName }) -join ','
        $want = @($sig.Value) -join ','
        if ($have -cne $want) { $Errors.Add("${id}: DATA enthaelt [$have], erwartet [$want] (Namen und Reihenfolge).") }
        $cond = $a.SelectSingleNode('CONDITION')
        if ($cond) {
            if ($Schema.condition_ops -cnotcontains $cond.GetAttribute('op')) { $Errors.Add("${id}: Vergleich op=""$($cond.GetAttribute('op'))"" ist unbekannt.") }
            if ($cond.GetAttribute('options') -notmatch '^[0-3]$') { $Errors.Add("${id}: CONDITION options muss 0 bis 3 sein.") }
            foreach ($m in [regex]::Matches($cond.GetAttribute('op1') + ' ' + $cond.GetAttribute('op2'), $VarRe)) {
                $condVars[$m.Groups[1].Value] = $true
                $refs.Add(@($m.Groups[1].Value, $id, $false))
            }
        }

        # Variablen: gesetzte merken, verwendete sammeln
        $names = New-Object Collections.Generic.List[string]   # Variablennamen dieser Aktion (gesetzt und verwendet)
        foreach ($n in 'VARNAME', 'PIDVARNAME') { $v = Get-Val $data $n; if ($v) { $defined[$v] = $true; $names.Add($v) } }
        if ($t -ne 'Comment') {
            foreach ($tn in $data.SelectNodes('.//text()')) {
                foreach ($m in [regex]::Matches($tn.Value, $VarRe)) {
                    $refs.Add(@($m.Groups[1].Value, $id, ($tn.ParentNode.LocalName -ceq 'SCRIPT')))
                    $names.Add($m.Groups[1].Value)
                }
            }
            if ($a.GetAttribute('logging_enabled') -eq '1' -and ($names -match 'passw|kennw|secret|token|pwd')) {
                $Hints.Add("${id}: verwendet offenbar ein Kennwort/Geheimnis und wird protokolliert - logging_enabled=""0"" setzen.")
            }
        }

        # x64-Modus: Netzwerk, Registry, System32
        if ($t -notin 'EvalVar', 'Comment') {
            $isNet = $false
            foreach ($n in 'SOURCE', 'DESTINATION', 'NAME', 'FILENAME', 'COMMAND', 'TARGET', 'INIFILE') { if ((Get-Val $data $n) -match '^(\\\\|\{DIP\})') { $isNet = $true } }
            if ($isNet -and $x64) { $Hints.Add("${id}: Netzwerkpfad im x64-Modus - laut Doku kann das scheitern, davor SetX64Mode 0.") }
        }
        $hklmSoft = (Get-Val $data 'REGISTRY') -eq '2147483650' -and (Get-Val $data 'REGKEY') -match '^software\\'
        if ($t -ceq 'EvalVar' -and (Get-Val $data 'SOURCE') -ceq 'Registry') {
            $p = @{}; foreach ($pe in $data.SelectNodes('Properties/PropertyEntry')) { $p[(Get-Val $pe 'Param')] = Get-Val $pe 'Value' }
            $hklmSoft = $p['Registry'] -eq 'HKEY_LOCAL_MACHINE' -and $p['Key'] -match '^software\\'
        }
        if ($hklmSoft -and -not $x64) { $Hints.Add("${id}: HKLM\SOFTWARE im 32-Bit-Modus landet in WOW6432Node - fuer den 64-Bit-Zweig davor SetX64Mode 1.") }
        if (-not $x64 -and $t -notin 'Comment', 'RunEmbeddedScript', 'RunEmbeddedCmd' -and $data.InnerText -match '\\system32\\') {
            $Hints.Add("${id}: System32-Pfad im 32-Bit-Modus wird nach SysWOW64 umgeleitet - davor SetX64Mode 1.")
        }

        # Typbezogene Pruefungen
        $svc = Get-Prop $Schema.service_types $t
        if ($svc -and (Get-Val $data 'TYPE') -ne $svc.Value) { $Errors.Add("${id}: TYPE muss $($svc.Value) sein.") }
        if ($t -in 'RunEmbeddedScript', 'RunEmbeddedCmd', 'LaunchProcess') {
            $rc = Get-Val $data 'RETURNCODES'; $vn = Get-Val $data 'VARNAME'
            if ($rc -eq '*' -and -not $vn) { $Hints.Add("${id}: RETURNCODES * ohne VARNAME - jeder Exitcode zaehlt als Erfolg und wird nicht ausgewertet.") }
            elseif ($rc -eq '*') { $exitVars[$vn] = $id }
        }
        switch -CaseSensitive ($t) {
            'EvalVar' {
                $src = Get-Val $data 'SOURCE'; $w = Get-Prop $Schema.evalvar_sources $src
                $got = @($data.SelectNodes('Properties/PropertyEntry/Param') | ForEach-Object { $_.InnerText }) -join ','
                if (-not $w) { $Errors.Add("${id}: SOURCE '$src' ist unbekannt.") }
                elseif ($got -cne (@($w.Value) -join ',')) { $Errors.Add("${id}: Properties [$got], erwartet [$(@($w.Value) -join ',')].") }
            }
            'Wait' {
                $wt = Get-Val $data 'TYPE'; $w = Get-Prop $Schema.wait_types $wt
                $got = @($data.SelectNodes('Properties/PropertyEntry/Param') | ForEach-Object { $_.InnerText }) -join ','
                if (-not $w) { $Errors.Add("${id}: TYPE '$wt' ist unbekannt.") }
                elseif ($got -cne (@($w.Value) -join ',')) { $Errors.Add("${id}: Properties [$got], erwartet [$(@($w.Value) -join ',')].") }
            }
            'SetX64Mode' {
                $mode = Get-Val $data 'MODE'
                if ($mode -eq '1') { $x64 = $true } elseif ($mode -eq '0') { $x64 = $false } else { $Errors.Add("${id}: MODE muss 0 oder 1 sein.") }
            }
            'EndBDS' {
                $mode = Get-Val $data 'RETURNMODESTR'
                if ($mode -notmatch '^[012]$') { $Errors.Add("${id}: RETURNMODESTR muss 0 (Fehler), 1 (Erfolg) oder 2 (Rueckgabewert) sein.") }
                elseif ($mode -eq '2' -and -not (Get-Val $data 'RETURNCODESTR')) { $Errors.Add("${id}: Modus 2 (Rueckgabewert) ohne RETURNCODESTR.") }
                if ((Get-Val $data 'RETURNMESSAGE') -match '\$[A-Za-z]') { $Hints.Add("${id}: Meldung enthaelt eine PowerShell-Variable - baramundi ersetzt nur {Variablen}.") }
            }
            'Label' { $n = Get-Val $data 'NAME'; if ($labels.ContainsKey($n)) { $Errors.Add("${id}: Sprungmarke '$n' gibt es doppelt.") }; $labels[$n] = $true }
            'Subroutine' { $n = Get-Val $data 'NAME'; if ($subs.ContainsKey($n)) { $Errors.Add("${id}: Unterroutine '$n' gibt es doppelt.") }; $subs[$n] = $true }
            'GotoLabel' { $jumps.Add(@($id, 'Sprungmarke', (Get-Val $data 'NAME'))) }
            'CallSubroutine' { $jumps.Add(@($id, 'Unterroutine', (Get-Val $data 'NAME'))) }
            'RunEmbeddedScript' {
                $lang = Get-Val $data 'SCRIPTLANGUAGE'
                if ($Schema.script_languages -cnotcontains $lang) { $Hints.Add("${id}: SCRIPTLANGUAGE '$lang' ist in den Beispielen nicht belegt - im Automation Studio pruefen.") }
                $code = Get-Val $data 'SCRIPT'
                if ($code.StartsWith($Bom)) {
                    $Hints.Add("${id}: Skript im UTF-8+BOM-Altformat (Umlaute im Editor unlesbar) - mit 'open -Normalize' nach Latin-1 umstellen.")
                    $code = $Utf8.GetString($Latin1.GetBytes($code)).Substring(1)
                }
                elseif ($code -match '\xC3[\x80-\xBF]') { $Hints.Add("${id}: Skript enthaelt UTF-8-Bytefolgen in Latin-1-Text - Kodierung pruefen.") }
                if ($lang -like 'PowerShell*') {
                    if (-not $x64) { $Hints.Add("${id}: x64-Modus ist aus - PowerShell laeuft als 32-Bit-Prozess.") }
                    $tok = $null; $perr = $null
                    [void][Management.Automation.Language.Parser]::ParseInput($code, [ref]$tok, [ref]$perr)
                    foreach ($pe in $perr) { $Errors.Add("${id}: PowerShell-Syntax, Skriptzeile $($pe.Extent.StartLineNumber): $($pe.Message)") }
                }
            }
        }
    }

    # Querverweise
    foreach ($j in $jumps) {
        $set = if ($j[1] -eq 'Sprungmarke') { $labels } else { $subs }
        if (-not $set.ContainsKey($j[2])) { $Errors.Add("$($j[0]): $($j[1]) '$($j[2])' existiert nicht.") }
    }
    $unknown = [ordered]@{}
    foreach ($r in $refs) {
        $n = $r[0]
        if ($defined.ContainsKey($n) -or $n -match '^%.+%$' -or $Schema.builtin_variables -contains $n) { continue }
        if (@($Schema.variable_prefixes | Where-Object { $n.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { continue }
        $key = if ($r[2]) { "Platzhalter {$n} im Skript" } else { "{$n}" }
        if (-not $unknown.Contains($key)) { $unknown[$key] = New-Object Collections.Generic.List[string] }
        if (-not $unknown[$key].Contains($r[1])) { $unknown[$key].Add($r[1]) }
    }
    foreach ($k in $unknown.Keys) { $Hints.Add("$k ist weder gesetzt noch bekannt und bliebe zur Laufzeit als Text stehen (Tippfehler?): $($unknown[$k] -join ', ')") }
    foreach ($k in $exitVars.Keys) { if (-not $condVars.ContainsKey($k)) { $Hints.Add("$($exitVars[$k]): Exitcode in {$k} wird in keiner Bedingung ausgewertet.") } }
    if (-not $lastTop -or $lastTop.GetAttribute('type') -cne 'EndBDS' -or $lastTop.SelectSingleNode('CONDITION')) {
        $Hints.Add('Die zuletzt ausgefuehrte Aktion ist kein bedingungsloses EndBDS - Auffang fuer unerwartete Faelle fehlt.')
    }
}

function Open-Bds([string]$In, [string]$Out) {
    $text = $Latin1.GetString([IO.File]::ReadAllBytes($In))
    $sb = New-Object Text.StringBuilder; $pos = 0; $legacy = 0; $converted = 0
    foreach ($m in [regex]::Matches($text, '<SCRIPT>([\s\S]*?)</SCRIPT>')) {
        $g = $m.Groups[1]; $body = $g.Value
        if ($body.StartsWith($Bom)) {
            $legacy++
            if ($Normalize) {
                $dec = $Utf8.GetString($Latin1.GetBytes($body)).Substring(1)
                if ($dec -match '[^\x00-\xFF]') { $Hints.Add("Skript ab Zeichen $($g.Index) enthaelt Zeichen ausserhalb von Latin-1 und bleibt im UTF-8-Altformat.") }
                else { $body = $dec -replace '\r?\n', "`r`n"; $converted++ }
            }
        }
        [void]$sb.Append($text.Substring($pos, $g.Index - $pos)).Append($body)
        $pos = $g.Index + $g.Length
    }
    [void]$sb.Append($text.Substring($pos))
    [IO.File]::WriteAllText($Out, $sb.ToString(), $Utf8)
    Write-Output "Arbeitskopie (UTF-8): $Out"
    if ($legacy) { Write-Output "Skripte im UTF-8+BOM-Altformat: $legacy, nach Latin-1 umgestellt: $converted" }
    if ($legacy -gt $converted -and -not $Normalize) { $Hints.Add('Vor Aenderungen in diesen Skripten mit -Normalize oeffnen; ohne Aenderung bleiben sie byte-genau erhalten.') }
}

function Save-Bds([string]$In, [string]$Out) {
    $text = [IO.File]::ReadAllText($In, $Utf8)
    # CRLF ueberall, ausser in Skripten im UTF-8+BOM-Altformat (die bleiben byte-genau)
    $sb = New-Object Text.StringBuilder
    foreach ($part in [regex]::Split($text, '(<SCRIPT>[\s\S]*?</SCRIPT>)')) {
        if ($part.StartsWith('<SCRIPT>' + $Bom)) { [void]$sb.Append($part) } else { [void]$sb.Append(($part -replace '\r?\n', "`r`n")) }
    }
    $text = $sb.ToString()
    if (-not $text.EndsWith("`r`n")) { $text += "`r`n" }
    # Edit vereinheitlicht Zeilenenden der ganzen Datei. Altformat-Skripte, die inhaltlich gleich geblieben sind,
    # deshalb byte-genau aus der vorhandenen Zieldatei uebernehmen.
    if (Test-Path -LiteralPath $Out) {
        $legacyRe = '<SCRIPT>' + [regex]::Escape($Bom) + '[\s\S]*?</SCRIPT>'
        $orig = New-Object 'Collections.Generic.Dictionary[string,string]'
        foreach ($m in [regex]::Matches($Latin1.GetString([IO.File]::ReadAllBytes($Out)), $legacyRe)) { $orig[$m.Value.Replace("`r`n", "`n")] = $m.Value }
        $text = [regex]::Replace($text, $legacyRe, [Text.RegularExpressions.MatchEvaluator] {
                param($m) $k = $m.Value.Replace("`r`n", "`n"); if ($orig.ContainsKey($k)) { $orig[$k] } else { $m.Value } })
    }
    $now = Get-Date -Format 'dd.MM.yyyy HH:mm:ss'
    $text = ([regex]'(<baramundiDeployScript\b[^>]*?\bLastChange=")[^"]*"').Replace($text, '${1}' + $now + '"', 1)
    foreach ($m in @([regex]::Matches($text, '[^\x00-\xFF]') | Select-Object -First 10)) {
        $line = ($text.Substring(0, $m.Index) -split "`n").Count
        $Errors.Add("Zeile ${line}: Zeichen U+$(([int][char]$m.Value[0]).ToString('X4')) gibt es in ISO-8859-1 nicht (z. B. typografische Anfuehrungszeichen, Gedankenstrich, Euro) - ersetzen.")
    }
    if ($Errors.Count -eq 0) { Test-Bds $text }
    if ($Errors.Count -gt 0) { Write-Output 'Nicht gespeichert.'; return }
    if (Test-Path -LiteralPath $Out) {
        if (-not $Backup) { $Errors.Add("$Out existiert bereits - mit -Backup ueberschreiben (legt eine .bak-Sicherung an) oder anderen Namen waehlen."); return }
        $bak = "$Out.bak"
        if (Test-Path -LiteralPath $bak) { $bak = "$Out.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak" }
        Copy-Item -LiteralPath $Out -Destination $bak
        Write-Output "Sicherung: $bak"
    }
    [IO.File]::WriteAllBytes($Out, $Latin1.GetBytes($text))
    Write-Output "Gespeichert: $Out (ISO-8859-1, CRLF)"
}

try {
    $src = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if ($Command -ne 'check' -and -not $Target) { throw "Ziel fehlt: bds.ps1 $Command <Quelle> <Ziel>" }
    if ($Target) { $dst = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target) }
    switch ($Command) {
        'open' { Open-Bds $src $dst }
        'save' { Save-Bds $src $dst }
        'check' { Test-Bds ($Latin1.GetString([IO.File]::ReadAllBytes($src))) }
    }
}
catch { Write-Output "FEHLER: $($_.Exception.Message)"; exit 2 }
foreach ($e in $Errors) { Write-Output "FEHLER: $e" }
foreach ($h in $Hints) { Write-Output "HINWEIS: $h" }
Write-Output ('Ergebnis: {0} Fehler, {1} Hinweise.' -f $Errors.Count, $Hints.Count)
if ($Errors.Count) { exit 1 } else { exit 0 }

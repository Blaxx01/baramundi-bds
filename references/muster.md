# Muster im Hausstil

Arbeitskopie-Format (UTF-8, so wie sie mit Write/Edit entsteht); `save` macht daraus die .bds. Die Vorlagen der
einzelnen Aktionen stehen in `aktionen.md`.

## Inhalt

1. Gerüst einer .bds
2. Abschnitte und Einrückung
3. Job-Parameter übernehmen (Text, Ja/Nein, Geheimnis)
4. Eingebettetes PowerShell: Gerüst und Regeln
5. Vollständiges Beispiel: Check_TaskUser im Hausstil

## 1. Gerüst

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<baramundiDeployScript Version="2620" LastChange="01.01.2026 00:00:00">
<META>
<INFO Vendor="" Name="" Version="" Author="" Comment="Ein Satz zum Zweck des Skripts."/>
<STATICVARS LoadInstallIni="1">
<BMSVars></BMSVars>
</STATICVARS>
</META>
<ACTIONS>
... Aktionen ...
</ACTIONS>
</baramundiDeployScript>
```

- Jede Zeile wie hier; Elemente ohne Inhalt als `<X></X>`, nicht `<X/>` (Ausnahme: `INFO` und `CONDITION`, die immer
  selbstschließend sind).
- `LastChange` setzt `save` auf die aktuelle Zeit; in der Arbeitskopie genügt ein Platzhalterdatum im Format.
- Jede `ACTION` trägt alle sieben Attribute in dieser Reihenfolge:
  `type level breakpoint ignore_error comment is_included logging_enabled`.
  Standard: `breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1"`;
  Kommentar-Aktionen haben `comment="1"`.
- Im Text von `VALUE`, `CONTENT`, `SCRIPT` usw. die fünf XML-Zeichen maskieren wie das Studio:
  `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&apos;`. In Attributen (`CONDITION`) mindestens
  `&`, `<`, `>`, `"`.

## 2. Abschnitte und Einrückung

Kommentar-Aktionen auf `level="0"` gliedern das Skript; die zugehörigen Aktionen stehen darunter auf `level="1"`.
Bedingungsgruppen (`Conditional`) und Unterroutinen (`Subroutine`) rücken ihren Rumpf um eine weitere Stufe ein.
Typische Abschnitte: „Parameter aus dem Job übernehmen“, „Prüfen“, „Ausführen“, „Abschluss“.

## 3. Job-Parameter übernehmen

Job-Parameter wirken erst, wenn die .bds in der Management Suite angelegt ist und jeder Parameter dort unter
„Konfigurierbare Parameter“ mit genau diesem Namen eingetragen ist. Fehlt einer, bleibt `{JobParam.X}` als Text stehen
(Probe) – Pflicht-Parameter deshalb direkt nach dem Übernehmen prüfen (`aktionen.md` 3.4, im Beispiel unten enthalten).

Text: Wert aus dem Job in eine Skriptvariable.

```xml
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>TaskName</VARNAME>
<VALUE>{JobParam.TaskName}</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
```

Ja/Nein für PowerShell: Job-Parameter vom Typ Ja/Nein liefert baramundi als `T` bzw. `F`. Erst den sicheren
Standard setzen, dann nur bei `T` umschalten – so bleibt das Skript auch bei fehlendem Job-Parameter auf der
sicheren Seite.

```xml
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>Umstellen</VARNAME>
<VALUE>$false</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>Umstellen</VARNAME>
<VALUE>$true</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
<CONDITION op1="{JobParam.Umstellen}" op="=" op2="T" options="0"/>
</ACTION>
```

Geheimnis (Kennwort, Token): in der Management Suite als Passwort-Parameter anlegen (im Job mit * maskiert), Übernahme
wie Text per `{JobParam.X}`, aber mit `logging_enabled="0"` – ebenso an jeder Aktion, die die Variable verwendet (z. B.
das eingebettete Skript).

## 4. Eingebettetes PowerShell

Reihenfolge der Aktionen: `SetX64Mode` 1 → `RunEmbeddedScript` → `SetX64Mode` 0 → je Exitcode ein `EndBDS` mit
`CONDITION` → bedingungsloses `EndBDS` mit Fehler als Auffang.

Gerüst des Skripttexts (hier unmaskiert; im XML werden `'`, `"`, `<`, `>`, `&` maskiert):

```powershell
# <Skriptname>: <Zweck in einem Satz>
# Exitcodes: 0 = <Erfolg>, 2 = <...>, 3 = <...>, 99 = unerwarteter Fehler.
#            Exitcode 1 wird nicht vergeben: Den meldet PowerShell selbst bei Abbruch oder Syntaxfehler.

# ================================== EINSTELLUNGEN ==================================
# baramundi ersetzt die Platzhalter in geschweiften Klammern vor dem Start. Für einen lokalen Test gilt
# der Standardwert aus der auskommentierten Zeile direkt darüber.

# <Beschreibung des Werts>
# $Ordner = 'C:\Temp'
$Ordner = '{Ordner}'

# $true = <was dann passiert>
# $Umstellen = $false
$Umstellen = {Umstellen}

# Zahl ohne Anführungszeichen
# $Tage = 90
$Tage = {Tage}

$LogDatei = 'C:\Windows\Temp\<Skriptname>.log'

# Ergebnis ins Log schreiben und das Skript mit diesem Exitcode beenden
function Ende([int]$Code, [string]$Text) {
    $zeile = '{0:yyyy-MM-dd HH:mm:ss}  Code {1}  {2}' -f (Get-Date), $Code, $Text
    Write-Output $zeile
    try { Add-Content -Path $LogDatei -Value $zeile -Encoding UTF8 -ErrorAction Stop } catch { }   # Log darf den Exitcode nie verhindern
    exit $Code
}

# Jeder unerwartete Fehler endet mit Code 99 und Meldung im Log
trap { Ende 99 "Unerwarteter Fehler: $_" }

# ==================================== ABLAUF ======================================
# ... jeder Schritt mit einem deutschen Kommentar ...
Ende 0 'Alles erledigt.'
```

Regeln dazu:

- **Platzhalter:** Text als `'{Name}'`; Ja/Nein und Zahlen ohne Anführungszeichen (`{Name}`), dafür muss die
  Variable `$true`/`$false` bzw. eine Zahl enthalten. Freitext, der `'` enthalten kann (Kennwörter, Meldungen), als
  Here-String:
  ```powershell
  $Kennwort = @'
  {Kennwort}
  '@
  ```
  (`'@` muss am Zeilenanfang stehen.)
- **Fehlenden Wert erkennen:** Fehlt der Job-Parameter, kommt der Text `{JobParam.X}` an (unbekannte Platzhalter
  bleiben stehen). Prüfen mit `$Wert.StartsWith('{') -and $Wert.EndsWith('}')` – den Platzhalter nie selbst
  ausschreiben, sonst ersetzt baramundi auch den Vergleichswert.
- **Geschweifte Klammern:** baramundi ersetzt `{Name}` überall im Skripttext. Formatangaben wie `'{0:yyyy-MM-dd}'`
  oder `{1}` und Skriptblöcke mit Leerzeichen (`{ $_ }`) sind unkritisch; einen einzelnen Bezeichner direkt in
  Klammern (`{Name}`) nur als gewollten Platzhalter schreiben.
- **Ausgabe:** Ein Ergebnis = eine Logzeile mit Zeitstempel und Exitcode (Funktion `Ende`). `Write-Output` landet
  zusätzlich in der Aktionsausgabe.
- **Zeichen:** Umlaute und ß ja; keine typografischen Anführungszeichen, kein Gedankenstrich, kein €.

## 5. Vollständiges Beispiel: Check_TaskUser im Hausstil

Job-Parameter: `TaskUser` (Domäne\Konto), `TaskName`, `Umstellen` (`T` = umstellen), `Kennwort`.
Ausgänge: 0 Erfolg, 2/3/5 Fehler, 4 Erfolg (umgestellt), alles andere → Auffang „Unerwarteter Exitcode“.

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<baramundiDeployScript Version="2620" LastChange="04.11.2026 12:00:00">
<META>
<INFO Vendor="" Name="" Version="" Author="" Comment="Prüft, unter welchem Konto eine geplante Aufgabe läuft, und stellt sie auf Wunsch um."/>
<STATICVARS LoadInstallIni="1">
<BMSVars></BMSVars>
</STATICVARS>
</META>
<ACTIONS>
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>Parameter aus dem Job übernehmen</VALUE>
</DATA>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>TaskUser</VARNAME>
<VALUE>{JobParam.TaskUser}</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>TaskName</VARNAME>
<VALUE>{JobParam.TaskName}</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Job-Parameter TaskUser fehlt</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{TaskUser}" op="STARTSWITH" op2="{JobParam." options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Job-Parameter TaskName fehlt</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{TaskName}" op="STARTSWITH" op2="{JobParam." options="0"/>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>Umstellen</VARNAME>
<VALUE>$false</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>Umstellen</VARNAME>
<VALUE>$true</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
<CONDITION op1="{JobParam.Umstellen}" op="=" op2="T" options="0"/>
</ACTION>
<ACTION type="SetVar" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="0">
<DATA>
<VARNAME>Kennwort</VARNAME>
<VALUE>{JobParam.Kennwort}</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>Aufgabe prüfen und ggf. umstellen (PowerShell 64 Bit)</VALUE>
</DATA>
</ACTION>
<ACTION type="SetX64Mode" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<MODE>1</MODE>
</DATA>
</ACTION>
<ACTION type="RunEmbeddedScript" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="0">
<DATA>
<SCRIPTLANGUAGE>PowerShell</SCRIPTLANGUAGE>
<RETURNCODES>*</RETURNCODES>
<VARNAME>Exitcode</VARNAME>
<SCRIPT># Check_TaskUser: Prüft, ob eine geplante Aufgabe unter dem erwarteten Konto läuft,
# und stellt sie auf Wunsch auf dieses Konto um.
# Exitcodes: 0 = Konto stimmt, 2 = anderes Konto eingetragen, 3 = Aufgabe nicht gefunden,
#            4 = umgestellt, 5 = Umstellen fehlgeschlagen (Aufgabe unverändert), 99 = unerwarteter Fehler.
#            Exitcode 1 wird nicht vergeben: Den meldet PowerShell selbst bei Abbruch oder Syntaxfehler.

# ================================== EINSTELLUNGEN ==================================
# baramundi ersetzt die Platzhalter in geschweiften Klammern vor dem Start. Für einen lokalen Test gilt
# der Standardwert aus der auskommentierten Zeile direkt darüber.

# Erwartetes Konto (Domäne\Benutzer)
# $Benutzer = &apos;FIRMA\svc_aufgabe&apos;
$Benutzer = &apos;{TaskUser}&apos;

# Name der geplanten Aufgabe
# $AufgabeName = &apos;vd_task&apos;
$AufgabeName = &apos;{TaskName}&apos;

# $true = bei falschem Konto auf $Benutzer umstellen (braucht das Kennwort)
# $Umstellen = $false
$Umstellen = {Umstellen}

# Kennwort für das Umstellen. Als Here-String, damit auch Kennwörter mit &apos; oder &quot; funktionieren.
# $Kennwort = &apos;&apos;
$Kennwort = @&apos;
{Kennwort}
&apos;@

$LogDatei = &apos;C:\Windows\Temp\Check_TaskUser.log&apos;

# Ergebnis ins Log schreiben und das Skript mit diesem Exitcode beenden
function Ende([int]$Code, [string]$Text) {
    $zeile = &apos;{0:yyyy-MM-dd HH:mm:ss}  Code {1}  {2}&apos; -f (Get-Date), $Code, $Text
    Write-Output $zeile
    try { Add-Content -Path $LogDatei -Value $zeile -Encoding UTF8 -ErrorAction Stop } catch { }   # Log darf den Exitcode nie verhindern
    exit $Code
}

# Jeder unerwartete Fehler endet mit Code 99 und Meldung im Log
trap { Ende 99 &quot;Unerwarteter Fehler: $_&quot; }

# ==================================== ABLAUF ======================================
# Aufgabe suchen; ohne Treffer gibt es nichts zu prüfen
$aufgabe = Get-ScheduledTask -TaskName $AufgabeName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $aufgabe) { Ende 3 &quot;Aufgabe &apos;$AufgabeName&apos; nicht gefunden.&quot; }

# Eingetragenes Konto lesen (bei Gruppen steht es in GroupId)
[string]$ist = $aufgabe.Principal.UserId
if (-not $ist) { $ist = $aufgabe.Principal.GroupId }

# Vergleichen: Domäne nur, wenn sie auf beiden Seiten angegeben ist
if ($ist.Contains(&apos;\&apos;) -and $Benutzer.Contains(&apos;\&apos;)) { $ok = $ist -eq $Benutzer }
else { $ok = ($ist -split &apos;\\&apos;)[-1] -eq ($Benutzer -split &apos;\\&apos;)[-1] }
if ($ok) { Ende 0 &quot;Aufgabe &apos;$AufgabeName&apos; läuft als &apos;$ist&apos;.&quot; }
if (-not $Umstellen) { Ende 2 &quot;Aufgabe &apos;$AufgabeName&apos; läuft als &apos;$ist&apos;, erwartet &apos;$Benutzer&apos;.&quot; }

# Umstellen: Die Aufgabenplanung prüft Konto und Kennwort selbst und speichert bei einem Fehler nichts
if (-not $Kennwort -or ($Kennwort.StartsWith(&apos;{&apos;) -and $Kennwort.EndsWith(&apos;}&apos;))) { Ende 5 &quot;Kein Kennwort übergeben, nichts geändert.&quot; }
try {
    Set-ScheduledTask -TaskName $AufgabeName -TaskPath $aufgabe.TaskPath -User $Benutzer -Password $Kennwort -ErrorAction Stop | Out-Null
} catch {
    Ende 5 &quot;Umstellen fehlgeschlagen ($($_.Exception.Message.Trim())), Aufgabe läuft weiter als &apos;$ist&apos;.&quot;
}
$neu = (Get-ScheduledTask -TaskName $AufgabeName -TaskPath $aufgabe.TaskPath).Principal.UserId
Ende 4 &quot;Aufgabe &apos;$AufgabeName&apos; läuft jetzt als &apos;$neu&apos; (vorher &apos;$ist&apos;).&quot;</SCRIPT>
<HIDDENEXECUTION>1</HIDDENEXECUTION>
</DATA>
</ACTION>
<ACTION type="SetX64Mode" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<MODE>0</MODE>
</DATA>
</ACTION>
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>Abschluss: eine Meldung je Exitcode, zuletzt der Auffang</VALUE>
</DATA>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Aufgabe {TaskName} läuft unter {TaskUser}</RETURNMESSAGE>
<RETURNMODESTR>1</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{Exitcode}" op="=" op2="0" options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Aufgabe {TaskName} läuft unter einem anderen Konto als {TaskUser}</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{Exitcode}" op="=" op2="2" options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Aufgabe {TaskName} nicht gefunden</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{Exitcode}" op="=" op2="3" options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Aufgabe {TaskName} auf {TaskUser} umgestellt</RETURNMESSAGE>
<RETURNMODESTR>1</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{Exitcode}" op="=" op2="4" options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Umstellen fehlgeschlagen, Aufgabe {TaskName} unverändert</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{Exitcode}" op="=" op2="5" options="0"/>
</ACTION>
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Unerwarteter Exitcode {Exitcode} - Details in C:\Windows\Temp\Check_TaskUser.log</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
</ACTION>
</ACTIONS>
</baramundiDeployScript>
```

# Aktionskatalog und Format (.bds, Schema 2620)

Nachschlagewerk zum Schreiben von .bds-Dateien. Grundlage: zwei Beispieldateien des Nutzers (US = UniversalScript.bds,
Schaudatei fast aller Aktionen; CTU = Check_TaskUser.bds, Produktivskript), die Gewinnerskripte der baramundi
Scripting Days 2025 samt Doku (SD-I = Level Intermediate, Neustart-Erinnerung mit Client-Variablen; SD-P = Level
Professional, serverseitige Aktion zur Jobzuweisung, bMS 2025.1), die offizielle Doku des Automation Studio
(bMS 2026R2; `t23428` = Topic-ID), Webquellen (W1 …, Liste am Ende) und ein Probelauf auf dem Testgerät des Nutzers am
04.11.2026 ([Probe]).

Sicherheit: [sicher] = dokumentiert, im Beispiel sichtbar oder per Probe bestätigt; [wahrscheinlich] = starke
Schlussfolgerung; [geraten] = Vermutung – solche Werte nur nutzen, wenn der Text sie als Generator-Standard nennt.
Zeilenangaben wie `US Z.187` verweisen auf die Beispieldateien und dienen nur der Nachverfolgung.

## Inhalt

1. Datei: Rahmen, Zeilen, Kodierung, Escaping, eingebettete Skripte
2. ACTION-Attribute und Einrückung
3. Variablen
4. Bedingungen
5. Aktionskatalog – 5.1 Benutzerinteraktion · 5.2 Variablen · 5.3 Dateioperationen · 5.4 Registry · 5.5 Dienste ·
   5.6 Systemfunktionen · 5.7 Programmfluss
6. Aktionen ohne bekanntes XML (nicht erzeugen)
7. Berechneter Ausdruck (EvalVar `Expression`)
8. Allgemeine Fallstricke
9. Offene Punkte
10. Serverseitige Aktion (SSA) und bConnect
Webquellen

## 1. Datei

### 1.1 Rahmen

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<baramundiDeployScript Version="2620" LastChange="[[dd.MM.yyyy HH:mm:ss]]">
<META>
<INFO Vendor="" Name="" Version="" Author="" Comment=""/>
<STATICVARS LoadInstallIni="1">
<BMSVars></BMSVars>
</STATICVARS>
</META>
<ACTIONS>
[[ACTION-Elemente]]
</ACTIONS>
</baramundiDeployScript>
```

- Deklaration exakt so, ohne BOM; Wurzel mit genau `Version` und `LastChange` in dieser Reihenfolge [sicher].
- `Version="2620"` = bDS-Schema des Automation Studio 26R2 (26.2.147) [sicher] (vom Studio gespeicherte Dateien,
  17.11.2026). Vorgänger `2420` = Schema seit 24R2 (eingeführt mit „Unsichtbar ausführen“), läuft nicht auf Agenten
  vor 24R2 [sicher] (t23436, W1).
- Ältere Skripte öffnet das Studio 26R2 nur schreibgeschützt oder konvertiert sie auf Nachfrage; konvertierte
  Skripte laufen laut Dialog nur noch auf dem aktuellsten bMA. Die Konvertierung 2420 → 2620 ändert nur `Version`
  (und `LastChange`) [sicher] – byteweiser Vergleich eines Skripts mit Comment, SetVar, SetX64Mode,
  RunEmbeddedScript, EvalVar/IniFile und EndBDS. Eine zweite vom Studio 26R2 gespeicherte Datei (EvalVar SubString/
  Expression/FileInfo, Conditional, Subroutine, CallSubroutine, Label, GotoLabel, MoveFileOrFolder, CopyFiles,
  CreateFolder) entspricht ebenfalls den Vorlagen hier. Übrige Aktionen in 2620: ungeprüft [wahrscheinlich gleich].
- Inline-Ausdrücke `{=…}` (VBScript) im Text unterstützt 26R2 nicht mehr („Verwendung einer veralteten Syntax“,
  Meldung in BDScript.dll) – stattdessen EvalVar `Expression` (Abschnitt 7).
- `LastChange` = Ortszeit `dd.MM.yyyy HH:mm:ss` – setzt `bds save`.
- `INFO` = Reiter „Allgemein“ der Skripteigenschaften: Vendor (Hersteller), Name, Version (Skriptversion), Author,
  Comment (Kommentar); selbstschließend, Reihenfolge fest [wahrscheinlich] (t23366). Hausregel: Author aus `author.txt` (SKILL.md), Comment = Zweck.
- `STATICVARS LoadInstallIni="1"` mit leerem `<BMSVars></BMSVars>` unverändert übernehmen [sicher].
- Weitere Elemente aus baramundis eigenem Installationsskript (Managed Software, Schema 2220):
  `<MANAGEDSOFTWAREWRITELOCK>True</MANAGEDSOFTWAREWRITELOCK>` in `META` zwischen `INFO` und `STATICVARS`
  (Schreibschutz für Herstellerskripte – nie erzeugen) und `<RUNOPTIONS HideProgress="1"/>` zwischen `</META>` und
  `<ACTIONS>` = Skriptfortschrittsfenster ausblenden [wahrscheinlich; HideProgress/RUNOPTIONS stehen auch in
  BDScript.dll]. Generator: beide weglassen, außer der Nutzer will das Fortschrittsfenster ausblenden.

### 1.2 Zeilen und Kodierung

- ISO-8859-1, jedes Zeichen ein Byte (`ü` = FC). Jede Zeile endet mit CRLF, auch die letzte. Keine Einrückung, keine
  Tabs, keine Leerzeilen außer in Textwerten, keine XML-Kommentare, kein CDATA [sicher]. `&#…;` nur für Umbrüche in
  UserInput-Texten (`&#x0d;&#x0a;`, 5.1) – sonst nirgends in 67 Skripten des Nutzers [sicher] (SD-I).
- Zeichen außerhalb Latin-1 (€ „ “ – …) gibt es nicht; `bds save` lehnt sie ab.

### 1.3 Escaping

- Elementtext wie das Studio: `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&apos;` [sicher].
- Attribute (`CONDITION`): `<` `>` `&` `"` maskieren (`op="&lt;&gt;"`) [sicher]. Roh bleiben `$ \ { } % ; | * ( ) [ ]`.
- Beispiel: PowerShell `2>&1` steht in der Datei als `2&gt;&amp;1`.

### 1.4 Mehrzeilige Werte

Text beginnt direkt nach dem Start-Tag und endet direkt vor dem End-Tag, Umbrüche literal als CRLF, keine
Einrückung. Ein Umbruch vor dem End-Tag gehört zum Wert [sicher].

### 1.5 Eingebettete Skripte (SCRIPT)

- Skripttext als Latin-1 mit CRLF, ohne BOM – so entsteht er auch beim Tippen im Studio-Editor [sicher].
- Laufzeit [sicher, Probe]: Der Agent schreibt den Text Byte für Byte (ANSI, ohne BOM, CRLF) nach
  `C:\ProgramData\baramundi\Temp\BDSxxxx.ps1`; Windows PowerShell 5.1 liest ihn als ANSI, `äöüß ÄÖÜ` kommen korrekt an.
- Altformat (CTU): rohe UTF-8-Bytes mit BOM aus einer importierten .ps1. Läuft auch (die Bytes landen 1:1 in der
  Datei), zeigt im Editor aber `PrÃ¼ft`; `Ü` und `ß` enthalten in UTF-8 Bytes 0x80–0x9F und sind gefährdet. Nicht
  erzeugen; vor Änderungen darin `bds open -Normalize`.
- PowerShell Core liest Dateien ohne BOM als UTF-8 → in Skripten für PowerShell Core keine Umlaute.

## 2. ACTION-Attribute

```xml
<ACTION type="[[Typ]]" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
```

Alle 148 ACTION-Elemente der Beispiele haben genau diese 7 Attribute in dieser Reihenfolge [sicher].

| Attribut | Werte | Bedeutung |
|---|---|---|
| `type` | z. B. `SetVar` | Aktionstyp (Abschnitt 5) [sicher] |
| `level` | 0, 1, 2 … | Einrückungstiefe [sicher] |
| `breakpoint` | 0 | Haltepunkt des Studio-Debuggers; immer 0 [wahrscheinlich] |
| `ignore_error` | 0 / 1 | 1 = „Fehler ignorieren“: Fehlschlag bricht das Skript nicht ab [wahrscheinlich] (t23358) |
| `comment` | 0 / 1 | Auskommentiert-Flag [wahrscheinlich]: Bei anderen Typen wird die Aktion dann nicht ausgeführt, bei Comment ist es ohne Wirkung. Das Studio des Nutzers schreibt bei Comment immer 1 (38/38), baramundis eigenes Installationsskript und ein Web-Export auch 0. Generator: Comment `1`, sonst `0` |
| `is_included` | 0 | immer 0 [geraten: Kennung für eingebundene Aktionen] |
| `logging_enabled` | 1 / 0 | 0 = Logging dieser Aktion unterdrücken (Geheimnisse) [wahrscheinlich] (t23327) |

**Einrückung**
- Kinder = direkt folgende Aktionen mit höherem level bis zur nächsten Aktion mit level ≤ Elternlevel; kein
  End-Marker; Anstiege nur um 1 [sicher].
- Eltern können Comment (Gliederung), Conditional (bedingter Block), Subroutine (Rumpf) und Label (Schleifenrumpf,
  5.7) sein [sicher] (SD-P und 9 Skripte des Nutzers rücken unter Label ein). Einrückung unter anderen Aktionen
  (einmal unter LaunchProcess gesehen): Wirkung unbekannt, nicht erzeugen.
- Comment, Label und Subroutine haben keine Bedingung, das Studio zeigt dort „(nicht unterstützt)“ [sicher]
  (Studio-Bilder in SD-I) → bedingte Abschnitte immer mit einer Bedingungsgruppe.
- Unter einem Kommentar eingerückte Aktionen laufen normal – Kommentare taugen als Abschnittsüberschrift [sicher, Probe].
- Kinder einer Bedingungsgruppe laufen nur bei erfüllter Bedingung; der Rumpf einer Unterroutine wird im normalen
  Ablauf übersprungen und läuft nur per CallSubroutine [sicher, Probe].

**Fehlerverhalten und Logging**
- Ohne `ignore_error` bricht ein Aktionsfehler das Skript mit Fehler ab [sicher] (t23358).
- Das Ergebnis der letzten Aktion steht in `{BDScript.LastResult}` = `SUCCESS`/`FAILED` [sicher] (W8). Muster:
  `ignore_error="1"`, danach eine Aktion mit Bedingung auf `{BDScript.LastResult}`.
- Das Skriptlog landet clientseitig im bMA.log [sicher] (t23347) → Geheimnisse mit `logging_enabled="0"`.

## 3. Variablen

### 3.1 Syntax

- Definieren ohne Klammern (`VARNAME`), verwenden als `{Name}`; Groß-/Kleinschreibung egal [sicher, Probe].
- Werte sind Text; die Ersetzung ist rein textuell und mit Literaltext kombinierbar (`{DIP}\Software`) [sicher].
- Kindvariablen mit Punkt (`{Prozess.PID}`), Arrays aus Wildcard-Abfragen: `{Var.Count}`, `{Var.<Index>.<Kind>}`,
  Index ab 1 [sicher] (t23377, t23406; SD-P zählt von 1 bis `{IniFiles.Count}`).
- Zusammengesetzte Namen funktionieren bei skriptinternen Variablen: `{IniFiles.{i}.Name}` – die innere Variable wird
  zuerst ersetzt [sicher] (SD-P, das Log im PDF zeigt die aufgelösten Dateinamen). bMS-Variablen (`{Client.…}`,
  `{Job.…}`, `{JobParam.…}`, eigene Variablen) stellt der Agent seit 22R2 dagegen nur bereit, wenn sie wörtlich im
  Skript stehen → für diese nie zusammengesetzte Namen [sicher] (W2).
- **Unbekannte Variablen und nicht gesetzte Job-Parameter bleiben als Text stehen** (`{GibtEsNicht}`,
  `{JobParam.Fehlt}`), ohne Fehler [sicher, Probe]. Jede verwendete Variable vorher setzen.

### 3.2 Herkunft

- **Job-Parameter** `{JobParam.<Name>}` [sicher]. Voraussetzung: Die .bds ist in der Management Suite angelegt und der
  Parameter dort unter „Konfigurierbare Parameter“ eingetragen; Ja/Nein-Parameter liefern `T` bzw. `F` [sicher, Nutzer].
  Typen: Zeichenkette, Zahl, EIN/AUS-Feld (T/F), Datum, Auswahlliste, Editierbares Auswahlfeld, Dateiname, Zertifikat;
  dazu eigene Passwort-Parameter, im Job mit * maskiert [sicher, Nutzer]. Fehlt der Parameter, steht wörtlich `{JobParam.<Name>}` im Wert [sicher, Probe]. Parameternamen dürfen Punkte
  enthalten, das Präfix ist unabhängig von Groß-/Kleinschreibung (`{jobParam.installDir.barMan}` in baramundis
  eigenem Skript) [sicher].
- **Umgebungsvariablen** `{%NAME%}`, z. B. `{%COMPUTERNAME%}`, `{%systemroot%}` [sicher, Probe]. Der Agent ist ein
  32-Bit-Prozess: `{%processor_architecture%}` ist immer x86 [sicher] (W5), `{%ProgramFiles%}` zeigt auf „Program Files (x86)“ –
  vermutlich auch im x64-Modus, der die Prozessumgebung nicht ändert [wahrscheinlich]. 64-Bit-Programmordner daher über
  `{%ProgramW6432%}` bzw. `{%CommonProgramW6432%}`, `{%ProgramFiles%}` nur für 32-Bit-Software [wahrscheinlich]
  (WOW64-Verhalten von Windows; die Auflösung durch bDS ist ungetestet).
- **bMS-Systemvariablen** – stehen in jedem Job bereit, ohne Setzen [sicher, Nutzer: Variablenliste eines echten Jobs,
  bMS 26.1, 11.11.2026; dazu W5]. **Geräte-, Netzwerk- und Jobdaten zuerst hier holen, nicht per Registry, WMI oder
  PowerShell** – z. B. Hersteller-Weichen direkt per Bedingung auf `{Manufacturer}`. Namen mit Doppelpunkt
  (`{Client:IP}`) heißen wirklich so. Werte können leer sein (z. B. `{Client:EntraIdDeviceId}` ohne Entra ID,
  `{InstallTargetPath}`) → bei Bedarf auf leer prüfen, nicht nur auf den Platzhaltertext.

| Thema | Variablen (Beispielwert) |
|---|---|
| Gerät | `{Manufacturer}` (HP), `{ModelName}` (HP ProBook 450 G6), `{FirmwareType}` (UEFI), `{UEFISecureBoot}` (enabled), `{UEFIBootCurrent}`, `{Client}` = `{Machine}` = `{Machine.ComputerName}` (Gerätename), `{Client:DisplayName}`, `{Client:GUID}`, `{Client:UUID}` (BIOS-UUID), `{Client:EntraIdDeviceId}`, `{Client:TenantID}` |
| Netzwerk | `{PrimaryIP}` = `{ClientAddress}` = `{Client:IP}`, `{PrimaryMAC}` = `{Client:MAC}`, `{Machine.LogicalMAC}`, `{PrimarySubnetMask}` = `{Client:SubnetMask}`, `{Client:CommunicationMode}`/`{Client:LastChannel}` (LAN), `{Network.Domain}` (DNS-Domäne), `{Network.Server}` |
| Betriebssystem | `{OSType}` = `{Machine.OSType}` (Win11_x64), `{Architecture}` = `{Arch}` (x64), `{Machine.OSVersion}` (Klartext mit Build und Edition), `{Machine.OSDisplayVersion}` (z. B. 24H2), `{Machine.OSReleaseID}`, `{OSServicePack}`, `{LCID}` = `{LangID}`, `{UserLCID}` (1031 = Deutsch) |
| Hardware | `{Machine.CPUDesc}`, `{Machine.CPUType}`, `{Machine.CPUSpeed}` (MHz), `{Machine.CPUCountPhysical}`/`{Machine.CPUCountTotalCores}`/`{Machine.CPUCountLogical}`, `{Machine.Memory}` (MB), `{Machine.DriveCSize}`/`{Machine.DriveCFree}` (MB; D und E analog, 0 = Laufwerk fehlt) |
| Benutzer und Gruppe | `{Username}` = `{RegisteredUser}` (UPN), `{Machine.RegisteredUserName}` (Anzeigename), `{Machine.RegisteredUserDomain}`, `{Domain}` (NetBIOS-Name), `{Company}`, `{Group}` = `{Machine.GroupName}` (bMS-Gruppe), `{Machine.Profile}` |
| Job und Software | `{Job.Name}`, `{Job.Creator}`, `{Job.Initiator}` (UPN des Auslösers), `{Software.Name}`, `{Software.Version}`, `{Software.Vendor}`, `{Mode}` (Install/Deinstall), `{Reinstall}` (FirstInstall bei Erstinstallation), `{Script}` (Pfad der laufenden .bds), `{InstallTargetPath}`; nur in W5: `{GUIDJob}`, `{GUIDClient}` |
| baramundi | `{DIP}` = `{Network.DIP}` (Verteilpunkt), `{Server}` = `{Network.Server}` (bMS als FQDN), `{ServerHostname}`, `{BMAPath}`, `{BMAVersion}`, `{BMSPath}`, `{BMSVersion}`, `{BDScript.ActionDelay}`/`{BDScript.GUIActionDelay}` (ms) |

  Hinweise: Hersteller und Modell stammen vermutlich aus der Inventur der bMS (bei einem frisch aufgenommenen Gerät
  womöglich leer) [wahrscheinlich]. Ältere HP-Geräte melden sich teils als „Hewlett-Packard“ → Weiche mit `CONTAINS`
  statt `=` und beide Schreibweisen bedenken [wahrscheinlich]. `{NetworkDiscovery.EnrollmentToken}` ist ein Geheimnis
  → nur mit `logging_enabled="0"` verwenden. `{FirstInstall}` fehlt in der Liste: Es ist der Wert von `{Reinstall}`,
  keine eigene Variable [wahrscheinlich]. Nicht verwenden: `{CDROM}`; veraltet: `{KitsServer}`, `{Depot}` (= `{DIP}`).
- **Benutzerdefinierte bMS-Variablen** `{Bereich.Kategorie.Name}` mit Bereich Client, Group, Profile, Software, Job;
  Typen Zeichenkette (ohne `'` und `"`), Ein/Aus (T/F), Passwort (verschlüsselt), Zahl, Datum [sicher] (W6, W7, SD-I).
  - **Client-Variable vom Gerät aus setzen**: LaunchProcess mit BMACmd (Vorlage 5.6),
    `/Cmd:SetCustomVar /Category:<Kategorie> /Name:<Name> /Value:"<Wert>"`, leeren mit `/Value:""` [sicher] (W17,
    SD-I). Voraussetzung: Die Variable ist im bMC unter Konfiguration > Variablen angelegt [sicher] (W17). Lesen in
    späteren Jobs als `{Client.<Kategorie>.<Name>}` [sicher] (SD-I).
  - Ein/Aus kommt als `T`/`F` an. Datumswerte liest SD-I als `yyyyMMddHHmmss` (es rechnet mit Left/Mid darauf und
    schreibt selbst `yyyyMMdd000000`) [wahrscheinlich].
  - Den Wert liefert der Server beim Jobstart. Was das Skript per BMACmd neu setzt, steht erst im nächsten Job in
    `{Client.…}` → im laufenden Skript mit der eigenen Variable weiterrechnen, wie SD-I [wahrscheinlich].
- **Status**: `{BDScript.LastResult}` (SUCCESS/FAILED), `{GUI.LastControl}` [sicher] (W8).
- **Skriptintern**: SetVar, EvalVar, UserInput-Rückgabe (Standard `UserInput`), VARNAME/PIDVARNAME von LaunchProcess
  und RunEmbedded*.

### 3.3 In eingebetteten Skripten

- `{Name}` wird im Skripttext vor dem Start ersetzt; unbekannte `{…}`, Formatangaben (`'{0}-{1}'`) und Skriptblöcke
  bleiben unverändert, ebenso Ziffern in Klammern wie `{0}` oder `\d{4}` [sicher, Probe]. Ein Escape für `{` gibt es
  nicht; `${env:X}` meiden, stattdessen `$env:X`.
- Der eingesetzte Wert wird nicht maskiert: Ein `'` im Wert bricht `'{Name}'` → Freitext und Kennwörter als
  Here-String einsetzen (muster.md).
- bDS-Variablen nur im Block EINSTELLUNGEN einsetzen, danach reines PowerShell (muster.md).
- Fehlenden Wert im Skript erkennen, ohne den Platzhalter auszuschreiben:
  `if ($Wert.StartsWith('{') -and $Wert.EndsWith('}')) { … }`.

### 3.4 Pflicht-Job-Parameter prüfen

Fehlt ein Pflicht-Parameter im Job, soll das Skript mit klarer Meldung enden statt mit dem Text `{JobParam.X}`
weiterzuarbeiten. `{JobParam.` ohne schließende Klammer wird nicht ersetzt [wahrscheinlich]:

```xml
<ACTION type="EndBDS" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>Job-Parameter TaskName fehlt</RETURNMESSAGE>
<RETURNMODESTR>0</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{TaskName}" op="STARTSWITH" op2="{JobParam." options="0"/>
</ACTION>
```

Direkt nach dem `SetVar TaskName = {JobParam.TaskName}`. Nur für Parameter ohne sinnvollen Standardwert; Parameter
mit Standard (z. B. Ja/Nein) bekommen stattdessen erst den Standard und dann den bedingten Wert.

### 3.5 Fallstricke

- .bds-Dateien sind für jeden mit Zugriff auf den Verteilpunkt im Klartext lesbar → keine Kennwörter fest ins Skript,
  sondern Job-Parameter bzw. bMS-Passwortvariablen, dazu `logging_enabled="0"` [sicher] (W10, t23347).
- Variablen sind Text; zum Vergleichen Abschnitt 4.

## 4. Bedingungen

```xml
<CONDITION op1="{[[Variable]]}" op="=" op2="[[Wert]]" options="0"/>
```

- Selbstschließend, eigene Zeile nach `</DATA>`, Attributreihenfolge `op1 op op2 options`; höchstens eine je Aktion
  [sicher]. Die Aktion läuft nur bei erfülltem Vergleich, sonst geht es mit der nächsten weiter; bei Conditional gilt
  sie für alle Kinder [sicher, Probe]. Label kann keine Bedingung haben [sicher].
- Dialog: Operand 1, Vergleichsoperator, Vergleichsmethode (Standard/Versionsnummer), Operand 2, Checkbox „Bei
  Textvergleichen Gross-/Kleinschreibung beachten“.

| `op` in der Datei | Bedeutung |
|---|---|
| `=` | ist gleich [sicher] |
| `&lt;&gt;` | ungleich [sicher] |
| `&gt;` / `&lt;` | größer / kleiner [sicher] |
| `&gt;=` / `&lt;=` | größer oder gleich / kleiner oder gleich [sicher] |
| `STARTSWITH` / `ENDSWITH` / `CONTAINS` | beginnt mit / endet mit / enthält [sicher] |
| `MATCHES` / `DOESNOTMATCH` | gleich / ungleich mit Wildcards `*` und `?` [wahrscheinlich] |

**options** [sicher, Probe]:

| options | Wirkung |
|---|---|
| 0 | Standard, Groß-/Kleinschreibung egal (`abc` = `ABC`) |
| 1 | Groß-/Kleinschreibung beachten |
| 2 | Vergleichsmethode „Versionsnummer“ |
| 3 | beides |

- „Standard“ vergleicht Zahlen numerisch (`10` > `9`; auch `1.10` > `1.9` war wahr), die Stellenzahl ist aber begrenzt
  (t23376) → Versionsnummern mit `options="2"` vergleichen.
- Leer oder nicht leer prüfen wie baramundi selbst: `op="MATCHES" op2=""` (leer) bzw. `op="DOESNOTMATCH" op2=""`
  (nicht leer). Für FOUND/NOTFOUND nutzt baramundi ebenfalls `MATCHES`; `=` funktioniert genauso [sicher, Probe].
- Kein Else: zweite Aktion oder Gruppe mit komplementärem Operator (`=` ↔ `&lt;&gt;`, `&gt;` ↔ `&lt;=`, `MATCHES` ↔
  `DOESNOTMATCH`). UND = verschachtelte Conditional. ODER = Hilfsvariable über mehrere bedingte SetVar, dann eine
  Bedingung darauf. Mehrfachauswahl = je Wert eine bedingte Aktion (z. B. ein EndBDS je Exitcode). Schleife = Sprungmarke →
  Berechneter Ausdruck → bedingter Sprung [sicher] (t23383); Zählvariable vorher setzen, sonst bleibt `{i}` als Text
  stehen und der Ausdruck wird ungültig [wahrscheinlich, Probe].
- Else-Falle: Jede Bedingung wird erst beim Erreichen ihrer Aktion ausgewertet. Ändert der erste Zweig die geprüfte
  Variable, läuft der zweite womöglich zusätzlich → beide Zweige auf einen Wert prüfen, den kein Zweig ändert, notfalls
  vorher eine Hilfsvariable setzen.

## 5. Aktionskatalog

### 5.0 Übersicht und gemeinsame Regeln

Zuordnung Dialogname → XML-Typ über die Abschnittskommentare des US-Autors direkt vor den Aktionen [sicher].

| Dialog / Doku-Name | `type` | Doku | Beleg |
|---|---|---|---|
| Nachrichten anzeigen | ShowMsg | t23373 | US Z.20–51 |
| Benutzereingabe | UserInput | t23381 | US Z.52–67 |
| Variable setzen | SetVar | t23341 | US Z.73–94; CTU Z.10–53 |
| Variable ermitteln | EvalVar | t23415 ff. | US Z.95–171 |
| Datei(en) kopieren | CopyFiles | t23428 | US Z.182–205 |
| Datei(en) löschen | DeleteFiles | t23445 | US Z.211–220 |
| Dateien und Verzeichnisse verschieben | MoveFileOrFolder | t23449 | US Z.226–231 |
| Verzeichnis erstellen | CreateFolder | t23435 | US Z.237–242 |
| Verzeichnis löschen | DeleteFolder | t23431 | US Z.248–252 |
| Shortcut erstellen | CreateShortcut | t23443 | US Z.258–369 |
| Shortcut löschen | DeleteShortcut | t23439 | US Z.375–381 |
| Text in Datei erstellen | CreateFile | t23442 | US Z.387–413, 777–784 |
| Datei herunterladen | DownloadFile | t23447 | US Z.419–425 |
| Archiv entpacken | Unzip | t23448 | US Z.431–437 |
| Setze Wert in INI-Datei | SetIniValue | t23440 | US Z.443–450 |
| Registrierungsschlüssel erstellen | CreateRegKey | t23405 | US Z.461–496 |
| Registrierungsschlüssel löschen | DeleteRegKey | t23413 | US Z.502–507 |
| Wert in Registry setzen | SetRegValue | t23393 | US Z.513–522 |
| Wert in Registry löschen | DeleteRegValue | t23416 | US Z.528–534 |
| Registry-Schlüssel aus Datei importieren | kein eigener Typ | t23385 | US Z.540–561 |
| Dienst starten / beenden / löschen | StartService / StopService / DeleteService | t23357, t23365, t23349 | US Z.572–623 |
| Prozess starten | LaunchProcess | t23409 | US Z.634–663 |
| Prozess beenden | TerminateProcess | t23434 | US Z.669–682 |
| Eingebettetes CMD ausführen | RunEmbeddedCmd | t23433 | US Z.683–693 |
| Eingebettetes Skript ausführen | RunEmbeddedScript | t23436 | US Z.694–703; CTU Z.59–67 |
| Warten | Wait | t23437 | US Z.709–718 |
| x64-Modus setzen | SetX64Mode | t23432 | US Z.724–733; CTU Z.54–58 |
| Tastatur- und Maussperre | KeyboardMouseLock | t23417 | US Z.739–746 |
| Kommentar | Comment | t23368 | US Z.10–14 u. v. a. |
| Sprungmarke / Gehe zu Sprungmarke | Label / GotoLabel | t23408, t23392 | US Z.757–766 |
| Unterroutine / Unterroutine ausführen | Subroutine / CallSubroutine | t23397, t23360 | US Z.767–789 |
| Bedingungsgruppe | Conditional | t23376 | US Z.795–859 |
| Skript beenden | EndBDS | t23384 | US Z.865–885; CTU Z.68–115 |
| bDS einbinden | IncludeBDS (5.7) | t23400 | baramundi-Installationsskript, W4 |

Gemeinsame Regeln [sicher, beide Samples]:
- Standardlayout: `<ACTION …>`, `<DATA>`, je Kindelement eine Zeile `<NAME>Wert</NAME>`, `</DATA>`, optional `<CONDITION …/>`, `</ACTION>`; klassische Feldnamen in GROSSBUCHSTABEN.
- Abweichendes Layout bei UserInput, EvalVar, Wait und KeyboardMouseLock – genau wie in den Skeletten.
- Leere Felder als Paar `<X></X>`, nie `<X/>`. Selbstschließend sind nur `INFO`, `CONDITION` und `<Value/>` in Properties.
- Wahrheitswerte: klassische Felder 0/1; `USERINPUTUSETIMEOUT` und `KEYBOARDMOUSELOCK` als `true`/`false` in Kleinbuchstaben.
- Elementreihenfolge je Typ wie im Skelett; sie folgt nicht immer dem Dialog.

### 5.1 Benutzerinteraktion

#### ShowMsg – Nachrichten anzeigen (t23373)

```xml
<ACTION type="ShowMsg" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<FORMAT>0</FORMAT>
<CONTENT>[[Text]]</CONTENT>
<OPTIONS>47</OPTIONS>
<TIMEOUT>60</TIMEOUT>
</DATA>
</ACTION>
```

- `FORMAT` = Typ: 0 Text, 1 HTML, 2 URL, 3 Datei. 2 und 3 [sicher] (US Z.38–47: https-URL bzw. Pfad einer .log-Datei); 0 und 1 [wahrscheinlich] (Index = Dropdown-Reihenfolge in t23373, durch 2 und 3 bestätigt). Widerspruch: Eine Recherche hielt 0/1 für ungeklärt; die Indexlogik gewinnt, weil sie für 2/3 belegt ist.
- `CONTENT` = Inhalt: Klartext, HTML-Quelltext (escaped), URL oder Dateipfad aus Client-Sicht [sicher] (t23373). „Importieren“ übernimmt den Dateiinhalt ins Feld, „Durchsuchen“ nur den Pfad [sicher] (t23373).
- `TIMEOUT` = Dauer in Sekunden, mindestens 10; wird immer geschrieben, ohne Timeout als 0 [sicher] (t23373; US: immer 60; SD-I: 0).
- `OPTIONS` = Bitmaske. Beobachtet: 47 (Text), 39 (HTML), 63 (URL), 33 (Datei), 32 (Text ohne Timeout, SD-I); Bit 32 ist immer gesetzt [sicher]. Dialog (Bild user-interaction01.png): Timeout verwenden, Einfluss (verändern / nicht verändern / deaktivieren), Fenster im Vordergrund halten, Skriptausführung sofort fortsetzen.
  - 8 = Fenster im Vordergrund halten [wahrscheinlich] (47 und 39 unterscheiden sich nur darin; der Doku-Dialog hat es aktiv).
  - 16 = Skriptausführung sofort fortsetzen [wahrscheinlich] (nur in 63; letzte Option im Dialog).
  - 2+4 = Einfluss: 6 vermutlich „Benutzer kann Timeout verändern“ (Buttons „Moment noch“ und „Timeout abbrechen“), 0 = „nicht verändern“; Kodierung von „deaktivieren“ unbekannt (evtl. nur 4) [geraten].
  - 1 = Timeout verwenden [wahrscheinlich] (fehlt nur bei 32 mit TIMEOUT 0 in SD-I); 32 unbekannt, immer setzen.
  - Generator: nur beobachtete Werte. 47 = Standard (Vordergrund, Skript wartet), 39 = ohne Vordergrund, 63 = 47 + sofort fortsetzen, 33 = ohne Einfluss-Bits und Vordergrund [Werte sicher, Deutung geraten]. 32 (wartet ohne Zeitlimit auf „Weiter >“) nur auf ausdrücklichen Wunsch und nie in unbeaufsichtigten Jobs.
- Laufzeit: Fenster „baramundi Deploy Script“ mit Fortschrittsbalken, je nach Einfluss Buttons „Moment noch“ und „Timeout abbrechen“, immer „Weiter >“ [sicher] (Bild user-interaction02.png). Das Doku-Bildpaar ist kein Beleg für die Einfluss-Kodierung: Der Dialog steht auf „deaktivieren“, das Laufzeitbild zeigt beide Buttons.
- Braucht einen sichtbaren Desktop: Applikationseinstellung „Sichtbare Ausführung“ nicht auf „Unsichtbar“ [wahrscheinlich] (W16); in Shutdown-Jobs nicht nutzbar, weil dort die sichtbare Ausführung aus sein muss [wahrscheinlich] (W20).

#### UserInput – Benutzereingabe (t23381)

```xml
<ACTION type="UserInput" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<USERINPUTCAPTION>[[Titel]]</USERINPUTCAPTION><USERINPUTTEXT>[[Text]]</USERINPUTTEXT><VARNAME>[[Rueckgabevariable]]</VARNAME><USERINPUTBUTTONS><USERINPUTBUTTONTEXT>[[Button1]]</USERINPUTBUTTONTEXT><USERINPUTBUTTONTEXT>[[Button2]]</USERINPUTBUTTONTEXT><USERINPUTBUTTONTEXT>[[Button3]]</USERINPUTBUTTONTEXT><USERINPUTBUTTONTEXT>[[Button4]]</USERINPUTBUTTONTEXT><USERINPUTBUTTONTEXT>[[Button5]]</USERINPUTBUTTONTEXT></USERINPUTBUTTONS><USERINPUTDEFAULTCHOICE>2</USERINPUTDEFAULTCHOICE><USERINPUTUSETIMEOUT>true</USERINPUTUSETIMEOUT><USERINPUTTIMEOUT>60</USERINPUTTIMEOUT><USERINPUTICON>32</USERINPUTICON></DATA>
</ACTION>
```

- Layout: Nach `<DATA>` + CRLF stehen alle Kinder samt `</DATA>` in einer Zeile [sicher] (US Z.54, 58, 62, 66).
- `USERINPUTCAPTION` = Titel, `USERINPUTTEXT` = Text, `VARNAME` = Rückgabevariable (leer → `UserInput`, geschrieben als `<VARNAME/>`) [sicher] (Bild user-interaction03.png; t23381; SD-I). Variablen in allen Texten erlaubt [sicher] (t23381). Zeilenumbruch im Text als `&#x0d;&#x0a;`, damit alles in einer Zeile bleibt [sicher] (SD-I).
- `USERINPUTBUTTONS`: je Schaltfläche ein `USERINPUTBUTTONTEXT`, 1 bis 5 Stück [sicher] (US: 5, SD-I: 1 und 3). Ist der Text zur Laufzeit leer, wird die Schaltfläche ausgeblendet [sicher] (t23381). Generator: nur so viele Elemente wie Schaltflächen.
- **Rückgabe**: Nummer der gedrückten Schaltfläche ab 1; Fenster geschlossen → `CANCEL` [sicher] (SD-I: `{UserInput} = 1` für die einzige Schaltfläche, `DateAdd("d", {UserInput}, Date)` hinter „1 Tag / 2 Tage / 3 Tage“, Rücksprung bei `CANCEL`). Wert nach Ablauf des Timeouts unbekannt.
- Auswahl erzwingen (nur in betreuten Jobs): Label vor der Abfrage, danach GotoLabel mit Bedingung `{UserInput} = CANCEL` [sicher] (SD-I).
- `USERINPUTDEFAULTCHOICE` (Rasterzeile „Standard…“, im Bild verdeckt): beobachtet 2 (Timeout an), 10000 (viermal, Timeout aus; US und SD-I), 10002 (Timeout an) [sicher]. Bedeutung unbekannt; Hypothese: Flag +10000 (Bedeutung offen) plus Index 0–4 [geraten]. Generator: UserInput nur auf ausdrücklichen Wunsch und immer mit Timeout (`true` mit dem beobachteten Wert 2) – ohne Timeout kann ein unbeaufsichtigter Job blockieren [geraten]. Wert und Folgebedingungen im Studio prüfen lassen (Abschnitt 9).
- `USERINPUTUSETIMEOUT` `true`/`false`, `USERINPUTTIMEOUT` Sekunden (auch bei false geschrieben) [sicher] (US Z.58, 66). Die Restzeit steht im Titel („Titel - 42 s“) [sicher] (Bild user-interaction03.png).
- `USERINPUTICON` 16 Stop, 32 Frage, 48 Warnung, 64 Information (MessageBox-Konstanten) [sicher]. Wert für „kein Icon“ unbekannt.
- Höchstens 5 Schaltflächen [sicher]. Die Antwort mit Bedingungen auf die Nummer auswerten, plus Auffang für `CANCEL` und Timeout.

### 5.2 Variablen

#### SetVar – Variable setzen (t23341)

```xml
<ACTION type="SetVar" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>[[Name]]</VARNAME>
<VALUE>[[Wert]]</VALUE>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
```

- `VARNAME` ohne `{}`; `VALUE` Freitext inkl. Platzhalter [sicher] (t23341). Belegt: `{JobParam.X}` (CTU Z.13), Liste `1;2;3;Vier;5;6` (US Z.83), Literale `$true`/`$false` zum späteren Einsetzen in PowerShell (CTU Z.34, 42).
- `OPTIONS` 1 = „Existierende Variable nicht überschreiben“ (einzige Option des Dialogs), 0 = überschreiben [wahrscheinlich] (t23341; Bild set-variable.png; US Z.84, 91).
- Muster: mehrere SetVar auf dieselbe Variable mit je eigener CONDITION (CTU Z.31–46) [sicher]. Verbesserung: zuerst ein unbedingtes SetVar mit Standardwert.

#### EvalVar – Variable ermitteln (t23415)

```xml
<ACTION type="EvalVar" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<VARNAME>[[Name]]</VARNAME>
<SOURCE>[[Quelle]]</SOURCE>
<OPTIONS>0</OPTIONS>
[[Properties-Zeile der Quelle, endet mit </DATA>]]
</ACTION>
```

- Layout: `VARNAME`, `SOURCE`, `OPTIONS` je eine Zeile, danach `<Properties>…</Properties></DATA>` in einer Zeile [sicher] (US Z.95–171, 11×).
- PropertyEntry-Einträge stehen alphabetisch nach `Param`, nicht in Dialogreihenfolge (alle 13 Properties-Blöcke in US, inkl. Wait) [sicher]. Ob Pflicht, ist unbekannt → nachbilden. Leerer Wert = `<Value/>` [sicher] (US Z.163).
- `OPTIONS`: immer 0 beobachtet; 1 = „Existierende Variable nicht überschreiben“ analog SetVar [geraten] (Checkbox in allen Screenshots determine-variables*).
- Nichts gefunden: Registry-Wert fehlt → `NOTFOUND` [sicher] (SD-I, Bedingung `<> NOTFOUND`); Zeile hinter dem Dateiende → `NOTFOUND` [sicher] (SD-P, Schleifenende); fehlender INI-Parameter → leer laut Annahme von SD-P [geraten] → auf leer und `NOTFOUND` prüfen; XML-Knoten unbekannt.

| SOURCE | Dialog-Quelle | Params → Dialogfeld | Ergebnis, Hinweise |
|---|---|---|---|
| Registry | Registrierung (t23414) | Key = Schlüssel ohne Hive; Registry = Hive als **Text**; Value = Wertname | Daten des Werts, fehlt er: `NOTFOUND` [sicher] (SD-I). Mehrteilige Werte (REG_MULTI_SZ wie PendingFileRenameOperations) lassen sich mit CONTAINS durchsuchen [sicher] (SD-I). Hive-Text belegt für HKEY_LOCAL_MACHINE (US Z.100) und HKEY_CURRENT_USER (Bild determine-variables01.png) [sicher], übrige analog [wahrscheinlich]. 64-Bit-Zweig nur mit vorherigem SetX64Mode 1 [sicher] (t23414). |
| IniFile | INI-Datei (t23382) | File, Param (Parameter), Section (Sektion) | Wert des Parameters [sicher]. INI-Datei als ANSI speichern, sonst kommen Umlaute falsch an [wahrscheinlich] (Doku zu SD-P). |
| SubString | Teilstring (t23427) | Length, Start, String | Startposition vermutlich 0-basiert (Doku-Bild: „baramundi“, Start 0, Länge 4) [geraten] |
| StringReplacement | Ersetzung in Zeichenkette (t23422) | Replace (zu ersetzen), Replacement (ersetzen mit), String | ersetzt vermutlich alle Vorkommen; Groß-/Kleinschreibung unbekannt [geraten] |
| StringToken | Listenelement (t23398) | Delimiter, Index, String | Index 1-basiert [sicher] (t23398: 1 = erstes Element). Widerspruch zu einer Recherche, die nur aus US „niedrig“ ableitete: die Doku gewinnt. |
| InstalledSoftwareInfo | Installierte Software Infos (t23390) | Name = Anzeigename; `*` `?` → Array | FOUND/NOTFOUND; Kinder je nach Daten: .DisplayName, .DisplayVersion, .InstallDate (yyyyMMdd), .InstallSource, .Key (Uninstall-Schlüssel), .Language (LCID), .Publisher, .SystemComponent, .UninstallString [sicher] (Bild determine-variables08.png). 32/64-Bit-Uninstall-Zweig: unbekannt. |
| Expression | Berechneter Ausdruck (t23430) | Expression | Ergebnis des Ausdrucks (Abschnitt 7). „Expression“ = neuer baramundi-Interpreter, nicht „VBS (veraltet)“ [wahrscheinlich] (US folgt der Quellenreihenfolge von t23415 und lässt genau „VBS (veraltet)“ und „Abbilddatei“ aus). |
| FileInfo | Datei- und Verzeichnisinformationen (t23377) | FileTimes (Zeitstempel: 0/1), Name | immer FOUND/NOTFOUND; Kinder u. a. .Attribs, .Company, .Description, .FileName, .FileVersion, .InternalVersion, .Language, .Name (voller Pfad), .OriginalFilename, .Path, .ProductName, .ProductVersion, .Size, .Version [sicher] (Bild determine-variables10a.png). FileTimes 1 = an [wahrscheinlich]; Namen der Zeitstempel-Kinder unbekannt. Mit Wildcard (`{Ordner}\**\*.ini`, `**` = auch Unterordner) eine Liste: `{Var}` FOUND/NOTFOUND, `{Var.Count}`, `{Var.<n>.Name}` (voller Pfad), `{Var.<n>.FileName}` (nur Dateiname), n ab 1 [sicher] (SD-P). |
| ProcessInfo | Prozessinformationen (t23406) | Name = Prozessname oder PID | immer FOUND/NOTFOUND; .Account, .CPU (%), .CommandLine, .Created (dd.MM.yyyy HH:mm:ss), .Created.Date (yyyyMMdd), .Created.Time (HHmmss), .Filename, .PID, .WorkingSetSize [sicher]. Alle Instanzen nur mit angehängter Wildcard (`explorer.exe*`) → Array [sicher]. |
| XML | XML (t23333) | Attribute (optional), Default, Name (Datei), Path | Path als Schrägstrichpfad ab Wurzel, ohne führenden `/` und ohne Namespace-Präfix (`unattend/settings/component`) [wahrscheinlich] (Bild determine-variables13.png). Default gilt bei fehlendem Attribut [sicher]. Ergebnis ohne Attribut (Elementtext?) unbekannt. |
| TextFile | Textdatei (t23326) | Index (Zeilennummer, leer = ganze Datei), Name | Zeilen ab 1; hinter der letzten Zeile `NOTFOUND` [sicher] (SD-P: Schleife über alle Zeilen, 5.7). Das in t23326 genannte Feld „XML-Pfad“ fehlt im Dialog (Bild determine-variables14.png) → Kopierfehler der Doku [wahrscheinlich]. |

Properties-Zeilen (exakt, alphabetisch):

Registry:
```xml
<Properties><PropertyEntry><Param>Key</Param><Value>[[SOFTWARE\Pfad]]</Value></PropertyEntry><PropertyEntry><Param>Registry</Param><Value>HKEY_LOCAL_MACHINE</Value></PropertyEntry><PropertyEntry><Param>Value</Param><Value>[[Wertname]]</Value></PropertyEntry></Properties></DATA>
```
IniFile:
```xml
<Properties><PropertyEntry><Param>File</Param><Value>[[Pfad.ini]]</Value></PropertyEntry><PropertyEntry><Param>Param</Param><Value>[[Parameter]]</Value></PropertyEntry><PropertyEntry><Param>Section</Param><Value>[[Sektion]]</Value></PropertyEntry></Properties></DATA>
```
SubString:
```xml
<Properties><PropertyEntry><Param>Length</Param><Value>[[Laenge]]</Value></PropertyEntry><PropertyEntry><Param>Start</Param><Value>[[Start]]</Value></PropertyEntry><PropertyEntry><Param>String</Param><Value>[[Text]]</Value></PropertyEntry></Properties></DATA>
```
StringReplacement:
```xml
<Properties><PropertyEntry><Param>Replace</Param><Value>[[Suchtext]]</Value></PropertyEntry><PropertyEntry><Param>Replacement</Param><Value>[[Ersatz]]</Value></PropertyEntry><PropertyEntry><Param>String</Param><Value>[[Text]]</Value></PropertyEntry></Properties></DATA>
```
StringToken:
```xml
<Properties><PropertyEntry><Param>Delimiter</Param><Value>[[;]]</Value></PropertyEntry><PropertyEntry><Param>Index</Param><Value>[[1..n]]</Value></PropertyEntry><PropertyEntry><Param>String</Param><Value>[[Liste]]</Value></PropertyEntry></Properties></DATA>
```
InstalledSoftwareInfo:
```xml
<Properties><PropertyEntry><Param>Name</Param><Value>[[Anzeigename]]</Value></PropertyEntry></Properties></DATA>
```
Expression:
```xml
<Properties><PropertyEntry><Param>Expression</Param><Value>[[Ausdruck]]</Value></PropertyEntry></Properties></DATA>
```
FileInfo:
```xml
<Properties><PropertyEntry><Param>FileTimes</Param><Value>0</Value></PropertyEntry><PropertyEntry><Param>Name</Param><Value>[[absoluter Pfad]]</Value></PropertyEntry></Properties></DATA>
```
ProcessInfo:
```xml
<Properties><PropertyEntry><Param>Name</Param><Value>[[name.exe]]</Value></PropertyEntry></Properties></DATA>
```
XML:
```xml
<Properties><PropertyEntry><Param>Attribute</Param><Value>[[Attribut]]</Value></PropertyEntry><PropertyEntry><Param>Default</Param><Value/></PropertyEntry><PropertyEntry><Param>Name</Param><Value>[[Pfad.xml]]</Value></PropertyEntry><PropertyEntry><Param>Path</Param><Value>[[wurzel/element]]</Value></PropertyEntry></Properties></DATA>
```
TextFile:
```xml
<Properties><PropertyEntry><Param>Index</Param><Value>[[Zeile]]</Value></PropertyEntry><PropertyEntry><Param>Name</Param><Value>[[Pfad.txt]]</Value></PropertyEntry></Properties></DATA>
```

Hinweise FileInfo (t23377): Pfade absolut, Verzeichnisse ohne abschließenden Backslash; Wildcards erzeugen ein Array. Die Doku ist zur Lage der Wildcard widersprüchlich; belegt ist `{Ordner}\**\*.ini`: findet die Dateien im Ordner und in allen Unterordnern, auch mit Umlauten im Namen [sicher] (SD-P). Für Versionsvergleiche `.Version` (normalisiert, z. B. 2007.100.1600.22) statt `.FileVersion` (Rohtext mit Zusätzen) [wahrscheinlich] (Bild determine-variables10a.png). Ohne x64-Modus landen System32-Pfade vermutlich in SysWOW64 [wahrscheinlich] (t23432). Der Screenshot in t23377 zeigt fälschlich den Ausdrucksdialog.

### 5.3 Dateioperationen

#### CopyFiles – Datei(en) kopieren (t23428)

```xml
<ACTION type="CopyFiles" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<SOURCE>[[Quellverzeichnis]]</SOURCE>
<DESTINATION>[[Zielverzeichnis]]</DESTINATION>
<FILES>[[Datei oder Muster;Muster]]</FILES>
<OPTIONS>11</OPTIONS>
</DATA>
</ACTION>
```

- `SOURCE` = Quellverzeichnis (UNC-Pfad, `{DIP}\…`), `DESTINATION` = Zielverzeichnis aus Sicht des Clients, `FILES` = Dateiname oder Muster, mehrere mit `;`, `*` als Wildcard [sicher] (t23428; US Z.182–205). DESTINATION mit und ohne abschließenden Backslash beobachtet [sicher].
- `OPTIONS` = Bitmaske der 7 Checkboxen (Bild file-operations01.png). Beobachtet: 11 (Einzeldatei) und 27 (`*` bzw. `*.bmp;*.png`) [sicher]. Zuordnung in Doku- bzw. Tab-Reihenfolge (linke Spalte, dann rechte):

| Bit | Option | Sicherheit |
|---|---|---|
| 1 | Existierende Dateien überschreiben | [wahrscheinlich] als Gruppe mit 2 und 8 (nie einzeln beobachtet) |
| 2 | Schreibgeschützte Dateien überschreiben (Unteroption von 1) | wie oben |
| 4 | Neuere Dateien nicht überschreiben (Unteroption von 1) | [geraten] |
| 8 | Gesperrte Files beim nächsten Reboot überschreiben | wie Bit 1 |
| 16 | Verzeichnisse mit allen Unterverzeichnissen kopieren | [wahrscheinlich] (einziger Unterschied 11 → 27, nur bei Wildcard-Kopien) |
| 32 | Backups von überschriebenen Dateien erstellen (`<Name>.$bak1$`) | [geraten] |
| 64 | NTFS-Berechtigungen kopieren (inkl. Besitzer) | [geraten] |

  Gegenhypothese zeilenweise Nummerierung (dann 16 = „Neuere nicht überschreiben“) ist weniger plausibel, weil 16 dann nicht an die Wildcard-Kopien gekoppelt wäre. Generator: 11 = überschreiben inkl. schreibgeschützt, gesperrte beim Reboot; 27 = zusätzlich rekursiv. Andere Kombinationen erst nach Prüfung im Studio.
- Ohne „Überschreiben“ wird eine vorhandene Zieldatei still übersprungen, ohne Fehler [sicher] (t23428). „Gesperrte beim Reboot“ löst keinen Neustart aus [wahrscheinlich]. Ob ein fehlendes Zielverzeichnis angelegt wird, ist undokumentiert → vorher CreateFolder [wahrscheinlich sinnvoll]. Netzwerkquellen nicht im x64-Modus kopieren (t23432).

#### DeleteFiles – Datei(en) löschen (t23445)

```xml
<ACTION type="DeleteFiles" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Pfad\Datei oder Pfad\*.tmp]]</NAME>
</DATA>
</ACTION>
```

- `NAME` = Pfad mit Dateiname oder `*`-Muster, kein OPTIONS [sicher] (t23445; US Z.211–220). Semikolonlisten und rekursives Löschen: unbekannt.

#### MoveFileOrFolder – Dateien und Verzeichnisse verschieben (t23449)

```xml
<ACTION type="MoveFileOrFolder" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<SOURCE>[[Quelle]]</SOURCE>
<DESTINATION>[[Zielordner]]</DESTINATION>
</DATA>
</ACTION>
```

- `SOURCE` = Datei oder Verzeichnis, `DESTINATION` = Ziel; kein OPTIONS [sicher] (US Z.226–231). Beobachtet ist Datei → Zielordner; ob DESTINATION auch ein neuer Name sein darf und was bei vorhandenem Ziel passiert, ist unbekannt.

#### CreateFolder – Verzeichnis erstellen (t23435)

```xml
<ACTION type="CreateFolder" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Pfad]]</NAME>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
```

- `OPTIONS` immer 0 schreiben; Bedeutung unbekannt, der Doku-Dialog hat keine Option [sicher für 0] (US Z.240). Ein Pfad je Aktion, keine Semikolonliste [sicher] (t23435); Zwischenebenen werden angelegt [wahrscheinlich] (Doku-Beispiel).
- Ob ein vorhandener Ordner einen Fehler auslöst, ist undokumentiert; baramundi selbst setzt `ignore_error="1"`. Sauberer:
  vorher FileInfo auf den Ordner und CreateFolder nur bei `NOTFOUND` (Bedingung an der Aktion).

#### DeleteFolder – Verzeichnis löschen (t23431)

```xml
<ACTION type="DeleteFolder" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Pfad]]</NAME>
</DATA>
</ACTION>
```

- Löscht samt allen Dateien und Unterverzeichnissen; kein OPTIONS (anders als CreateFolder) [sicher] (t23431; US Z.248–252).

#### CreateShortcut – Shortcut erstellen (t23443)

```xml
<ACTION type="CreateShortcut" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Bezeichnung]]</NAME>
<FILENAME>[[Ziel der Verknüpfung]]</FILENAME>
<ARGEUMENT></ARGEUMENT>
<WORKINGDIR></WORKINGDIR>
<SYMBOL>[[Pfad.ico:0]]</SYMBOL>
<DESCRIPTION></DESCRIPTION>
<RELPATH></RELPATH>
<USERTYPE>0</USERTYPE>
<LOCATIONTYPE>0</LOCATIONTYPE>
<SHOWSTYLE>NORMAL</SHOWSTYLE>
</DATA>
</ACTION>
```

- Felder: `NAME` = Bezeichnung, `FILENAME` = Dateiname (Ziel), `ARGEUMENT` = Argumente, `WORKINGDIR` = Arbeitsverzeichnis, `SYMBOL` = Symbol, `DESCRIPTION` = Beschreibung, `RELPATH` = Relativer Pfad (Pfad zum Programm ohne Dateiname) [sicher] (t23443; Bild file-operations05.png; US Z.258–271).
- `ARGEUMENT` ist ein Tippfehler des Herstellers und muss exakt so heißen; in allen 8 Samples leer [sicher]. Was mit `ARGUMENT` passiert, ist unbekannt.
- `SYMBOL` = Icon-Datei oder -Bibliothek + `:Index`; bei .ico oder Einzel-Icon `:0` [sicher] (t23443). Das Doku-Bild nutzt `%SystemRoot%` ohne Klammern; ob das aufgelöst wird, ist unbekannt → `{%SystemRoot%}` oder absoluter Pfad [geraten].
- `LOCATIONTYPE` (Dialog „Ziel“): 0 Desktop, 1 Startmenü, 2 Programme, 3 Autostart [sicher] (Bezeichnungen der US-Shortcuts Z.260–310 und Reihenfolge in t23443). Widerspruch: eine Recherche stufte dies nur „mittel“ ein; Bezeichnung plus Doku-Reihenfolge reichen für [sicher].
- `USERTYPE` (Dialog „Benutzer“): 0 Alle Benutzer [wahrscheinlich] (Doku-Reihenfolge, Ausschluss, DeleteShortcut-Pfad `C:\Users\Public\Desktop`), 1 Angemeldeter Benutzer, 2 Standardbenutzer (Default-Profil) [sicher] (US Z.316, 330).
- `SHOWSTYLE` (Dialog „Ausführen“) als Text: `NORMAL`, `MINIMIZED`, `MAXIMIZED` [sicher] (US Z.269, 353, 367).
- Verhalten von USERTYPE 1 ohne angemeldeten Benutzer: unbekannt.

#### DeleteShortcut – Shortcut löschen (t23439)

```xml
<ACTION type="DeleteShortcut" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Verknuepfung]]</NAME>
<USERTYPE>0</USERTYPE>
<LOCATIONTYPE>0</LOCATIONTYPE>
</DATA>
</ACTION>
```

- Dialog (Bild file-operations06.png): Quelle = `LOCATIONTYPE`, Benutzer = `USERTYPE`, Verknüpfung = `NAME`; Kodierung wie CreateShortcut [wahrscheinlich].
- Ob `NAME` die Bezeichnung oder einen vollen .lnk-Pfad erwartet, ist unklar; US nutzt den vollen Pfad (Z.377). Eindeutige Alternative: DeleteFiles auf den .lnk-Pfad [wahrscheinlich].

#### CreateFile – Text in Datei erstellen (t23442)

```xml
<ACTION type="CreateFile" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<FILENAME>[[Pfad]]</FILENAME>
<ENCODING>1</ENCODING>
<CONTENT>[[Text]]</CONTENT>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- Reihenfolge `FILENAME`, `ENCODING`, `CONTENT`, `OPTIONS` [sicher] (US Z.387–413, 777–784).
- `ENCODING`: Dialoglabel „ASCII“ bzw. „UTF8“; 1 = UTF8 [wahrscheinlich] (US-Text „UTF-8 text datei“ bei 1, Doku-Reihenfolge), 0 = „ASCII“. Mit 0 kommen Umlaute lesbar an [wahrscheinlich] (SD-P schreibt sein Log mit 0, im PDF steht „SW für alle.ini“ korrekt) – vermutlich ANSI, die genauen Bytes und ein BOM bei 1 sind ungeprüft.
- `OPTIONS`: 1 = überschreiben, falls vorhanden [wahrscheinlich] (einzige Checkbox im alten Dialog, Bild file-operations08.png; Doku-Beispiel überschreibt); 0 = nicht überschreiben [wahrscheinlich] (US-Text Z.408); 2 = anhängen, legt die Datei beim ersten Mal an [sicher] (US-Text „hinzugefügt“ Z.399; SD-P schreibt so ein ganzes Log, Ergebnis im PDF). Widerspruch Dialog (nur Checkbox) gegen Sample (drei Werte): das neuere Sample gewinnt. Verhalten bei 0 und vorhandener Datei (Fehler oder still) unbekannt. 3 nie beobachtet → nicht verwenden.
- Zeilenumbrüche in `CONTENT` als CRLF; ein Schlussumbruch gehört zum Inhalt (beim Anhängen sinnvoll).
- Muster Log ohne PowerShell (SD-P): Unterroutine „Log schreiben“ mit EvalVar `Zeit` ← Expression `Now()` und
  CreateFile `OPTIONS` 2, `CONTENT` = `{Zeit}: {Meldung}` + CRLF; Aufruf nach SetVar `Meldung`. Den Dateinamen einmal
  am Anfang bilden (Zeitstempel ohne `:` und `/`, 7).

#### DownloadFile – Datei herunterladen (t23447)

```xml
<ACTION type="DownloadFile" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<URL>[[https://…]]</URL>
<FILENAME>[[voller Zielpfad mit Dateiname]]</FILENAME>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- `OPTIONS` 1 = „Datei überschreiben, falls sie schon existiert“ (einzige Checkbox) [wahrscheinlich] (Bild file-operations09.png; US Z.423).
- Fehlt die Quelle oder existiert das Ziel ohne Überschreiben-Option, meldet die Aktion einen Fehler und das Skript bricht ab [sicher] (t23447). `&` in der URL als `&amp;`. Nicht im x64-Modus ausführen (t23432).

#### Unzip – Archiv entpacken (t23448)

```xml
<ACTION type="Unzip" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<FILENAME>[[Archiv.zip]]</FILENAME>
<TARGET>[[Zielverzeichnis\]]</TARGET>
<OPTIONS>0</OPTIONS>
</DATA>
</ACTION>
```

- `OPTIONS` immer 0, Bedeutung unbekannt [sicher für 0] (US Z.435). Belegt ist nur .zip; Überschreibverhalten unbekannt.

#### SetIniValue – Setze Wert in INI-Datei (t23440)

```xml
<ACTION type="SetIniValue" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<INIFILE>[[Pfad.ini]]</INIFILE>
<SECTION>[[Abschnitt]]</SECTION>
<INIVALUENAME>[[Name]]</INIVALUENAME>
<VALUE>[[Daten]]</VALUE>
</DATA>
</ACTION>
```

- Kein OPTIONS; vorhandene Parameter werden geändert, fehlende Parameter, Sektionen und Dateien angelegt [sicher] (t23440; US Z.443–450).

### 5.4 Registry

Hive-Kodierung der Registry-Aktionen (Win32-HKEY-Konstanten) [sicher]:

| REGISTRY | Hive |
|---|---|
| 2147483648 | HKEY_CLASSES_ROOT |
| 2147483649 | HKEY_CURRENT_USER |
| 2147483650 | HKEY_LOCAL_MACHINE |
| 2147483651 | HKEY_USERS (US: REGKEY `.DEFAULT\Test`) |
| 2147483653 | HKEY_CURRENT_CONFIG |
| 2147484162 | unbekannt (0x80000202) → nicht verwenden |

- 2147484162: Hypothese A = Dropdown-Eintrag „Interactive user“ (aktuell angemeldeter Benutzer; t23393 nennt ihn als einzigen Sondereintrag; er stünde in US als sechster Eintrag nach den fünf Hives) [geraten, bevorzugt]. Hypothese B = HKLM + 0x200 (KEY_WOW64_32KEY) [geraten]. Klärung: US im Studio öffnen und die Aktion aus Z.491 ansehen.
- Nicht verwechseln: EvalVar/Registry speichert den Hive als Text (`HKEY_LOCAL_MACHINE`), die vier Registry-Aktionen als Zahl [sicher] (US Z.100 vs. Z.463).
- `REGKEY` ohne Hive und ohne führenden Backslash [sicher] (US Z.464).
- Auf 64-Bit-Systemen vor Registry-Aktionen SetX64Mode 1 setzen, sonst greift die 32-Bit-Sicht (z. B. WOW6432Node) [sicher] (t23405, t23413, t23393, t23416; W8). Der Registry-Explorer im Studio zeigt die lokale Registry des Admin-PCs [sicher] (t23405).

#### CreateRegKey / DeleteRegKey (t23405, t23413)

```xml
<ACTION type="CreateRegKey" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<REGISTRY>2147483650</REGISTRY>
<REGKEY>[[SOFTWARE\Pfad]]</REGKEY>
</DATA>
</ACTION>
```

- DeleteRegKey identisch mit `type="DeleteRegKey"` [sicher] (US Z.502–507). Ob Unterschlüssel mitgelöscht werden, ist unbekannt.

#### SetRegValue – Wert in Registry setzen (t23393)

```xml
<ACTION type="SetRegValue" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<REGISTRY>2147483650</REGISTRY>
<REGKEY>[[SOFTWARE\Pfad]]</REGKEY>
<REGVALUENAME>[[Name]]</REGVALUENAME>
<VALUE>[[Daten]]</VALUE>
<REGVALUETYPE>4</REGVALUETYPE>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- Reihenfolge weicht vom Dialog ab: `VALUE` steht vor `REGVALUETYPE` [sicher] (US Z.513–522; Bild registry03.png).
- `REGVALUETYPE`: 1 = REG_SZ [wahrscheinlich] (W3: Hostname-Variable mit Typ 1), 4 = REG_DWORD [wahrscheinlich] (US Z.519 mit VALUE 1; W3). Weitere vermutlich nach Win32: 2 REG_EXPAND_SZ, 3 REG_BINARY, 7 REG_MULTI_SZ, 11 REG_QWORD [geraten].
- `OPTIONS` 1 = „Erstellen, falls nicht vorhanden“ (einzige Checkbox) [wahrscheinlich]. Mit 0 wird ein fehlender Wert nicht angelegt; ob dann ein Fehler kommt und ob 1 auch fehlende Schlüssel anlegt, ist unbekannt → CreateRegKey davor.
- Datenformat: belegt ist nur DWORD `1` (dezimal und hex nicht unterscheidbar); vermutlich dezimal [geraten]. Schreibweise für REG_BINARY und QWORD unbekannt.
- REG_MULTI_SZ: `|` trennt die Einträge; laut Doku-Tabelle schreibt `!|` ein `!` und `!!` ein `|` – wirkt vertauscht [Doku-Aussage sicher, Bedeutung geraten] → `!` und `|` in Werten meiden.

#### DeleteRegValue – Wert in Registry löschen (t23416)

```xml
<ACTION type="DeleteRegValue" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<REGISTRY>2147483650</REGISTRY>
<REGKEY>[[SOFTWARE\Pfad]]</REGKEY>
<REGVALUENAME>[[Name]]</REGVALUENAME>
</DATA>
</ACTION>
```

- Kein OPTIONS [sicher] (US Z.528–534). Wie der „(Standard)“-Wert adressiert wird, ist unbekannt.

#### Registry-Schlüssel aus Datei importieren (t23385)

Kein eigener Typ: Der Editor liest die .reg-Datei beim Bearbeiten und erzeugt Einzelaktionen [sicher] (t23385: „für jeden Schlüssel und Wert eine Erstellen-Aktion“; US Z.540–561). Der Client braucht die .reg-Datei nicht [wahrscheinlich]. Der Generator baut den Block selbst:

```xml
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>Beginn Import aus Registry-Datei [[[Pfad.reg]]]</VALUE>
</DATA>
</ACTION>
<ACTION type="CreateRegKey" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<REGISTRY>2147483650</REGISTRY>
<REGKEY>[[SOFTWARE\Pfad]]</REGKEY>
</DATA>
</ACTION>
<ACTION type="SetRegValue" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<REGISTRY>2147483650</REGISTRY>
<REGKEY>[[SOFTWARE\Pfad]]</REGKEY>
<REGVALUENAME>[[Name]]</REGVALUENAME>
<VALUE>[[Daten]]</VALUE>
<REGVALUETYPE>1</REGVALUETYPE>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>Ende Import aus Registry-Datei [[[Pfad.reg]]]</VALUE>
</DATA>
</ACTION>
```

- Alle Aktionen auf derselben Ebene [sicher] (US Z.540–561). Marker-Texte wörtlich wie im Sample: `Beginn Import aus Registry-Datei [<Pfad>]` bzw. `Ende Import aus Registry-Datei [<Pfad>]`, die eckigen Klammern gehören zum Text [sicher]. Der SetRegValue-Teil ist nur durch t23385 belegt; welche OPTIONS das Studio dort schreibt, ist unbekannt.

### 5.5 Dienste (t23357, t23365, t23349)

```xml
<ACTION type="StartService" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<TYPE>48</TYPE>
<SERVICENAME>[[Dienstname]]</SERVICENAME>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- `TYPE` ist eine feste Konstante je Typ: StartService 48, StopService 49, DeleteService 50 (kein Dialogfeld) [sicher] (US Z.574–619, je 2× gleich).
- `SERVICENAME` = Dienstname (Kurzname wie `wuauserv`, nicht Anzeigename) [wahrscheinlich] (US Z.575; Bild service-control01.png). Das Dropdown im Dialog listet die Dienste des Admin-PCs [sicher] (t23357).
- `OPTIONS` (Bild service-control01.png): 1 = „Auf Beendigung der Dienstfunktion warten“, 2 = „Fehler, wenn Dienst nicht existiert“, 3 = beide [wahrscheinlich] (Dialogreihenfolge; US: 1 und 2 je einzeln; 3 nicht beobachtet).
- DeleteService entfernt die Dienstregistrierung [sicher] (t23349); vorher StopService ausführen [wahrscheinlich].

### 5.6 Systemfunktionen

#### LaunchProcess – Prozess starten (t23409)

```xml
<ACTION type="LaunchProcess" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<COMMAND>[[Programm.exe]]</COMMAND>
<PARAM>[[Parameter]]</PARAM>
<RETURNCODES>0</RETURNCODES>
<VARNAME>[[ExitCodeVariable]]</VARNAME>
<PIDVARNAME></PIDVARNAME>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- Reihenfolge `COMMAND`, `PARAM`, `RETURNCODES`, `VARNAME`, `PIDVARNAME`, `OPTIONS`; kein HIDDENEXECUTION [sicher] (US Z.634–663).
- `COMMAND` = Kommando (meist .exe, Pfad aus Client-Sicht), `PARAM` = Parameter; gleiche Einträge wie im bMC möglich [sicher] (t23409). Pfade mit Variablen oder Leerzeichen in Anführungszeichen: `<COMMAND>&quot;{BMAPath}\BMACmd.exe&quot;</COMMAND>` [sicher] (SD-I, 13×); fester Pfad ohne Leerzeichen geht ohne (`C:\Windows\System32\shutdown.exe`, SD-I).
- `RETURNCODES` = „Rückgabewerte bei Erfolg“, Dialog-Standard 0 [sicher] (Bild system-functions01.png). `*` = jeder Exitcode gilt als Erfolg [wahrscheinlich] (US, CTU). Mehrere Codes mit Komma, z. B. `0,3010` – so in baramundis eigenem Installationsskript [sicher]; ein Web-Export nutzt `;`. Parameter dort in Variablen vorbereitet und verkettet (`{setupParam}{installdirParam}`), Pfade mit Leerzeichen als `&quot;…&quot;` im Wert. Ein Code außerhalb der Liste lässt die Aktion vermutlich fehlschlagen → Skriptabbruch ohne `ignore_error` [wahrscheinlich].
- `VARNAME` = „Rückgabewert in Variable“, nur mit „Auf Beendigung warten“; `PIDVARNAME` = „Prozess-ID in Variable“, nur ohne Warten [sicher] (t23409).
- `OPTIONS`: Bit 1 = Auf Beendigung warten [wahrscheinlich] (alle drei Samples ungerade und mit VARNAME, das Warten voraussetzt). Startverhalten Normal = kein Zusatzbit [wahrscheinlich]. Die Bits 2 und 4 kodieren Minimiert bzw. Unsichtbar, Zuordnung offen; beste Vermutung 2 = Unsichtbar, 4 = Minimiert [geraten] (US: `/c exit 1` mit 5, `/c exit 2` mit 3 – der Autor nummerierte offenbar den Dropdown-Index Normal 0, Minimiert 1, Unsichtbar 2). Generator: 1 (Normal + Warten); für unsichtbare Ausführung besser RunEmbeddedCmd mit HIDDENEXECUTION 1 oder Bit vorher im Studio klären.
- Warnung: Ohne Warten gestartete Prozesse können nach Jobende weiterlaufen; mit erhöhten Rechten sichtbar oder minimiert gestartete Prozesse kann ggf. ein nicht privilegierter Benutzer steuern [sicher] (t23409).

BMACmd – Client-Variable setzen (3.2) [sicher] (W17, SD-I):

```xml
<ACTION type="LaunchProcess" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<COMMAND>&quot;{BMAPath}\BMACmd.exe&quot;</COMMAND>
<PARAM>/Cmd:SetCustomVar /Category:[[Kategorie]] /Name:[[Name]] /Value:&quot;{[[Variable]]}&quot;</PARAM>
<RETURNCODES>0</RETURNCODES>
<VARNAME></VARNAME>
<PIDVARNAME></PIDVARNAME>
<OPTIONS>1</OPTIONS>
</DATA>
</ACTION>
```

- Wert immer in Anführungszeichen (W17: Parameter mit Leerzeichen in Anführungszeichen); leeren mit `/Value:&quot;&quot;`. BMACmd braucht keine erhöhten Rechte [sicher] (W17). Rückgabewerte laut W17 (dort beim Kommando OpenKiosk): 0 = Erfolg, 1 = Kommunikationsfehler bMA/BMACmd, 2 = bMA nicht erreichbar, 3 = bServer nicht erreichbar [wahrscheinlich auch für SetCustomVar]. Weitere Kommandos: `/Cmd:Log /Type:<1|2|4> /Text:"<Text>"` (Eintrag im Serverlog; 1 Information, 2 Warnung, 4 Fehler), `/Cmd:RestartJob /Job:"<Name>"` (nur für bereits zugewiesene Jobs) [sicher] (W17).

#### TerminateProcess – Prozess beenden (t23434)

```xml
<ACTION type="TerminateProcess" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[name.exe oder PID]]</NAME>
<OPTIONS>0</OPTIONS>
<RETURNCODE>0</RETURNCODE>
</DATA>
</ACTION>
```

- `NAME` = Prozessname oder PID [sicher] (t23434). `OPTIONS` 1 = „Fehler, wenn Prozeß nicht existiert“ (einzige Checkbox), 0 = kein Fehler [wahrscheinlich] (Bild system-functions03.png; US Z.672, 679). `RETURNCODE` (Singular) = „Returncode setzen“, Standard 0, vermutlich Exitcode für den beendeten Prozess [wahrscheinlich].
- Kann Datenverlust verursachen, wenn der Prozess Dateien offen hat [sicher] (t23434).

#### RunEmbeddedCmd – Eingebettetes CMD ausführen (t23433)

```xml
<ACTION type="RunEmbeddedCmd" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<SCRIPT>@echo off
[[Batch-Zeilen]]</SCRIPT>
<RETURNCODES>0</RETURNCODES>
<VARNAME></VARNAME>
<OPTIONS>1</OPTIONS>
<HIDDENEXECUTION>1</HIDDENEXECUTION>
</DATA>
</ACTION>
```

- Reihenfolge `SCRIPT`, `RETURNCODES`, `VARNAME`, `OPTIONS`, `HIDDENEXECUTION` [sicher] (US Z.683–693).
- `OPTIONS` 1 = „Auf Beendigung warten“ (Dialog-Standard an) [wahrscheinlich] (Bild system-functions0424R2.png). `VARNAME` wirkt vermutlich nur mit Warten [geraten, analog LaunchProcess].
- `HIDDENEXECUTION` 1 = „Unsichtbar ausführen“; Standard bei neuen Aktionen; fehlt das Element (Altskripte), läuft die Aktion sichtbar [sicher] (t23433). Immer schreiben.
- Batch-Zeilen mit CRLF (cmd.exe kann bei reinem LF u. a. Sprungmarken falsch verarbeiten [wahrscheinlich]); `>` als `&gt;`, `&` als `&amp;`. Praxis: bDS-Variablen am Anfang per `set NAME={NAME}` übernehmen [wahrscheinlich] (W3, W4).

#### RunEmbeddedScript – Eingebettetes Skript ausführen (t23436)

```xml
<ACTION type="RunEmbeddedScript" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<SCRIPTLANGUAGE>PowerShell</SCRIPTLANGUAGE>
<RETURNCODES>*</RETURNCODES>
<VARNAME>[[ExitCode]]</VARNAME>
<SCRIPT>[[PowerShell-Code, escaped, CRLF]]</SCRIPT>
<HIDDENEXECUTION>1</HIDDENEXECUTION>
</DATA>
</ACTION>
```

- Reihenfolge `SCRIPTLANGUAGE`, `RETURNCODES`, `VARNAME`, `SCRIPT`, `HIDDENEXECUTION`; kein OPTIONS [sicher] (CTU Z.59–67; US Z.694–703).
- `SCRIPTLANGUAGE` `PowerShell` [sicher]. Weitere Werte laut Programmdateien des Studios: `VBScript`, `JScript` (= JavaScript) [wahrscheinlich]. PowerShell Core ist offenbar kein eigener Wert, sondern eine Zusatzangabe `PowerShellVersion` [wahrscheinlich; genaue Form unbekannt → einmal im Studio anlegen und das XML ansehen].
- `exit <Code>` beendet das Skript, der Code landet in `VARNAME` [sicher] (t23436). Mit `RETURNCODES` `*` + `VARNAME` + bedingten Folgeaktionen werden Exitcodes ausgewertet [sicher] (CTU). Mit `RETURNCODES` 0 und anderem Exitcode schlägt die Aktion vermutlich fehl → Abbruch [wahrscheinlich].
- Bitness: nach SetX64Mode 1 läuft 64-Bit-PowerShell, ohne x64-Modus 32-Bit [sicher, Probe]. PowerShell Core wird analog gewählt, bei mehreren Versionen die höchste in der Registry [sicher] (t23436).
- Der Dialog hat keine Option „Auf Beendigung warten“ → es wird vermutlich immer gewartet [wahrscheinlich] (Bild system-functions05new24R2.png). Im Screenshot mit Sprache VBScript sind „Unsichtbar ausführen“ und die Rückgabefelder ausgegraut – evtl. nur für PowerShell-Varianten wirksam [geraten].
- Eingebettete Skripte: siehe 1.5 (Latin-1, CRLF) und 3.3 (Variablen, Quoting); Gerüst in muster.md.

#### Wait – Warten (t23437)

Vorgegebene Zeit:
```xml
<ACTION type="Wait" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<TYPE>Duration</TYPE>
<Properties><PropertyEntry><Param>Duration</Param><Value>[[Sekunden]]</Value></PropertyEntry></Properties></DATA>
</ACTION>
```
Prozessbeendigung:
```xml
<ACTION type="Wait" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<TYPE>ProcessTermination</TYPE>
<Properties><PropertyEntry><Param>Duration</Param><Value>15</Value></PropertyEntry><PropertyEntry><Param>Process</Param><Value>[[name.exe]]</Value></PropertyEntry><PropertyEntry><Param>Timeout</Param><Value>[[Sekunden]]</Value></PropertyEntry></Properties></DATA>
</ACTION>
```

- `TYPE` `Duration` = „Vorgegebene Zeit warten“ (Parameter „Sekunden“), `ProcessTermination` = „Prozessbeendigung“ (Parameter Prozess, Timeout) [sicher] (Bilder system-functions06.png, -07.png; US Z.709–718).
- Nach Ablauf des Timeouts bricht die Aktion mit Fehler ab [sicher] (t23437); Einheit des Timeouts vermutlich Sekunden (Standard 120) [wahrscheinlich].
- Layout wie EvalVar: `TYPE` eigene Zeile, Properties alphabetisch samt `</DATA>` in einer Zeile [sicher]. Der Duration-Eintrag bei ProcessTermination ist ein Rest vom Wechsel der Warteart [sicher beobachtet]; wird vermutlich ignoriert, Weglassen ungeprüft.

#### SetX64Mode – x64-Modus setzen (t23432)

```xml
<ACTION type="SetX64Mode" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<MODE>1</MODE>
</DATA>
</ACTION>
```

- `MODE` 1 = expliziten x64-Modus aktivieren, 0 = deaktivieren; gilt für nachfolgende Aktionen [sicher] (t23432; Bild system-functions11.png; CTU Z.56; US Z.726, 731).
- Das Deploy-Skript läuft als 32-Bit-Prozess; x64-Modus = 64-Bit-Prozesse, direkte 64-Bit-Registry, keine Dateisystem-Virtualisierung [sicher] (t23432, t23405). Netzwerkzugriffe können im x64-Modus scheitern → dann MODE 0 [sicher] (t23432).
- Praxis: x64-Modus nur blockweise um 64-Bit-Aktionen, danach sofort MODE 0 [wahrscheinlich] (W4).

#### KeyboardMouseLock – Tastatur- und Maussperre (t23417)

```xml
<ACTION type="KeyboardMouseLock" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<KEYBOARDMOUSELOCK>true</KEYBOARDMOUSELOCK></DATA>
</ACTION>
```

- `true` = sperren, `false` = freigeben; Wertelement und `</DATA>` in einer Zeile [sicher] (US Z.739–746).
- Die Sperre kann über den Jobschritt hinaus bestehen und endet spätestens mit dem Jobende; im Studio-Debug (auch „Ausführen“) wird die Aktion übergangen; bei als exe ausgeführtem bDS funktioniert sie nicht [sicher] (t23417).

### 5.7 Programmfluss

#### Comment – Kommentar (t23368)

```xml
<ACTION type="Comment" level="0" breakpoint="0" ignore_error="0" comment="1" is_included="0" logging_enabled="1">
<DATA>
<VALUE>[[Kommentartext]]</VALUE>
</DATA>
</ACTION>
```

- `comment="1"` schreibt das Studio bei Comment immer (US 38/38; ein Web-Export hat auch 0). Keine Auswirkung auf die Funktion [sicher] (t23368); darunter eingerückte Aktionen laufen normal – Kommentare taugen als Abschnittsüberschrift [sicher, Probe].

#### Label / GotoLabel – Sprungmarke, Gehe zu Sprungmarke (t23408, t23392)

```xml
<ACTION type="Label" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Marke]]</NAME>
</DATA>
</ACTION>
<ACTION type="GotoLabel" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Marke]]</NAME>
</DATA>
<CONDITION op1="{[[Zaehler]]}" op="&lt;=" op2="3" options="0"/>
</ACTION>
```

- Namen müssen eindeutig sein; Aktionen zwischen GotoLabel und Ziel werden übersprungen [sicher] (t23408, t23392). Label unterstützt keine Bedingung [sicher] (Bild program-flow03.png).
- Rücksprung ohne Bedingung = Endlosschleife (US Z.757–766). Zählvariable vor der Marke initialisieren; sonst liefert `{i}+1` beim ersten Durchlauf vermutlich eine Fehlermarke [wahrscheinlich].
- Die Fehlerliste meldet Sprünge ohne passende Marke [sicher] (t23350).
- Der Schleifenrumpf darf eine Stufe tiefer unter der Marke stehen, das GotoLabel auf der Stufe der Marke – so ist
  die Schleife im Studio auf- und zuklappbar [sicher] (SD-P). Muster:

```
Über Zeilen einer Textdatei (SD-P)          Über gefundene Dateien (SD-P)
SetVar i = 1                                EvalVar Liste ← FileInfo {Ordner}\**\*.ini
Label „Zeile lesen“                         Conditional {Liste} = FOUND
  EvalVar Zeile ← TextFile {Datei}, {i}       SetVar i = 1
  Conditional {Zeile} <> NOTFOUND             Label „Datei verarbeiten“
    … {Zeile} verarbeiten …                     … {Liste.{i}.Name} verarbeiten …
    EvalVar i ← Expression {i}+1                EvalVar i ← Expression {i}+1
GotoLabel „Zeile lesen“                       GotoLabel „Datei verarbeiten“
  [Bedingung {Zeile} <> NOTFOUND]               [Bedingung {i} <= {Liste.Count}]
```

- Lauf in zwei Durchgängen (SD-P): Marke ganz oben, am Ende Modus-Variable umschalten und per GotoLabel mit
  Bedingung auf den alten Modus zurückspringen.

#### Subroutine / CallSubroutine – Unterroutine, Unterroutine ausführen (t23397, t23360)

```xml
<ACTION type="Subroutine" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Name]]</NAME>
</DATA>
</ACTION>
<ACTION type="[[Rumpfaktion]]" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
[[…]]
</ACTION>
<ACTION type="CallSubroutine" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<NAME>[[Name]]</NAME>
</DATA>
</ACTION>
```

- Rumpf = direkt folgende Aktionen mit level+1 [sicher] (t23397; US Z.767–784). Definieren allein reicht nicht, die Unterroutine muss aufgerufen werden; nach dem Aufruf geht es mit der Aktion nach CallSubroutine weiter [sicher] (t23360).
- Der normale Ablauf überspringt den Rumpf einer im Fluss stehenden Definition; er läuft nur per CallSubroutine [sicher, Probe]. Platzierung daher frei – im Hausstil vor dem ersten Aufruf. Beide Gewinnerskripte sammeln die Unterroutinen stattdessen hinter dem abschließenden EndBDS; auch das funktioniert [sicher] (SD-I, SD-P).
- CallSubroutine darf eine Bedingung haben (bedingter Aufruf), Subroutine selbst nicht [sicher] (SD-I).
- Keine Parameter und keine Rückgabewerte; Datenaustausch nur über Variablen [wahrscheinlich] (Bilder program-flow05.png, -06.png zeigen nur den Namen).

#### Conditional – Bedingungsgruppe (t23376)

```xml
<ACTION type="Conditional" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
</DATA>
<CONDITION op1="{[[Variable]]}" op="=" op2="[[Wert]]" options="0"/>
</ACTION>
<ACTION type="[[Kindaktion]]" level="1" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
[[…]]
</ACTION>
```

- `DATA` leer, aber als `<DATA>` + CRLF + `</DATA>` geschrieben, nicht selbstschließend [sicher] (US Z.795–797).
- Alle untergeordneten Aktionen (level+1) laufen nur bei erfüllter Bedingung, danach geht es normal weiter [sicher, Probe].

#### EndBDS – Skript beenden (t23384)

```xml
<ACTION type="EndBDS" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<RETURNMESSAGE>[[Meldung]]</RETURNMESSAGE>
<RETURNMODESTR>1</RETURNMODESTR>
<RETURNCODESTR></RETURNCODESTR>
</DATA>
<CONDITION op1="{[[ExitCode]]}" op="=" op2="0" options="0"/>
</ACTION>
```

- `RETURNMODESTR` (trotz „STR“ eine Zahl): 0 = Beenden mit Fehler, 1 = Beenden mit Erfolg, 2 = Beenden mit Rückgabewert [sicher] (US Z.865–885; CTU; Bild program-flow08.png).
- `RETURNMESSAGE` = Rückgabetext; erscheint im bMC in den Jobdetails des Schritts [sicher] (t23384).
- `RETURNCODESTR` = Rückgabewert, nur bei Modus 2 gefüllt, sonst leeres Paar [sicher]; Variable erlaubt (`{RUECKGABEWERT}` im Doku-Bild) [sicher]. Die Wertung erfolgt über die Konsistenzprüfung der zugehörigen Applikation [sicher] (t23384). Wirkung eines nicht numerischen Werts (US: `EndScriptSuccess`) unbekannt. Generator: Modus 0/1, Modus 2 nur auf ausdrücklichen Wunsch.
- EndBDS beendet sofort; nachfolgende Aktionen sind unerreichbar [sicher] (t23384; US Z.865–885).
- Serverseitige Aktionen: Modus Erfolg mit `#DELAYJOB#` im Rückgabetext plant den Job neu (ohne eigenes Abbruchkriterium endlos) [sicher] (W12, W13).
- Ende des Skripts ohne EndBDS: Status undokumentiert (vermutlich Erfolg) [geraten] → immer ein abschließendes EndBDS.


#### IncludeBDS – bDS einbinden (t23400)

```xml
<ACTION type="IncludeBDS" level="0" breakpoint="0" ignore_error="0" comment="0" is_included="0" logging_enabled="1">
<DATA>
<FILENAME>[[Pfad\Include.bds]]</FILENAME>
<DATERESOLVED>0</DATERESOLVED>
<FILENAMERESOLVED></FILENAMERESOLVED>
<RESOLVINGMACHINE></RESOLVINGMACHINE>
<RESOLVEERROR></RESOLVEERROR>
</DATA>
</ACTION>
```

- XML so in baramundis eigenem Installationsskript (2×) und in einem Web-Export [sicher]. Die Resolve-Felder füllt der
  Server beim Zusammensetzen; im Quellskript `0` bzw. leer lassen.
- Der bMS-Server setzt die Skripte vor der Ausführung zusammen; Änderungen im eingebundenen Skript wirken automatisch.
  Im Pfad keine Laufzeitvariablen, laufzeitabhängiges über Bedingungen [sicher] (t23400). baramundi nutzt einen Pfad
  relativ zum Skript (`..\..\..\..\customer\<Hersteller>\<Produkt>\preInst.bds`) und `ignore_error="1"`, weil diese
  Kundenerweiterungen fehlen dürfen.
- Nur auf ausdrücklichen Wunsch erzeugen – der Nutzer braucht es bisher nicht.

## 6. Aktionen ohne bekanntes XML (nicht erzeugen)

Für alle folgenden Aktionen gilt: **XML unbekannt – Beispiel aus dem Automation Studio nötig** (Aktion einmal im Studio anlegen, speichern, XML übernehmen). Weder Samples noch vertrauenswürdige Webquellen enthalten XML dafür. Bis dahin die Funktion per RunEmbeddedScript (PowerShell) umsetzen [wahrscheinlich praktikabel].

| Dialog | Doku | Felder laut Dialog | Hinweise |
|---|---|---|---|
| Variable ermitteln > Abbilddatei (Dropdown „Imagedatei“) | t23374, Bild determine-variables15.png | Variablenname; Dateiname einer .bim-Abbilddatei (Variablen erlaubt, z. B. `{DIP}\Backup\{Client}.bim`); „Existierende Variable nicht überschreiben“ | laut Doku nur in baramundi-eigenen bDS; SOURCE-Wert unbekannt |
| Variable ermitteln > Berechneter Ausdruck – VBS (veraltet) | t23438, Bild determine-variables09.png | Ausdruck (z. B. `{Zaehler}+2`); Checkbox wie oben | Windows-VBScript-Engine, von Microsoft abgekündigt; nicht verwenden, stattdessen SOURCE `Expression` |
| Variablenersetzung in Datei durchführen | t23420, Bild file-operations07.png | Quelldatei, Zieldatei | ersetzt `{Variablen}` der Quelldatei, schreibt in neue Datei; Fehler und Abbruch bei fehlender Quelle oder Quelle = Ziel [sicher]. Seit 22R2/23R1 nur Variablen, die im bDS selbst vorkommen; ob nur Passwort-Variablen ersetzt werden (RN 23R1, W19), ist unbekannt – das Doku-Beispiel ersetzt `{Client}` |
| Komponente registrieren | t23425, Bild system-functions08.png | Datei (Pfad aus Client-Sicht) | Beispiel DLL |
| Anzeigemodus setzen | t23424, Bild system-functions09.png | Auflösung, Farbtiefe, Wiederholfrequenz | nur Standardauflösungen |
| Berechtigungen bearbeiten | t23401, Bild system-functions12.png | Typ (Datei, Verzeichnis, Registrierungsschlüssel/-wert, Drucker); Ziel; Aktion (setzen = überschreiben, hinzufügen, verweigern, löschen); Benutzer/Gruppe; Vollzugriff, Ändern, Lesen/Ausführen, Lesen, Schreiben; rekursiv | AD-Auswahl speichert SID statt Namen (sprachneutral); vererbte Rechte nicht änderbar [sicher] |
| Benutzer anlegen (Dialog „Windows Benutzer anlegen / ändern“) | t23347, Bild usermgt01.png | Typ (lokal/Domäne); Domäne/Server (z. B. `\\{Client}`); Account; Vollständiger Name; Passwort, Wiederholung; „bMS Variablen im Passwort ersetzen“; muss Passwort ändern; kann Passwort nicht ändern; läuft nicht ab; HomeDir; Anmeldeskript; Kommentar | Passwort als Variable vom Typ Passwort, Logging aus [sicher] (t23347) |
| Benutzer löschen | t23334, Bild usermgt02.png | Typ; Domäne/Server; Account; lokales Benutzerprofil löschen; Fehler, wenn Benutzer nicht existiert | |
| Benutzergruppe anlegen | t23339, Bild usermgt03.png | Typ (lokale/Domänengruppe); Domäne/Server; Name; Kommentar; kein Fehler, wenn Gruppe existiert | |
| Benutzergruppe löschen | t23355, Bild usermgt04.png | Typ; Domäne/Server; Gruppe; kein Fehler, wenn Gruppe nicht existiert | Dialog lädt nur Sicherheitsgruppen |
| Benutzer zu Benutzergruppe hinzufügen | t23331, Bild usermgt05.png | Typ; Domäne/Server; Gruppe; Account (auch SID) | Gruppen-Dropdown fehlt, wenn Domäne/Server eine Variable ist |
| Benutzer aus Benutzergruppe entfernen | t23342, Bild usermgt06.png | Typ; Domäne/Server; Gruppe; Account (auch SID) | nur Sicherheitsgruppen |
| Freigabe erstellen | t23344, Bild network-shares01.png | Name; Pfad; Kommentar; Benutzerbegrenzung (Maximum / max. N) | |
| Freigabe verbinden | t23336, Bild network-shares02.png | Server; Freigabe; Laufwerk; persistent; bestehende Verbindung trennen; Benutzeraccount (Name, Kennwort) | im Job laufen SMB-Zugriffe ohnehin über den Netzwerkbenutzer (W15); x64-Modus meiden |
| Freigabe löschen (Dialog „Freigabe entfernen“) | t23352, Bild network-shares03.png | Freigabe; kein Fehler, wenn Freigabe nicht existiert | |
| GUI-Automatisierung (alle Oberflächenaktionen) | t23343, t23351 ff. | Suchkriterien, Zielelement, Aktion; Aufzeichnungsmodus | aufgezeichnete Aktionen sind von Hand kaum erzeugbar; nicht generieren |

„Registry-Schlüssel aus Datei importieren“ ist kein Laufzeittyp, sondern wird als Einzelaktionen erzeugt (5.4).

## 7. Berechneter Ausdruck (SOURCE `Expression`)

Grundlage: baramundi-eigener VBScript-Ausdrucksinterpreter, ersetzt die von Microsoft abgekündigte VBScript-Engine ohne Skriptänderungen [sicher] (t23430). Die deutsche Doku enthält Übersetzungsfehler (Dezimalkomma, „Leer“, „Okt“, „Leerzeichen(3)“); sie sind unten korrigiert [wahrscheinlich].

- **Umfang**: genau ein einzeiliger Ausdruck, beliebig verschachtelte Funktionsaufrufe und Operatoren, höchstens 100 Ebenen (sonst „Out of stack space“); 89 von 96 VBScript-Funktionen [sicher] (t23430, t23353).
- **Nicht unterstützt**: mehrere Anweisungen, Zeilenfortsetzung, Dim/Set/Let und Zuweisungen, If/Select Case/For/While/Do, Function/Sub, Class, On Error; Funktionen GetRef, LoadPicture, ScriptEngine, ScriptEngineBuildVersion/MajorVersion/MinorVersion, SetLocale sowie `GetObject("", ProgID)` [sicher] (t23430, t23369, t23441).
- **Literale**: `"Text"` (`""` = leer), Ganzzahl, Gleitkomma **mit Dezimalpunkt** (`3.14`, `1.0E6`; die Kommas der deutschen Tabellen sind Übersetzungsfehler, `Round(3,5) → 4` ergibt nur als `3.5` Sinn) [wahrscheinlich], Hex `&HFF`, Oktal `&O77`, Datum `#…#`, `True`, `False`, `Null`, `Empty` („Leer“ in der Doku) [sicher bis auf Schreibweisen] (t23353).
- **Datumsliterale** eindeutig schreiben: ISO `#2025-01-15 13:30:45#` oder `DateSerial(…)`/`TimeSerial(…)`; die Doku mischt `#6/1/2026#` und `#15.01.2025#` [wahrscheinlich].
- **Operatoren** von niedrig nach hoch: Imp, Eqv, Or, Xor, And, Not, Vergleich (`= <> < > <= >=`), `&`, `+ -`, Mod, `\`, `* /`, unäres `- +`, `^`; gleiche Stufe links nach rechts (t23337). Die Doku ordnet Or unter Xor ein, VBScript umgekehrt → Or/Xor immer klammern.
- **Wahrheitswerte**: True = -1, False = 0; Vergleiche liefern -1/0 [sicher] (t23337). Wie ein boolesches Ergebnis in der Variable erscheint (-1 oder „True“), ist unbekannt.
- **Verkettung** immer mit `&`; `+` addiert Zahlen, verkettet zwei Strings und wirft bei gemischten nicht-numerischen Operanden einen Fehler; `\` und Mod rechnen mit 32-Bit-Ganzzahlen; Division durch 0 ist ein Fehler [sicher] (t23337).
- **Typen** (VarType): Empty 0, Null 1, Integer 2, Long 3, Single 4, Double 5, Currency 6, Date 7, String 8, Boolean 11, Byte 17 [sicher] (t23444).
- **Typumwandlung**: Empty wirkt als 0 bzw. `""`; `Null + x` = Fehler; `"x" & Null` = `"x"`, `Null & Null` = Fehler; numerische Strings (`"3"`, `"&HFF"`) werden implizit umgewandelt, `"3abc" + 4` = Fehler; Round und Konvertierungen runden Halbwerte auf die gerade Zahl (Banker-Rundung, nicht kaufmännisch: 2.5 → 2, 3.5 → 4) [sicher] (t23361, t23441).
- **Funktionen** [sicher] (t23441):
  - Text: Asc, Chr, Filter, InStr, InStrRev, Join, LCase, Left, Len, LTrim, Mid, Replace, Right, RTrim, Space, Split, StrComp, String, StrReverse, Trim, UCase (compare: vbBinaryCompare 0 = Standard, vbTextCompare 1).
  - Mathe: Abs, Atn, Cos, Exp, Fix, Hex, Int, Log, Oct, Rnd, Round, Sgn, Sin, Sqr, Tan.
  - Datum: Date, DateAdd, DateDiff, DatePart, DateSerial, DateValue, Day, Hour, Minute, Month, MonthName, Now, Second, Time, TimeSerial, TimeValue, Timer, Weekday, WeekdayName, Year; Intervalle `yyyy q m y d w ww h n s` (`n` = Minute).
  - Konvertierung: CBool, CByte, CCur, CDate, CDbl, CInt, CLng, CSng, CStr. Info: IsArray, IsDate, IsEmpty, IsNull, IsNumeric, IsObject, TypeName, VarType.
  - Format: FormatCurrency, FormatDateTime (vbGeneralDate 0 … vbShortTime 4), FormatNumber, FormatPercent. Sonstige: Escape, Eval, GetLocale, InputBox, MsgBox, RGB, Unescape. COM: CreateObject, GetObject. Array: Array, LBound (immer 0), UBound.
- **Arrays** dürfen nicht das Endergebnis sein → mit `Join(…)` in Text wandeln [sicher] (t23441).
- **Konstanten** [sicher] (t23345): vbTrue/vbFalse/vbUseDefault; vbCrLf, vbCr, vbLf, vbNewLine, vbTab, vbBack, vbFormFeed, vbVerticalTab, vbNullChar, vbNullString; vbBinaryCompare/vbTextCompare; vbSunday 1 … vbSaturday 7, vbUseSystemDayOfWeek 0; vbFirstJan1/vbFirstFourDays/vbFirstFullWeek 1–3; VarType-Konstanten; MsgBox-Konstanten (vbOKOnly 0 … vbRetryCancel 5, vbCritical 16, vbQuestion 32, vbExclamation 48, vbInformation 64, vbDefaultButton1–4, vbOK 1 … vbNo 7); Farben vbBlack … vbWhite.
- **Locale**: Format-Funktionen, Date() und Now() nutzen die Systemsprache des Clients (z. B. `11.06.2026 14:05:00`) [sicher] (t23441). Nicht ganzzahlige Ergebnisse landen evtl. mit Dezimalkomma in der Variable → vor Weiterverwendung Fix/Round/Replace [geraten].
- **Fehler** brechen nichts ab: Die Variable erhält eine Markierungszeichenfolge, laut deutscher Doku `<Ungültiger Ausdruck>` (Laufzeittext evtl. englisch, ungeprüft) [sicher für das Prinzip] (t23323). Ursachen: Division durch 0, Typkonflikt, Null in Arithmetik, Überlauf (`CByte(256)`, `CInt(40000)`), ungültiges Argument (`Sqr(-1)`, `Log(0)`, `Chr(256)`), unbekannte Funktion, mehr als 100 Ebenen. Prüfung sprachunabhängig per Bedingung `op="STARTSWITH" op2="&lt;"` [wahrscheinlich].
- **Variablen im Ausdruck**: `{Name}` wird textuell eingesetzt (`{Zaehler}+1`); Textwerte in Anführungszeichen setzen (`UCase("{Name}")`); ein `"` im Wert bricht den Ausdruck [wahrscheinlich] (t23438; Bild determine-variables09.png). In der Datei: `"` → `&quot;`, `&` → `&amp;`, `<`/`>` → `&lt;`/`&gt;`.
- **Empfehlungen**: MsgBox/InputBox nicht verwenden (blockieren im unbeaufsichtigten Kontext; für Dialoge UserInput) [geraten]; „VBS (veraltet)“ nie erzeugen [sicher] (t23430).
- **Bewährte Ausdrücke** aus den Gewinnerskripten [sicher] (SD-I, SD-P); in der Datei `&` → `&amp;`, `"` → `&quot;`:

| Zweck | Ausdruck | Ergebnis |
|---|---|---|
| Zähler | `{i}+1` | 2 |
| Datum sortierbar | `Year(Now) & Right("0" & Month(Now),2) & Right("0" & Day(Now),2)` | 20250925 |
| Zeitstempel für Logzeilen | `Now()` | 25.09.2025 14:34:22 |
| Zeitstempel für Dateinamen | `Date() & " " & FormatDateTime(Now(), 4)`, danach `:` und `/` per StringReplacement ersetzen | 25.09.2025 14_34 |
| Datum in n Tagen | `DateAdd("d", {n}, Date)` | 28.09.2025 |
| Tage zwischen zwei yyyyMMdd-Werten | `CDate(Left({B},4) & "/" & Mid({B},5,2) & "/" & Mid({B},7,2)) - CDate(Left({A},4) & "/" & Mid({A},5,2) & "/" & Mid({A},7,2))` | 3 |
| Text anhängen | `"{Grund}" & "Treiber "` | bisheriger Text + „Treiber “ |
## 8. Allgemeine Fallstricke
- 32-Bit-Prozess: Registry- und Dateisystem-Umleitung (WOW6432Node, SysWOW64), `{%processor_architecture%}` = x86 [sicher]; x64-Modus behebt das, kann aber Netzwerkzugriffe stören (t23432). 64-Bit-Programmordner über `{%ProgramW6432%}` (3.2).
- bMS-Variablen nur wörtlich (seit 22R2); zusammengesetzte Namen wie `{Liste.{i}.Name}` nur für skriptinterne
  Variablen (3.1) [sicher] (W2, SD-P).
- EvalVar/Registry: Hive als Text; Registry-Aktionen: Hive als Zahl [sicher].
- `ARGEUMENT` mit Tippfehler; `RETURNCODE` (TerminateProcess) Singular; `RETURNMODESTR` enthält eine Zahl [sicher].
- CopyFiles ohne Überschreiben überspringt still; DownloadFile ohne Überschreiben bricht ab [sicher] (t23428, t23447).
- Berechneter Ausdruck bricht bei Fehlern nicht ab, sondern liefert eine Fehlermarke [sicher] (t23323).
- Schema 2620 läuft laut Studio-Dialog nur auf dem aktuellsten bMA (26R2) [wahrscheinlich]; Schema 2420 nicht vor 24R2 [sicher] (W1).
- Kein Else; Comment, Label und Subroutine ohne Bedingung; höchstens eine CONDITION je Aktion [sicher].
- KeyboardMouseLock wird im Studio-Debug übergangen – Tests im Studio sagen über diese Aktion nichts [sicher] (t23417).
- Installer per LaunchProcess: `OPTIONS` 1, `RETURNCODES` `0,3010,1641` + `VARNAME`, danach Bedingung auf 3010/1641
  (Neustart nötig) [wahrscheinlich, nur Web-Quelle W4].
- Das ausführende Konto bestimmt der Sicherheitskontext der Applikation (Installationsbenutzer, LocalSystem, …); HKCU ist
  das Profil dieses Kontos [wahrscheinlich] (W14). Benutzereinstellungen besser über das Benutzereinstellungen-bDS der
  Applikation (W16).
- ShowMsg und UserInput brauchen eine sichtbare Ausführung der Applikation; in Shutdown-Jobs nicht nutzbar
  [wahrscheinlich] (W16, W20).
- Debuggen und Ausführen im Studio führen die Aktionen real auf dem Admin-PC aus → nur auf einem Testgerät [sicher] (t23358).

## 9. Offene Punkte

Ungeklärt; im Zweifel nur die beobachteten Werte verwenden oder im Studio nachsehen (Aktion anlegen, speichern, XML vergleichen):

1. LaunchProcess `OPTIONS` 2/4: welches Bit startet unsichtbar, welches minimiert (Vermutung 2 = unsichtbar)?
   Für unsichtbare Ausführung RunEmbeddedCmd/RunEmbeddedScript mit `HIDDENEXECUTION` 1 nehmen.
2. ShowMsg `OPTIONS`: Bedeutung von Bit 32, Kodierung der Einfluss-Stufen (Bit 1 = Timeout ist wahrscheinlich).
3. UserInput: Wert der Rückgabevariable nach Ablauf des Timeouts und `USERINPUTDEFAULTCHOICE` (Nummer bzw.
   `CANCEL` sind geklärt, 5.1).
4. `REGISTRY` 2147484162 (Vermutung: „Interactive user“) – nicht verwenden.
5. Jobstatus, wenn ein Skript ohne EndBDS endet (vermutlich Erfolg) → immer ein abschließendes EndBDS.
6. CreateFile: Verhalten bei `OPTIONS` 0 und vorhandener Datei, genaue Bytes bei `ENCODING` 0 (ANSI?), BOM bei
   `ENCODING` 1.
7. SetRegValue: Typcodes außer 1/4, Datenformate (DWORD hex?, Binär, MULTI_SZ), legt `OPTIONS` 1 fehlende Schlüssel an?
   → CreateRegKey davor.
8. Genaue Form der PowerShell-Core-Auswahl (`PowerShellVersion`) in RunEmbeddedScript.
9. Skripteigenschaft „Protokollierung“ im XML (das Fortschrittsfenster ist `RUNOPTIONS HideProgress`, 1.1).
10. CopyFiles-Einzelbits außer 11/27 und ob das Zielverzeichnis angelegt wird → CreateFolder davor.
11. Einrückung unter Aktionen, die keine Klammer sind (einmal unter LaunchProcess gesehen): laufen die Kinder normal?
12. DeleteShortcut `NAME`: Bezeichnung oder voller .lnk-Pfad? Eindeutige Alternative: DeleteFiles auf den .lnk-Pfad.

## 10. Serverseitige Aktion (SSA) und bConnect

Eine .bds kann statt auf dem Client auf dem bMS-Server laufen: Jobschritt „Serverseitige Aktion ausführen“,
stellvertretend für das Zielgerät [sicher] (W12, W13). Nur auf ausdrücklichen Wunsch erzeugen.

- **Ablage**: direkt in `\\<bMS-Server>\bms$\Scripts\Serverside` (lokal unter `…\baramundi\Management Server\Shared\Scripts\ServerSide`),
  keine Unterordner; der Jobschritt nennt nur den Dateinamen. Keine Applikation in der bMC nötig [sicher] (W12, W13, SD-P).
- **Konto**: „Konfigurierter Installationsbenutzer“ (der des Zielgeräts) oder bServer-Kontext (LocalSystem bzw.
  Dienstkonto, als einziges ohne UAC-Hürde, im Netzwerk evtl. eingeschränkt). „Skriptabbruch nach x Minuten“ setzen
  [sicher] (W12, W13). Das Konto braucht Schreibrechte auf alle Arbeitsordner; Module wie ActiveDirectory müssen auf
  dem Server installiert sein [sicher] (SD-P).
- **Laufzeit**: Kopie der .bds plus `vars.xml` (Variablen des Zielgeräts) in einem temporären Ordner unter
  `%ProgramData%\baramundi\ServerSideExecution`, nach dem Schritt gelöscht → relative Pfade nur für Wegwerfdateien,
  Dauerhaftes (Logs, Listen) mit absolutem Pfad, IncludeBDS nicht relativ [sicher] (W12, W13). SD-P legt seinen
  Arbeitsordner unter `{DIP}\…` an.
- **Ablauf**: startet auch, wenn das Ziel nicht erreichbar ist; `#DELAYJOB#` plant neu (5.7 EndBDS); höchstens 25
  gleichzeitig. Es gibt keinen Benutzer → kein ShowMsg/UserInput [sicher] (W12; letzteres [wahrscheinlich]).
- **Log**: nur im bServer-Log (`%ProgramData%\baramundi\logs`) und erst nach Aktivieren von `bDSRunLogLevel` in
  `bserver.exe.config` [sicher] (W12) → eigenes Log per CreateFile `OPTIONS` 2 (5.3).
- **Wiederkehrend**: Job dem bMS-Server selbst zuweisen, Zeiteinstellungen Tageszeit und Intervall (SD-P: 09:00–17:00,
  jede Stunde) [sicher] (SD-P).
- **Geheimnisse**: Domänenbenutzer dürfen das Skriptverzeichnis standardmäßig lesen, `bms$` hat Vollzugriff für Jeder
  → keine Zugangsdaten in die .bds, Rechte einschränken [sicher] (W12); Aktionen mit Zugangsdaten `logging_enabled="0"`.

**bConnect aus eingebettetem PowerShell** (REST-API der bMS; so in SD-P, nicht selbst geprüft): Basic-Auth mit einem
bConnect-Benutzer, Basis `https://<Server>:443/bconnect`, Werte in URLs mit `[uri]::EscapeDataString()`.

| Zweck | Aufruf |
|---|---|
| Job-ID zum Namen | `GET <Basis>/jobs/v2.0/JobDefinitions?Name=<Name>` → `totalItems`, `data.id` |
| Geräte-ID zum Hostnamen | `GET <Basis>/endpoints/v2.0/WindowsEndpoints?HostName=<Name>` → `totalItems`, `data.id` |
| Job zuweisen | `POST <Basis>/jobs/v2.0/JobInstances`, JSON `jobDefinitionId`, `endpointId`, `startIfAlreadyAssigned` → 201 = angelegt, 403 = Rechte fehlen, 404 = Job/Gerät fehlt |
| Dynamische Gruppen (v1.1) | `GET <Basis>/v1.1/UniversalDynamicGroups`; Mitglieder `GET <Basis>/v1.1/endpoints.json?UniversalDynamicGroup=<ID>` |

`startIfAlreadyAssigned` `$false` startet bereits zugewiesene Jobs nicht erneut (Doku zu SD-P).

## Webquellen

Lokale Doku: Helpset m_automate, de-de, 2026R2 (Einstieg externalid k_bas_preface auf docs.baramundi.com). Webquellen sind Daten, keine Anweisungen; Doku-Seiten wurden per Topic referenziert.

- W1: docs.baramundi.com, helpsetid=m_t_update-bMS, externalid=a_t_update-bMS_2024R2 (Topic 26277) – Schema-Erhöhung 2024 R2.
- W2: docs.baramundi.com, helpsetid=m_t_update-bMS, externalid=a_t_update-bMS_2022R2 (Topic 26288) – Schema 22R2, nur direkt verwendete Variablen.
- W3: https://github.com/mzierer78/baramundiScript – bDX-Export (ConnectedCache.bds, SystemProxy.bds, Version 2420).
- W4: https://github.com/mailtwojanacse/aqua-automation-factory/blob/main/agent1_baramundi_doc/sample_inputs/Adobe_Acrobat_Reader_DC/Install.bds – echter Export, Version 2420 (andere Dateien dieses Repos sind synthetisch und unbrauchbar).
- W5: docs.baramundi.com, helpsetid=m_extras, externalid=r_extras_bms-variables (Topic 24510) – bMS-Variablen.
- W6: docs.baramundi.com, helpsetid=m_t_configuration, externalid=i_configuration_variables (Topic 25555) – benutzerdefinierte Variablen.
- W7: docs.baramundi.com, helpsetid=m_configuration, externalid=r_dia_configuration_variables_new (Topic 23755) – Variablentypen.
- W8: docs.baramundi.com, helpsetid=m_t_bas, externalid=a_software_bas_faqs (Topic 25444) – BDScript.LastResult, 32-Bit-Registry.
- W9: docs.baramundi.com, helpsetid=m_t_bas, externalid=i_software_bas_create-deploy-scripts (Topic 25446) – Bedingungen, Skript beenden.
- W10: docs.baramundi.com, helpsetid=m_t_bas, externalid=t_software_bas_working-with-variables (Topic 25454) – Variablenarten, Sicherheit.
- W11: docs.baramundi.com, helpsetid=m_t_bas, externalid=t_software_bas_debugger (Topic 25449) – Debugger, install.ini.
- W12: docs.baramundi.com, helpsetid=m_jobs, externalid=r_dia_jobs_job-for-windows-device_new-job-for-windows-device_run-server-side-action (Topic 24776) – serverseitige Aktionen.
- W13: docs.baramundi.com, helpsetid=m_t_software, externalid=i_software_execute-server-side-action (Topic 26252) – #DELAYJOB#.
- W14: docs.baramundi.com, helpsetid=m_software, externalid=r_dia_software_applications_application-properties_security (Topic 25131) – Sicherheitskontexte.
- W15: docs.baramundi.com, helpsetid=m_extras, externalid=r_hardening_users-and-rights (Topic 24519) – baraInstLocal, Netzwerkbenutzer.
- W16: docs.baramundi.com, helpsetid=m_software, externalid=r_dia_software_applications_application-properties_installation (Topic 25116) – Sichtbare Ausführung, Benutzereinstellungen.
- W17: docs.baramundi.com, helpsetid=m_configuration, externalid=t_bma-command-line-interface (Topic 23794) – BMACmd.
- W18: docs.baramundi.com, helpsetid=m_t_microsoft-secure-boot-certificate, externalid=a_microsoft-secure-boot-certificate-expiration_how-to-microsoft-certificates (Topic 25891) – Ablage {DIP}\Scripts\BDS, SetCustomVar-Muster.
- W19: bms-downloads.de Release Notes 2021R2–2023R1 (PDF nicht mehr abrufbar, nur Suchmaschinen-Ausschnitte).
- W20: docs.baramundi.com, helpsetid=m_t_jobs, externalid=a_jobs_settings-results_client-server-interactions (Topic 25850) – Shutdown-Jobs.
- W21: docs.baramundi.com, helpsetid=m_t_jobs, externalid=a_jobs_custom-job-execution_practice (Topic 25853) – benutzerspezifische Ausführung.

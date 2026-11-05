---
name: baramundi-bds
description: Schreibt, ändert, prüft und erklärt Skripte für das baramundi Automation Studio (.bds-Dateien, baramundi Deploy Script/bDS) – mit korrekter ISO-8859-1-Kodierung, Job-Parametern, x64-Modus, eingebettetem PowerShell und klaren EndBDS-Meldungen. Immer verwenden, wenn es um baramundi, bMS, Automation Studio, bDS, .bds-Dateien, Deploy- oder Verteilungsskripte für baramundi-Jobs geht – auch wenn nur von „baramundi-Skript“, „Skript für den Job“ oder „Automation-Studio-Datei“ die Rede ist oder eine .bds angehängt wird.
---

# baramundi-bds

Eine .bds-Datei ist XML: Kopf (`META`) und eine flache Liste von `ACTION`-Elementen, die das Automation Studio
von oben nach unten ausführt. Das Studio liest und schreibt die Datei als **ISO-8859-1 mit CRLF**. Write und Edit
arbeiten in UTF-8 – deshalb entsteht jede .bds über eine UTF-8-Arbeitskopie und das Hilfsskript `bds`, das
kodiert, prüft und speichert. Eine .bds nie direkt mit Write/Edit anlegen oder ändern: Umlaute würden zu
UTF-8-Bytes, die das Studio als „Ã¤“ zeigt.

## Werkzeug

| Umgebung | Aufruf |
|---|---|
| Claude Code (Windows) | `powershell -NoProfile -ExecutionPolicy Bypass -File "<Skillordner>\scripts\bds.ps1" <Befehl> …` |
| claude.ai / Linux | `python3 <Skillordner>/scripts/bds.py <Befehl> …` (Schalter mit `--`, z. B. `--backup`) |

`<Skillordner>` ist der Ordner dieser SKILL.md.

- `open <Datei.bds> <Arbeitskopie.xml> [-Normalize]` – .bds als UTF-8-Arbeitskopie zum Bearbeiten.
- `save <Arbeitskopie.xml> <Datei.bds> [-Backup]` – prüft, setzt LastChange, CRLF und ISO-8859-1, schreibt erst bei 0 Fehlern. Überschreibt nur mit `-Backup` (legt `<Datei>.bds.bak` an).
- `check <Datei.bds>` – nur prüfen.

Ausgabe: `FEHLER:` (Datei wäre kaputt oder falsch, wird nicht gespeichert) und `HINWEIS:` (Risiko oder Abweichung
von den Hausregeln – jeden Hinweis bewerten und beheben oder in der Antwort begründen). Die PowerShell-Fassung prüft
zusätzlich die Syntax eingebetteter PowerShell-Skripte.

## Nachschlagen

- `references/aktionen.md` – jede erlaubte Aktion mit exakter XML-Vorlage, Feldern und Optionswerten. Vor dem
  Schreiben einer Aktion deren Abschnitt lesen; Elementnamen und Reihenfolge exakt übernehmen (auch Eigenheiten
  wie `ARGEUMENT`).
- `references/muster.md` – vollständiges Beispielskript im Hausstil und das Gerüst für eingebettetes PowerShell.
- `scripts/schema.json` – maschinenlesbare Liste der erlaubten Aktionstypen; was dort fehlt, kennt der Skill nicht.

## Neues Skript

1. **Klären.** Nur nachfragen, wenn eine Lücke das Ergebnis ändert (höchstens drei Fragen auf einmal), z. B.
   genauer Registry-Pfad, Verhalten im Fehlerfall, Neustart nötig. Kleinigkeiten mit sinnvollen Standardwerten
   lösen und in der Abgabe als Annahme nennen.
2. **Planen.** Ablauf als Liste von Aktionen. Native Aktionen zuerst (Dateien, Registry, Dienste, Prozesse …):
   Sie sind im Studio lesbar und stehen einzeln im Joblog. Eingebettetes PowerShell nur für Logik, die nativ
   fehlt oder unübersichtlich würde. Braucht die Aufgabe einen Aktionstyp, den `schema.json` nicht kennt (z. B.
   Benutzer/Gruppen, Freigaben, GUI-Automatisierung): das sagen und PowerShell vorschlagen oder um eine kleine
   Beispiel-.bds aus dem Automation Studio bitten – XML für unbekannte Aktionen nie raten. Nur bauen, was das Ziel
   braucht: Ein Zusatz, ohne den das Ziel nicht erreicht wird, kommt hinein und wird in der Abgabe begründet (wie man
   ihn wieder entfernt); alles Weitere nur als Vorschlag nennen.
3. **Schreiben.** UTF-8-Arbeitskopie `<Name>.xml` in einem temporären Ordner (Scratchpad bzw. `/tmp`), Aufbau nach
   `references/muster.md`, jede Aktion nach ihrer Vorlage aus `references/aktionen.md`.
4. **Speichern.** `save` in den Arbeitsordner der Sitzung (claude.ai: `/mnt/user-data/outputs/`). Bei FEHLER die
   Arbeitskopie korrigieren und erneut speichern, bis 0 Fehler. Bestehende Datei nur nach Rückfrage überschreiben.
5. **Abgeben** (siehe „Abgabe“).

Dateiname: `<Verb>_<Gegenstand>.bds` wie `Check_TaskUser.bds` – ASCII, ohne Leerzeichen und Umlaute.

## Bestehendes Skript ändern

1. `open <Datei.bds> <tmp>\<Name>.xml` – meldet Skripte im UTF-8+BOM-Altformat (siehe unten).
2. Arbeitskopie mit Edit ändern; nichts „nebenbei“ aufräumen. Edit vereinheitlicht dabei die Zeilenenden – `save`
   stellt unveränderte Altformat-Skripte deshalb byte-genau aus der Zieldatei wieder her, der Rest ist ohnehin CRLF.
3. `save <tmp>\<Name>.xml <Datei.bds> -Backup` – die Datei wird direkt geändert, das Original liegt als `.bak` daneben.

Soll Code *innerhalb* eines Altformat-Skripts geändert werden, mit `open … -Normalize` öffnen: Das Skript wird auf
lesbares Latin-1 umgestellt. Sonst würden neue Umlaute in einem UTF-8-Skript zu Kodierungs-Mischmasch.

## Prüfen oder erklären

`check` laufen lassen und die Datei lesen (`open` in eine Arbeitskopie, falls Umlaute lesbar sein sollen). Dann auf
Deutsch: Was das Skript tut (Ablauf in Schritten, mit Aktionsnummern `#n` wie im Prüfergebnis), welche
Job-Parameter es erwartet, wie es endet. Danach die Befunde nach Schwere: erst was falsch läuft, dann Risiken, dann
Stil. Änderungen nur auf Wunsch.

## Hausregeln

Mit dem Nutzer vereinbart; jede Regel hat einen Grund.

- **Kopf:** `Version="2420"` (bDS-Schema seit 24R2), `Author=""`, `Comment` = ein Satz
  zum Zweck. LastChange setzt `save`.
- **Gliederung:** Kommentar-Aktionen als Abschnittsüberschriften (Parameter, Prüfen, Ausführen, Abschluss), damit
  das Skript im Studio lesbar bleibt. Einrückung (`level`) nach `references/aktionen.md`.
- **Parameter:** Veränderliche Werte kommen als Job-Parameter: `{JobParam.X}` → „Variable setzen“ → Verwendung als
  `{X}`. Sie wirken erst, wenn die .bds in der Management Suite angelegt ist und jeder Parameter dort unter
  „Konfigurierbare Parameter“ mit genau diesem Namen steht; Ja/Nein-Parameter liefern `T`/`F`. Fehlt einer, bleibt
  `{JobParam.X}` als Text stehen – Pflicht-Parameter deshalb direkt danach prüfen (`aktionen.md` 3.4), Ja/Nein erst
  mit sicherem Standard setzen und nur bei `T` umschalten (`muster.md` 3).
- **Bedingungen:** `options="0"` (Groß-/Kleinschreibung egal, Zahlen numerisch); Versionsnummern mit `options="2"`,
  Groß-/Kleinschreibung beachten mit `1` – per Probe auf dem Testgerät bestätigt.
- **x64-Modus gezielt:** `SetX64Mode 1` direkt vor eingebettetem PowerShell, Registry-Zugriffen auf den 64-Bit-Zweig
  (`HKLM\SOFTWARE\…`) und System32-Pfaden, danach `SetX64Mode 0`. Netzwerk- und UNC-Zugriffe (auch `{DIP}`) im
  x86-Modus – laut baramundi-Doku können sie im x64-Modus scheitern. Ohne x64-Modus läuft PowerShell als 32-Bit,
  `HKLM\SOFTWARE` landet in `WOW6432Node` und System32 wird nach SysWOW64 umgeleitet. Der Agent selbst bleibt ein
  32-Bit-Prozess: 64-Bit-Programmordner als `{%ProgramW6432%}`, nicht `{%ProgramFiles%}` (zeigt auf „Program Files (x86)“).
- **Abschluss:** Jeder Ausgang endet mit einem `EndBDS` und einer klaren deutschen Meldung (Erfolg/Fehler). Die
  zuletzt ausgeführte Aktion ist immer ein bedingungsloses `EndBDS`: bei einem geradlinigen Skript die
  Erfolgsmeldung; stehen davor bedingte Ausgänge (z. B. je Exitcode), ist es der Auffang mit Fehler, etwa
  „Unerwarteter Exitcode {Exitcode}“ – sonst endet ein unvorhergesehener Fall still als Erfolg. In Meldungen nur
  `{Variablen}` verwenden, keine PowerShell-Variablen (`$x` ersetzt baramundi nicht).
- **Unbeaufsichtigt:** Keine Meldungen oder Abfragen, außer der Nutzer will sie; dann immer mit Timeout und
  Standardauswahl. Eingebettete Skripte laufen unsichtbar (`HIDDENEXECUTION` 1).
- **Geheimnisse:** Kennwörter als Passwort-Parameter anlegen lassen (eigener Bereich bei den konfigurierbaren
  Parametern, im Job mit * maskiert), nie als Zeichenkette; im Skript ebenfalls `{JobParam.X}`. Aktionen, die ein
  Kennwort oder Token setzen oder verwenden, bekommen `logging_enabled="0"`. In der Abgabe erwähnen, dass der Wert
  trotzdem kurz im temporären Skript auf dem Client steht.
- **Fehlerverhalten:** `ignore_error="1"` nur, wenn ein Fehlschlag ausdrücklich egal ist (z. B. Löschen einer Datei,
  die fehlen darf) – und dann im Kommentar begründen.
- **Zeichen:** Nur Zeichen aus ISO-8859-1. Umlaute und ß sind erlaubt; typografische Anführungszeichen („ “),
  Gedankenstrich (–), Euro (€) und Emojis gibt es nicht – `save` lehnt sie ab.

## Eingebettetes PowerShell

Gerüst und Beispiel in `references/muster.md`. Das Wichtigste:

- `SCRIPTLANGUAGE` `PowerShell`, `RETURNCODES` `*`, `VARNAME` `Exitcode`, danach ein `EndBDS` je Exitcode plus Auffang.
  So landet jeder Ausgang mit eigener Meldung im Job, statt als pauschaler Aktionsfehler.
- Exitcodes: 0 = Erfolg, eigene Ergebnisse ab 2, unerwartete Fehler per `trap` → 99. Exitcode 1 nicht selbst
  vergeben: Den liefert PowerShell bei Abbruch oder Syntaxfehler, er soll beim Auffang landen.
- Der Nutzer schreibt selbst kein PowerShell: jeden Schritt auf Deutsch kommentieren, Exitcodes im Kopf erklären.
- Oben ein Block EINSTELLUNGEN: je Wert eine Beschreibungszeile, darunter die auskommentierte Zeile mit Standardwert
  für lokale Tests, darunter die Zeile mit dem baramundi-Platzhalter. Text in Anführungszeichen (`'{Name}'`),
  Ja/Nein und Zahlen ohne (`{Umstellen}` → baramundi setzt `$true`/`$false` bzw. die Zahl ein).
- Log nach `C:\Windows\Temp\<Skriptname>.log`, eine Zeile je Ergebnis mit Zeitstempel und Exitcode.
- Das Skript steht als Latin-1-Text im XML (im Studio-Editor lesbar). Der Agent schreibt es Byte für Byte als
  ANSI-Datei, Windows PowerShell 5.1 liest Umlaute korrekt (per Probe bestätigt). Für „PowerShell Core“ keine Umlaute –
  es liest Dateien ohne BOM als UTF-8.
- `{Name}` ersetzt baramundi überall im Skripttext; unbekannte Namen bleiben als Text stehen. Skriptblöcke und
  Formatangaben wie `'{0:yyyy-MM-dd}'` sind unkritisch. Einen einzelnen Bezeichner in Klammern nur als gewollten
  Platzhalter schreiben – heißt eine Variable so (z. B. `{Client}`, `{Mode}`), wird er ersetzt.
- Fehlenden Wert erkennen: `$Wert.StartsWith('{') -and $Wert.EndsWith('}')` – den Platzhalter nie selbst ausschreiben.
- Syntax prüft `save`/`check`. Lokal ausführen nur, wenn das Skript nichts verändert (Platzhalter durch die
  Standardwerte ersetzt); alles andere testet der Nutzer auf seinem Testgerät.

## Abgabe

Kurz und auf Deutsch:

1. Pfad der .bds (claude.ai: Download) und das Prüfergebnis (0 Fehler; verbliebene Hinweise mit Begründung).
2. Ablauf in wenigen Zeilen.
3. **Job-Parameter** als Tabelle: Name, Typ, Pflicht ja/nein, Bedeutung, Beispielwert – mit dem Hinweis, die .bds in
   der Management Suite anzulegen und genau diese Namen unter „Konfigurierbare Parameter“ einzutragen. Verfügbare
   Typen: Zeichenkette, Zahl, EIN/AUS-Feld (liefert T/F), Datum, Auswahlliste, Editierbares Auswahlfeld, Dateiname,
   Zertifikat; Kennwörter als eigener Passwort-Parameter (im Job mit * maskiert).
4. **Ausgänge**: jede EndBDS-Meldung mit Status (Erfolg/Fehler) und wann sie kommt.
5. Annahmen und offene Punkte; was nur auf dem Testgerät geprüft werden kann.

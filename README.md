# baramundi-bds

Ein Skill für [Claude](https://claude.com), der Skripte für das **baramundi Automation Studio** schreibt, ändert,
prüft und erklärt (`.bds`, baramundi Deploy Script). Man beschreibt auf Deutsch, was auf dem Client passieren soll,
und bekommt eine fertige `.bds`, die sich im Automation Studio öffnen und in der Management Suite als Job
verteilen lässt.

> Inoffizielles Community-Projekt, nicht von der baramundi software GmbH. Erzeugte Skripte immer erst auf einem
> Testgerät laufen lassen.

## Was der Skill kann

- **Neu schreiben:** aus einer Beschreibung ein vollständiges Skript, mit Job-Parametern und einer klaren Meldung
  für jeden Ausgang.
- **Ändern:** bestehende `.bds` gezielt anpassen; das Original bleibt als `.bak` daneben liegen.
- **Prüfen und erklären:** Ablauf Schritt für Schritt, erwartete Job-Parameter, Befunde nach Schwere.

Beispiele für Anfragen:

```
Schreib mir ein baramundi-Skript, das den Druckspooler stoppt, die Warteschlange leert und den Dienst wieder startet.
Ändere Check_TaskUser.bds so, dass ein unerwarteter Exitcode als Fehler endet.
Erklär mir, was dieses Skript macht und ob etwas daran riskant ist. (mit angehängter .bds)
```

## Warum ein eigener Skill

Eine `.bds` ist XML, aber mit Eigenheiten, an denen ein Sprachmodell ohne Hilfe scheitert:

- **Kodierung:** Das Studio erwartet ISO-8859-1 mit CRLF. Wird die Datei als UTF-8 geschrieben, zeigt das Studio
  statt Umlauten „Ã¤“. Der Skill bearbeitet deshalb eine UTF-8-Arbeitskopie und speichert über ein Werkzeug, das
  kodiert und vorher prüft.
- **Exaktes Format:** Elementnamen und ihre Reihenfolge müssen stimmen, samt Eigenheiten wie `ARGEUMENT`. Der
  Aktionskatalog enthält für jede unterstützte Aktion die XML-Vorlage mit Feldern und Optionswerten.
- **Prüfung vor dem Speichern:** Das Werkzeug schreibt die Datei erst bei 0 Fehlern. Es prüft unter anderem
  Struktur, Einrückung, unbekannte Variablen, fehlendes Skriptende und (unter Windows) die Syntax eingebetteter
  PowerShell-Skripte.

## Unterstützte Aktionen

37 Aktionstypen, darunter Variablen setzen und ermitteln, Datei- und Ordneroperationen, Registry, Dienste, Prozesse
starten und beenden, eingebettete Skripte (PowerShell, Batch), x64-Modus, Bedingungen, Sprungmarken, Unterroutinen
und Skriptende. Die vollständige Liste steht in `scripts/schema.json`.

Was dort fehlt (z. B. GUI-Automatisierung, Benutzer und Gruppen, Freigaben), erzeugt der Skill nicht als native
Aktion. Er schlägt dafür eingebettetes PowerShell vor oder bittet um ein kleines Beispiel aus dem Studio – XML für
unbekannte Aktionen wird nicht geraten.

## Stand

- Schema `2620` (Automation Studio 26R2). Skripte mit diesem Schema laufen laut Studio nur auf dem aktuellen
  Management Agent. Ältere Skripte (z. B. `2420`) meldet die Prüfung als Hinweis.
- Getestet mit Claude Code unter Windows und Windows PowerShell 5.1.
- Grundlage des Aktionskatalogs: die offizielle Dokumentation des Automation Studio, echte Skripte und Probeläufe
  auf einem Testgerät. Jede Angabe im Katalog ist als `[sicher]`, `[wahrscheinlich]` oder `[geraten]` markiert.

## Installation

**Claude Code**

```bash
git clone https://github.com/Blaxx01/baramundi-bds.git ~/.claude/skills/baramundi-bds
```

**claude.ai**

Den Ordner ohne `evals/` und `.git/` zippen und unter Einstellungen → Fähigkeiten → Skills hochladen.

### Einrichten

Im Skillordner eine Datei `author.txt` anlegen. Ihre erste Zeile landet als Author in den Eigenschaften jedes neuen
Skripts. Ohne die Datei bleibt das Feld leer. Die Datei gehört nicht zum Repository.

## Hausregeln

Der Skill schreibt nach festen Regeln, die in `SKILL.md` stehen und sich dort anpassen lassen. Die wichtigsten:

- Native Aktionen zuerst; eingebettetes PowerShell nur für Logik, die nativ fehlt.
- Veränderliche Werte kommen als Job-Parameter (`{JobParam.X}`), nicht fest ins Skript.
- Jeder Ausgang endet mit einem `EndBDS` und einer deutschen Meldung; am Ende steht immer ein Auffang, damit ein
  unvorhergesehener Fall nicht still als Erfolg endet.
- x64-Modus gezielt an und wieder aus.
- Kennwörter als Passwort-Parameter, Aktionen damit ohne Protokollierung.
- Keine Dialoge, außer sie sind ausdrücklich gewünscht.

## Werkzeug ohne Claude

Die Prüfung funktioniert auch allein, zum Beispiel für vorhandene Skripte:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 check <Datei.bds>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 open  <Datei.bds> <Arbeitskopie.xml> [-Normalize]
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 save  <Arbeitskopie.xml> <Datei.bds> [-Backup]
```

Unter Linux bzw. in claude.ai dieselben Befehle mit `python3 scripts/bds.py` (Schalter mit `--`, ohne
PowerShell-Syntaxprüfung).

`FEHLER:` heißt, die Datei wäre kaputt oder falsch; `HINWEIS:` ist ein Risiko oder eine Abweichung von den
Hausregeln. Exitcodes: 0 = in Ordnung, 1 = Fehler gefunden, 2 = Aufruf- oder Dateifehler.

## Inhalt

| Pfad | Zweck |
|---|---|
| `SKILL.md` | Anleitung für Claude: Ablauf (neu, ändern, prüfen) und Hausregeln |
| `references/aktionen.md` | alle unterstützten Aktionen mit XML-Vorlage, Feldern, Optionswerten |
| `references/muster.md` | Beispielskript im Hausstil und Gerüst für eingebettetes PowerShell |
| `scripts/bds.ps1` | open / save / check unter Windows (inkl. PowerShell-Syntaxprüfung) |
| `scripts/bds.py` | dieselben Befehle für claude.ai bzw. Linux |
| `scripts/schema.json` | Regeln für beide Skripte (Aktionstypen, Elementreihenfolge, bekannte Variablen) |
| `scripts/test/` | Selbsttest der Prüfregeln (Testskript und erwartete Ausgabe beider Fassungen) |
| `evals/` | Testfälle im Format von `claude plugin eval` |

## Selbsttest

Nach Änderungen an `bds.ps1`, `bds.py` oder `schema.json` müssen beide Fassungen für `scripts/test/selftest.bds`
genau die erwartete Ausgabe liefern (keine Ausgabe = kein Unterschied):

```
powershell -NoProfile -Command "Compare-Object (Get-Content scripts\test\erwartet-ps1.txt) (powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 check scripts\test\selftest.bds)"
python3 scripts/bds.py check scripts/test/selftest.bds | diff - scripts/test/erwartet-py.txt
```

## Mitmachen

Fehlt eine Aktion oder stimmt eine Vorlage nicht: ein Issue mit einer kleinen Beispiel-`.bds` aus dem Automation
Studio genügt (Aktion einmal anlegen, speichern, anhängen – ohne interne Pfade, Servernamen oder Kennwörter).

## Lizenz

[MIT](LICENSE). baramundi ist eine Marke der baramundi software GmbH; dieses Projekt steht in keiner Verbindung
zum Hersteller.

# baramundi-bds

Claude-Skill zum Schreiben, Ändern, Prüfen und Erklären von Skripten für das baramundi Automation Studio
(`.bds`, baramundi Deploy Script). Kern ist ein Werkzeug, das die Datei als ISO-8859-1 mit CRLF speichert und
vorher prüft, dazu ein Aktionskatalog mit exakten XML-Vorlagen.

## Inhalt

| Pfad | Zweck |
|---|---|
| `SKILL.md` | Anleitung für Claude: Ablauf (neu, ändern, prüfen) und Hausregeln |
| `references/aktionen.md` | alle unterstützten Aktionen mit XML-Vorlage, Feldern, Optionswerten |
| `references/muster.md` | Hausstil-Beispiel und Gerüst für eingebettetes PowerShell |
| `scripts/bds.ps1` | open / save / check unter Windows (inkl. PowerShell-Syntaxprüfung) |
| `scripts/bds.py` | dieselben Befehle für claude.ai bzw. Linux |
| `scripts/schema.json` | Regeln für beide Skripte (Aktionstypen, Elementreihenfolge …) |
| `scripts/test/` | Selbsttest der Prüfregeln (Testskript und erwartete Ausgabe beider Fassungen) |
| `evals/` | Testfälle im Format von `claude plugin eval` |

## Installation

- **Claude Code:** Ordner als `~/.claude/skills/baramundi-bds` ablegen.
- **claude.ai:** Ordner ohne `evals/` und `.git/` zippen und unter Einstellungen → Fähigkeiten → Skills hochladen.

## Werkzeug

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 open  <Datei.bds> <Arbeitskopie.xml> [-Normalize]
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 save  <Arbeitskopie.xml> <Datei.bds> [-Backup]
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 check <Datei.bds>
```

Exitcodes: 0 = in Ordnung, 1 = Fehler gefunden, 2 = Aufruf- oder Dateifehler.

## Selbsttest

Nach Änderungen an `bds.ps1`, `bds.py` oder `schema.json` müssen beide Fassungen für `scripts/test/selftest.bds`
genau die erwartete Ausgabe liefern (keine Ausgabe = kein Unterschied):

```
powershell -NoProfile -Command "Compare-Object (Get-Content scripts\test\erwartet-ps1.txt) (powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bds.ps1 check scripts\test\selftest.bds)"
python3 scripts/bds.py check scripts/test/selftest.bds | diff - scripts/test/erwartet-py.txt
```

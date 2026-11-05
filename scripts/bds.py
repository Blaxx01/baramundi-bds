#!/usr/bin/env python3
"""Oeffnen, Speichern und Pruefen von baramundi-Automation-Studio-Skripten (.bds).

.bds-Dateien sind XML in ISO-8859-1 mit CRLF. Bearbeitet wird eine UTF-8-Arbeitskopie;
'save' prueft sie wie 'check' und schreibt erst dann die .bds.

  python3 bds.py open  <datei.bds> <arbeitskopie.xml> [--normalize]
  python3 bds.py save  <arbeitskopie.xml> <datei.bds> [--backup]
  python3 bds.py check <datei.bds>

Exitcodes: 0 = in Ordnung (Hinweise moeglich), 1 = Fehler gefunden, 2 = Aufruf- oder Dateifehler.
Gegenstueck zu bds.ps1 mit denselben Regeln (schema.json), aber ohne PowerShell-Syntaxpruefung.
"""
import argparse
import datetime
import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SCHEMA = json.loads(Path(__file__).with_name("schema.json").read_text(encoding="utf-8"))
DECL = '<?xml version="1.0" encoding="ISO-8859-1"?>'
BOM = "\xef\xbb\xbf"  # UTF-8-BOM, so wie er in Latin-1 gelesen aussieht
VAR_RE = re.compile(r"\{(%?[A-Za-z_][A-Za-z0-9_.]*%?)\}")
SECRET_RE = re.compile(r"passw|kennw|secret|token|pwd", re.I)
errors, hints = [], []


def val(node, name):
    n = node.find(name)
    return "".join(n.itertext()) if n is not None else ""


def check(text):
    if not text.startswith(DECL):
        errors.append(f"Erste Zeile muss {DECL} sein.")
    try:
        root = ET.fromstring(text.encode("latin-1"))
    except (ET.ParseError, UnicodeEncodeError) as e:
        errors.append(f"XML nicht wohlgeformt: {e}")
        return
    if root.tag != "baramundiDeployScript":
        errors.append(f"Wurzelelement <{root.tag}> statt <baramundiDeployScript>.")
        return
    if root.get("Version") != SCHEMA["version"]:
        hints.append(f'Version="{root.get("Version")}", erwartet {SCHEMA["version"]}.')
    if not re.fullmatch(r"\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}", root.get("LastChange") or ""):
        errors.append("LastChange fehlt oder ist nicht TT.MM.JJJJ hh:mm:ss.")
    if root.find("META/INFO") is None or root.find("META/STATICVARS/BMSVars") is None:
        errors.append("META/INFO oder META/STATICVARS/BMSVars fehlt.")
    if root.find("ACTIONS") is None:
        errors.append("ACTIONS fehlt.")
        return
    actions = root.findall("ACTIONS/ACTION")
    if not actions:
        errors.append("Keine Aktionen.")
        return

    # Variablennamen ohne Ruecksicht auf Gross-/Kleinschreibung, wie bei baramundi
    defined, cond_vars, exit_vars = set(), set(), {}
    labels, subs, jumps, refs = set(), set(), [], []
    x64, stack, prev, last_top = False, {}, -1, None

    for i, a in enumerate(actions, 1):
        t = a.get("type")
        aid = f"#{i} {t}"

        # Attribute und Einrueckung (level)
        for att in ("level", "breakpoint", "ignore_error", "comment", "is_included", "logging_enabled"):
            v = a.get(att)
            if v is None:
                errors.append(f"{aid}: Attribut {att} fehlt.")
            elif att != "level" and v not in ("0", "1"):
                errors.append(f"{aid}: {att} muss 0 oder 1 sein.")
        try:
            lvl = int(a.get("level"))
        except (TypeError, ValueError):
            errors.append(f"{aid}: level ist keine Zahl.")
            lvl = max(prev, 0)
        if i == 1:
            if lvl != 0:
                errors.append(f"{aid}: die erste Aktion braucht level 0.")
        elif lvl > prev + 1:
            errors.append(f"{aid}: level springt von {prev} auf {lvl}.")
        elif lvl == prev + 1 and stack.get(prev) not in SCHEMA["containers"]:
            errors.append(f"{aid}: einruecken geht nur unter Comment, Conditional oder Subroutine (darueber steht {stack.get(prev)}).")
        in_body = any(stack.get(lv) in ("Conditional", "Subroutine") for lv in range(lvl))
        stack[lvl], prev = t, lvl
        if not in_body and t not in ("Subroutine", "Comment"):
            last_top = a

        # Typ, DATA-Aufbau, CONDITION
        if t not in SCHEMA["actions"]:
            errors.append(f"{aid}: unbekannter Aktionstyp (erlaubt sind nur die Typen aus schema.json).")
            continue
        elems = list(a)
        if not elems or elems[0].tag != "DATA":
            errors.append(f"{aid}: erstes Kindelement muss DATA sein.")
            continue
        data, rest = elems[0], elems[1:]
        if len(rest) > 1 or (rest and rest[0].tag != "CONDITION"):
            errors.append(f"{aid}: nach DATA ist nur ein CONDITION-Element erlaubt.")
        have, want = ",".join(c.tag for c in data), ",".join(SCHEMA["actions"][t])
        if have != want:
            errors.append(f"{aid}: DATA enthaelt [{have}], erwartet [{want}] (Namen und Reihenfolge).")
        cond = a.find("CONDITION")
        if cond is not None:
            if cond.get("op") not in SCHEMA["condition_ops"]:
                errors.append(f'{aid}: Vergleich op="{cond.get("op")}" ist unbekannt.')
            if (cond.get("options") or "") not in ("0", "1", "2", "3"):
                errors.append(f"{aid}: CONDITION options muss 0 bis 3 sein.")
            for m in VAR_RE.finditer((cond.get("op1") or "") + " " + (cond.get("op2") or "")):
                cond_vars.add(m.group(1).lower())
                refs.append((m.group(1), aid, False))

        # Variablen: gesetzte merken, verwendete sammeln
        names = []
        for n in ("VARNAME", "PIDVARNAME"):
            v = val(data, n)
            if v:
                defined.add(v.lower())
                names.append(v)
        if t != "Comment":
            for el in data.iter():
                for m in VAR_RE.finditer(el.text or ""):
                    refs.append((m.group(1), aid, el.tag == "SCRIPT"))
                    names.append(m.group(1))
            if a.get("logging_enabled") == "1" and any(SECRET_RE.search(n) for n in names):
                hints.append(f'{aid}: verwendet offenbar ein Kennwort/Geheimnis und wird protokolliert - logging_enabled="0" setzen.')

        # x64-Modus: Netzwerk, Registry, System32
        if t not in ("EvalVar", "Comment"):
            fields = ("SOURCE", "DESTINATION", "NAME", "FILENAME", "COMMAND", "TARGET", "INIFILE")
            if x64 and any(re.match(r"(\\\\|\{DIP\})", val(data, n)) for n in fields):
                hints.append(f"{aid}: Netzwerkpfad im x64-Modus - laut Doku kann das scheitern, davor SetX64Mode 0.")
        hklm_soft = val(data, "REGISTRY") == "2147483650" and re.match(r"software\\", val(data, "REGKEY"), re.I)
        if t == "EvalVar" and val(data, "SOURCE") == "Registry":
            p = {val(pe, "Param"): val(pe, "Value") for pe in data.findall("Properties/PropertyEntry")}
            hklm_soft = p.get("Registry") == "HKEY_LOCAL_MACHINE" and re.match(r"software\\", p.get("Key", ""), re.I)
        if hklm_soft and not x64:
            hints.append(f"{aid}: HKLM\\SOFTWARE im 32-Bit-Modus landet in WOW6432Node - fuer den 64-Bit-Zweig davor SetX64Mode 1.")
        if not x64 and t not in ("Comment", "RunEmbeddedScript", "RunEmbeddedCmd") and re.search(r"\\system32\\", "".join(data.itertext()), re.I):
            hints.append(f"{aid}: System32-Pfad im 32-Bit-Modus wird nach SysWOW64 umgeleitet - davor SetX64Mode 1.")

        # Typbezogene Pruefungen
        if t in SCHEMA["service_types"] and val(data, "TYPE") != SCHEMA["service_types"][t]:
            errors.append(f"{aid}: TYPE muss {SCHEMA['service_types'][t]} sein.")
        if t in ("RunEmbeddedScript", "RunEmbeddedCmd", "LaunchProcess"):
            rc, vn = val(data, "RETURNCODES"), val(data, "VARNAME")
            if rc == "*" and not vn:
                hints.append(f"{aid}: RETURNCODES * ohne VARNAME - jeder Exitcode zaehlt als Erfolg und wird nicht ausgewertet.")
            elif rc == "*":
                exit_vars[vn.lower()] = (vn, aid)
        if t in ("EvalVar", "Wait"):
            key, table = ("SOURCE", "evalvar_sources") if t == "EvalVar" else ("TYPE", "wait_types")
            kind = val(data, key)
            got = ",".join(val(pe, "Param") for pe in data.findall("Properties/PropertyEntry"))
            if kind not in SCHEMA[table]:
                errors.append(f"{aid}: {key} '{kind}' ist unbekannt.")
            elif got != ",".join(SCHEMA[table][kind]):
                errors.append(f"{aid}: Properties [{got}], erwartet [{','.join(SCHEMA[table][kind])}].")
        elif t == "SetX64Mode":
            mode = val(data, "MODE")
            if mode in ("0", "1"):
                x64 = mode == "1"
            else:
                errors.append(f"{aid}: MODE muss 0 oder 1 sein.")
        elif t == "EndBDS":
            mode = val(data, "RETURNMODESTR")
            if mode not in ("0", "1", "2"):
                errors.append(f"{aid}: RETURNMODESTR muss 0 (Fehler), 1 (Erfolg) oder 2 (Rueckgabewert) sein.")
            elif mode == "2" and not val(data, "RETURNCODESTR"):
                errors.append(f"{aid}: Modus 2 (Rueckgabewert) ohne RETURNCODESTR.")
            if re.search(r"\$[A-Za-z]", val(data, "RETURNMESSAGE")):
                hints.append(f"{aid}: Meldung enthaelt eine PowerShell-Variable - baramundi ersetzt nur {{Variablen}}.")
        elif t in ("Label", "Subroutine"):
            n, seen = val(data, "NAME").lower(), labels if t == "Label" else subs
            if n in seen:
                errors.append(f"{aid}: {'Sprungmarke' if t == 'Label' else 'Unterroutine'} '{val(data, 'NAME')}' gibt es doppelt.")
            seen.add(n)
        elif t in ("GotoLabel", "CallSubroutine"):
            jumps.append((aid, "Sprungmarke" if t == "GotoLabel" else "Unterroutine", val(data, "NAME")))
        elif t == "RunEmbeddedScript":
            lang, code = val(data, "SCRIPTLANGUAGE"), val(data, "SCRIPT")
            if lang not in SCHEMA["script_languages"]:
                hints.append(f"{aid}: SCRIPTLANGUAGE '{lang}' ist in den Beispielen nicht belegt - im Automation Studio pruefen.")
            if code.startswith(BOM):
                hints.append(f"{aid}: Skript im UTF-8+BOM-Altformat (Umlaute im Editor unlesbar) - mit 'open --normalize' nach Latin-1 umstellen.")
            elif re.search(r"\xc3[\x80-\xbf]", code):
                hints.append(f"{aid}: Skript enthaelt UTF-8-Bytefolgen in Latin-1-Text - Kodierung pruefen.")
            if lang.startswith("PowerShell"):
                if not x64:
                    hints.append(f"{aid}: x64-Modus ist aus - PowerShell laeuft als 32-Bit-Prozess.")
                hints.append(f"{aid}: PowerShell-Syntax nicht geprueft (nur bds.ps1 unter Windows kann das).")

    # Querverweise
    for aid, kind, name in jumps:
        if name.lower() not in (labels if kind == "Sprungmarke" else subs):
            errors.append(f"{aid}: {kind} '{name}' existiert nicht.")
    unknown = {}
    for n, aid, in_script in refs:
        # Kindvariablen wie {Datei.Size} oder {Liste.1.Name} gehoeren zur Variable vor dem ersten Punkt
        if n.lower() in defined or n.split(".")[0].lower() in defined or re.fullmatch(r"%.+%", n) \
                or n.lower() in (b.lower() for b in SCHEMA["builtin_variables"]) \
                or any(n.lower().startswith(p.lower()) for p in SCHEMA["variable_prefixes"]):
            continue
        key = f"Platzhalter {{{n}}} im Skript" if in_script else f"{{{n}}}"
        ids = unknown.setdefault(key, [])
        if aid not in ids:
            ids.append(aid)
    for key, ids in unknown.items():
        hints.append(f"{key} ist weder gesetzt noch bekannt und bliebe zur Laufzeit als Text stehen (Tippfehler?): {', '.join(ids)}")
    for low, (vn, aid) in exit_vars.items():
        if low not in cond_vars:
            hints.append(f"{aid}: Exitcode in {{{vn}}} wird in keiner Bedingung ausgewertet.")
    if last_top is None or last_top.get("type") != "EndBDS" or last_top.find("CONDITION") is not None:
        hints.append("Die zuletzt ausgefuehrte Aktion ist kein bedingungsloses EndBDS - Auffang fuer unerwartete Faelle fehlt.")


def open_bds(src, dst, normalize):
    text = Path(src).read_bytes().decode("latin-1")
    count = {"legacy": 0, "converted": 0}

    def fix(m):
        body = m.group(2)
        if body.startswith(BOM):
            count["legacy"] += 1
            if normalize:
                dec = body.encode("latin-1").decode("utf-8", errors="replace")[1:]
                if re.search(r"[^\x00-\xff]", dec):
                    hints.append(f"Skript ab Zeichen {m.start(2)} enthaelt Zeichen ausserhalb von Latin-1 und bleibt im UTF-8-Altformat.")
                else:
                    body = re.sub(r"\r?\n", "\r\n", dec)
                    count["converted"] += 1
        return m.group(1) + body + m.group(3)

    text = re.sub(r"(<SCRIPT>)([\s\S]*?)(</SCRIPT>)", fix, text)
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print(f"Arbeitskopie (UTF-8): {dst}")
    if count["legacy"]:
        print(f"Skripte im UTF-8+BOM-Altformat: {count['legacy']}, nach Latin-1 umgestellt: {count['converted']}")
    if count["legacy"] > count["converted"] and not normalize:
        hints.append("Vor Aenderungen in diesen Skripten mit --normalize oeffnen; ohne Aenderung bleiben sie byte-genau erhalten.")


def save(src, dst, backup):
    with open(src, encoding="utf-8-sig", newline="") as f:
        text = f.read()
    # CRLF ueberall, ausser in Skripten im UTF-8+BOM-Altformat (die bleiben byte-genau)
    parts = re.split(r"(<SCRIPT>[\s\S]*?</SCRIPT>)", text)
    text = "".join(p if p.startswith("<SCRIPT>" + BOM) else re.sub(r"\r?\n", "\r\n", p) for p in parts)
    if not text.endswith("\r\n"):
        text += "\r\n"
    # Edit-Werkzeuge vereinheitlichen Zeilenenden der ganzen Datei. Altformat-Skripte, die inhaltlich gleich
    # geblieben sind, deshalb byte-genau aus der vorhandenen Zieldatei uebernehmen.
    if Path(dst).exists():
        legacy_re = re.compile(r"<SCRIPT>" + re.escape(BOM) + r"[\s\S]*?</SCRIPT>")
        orig = {m.group().replace("\r\n", "\n"): m.group()
                for m in legacy_re.finditer(Path(dst).read_bytes().decode("latin-1"))}
        text = legacy_re.sub(lambda m: orig.get(m.group().replace("\r\n", "\n"), m.group()), text)
    now = datetime.datetime.now().strftime("%d.%m.%Y %H:%M:%S")
    text = re.sub(r'(<baramundiDeployScript\b[^>]*?\bLastChange=")[^"]*"', lambda m: m.group(1) + now + '"', text, count=1)
    for m in list(re.finditer(r"[^\x00-\xff]", text))[:10]:
        line = text.count("\n", 0, m.start()) + 1
        errors.append(f"Zeile {line}: Zeichen U+{ord(m.group()):04X} gibt es in ISO-8859-1 nicht "
                      "(z. B. typografische Anfuehrungszeichen, Gedankenstrich, Euro) - ersetzen.")
    if not errors:
        check(text)
    if errors:
        print("Nicht gespeichert.")
        return
    dst = Path(dst)
    if dst.exists():
        if not backup:
            errors.append(f"{dst} existiert bereits - mit --backup ueberschreiben (legt eine .bak-Sicherung an) oder anderen Namen waehlen.")
            return
        bak = dst.with_name(dst.name + ".bak")
        if bak.exists():
            bak = dst.with_name(f"{dst.name}.{datetime.datetime.now():%Y%m%d-%H%M%S}.bak")
        shutil.copy2(dst, bak)
        print(f"Sicherung: {bak}")
    dst.write_bytes(text.encode("latin-1"))
    print(f"Gespeichert: {dst} (ISO-8859-1, CRLF)")


def main():
    ap = argparse.ArgumentParser(description="baramundi-.bds oeffnen, speichern, pruefen")
    ap.add_argument("command", choices=["open", "save", "check"])
    ap.add_argument("path")
    ap.add_argument("target", nargs="?")
    ap.add_argument("--normalize", action="store_true", help="open: UTF-8+BOM-Altskripte nach Latin-1 umstellen")
    ap.add_argument("--backup", action="store_true", help="save: vorhandene Zieldatei vorher als .bak sichern")
    a = ap.parse_args()
    try:
        if a.command == "check":
            check(Path(a.path).read_bytes().decode("latin-1"))
        elif not a.target:
            print(f"FEHLER: Ziel fehlt: bds.py {a.command} <Quelle> <Ziel>")
            return 2
        elif a.command == "open":
            open_bds(a.path, a.target, a.normalize)
        else:
            save(a.path, a.target, a.backup)
    except OSError as e:
        print(f"FEHLER: {e}")
        return 2
    for e in errors:
        print(f"FEHLER: {e}")
    for h in hints:
        print(f"HINWEIS: {h}")
    print(f"Ergebnis: {len(errors)} Fehler, {len(hints)} Hinweise.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

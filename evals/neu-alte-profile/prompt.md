---
tags: [skill-creator]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash, PowerShell]
---
Schreib mir ein Skript fürs baramundi Automation Studio, das auf dem Client nachschaut, ob es lokale Benutzerprofile gibt, die länger als X Tage nicht benutzt wurden. X soll ein Job-Parameter sein (Standard 90). Die gefundenen Profile sollen in ein Log geschrieben werden. Wenn welche gefunden werden, soll der Job als Fehler enden, damit ich es in der Übersicht sehe, sonst Erfolg.

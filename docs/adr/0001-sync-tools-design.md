# 0001: Design der Sync-Werkzeuge (sync-*, t3-fs-*)

Status: angenommen (2026-11)

## Kontext

Auf Webhosting-Servern sollen Dateien und Ordner (vor allem der TYPO3-fileadmin) zwischen Live, Stage und Dev abgeglichen werden, ohne dass man die rsync-Syntax kennen muss. Die Gegenstelle ist ein anderer Server (SSH-Alias, Passwort-Login ist normal) oder nur ein anderer Ordner auf demselben Server.

## Entscheidungen

1. **Wrapper statt rohes rsync.** Ein fester Satz Standards (Optionen, Pfadregeln, Excludes) und Sicherheitsnetze (Dry-Run, Rückfrage) verhindert die typischen Fehler wie fehlenden oder zusätzlichen Slash. Wer rsync-Optionen braucht, bekommt `--rsync-opts`.
2. **Spiegel-Prinzip, Pfad relativ zu `~`.** Ein Pfad gilt auf beiden Seiten gleich (Basis der Gegenstelle ist `REMOTE_BASE_DIR` bzw. deren Home), dadurch gibt es nur ein Argument und keine Verwechslung von Quelle und Ziel. Absolute Pfade außerhalb des Home und `..` werden abgelehnt.
3. **Slash nur bei `--to` relevant (cp-Konvention).** Ein Slash am Ende von `--to` heißt "in diesen Ordner hinein", ohne Slash ist es der Pfad des Objekts selbst. Das ist vorhersehbar, statt vom Zustand des Ziels abzuhängen (existiert der Ordner schon?).
4. **Dry-Run mit Rückfrage als Standard.** Jeder Lauf zeigt erst die Änderungsliste mit Zusammenfassung und fragt dann "y/N"; `--run` und `--dry-run` sind bewusste Abkürzungen. So wird nichts aus Versehen übertragen, und der Dry-Run ist in Skripten trotzdem schnell.
5. **Löschen nie als Standard.** `--delete` ist eine eigene Option, wirkt auch mit `--run` (bewusste Entscheidung) und wird in der Rückfrage rot mit der Anzahl genannt. Eigene `--rsync-opts` schalten das Löschen nie ein oder aus.
6. **`-rlt` statt `-a`.** Rechte, Besitzer und Gruppe sollen auf Webhostings nicht mitwandern (andere Benutzer, Rechte-Schema), sonst scheitern Läufe oder erzeugen falsche Rechte. Zeiten bleiben erhalten, damit rsync wirklich nur Geändertes überträgt.
7. **Verbindungsteilung (ControlMaster).** Mit Passwort-Login würde jeder ssh-Aufruf (Versionsprüfung, Probes, rsync) neu nach dem Passwort fragen. Ein gemeinsamer Master für die Dauer des Laufs lässt es bei einer Abfrage.
8. **Eine gemeinsame `sync_<name>.conf`, `REMOTE_BASE_DIR` für SSH oder Ordner.** Dieselbe Gegenstelle gilt für `sync-*` und `t3-fs-*`; ohne `SSH_HOST` ist `REMOTE_BASE_DIR` ein anderer Ordner auf demselben Server. Zugangsdaten stehen nie in der Config, nur der Alias aus `~/.ssh/config`.
9. **`conf/` mit Root-Fallback.** Echte Configs liegen in `conf/` (per `.gitignore` ausgeschlossen, Vorlage versioniert), alte Dateien im Repo-Root werden übergangsweise weiter gefunden. Gibt es einen Namen an beiden Orten, gewinnt `conf/` und die Doppelung wird gemeldet.
10. **Home als Basis, fileadmin-Pfade je Seite in der Config.** Der fileadmin liegt auf Live, Stage und Dev an verschiedenen Stellen, deshalb stehen `LOCAL_FILEADMIN_DIR` und `REMOTE_FILEADMIN_DIR` pro Gegenstelle in der Config. Für `sync-*` bleibt das Home die einzige Wurzel.
11. **Kein Storage-Index-Hinweis im Wrapper.** Der Hinweis wäre bei jedem Lauf Rauschen und trifft nur bei abweichendem Ziel oder `--delete` zu. Der Zusammenhang (Dateien und `sys_file` aus demselben Stand) steht stattdessen in der README.
12. **Namensraum `t3-`.** Die TYPO3-Befehle heißen `t3-fs-send`/`t3-fs-fetch` und sind klar vom Kern `sync-*` getrennt. `fs` steht für den Dateispeicher und lässt Platz für weitere `t3-*`-Befehle.
13. **Kern plus dünne TYPO3-Schicht.** `t3/t3-fs-*.sh` setzen nur `SYNC_T3=1` und rufen dieselbe Funktion `sync_transfer_main` wie der Kern auf; fileadmin-Wurzel, feste Excludes (`_processed_/`, `_temp_/`, `_recycler_/`), `--all` und die Existenzprüfung der fileadmin-Ordner (`--need-dir` in `sync_run`) sind die einzigen Unterschiede. Ablauf und Tests existieren so nur einmal.

## Folgen

- `--to` bei `t3-fs-*` ist nur mit Unterpfad erlaubt (sonst würde der ganze fileadmin in einen Unterordner kopiert).
- `--mirror` bei `t3-fs-*` ist die Komplettübernahme (ganzer fileadmin wie die Quelle): `--delete` plus `_processed_/` mit, `_temp_/`, `_recycler_/` und `EXTRA_EXCLUDES` weiter aus. Nur ohne Unterpfad (Teilordner syncen mit den normalen Optionen), nicht mit `--all` oder `--to`. Grund: nach Übernahme einer Stage-DB sollen die Dateien zu `sys_file_processedfile` passen; `--delete` allein ließe verwaiste Processed-Dateien stehen.
- Fehlende fileadmin-Ordner brechen vor jeder Änderung ab; eine falsche Config endet nicht in einem falschen Pfad.
- Die Befehle ohne Endung sind Symlinks in `~/bin`, angelegt von `install.sh`; Cron und Hooks nutzen den absoluten Pfad auf die `.sh`.

# remote-tools

Sammlung von Aliases und Skripten (Bash-Aliases, -Funktionen und Befehle), die auf allen Remote-Servern (Webhosting) und lokal zur Verfügung stehen sollen.

## Einrichtung auf einem neuen Remote

```
git clone https://github.com/coding-daniel-de/remote-tools.git ~/remote-tools
~/remote-tools/install.sh
```

`install.sh` bindet `remote-aliases.sh` per `source`-Zeile in die `~/.bashrc` ein (nur, wenn sie noch fehlt) und legt Symlinks ohne Endung in `~/bin` an (`sync-send`, `sync-fetch`, `sync-configs`, `t3-fs-send`, `t3-fs-fetch`; Ordner wird bei Bedarf angelegt). Existiert am Ziel schon etwas anderes, bricht der Installer ab und ändert nichts; ein erneuter Aufruf ist gefahrlos. Anderer Zielordner: `./install.sh [--path] <ziel-ordner>`. Zusätzlich sorgt es dafür, dass der Zielordner (`~/bin`) im `PATH` liegt (Block mit Marker `# bin-path` in der `~/.bashrc`, kommt nie doppelt). Die restliche `.bashrc` bleibt unangetastet, es wird nur ergänzt. Es wird kein `realpath` benötigt, der Installer läuft auch auf älteren Servern (z. B. Debian 7).

Alle Eintragungen (Aliase, `PATH`, Login-Zeile) erfolgen im Terminal mit Rückfrage (y/N), mit `./install.sh --path` ohne Rückfrage. Ohne Terminal und ohne `--path` legt der Installer nur die Symlinks an und gibt die Zeilen als Hinweis aus.

**Login-Kette:** Bei einem Login (z. B. per SSH) liest bash nur die erste vorhandene Datei von `~/.bash_profile`, `~/.bash_login` und `~/.profile`. Bindet diese Datei die `~/.bashrc` nicht ein, fehlen dort `PATH`-Eintrag und Aliase. Deshalb prüft `install.sh` diese Datei und schlägt, falls nötig, die Zeile `[ -f ~/.bashrc ] && . ~/.bashrc` vor (bestehender Inhalt bleibt unverändert).

Der Zielordner ist frei wählbar, z. B. `~/scripts/remote-tools`. Der Installer ermittelt seinen eigenen Ort und trägt dessen absoluten Pfad ein, die Aliasdatei bleibt im Repo. Wird der Ordner später verschoben, `install.sh` am neuen Ort erneut ausführen und die alte Zeile in der `~/.bashrc` von Hand entfernen.

Update später:

```
git -C ~/remote-tools pull
```

## Enthalten

### tilde-path

```
tilde-path datei
```

Gibt den absoluten Pfad mit `~` statt `$HOME` aus, z. B. `~/mein-folder/datei`. Hilfreich für `scp`, wenn das Hosting per chroot arbeitet und der echte absolute Pfad im SFTP-Jail nicht existiert. Reine bash, ohne `realpath`.

### Tab-Vervollständigung

Für `sync-send`, `sync-fetch`, `t3-fs-send` und `t3-fs-fetch` vervollständigt die Tabulatortaste an Position 1 die Namen der Gegenstellen (alle `sync_<name>.conf`). Die Namen werden erst beim Tab-Druck gelesen, das Laden der Shell wird nicht langsamer.

## Sync-Werkzeuge (rsync)

Dateien und Ordner zwischen zwei Umgebungen abgleichen: `sync-send` schickt zur Gegenstelle, `sync-fetch` holt von dort. `t3-fs-send` und `t3-fs-fetch` sind die dünne TYPO3-Schicht darüber für den fileadmin.

### Gegenstelle einrichten (Config)

Pro Gegenstelle eine Datei `conf/sync_<name>.conf` (Vorlage: `conf/sync_template.conf`, der Name ist das, was man als `<server>` angibt). Die Datei gilt für alle vier Befehle. Passwörter gehören nie hinein, Verbindungsdaten stehen als Alias in `~/.ssh/config`.

| Schlüssel | Bedeutung |
|---|---|
| `SSH_HOST` | Alias aus `~/.ssh/config`. Leer = die Gegenstelle ist nur ein anderer Ordner auf diesem Server. |
| `REMOTE_BASE_DIR` | Basis der Gegenstelle. Mit SSH optional (Standard: Home der Gegenstelle), ohne `SSH_HOST` Pflicht und absolut. Keine Tilde. |
| `LOCAL_FILEADMIN_DIR` | Nur `t3-fs-*`: fileadmin dieser Maschine, relativ zum Home (z. B. `public/fileadmin`). |
| `REMOTE_FILEADMIN_DIR` | Nur `t3-fs-*`: fileadmin der Gegenstelle, relativ zu `REMOTE_BASE_DIR` bzw. deren Home. |
| `EXTRA_EXCLUDES` | Nur `t3-fs-*`: zusätzliche rsync-Excludes, durch Leerzeichen getrennt. |
| `RSYNC_OPTS` | Ersetzt die Standard-rsync-Optionen (`-rlt --partial`). |

`sync-configs` (oder jeder Sync-Befehl mit `--configs`) zeigt alle Gegenstellen als Tabelle, bei `t3-fs-*` mit der Zusatzspalte "fileadmin" (sind beide fileadmin-Pfade gesetzt?).

### sync-send und sync-fetch

```
sync-send  <server> <pfad> [--to <ziel>] [--run | --dry-run] [--delete] [--rsync-opts "<opts>"] [--configs]
sync-fetch <server> <pfad> [--to <ziel>] [--run | --dry-run] [--delete] [--rsync-opts "<opts>"] [--configs]
```

Beispiele (Befehl, Ergebnis):

| Befehl | Ergebnis |
|---|---|
| `sync-send stage notizen.txt` | `~/notizen.txt` nach `stage:~/notizen.txt` |
| `sync-send stage notizen.txt --to backup/` | `stage:~/backup/notizen.txt` (in den Ordner hinein) |
| `sync-send stage notizen.txt --to backup` | eine **Datei** `backup` auf der Gegenstelle |
| `sync-send stage public/fileadmin/user_upload --to tmp/test` | Ordner nach `~/tmp/test` auf der Gegenstelle |
| `sync-fetch live public/fileadmin/user_upload` | holt diesen Ordner an dieselbe Stelle |

Regeln:

- **Spiegel-Prinzip:** `<pfad>` ist relativ zu `~` und gilt auf beiden Seiten gleich. Auf der Gegenstelle ist die Basis `REMOTE_BASE_DIR` bzw. deren Home. Ein Slash am Ende von `<pfad>` ist egal; `..` und das ganze Home sind nicht erlaubt.
- **`--to`:** Pfad des Objekts selbst auf der Zielseite. Nur ein Slash am Ende von `--to` bedeutet "in diesen Ordner hinein" (wie bei `cp`).
- **Standard = Dry-Run + Rückfrage:** erst die Änderungsliste mit Zusammenfassung, dann "Ausführen? (y/N)". `--run` führt ohne Rückfrage aus, `--dry-run` zeigt nur die Liste.
- **`--delete`:** löscht am Ziel, was in der Quelle fehlt. Nie Standard; auch mit `--run` erlaubt (bewusste Entscheidung), die Rückfrage nennt die Zahl der Löschungen.
- **Excludes:** `sync-*` kennt keine festen Excludes, nur die von `t3-fs-*`.
- **Ordner-Modus:** Ist `SSH_HOST` leer, ist `REMOTE_BASE_DIR` ein anderer Ordner auf demselben Server (z. B. Stage neben Live). Quelle und Ziel dürfen nicht gleich oder ineinander verschachtelt sein.
- **`--rsync-opts "<opts>"`** ersetzt die Standardoptionen (`-rlt --partial`) für diesen Aufruf; Reihenfolge: Aufruf vor `RSYNC_OPTS` vor Standard. Das Löschen bleibt davon unberührt.
- Bei SSH wird die Verbindung geteilt (ControlMaster), das Passwort wird nur einmal abgefragt.

### t3-fs-send und t3-fs-fetch

```
t3-fs-send  <server> [unterpfad] [--to <ziel>] [--run | --dry-run] [--delete] [--all | --mirror] [--rsync-opts "<opts>"] [--configs]
t3-fs-fetch <server> [unterpfad] [--to <ziel>] [--run | --dry-run] [--delete] [--all | --mirror] [--rsync-opts "<opts>"] [--configs]
```

Der Unterpfad ist relativ zum fileadmin-Root und optional. Lokal gilt `~/<LOCAL_FILEADMIN_DIR>/<unterpfad>`, entfernt `<Basis>/<REMOTE_FILEADMIN_DIR>/<unterpfad>`. Beide fileadmin-Ordner müssen existieren, sonst Abbruch. Ablauf (Dry-Run, Rückfrage, `--run`, `--delete` usw.) wie oben.

| Befehl | Ergebnis |
|---|---|
| `t3-fs-send stage` | ganzer fileadmin nach Stage |
| `t3-fs-send stage user_upload/bilder` | nur dieser Unterordner |
| `t3-fs-send stage user_upload/bilder --to test/bilder` | Probelauf in einen Testordner auf Stage |
| `t3-fs-fetch live user_upload` | holt diesen Unterordner von Live |

Fest ausgeschlossen sind `_processed_/`, `_temp_/` und `_recycler_/`, dazu `EXTRA_EXCLUDES` aus der Config. `--all` schaltet nur die drei festen Standards ab. **`--mirror`** ist die sinnvolle Option, wenn das komplette System übernommen werden soll (z. B. Stage-DB samt fileadmin 1:1 auf Live oder umgekehrt): ganzer fileadmin wie die Quelle (`--delete`), inklusive `_processed_/`, damit die Dateien zur übernommenen `sys_file_processedfile` passen. `_temp_/`, `_recycler_/` und `EXTRA_EXCLUDES` bleiben ausgeschlossen. Nur ohne Unterpfad, nicht zusammen mit `--all` oder `--to`; Dry-Run und Rückfrage bleiben. Ausgeschlossene Pfade fasst rsync am Ziel auch bei `--delete` nicht an.

`--to` gibt es nur zusammen mit einem Unterpfad (sonst würde der ganze fileadmin in einen Unterordner kopiert). Weicht das Ziel vom Quellpfad ab, kennt TYPO3 die Dateien erst nach dem Indexieren (Ordner im Backend öffnen oder Storage-Index aktualisieren). Soll der Ordner an die echte Stelle, danach ohne `--to` erneut syncen.

#### Storage-Index (wichtig)

Dateien im fileadmin und die Tabellen `sys_file`/`sys_file_metadata` müssen aus demselben Stand kommen: Live-DB und Live-fileadmin zusammen. Nur den fileadmin zu syncen erzeugt Abweichungen. Verweise über `sys_file_reference` laufen über `sys_file`-UIDs; der Indexer vergibt für unbekannte Dateien neue UIDs und repariert keine fremden Verweise.

Neue Dateien indexiert TYPO3 beim Öffnen des Ordners im Backend meist selbst. Nach `--delete` bleiben `sys_file`-Einträge stehen, bis der Indexer sie als fehlend (`missing`) markiert. Dafür gibt es keinen eigenen Konsolenbefehl, nur den Scheduler-Task "File Abstraction Layer: Update storage index", konsolenseitig `vendor/bin/typo3 scheduler:execute --task=<UID>`. (`referenceindex:update` ist dafür nicht der richtige Befehl, er betrifft `sys_refindex`.)

### Tests

`tests/run.sh` führt alle Tests aus (Wegwerf-Ordner, SSH über einen Stub, kein echter Server nötig).

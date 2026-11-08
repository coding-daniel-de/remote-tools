#!/bin/bash
# Tests fuer sync-send.sh / sync-fetch.sh / sync_run. Ordner-Modus mit echtem rsync in Wegwerf-Ordnern,
# SSH-Modus ueber den ssh-Stub (tests/stubs/ssh, $STUB_REMOTE als Home der Gegenstelle).
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
TOOLS="$T/tools"
SEND="$TOOLS/sync/sync-send.sh"
FETCH="$TOOLS/sync/sync-fetch.sh"
mkdir -p "$T/other" "$T/remote"
printf 'REMOTE_BASE_DIR="%s"\n' "$T/other" > "$TOOLS/conf/sync_dir.conf"
printf 'SSH_HOST="stubhost"\n' > "$TOOLS/conf/sync_ssh.conf"
printf 'SSH_HOST="stubhost"\nREMOTE_BASE_DIR="base"\n' > "$TOOLS/conf/sync_sshbase.conf"
export STUB_REMOTE="$T/remote" STUB_SSH_LOG="$T/ssh.log"
ORIG_PATH="$PATH"
H="$HOME"   # lokales Home = $T

reset() { rm -rf "$T/other" "$T/remote" "$H/data" "$H/notizen.txt" "$H/tmp"; mkdir -p "$T/other" "$T/remote"; : > "$STUB_SSH_LOG"; }
content() { cat "$1" 2>/dev/null; }
mkdata() { mkdir -p "$H/data/sub"; echo a > "$H/data/a.txt"; echo b > "$H/data/sub/b.txt"; echo hallo > "$H/notizen.txt"; }
sshon() { export PATH="$T/stubs:$ORIG_PATH"; }
sshoff() { export PATH="$ORIG_PATH"; }

# --- Ordner-Modus: Datei und Ordner, send und fetch ---
reset; mkdata
"$SEND" dir notizen.txt --run >/dev/null 2>&1
ok "send Datei: landet in der Basis" '[ "$(content "$T/other/notizen.txt")" = hallo ]'
"$SEND" dir data --run >/dev/null 2>&1
ok "send Ordner: Spiegel" '[ -f "$T/other/data/sub/b.txt" ] && [ -f "$T/other/data/a.txt" ]'
"$SEND" dir data/ --run >/dev/null 2>&1
ok "Slash am Ende egal" '[ -f "$T/other/data/a.txt" ] && [ ! -e "$T/other/data/data" ]'
ok "~/ am Anfang toleriert" '"$SEND" dir "~/notizen.txt" --run >/dev/null 2>&1'
ok "\$HOME/ am Anfang toleriert" '"$SEND" dir "\$HOME/notizen.txt" --run >/dev/null 2>&1'
ok "absoluter Pfad im Home toleriert" '"$SEND" dir "$H/notizen.txt" --run >/dev/null 2>&1'
rm -rf "$H/data" "$H/notizen.txt"
"$FETCH" dir data --run >/dev/null 2>&1
ok "fetch Ordner: Spiegel" '[ -f "$H/data/sub/b.txt" ]'
"$FETCH" dir notizen.txt --run >/dev/null 2>&1
ok "fetch Datei" '[ "$(content "$H/notizen.txt")" = hallo ]'

# --- --to in allen Formen ---
reset; mkdata
"$SEND" dir notizen.txt --to backup/notizen-alt.txt --run >/dev/null 2>&1
ok "--to Datei mit neuem Namen" '[ "$(content "$T/other/backup/notizen-alt.txt")" = hallo ]'
"$SEND" dir notizen.txt --to backup2/ --run >/dev/null 2>&1
ok "--to mit Slash: in Ordner hinein" '[ "$(content "$T/other/backup2/notizen.txt")" = hallo ]'
"$SEND" dir notizen.txt --to=backup3 --run >/dev/null 2>&1
ok "--to ohne Slash: Datei mit diesem Namen" '[ -f "$T/other/backup3" ]'
"$SEND" dir data --to tmp/test --run >/dev/null 2>&1
ok "--to Ordner ohne Slash: Spiegel" '[ -f "$T/other/tmp/test/a.txt" ] && [ -f "$T/other/tmp/test/sub/b.txt" ]'
"$SEND" dir data --to tmp/ --run >/dev/null 2>&1
ok "--to Ordner mit Slash: Ordnername angehaengt" '[ -f "$T/other/tmp/data/a.txt" ]'
OUT=$("$SEND" dir notizen.txt --to zielx/ --dry-run 2>&1)
ok "Rueckfrage/Ausgabe zeigt aufgeloesten Zielpfad" 'echo "$OUT" | grep -q "Nach: $T/other/zielx/notizen.txt"'
"$SEND" dir notizen.txt --run >/dev/null 2>&1
"$FETCH" dir notizen.txt --to lokal/kopie.txt --run >/dev/null 2>&1
ok "fetch --to: lokale Zielseite" '[ "$(content "$H/lokal/kopie.txt")" = hallo ]'
echo x > "$T/other/ordnerdatei"
mkdir -p "$T/other/istordner"
OUT=$("$SEND" dir notizen.txt --to istordner --run 2>&1); RC=$?
ok "Datei auf bestehenden Ordner: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "ist ein Ordner"'

# --- Dry-Run, Rueckfrage, --run ---
reset; mkdata
OUT=$("$SEND" dir data --dry-run 2>&1); RC=$?
ok "--dry-run: Exit 0, Liste da" '[ $RC -eq 0 ] && echo "$OUT" | grep -q "a.txt"'
ok "--dry-run: nichts geaendert" '[ ! -e "$T/other/data" ]'
ok "--dry-run: keine Rueckfrage" '! echo "$OUT" | grep -q "Ausführen?"'
ok "Zusammenfassung mit Anzahl" 'echo "$OUT" | grep -qE "Zusammenfassung: [0-9]+ neu, 0 geändert, 0 zu löschen"'
OUT=$(echo n | "$SEND" dir data 2>&1); RC=$?
ok "Standard fragt, n bricht ab" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "Ausführen? (y/N)" && [ ! -e "$T/other/data" ]'
OUT=$("$SEND" dir data </dev/null 2>&1); RC=$?
ok "Standard: leere Eingabe = Nein" '[ $RC -ne 0 ] && [ ! -e "$T/other/data" ]'
OUT=$(echo y | "$SEND" dir data 2>&1); RC=$?
ok "Standard: y fuehrt aus" '[ $RC -eq 0 ] && [ -f "$T/other/data/a.txt" ]'
OUT=$("$SEND" dir data --run 2>&1 </dev/null)
ok "zweiter Lauf: keine Aenderungen" 'echo "$OUT" | grep -q "Keine Änderungen"'
rm -rf "$T/other/data"
OUT=$("$SEND" dir data --run 2>&1 </dev/null)
ok "--run fragt nicht" '! echo "$OUT" | grep -q "Ausführen?" && [ -f "$T/other/data/a.txt" ]'
ok "--run und --dry-run zusammen: Fehler" '! "$SEND" dir data --run --dry-run >/dev/null 2>&1'

# --- --delete ---
echo weg > "$T/other/data/extra.txt"
"$SEND" dir data --run >/dev/null 2>&1
ok "ohne --delete wird nichts geloescht" '[ -f "$T/other/data/extra.txt" ]'
OUT=$(echo n | "$SEND" dir data --delete 2>&1)
ok "--delete: Loeschzahl in der Rueckfrage" 'echo "$OUT" | grep -q "1 Datei(en) werden gelöscht" && echo "$OUT" | grep -q "1 zu löschen"'
ok "--delete mit n: nichts geloescht" '[ -f "$T/other/data/extra.txt" ]'
"$SEND" dir data --delete --run >/dev/null 2>&1
ok "--delete mit --run erlaubt, loescht" '[ ! -e "$T/other/data/extra.txt" ] && [ -f "$T/other/data/a.txt" ]'

# --- rsync-Optionen ---
# Rechte-Test: Ziel existiert mit 644, Quelle hat 600. Ohne -p bleibt 644, mit -p wird 600.
reset; mkdata; chmod 600 "$H/notizen.txt"
prep() { echo alt > "$T/other/notizen.txt"; chmod 644 "$T/other/notizen.txt"; touch -d '2000-01-01' "$T/other/notizen.txt"; }
prep; "$SEND" dir notizen.txt --run >/dev/null 2>&1
ok "Standard ohne -p: Rechte nicht uebernommen" '[ "$(stat -c %a "$T/other/notizen.txt")" = 644 ] && [ "$(content "$T/other/notizen.txt")" = hallo ]'
prep; "$SEND" dir notizen.txt --rsync-opts "-rlt -p" --run >/dev/null 2>&1
ok "--rsync-opts ersetzt den Standard" '[ "$(stat -c %a "$T/other/notizen.txt")" = 600 ]'
printf 'REMOTE_BASE_DIR="%s"\nRSYNC_OPTS="-rlt -p"\n' "$T/other" > "$TOOLS/conf/sync_optsconf.conf"
prep; "$SEND" optsconf notizen.txt --run >/dev/null 2>&1
ok "RSYNC_OPTS aus der Config ersetzt den Standard" '[ "$(stat -c %a "$T/other/notizen.txt")" = 600 ]'
prep; "$SEND" optsconf notizen.txt --rsync-opts "-rlt" --run >/dev/null 2>&1
ok "--rsync-opts schlaegt RSYNC_OPTS" '[ "$(stat -c %a "$T/other/notizen.txt")" = 644 ]'
rm -f "$T/other/notizen.txt"
"$SEND" dir notizen.txt --rsync-opts "-rlt" --dry-run >/dev/null 2>&1
ok "Schutz: --dry-run aendert auch mit eigenen Optionen nichts" '[ ! -e "$T/other/notizen.txt" ]'
mkdir -p "$T/other/data"; echo weg > "$T/other/data/extra.txt"; mkdir -p "$H/data"; echo a > "$H/data/a.txt"
"$SEND" dir data --rsync-opts "-rlt" --run >/dev/null 2>&1
ok "Schutz: --delete bleibt aus, auch mit eigenen Optionen" '[ -f "$T/other/data/extra.txt" ]'

# --- Fehlerfaelle ---
reset; mkdata
ok "identischer Ordner: Abbruch" 'printf "REMOTE_BASE_DIR=\"%s\"\n" "$H" > "$TOOLS/conf/sync_selbst.conf"; OUT=$("$SEND" selbst data --run 2>&1); [ $? -ne 0 ] && echo "$OUT" | grep -q "derselbe Pfad"'
ok "verschachtelt (Ziel in Quelle): Abbruch" 'OUT=$("$SEND" selbst data --to data/unter --run 2>&1); [ $? -ne 0 ] && echo "$OUT" | grep -q "verschachtelt" && [ ! -e "$H/data/unter" ]'
ok "verschachtelt (Quelle in Ziel): Abbruch" 'OUT=$("$SEND" selbst data/sub --to data --run 2>&1); [ $? -ne 0 ] && echo "$OUT" | grep -q "verschachtelt"'
OUT=$("$SEND" dir data/../notizen.txt --run 2>&1); RC=$?
ok ".. im Pfad: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "\.\."'
OUT=$("$SEND" dir /etc/hosts --run 2>&1); RC=$?
ok "absolut ausserhalb Home: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "nicht im Home"'
ok ".. in --to: Fehler" '! "$SEND" dir notizen.txt --to ../x --run >/dev/null 2>&1'
OUT=$("$SEND" dir gibtsnicht --run 2>&1); RC=$?
ok "fehlende Quelle: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "existiert nicht"'
OUT=$("$SEND" dir 2>&1); RC=$?
ok "fehlender Pfad: Fehler mit Hilfetext" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "Pfad fehlt" && echo "$OUT" | grep -q "sync-send <server> <pfad>"'
ok "Pfad ~ (ganzes Home): Fehler" '! "$SEND" dir "~" --run >/dev/null 2>&1'
OUT=$("$SEND" dir data --foo 2>&1); RC=$?
ok "unbekannte Option: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "Unbekannte Option"'
ok "--to ohne Wert: Fehler" '! "$SEND" dir data --to >/dev/null 2>&1'
ok "unbekannte Gegenstelle: Fehler" '! "$SEND" gibtsnicht data --run >/dev/null 2>&1'
mkdir -p "$T/nobin"; for c in dirname readlink mktemp sed sort head awk cat basename grep; do ln -sf "$(command -v $c)" "$T/nobin/$c"; done
OUT=$(PATH="$T/nobin" "$BASH" "$SEND" dir data --run 2>&1)
ok "fehlendes rsync lokal: Fehler" 'echo "$OUT" | grep -q "rsync ist lokal nicht installiert"'

# --- Tabelle und Hilfe ---
OUT=$("$SEND" 2>&1); RC=$?
ok "ohne Argumente: Tabelle plus Hilfe, Exit 0" '[ $RC -eq 0 ] && echo "$OUT" | grep -qE "^Name +Ziel +Datei" && echo "$OUT" | grep -q "sync-send <server>"'
OUT=$("$FETCH" --configs 2>&1); RC=$?
ok "--configs: Tabelle, Exit 0, keine Hilfe" '[ $RC -eq 0 ] && echo "$OUT" | grep -q "^dir " && ! echo "$OUT" | grep -q "<pfad>"'
ok "fetch-Hilfe nennt sync-fetch" '"$FETCH" 2>&1 | grep -q "sync-fetch <server>"'

# --- Elternordner anlegen ---
reset; mkdata
"$SEND" dir notizen.txt --to a/b/c/n.txt --run >/dev/null 2>&1
ok "fehlende Elternordner werden angelegt" '[ "$(content "$T/other/a/b/c/n.txt")" = hallo ]'
rm -rf "$T/other/a"
"$SEND" dir notizen.txt --to a/b/c/n.txt --dry-run >/dev/null 2>&1
ok "Dry-Run legt keine Elternordner an" '[ ! -e "$T/other/a" ]'

# --- alter rsync (< 3.2.3): kein --mkpath, Elternordner per mkdir -p ---
REAL_RSYNC=$(command -v rsync); mkdir -p "$T/oldbin"
cat > "$T/oldbin/rsync" <<OLD
#!/bin/bash
if [ "\$1" = "--version" ]; then echo "rsync  version 3.1.3  protocol version 31"; exit 0; fi
for a in "\$@"; do [ "\$a" = "--mkpath" ] && { echo "alter rsync kennt --mkpath nicht" >&2; exit 1; }; done
exec "$REAL_RSYNC" "\$@"
OLD
chmod +x "$T/oldbin/rsync"
rm -rf "$T/other/p"
OUT=$(PATH="$T/oldbin:$PATH" "$SEND" dir notizen.txt --to p/q/n.txt --dry-run 2>&1)
ok "alter rsync, Dry-Run: Hinweis, nichts angelegt" 'echo "$OUT" | grep -q "wird beim Ausführen angelegt" && [ ! -e "$T/other/p" ]'
PATH="$T/oldbin:$PATH" "$SEND" dir notizen.txt --to p/q/n.txt --run >/dev/null 2>&1
ok "alter rsync, echter Lauf: Elternordner per mkdir -p" '[ "$(content "$T/other/p/q/n.txt")" = hallo ]'

# --- SSH-Modus (Stub) ---
sshon
reset; mkdata
"$SEND" ssh notizen.txt --run >/dev/null 2>&1
ok "SSH send Datei: im Home der Gegenstelle" '[ "$(content "$T/remote/notizen.txt")" = hallo ]'
"$SEND" ssh data --run >/dev/null 2>&1
ok "SSH send Ordner" '[ -f "$T/remote/data/sub/b.txt" ]'
"$SEND" sshbase data --to ziel/neu --run >/dev/null 2>&1
ok "SSH mit REMOTE_BASE_DIR und --to" '[ -f "$T/remote/base/ziel/neu/a.txt" ]'
rm -rf "$H/data" "$H/notizen.txt"
"$FETCH" ssh data --run >/dev/null 2>&1
ok "SSH fetch Ordner" '[ -f "$H/data/sub/b.txt" ]'
"$FETCH" ssh notizen.txt --run >/dev/null 2>&1
ok "SSH fetch Datei (Typ auf der Gegenstelle erkannt)" '[ "$(content "$H/notizen.txt")" = hallo ]'
"$FETCH" sshbase ziel/neu --to geholt --run >/dev/null 2>&1
ok "SSH fetch mit Basis und --to" '[ -f "$H/geholt/a.txt" ]'
OUT=$(echo n | "$SEND" ssh data 2>&1)
ok "SSH Rueckfrage zeigt Host" 'echo "$OUT" | grep -q "stubhost:~/data"'
echo weg > "$T/remote/data/extra.txt"
OUT=$("$SEND" ssh data --delete --dry-run 2>&1)
ok "SSH --delete Dry-Run zaehlt Loeschung, loescht nicht" 'echo "$OUT" | grep -q "1 zu löschen" && [ -f "$T/remote/data/extra.txt" ]'
OUT=$("$SEND" ssh gibtsnicht --run 2>&1)
ok "SSH fehlende Quelle: Fehler" 'echo "$OUT" | grep -q "existiert nicht"'
export STUB_SSH_FAIL=1
OUT=$("$SEND" ssh data --run 2>&1); RC=$?
ok "SSH-Fehler: Abbruch mit Meldung" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "SSH-Verbindung"'
unset STUB_SSH_FAIL

# ControlMaster
: > "$STUB_SSH_LOG"
"$SEND" ssh data --run >/dev/null 2>&1
ok "ControlMaster-Optionen im ssh-Aufruf" 'grep -q "ControlMaster=auto" "$STUB_SSH_LOG" && grep -q "ControlPersist=60" "$STUB_SSH_LOG" && grep -q "ControlPath=" "$STUB_SSH_LOG"'
ok "ControlMaster-Optionen auch bei rsync -e" 'grep "ARGS" "$STUB_SSH_LOG" | grep -q "rsync --server"'
ok "ssh -O exit beim Beenden" 'grep -q -- "-O exit" "$STUB_SSH_LOG"'
CP=$(grep -o "ControlPath=[^ ]*" "$STUB_SSH_LOG" | head -1 | cut -d= -f2); CPD=$(dirname "$CP")
ok "Socket-Ordner aufgeraeumt" '[ ! -e "$CPD" ]'
ok "Socket-Pfad kurz" '[ ${#CP} -lt 90 ]'
# TMPDIR mit Leerzeichen bzw. zu lang: Ausweichen auf /tmp, Lauf funktioniert
mkdir -p "$T/tmp mit leerzeichen"; : > "$STUB_SSH_LOG"
TMPDIR="$T/tmp mit leerzeichen" "$SEND" ssh data --run >/dev/null 2>&1
ok "TMPDIR mit Leerzeichen: Lauf klappt, Socket unter /tmp" '[ $? -eq 0 ] && grep -q "ControlPath=/tmp/sync-ssh\." "$STUB_SSH_LOG"'
LONG="$T/$(printf 'x%.0s' $(seq 1 80))"; mkdir -p "$LONG"; : > "$STUB_SSH_LOG"
TMPDIR="$LONG" "$SEND" ssh data --run >/dev/null 2>&1
ok "langer TMPDIR: Socket unter /tmp" 'grep -q "ControlPath=/tmp/sync-ssh\." "$STUB_SSH_LOG"'
# Abbruch per SIGTERM
: > "$STUB_SSH_LOG"
STUB_SSH_SLEEP=2 "$SEND" ssh data --run >/dev/null 2>&1 &
BG=$!
for i in $(seq 1 40); do grep -q ControlPath "$STUB_SSH_LOG" && break; sleep 0.1; done
CP=$(grep -o "ControlPath=[^ ]*" "$STUB_SSH_LOG" | head -1 | cut -d= -f2); CPD=$(dirname "$CP")
kill -TERM $BG; wait $BG 2>/dev/null
ok "SIGTERM: Socket-Ordner aufgeraeumt, -O exit" '[ ! -e "$CPD" ] && grep -q -- "-O exit" "$STUB_SSH_LOG"'

# Ordner-Modus: kein SSH
sshoff; : > "$STUB_SSH_LOG"
"$SEND" dir data --run >/dev/null 2>&1
ok "Ordner-Modus: kein ssh-Aufruf" '[ ! -s "$STUB_SSH_LOG" ]'

rm -rf "$T"
exit $PASSFAIL

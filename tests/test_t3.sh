#!/bin/bash
# Tests fuer t3-fs-send.sh / t3-fs-fetch.sh (fileadmin-Pfade, --to, Excludes, Config-Pruefung, Tabelle).
# Ablauf-Logik (Dry-Run, Rueckfrage, --run ...) steckt in sync_run und ist in test_transfer.sh getestet.
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
TOOLS="$T/tools"
SEND="$TOOLS/t3/t3-fs-send.sh"
FETCH="$TOOLS/t3/t3-fs-fetch.sh"
H="$HOME"
mkdir -p "$T/other"
printf 'REMOTE_BASE_DIR="%s"\nLOCAL_FILEADMIN_DIR="public/fileadmin"\nREMOTE_FILEADMIN_DIR="www/fileadmin"\n' "$T/other" > "$TOOLS/conf/sync_dir.conf"
printf 'SSH_HOST="stubhost"\nLOCAL_FILEADMIN_DIR="public/fileadmin"\nREMOTE_FILEADMIN_DIR="www/fileadmin"\n' > "$TOOLS/conf/sync_ssh.conf"
printf 'REMOTE_BASE_DIR="%s"\n' "$T/other" > "$TOOLS/conf/sync_nofa.conf"
printf 'REMOTE_BASE_DIR="%s"\nLOCAL_FILEADMIN_DIR="public/fileadmin"\n' "$T/other" > "$TOOLS/conf/sync_halbfa.conf"
printf 'REMOTE_BASE_DIR="%s"\nLOCAL_FILEADMIN_DIR="public/fileadmin"\nREMOTE_FILEADMIN_DIR="www/fileadmin"\nEXTRA_EXCLUDES="geheim *.tmp"\n' "$T/other" > "$TOOLS/conf/sync_extra.conf"
export STUB_REMOTE="$T/remote" STUB_SSH_LOG="$T/ssh.log"
LFA="$H/public/fileadmin"; RFA="$T/other/www/fileadmin"
content() { cat "$1" 2>/dev/null; }
reset() {
    rm -rf "$H/public" "$T/other/www" "$T/remote"
    mkdir -p "$LFA/user_upload/bilder" "$LFA/_processed_" "$LFA/_temp_" "$LFA/_recycler_" "$RFA" "$T/remote/www/fileadmin"
    echo a > "$LFA/user_upload/bilder/a.jpg"; echo r > "$LFA/root.txt"
    echo p > "$LFA/_processed_/p.jpg"; echo t > "$LFA/_temp_/t.txt"; echo c > "$LFA/_recycler_/c.txt"
    mkdir -p "$LFA/geheim"; echo g > "$LFA/geheim/g.txt"; echo x > "$LFA/x.tmp"
}

# --- Pfadaufloesung: komplett und Unterpfad ---
reset
"$SEND" dir --run >/dev/null 2>&1; RC=$?
ok "ohne Unterpfad: kompletter fileadmin" '[ $RC -eq 0 ] && [ -f "$RFA/root.txt" ] && [ -f "$RFA/user_upload/bilder/a.jpg" ]'
rm -rf "$RFA"; mkdir -p "$RFA"
"$SEND" dir user_upload/bilder --run >/dev/null 2>&1
ok "Unterpfad: nur dieser Ordner an gleicher Stelle" '[ -f "$RFA/user_upload/bilder/a.jpg" ] && [ ! -e "$RFA/root.txt" ]'
OUT=$("$SEND" dir user_upload --dry-run 2>&1)
ok "Ausgabe nennt beide aufgeloesten Pfade" 'echo "$OUT" | grep -q "Von:  $LFA/user_upload" && echo "$OUT" | grep -q "Nach: $RFA/user_upload"'
rm -rf "$LFA"; mkdir -p "$LFA/user_upload"
"$FETCH" dir user_upload/bilder --run >/dev/null 2>&1
ok "fetch Unterpfad: holt an dieselbe Stelle" '[ -f "$LFA/user_upload/bilder/a.jpg" ]'
mkdir -p "$RFA/neu"; echo n > "$RFA/neu/n.txt"
"$FETCH" dir --run >/dev/null 2>&1
ok "fetch ohne Unterpfad: kompletter fileadmin" '[ -f "$LFA/neu/n.txt" ] && [ -f "$LFA/user_upload/bilder/a.jpg" ]'

# --- Excludes ---
reset
"$SEND" dir --run >/dev/null 2>&1
ok "Standard-Excludes: _processed_/_temp_/_recycler_ fehlen am Ziel" '[ ! -e "$RFA/_processed_" ] && [ ! -e "$RFA/_temp_" ] && [ ! -e "$RFA/_recycler_" ] && [ -f "$RFA/root.txt" ]'
rm -rf "$RFA"; mkdir -p "$RFA"
"$SEND" dir --all --run >/dev/null 2>&1
ok "--all: Standard-Excludes aus" '[ -f "$RFA/_processed_/p.jpg" ] && [ -f "$RFA/_temp_/t.txt" ] && [ -f "$RFA/_recycler_/c.txt" ]'
rm -rf "$RFA"; mkdir -p "$RFA"
"$SEND" extra --run >/dev/null 2>&1
ok "EXTRA_EXCLUDES greifen (Leerzeichen getrennt, Glob)" '[ ! -e "$RFA/geheim" ] && [ ! -e "$RFA/x.tmp" ] && [ -f "$RFA/root.txt" ] && [ ! -e "$RFA/_temp_" ]'
rm -rf "$RFA"; mkdir -p "$RFA"
"$SEND" extra --all --run >/dev/null 2>&1
ok "--all laesst EXTRA_EXCLUDES stehen" '[ ! -e "$RFA/geheim" ] && [ -f "$RFA/_temp_/t.txt" ]'
reset
mkdir -p "$RFA/_processed_" "$RFA/_temp_" "$RFA/user_upload"; echo keep > "$RFA/_processed_/k.jpg"; echo keep > "$RFA/_temp_/k.txt"; echo weg > "$RFA/user_upload/alt.txt"
"$SEND" dir --delete --run >/dev/null 2>&1
ok "--delete: ausgeschlossene Ordner am Ziel unberuehrt" '[ -f "$RFA/_processed_/k.jpg" ] && [ -f "$RFA/_temp_/k.txt" ]'
ok "--delete: sonstiges Ueberzaehliges geloescht" '[ ! -e "$RFA/user_upload/alt.txt" ] && [ -f "$RFA/root.txt" ]'

# --- --to ---
reset
"$SEND" dir user_upload/bilder --to test/bilder --run >/dev/null 2>&1
ok "--to ohne Slash: Pfad des Objekts selbst" '[ -f "$RFA/test/bilder/a.jpg" ] && [ ! -e "$RFA/user_upload" ]'
"$SEND" dir user_upload/bilder --to test2/ --run >/dev/null 2>&1
ok "--to mit Slash: in den Ordner hinein" '[ -f "$RFA/test2/bilder/a.jpg" ]'
"$SEND" dir root.txt --to dateiname --run >/dev/null 2>&1
ok "--to bei Datei: Datei mit diesem Namen" '[ "$(content "$RFA/dateiname")" = r ]'
OUT=$("$SEND" dir --to test/ --run 2>&1); RC=$?
ok "--to ohne Unterpfad: Fehler mit Hinweis" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "nur zusammen mit einem Unterpfad"'
OUT=$("$SEND" dir user_upload --to ../x --run 2>&1); RC=$?
ok "--to mit ..: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "\.\."'
ok "..-Unterpfad: Fehler" '! "$SEND" dir ../x --run >/dev/null 2>&1'
rm -rf "$LFA/geholt"
"$FETCH" dir test/bilder --to geholt --run >/dev/null 2>&1
ok "fetch --to: lokale Zielseite im fileadmin" '[ -f "$LFA/geholt/a.jpg" ]'

# --- Config-Pruefung ---
OUT=$("$SEND" nofa --run 2>&1); RC=$?
ok "keine fileadmin-Schluessel: Fehler mit Config-Hinweis" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "LOCAL_FILEADMIN_DIR und REMOTE_FILEADMIN_DIR" && echo "$OUT" | grep -q "sync_nofa.conf"'
OUT=$("$SEND" halbfa --run 2>&1); RC=$?
ok "nur ein Schluessel: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "LOCAL_FILEADMIN_DIR und REMOTE_FILEADMIN_DIR"'
printf 'REMOTE_BASE_DIR="%s"\nLOCAL_FILEADMIN_DIR="../x"\nREMOTE_FILEADMIN_DIR="a"\n' "$T/other" > "$TOOLS/conf/sync_dotdot.conf"
ok "ungueltiger Schluessel (..): Fehler" '! "$SEND" dotdot --run >/dev/null 2>&1'
reset; rm -rf "$LFA"
OUT=$("$SEND" dir --run 2>&1); RC=$?
ok "lokaler fileadmin fehlt: Abbruch" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "existiert nicht" && [ ! -e "$RFA/root.txt" ]'
reset; rm -rf "$RFA"
OUT=$("$SEND" dir --run 2>&1); RC=$?
ok "entfernter fileadmin fehlt: Abbruch, nichts angelegt" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "existiert nicht" && [ ! -e "$RFA" ]'
ok "unbekannte Gegenstelle: Fehler" '! "$SEND" gibtsnicht --run >/dev/null 2>&1'
OUT=$("$SEND" dir --foo 2>&1); RC=$?
ok "unbekannte Option: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "Unbekannte Option"'

# --- --mirror: Komplettuebernahme ---
reset
mkdir -p "$RFA/_processed_" "$RFA/_temp_" "$RFA/user_upload"; echo alt > "$RFA/_processed_/alt.jpg"; echo keep > "$RFA/_temp_/k.txt"; echo weg > "$RFA/user_upload/alt.txt"
"$SEND" extra --mirror --run >/dev/null 2>&1; RC=$?
ok "--mirror: processed uebertragen, Ueberzaehliges (auch in _processed_) geloescht" '[ $RC -eq 0 ] && [ -f "$RFA/_processed_/p.jpg" ] && [ ! -e "$RFA/_processed_/alt.jpg" ] && [ ! -e "$RFA/user_upload/alt.txt" ] && [ -f "$RFA/root.txt" ]'
ok "--mirror: _temp_/_recycler_ und EXTRA_EXCLUDES bleiben aus" '[ -f "$RFA/_temp_/k.txt" ] && [ ! -e "$RFA/_temp_/t.txt" ] && [ ! -e "$RFA/_recycler_" ] && [ ! -e "$RFA/geheim" ]'
OUT=$("$SEND" dir user_upload --mirror --run 2>&1); RC=$?
ok "--mirror mit Unterpfad: Fehler" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "ohne Unterpfad"'
ok "--mirror mit --all: Fehler" '! "$SEND" dir --mirror --all --run >/dev/null 2>&1'
ok "--mirror mit --to: Fehler" '! "$SEND" dir --mirror --to x --run >/dev/null 2>&1'
ok "sync-send kennt --mirror nicht" '! "$TOOLS/sync/sync-send.sh" dir x --mirror >/dev/null 2>&1'
ok "Hilfe nennt --mirror als Option fuer Komplettuebernahme" '"$SEND" 2>&1 | grep -q "sinnvolle Option, wenn das komplette System"'

# --- --all gibt es nur bei t3 ---
ok "sync-send kennt --all nicht" '! "$TOOLS/sync/sync-send.sh" dir x --all >/dev/null 2>&1'

# --- Tabelle und Hilfe ---
OUT=$("$SEND" 2>&1); RC=$?
ok "ohne Argumente: Tabelle mit Spalte fileadmin plus t3-Hilfe" '[ $RC -eq 0 ] && echo "$OUT" | grep -qE "^Name +Ziel +fileadmin +Datei" && echo "$OUT" | grep -q "t3-fs-send <server> \[unterpfad\]"'
ok "Tabelle: ja/nein je nach Config" 'echo "$OUT" | grep -E "^dir " | grep -q " ja " && echo "$OUT" | grep -E "^nofa " | grep -q " nein " && echo "$OUT" | grep -E "^halbfa " | grep -q " nein "'
OUT=$("$FETCH" --configs 2>&1); RC=$?
ok "--configs: Tabelle, keine Hilfe" '[ $RC -eq 0 ] && echo "$OUT" | grep -qE "^Name +Ziel +fileadmin" && ! echo "$OUT" | grep -q "t3-fs-fetch <server>"'
ok "fetch-Hilfe nennt t3-fs-fetch" '"$FETCH" 2>&1 | grep -q "t3-fs-fetch <server>"'

# --- SSH-Modus (Stub): Basis ist das Home der Gegenstelle ---
export PATH="$T/stubs:$PATH"
reset
"$SEND" ssh user_upload --run >/dev/null 2>&1
ok "SSH send: unter REMOTE_FILEADMIN_DIR im Home der Gegenstelle" '[ -f "$T/remote/www/fileadmin/user_upload/bilder/a.jpg" ]'
OUT=$("$SEND" ssh --dry-run 2>&1)
ok "SSH: fehlt entfernter fileadmin nicht, Dry-Run zeigt Host" 'echo "$OUT" | grep -q "stubhost:~/www/fileadmin"' 
rm -rf "$T/remote/www"; mkdir -p "$T/remote"
OUT=$("$SEND" ssh --run 2>&1); RC=$?
ok "SSH: entfernter fileadmin fehlt -> Abbruch" '[ $RC -ne 0 ] && echo "$OUT" | grep -q "existiert nicht"'

rm -rf "$T"; exit $PASSFAIL

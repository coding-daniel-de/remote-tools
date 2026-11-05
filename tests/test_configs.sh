#!/bin/bash
# Tests fuer Config finden/laden/pruefen und die Tabelle (sync-lib.sh, sync-configs.sh).
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
TOOLS="$T/tools"
CMD="$TOOLS/sync/sync-configs.sh"
# Aufruf der Lib in frischer Shell: lib "<befehl>"
lib() { bash -c "source '$TOOLS/sync/sync-lib.sh'; $1" 2>&1; }

ssh_conf()   { printf 'SSH_HOST="%s"\n' "$1" > "$2"; }
dir_conf()   { printf 'REMOTE_BASE_DIR="%s"\n' "$1" > "$2"; }

# --- Finden ---
ssh_conf live "$TOOLS/conf/sync_a.conf"
ok "nur in conf/: gefunden" '[ "$(lib "sync_find_conf a")" = "$TOOLS/conf/sync_a.conf" ]'
ssh_conf live "$TOOLS/sync_b.conf"
ok "nur im Root: gefunden" '[ "$(lib "sync_find_conf b")" = "$TOOLS/sync_b.conf" ]'
ssh_conf live "$TOOLS/conf/sync_c.conf"; ssh_conf alt "$TOOLS/sync_c.conf"
ok "in beiden: conf/ gewinnt" '[ "$(lib "sync_find_conf c")" = "$TOOLS/conf/sync_c.conf" ]'
ok "in beiden: geladener Host kommt aus conf/" '[ "$(lib "sync_load_conf c; echo \$SSH_HOST")" = "live" ]'
ok "in beiden: Doppelung wird gemeldet" '[ "$(lib "sync_load_conf c; echo \$SYNC_CONF_DUPLICATE")" = "$TOOLS/sync_c.conf" ]'
ok "Laden liefert verwendete Datei" '[ "$(lib "sync_load_conf b; echo \$SYNC_CONF_FILE")" = "$TOOLS/sync_b.conf" ]'

# --- Namen ---
ok "Name mit / abgelehnt" '! lib "sync_find_conf ../x" >/dev/null'
ok "Name mit / meldet Fehler" 'lib "sync_load_conf ../x" | grep -q "Ungültiger Name"'
ok "Name mit Leerzeichen abgelehnt" '! lib "sync_find_conf \"a b\"" >/dev/null'
ok "Unbekannter Name: Fehler mit Vorlagen-Hinweis" 'lib "sync_load_conf gibtsnicht" | grep -q "sync_template.conf"'
ok "template ist keine Gegenstelle" '! lib "sync_find_conf template" >/dev/null'

# --- Validierung ---
printf '# leer\n' > "$TOOLS/conf/sync_leer.conf"
ok "weder SSH_HOST noch REMOTE_BASE_DIR: Fehler" 'lib "sync_load_conf leer" | grep -q "weder SSH_HOST noch REMOTE_BASE_DIR"'
ok "weder SSH_HOST noch REMOTE_BASE_DIR: Exit 1" '! lib "sync_load_conf leer" >/dev/null'
dir_conf "var/www" "$TOOLS/conf/sync_rel.conf"
ok "ohne SSH nicht absolut: Fehler" 'lib "sync_load_conf rel" | grep -q "absoluter Pfad"'
dir_conf "~/stage" "$TOOLS/conf/sync_tilde.conf"
ok "Tilde: Fehler mit Hinweis" 'lib "sync_load_conf tilde" | grep -q "Tilde"'
printf 'SSH_HOST="x"\nREMOTE_BASE_DIR="~/stage"\n' > "$TOOLS/conf/sync_tilde2.conf"
ok "Tilde auch mit SSH: Fehler" '! lib "sync_load_conf tilde2" >/dev/null'
printf 'SSH_HOST="x"\nREMOTE_BASE_DIR="relativ"\n' > "$TOOLS/conf/sync_sshrel.conf"
ok "mit SSH ist relativ erlaubt" 'lib "sync_load_conf sshrel" >/dev/null'
dir_conf "/var/www/dev" "$TOOLS/conf/sync_dev.conf"
ok "Ordner-Config mit absolutem Pfad gueltig" 'lib "sync_load_conf dev" >/dev/null'

# --- Tabelle ---
rm -f "$TOOLS"/conf/sync_*.conf "$TOOLS"/sync_*.conf; cp "$REPO/conf/sync_template.conf" "$TOOLS/conf/"
OUT=$("$CMD"); RC=$?
ok "leerer Ordner: Hinweis mit cp-Befehl" 'echo "$OUT" | grep -q "cp .*sync_template.conf .*sync_<name>.conf"'
ok "leerer Ordner: Exit 0" '[ $RC -eq 0 ]'
ok "Vorlage wird nicht gelistet" '! echo "$OUT" | grep -q "^template"'

ssh_conf projekt-live "$TOOLS/conf/sync_projekt-live.conf"
dir_conf /var/www/dev "$TOOLS/conf/sync_projekt-dev.conf"
OUT=$("$CMD")
ok "Tabelle: Kopfzeile" 'echo "$OUT" | head -1 | grep -qE "^Name +Ziel +Datei$"'
ok "Tabelle: SSH-Config" 'echo "$OUT" | grep -qE "^projekt-live +SSH: projekt-live +$TOOLS/conf/sync_projekt-live.conf$"'
ok "Tabelle: Ordner-Config" 'echo "$OUT" | grep -qE "^projekt-dev +Ordner: /var/www/dev +$TOOLS/conf/sync_projekt-dev.conf$"'
ok "Tabelle: Vorlage fehlt weiterhin" '! echo "$OUT" | grep -q template'

dir_conf "~/x" "$TOOLS/conf/sync_kaputt.conf"
OUT=$("$CMD")
ok "kaputte Config erscheint mit FEHLER" 'echo "$OUT" | grep -qE "^kaputt +FEHLER: .*Tilde"'
ok "kaputte Config: Exit 0 und andere Zeilen bleiben" '"$CMD" >/dev/null && echo "$OUT" | grep -q "^projekt-live"'

ssh_conf alt "$TOOLS/sync_projekt-live.conf"; ssh_conf nurroot "$TOOLS/sync_rootonly.conf"
OUT=$("$CMD")
ok "Doppelung: conf/ gewinnt in der Tabelle" 'echo "$OUT" | grep -qE "^projekt-live +SSH: projekt-live +$TOOLS/conf/"'
ok "Doppelung: Root-Datei als doppelt/veraltet" 'echo "$OUT" | grep -E "^projekt-live +doppelt/veraltet" | grep -q "$TOOLS/sync_projekt-live.conf"'
ok "nur im Root: normal gelistet" 'echo "$OUT" | grep -qE "^rootonly +SSH: nurroot +$TOOLS/sync_rootonly.conf$"'

# fileadmin-Spalte
printf 'SSH_HOST="x"\nLOCAL_FILEADMIN_DIR="public/fileadmin"\nREMOTE_FILEADMIN_DIR="public/fileadmin"\n' > "$TOOLS/conf/sync_fa.conf"
OUT=$(lib "sync_print_configs 1")
ok "fileadmin-Spalte: ja bei beiden gesetzt" 'echo "$OUT" | grep -E "^fa " | grep -qE " ja "'
ok "fileadmin-Spalte: nein bei ungesetzt" 'echo "$OUT" | grep -E "^projekt-dev " | grep -qE " nein "'
ok "ohne Parameter keine fileadmin-Spalte" '! "$CMD" | head -1 | grep -q fileadmin'
ok "Unbekannter Parameter: Fehler" '! "$CMD" --foo >/dev/null 2>&1'

rm -rf "$T"
exit $PASSFAIL

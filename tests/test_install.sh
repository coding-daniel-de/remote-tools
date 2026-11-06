#!/bin/bash
# Tests fuer install.sh (Symlinks ohne Endung, Konflikte, Wiederholbarkeit, bashrc, PATH-Eintrag).
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
B="$T/bin"
H="$T/home"; mkdir -p "$H"; : > "$H/.bashrc"
run() { ( HOME="$H" "$REPO/install.sh" "$@" ) >"$T/out" 2>&1; }

run "$B" </dev/null; rc=$?
ok "install: Exit 0, fuenf Symlinks mit absolutem Ziel" "[ $rc -eq 0 ] && [ \"\$(readlink $B/sync-send)\" = '$REPO/sync/sync-send.sh' ] && [ \"\$(readlink $B/sync-fetch)\" = '$REPO/sync/sync-fetch.sh' ] && [ \"\$(readlink $B/sync-configs)\" = '$REPO/sync/sync-configs.sh' ] && [ \"\$(readlink $B/t3-fs-send)\" = '$REPO/t3/t3-fs-send.sh' ] && [ \"\$(readlink $B/t3-fs-fetch)\" = '$REPO/t3/t3-fs-fetch.sh' ]"
ok "install: Symlinks ohne Dateiendung, Ziele ausfuehrbar" "[ \$(ls $B | wc -l) -eq 5 ] && [ -x $B/sync-send ] && [ -x $B/t3-fs-fetch ]"
ok "install: source-Zeile in der bashrc" "grep -qF 'source \"$REPO/remote-aliases.sh\"' $H/.bashrc"
ok "install: PATH-Hinweis, wenn Zielordner nicht im PATH" "grep -q 'liegt nicht im PATH' $T/out"
run "$B" </dev/null; rc=$?
ok "install: zweiter Lauf ok, nichts zu tun" "[ $rc -eq 0 ] && [ \"\$(grep -c 'Schon vorhanden' $T/out)\" -eq 5 ] && [ \"\$(grep -c 'remote-aliases.sh' $H/.bashrc)\" -eq 1 ]"

# --- Konflikte: nichts ueberschreiben, nichts halb installieren, bashrc unberuehrt ---
B2="$T/bin2"; H2="$T/home2"; mkdir -p "$B2" "$H2"; : > "$H2/.bashrc"; echo fremd > "$B2/t3-fs-send"
( HOME="$H2" "$REPO/install.sh" "$B2" </dev/null ) >"$T/out" 2>&1; rc=$?
ok "install: fremde Datei -> Abbruch, unveraendert, nichts angelegt, bashrc leer" "[ $rc -ne 0 ] && [ \"\$(cat $B2/t3-fs-send)\" = fremd ] && [ ! -e $B2/sync-send ] && [ ! -s $H2/.bashrc ] && grep -q 't3-fs-send' $T/out"
B3="$T/bin3"; mkdir -p "$B3"; ln -s /bin/true "$B3/sync-fetch"
( HOME="$H2" "$REPO/install.sh" "$B3" </dev/null ) >"$T/out" 2>&1; rc=$?
ok "install: Symlink woandershin -> Abbruch, unveraendert" "[ $rc -ne 0 ] && [ \"\$(readlink $B3/sync-fetch)\" = /bin/true ] && [ ! -e $B3/sync-send ]"

# --- PATH ---
H4="$T/home4"; mkdir -p "$H4"; : > "$H4/.bashrc"
( HOME="$H4" "$REPO/install.sh" --path "$H4/bin" ) >"$T/out" 2>&1; rc=$?
ok "install --path: bashrc-Eintrag mit \$HOME" "[ $rc -eq 0 ] && grep -qxF 'export PATH=\"\$HOME/bin:\$PATH\"' $H4/.bashrc"
( HOME="$H4" "$REPO/install.sh" --path "$H4/bin" ) >"$T/out" 2>&1
ok "install --path: zweiter Lauf traegt nicht doppelt ein" "[ \"\$(grep -c '^export PATH' $H4/.bashrc)\" -eq 1 ]"
H5="$T/home5"; mkdir -p "$H5"; : > "$H5/.bashrc"
( HOME="$H5" "$REPO/install.sh" "$H5/bin" </dev/null ) >"$T/out" 2>&1
ok "install: ohne Terminal und ohne --path bleibt der PATH unveraendert" "! grep -q '^export PATH' $H5/.bashrc && grep -q 'liegt nicht im PATH' $T/out"
( HOME="$H5" PATH="$H5/bin:$PATH" "$REPO/install.sh" "$H5/bin" </dev/null ) >"$T/out" 2>&1
ok "install: kein PATH-Hinweis, wenn Zielordner im PATH" "! grep -q 'liegt nicht im PATH' $T/out"

# --- Aufruf ueber Symlink findet Lib und Config ---
mkdir -p "$T/real"; cp -r "$REPO/sync" "$REPO/t3" "$T/real/"; mkdir -p "$T/real/conf"
printf 'REMOTE_BASE_DIR="%s"\n' "$T" > "$T/real/conf/sync_x.conf"
mkdir -p "$T/lb"; ln -s "$T/real/sync/sync-configs.sh" "$T/lb/sync-configs"; ln -s "$T/real/t3/t3-fs-send.sh" "$T/lb/t3-fs-send"
ok "sync-configs per Symlink: Config gefunden" "( cd / && $T/lb/sync-configs ) 2>&1 | grep -q '^x '"
ok "t3-fs-send per Symlink: Lib und Config gefunden, Tabelle mit fileadmin" "( cd / && $T/lb/t3-fs-send ) 2>&1 | grep -qE '^Name +Ziel +fileadmin'"
rm -rf "$T"; exit $PASSFAIL

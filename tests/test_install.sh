#!/bin/bash
# Tests fuer install.sh (Symlinks ohne Endung, Konflikte, Wiederholbarkeit, bashrc, PATH-Eintrag).
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
B="$T/bin"
H="$T/home"; mkdir -p "$H"; : > "$H/.bashrc"
run() { ( HOME="$H" "$REPO/install.sh" "$@" ) >"$T/out" 2>&1; }

run --path "$B" </dev/null; rc=$?
ok "install: Exit 0, fuenf Symlinks mit absolutem Ziel" "[ $rc -eq 0 ] && [ \"\$(readlink $B/sync-send)\" = '$REPO/sync/sync-send.sh' ] && [ \"\$(readlink $B/sync-fetch)\" = '$REPO/sync/sync-fetch.sh' ] && [ \"\$(readlink $B/sync-configs)\" = '$REPO/sync/sync-configs.sh' ] && [ \"\$(readlink $B/t3-fs-send)\" = '$REPO/t3/t3-fs-send.sh' ] && [ \"\$(readlink $B/t3-fs-fetch)\" = '$REPO/t3/t3-fs-fetch.sh' ]"
ok "install: Symlinks ohne Dateiendung, Ziele ausfuehrbar" "[ \$(ls $B | wc -l) -eq 5 ] && [ -x $B/sync-send ] && [ -x $B/t3-fs-fetch ]"
ok "install: source-Zeile in der bashrc" "grep -qF 'source \"$REPO/remote-aliases.sh\"' $H/.bashrc"
ok "install: PATH-Eintrag, wenn Zielordner nicht im PATH (--path)" "grep -q '^export PATH' $H/.bashrc"
run --path "$B" </dev/null; rc=$?
ok "install: zweiter Lauf ok, nichts zu tun" "[ $rc -eq 0 ] && [ \"\$(grep -c 'Schon vorhanden' $T/out)\" -eq 5 ] && [ \"\$(grep -c 'remote-aliases.sh' $H/.bashrc)\" -eq 1 ]"

# --- Konflikte: nichts ueberschreiben, nichts halb installieren, bashrc unberuehrt ---
B2="$T/bin2"; H2="$T/home2"; mkdir -p "$B2" "$H2"; : > "$H2/.bashrc"; echo fremd > "$B2/t3-fs-send"
( HOME="$H2" "$REPO/install.sh" --path "$B2" </dev/null ) >"$T/out" 2>&1; rc=$?
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

# --- Optionen: ueberall erlaubt, unbekannte = Fehler ---
H6="$T/home6"; mkdir -p "$H6"; : > "$H6/.bashrc"
( HOME="$H6" "$REPO/install.sh" "$H6/bin" --path ) >"$T/out" 2>&1; rc=$?
ok "install: --path auch nach dem Zielordner erkannt" "[ $rc -eq 0 ] && grep -q '^export PATH' $H6/.bashrc"
( HOME="$H6" "$REPO/install.sh" --foo ) >"$T/out" 2>&1; rc=$?
ok "install: unbekannte Option -> Fehler, nichts angelegt" "[ $rc -ne 0 ] && grep -q 'Unbekannte Option' $T/out && [ ! -e ./--foo ] && [ ! -e $H6/--foo ]"
( HOME="$H6" "$REPO/install.sh" a b ) >"$T/out" 2>&1; rc=$?
ok "install: zwei Zielordner -> Fehler" "[ $rc -ne 0 ] && grep -q 'Unerwarteter Parameter' $T/out"

# --- Aufruf ueber Symlink findet Lib und Config ---
mkdir -p "$T/real"; cp -r "$REPO/sync" "$REPO/t3" "$T/real/"; mkdir -p "$T/real/conf"
printf 'REMOTE_BASE_DIR="%s"\n' "$T" > "$T/real/conf/sync_x.conf"
mkdir -p "$T/lb"; ln -s "$T/real/sync/sync-configs.sh" "$T/lb/sync-configs"; ln -s "$T/real/t3/t3-fs-send.sh" "$T/lb/t3-fs-send"
ok "sync-configs per Symlink: Config gefunden" "( cd / && $T/lb/sync-configs ) 2>&1 | grep -q '^x '"
ok "t3-fs-send per Symlink: Lib und Config gefunden, Tabelle mit fileadmin" "( cd / && $T/lb/t3-fs-send ) 2>&1 | grep -qE '^Name +Ziel +fileadmin'"
# --- Login-Kette (eigenes .bash_profile, Debian-.profile), Altbestand, Konflikt ---
mkdir -p "$T/fk"
mkhome() { H="$T/fk/$1"; rm -rf "$H"; mkdir -p "$H"; }
mkhome h1; echo 'export FOO=1' > "$H/.bash_profile"; echo '# profile' > "$H/.profile"
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" --path "$H/bin" ) >"$T/out" 2>&1; rc=$?
ok "install: .bash_profile ohne bashrc-Einbindung bekommt die Zeile, Login findet Befehl" "[ $rc -eq 0 ] && [ \"\$(grep -c 'bashrc' $H/.bash_profile)\" -eq 1 ] && [ \"\$(cat $H/.profile)\" = '# profile' ] && HOME=$H PATH=/usr/bin:/bin bash -l -c 'command -v sync-send' | grep -q sync-send"
cp "$H/.bash_profile" "$T/bp1"; cp "$H/.bashrc" "$T/br1"
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" --path "$H/bin" ) >"$T/out" 2>&1
ok "install: zweiter Lauf idempotent (bashrc und Login-Datei)" "cmp -s $T/bp1 $H/.bash_profile && cmp -s $T/br1 $H/.bashrc"
mkhome h2; printf 'if [ -n "$BASH_VERSION" ]; then\n    if [ -f "$HOME/.bashrc" ]; then\n        . "$HOME/.bashrc"\n    fi\nfi\n' > "$H/.profile"; cp "$H/.profile" "$T/p2"
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" --path "$H/bin" ) >"$T/out" 2>&1
ok "install: Debian-.profile bindet bashrc ein, bleibt unveraendert" "cmp -s $T/p2 $H/.profile"
mkhome h3
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" "$H/bin" </dev/null ) >"$T/out" 2>&1
ok "install: ohne Terminal und ohne --path nur Hinweis, keine Dateien, Symlinks da" "[ ! -e $H/.bashrc ] && [ ! -e $H/.profile ] && [ -L $H/bin/sync-send ] && grep -q 'export PATH' $T/out"
mkhome h4; printf '\n# remote-tools\n[ -f "%s" ] && source "%s"\n' "$REPO/remote-aliases.sh" "$REPO/remote-aliases.sh" > "$H/.bashrc"
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" --path "$H/bin" ) >"$T/out" 2>&1
ok "install: alte source-Zeile in der bashrc -> kein zweiter Eintrag" "[ \"\$(grep -c 'remote-aliases.sh' $H/.bashrc)\" -eq 1 ] && [ \"\$(grep -c '^# remote-tools' $H/.bashrc)\" -eq 1 ]"
mkhome h5; : > "$H/.bashrc"; mkdir -p "$H/bin"; echo fremd > "$H/bin/sync-send"
( HOME="$H" PATH=/usr/bin:/bin "$REPO/install.sh" --path "$H/bin" ) >"$T/out" 2>&1; rc=$?
ok "install: Konflikt -> Abbruch, bashrc unberuehrt, keine Login-Datei" "[ $rc -ne 0 ] && [ ! -s $H/.bashrc ] && [ ! -e $H/.profile ]"

rm -rf "$T"; exit $PASSFAIL

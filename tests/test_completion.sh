#!/bin/bash
# Tests fuer die Tab-Vervollstaendigung in remote-aliases.sh (Funktion direkt aufrufen, ohne echtes Tab).
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
setup
TOOLS="$T/tools"
cp "$REPO/remote-aliases.sh" "$TOOLS/"
printf 'SSH_HOST="a"\n' > "$TOOLS/conf/sync_stage.conf"
printf 'SSH_HOST="b"\n' > "$TOOLS/conf/sync_live.conf"
printf 'SSH_HOST="c"\n' > "$TOOLS/sync_stagealt.conf"
comp() { # comp <cword> <wort0> <wort1> ... : Ergebnis der Vervollstaendigung
    local cw="$1"; shift
    bash -c 'source "$1"; shift; cw="$1"; shift; COMP_WORDS=("$@"); COMP_CWORD=$cw; _remote_tools_complete_sync; echo "${COMPREPLY[*]}"' _ "$TOOLS/remote-aliases.sh" "$cw" "$@"
}
ok "alle Namen (conf/ und Root, ohne Vorlage)" '[ "$(comp 1 sync-send "")" = "live stage stagealt" ]'
ok "Praefix filtert" '[ "$(comp 1 t3-fs-send st)" = "stage stagealt" ]'
ok "kein Treffer: leer" '[ -z "$(comp 1 sync-fetch xyz)" ]'
ok "Position 2: keine Vorschlaege" '[ -z "$(comp 2 sync-send stage "")" ]'
ok "Registrierung fuer alle vier Befehle" 'bash -c "source \"$TOOLS/remote-aliases.sh\"; complete -p sync-send sync-fetch t3-fs-send t3-fs-fetch" | grep -c _remote_tools_complete_sync | grep -qx 4'
ok "Laden der Datei liest keine Configs" '! grep -n "_sync_list_names" "$TOOLS/remote-aliases.sh" | grep -v "names=" | grep -q .'
rm -f "$TOOLS/conf/"sync_*.conf "$TOOLS/sync_stagealt.conf"
ok "keine Config: leere Liste" '[ -z "$(comp 1 sync-send "")" ]'
rm -rf "$T"; exit $PASSFAIL

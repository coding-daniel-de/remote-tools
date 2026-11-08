# Bindet remote-aliases.sh in die ~/.bashrc ein (idempotent), legt Symlinks ohne Endung an (sync-send,
# sync-fetch, sync-configs, t3-fs-send, t3-fs-fetch) und sorgt dafuer, dass der Zielordner im PATH liegt
# (Marker "# bin-path"). Bindet die Login-Datei, die bash beim Login liest, die ~/.bashrc nicht ein, wird die
# Zeile dafuer ergaenzt. Es wird nur ergaenzt, nie ueberschrieben. Die Hilfsfunktionen stehen in lib/shell-setup.sh.
# Nutzung: ./install.sh [--path] [ziel-ordner]    (Standard: ~/bin)
#   --path   Eintragungen in ~/.bashrc (PATH, Aliase) und bei Bedarf in die Login-Datei ohne Rueckfrage vornehmen
#            (sonst Rueckfrage im Terminal, ohne Terminal nur Hinweis).

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${DIR}/lib/shell-setup.sh" || exit 1

SS_YES=0
POS=()
for arg in "$@"; do
    case "$arg" in
        --path) SS_YES=1 ;;
        -*) echo "Fehler: Unbekannte Option '$arg'! Nutzung: ./install.sh [--path] [ziel-ordner]"; exit 1 ;;
        *) POS+=("$arg") ;;
    esac
done
if [ "${#POS[@]}" -gt 1 ]; then
    echo "Fehler: Unerwarteter Parameter '${POS[1]}'! Nutzung: ./install.sh [--path] [ziel-ordner]"
    exit 1
fi
TARGET=$(ss_abs_path "${POS[0]:-$HOME/bin}")

declare -A LINKS=(
    [sync-send]="sync/sync-send.sh"
    [sync-fetch]="sync/sync-fetch.sh"
    [sync-configs]="sync/sync-configs.sh"
    [t3-fs-send]="t3/t3-fs-send.sh"
    [t3-fs-fetch]="t3/t3-fs-fetch.sh"
)
NAMES=(sync-send sync-fetch sync-configs t3-fs-send t3-fs-fetch)

# Erst alles pruefen, damit bei einem Konflikt nichts halb installiert wird (auch die bashrc bleibt dann unberuehrt)
for name in "${NAMES[@]}"; do
    link="${TARGET}/${name}"
    source_file="${DIR}/${LINKS[$name]}"
    if [ -e "$link" ] || [ -L "$link" ]; then
        if [ ! -L "$link" ] || [ "$(readlink -f "$link")" != "$source_file" ]; then
            echo "Fehler: '$link' existiert bereits und ist kein Symlink auf '$source_file'. Es wurde nichts geändert!"
            exit 1
        fi
    fi
done

# Neuer Eintrag nur nach Rueckfrage (--path = ja), ohne Terminal nur Hinweis; Vorhandenes wird immer erkannt
if grep -qF "$DIR/remote-aliases.sh" "$SS_BASHRC" 2>/dev/null \
        || ss_confirm "remote-aliases.sh in $SS_BASHRC einbinden?"; then
    ss_ensure_source "$DIR/remote-aliases.sh" "remote-tools"
else
    echo "Hinweis: Aliase nicht eingebunden. Zeile fuer ~/.bashrc (oder: ./install.sh --path):"
    echo "    [ -f \"$DIR/remote-aliases.sh\" ] && source \"$DIR/remote-aliases.sh\""
fi

# --- Symlinks ---
mkdir -p "$TARGET" || exit 1
for name in "${NAMES[@]}"; do
    link="${TARGET}/${name}"
    source_file="${DIR}/${LINKS[$name]}"
    if [ -L "$link" ]; then
        echo "Schon vorhanden: $link"
    else
        ln -s "$source_file" "$link" || exit 1
        echo "Angelegt: $link -> $source_file"
    fi
done

# --- Zielordner im PATH, Login-Kette ---
ss_ensure_path "$TARGET"
ss_ensure_login_chain

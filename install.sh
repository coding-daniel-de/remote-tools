#!/bin/bash
# Traegt die source-Zeile fuer remote-aliases.sh in die ~/.bashrc ein (idempotent), legt Symlinks ohne Endung
# an (sync-send, sync-fetch, sync-configs, t3-fs-send, t3-fs-fetch) und sorgt dafuer, dass der Zielordner im
# PATH liegt (gleicher Block wie im install.sh von db-tools, Marker "# bin-path").
# Nutzung: ./install.sh [--path] [ziel-ordner]    (Standard: ~/bin)
#   --path   Zielordner ohne Rueckfrage in den PATH eintragen (sonst Rueckfrage im Terminal, ohne Terminal nur Hinweis).

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LINE="[ -f \"$DIR/remote-aliases.sh\" ] && source \"$DIR/remote-aliases.sh\""
BASHRC="$HOME/.bashrc"

ADD_PATH=0
if [ "$1" = "--path" ]; then
    ADD_PATH=1
    shift
fi
TARGET=$(realpath -m -- "${1:-$HOME/bin}")

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

if grep -qF "$DIR/remote-aliases.sh" "$BASHRC" 2>/dev/null; then
    echo "Bereits in ~/.bashrc eingetragen."
else
    printf '\n# remote-tools\n%s\n' "$LINE" >> "$BASHRC"
    echo "Eingetragen. Neue Shell oeffnen oder: source ~/.bashrc"
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

# --- Zielordner im PATH ---
case ":${PATH}:" in
    *":${TARGET}:"*) ;;
    *)
        MARKER="# bin-path: ${TARGET}"
        # Im Home-Ordner mit $HOME schreiben, damit der Eintrag auch bei verschobenem Home stimmt
        case "$TARGET" in
            "$HOME"/*) TARGET_EXPR="\$HOME/${TARGET#"$HOME"/}" ;;
            *)         TARGET_EXPR="$TARGET" ;;
        esac
        EXPORT_LINE="export PATH=\"${TARGET_EXPR}:\$PATH\""
        echo
        if [ -f "$BASHRC" ] && grep -qxF "$MARKER" "$BASHRC"; then
            echo "'$TARGET' ist schon in $BASHRC eingetragen, gilt ab der naechsten Shell (oder: source ~/.bashrc)."
        else
            DO_ADD=$ADD_PATH
            if [ "$DO_ADD" -eq 0 ] && [ -t 0 ]; then
                read -r -n 1 -p "'$TARGET' liegt nicht im PATH. In $BASHRC eintragen? (y/N) " answer
                [ -n "$answer" ] && echo
                [[ "$answer" =~ ^[yY]$ ]] && DO_ADD=1
            fi
            if [ "$DO_ADD" -eq 1 ]; then
                printf '\n%s\n%s\n' "$MARKER" "$EXPORT_LINE" >> "$BASHRC" || exit 1
                echo "Eingetragen in $BASHRC, gilt ab der naechsten Shell (oder: source ~/.bashrc)."
            else
                echo "Hinweis: '$TARGET' liegt nicht im PATH. Zeile fuer ~/.bashrc (oder: ./install.sh --path):"
                echo "    $EXPORT_LINE"
            fi
        fi
        ;;
esac

#!/bin/bash
# Traegt die source-Zeile fuer remote-aliases.sh in die ~/.bashrc ein (idempotent) und sorgt dafuer,
# dass ~/bin im PATH liegt (gleicher Block wie im install.sh von db-tools, Marker "# bin-path").
# Nutzung: ./install.sh [--path]
#   --path   ~/bin ohne Rueckfrage in den PATH eintragen (sonst Rueckfrage im Terminal, ohne Terminal nur Hinweis).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINE="[ -f \"$DIR/remote-aliases.sh\" ] && source \"$DIR/remote-aliases.sh\""
BASHRC="$HOME/.bashrc"

ADD_PATH=0
[ "$1" = "--path" ] && ADD_PATH=1

if grep -qF "$DIR/remote-aliases.sh" "$BASHRC" 2>/dev/null; then
    echo "Bereits in ~/.bashrc eingetragen."
else
    printf '\n# remote-tools\n%s\n' "$LINE" >> "$BASHRC"
    echo "Eingetragen. Neue Shell oeffnen oder: source ~/.bashrc"
fi

# --- ~/bin im PATH ---
TARGET="$HOME/bin"
case ":${PATH}:" in
    *":${TARGET}:"*) ;;
    *)
        MARKER="# bin-path: ${TARGET}"
        EXPORT_LINE='export PATH="$HOME/bin:$PATH"'
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
                mkdir -p "$TARGET" || exit 1
                printf '\n%s\n%s\n' "$MARKER" "$EXPORT_LINE" >> "$BASHRC" || exit 1
                echo "Eingetragen in $BASHRC, gilt ab der naechsten Shell (oder: source ~/.bashrc)."
            else
                echo "Hinweis: '$TARGET' liegt nicht im PATH. Zeile fuer ~/.bashrc (oder: ./install.sh --path):"
                echo "    $EXPORT_LINE"
            fi
        fi
        ;;
esac

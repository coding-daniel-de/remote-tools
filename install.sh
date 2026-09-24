#!/bin/bash
# Traegt die source-Zeile fuer remote-aliases.sh in die ~/.bashrc ein (idempotent).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINE="[ -f \"$DIR/remote-aliases.sh\" ] && source \"$DIR/remote-aliases.sh\""

if grep -qF "$DIR/remote-aliases.sh" ~/.bashrc 2>/dev/null; then
    echo "Bereits in ~/.bashrc eingetragen."
else
    printf '\n# remote-tools\n%s\n' "$LINE" >> ~/.bashrc
    echo "Eingetragen. Neue Shell oeffnen oder: source ~/.bashrc"
fi

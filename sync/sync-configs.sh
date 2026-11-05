#!/bin/bash
# Zeigt alle Gegenstellen (sync_<name>.conf) als Tabelle.
# Nutzung: sync-configs.sh

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$DIR/sync-lib.sh"

if [ $# -gt 0 ]; then
    echo "Fehler: Unbekannte Option oder Parameter '$1'!" >&2
    echo "Nutzung: sync-configs.sh" >&2
    exit 1
fi

sync_print_configs

#!/bin/bash
# Schickt den TYPO3-fileadmin (oder einen Unterordner) per rsync zur Gegenstelle.
# Dünne TYPO3-Schicht über dem sync-Kern: fileadmin als Wurzel, feste Excludes (_processed_/, _temp_/, _recycler_/).
#
# Nutzung: t3-fs-send.sh <server> [unterpfad] [--to <ziel>] [--run | --dry-run] [--delete] [--all] [--rsync-opts "<opts>"] [--configs]
# Details: t3-fs-send.sh ohne Argumente zeigt Tabelle und Hilfe.

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$DIR/../sync/sync-lib.sh"

SYNC_T3=1
sync_transfer_main send "$@"
exit $?

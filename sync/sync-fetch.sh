#!/bin/bash
# Holt eine Datei oder einen Ordner per rsync von der Gegenstelle.
# Gegenstelle = Name einer conf/sync_<name>.conf (SSH-Alias oder Ordner auf demselben Server).
# <pfad> ist relativ zu ~ und gilt auf beiden Seiten gleich (Spiegel-Prinzip). Standard: Dry-Run, dann Rueckfrage.
#
# Nutzung: sync-fetch.sh <server> <pfad> [--to <ziel>] [--run | --dry-run] [--delete] [--rsync-opts "<opts>"] [--configs]
#
# Beispiele:
#   sync-fetch.sh stage notizen.txt                       Datei, Dry-Run und Rueckfrage
#   sync-fetch.sh stage public/fileadmin/user_upload      Ordner (Spiegel), Dry-Run und Rueckfrage
#   sync-fetch.sh stage notizen.txt --to backup/          in den Ordner backup/ hinein (Slash am Ende)
#   sync-fetch.sh stage notizen.txt --to backup/alt.txt   anderer Name/Pfad auf der Zielseite
#   sync-fetch.sh stage ordner --dry-run                  nur Liste, nichts aendern, keine Rueckfrage
#   sync-fetch.sh stage ordner --run                      ohne Rueckfrage ausfuehren
#   sync-fetch.sh stage ordner --delete                   Dateien am Ziel loeschen, die in der Quelle fehlen
#   sync-fetch.sh stage ordner --rsync-opts "-rltz"       rsync-Optionen ersetzen (Standard: -rlt --partial)
#   sync-fetch.sh --configs                               Tabelle der Gegenstellen
#   sync-fetch.sh                                         Tabelle plus Hilfe
#
# --to ist der Pfad des Objekts selbst auf der Zielseite (bei send relativ zur Basis der Gegenstelle,
# bei fetch relativ zu ~). Mit Slash am Ende: in diesen Ordner hinein.

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$DIR/sync-lib.sh"

sync_transfer_main fetch "$@"
exit $?

# Gemeinsame Funktionen fuer die sync-Befehle (Configs finden, laden, pruefen, auflisten).
# Wird per source geladen, nicht direkt ausgefuehrt.
#
# Config pro Gegenstelle: sync_<name>.conf. Suchreihenfolge: conf/ im Repo-Root, dann das Repo-Root
# selbst (Uebergang). Gibt es den Namen an beiden Orten, gewinnt conf/.

SYNC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_CONF_DIR="${SYNC_ROOT}/conf"

# Alle Schluessel einer Config; vor dem Laden geleert, damit nichts aus einer frueheren Config bleibt.
_sync_reset_conf() {
    SSH_HOST=""
    REMOTE_BASE_DIR=""
    LOCAL_FILEADMIN_DIR=""
    REMOTE_FILEADMIN_DIR=""
    EXTRA_EXCLUDES=""
    RSYNC_OPTS=""
}

# sync_find_conf <name>: gibt den Pfad der verwendeten Config aus.
# Setzt SYNC_CONF_DUPLICATE auf den Pfad der verdeckten Root-Datei, wenn es den Namen auch dort gibt
# (sonst leer). Fehler (Exit 1): ungueltiger Name oder keine Config.
sync_find_conf() {
    local NAME="$1" IN_CONF IN_ROOT
    SYNC_CONF_DUPLICATE=""
    if ! [[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Fehler: Ungültiger Name '${NAME}' (erlaubt: Buchstaben, Ziffern, . _ -)!" >&2
        return 1
    fi
    if [ "$NAME" = "template" ]; then
        echo "Fehler: 'template' ist die Vorlage, keine Gegenstelle!" >&2
        return 1
    fi
    IN_CONF="${SYNC_CONF_DIR}/sync_${NAME}.conf"
    IN_ROOT="${SYNC_ROOT}/sync_${NAME}.conf"
    if [ -f "$IN_CONF" ]; then
        [ -f "$IN_ROOT" ] && SYNC_CONF_DUPLICATE="$IN_ROOT"
        echo "$IN_CONF"
    elif [ -f "$IN_ROOT" ]; then
        echo "$IN_ROOT"
    else
        echo "Fehler: Keine Config für '${NAME}' gefunden! Vorlage: cp ${SYNC_CONF_DIR}/sync_template.conf ${SYNC_CONF_DIR}/sync_${NAME}.conf" >&2
        return 1
    fi
}

# sync_validate_conf <datei>: prueft die geladenen Werte, Meldung auf Deutsch, Exit 1 bei Fehler.
_sync_validate_conf() {
    local CONF="$1"
    if [ -z "$SSH_HOST" ] && [ -z "$REMOTE_BASE_DIR" ]; then
        echo "Fehler: In '${CONF}' ist weder SSH_HOST noch REMOTE_BASE_DIR gesetzt!" >&2
        return 1
    fi
    if [[ "$REMOTE_BASE_DIR" == "~"* ]]; then
        echo "Fehler: In '${CONF}' beginnt REMOTE_BASE_DIR mit einer Tilde! Bash löst ~ in Anführungszeichen nicht auf, bitte den Pfad ohne Tilde angeben." >&2
        return 1
    fi
    if [ -z "$SSH_HOST" ] && [[ "$REMOTE_BASE_DIR" != /* ]]; then
        echo "Fehler: In '${CONF}' muss REMOTE_BASE_DIR ohne SSH_HOST ein absoluter Pfad sein (beginnt mit /)!" >&2
        return 1
    fi
}

# sync_load_conf <name>: findet, laedt (source) und prueft die Config.
# Setzt SYNC_CONF_FILE (verwendete Datei), SYNC_CONF_DUPLICATE und die Schluessel der Config.
# Exit 1 mit Fehlermeldung auf stderr.
sync_load_conf() {
    local FILE
    FILE=$(sync_find_conf "$1") || return 1
    # sync_find_conf lief in einer Subshell, die Doppelung deshalb separat bestimmen
    SYNC_CONF_DUPLICATE=""
    [ "$FILE" = "${SYNC_CONF_DIR}/sync_${1}.conf" ] && [ -f "${SYNC_ROOT}/sync_${1}.conf" ] && SYNC_CONF_DUPLICATE="${SYNC_ROOT}/sync_${1}.conf"
    SYNC_CONF_FILE="$FILE"
    _sync_reset_conf
    # shellcheck disable=SC1090
    source "$FILE" || { echo "Fehler: '${FILE}' konnte nicht geladen werden!" >&2; return 1; }
    _sync_validate_conf "$FILE"
}

# Alle Namen mit einer sync_<name>.conf in conf/ oder im Root, sortiert, ohne Vorlage.
_sync_list_names() {
    local F B
    for F in "${SYNC_CONF_DIR}"/sync_*.conf "${SYNC_ROOT}"/sync_*.conf; do
        [ -f "$F" ] || continue
        B="${F##*/}"; B="${B#sync_}"; B="${B%.conf}"
        [ "$B" = "template" ] && continue
        echo "$B"
    done | sort -u
}

# sync_print_configs [fileadmin]: Uebersichtstabelle aller Configs (Name, Ziel, Datei).
# Mit Argument 1 kommt eine Spalte "fileadmin" dazu (ja, wenn beide *_FILEADMIN_DIR gesetzt sind),
# gedacht fuer t3-fs-*. Kaputte Configs stehen mit "FEHLER: <Grund>" statt Ziel in der Tabelle,
# eine von conf/ verdeckte Root-Datei als eigene Zeile "doppelt/veraltet".
sync_print_configs() {
    local WITH_FA="${1:-0}" NAME ZIEL FA FILE ERR DUP
    local -a ROWS=()
    local W1=4 W2=4 W3=5 W4=9

    while IFS= read -r NAME; do
        [ -n "$NAME" ] || continue
        FA="nein"
        if ERR=$( (sync_load_conf "$NAME") 2>&1 >/dev/null ); then
            # in Subshell laden, damit keine Werte in die aufrufende Shell lecken
            IFS=$'\t' read -r ZIEL FA FILE DUP < <(
                sync_load_conf "$NAME" 2>/dev/null
                if [ -n "$SSH_HOST" ]; then Z="SSH: ${SSH_HOST}"; else Z="Ordner: ${REMOTE_BASE_DIR}"; fi
                F="nein"; [ -n "$LOCAL_FILEADMIN_DIR" ] && [ -n "$REMOTE_FILEADMIN_DIR" ] && F="ja"
                printf '%s\t%s\t%s\t%s\n' "$Z" "$F" "$SYNC_CONF_FILE" "$SYNC_CONF_DUPLICATE"
            )
            ROWS+=("${NAME}"$'\t'"${ZIEL}"$'\t'"${FILE}"$'\t'"${FA}")
            [ -n "$DUP" ] && ROWS+=("${NAME}"$'\t'"doppelt/veraltet (conf/ gewinnt)"$'\t'"${DUP}"$'\t'"-")
        else
            ERR="${ERR#Fehler: }"
            FILE=$(sync_find_conf "$NAME" 2>/dev/null) || FILE="-"
            ROWS+=("${NAME}"$'\t'"FEHLER: ${ERR}"$'\t'"${FILE}"$'\t'"-")
        fi
    done < <(_sync_list_names)

    if [ "${#ROWS[@]}" -eq 0 ]; then
        echo "Keine Gegenstelle konfiguriert. Neue anlegen mit:"
        echo "    cp ${SYNC_CONF_DIR}/sync_template.conf ${SYNC_CONF_DIR}/sync_<name>.conf"
        return 0
    fi

    local ROW A B C D
    for ROW in "${ROWS[@]}"; do
        IFS=$'\t' read -r A B C D <<< "$ROW"
        [ ${#A} -gt $W1 ] && W1=${#A}
        [ ${#B} -gt $W2 ] && W2=${#B}
        [ ${#C} -gt $W3 ] && W3=${#C}
    done
    if [ "$WITH_FA" = "1" ]; then
        printf "%-${W1}s  %-${W2}s  %-9s  %s\n" "Name" "Ziel" "fileadmin" "Datei"
    else
        printf "%-${W1}s  %-${W2}s  %s\n" "Name" "Ziel" "Datei"
    fi
    for ROW in "${ROWS[@]}"; do
        IFS=$'\t' read -r A B C D <<< "$ROW"
        if [ "$WITH_FA" = "1" ]; then
            printf "%-${W1}s  %-${W2}s  %-9s  %s\n" "$A" "$B" "$D" "$C"
        else
            printf "%-${W1}s  %-${W2}s  %s\n" "$A" "$B" "$C"
        fi
    done
}

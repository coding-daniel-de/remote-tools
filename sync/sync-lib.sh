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

# ---------------------------------------------------------------------------------------------
# Teil 2: Pfadauflösung, Argumente, Ausführung (sync_run)
# ---------------------------------------------------------------------------------------------

SYNC_DEFAULT_RSYNC_OPTS="-rlt --partial"

# _sync_norm_path <pfad> [leer-erlaubt]: Pfad relativ zu ~ normalisieren (gibt ihn auf stdout aus).
# Schneidet ~/ und $HOME/ am Anfang ab, entfernt //, ./ und den Slash am Ende. Fehler (Exit 1):
# ".." im Pfad, absoluter Pfad ausserhalb des Home, leerer Pfad (= ganzes Home), ausser Argument 2 = 1.
_sync_norm_path() {
    local P="$1" ALLOW_EMPTY="${2:-0}" PART OUT=""
    case "$P" in
        "~")        P="" ;;
        "~/"*)      P="${P#"~/"}" ;;
        '$HOME')    P="" ;;
        '$HOME/'*)  P="${P#'$HOME/'}" ;;
        "$HOME")    P="" ;;
        "$HOME/"*)  P="${P#"$HOME/"}" ;;
        /*)
            echo "Fehler: Absoluter Pfad '${1}' liegt nicht im Home (${HOME})! Pfade sind relativ zu ~ anzugeben." >&2
            return 1 ;;
    esac
    local -a PARTS
    IFS='/' read -ra PARTS <<< "$P"
    for PART in "${PARTS[@]}"; do
        case "$PART" in
            ""|".") ;;
            "..")
                echo "Fehler: '..' im Pfad '${1}' ist nicht erlaubt!" >&2
                return 1 ;;
            *) OUT="${OUT:+$OUT/}${PART}" ;;
        esac
    done
    if [ -z "$OUT" ] && [ "$ALLOW_EMPTY" != "1" ]; then
        echo "Fehler: Der Pfad '${1}' wäre das ganze Home/die ganze Basis! Bitte einen Unterpfad angeben." >&2
        return 1
    fi
    printf '%s' "$OUT"
}

# _sync_remote_join <relativer-pfad>: Pfad auf der Gegenstelle (Basis davor, wenn gesetzt).
_sync_remote_join() {
    if [ -n "$REMOTE_BASE_DIR" ]; then
        printf '%s/%s' "${REMOTE_BASE_DIR%/}" "$1"
    else
        printf '%s' "$1"
    fi
}

# sync_parse_transfer_args "$@": wertet die Argumente von sync-send/sync-fetch aus.
# Setzt P_SERVER, P_PATH, P_TO, P_TO_SET, P_MODE (ask|run|dry), P_DELETE, P_RSYNC_OPTS,
# P_RSYNC_OPTS_SET, P_CONFIGS, P_ALL, P_MIRROR (beide nur mit SYNC_T3=1). Fehler: Meldung auf stderr, Exit 1.
sync_parse_transfer_args() {
    P_SERVER=""; P_PATH=""; P_TO=""; P_TO_SET=0; P_MODE="ask"; P_DELETE=0
    P_RSYNC_OPTS=""; P_RSYNC_OPTS_SET=0; P_CONFIGS=0; P_ALL=0; P_MIRROR=0
    local MODE_SET=0
    local -a POS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --to|--rsync-opts)
                if [ $# -lt 2 ]; then echo "Fehler: Option '$1' braucht einen Wert!" >&2; return 1; fi
                if [ "$1" = "--to" ]; then P_TO="$2"; P_TO_SET=1; else P_RSYNC_OPTS="$2"; P_RSYNC_OPTS_SET=1; fi
                shift 2 ;;
            --to=*)         P_TO="${1#--to=}"; P_TO_SET=1; shift ;;
            --rsync-opts=*) P_RSYNC_OPTS="${1#--rsync-opts=}"; P_RSYNC_OPTS_SET=1; shift ;;
            --run|--dry-run)
                local NEW_MODE="run"; [ "$1" = "--dry-run" ] && NEW_MODE="dry"
                if [ "$MODE_SET" = 1 ] && [ "$P_MODE" != "$NEW_MODE" ]; then echo "Fehler: --run und --dry-run schließen sich aus!" >&2; return 1; fi
                MODE_SET=1; P_MODE="$NEW_MODE"
                shift ;;
            --delete)  P_DELETE=1; shift ;;
            --configs) P_CONFIGS=1; shift ;;
            --all)
                # nur t3-fs-*: schaltet die festen Standard-Excludes ab
                if [ "${SYNC_T3:-0}" != 1 ]; then echo "Fehler: Unbekannte Option '--all'!" >&2; return 1; fi
                P_ALL=1; shift ;;
            --mirror)
                # nur t3-fs-*: Komplettuebernahme (ganzer fileadmin wie die Quelle)
                if [ "${SYNC_T3:-0}" != 1 ]; then echo "Fehler: Unbekannte Option '--mirror'!" >&2; return 1; fi
                P_MIRROR=1; shift ;;
            -*)
                echo "Fehler: Unbekannte Option '$1'!" >&2
                return 1 ;;
            *) POS+=("$1"); shift ;;
        esac
    done
    if [ "${#POS[@]}" -gt 2 ]; then
        echo "Fehler: Unerwarteter Parameter '${POS[2]}'!" >&2
        return 1
    fi
    P_SERVER="${POS[0]:-}"
    P_PATH="${POS[1]:-}"
    if [ "$P_MIRROR" = 1 ] && [ "$P_ALL" = 1 ]; then
        echo "Fehler: --mirror und --all schließen sich aus!" >&2
        return 1
    fi
    if [ "$P_MIRROR" = 1 ] && [ -n "$P_PATH" ]; then
        echo "Fehler: --mirror gilt nur für den ganzen fileadmin, ohne Unterpfad!" >&2
        return 1
    fi
    if [ "$P_MIRROR" = 1 ] && [ "$P_TO_SET" = 1 ]; then
        echo "Fehler: --mirror und --to schließen sich aus!" >&2
        return 1
    fi
    if [ "$P_TO_SET" = 1 ] && [ -z "$P_TO" ]; then
        echo "Fehler: --to braucht einen Wert!" >&2
        return 1
    fi
    return 0
}

# _sync_transfer_usage <send|fetch>: Hilfetext
_sync_transfer_usage() {
    local D="$1" VERB WOHIN
    if [ "${SYNC_T3:-0}" = 1 ]; then _sync_t3_usage "$D"; return; fi
    if [ "$D" = "send" ]; then VERB="schickt"; WOHIN="zur Gegenstelle"; else VERB="holt"; WOHIN="von der Gegenstelle"; fi
    cat <<USAGE
sync-${D} <server> <pfad> [--to <ziel>] [--run | --dry-run] [--delete] [--rsync-opts "<opts>"] [--configs]

${D^}: ${VERB} eine Datei oder einen Ordner per rsync ${WOHIN}. <server> ist der Name nach sync_ (siehe Tabelle).
<pfad> ist relativ zu ~ und gilt auf beiden Seiten gleich (Gegenstelle: relativ zu REMOTE_BASE_DIR bzw. ihrem Home).

  sync-${D} stage notizen.txt                       eine Datei, Dry-Run und Rückfrage
  sync-${D} stage public/fileadmin/user_upload      ein Ordner (Spiegel), Dry-Run und Rückfrage
  sync-${D} stage notizen.txt --to backup/          in den Ordner backup/ hinein (Slash am Ende)
  sync-${D} stage notizen.txt --to backup/alt.txt   unter anderem Namen/Pfad auf der Zielseite
  sync-${D} stage ordner --dry-run                  nur die Änderungsliste zeigen, nichts ändern
  sync-${D} stage ordner --run                      ohne Rückfrage ausführen
  sync-${D} stage ordner --delete                   auch Dateien am Ziel löschen, die in der Quelle fehlen
  sync-${D} stage ordner --rsync-opts "-rltz"       rsync-Optionen ersetzen (Standard: ${SYNC_DEFAULT_RSYNC_OPTS})
  sync-${D} --configs                               Tabelle der Gegenstellen
USAGE
}

# _sync_t3_usage <send|fetch>: Hilfetext von t3-fs-send / t3-fs-fetch
_sync_t3_usage() {
    local D="$1" VERB WOHIN
    if [ "$D" = "send" ]; then VERB="schickt"; WOHIN="zur Gegenstelle"; else VERB="holt"; WOHIN="von der Gegenstelle"; fi
    cat <<USAGE
t3-fs-${D} <server> [unterpfad] [--to <ziel>] [--run | --dry-run] [--delete] [--all | --mirror] [--rsync-opts "<opts>"] [--configs]

${D^}: ${VERB} den TYPO3-fileadmin (oder einen Unterordner) per rsync ${WOHIN}. <server> ist der Name nach sync_ (siehe Tabelle).
[unterpfad] ist relativ zum fileadmin-Root; ohne Angabe wird der komplette fileadmin synchronisiert.
Ausgeschlossen sind _processed_/, _temp_/ und _recycler_/ (mit --all nicht) sowie EXTRA_EXCLUDES aus der Config.

--mirror ist die sinnvolle Option, wenn das komplette System übernommen werden soll (z. B. Stage-DB und
fileadmin 1:1 auf Live, oder umgekehrt): ganzer fileadmin wie die Quelle (--delete), inklusive _processed_/,
damit die Dateien zu sys_file_processedfile in der übernommenen DB passen. _temp_/, _recycler_/ und
EXTRA_EXCLUDES bleiben ausgeschlossen. Nur ohne Unterpfad, nicht mit --all oder --to. Dry-Run und Rückfrage bleiben.

  t3-fs-${D} stage                                  ganzer fileadmin, Dry-Run und Rückfrage
  t3-fs-${D} stage user_upload/bilder               nur dieser Unterordner
  t3-fs-${D} stage user_upload/bilder --to test/bilder   Probelauf in einen Testordner (nur mit Unterpfad)
  t3-fs-${D} stage user_upload --dry-run            nur die Änderungsliste zeigen, nichts ändern
  t3-fs-${D} stage user_upload --run                ohne Rückfrage ausführen
  t3-fs-${D} stage user_upload --delete             auch Dateien am Ziel löschen, die in der Quelle fehlen
  t3-fs-${D} stage --all                            auch _processed_/, _temp_/ und _recycler_/ übertragen
  t3-fs-${D} stage --mirror                         Komplettübernahme: ganzer fileadmin 1:1 inkl. _processed_/, mit Löschen
  t3-fs-${D} --configs                              Tabelle der Gegenstellen (mit Spalte fileadmin)
USAGE
}

# --- Hilfsfunktionen fuer sync_run ---------------------------------------------------------

_sync_bold_red() { if [ -t 1 ]; then printf '\033[1;31m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }

# _sync_ver_ge <a> <b>: Exit 0, wenn Version a >= b
_sync_ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# _sync_ssh_cleanup: SSH-Master beenden und Socket-Ordner entfernen
_sync_ssh_cleanup() {
    if [ -n "${SYNC_SSH_DIR:-}" ]; then
        ssh -o "ControlPath=${SYNC_SSH_DIR}/c" -O exit "$SSH_HOST" >/dev/null 2>&1
        rm -rf "$SYNC_SSH_DIR"
        SYNC_SSH_DIR=""
    fi
}

# _sync_is_ssh <seite>: Exit 0, wenn die Seite "remote" ist und per SSH erreicht wird
_sync_is_ssh() { [ "$1" = "remote" ] && [ -n "$SSH_HOST" ]; }

# _sync_exec <seite> <befehl>: Befehl auf der Seite ausfuehren (remote+SSH: per ssh, sonst lokal)
_sync_exec() {
    if _sync_is_ssh "$1"; then
        ssh "${SYNC_SSH_OPTS[@]}" "$SSH_HOST" "$2"
    else
        bash -c "$2"
    fi
}

# Absoluter, bereinigter Pfad ohne realpath (fehlt auf aelteren Servern): der tiefste vorhandene Ordner wird
# physisch aufgeloest (Symlinks), der Rest lexikalisch angehaengt ("." und ".." entfernt). Ziel muss nicht existieren.
_sync_abs() {
    local p="$1" rest="" base head out part
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    while [ ! -d "$p" ] && [ "$p" != "/" ]; do
        base="${p##*/}"; p="${p%/*}"; [ -n "$p" ] || p="/"
        rest="$base${rest:+/$rest}"
    done
    head="$(cd -P -- "$p" 2>/dev/null && pwd -P)" || head="$p"
    out="$head"
    local IFS=/
    for part in $rest; do
        case "$part" in
            ""|.) ;;
            ..) out="${out%/*}"; [ -n "$out" ] || out="/" ;;
            *)  [ "$out" = "/" ] && out="/$part" || out="$out/$part" ;;
        esac
    done
    printf '%s\n' "$out"
}

# _sync_probe <seite> <pfad>: gibt dir|file|other|none aus. Exit 1 bei SSH-Fehler.
_sync_probe() {
    local CMD
    CMD=$(printf 'p=%q; if [ -d "$p" ]; then echo dir; elif [ -f "$p" ]; then echo file; elif [ -e "$p" ]; then echo other; else echo none; fi' "$2")
    _sync_exec "$1" "$CMD"
}

_sync_disp() {
    if _sync_is_ssh "$1"; then
        case "$2" in /*) printf '%s:%s' "$SSH_HOST" "$2" ;; *) printf '%s:~/%s' "$SSH_HOST" "$2" ;; esac
    else
        printf '%s' "$2"
    fi
}

_sync_spec() {
    local P="$2"
    [ "$3" = "dir" ] && P="${P%/}/"
    if _sync_is_ssh "$1"; then printf '%s:%s' "$SSH_HOST" "$P"; else printf '%s' "$P"; fi
}

# sync_run: der ganze Ablauf ab den Vorab-Checks (Pfadaufloesung macht der Aufrufer, siehe sync-send/-fetch
# und spaeter t3-fs-*). Voraussetzung: Config ist geladen (SSH_HOST, RSYNC_OPTS).
#
#   sync_run --direction send|fetch --src <pfad> --dst <pfad> [--kind auto|file|dir]
#            [--server <name>] [--run | --dry-run] [--delete] [--rsync-opts "<opts>"] [--exclude <muster>]...
#
# --direction  send: Quelle lokal, Ziel entfernt. fetch: Quelle entfernt, Ziel lokal.
# --src/--dst  fertig aufgeloeste Pfade: lokale Seite absolut; entfernte Seite absolut (Ordner-Modus ohne
#              SSH_HOST) bzw. relativ zum Home der Gegenstelle (SSH, Basis ist schon enthalten).
#              --dst ist der Pfad des Objekts selbst (Datei: exakter Name, Ordner: Spiegel der Quelle).
# --kind       auto (Standard): Datei/Ordner auf der Quellseite testen.
# --exclude    rsync-Exclude, mehrfach moeglich (t3-fs-* setzt feste Excludes).
# --need-dir   <seite> <pfad>: Ordner muss auf der Seite (local|remote) existieren, sonst Abbruch; mehrfach moeglich.
# --rsync-opts Ebene "Aufruf"; leer -> RSYNC_OPTS der Config -> SYNC_DEFAULT_RSYNC_OPTS.
# Rueckgabe: rsync-Exit-Code; 1 bei Fehlern/Abbruch; 0 bei --dry-run und wenn nichts zu tun ist.
sync_run() {
    SYNC_SSH_DIR=""
    local RC
    if [ -n "$SSH_HOST" ]; then
        # rsync -e zerlegt den ssh-Befehl an Leerzeichen, und Unix-Sockets haben ein Laengenlimit (ca. 104 Zeichen):
        # bei Leerzeichen oder langem TMPDIR deshalb /tmp nehmen
        local TMPBASE="${TMPDIR:-/tmp}"
        if [[ "$TMPBASE" =~ [[:space:]] ]] || [ ${#TMPBASE} -gt 60 ]; then TMPBASE="/tmp"; fi
        SYNC_SSH_DIR=$(mktemp -d "${TMPBASE%/}/sync-ssh.XXXXXX") || { echo "Fehler: Temp-Ordner für SSH konnte nicht angelegt werden!" >&2; return 1; }
        SYNC_SSH_OPTS=(-o ControlMaster=auto -o ControlPersist=60 -o "ControlPath=${SYNC_SSH_DIR}/c")
        trap '_sync_ssh_cleanup; exit 130' INT TERM HUP
    else
        SYNC_SSH_OPTS=()
    fi
    _sync_run_inner "$@"
    RC=$?
    if [ -n "$SSH_HOST" ]; then
        _sync_ssh_cleanup
        trap - INT TERM HUP
    fi
    return $RC
}

_sync_run_inner() {
    local DIRECTION="" SRC="" DST="" KIND="auto" SERVER="${SSH_HOST:-Ordner}" MODE="ask" DELETE=0 OPTS_CALL=""
    local -a EXCLUDES=() NEED_DIRS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --direction) DIRECTION="$2"; shift 2 ;;
            --src) SRC="$2"; shift 2 ;;
            --dst) DST="$2"; shift 2 ;;
            --kind) KIND="$2"; shift 2 ;;
            --server) SERVER="$2"; shift 2 ;;
            --run) MODE="run"; shift ;;
            --dry-run) MODE="dry"; shift ;;
            --delete) DELETE=1; shift ;;
            --rsync-opts) OPTS_CALL="$2"; shift 2 ;;
            --exclude) EXCLUDES+=("--exclude=$2"); shift 2 ;;
            --need-dir) NEED_DIRS+=("$2|$3"); shift 3 ;;
            *) echo "Fehler (intern): sync_run kennt '$1' nicht!" >&2; return 1 ;;
        esac
    done
    local SRC_SIDE DST_SIDE
    case "$DIRECTION" in
        send)  SRC_SIDE="local";  DST_SIDE="remote" ;;
        fetch) SRC_SIDE="remote"; DST_SIDE="local" ;;
        *) echo "Fehler (intern): sync_run braucht --direction send|fetch!" >&2; return 1 ;;
    esac

    # --- Vorab-Checks ---
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Fehler: rsync ist lokal nicht installiert!" >&2
        return 1
    fi
    local LOCAL_VER REMOTE_VER MKPATH=0
    LOCAL_VER=$(rsync --version | sed -n '1s/^rsync *version \([0-9][0-9.]*\).*/\1/p')
    REMOTE_VER="$LOCAL_VER"
    if [ -n "$SSH_HOST" ]; then
        REMOTE_VER=$(ssh "${SYNC_SSH_OPTS[@]}" "$SSH_HOST" 'command -v rsync >/dev/null 2>&1 && rsync --version | sed -n "1s/^rsync *version \([0-9][0-9.]*\).*/\1/p"')
        if [ -z "$REMOTE_VER" ]; then
            echo "Fehler: SSH-Verbindung zu '${SSH_HOST}' fehlgeschlagen oder rsync ist dort nicht installiert!" >&2
            return 1
        fi
    fi
    if _sync_ver_ge "$LOCAL_VER" 3.2.3 && _sync_ver_ge "$REMOTE_VER" 3.2.3; then MKPATH=1; fi

    # --need-dir <seite> <pfad>: Ordner muss auf der Seite existieren (z. B. fileadmin-Root)
    local ND ND_SIDE ND_PATH
    for ND in "${NEED_DIRS[@]}"; do
        ND_SIDE="${ND%%|*}"; ND_PATH="${ND#*|}"
        if [ "$(_sync_probe "$ND_SIDE" "$ND_PATH")" != "dir" ]; then
            echo "Fehler: Ordner '$(_sync_disp "$ND_SIDE" "$ND_PATH")' existiert nicht! Bitte LOCAL_FILEADMIN_DIR/REMOTE_FILEADMIN_DIR in der Config prüfen." >&2
            return 1
        fi
    done

    local SRC_KIND DST_KIND
    SRC_KIND=$(_sync_probe "$SRC_SIDE" "$SRC") || { echo "Fehler: Quelle konnte nicht geprüft werden!" >&2; return 1; }
    case "$SRC_KIND" in
        none)  echo "Fehler: Quelle '$(_sync_disp "$SRC_SIDE" "$SRC")' existiert nicht!" >&2; return 1 ;;
        other) echo "Fehler: Quelle '$(_sync_disp "$SRC_SIDE" "$SRC")' ist weder Datei noch Ordner!" >&2; return 1 ;;
    esac
    if [ "$KIND" != "auto" ] && [ "$KIND" != "$SRC_KIND" ]; then
        echo "Fehler: Quelle ist ein(e) ${SRC_KIND}, erwartet war ${KIND}!" >&2
        return 1
    fi
    KIND="$SRC_KIND"

    DST_KIND=$(_sync_probe "$DST_SIDE" "$DST") || { echo "Fehler: Ziel konnte nicht geprüft werden!" >&2; return 1; }
    if [ "$KIND" = "file" ] && [ "$DST_KIND" = "dir" ]; then
        echo "Fehler: Ziel '$(_sync_disp "$DST_SIDE" "$DST")' ist ein Ordner, die Quelle eine Datei! Mit Slash am Ende von --to in den Ordner hinein kopieren." >&2
        return 1
    fi
    if [ "$KIND" = "dir" ] && { [ "$DST_KIND" = "file" ] || [ "$DST_KIND" = "other" ]; }; then
        echo "Fehler: Ziel '$(_sync_disp "$DST_SIDE" "$DST")' existiert und ist kein Ordner!" >&2
        return 1
    fi

    # Ordner-Modus (kein SSH): Quelle und Ziel duerfen weder gleich noch ineinander verschachtelt sein
    if [ -z "$SSH_HOST" ]; then
        local RS RD
        RS=$(_sync_abs "$SRC"); RD=$(_sync_abs "$DST")
        if [ "$RS" = "$RD" ]; then
            echo "Fehler: Quelle und Ziel sind derselbe Pfad (${RS})!" >&2
            return 1
        fi
        if [ "$KIND" = "dir" ] && { [[ "$RD" == "$RS"/* ]] || [[ "$RS" == "$RD"/* ]]; }; then
            echo "Fehler: Quelle (${RS}) und Ziel (${RD}) sind ineinander verschachtelt!" >&2
            return 1
        fi
    fi

    # Elternordner des Ziels: ohne --mkpath vor dem echten Lauf anlegen (nie im Dry-Run)
    local PARENT PARENT_KIND="dir" PARENT_MISSING=0
    PARENT=$(dirname -- "$DST")
    PARENT_KIND=$(_sync_probe "$DST_SIDE" "$PARENT") || { echo "Fehler: Ziel konnte nicht geprüft werden!" >&2; return 1; }
    [ "$PARENT_KIND" = "dir" ] || PARENT_MISSING=1
    if [ "$PARENT_MISSING" = 1 ] && [ "$PARENT_KIND" != "none" ]; then
        echo "Fehler: '$(_sync_disp "$DST_SIDE" "$PARENT")' existiert und ist kein Ordner!" >&2
        return 1
    fi

    # --- rsync-Argumente ---
    local OPTS="$SYNC_DEFAULT_RSYNC_OPTS"
    [ -n "$RSYNC_OPTS" ] && OPTS="$RSYNC_OPTS"
    [ -n "$OPTS_CALL" ] && OPTS="$OPTS_CALL"
    local -a BASE_ARGS=()
    read -ra BASE_ARGS <<< "$OPTS"
    [ "$DELETE" = 1 ] && BASE_ARGS+=(--delete)
    [ "$MKPATH" = 1 ] && BASE_ARGS+=(--mkpath)
    BASE_ARGS+=(--itemize-changes "${EXCLUDES[@]}")
    if [ -n "$SSH_HOST" ]; then
        BASE_ARGS+=(-e "ssh ${SYNC_SSH_OPTS[*]}")
    fi
    local SPEC_SRC SPEC_DST
    SPEC_SRC=$(_sync_spec "$SRC_SIDE" "$SRC" "$KIND")
    SPEC_DST=$(_sync_spec "$DST_SIDE" "$DST" "$KIND")

    echo "Richtung: ${DIRECTION}, Server: ${SERVER}"
    echo "Von:  $(_sync_disp "$SRC_SIDE" "$SRC")"
    echo "Nach: $(_sync_disp "$DST_SIDE" "$DST")"
    echo

    # --- Dry-Run ---
    local OUT="" NEW=0 CHG=0 DEL=0 RC=0
    if [ "$PARENT_MISSING" = 1 ] && [ "$MKPATH" = 0 ]; then
        echo "Zielordner '$(_sync_disp "$DST_SIDE" "$PARENT")' existiert noch nicht und wird beim Ausführen angelegt: alles ist neu."
        OUT="neu"
    else
        OUT=$(rsync -n "${BASE_ARGS[@]}" -- "$SPEC_SRC" "$SPEC_DST")
        RC=$?
        if [ $RC -ne 0 ]; then
            [ -n "$OUT" ] && echo "$OUT"
            echo "Fehler: rsync-Dry-Run endete mit Exit-Code ${RC}." >&2
            return $RC
        fi
        [ -n "$OUT" ] && echo "$OUT"
        read -r NEW CHG DEL < <(awk '/^\*deleting/{d++;next} /^.[fLDSd]\+\+\+\+\+\+\+\+\+/{n++;next} /^[<>ch.][fLDS]/{c++} END{print n+0,c+0,d+0}' <<< "$OUT")
        if [ -z "$OUT" ]; then
            echo "Keine Änderungen."
            return 0
        fi
        echo
        echo "Zusammenfassung: ${NEW} neu, ${CHG} geändert, ${DEL} zu löschen"
    fi

    [ "$MODE" = "dry" ] && return 0

    if [ "$MODE" = "ask" ]; then
        local DELTXT="" ANSWER=""
        [ "$DEL" -gt 0 ] && DELTXT=" $(_sync_bold_red "${DEL} Datei(en) werden gelöscht!")"
        echo "${DIRECTION} ${SERVER}: $(_sync_disp "$SRC_SIDE" "$SRC") -> $(_sync_disp "$DST_SIDE" "$DST")${DELTXT}"
        printf 'Ausführen? (y/N) '
        read -r ANSWER
        case "$ANSWER" in
            y|Y|j|J) ;;
            *) echo "Abgebrochen."; return 1 ;;
        esac
    fi

    if [ "$PARENT_MISSING" = 1 ] && [ "$MKPATH" = 0 ]; then
        _sync_exec "$DST_SIDE" "$(printf 'mkdir -p -- %q' "$PARENT")" || { echo "Fehler: Zielordner konnte nicht angelegt werden!" >&2; return 1; }
    fi
    rsync "${BASE_ARGS[@]}" -- "$SPEC_SRC" "$SPEC_DST"
}

# sync_transfer_main <send|fetch> "$@": gemeinsamer Ablauf von sync-send/-fetch und (mit SYNC_T3=1) t3-fs-send/-fetch.
# Mit SYNC_T3=1 gilt der fileadmin als Wurzel (LOCAL_/REMOTE_FILEADMIN_DIR), der Pfad ist optional und die
# festen TYPO3-Excludes kommen dazu. Die Wrapper in t3/ setzen nur SYNC_T3=1 und rufen diese Funktion.
sync_transfer_main() {
    local D="$1"; shift
    local T3="${SYNC_T3:-0}"
    if [ $# -eq 0 ]; then
        sync_print_configs "$T3"
        echo
        _sync_transfer_usage "$D"
        return 0
    fi
    sync_parse_transfer_args "$@" || { echo >&2; _sync_transfer_usage "$D" >&2; return 1; }
    if [ "$P_CONFIGS" = 1 ]; then
        sync_print_configs "$T3"
        return 0
    fi
    if [ -z "$P_SERVER" ]; then
        echo "Fehler: Gegenstelle fehlt!" >&2; echo >&2; _sync_transfer_usage "$D" >&2
        return 1
    fi
    if [ "$T3" != 1 ] && [ -z "$P_PATH" ]; then
        echo "Fehler: Pfad fehlt (nie das ganze Home übertragen)!" >&2; echo >&2; _sync_transfer_usage "$D" >&2
        return 1
    fi
    sync_load_conf "$P_SERVER" || return 1
    [ -n "$SYNC_CONF_DUPLICATE" ] && echo "Hinweis: '${SYNC_CONF_DUPLICATE}' wird von conf/ verdeckt (doppelt/veraltet)." >&2

    # Wurzeln: Home (sync-*) bzw. fileadmin (t3-fs-*); LROOT lokal relativ zu ~, RROOT relativ zur Basis der Gegenstelle
    local LROOT="" RROOT="" REL TGT_REL BASENAME TO_REL
    if [ "$T3" = 1 ]; then
        if [ -z "$LOCAL_FILEADMIN_DIR" ] || [ -z "$REMOTE_FILEADMIN_DIR" ]; then
            echo "Fehler: In '${SYNC_CONF_FILE}' müssen LOCAL_FILEADMIN_DIR und REMOTE_FILEADMIN_DIR gesetzt sein!" >&2
            return 1
        fi
        LROOT=$(_sync_norm_path "$LOCAL_FILEADMIN_DIR") || return 1
        RROOT=$(_sync_norm_path "$REMOTE_FILEADMIN_DIR") || return 1
    fi

    REL=$(_sync_norm_path "$P_PATH" "$T3") || return 1
    if [ "$T3" = 1 ] && [ "$P_TO_SET" = 1 ] && [ -z "$REL" ]; then
        echo "Fehler: --to geht nur zusammen mit einem Unterpfad (sonst würde der ganze fileadmin in einen Unterordner kopiert)!" >&2
        return 1
    fi
    BASENAME="${REL##*/}"
    TGT_REL="$REL"
    if [ "$P_TO_SET" = 1 ]; then
        if [[ "$P_TO" == */ ]]; then
            TO_REL=$(_sync_norm_path "$P_TO" 1) || return 1
            TGT_REL="${TO_REL:+$TO_REL/}${BASENAME}"
        else
            TGT_REL=$(_sync_norm_path "$P_TO") || return 1
        fi
    fi

    local SRC DST
    if [ "$D" = "send" ]; then
        SRC="${HOME}/${LROOT:+$LROOT/}${REL}"
        DST=$(_sync_remote_join "${RROOT:+$RROOT/}${TGT_REL}")
    else
        SRC=$(_sync_remote_join "${RROOT:+$RROOT/}${REL}")
        DST="${HOME}/${LROOT:+$LROOT/}${TGT_REL}"
    fi
    SRC="${SRC%/}"; DST="${DST%/}"

    local -a ARGS=(--direction "$D" --src "$SRC" --dst "$DST" --server "$P_SERVER")
    [ "$P_MODE" = "run" ] && ARGS+=(--run)
    [ "$P_MODE" = "dry" ] && ARGS+=(--dry-run)
    { [ "$P_DELETE" = 1 ] || [ "$P_MIRROR" = 1 ]; } && ARGS+=(--delete)
    [ "$P_RSYNC_OPTS_SET" = 1 ] && ARGS+=(--rsync-opts "$P_RSYNC_OPTS")
    if [ "$T3" = 1 ]; then
        ARGS+=(--need-dir local "${HOME}/${LROOT}" --need-dir remote "$(_sync_remote_join "$RROOT")")
        local EX
        if [ "$P_MIRROR" = 1 ]; then
            for EX in _temp_/ _recycler_/; do ARGS+=(--exclude "$EX"); done
        elif [ "$P_ALL" != 1 ]; then
            for EX in _processed_/ _temp_/ _recycler_/; do ARGS+=(--exclude "$EX"); done
        fi
        local -a EXTRA=()
        read -ra EXTRA <<< "$EXTRA_EXCLUDES"
        for EX in "${EXTRA[@]}"; do ARGS+=(--exclude "$EX"); done
    fi
    sync_run "${ARGS[@]}"
}

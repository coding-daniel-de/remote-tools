# Gemeinsame Testhilfen, wird von den test_*.sh per source geladen.
# Gearbeitet wird in einem Wegwerf-Ordner mit Kopie der Skripte, HOME zeigt dorthin.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$TESTS_DIR")"
PASSFAIL=0

# Wegwerf-Umgebung: $T/tools mit sync/, conf/ (inkl. Vorlage), leer von echten Configs
setup() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/synctools-test.XXXXXX")
    mkdir -p "$T/tools/sync" "$T/tools/conf"
    cp "$REPO/sync/sync-lib.sh" "$REPO/sync/sync-configs.sh" "$T/tools/sync/"
    cp "$REPO/conf/sync_template.conf" "$T/tools/conf/"
    export HOME="$T"
}

# ok "Beschreibung" "Bedingung": Bedingung per eval auswerten und Ergebnis ausgeben
ok() {
    if eval "$2"; then
        echo "PASS: $1"
    else
        echo "FAIL: $1"
        PASSFAIL=1
    fi
}

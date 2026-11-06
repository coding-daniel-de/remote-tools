# Gemeinsame Testhilfen, wird von den test_*.sh per source geladen.
# Gearbeitet wird in einem Wegwerf-Ordner mit Kopie der Skripte, HOME zeigt dorthin.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$TESTS_DIR")"
PASSFAIL=0

# Wegwerf-Umgebung: $T/tools mit sync/, conf/ (inkl. Vorlage), leer von echten Configs; $T/stubs mit ssh-Stub
setup() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/synctools-test.XXXXXX")
    mkdir -p "$T/tools/sync" "$T/tools/conf"
    cp "$REPO"/sync/*.sh "$T/tools/sync/"
    mkdir -p "$T/tools/t3"; cp "$REPO"/t3/*.sh "$T/tools/t3/" 2>/dev/null
    cp -r "$TESTS_DIR/stubs" "$T/stubs"
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

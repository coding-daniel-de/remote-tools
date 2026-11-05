#!/bin/bash
# Führt alle Tests in tests/ aus.
# Nutzung: tests/run.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILED=0
for test in "$DIR"/test_*.sh; do
    echo "=== $(basename "$test")"
    OUTPUT=$(bash "$test" 2>&1)
    echo "$OUTPUT" | grep -E '^(PASS|FAIL):'
    if echo "$OUTPUT" | grep -q '^FAIL:'; then
        FAILED=1
    fi
done

if [ "$FAILED" -eq 0 ]; then
    echo "Alle Tests bestanden."
else
    echo "Es gab fehlgeschlagene Tests."
    exit 1
fi

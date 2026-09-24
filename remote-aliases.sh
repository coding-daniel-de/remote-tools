# Aliase und Funktionen fuer Remote-Server, wird von der .bashrc per source geladen.

# Gibt den Pfad einer Datei/eines Ordners mit ~ statt $HOME am Anfang aus.
# Nuetzlich fuer scp/sftp bei gechrooteten Hostings, wo der echte absolute
# Pfad (realpath) im SFTP-Jail nicht existiert, ~/... aber funktioniert.
tilde-path() {
    local p
    for f in "${@:-.}"; do
        p="$(realpath "$f")" || continue
        case "$p" in
            "$HOME")   echo "~" ;;
            "$HOME"/*) echo "~${p#"$HOME"}" ;;
            *)         echo "$p" ;;
        esac
    done
}

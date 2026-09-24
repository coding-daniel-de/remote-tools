# Aliase und Funktionen fuer Remote-Server, wird von der .bashrc per source geladen.

# Gibt den Pfad einer Datei/eines Ordners mit ~ statt $HOME am Anfang aus.
# Nuetzlich fuer scp/sftp bei gechrooteten Hostings, wo der echte absolute
# Pfad (realpath) im SFTP-Jail nicht existiert, ~/... aber funktioniert.
tilde-path() {
    local f p home real_home
    real_home="$(realpath "$HOME")"
    for f in "${@:-.}"; do
        p="$(realpath "$f")" || continue
        # $HOME kann ein Symlink sein (z. B. IONOS), daher gegen beide Varianten pruefen
        for home in "$real_home" "$HOME"; do
            case "$p" in
                "$home")   p="~"; break ;;
                "$home"/*) p="~${p#"$home"}"; break ;;
            esac
        done
        echo "$p"
    done
}

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

# --- Tab-Vervollstaendigung fuer sync-send, sync-fetch, t3-fs-send, t3-fs-fetch ---
# Position 1 = Name der Gegenstelle (sync_<name>.conf). Der Repo-Ort kommt aus dieser Datei (BASH_SOURCE),
# die Namen werden erst beim Tab-Druck ausgelesen (in einer Subshell, damit die Lib die Shell nicht zumuellt).
_REMOTE_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_remote_tools_complete_sync() {
    [ "$COMP_CWORD" -eq 1 ] || return 0
    local cur="${COMP_WORDS[1]}" names
    names=$(source "$_REMOTE_TOOLS_DIR/sync/sync-lib.sh" 2>/dev/null && _sync_list_names 2>/dev/null)
    COMPREPLY=($(compgen -W "$names" -- "$cur"))
}
complete -F _remote_tools_complete_sync sync-send sync-fetch t3-fs-send t3-fs-fetch

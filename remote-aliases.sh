# Aliase und Funktionen fuer Remote-Server, wird von der .bashrc per source geladen.

# Gibt den Pfad einer Datei/eines Ordners mit ~ statt $HOME am Anfang aus.
# Nuetzlich fuer scp/sftp bei gechrooteten Hostings, wo der echte absolute
# Pfad im SFTP-Jail nicht existiert, ~/... aber funktioniert.
# Reine bash, ohne realpath (fehlt in Jails und auf aelteren Servern). Symlinks im Ordnerteil werden aufgeloest.
tilde-path() {
    local f p home real_home d b
    real_home="$(cd -P -- "$HOME" 2>/dev/null && pwd -P)" || real_home="$HOME"
    for f in "${@:-.}"; do
        if [ -d "$f" ]; then
            p="$(cd -P -- "$f" && pwd -P)" || continue
        elif [ -e "$f" ] || [ -L "$f" ]; then
            d="$(dirname -- "$f")"; b="$(basename -- "$f")"
            p="$(cd -P -- "$d" && pwd -P)" || continue
            [ "$p" = "/" ] && p="/$b" || p="$p/$b"
        else
            echo "tilde-path: '$f': Datei oder Ordner nicht gefunden" >&2; continue
        fi
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

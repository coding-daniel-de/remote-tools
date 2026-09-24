# remote-tools

Sammlung von Bash-Aliases und -Funktionen, die auf allen Remote-Servern (Webhosting) zur Verfügung stehen sollen.

## Einrichtung auf einem neuen Remote

```
git clone https://github.com/coding-daniel-de/remote-tools.git ~/remote-tools
~/remote-tools/install.sh
```

`install.sh` trägt eine einzelne `source`-Zeile in die `~/.bashrc` ein (nur, wenn sie noch fehlt). Die restliche `.bashrc` bleibt unangetastet.

Der Zielordner ist frei wählbar, z. B. `~/scripts/remote-tools`. Der Installer ermittelt seinen eigenen Ort und trägt dessen absoluten Pfad ein, die Aliasdatei bleibt im Repo. Wird der Ordner später verschoben, `install.sh` am neuen Ort erneut ausführen und die alte Zeile in der `~/.bashrc` von Hand entfernen.

Update später:

```
git -C ~/remote-tools pull
```

## Enthalten

### tilde-path

```
tilde-path datei
```

Gibt den absoluten Pfad mit `~` statt `$HOME` aus, z. B. `~/mein-folder/datei`. Hilfreich für `scp`, wenn das Hosting per chroot arbeitet und der echte `realpath` im SFTP-Jail nicht existiert.

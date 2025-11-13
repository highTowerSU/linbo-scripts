# linbo-scripts

Skriptsammlung rund um den LINBO-Einsatz im linuxmuster.net-Umfeld. Die enthaltenen Helfer
werden auf dem Schulserver ausgeführt und automatisieren typische Wartungsaufgaben wie das
Synchronisieren von Rechnergruppen oder das Auswerten der `devices.csv`.

## Übersicht

| Skript            | Zweck |
|-------------------|-------|
| `sync_pcs.sh`     | Weckt komplette Rechnergruppen, stößt einen LINBO-Sync an und meldet veraltete Geräte. |
| `lm-devices`      | Liest die `devices.csv`, filtert Räume/Geräte-Typen und zeigt (optional farbig) den Image-Stand an. |

## Voraussetzungen

* linuxmuster.net-Server mit LINBO (getestet ab v7)
* funktionierender `linbo-remote`-Aufruf und eingerichtete Rechnergruppen (`linux-efi`, `linux-efi-p6012`)
* Log-Verzeichnisse `/var/log/linbo-scripts/` (Standard für `sync_pcs.sh`, per `LOG_DIR` anpassbar) und `/var/log/linuxmuster/linbo/`
* `wakeonlan`-Wrapper (z. B. `ssh-wol`) im `PATH`, wenn WOL-Pakete über Unifi gesendet werden
* Zugriff auf `/etc/linuxmuster/sophomorix/default-school/devices.csv`

## Installation
cd /usr/local/lib/
git clone https://github.com/highTowerSU/linbo-scripts/
cd linbo-scripts
ln -s /usr/local/lib/linbo-scripts/10_keine_komischen_namen /var/lib/linuxmuster/hooks/update-linbofs.pre.d/10_keine_komischen_namen
ln -s /usr/local/lib/linbo-scripts/lm-devices /usr/local/sbin/lm-devices
ln -s /usr/local/lib/linbo-scripts/sync_pcs.sh /usr/local/bin/sync_pcs.sh

## `sync_pcs.sh`

### Zweck

Automatisiert den täglichen Sync der Rechnergruppen `linux-efi` und `linux-efi-p6012`. Das Skript

1. schreibt einen Startblock ins Log `${LOG_DIR:-/var/log/linbo-scripts}/sync_pcs.sh`,
2. setzt den `PATH`, damit `ssh-wol` für Wake-on-LAN verfügbar ist,
3. startet für beide Gruppen `linbo-remote` mit folgenden Parametern:
   * `-b 30` – verzögert WOL-Signale um 30 s je Gerät,
   * `-w 60` – wartet 60 s, bis alle Clients im LINBO-Menü sind,
   * `-p initcache,sync:1,halt,halt` – baut den Cache neu auf, synchronisiert OS 1 und fährt danach herunter,
4. filtert die Ausgabe auf WOL-/LINBO-Statuszeilen,
5. wartet an Werktagen (Di–Fr) 60 Minuten, prüft mit `lm-devices --outdated`, ob Clients das aktuelle Image besitzen, und
6. gibt eine Liste nicht aktualisierter Hosts aus.

### Aufruf & Integration

Das Skript ist für einen Cronjob auf dem Server gedacht, z. B.:

```cron
30 05 * * 1-5 /srv/linbo-scripts/sync_pcs.sh
```

Anpassungen:

* **Rechnergruppen**: In `linbo-do` die `-g`-Parameter auf die eigenen Geräte-Gruppen ändern.
* **Image-Index**: `sync:1` bezieht sich auf den ersten `[OS]`-Block der jeweiligen `start.conf`.
* **Logpfad**: Über die Umgebungsvariable `LOG_DIR` (Standard: `/var/log/linbo-scripts`) anpassen.

## `lm-devices`

### Zweck

Hilfsskript, um die `devices.csv` auszuwerten. Es kann Räume, Gerätetypen oder einzelne Hosts
listen und optional die zuletzt synchronisierte Image-Version ausgeben.

### Beispiele

```bash
# Alle Hosts eines Raumes, inkl. Image-Status (grün aktuell, rot veraltet)
./lm-devices --room r210 --show-version

# Nur Geräte mit veralteter Image-Version für das Standardimage
./lm-devices --hosts --show-version --outdated --quiet

# Alle Gerätetypen (inkl. versteckter Geräteklassen)
./lm-devices --types --all
```

### Wichtige Optionen

| Option | Beschreibung |
|--------|--------------|
| `--hosts` / `--rooms` / `--types` / `--ips` | Legt den Ausgabemodus fest. |
| `--room <RAUM>` | Filtert auf einen Raum (Spalte 1 in `devices.csv`). |
| `--type <TYP>` | Filtert auf Gerätetyp (Spalte 10). |
| `--all` bzw. `--hidden` | Zeigt auch Geräteklassen, die standardmäßig ausgeblendet werden (`${HIDDEN}`). |
| `--image <NAME>` | Überschreibt das Standardimage (`UbuntuV2`). Der `.qcow2`-Suffix ist optional. |
| `--show-version` | Liest die letzte Image-Version pro Host aus `*_image.status` und färbt die Ausgabe ein. |
| `--outdated` | Kombiniert mit `--show-version`: Nur Hosts, deren Timestamp vom aktuellen Image abweicht. |
| `--quiet` | Unterdrückt die Ausgabe des aktuellen Image-Timestamps.

Die Image-Vergleiche nutzen die Datei `/srv/linbo/images/<image>/<image>.qcow2.info`. Fehlt diese,
bricht das Skript mit einem Hinweis ab.

## Entwicklung

Das Repository enthält ausschließlich Shellskripte. Für Anpassungen genügt ein Editor und Zugang
zum linuxmuster-Server. Bitte führe nach Änderungen lokale Tests (z. B. mit `shellcheck`) aus und
überprüfe die Cron-Ausgaben sowie die Logdateien.


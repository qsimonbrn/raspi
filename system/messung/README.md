# Befristete Speichermessung

Bis zum Neustart am 18.08.2026 fehlten in `/boot/firmware/cmdline.txt` die
Parameter `cgroup_enable=memory cgroup_memory=1`. Ohne sie gab es keine
Speicherbuchfuehrung: `docker stats` meldete bei jedem Container `0B / 0B`,
und ein `mem_limit` in einer Compose-Datei waere wirkungslos geblieben.

Seit dem Neustart ist der Controller `memory` aktiv. Diese Messung schreibt
alle fuenf Minuten den Verbrauch je Container nach
`/mnt/usb-hdd/messungen/docker-speicher.csv`, damit die spaeteren Limits auf
gemessenen Werten beruhen statt auf Schaetzungen.

**Nach der Auswertung wieder entfernen:**

    sudo systemctl disable --now docker-stats-messung.timer
    sudo rm /etc/systemd/system/docker-stats-messung.{service,timer}
    sudo rm /usr/local/bin/docker-stats-messung.sh
    sudo systemctl daemon-reload

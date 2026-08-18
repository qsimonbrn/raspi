#!/bin/bash
# Schreibt alle paar Minuten den Speicherverbrauch je Container in eine CSV.
# Zweck: Grundlage fuer mem_limit-Werte, statt sie zu raten. Nach der
# Auswertung wieder entfernen -- siehe docs/15-aenderungshistorie.md.
CSV=/mnt/usb-hdd/messungen/docker-speicher.csv
mkdir -p "$(dirname "$CSV")"
[ -s "$CSV" ] || echo "zeitpunkt,container,mem_bytes,mem_prozent,cpu_prozent" > "$CSV"
TS=$(date --iso-8601=seconds)
docker stats --no-stream --format '{{.Name}};{{.MemUsage}};{{.MemPerc}};{{.CPUPerc}}' \
| while IFS=';' read -r name mem perc cpu; do
    roh=${mem%% /*}
    echo "$TS,$name,$roh,${perc%\%},${cpu%\%}" >> "$CSV"
  done

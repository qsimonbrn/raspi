# 07 — Sicherheit

*Erfasst: 18.08.2026*

## Zusammenfassung

Die Architektur ist richtig gedacht: Fernzugriff läuft über Tailscale statt über
Portfreigaben, der rekursive DNS-Resolver ist auf localhost beschränkt, kein Container
läuft privilegiert, die Samba-Freigabe ist auf einen Benutzer begrenzt, und das
Betriebssystem ist vollständig gepatcht.

Was fehlt, ist die **Tiefenverteidigung**. Aktuell schützt genau eine Schicht — die
FRITZ!Box. Fällt die aus oder wird sie fehlkonfiguriert, gibt es dahinter nichts mehr.

---

## 🔴 Keine Firewall auf dem Host

```
iptables  INPUT  policy ACCEPT   (keine einzige Regel)
ip6tables INPUT  policy ACCEPT   (keine einzige Regel)
ufw       nicht installiert
```

Jeder Dienst auf dem Pi ist von jedem Gerät im Heimnetz erreichbar — und über IPv6
grundsätzlich auch von außerhalb, sofern die FRITZ!Box es zuließe.

**Warum das im Heimnetz trotzdem relevant ist:** Ein Heimnetz ist kein vertrauenswürdiger
Raum. Darin hängen typischerweise Geräte, die niemand patcht: Smart-TVs, Drucker,
IoT-Steckdosen, Saugroboter, Kameras, Spielekonsolen, dazu Notebooks von Gästen. Wird
eines davon kompromittiert, steht die Portainer-Oberfläche — also die vollständige
Kontrolle über alle Container — ohne weitere Hürde offen.

**Empfehlung:** `ufw` installieren mit einem Regelwerk in dieser Richtung:

| Regel | Zweck |
|---|---|
| `allow from 192.168.178.0/24 to any port 22,80,53,445,139` | LAN-Dienste |
| `allow from 100.64.0.0/10` | Tailscale-Geräte bekommen vollen Zugriff |
| `allow in on tailscale0` | Verkehr aus dem Tailnet |
| `deny` für Verwaltungsoberflächen aus dem LAN, nur über VPN | Portainer (9000/9443) |
| `default deny incoming` | alles Übrige |

Der Gedanke dahinter: Was nur du brauchst (Portainer, Filebrowser), erreichbar nur über
VPN. Was das Netz braucht (DNS, Samba), erreichbar im LAN.

**Wichtig:** `ufw` und Docker vertragen sich nicht selbstverständlich — Docker schreibt
eigene iptables-Regeln, die `ufw` umgehen. Container-Ports müssen zusätzlich über
`DOCKER-USER` oder durch Binden an `127.0.0.1` plus Reverse Proxy abgesichert werden.
Das ist der Grund, warum ein Reverse Proxy (siehe [09](09-empfehlungen.md)) hier doppelt
sinnvoll ist.

---

## 🟠 SSH-Passwortanmeldung ist aktiv

| Parameter | Aktuell | Empfohlen |
|---|---|---|
| `PasswordAuthentication` | **`yes`** | `no` |
| `PubkeyAuthentication` | `yes` | `yes` |
| `PermitRootLogin` | `without-password` | `prohibit-password` (gleichbedeutend) ✅ |
| `PermitEmptyPasswords` | `no` | `no` ✅ |
| Port | 22 | 22 (unkritisch) |

Der Schlüssel-Login funktioniert nachweislich. Die Passwortanmeldung ist damit reine
zusätzliche Angriffsfläche.

**Vor der Umstellung prüfen:** Von *jedem* Gerät, das SSH-Zugang braucht, einmal
verbinden und sicherstellen, dass es ohne Passwortabfrage klappt. Danach:

```
PasswordAuthentication no
```

in `/etc/ssh/sshd_config.d/99-hardening.conf` (nicht direkt in der Hauptdatei — das
überlebt Paketupdates besser), dann `sudo systemctl reload ssh`.

**Sicherheitsnetz:** Die bestehende SSH-Sitzung geöffnet lassen und erst in einer
*zweiten* Sitzung testen, ob der Login noch klappt. Falls nicht, lässt sich die Änderung
über die noch offene Verbindung zurücknehmen.

---

## 🟠 Kein `fail2ban`

Es gibt keinerlei Begrenzung fehlgeschlagener Anmeldeversuche. In Kombination mit der
aktiven Passwortanmeldung bedeutet das: Ein Angreifer im LAN kann beliebig oft Passwörter
durchprobieren, ohne dass etwas passiert.

Wird `PasswordAuthentication` deaktiviert, sinkt die Dringlichkeit deutlich — sinnvoll
bleibt `fail2ban` trotzdem, unter anderem für Samba.

---

## 🟠 Öffentliche IPv6-Adresse ohne lokale Absicherung

Der Pi ist unter `2a02:8071:2c83:1440:…` global adressierbar. Details in
[03 — Netzwerk](03-netzwerk.md).

Die FRITZ!Box blockiert eingehende IPv6-Verbindungen in der Standardkonfiguration. Das
Risiko liegt in der Kombination: **einzige Schutzschicht** plus **alle Dienste auf
`[::]` gebunden**. Ein falsch gesetzter Haken genügt, damit Paperless, Portainer und
Filebrowser aus dem Internet erreichbar sind.

**Zu prüfen (manuell):**

1. FRITZ!Box → *Internet → Freigaben → Portfreigaben* → Gerät `raspberrypi`
2. Insbesondere: „Selbstständige Portfreigaben für dieses Gerät erlauben" — sollte
   **deaktiviert** sein
3. FRITZ!Box → *Internet → Freigaben → FRITZ!Box-Dienste* — prüfen, was nach außen offen ist

**Gegenprobe von außen:** Über das Mobilfunknetz (nicht über WLAN) versuchen, die
IPv6-Adresse des Pi auf Port 8000 oder 9000 zu erreichen. Keine Verbindung = korrekt
abgeschottet.

---

## 🟠 Schwache Standardpasswörter bei Paperless

In `docker-stacks/paperless/docker-compose.yml` stehen unveränderte Beispielwerte:

| Variable | Wert |
|---|---|
| `PAPERLESS_ADMIN_PASSWORD` | `***ENTFERNT-20260820***` |
| `POSTGRES_PASSWORD` | `paperless` |

Paperless ist auf `0.0.0.0:8000` gebunden, also aus dem gesamten Heimnetz erreichbar.
`***ENTFERNT-20260820***` ist in jeder Standard-Wortliste enthalten.

Erschwerend: Die Datei liegt in einem **Git-Repository**. Es ist privat, aber Passwörter
gehören auch dort nicht hinein — sie landen dauerhaft in der Versionsgeschichte, wo sie
auch nach einer Änderung noch nachlesbar bleiben.

**Empfehlung:** Beide Werte in eine `.env`-Datei auslagern, diese über `.gitignore`
ausschließen und in der Compose-Datei nur noch referenzieren. Anschließend das
Paperless-Administratorpasswort in der Weboberfläche ändern — die Umgebungsvariable
wirkt nur bei der Ersteinrichtung. Beim PostgreSQL-Passwort ist zu beachten, dass die
Datenbank es beim ersten Start übernommen hat; eine Änderung erfordert `ALTER USER`
in der laufenden Datenbank.

---

## 🟡 Keine automatischen Sicherheitsupdates

`unattended-upgrades` ist nicht aktiv. Details in
[02 — Betriebssystem](02-betriebssystem.md).

Das System ist aktuell vollständig gepatcht — der Prozess funktioniert also. Er hat nur
keine Rückfallebene, wenn du einmal mehrere Wochen nicht dazu kommst.

---

## 🟡 Container-Images veraltet

Zwischen 8 und 17 Monate ohne Update. Ausführlich in [05 — Docker](05-docker.md),
inklusive der Begründung, warum ein pauschales Auto-Update hier die falsche Antwort wäre.

---

## 🟢 Samba: kleinere Härtungsmöglichkeiten

| Parameter | Aktuell | Vorschlag | Begründung |
|---|---|---|---|
| `map to guest` | `Bad User` | `Never` | Unbekannte Logins werden derzeit stillschweigend zu Gast-Zugriffen |
| `usershare allow guests` | `Yes` | `No` | Es gibt keine Gast-Freigabe, die das braucht |
| `server min protocol` | nicht gesetzt | `SMB3` | Schließt veraltetes SMB1/SMB2 aus |
| `[printers]`, `[print$]` | aktiv | entfernen | Werden nicht genutzt |

Die eigentliche Freigabe `[usb-share]` ist korrekt eng gefasst: `valid users = simon`,
kein Gastzugriff. Die Punkte oben sind Debian-Standardwerte, keine Fehler — aber
unnötige Fläche.

---

## Positiv hervorzuheben

| | Warum es zählt |
|---|---|
| **Tailscale statt Portfreigaben** | Gar kein eingehender Port. Ein Portscan von außen findet nichts, weil es nichts zu finden gibt. Der Preis ist die Abhängigkeit von Tailscales Vermittlung und vom GitHub-Konto. |
| **unbound nur auf `127.0.0.1`** | Ein offener rekursiver Resolver wäre für DNS-Amplification-Angriffe missbrauchbar. Korrekt vermieden. |
| **Kein `privileged`-Container** | Ein Ausbruch aus einem Container führt nicht direkt zu Root auf dem Host. |
| **Kein `network_mode: host`** | Container sind netzwerkseitig isoliert. |
| **Getrennte Docker-Netze je Stack** | Seitwärtsbewegung zwischen Diensten ist erschwert. |
| **`PermitRootLogin without-password`** | Root ist nur per Schlüssel erreichbar. |
| **OS vollständig gepatcht** | 0 ausstehende Updates. |

---

## Priorisierte Maßnahmenliste

| # | Maßnahme | Aufwand | Wirkung |
|---|---|---|---|
| 1 | `PasswordAuthentication no` | 5 min | hoch |
| 2 | IPv6-Freigaben in der FRITZ!Box prüfen | 5 min | hoch |
| 3 | `unattended-upgrades` (nur Security) aktivieren | 5 min | hoch |
| 4 | `fail2ban` installieren | 10 min | mittel |
| 5 | `ufw` mit Regelwerk | 30 min | hoch |
| 6 | Container-Updates einspielen (nach Backup!) | 1–2 h | hoch |
| 7 | Diun für Update-Benachrichtigungen | 20 min | mittel |
| 8 | Samba-Härtung | 15 min | niedrig |

> **Reihenfolge beachten:** Punkt 6 gehört *hinter* ein funktionierendes Backup
> (siehe [06 — Daten & Speicher](06-daten-und-speicher.md)). Ein Container-Update ohne
> Rückfallebene ist selbst ein Risiko.

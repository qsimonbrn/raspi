# =============================================================================
#  Aliase fuer den Pi
#
#  Lagen bis zum 18.08.2026 von Hand in /etc/bash.bashrc und waren damit weder
#  versioniert noch beim Wiederaufbau auffindbar. Jetzt hier, versioniert unter
#  docker-stacks/wartung/pi-aliase.sh und ueber den taeglichen Abgleich geprueft.
#
#  Wirkt fuer alle Benutzer, sobald eine neue Anmeldung oder Shell startet.
#  Sofort uebernehmen:  . /etc/profile.d/pi-aliase.sh
# =============================================================================

alias wartung='sudo /usr/local/sbin/pi-wartung.sh'
alias abgleich='sudo /usr/local/sbin/pi-abgleich.sh'
alias temp='vcgencmd measure_temp'
alias throttled='vcgencmd get_throttled'
alias bootcheck='sudo rpi-eeprom-update'

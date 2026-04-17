#!/bin/bash
# fail2ban
# Autor: Bartlomiej Szyszko
# Edycja: ThomasMaven

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

# Sprawdz uprawnienia przed wykonaniem skryptu instalacyjnego
require_root

# Domyslne zmienne konfiguracyjne
BAN_TIME=30m
FIND_TIME=3m
MAXRETRY=5
SSH_PORT=

usage() {
   echo "Uzycie: sudo $0 -p SSH_PORT [-b BAN_TIME] [-f FIND_TIME] [-m MAXRETRY]"
   echo ""
   echo "  -p PORT    Port SSH (wymagany)"
   echo "  -b TIME    Czas bana (domyslnie: 30m)"
   echo "  -f TIME    Czas okna monitorowania (domyslnie: 3m)"
   echo "  -m NUM     Maksymalna liczba prob (domyslnie: 5)"
   echo ""
   echo "Przyklad: sudo $0 -p 2222 -b 1h -f 5m -m 3"
   exit 1
}

while getopts "p:b:f:m:h" opt; do
   case $opt in
      p) SSH_PORT="$OPTARG" ;;
      b) BAN_TIME="$OPTARG" ;;
      f) FIND_TIME="$OPTARG" ;;
      m) MAXRETRY="$OPTARG" ;;
      h) usage ;;
      *) usage ;;
   esac
done

if [[ -z "$SSH_PORT" ]]; then
   msg_error "Nie podano portu SSH. Uzyj flagi -p PORT."
   echo ""
   usage
fi

pkg_update
pkg_install fail2ban

# Zatrzymaj usluge fail2ban
service_stop fail2ban

# Lokalny plik konfiguracyjny
config=$(cat <<EOF
[DEFAULT]
ignoreip = 127.0.0.1
bantime  = $BAN_TIME
findtime = $FIND_TIME
maxretry = $MAXRETRY

[sshd]
port = $SSH_PORT
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
)

rm /etc/fail2ban/jail.local 2> /dev/null
echo "$config" >> /etc/fail2ban/jail.local

# Uruchomienie uslugi
service_enable_now fail2ban

msg_ok "Fail2ban zainstalowany i uruchomiony!"

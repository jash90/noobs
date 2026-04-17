#!/bin/bash
#
# Skrypt sprawdza czy HAProxy jest zainstalowane i instaluje jezeli nie.
# Nastepnie za pomocą kreatora tworzy kowa konfigurację load balancera.
#
# Autor: Pawel 'Pawilonek' Kaminski

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

# Spawdzanie czy uzytkownik jest administratorem
require_root

##########
# Instalowanie zaleznosci
#

msg_info "Instalowanie HAProxy"
# Spawdzanie czy HAProxy jest juz zainstalowane
if service_exists haproxy; then
    msg_ok "Jest już zainstalowane"
else
    pkg_update
    pkg_install haproxy
    msg_ok "zainstalowane"
fi



##########
# Sprawdzanie obecnej konfiguracji
#

haproxy -c -V -f /etc/haproxy/haproxy.cfg
if [ $? -ne 0 ]; then
  msg_error "Twoja obecna konfiguracja serwera HAProxy jest niepoprawna"
  die "Sprawdź plik /etc/haproxy/haproxy.cfg"
fi



##########
# Zbieranie danych od uzytkownika
#

msg_info "Dodawanie nowej konfiguracji"

# Generowanie losowej nazwy
randomName=$(echo $RANDOM | md5sum | head -c 5)

ask_input "Nazwa serwisu [$randomName]"
name="${REPLY:-$randomName}"

ask_input "Na jakim porcie nasłuchiwać [80]"
port="${REPLY:-80}"

servers=()
echo "Podaj listę adresów z portem na jakie ruch ma być przekierowany. Pusta linijka kończy wpisywanie."
echo "Przykładowe wartości:"
echo "  127.0.0.1:80"
echo "  mikrus:443"
echo ""

ask_input "1"
server="$REPLY"
i=1

while [[ -n $server ]]
do
  servers+=("$server")
  ((i=i+1))

  ask_input "$i"
  server="$REPLY"
done

# Spawdzanie czy zostal podany przynajmniej jeden serwer
if [ ${#servers[@]} -eq 0 ]; then
  die "Musisz podać przynajmniej jeden serwer"
fi



##########
# Przygotowanie nowj konfiguracji
#


# Pozbywamy sie spacji z nazwy
name="${name// /_}"

# Przygotowanie przykladowej konfiguracji
config=$(cat <<-END

frontend ${name}_front
        # Słuchaj na porcie ${port} ipv4 i ipv6
        bind *:${port}
        bind [::]:${port} v4v6
        # I przekerowuj ruch na serwery pod nazwą ${name}_backend_servers
        default_backend    ${name}_backend_servers

backend ${name}_backend_servers
        # Rozkładaj ruch za pomocą karuzeli (roundrobin)
        balance            roundrobin
        # I przekerowuj ruch na następujące serwery
END
)

# Dodanie do konfiguracj serwerow
i=0
for address in "${servers[@]}"
do
  config="${config}
        server             srv${i} ${address} check"

  ((i=i+1))
done


# Sprawdzanie nowej konfiguracji
tmpConfig=/tmp/${randomName}-haproxy.cfg
cp /etc/haproxy/haproxy.cfg ${tmpConfig}
echo "$config" >> ${tmpConfig}
haproxy -c -V -f ${tmpConfig}
configReturn=$?
rm ${tmpConfig}
if [ $configReturn -ne 0 ]; then
  die "Niestety podana konfiguracja jest niepoprawna"
fi


# Dodanie nowego wpisu do konfiguracji
echo "$config" >> /etc/haproxy/haproxy.cfg
msg_ok "Twoja konfiguracja została zapisana w: /etc/haproxy/haproxy.cfg"

# Restart servera HAProxy
msg_info "Restart serwera"
service_restart haproxy


msg_ok "Gotowe!"

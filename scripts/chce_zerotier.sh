#!/bin/bash
# Skrypt instaluje i laczy sie z sieca ZeroTier
# Autor: Maciej Loper @2021-10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

SLEEP=5
TIMEOUT=60

status() {
    echo -e "\e[0;32m[x] \e[1;32m$1\e[0;0m"
}

usage (){
    echo "Uzycie: $0 <network_id>";
    echo "Jesli nie masz konta, zarejestruj sie na: https://www.zerotier.com";
    exit 3;
}

# start -----------------------------
[ "$#" -lt 1 ] && usage

require_non_root

net="$1"

status "pobranie i instalacja z oficjalnego skryptu"
dpkg --status zerotier-one &>/dev/null || {
    curl -s https://install.zerotier.com | sudo bash
}

status "uruchomienie (+ dodanie do boot'a)"
service_enable_now zerotier-one.service

status "dolaczanie do sieci $net"
sudo zerotier-cli join "$net"

id="$(sudo zerotier-cli info | cut -d" " -f3)"
status "twoj ID w sieci to: $id"

status "oczekiwanie na polaczenie..."

counter=0
while true; do
    echo -n "."
    found="$(ip -br -c=never addr show | grep 'ztbt' | awk -F" " '{print $3}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
    [ -n "$found" ] && break
    sleep $SLEEP
    counter=$((counter+1))
    [ "$counter" -ge $TIMEOUT ] && { echo; die "brak polaczenia"; exit 5; }
done

echo
status "Twoj IP w sieci ZeroTier to: $found"

#!/bin/bash
# Autor: Jakub Suchenek (itsanon.xyz)
#
# Przed przystąpieniem do instalacji, skrypt sprawdza:
# 1. Czy jest uruchomiony jako root.
# 2. Czy Tailscale jest już zainstalowany.
# 3. Czy system operacyjny to Ubuntu 20.04 lub nowszy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

require_root

if command_exists tailscale; then
    echo "Tailscale jest już zainstalowany na tym systemie."
    exit 0
fi

if [ ! -f /etc/os-release ]; then
    die "Nie można wykryć systemu operacyjnego!"
else
    . /etc/os-release
fi

if [ ! "$ID" == "ubuntu" ]; then
    die "Ten skrypt działa tylko na Ubuntu!"
fi

# Sposób instalacji jest analogcziny tylko dla wersji Ubuntu 20.04 i nowszych.
# Starsze wersje mają inne, indywidualne metody instalacji
# oraz inne klucze GPG.
if [[ "${VERSION_ID:0:2}" -lt 20 ]]; then
    die "Ten skrypt działa tylko na Ubuntu 20.04 lub nowszym!"
fi

if ! command_exists curl; then
    echo "Breakuje curl, instaluję..."
    pkg_update
    pkg_install curl || die "Nie udało się zainstalować curl! Zobacz co się stało powyżej."
fi

echo "Wykryto instalację Ubuntu '$UBUNTU_CODENAME'."

echo "Pobieranie klucza GPG Tailscale..."
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$UBUNTU_CODENAME.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || die "Nie udało się pobrać klucza GPG Tailscale!"

echo "Dodawanie repozytorium Tailscale..."
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$UBUNTU_CODENAME.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list || die "Nie udało się dodać repozytorium Tailscale!"

echo "Instalowanie Tailscale..."
pkg_update
pkg_install tailscale || die "Nie udało się zainstalować Tailscale! Zobacz co się stało powyżej."

echo "Weryfikacja instalacji Tailscale..."
if ! command_exists tailscale; then
    die "Instalacja Tailscale zakończyła się niepowodzeniem!"
fi

echo ""
echo "-----------------------------------------"
echo "Tailscale został pomyślnie zainstalowany!"
echo "-----------------------------------------"
echo "Następne kroki:"
echo "1. Uruchom 'tailscale up' aby połączyć się z siecią Tailscale."
echo "2. Postępuj zgodnie z instrukcjami wyświetlanymi w terminalu."
echo ""

exit 0

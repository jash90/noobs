#!/bin/bash
# docker + docker-compose
# Autor: Jakub Rolecki
# Zmodyfikowane przez: Jakub Suchenek (itsanon.xyz)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

require_root

if [ ! -f /etc/os-release ]; then
    die "Nie można wykryć systemu operacyjnego!"
else
    . /etc/os-release
fi

if [ ! "$ID" == "ubuntu" ]; then
    die "Ten skrypt działa tylko na Ubuntu!"
fi

# Zgodnie z oficjalną dokumentacją, minimalnym wspieranym systemem jest Ubuntu 22.04 LTS.
# https://docs.docker.com/engine/install/ubuntu/#os-requirements
if [[ "${VERSION_ID:0:2}" -lt 22 ]]; then
    die "Ten skrypt działa tylko na Ubuntu 22.04 lub nowszym!"
fi

msg_info "Usuwanie starych lub innych implementacji Dockera..."
apt-get remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) || die "Wystąpił błąd podczas usuwania! Zobacz co się stało powyżej."

msg_info "Przygotowywanie repozytorium Dockera..."
pkg_update
pkg_install ca-certificates curl || die "Nie można zainstalować pośrednich zależności Dockera! Zobacz co się stało powyżej."

msg_info "Pobieranie klucza GPG repozytorium Dockera..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || die "Nie można pobrać klucza GPG!"
chmod a+r /etc/apt/keyrings/docker.asc

msg_info "Wykryto instalację Ubuntu '$UBUNTU_CODENAME'."

msg_info "Dodawanie repozytorium Dockera..."
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $UBUNTU_CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
pkg_update || die "Wystąpił błąd przy dodawaniu repozytrium! Zobacz co się stało powyżej lub zgłoś ten problem na GitHubie."

msg_info "Instalowanie Dockera..."
pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || die "Wystąpił błąd podczas instalowania Dockera! Zobacz co się stało powyżej."

msg_info "Uruchamianie Dockera (dla pewności)..."
# Dokumentacja nie precyzuje, czy ma być to 'docker.service' czy 'docker.socket'.
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
service_enable_now docker || die "Nie można uruchomić Dockera! Sprawdź logi korzystając z: systemctl status docker"

msg_info "Uruchamianie testowego obrazu Dockera..."
docker run hello-world || die "Nie można uruhcomić testowego obrazu Dockera!"

# Nadanie uprawnień do Dockera dla domyślnego użytkownika.
DEFAULT_USER=$(getent passwd 1000 | cut -d ":" -f 1)
if [ ! "$DEFAULT_USER" == "" ]; then
    groupadd docker
    usermod -aG docker $DEFAULT_USER
    echo "Dodano uprawnienia do Dockera dla konta '$DEFAULT_USER'."
    echo "Zalecane jest ponownie uruchomienie Mikrusa z panelu."
fi

echo ""
echo "--------------------------------------"
echo "Docker został pomyślnie zainstalowany!"
echo "--------------------------------------"
echo "> Możesz korzystać zarówno z 'docker' jak i 'docker compose'."
echo "  Uwaga, NIE 'docker-compose'!"
if [ ! "$DEFAULT_USER" == "" ]; then
    echo "> Korzystając z Dockera, nie musisz pisać 'sudo'."
fi
echo ""

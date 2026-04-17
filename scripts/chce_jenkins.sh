#!/bin/bash
# Jenkins na mikrusowym porcie
# Autor: Maciej Loper, Radoslaw Karasinski, pablowyourmind

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

status() {
    echo "[x] $1"
}

ask_input "Podaj port, na którym ma działać Jenkins. Brak podania numeru spowoduje ustawienie portu 80:"
port=${REPLY:-80}
status "Jenkins będzie nasłuchiwał na porcie $port"

status "instalacja wymaganych pakietow"
pkg_install gnupg
echo

status "dodawanie repozytorium Jenkinsa"
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

status "aktualizacja repozytoriow"
pkg_update
echo

status "instalacja Jenkinsa i Javy JRE17"
pkg_install openjdk-17-jre-headless
pkg_install jenkins
echo

status "poprawki w konfiguracji"
service_stop jenkins
sed -i 's|User=jenkins|User=root|' /lib/systemd/system/jenkins.service
sed -i "s|JENKINS_PORT=8080|JENKINS_PORT=$port|" /lib/systemd/system/jenkins.service
sed -i 's|JAVA_OPTS=-Djava.awt.headless=true|JAVA_OPTS=-Djava.awt.headless=true -Xms256m -Xmx512m|' /lib/systemd/system/jenkins.service
sudo systemctl daemon-reload
echo

status "uruchomienie"
service_start jenkins
echo

echo -n "Gotowe. Jenkins nasłuchuje na porcie $port. Hasło początkowe: "
cat /var/lib/jenkins/secrets/initialAdminPassword

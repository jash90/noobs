#!/bin/bash
# Vault installation script
#
# Author: Sebastian Matuszczyk
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

# Add the HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

# Install the software-properties-common package in order to add HashiCorp repo
pkg_install software-properties-common

# Add the HashiCorp repo
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Update and install
pkg_update
pkg_install vault

# Verifying the installation
if vault -h ; then
    msg_ok "Vault zainstalowany."
else
    msg_error "Instalacja się nie powiodła."
fi

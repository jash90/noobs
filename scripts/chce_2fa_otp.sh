#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

if [ -f "/etc/pam.d/sshd" ]; then
    if grep -Fq "pam_google_authenticator.so" "/etc/pam.d/sshd"; then
        msg_error "2FA prawdopodobnie jest już skonfigurowane na twoim systemie."
        msg_warn "Zweryfikuj zawartość pliku /etc/pam.d/sshd i spróbuj ponownie."
        exit 1
    fi
fi

msg_warn "UWAGA	UWAGA	UWAGA"
echo -e "Uruchom przynajmiej jedną dodatkową sesję ssh przed wykonaniem tego skryptu!"
echo -e "Wykonaj oczywiście z sudo.\n"
msg_info "Dodaj danego użytkownika do grupy without-otp, jeśli nie należy wymagać od niego podania kodu OTP przy logowaniu (np. sesje sftp)!"

read -n1 -s -r -p $'\033[0;33mNaciśnij enter, aby kontynuować...\033[0m\n' key
if [ "$key" != "" ]; then
    msg_error "Wykryto inny przycisk, anulowanie aktywowania usługi 2FA..."
    exit 1
fi

pkg_update
pkg_install libpam-google-authenticator
google-authenticator
if [ $? != 0 ]; then
    die "Konfiguracja 2FA nie zwróciła prawidłowego kodu zakończenia, anulowanie aktywowania usługi 2FA..."
fi

if [ ! -f "$HOME/.google_authenticator" ]; then
    die "Nie znaleziono pliku konfiguracyjnego 2FA w katalogu domowym. Spróbuj ponownie uruchomić skrypt."
fi

echo "auth [success=done default=ignore] pam_succeed_if.so user ingroup without-otp" >>/etc/pam.d/sshd
echo "auth required pam_google_authenticator.so" >>/etc/pam.d/sshd
# DO NOT CHANGE THE SEQUENCE OF ABOVE LINES

grep -Fq "UsePAM" /etc/ssh/sshd_config && sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config || echo "UsePAM yes" >> /etc/ssh/sshd_config
grep -Fq "ChallengeResponseAuthentication" /etc/ssh/sshd_config && sed -i 's/\(ChallengeResponseAuthentication\) no/\1 yes/g' /etc/ssh/sshd_config || echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
service_restart sshd.service

msg_ok "Gotowe!"

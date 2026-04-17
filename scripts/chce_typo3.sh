#!/bin/bash
#Michał Giza

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

require_root

msg_info "Aktualizacja pakietów"
pkg_update

msg_info "Dodanie repozytorium z PHP"
pkg_install software-properties-common
add-apt-repository ppa:ondrej/php -y
pkg_update

msg_info "Instalacja pakietów"
pkg_install vsftpd apache2 mariadb-server php7.4 libapache2-mod-php7.4 php7.4-common php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-xmlrpc php7.4-mysql php7.4-gd php7.4-xml php7.4-cli php7.4-zip curl git gnupg2

msg_info "Konfiguracja FTP"
cp /etc/vsftpd.conf /etc/vsftpd.conf.backup
cat > /etc/vsftpd.conf <<EOL
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=Yes
pasv_min_port=40000
pasv_max_port=40100
EOL

msg_info "Restart vsftpd"
service_restart vsftpd

msg_info "Dodanie dedykowanego usera dla web servera"
SSH_PASS="$(generate_password)"
useradd -m cms -s /bin/bash
echo cms:${SSH_PASS} | chpasswd

msg_info "Blokada dostępu SSH"
cat >> /etc/ssh/sshd_config <<EOL
Match User cms
ChrootDirectory /home/cms
EOL

msg_info "Restart SSH"
service_restart ssh

msg_info "Zmiana ustawień PHP"
sed -i 's,^memory_limit =.*$,memory_limit = 256M,' /etc/php/7.4/apache2/php.ini
sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 100M,' /etc/php/7.4/apache2/php.ini
sed -i 's,^post_max_size =.*$,post_max_size = 100M,' /etc/php/7.4/apache2/php.ini
sed -i 's,^max_execution_time =.*$,max_execution_time = 360,' /etc/php/7.4/apache2/php.ini
sed -i 's,^date.timezone =.*$,date.timezone = Europe/Warsaw,' /etc/php/7.4/apache2/php.ini
cat >> /etc/php/7.4/apache2/php.ini <<EOL
max_input_vars = 1500
EOL

msg_info "Restart Apache"
service_restart apache2

msg_info "Tworzenie bazy i usera"
HASLO="$(generate_password)"
mysql -e "CREATE DATABASE cms;"
mysql -e "CREATE USER 'cms'@'localhost' IDENTIFIED BY '${HASLO}';"
mysql -e "GRANT ALL ON cms.* TO 'cms'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

msg_info "Pobieranie TYPO3"
curl -L -o /tmp/typo3_src.tgz https://get.typo3.org/10.4.21

msg_info "Rozpackowanie archiwum"
tar -xvzf /tmp/typo3_src.tgz

msg_info "Przeniesienie katalogu z TYPO3 do /home/cms"
mv typo3_src-10.4.21 /home/cms

msg_info "Zmiana nazwy katalogu na public_html"
mv /home/cms/typo3_src-10.4.21 /home/cms/public_html

msg_info "Zmiana uprawnień na odpowiednie"
chown -R cms:www-data /home/cms/public_html
chmod 2775 /home/cms/public_html
find /home/cms/public_html -type d -exec chmod 2775 {} +
find /home/cms/public_html -type f -exec chmod 0664 {} +

msg_info "Zapisanie konfiguracji Apache"
cat > /etc/apache2/sites-available/cms.conf <<EOL
<VirtualHost *:80>
     DocumentRoot /home/cms/public_html
     <Directory /home/cms/public_html>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
     </Directory>

     ErrorLog ${APACHE_LOG_DIR}/typo3_error.log
     CustomLog ${APACHE_LOG_DIR}/typo3_access.log combined

</VirtualHost>
EOL

msg_info "Aktywacja virtual hosta i wyłączenie domyślnej strony Apache"
a2ensite cms.conf
a2dissite 000-default.conf

msg_info "Aktywacja mod_rewrite"
a2enmod rewrite

msg_info "Restart Apache"
service_restart apache2

msg_info "Utworzenie koniecznego pliku FIRST_INSTALL"
sudo -u cms touch /home/cms/public_html/FIRST_INSTALL

msg_info "Dalsze instrukcje w pliku typo3.txt"
IP="$(get_local_ip)"
cat > typo3.txt <<EOL
TYPO3 jest gotowy do instalacji pod http://${IP}.
Nazwa bazy i użytkownika to cms.
Hasło do bazy: ${HASLO}
Hasło FTP dla lokalnego użytkownika cms: ${SSH_PASS}
EOL

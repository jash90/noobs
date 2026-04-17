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
pkg_install vsftpd unzip nginx mariadb-server php7.4-fpm php7.4-common php7.4-mysql php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-xmlrpc php7.4-gd php7.4-xml php7.4-cli php7.4-zip

msg_info "Blokada dostępu SSH"
cat >> /etc/ssh/sshd_config <<EOL
Match User shop
ChrootDirectory /home/shop
EOL

msg_info "Restart SSH"
service_restart ssh

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

msg_info "Tworzenie bazy i usera"
HASLO="$(generate_password)"
mysql -e "CREATE DATABASE shop;"
mysql -e "CREATE USER 'shop'@'localhost' IDENTIFIED BY '${HASLO}';"
mysql -e "GRANT ALL ON shop.* TO 'shop'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

msg_info "Dodanie dedykowanego usera dla web servera"
SSH_PASS="$(generate_password)"
useradd -m shop -s /bin/bash
echo shop:${SSH_PASS} | chpasswd

msg_info "Zmiana ustawień PHP"
sed -i 's,^file_uploads =.*$,file_uploads = On,' /etc/php/7.4/fpm/php.ini
sed -i 's,^allow_url_fopen =.*$,allow_url_fopen = On,' /etc/php/7.4/fpm/php.ini
sed -i 's,^short_open_tag =.*$,short_open_tag = On,' /etc/php/7.4/fpm/php.ini
sed -i 's,^memory_limit =.*$,memory_limit = 256M,' /etc/php/7.4/fpm/php.ini
sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 100M,' /etc/php/7.4/fpm/php.ini
sed -i 's,^max_execution_time =.*$,max_execution_time = 360,' /etc/php/7.4/fpm/php.ini
cat >> /etc/php/7.4/fpm/php.ini <<EOL
cgi.fix_pathinfo = 0
date.timezone = Europe/Warsaw
EOL

msg_info "Utworzenie dedykowanego PHP pool"
cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/shop.conf
cat > /etc/php/7.4/fpm/pool.d/shop.conf <<EOL
[shop]
user = shop
group = shop
listen = /run/php/shop.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

msg_info "Restart PHP"
service_restart php7.4-fpm

msg_info "Pobieranie PrestaShop"
wget https://download.prestashop.com/download/releases/prestashop_1.7.7.8.zip -O /tmp/prestashop_main.zip

msg_info "Wypakowywanie do /home/shop i usunięcie niepotrzebnych plików"
unzip /tmp/prestashop_main.zip
rm Install_PrestaShop.html index.php
unzip prestashop.zip -d /home/shop
rm prestashop.zip

msg_info "Dostosowanie uprawnień"
chown -R shop:shop /home/shop
chmod -R 755 /home/shop
chmod -R 777 /home/shop/var

msg_info "Dodanie konfiguracji Nginx"
unlink /etc/nginx/sites-enabled/default
wget https://raw.githubusercontent.com/gizamichal/NGINX/main/prestashop
mv prestashop /etc/nginx/sites-available/prestashop
ln -s /etc/nginx/sites-available/prestashop /etc/nginx/sites-enabled/

msg_info "Restart Nginx"
service_restart nginx

msg_info "Dalsze instrukcje w pliku prestashop.txt"
IP="$(get_local_ip)"
cat > prestashop.txt <<EOL
PrestaShop jest gotowa do instalacji pod http://${IP}.
Nazwa bazy i użytkownika to shop.
Hasło do bazy: ${HASLO}
Hasło FTP dla lokalnego użytkownika shop: ${SSH_PASS}

Po zakończonej instalacji usuń katalog install: sudo rm -rf /home/shop/install (lub poprzez FTP)
Sprawdź, pod jakim adresem jest panel administratora.
Nazwa katalogu w /home/shop zaczyna się od 'admin'.
W pliku /etc/nginx/sites-enabled/prestashop zamień 'CHANGE' (2x) na nazwę katalogu z panelem.
Następnie wykonaj sudo systemctl restart nginx
EOL

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
pkg_install vsftpd nginx php7.4-fpm php7.4-common php7.4-iconv php7.4-mysql php7.4-curl php7.4-mbstring php7.4-xmlrpc php7.4-soap php7.4-zip php7.4-gd php7.4-xml php7.4-intl php7.4-json libpcre3 libpcre3-dev graphviz aspell ghostscript clamav mariadb-server

msg_info "Blokada dostępu SSH"
cat >> /etc/ssh/sshd_config <<EOL
Match User moodle
ChrootDirectory /home/moodle
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

msg_info "Dodanie dedykowanego usera dla web servera"
SSH_PASS="$(generate_password)"
useradd -m moodle -s /bin/bash
echo moodle:${SSH_PASS} | chpasswd

msg_info "Zmiana ustawień PHP"
cat >> /etc/php/7.4/fpm/php.ini <<EOL
max_input_vars = 5000
EOL

msg_info "Utworzenie dedykowanego PHP pool"
cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/moodle.conf
cat > /etc/php/7.4/fpm/pool.d/moodle.conf <<EOL
[moodle]
user = moodle
group = moodle
listen = /run/php/moodle.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

msg_info "Restart PHP-FPM"
service_restart php7.4-fpm

msg_info "Zmiana konfiguracji MySQL"
cat > /etc/mysql/mariadb.conf.d/50-server.cnf <<EOL
[server]
[mysqld]
innodb_file_format = Barracuda
innodb_large_prefix = 1
user                    = mysql
pid-file                = /run/mysqld/mysqld.pid
socket                  = /run/mysqld/mysqld.sock
#port                   = 3306
basedir                 = /usr
datadir                 = /var/lib/mysql
tmpdir                  = /tmp
lc-messages-dir         = /usr/share/mysql
bind-address            = 127.0.0.1
query_cache_size        = 16M
log_error = /var/log/mysql/error.log
expire_logs_days        = 10
character-set-server  = utf8mb4
collation-server      = utf8mb4_general_ci
[embedded]
[mariadb]
[mariadb-10.3]
EOL

msg_info "Restart MySQL"
service_restart mariadb

msg_info "Tworzenie bazy i usera"
HASLO="$(generate_password)"
mysql -e "CREATE DATABASE moodle;"
mysql -e "CREATE USER 'moodle'@'localhost' IDENTIFIED BY '${HASLO}'"
mysql -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodle'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

msg_info "Pobieranie Moodle"
wget https://download.moodle.org/stable311/moodle-3.11.2.tgz -O /tmp/moodle.tgz

msg_info "Rozpackowanie archiwum"
tar -zvxf /tmp/moodle.tgz -C /home/moodle
mv /home/moodle/moodle /home/moodle/public_html

msg_info "Zmiana uprawnień"
chown moodle:moodle -R /home/moodle/public_html
chmod 755 -R /home/moodle/public_html

msg_info "Utworzenie katalogu na dane użytkowników"
mkdir /var/moodledata
chmod 755 -R /var/moodledata
chown moodle:moodle -R /var/moodledata

msg_info "Dodanie konfiguracji Nginx"
unlink /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/moodle <<EOL
server{
   listen 80;
    server_name _;
    root        /home/moodle/public_html;
    index       index.php;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ ^(.+\.php)(.*)$ {
        fastcgi_split_path_info ^(.+\.php)(.*)$;
        fastcgi_index           index.php;
        fastcgi_pass           unix:/run/php/moodle.sock;
        include                 /etc/nginx/mime.types;
        include                 fastcgi_params;
        fastcgi_param           PATH_INFO       \$fastcgi_path_info;
        fastcgi_param           SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}
}
EOL
ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/

msg_info "Restart Nginx"
service_restart nginx

msg_info "Dalsze instrukcje w pliku moodle.txt"
IP="$(get_local_ip)"
cat > moodle.txt <<EOL
Moodle jest gotowe do instalacji pod http://${IP}.
Katalog danych Moodle to /var/moodledata
Wybierz MariaDB jako typ bazy.
Nazwa bazy i użytkownika to moodle.
Hasło do bazy: ${HASLO}
Hasło FTP dla lokalnego użytkownika moodle: ${SSH_PASS}
EOL

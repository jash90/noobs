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
pkg_install vsftpd unzip nginx mariadb-server php8.0-fpm php8.0-dom php8.0-gd php8.0-xml php8.0-mysql php8.0-mbstring

msg_info "Blokada dostępu SSH"
cat >> /etc/ssh/sshd_config <<EOL
Match User drupal
ChrootDirectory /home/drupal
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
mysql -e "CREATE DATABASE drupal;"
mysql -e "CREATE USER 'drupal'@'localhost' IDENTIFIED BY '${HASLO}';"
mysql -e "GRANT ALL ON drupal.* TO 'drupal'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

msg_info "Dodanie dedykowanego usera dla web servera"
SSH_PASS="$(generate_password)"
useradd -m drupal -s /bin/bash
echo drupal:${SSH_PASS} | chpasswd

msg_info "Zmiana ustawień PHP"
sed -i 's,^memory_limit =.*$,memory_limit = 768M,' /etc/php/8.0/fpm/php.ini
sed -i 's,^max_execution_time =.*$,max_execution_time = 3600,' /etc/php/8.0/fpm/php.ini
sed -i 's,^max_input_time =.*$,max_input_time = 3600,' /etc/php/8.0/fpm/php.ini

msg_info "Utworzenie dedykowanego PHP pool"
cp /etc/php/8.0/fpm/pool.d/www.conf /etc/php/8.0/fpm/pool.d/drupal.conf
cat > /etc/php/8.0/fpm/pool.d/drupal.conf <<EOL
[drupal]
user = drupal
group = drupal
listen = /run/php/drupal.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

msg_info "Restart PHP"
service_restart php8.0-fpm

msg_info "Pobieranie Drupal"
su - drupal -c "wget https://ftp.drupal.org/files/projects/drupal-9.2.8.zip"

msg_info "Wypakowywanie do /home/drupal/public_html"
su - drupal -c "unzip drupal-9.2.8.zip"
su - drupal -c "rm drupal-9.2.8.zip"
su - drupal -c "mv drupal-9.2.8 public_html"

msg_info "Dodanie konfiguracji Nginx"
unlink /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/drupal <<EOL
server {
    server_name _;
    root /home/drupal/public_html;
    location / {
        try_files \$uri /index.php?\$query_string;
    }

    location @rewrite {
        rewrite ^ /index.php;
    }
    location ~ '\.php\$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)\$;
        try_files \$fastcgi_script_name =404;
        include fastcgi_params;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:/run/php/drupal.sock;
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        try_files \$uri @rewrite;
        expires max;
        log_not_found off;
    }
    location ~ ^/sites/.*/files/styles/ {
        try_files \$uri @rewrite;
    }
    location ~ ^(/[a-z\-]+)?/system/files/ {
        try_files \$uri /index.php?\$query_string;
    }
    if (\$request_uri ~* "^(.*/)index\.php/(.*)") {
        return 307 \$1\$2;
    }
}
EOL
ln -s /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/

msg_info "Restart Nginx"
service_restart nginx

msg_info "Dalsze instrukcje w pliku drupal.txt"
IP="$(get_local_ip)"
cat > drupal.txt <<EOL
Drupal jest gotowy do instalacji pod http://${IP}.
Nazwa bazy i użytkownika to drupal.
Hasło do bazy: ${HASLO}
Hasło FTP dla lokalnego użytkownika drupal: ${SSH_PASS}
EOL

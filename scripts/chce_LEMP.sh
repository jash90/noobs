#!/bin/bash
# LEMP = Linux + Nginx + MySQL (MariaDB) + PHP
# Autor: Jakub Rolecki

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/noobs_lib.sh" || exit 1

# Sprawdz uprawnienia przed wykonaniem skryptu instalacyjnego
require_root

pkg_update
pkg_install software-properties-common

# Repozytoria zewnętrzne z PHP i najnowszymi wydaniami nginx
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:nginx/stable

# Aktualizacja repozytoriow
pkg_update

# nginx + najpopularniejsze moduły do PHP
pkg_install nginx php php-fpm php-zip php-xml php-sqlite3 php-pgsql php-mysql php-mcrypt php-mbstring php-intl php-gd php-curl php-cli php-bcmath

# dodanie MariaDB (klient i serwer)
pkg_install mariadb-server mariadb-client

# utworzenie konfiguracji wspierającej PHP w nginx
config=$(cat <<EOF
server {
   listen   80 default_server;
   listen   [::]:80 default_server;

   root /var/www/html;

   index index.html index.htm index.php;

   server_name _;

   location / {
      try_files \$uri \$uri/ =404;
   }

   location ~ \.php\$ {
      include snippets/fastcgi-php.conf;

      fastcgi_pass unix:/var/run/php/php-fpm.sock;
   }
}
EOF
)

# aktualizacja konfiguracji
echo "$config" >/etc/nginx/sites-available/default

# Dowód na działanie PHP
echo '<?php echo "2 + 2 = ".(2+2); ' >/var/www/html/index.php

# Serwer będzie się przedstawiał jako "Nginx" - bez wersji serwera
sed -e 's/# server_tokens off;/server_tokens off;/' -i /etc/nginx/nginx.conf

# Dodanie nginxa do autostartu
service_enable_now nginx

# Przeładowanie nginxa
service_reload nginx

service_status nginx

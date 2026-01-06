#!/bin/bash
#
# This is a Shell script for VPS initialization and
# LNMP (Linux + Nginx + MariaDB + PHP) installation
#
# Supported OS:
# Debian 11
# Debian 12
# Debian 13
# Ubuntu 20.04
# Ubuntu 22.04
# Ubuntu 24.04
#
# Copyright (C) 2013 - 2025 Teddysun <i@teddysun.com>
# Copyright (C) 2025 a950216t <admin@999199.xyz>
#
trap _exit INT QUIT TERM

cur_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

_red() {
    printf '\033[1;31;31m%b\033[0m' "$1"
}

_green() {
    printf '\033[1;31;32m%b\033[0m' "$1"
}

_yellow() {
    printf '\033[1;31;33m%b\033[0m' "$1"
}

_printargs() {
    printf -- "%s" "[$(date)] "
    printf -- "%s" "$1"
    printf "\n"
}

_info() {
    _printargs "$@"
}

_warn() {
    printf -- "%s" "[$(date)] "
    _yellow "$1"
    printf "\n"
}

_error() {
    printf -- "%s" "[$(date)] "
    _red "$1"
    printf "\n"
    exit 2
}

_exit() {
    printf "\n"
    _red "$0 has been terminated."
    printf "\n"
    exit 1
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

_error_detect() {
    local cmd="$1"
    _info "${cmd}"
    if ! eval "${cmd}" 1>/dev/null; then
        _error "Execution command (${cmd}) failed, please check it and try again."
    fi
}

check_sys() {
    local value="$1"
    local release=''

    if [ -f /etc/linuxmint/info ]; then
        if grep -Eqi "LMDE|Debian" /etc/linuxmint/info; then
             release="debian"
        else
             release="ubuntu"
        fi
    elif [ -f /etc/debian_version ]; then
        release="debian"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
    fi

    if [ "${value}" == "${release}" ]; then
        return 0
    else
        return 1
    fi
}

get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty "${SAVEDSTTY}"
}

get_opsy() {
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

get_debianversion() {
    if check_sys debian; then
        local version
        local code=$1
        local main_ver

        if [ -f /etc/debian_version ]; then
            version=$(cat /etc/debian_version)
            main_ver=$(echo "${version}" | grep -oE "[0-9]+" | head -n1)

            if [ -z "${main_ver}" ]; then
                 version=$(get_opsy)
                 main_ver=$(echo "${version}" | grep -oE "[0-9.]+")
            fi
        else
            version=$(get_opsy)
            main_ver=$(echo "${version}" | grep -oE "[0-9.]+")
        fi

        if [ "${main_ver%%.*}" == "${code}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ubuntuversion() {
    if check_sys ubuntu; then
        local version
        local code=$1

        if [ -f /etc/upstream-release/lsb-release ]; then
            version=$(grep "DISTRIB_RELEASE" /etc/upstream-release/lsb-release | awk -F "=" '{print $2}')
        else
            version=$(get_opsy)
        fi

        if echo "${version}" | grep -q "${code}"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d- -f1)
    if version_ge "${kernel_version}" 4.9; then
        return 0
    else
        return 1
    fi
}

# Check BBR status
check_bbr_status() {
    local param
    param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "${param}" == "bbr" ]]; then
        return 0
    else
        return 1
    fi
}

initialize_deb() {
    _error_detect "rm -f /etc/localtime"
    _error_detect "ln -s /usr/share/zoneinfo/Asia/Taipei /etc/localtime"
    _error_detect "apt-get update"
    _error_detect "apt-get -yq install lsb-release ca-certificates curl gnupg"
    _error_detect "apt-get -yq install vim nano tar zip unzip net-tools screen git virt-what wget mtr traceroute iftop htop jq tree"
    if ufw status >/dev/null 2>&1; then
        _error_detect "ufw allow http"
        _error_detect "ufw allow https"
        _error_detect "ufw allow 443/udp"
    else
        _warn "ufw is not running, skipped firewall configuration"
    fi
}

# Configure BBR
configure_bbr() {
    if check_kernel_version; then
        if ! check_bbr_status; then
            sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
            sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
            sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
            cat >>"/etc/sysctl.conf" <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 2500000
EOF
            sysctl -p >/dev/null 2>&1
            _info "BBR configured"
        else
            _info "BBR is already enabled, skipped configuration"
        fi
    else
        _warn "Kernel version is below 4.9, skipped BBR configuration"
    fi
}

# Configure systemd-journald
configure_journald() {
    local journald_config
    if systemctl status systemd-journald >/dev/null 2>&1; then
        if [ -s "/etc/systemd/journald.conf" ]; then
            journald_config="/etc/systemd/journald.conf"
        elif [ -s "/usr/lib/systemd/journald.conf" ]; then
            journald_config="/usr/lib/systemd/journald.conf"
        fi
        sed -i 's/^#\?Storage=.*/Storage=volatile/' ${journald_config}
        sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=16M/' ${journald_config}
        sed -i 's/^#\?RuntimeMaxUse=.*/RuntimeMaxUse=16M/' ${journald_config}
        _error_detect "systemctl restart systemd-journald"
        _info "systemd-journald configuration completed"
    fi
}

# Check user
[ ${EUID} -ne 0 ] && _red "This script must be run as root!\n" && exit 1

# Check OS
if ! get_debianversion 11 && ! get_debianversion 12 && ! get_debianversion 13 &&
   ! get_ubuntuversion 20.04 && ! get_ubuntuversion 22.04 && ! get_ubuntuversion 24.04; then
    _error "Unsupported OS. Please switch to Debian 11+, or Ubuntu 20.04+ and try again."
fi

# Choose MariaDB version
while true; do
    _info "Please choose a version of the MariaDB:"
    _info "$(_green 1). MariaDB 10.11"
    _info "$(_green 2). MariaDB 11.4"
    _info "$(_green 3). MariaDB 11.8"
    read -r -p "[$(date)] Please input a number: (Default 1) " mariadb_version
    [ -z "${mariadb_version}" ] && mariadb_version=1
    case "${mariadb_version}" in
    1)
        mariadb_ver="10.11"
        break
        ;;
    2)
        mariadb_ver="11.4"
        break
        ;;
    3)
        mariadb_ver="11.8"
        break
        ;;
    *)
        _info "Input error. Please input a number between 1 and 3"
        ;;
    esac
done
_info "---------------------------"
_info "MariaDB version = $(_red "${mariadb_ver}")"
_info "---------------------------"

# Set MariaDB root password
_info "Please input the root password of MariaDB:"
read -s -r -p "[$(date)] (Default password: Teddysun.com) (password will not shown):" db_pass
if [ -z "${db_pass}" ]; then
    db_pass="Teddysun.com"
fi
echo
_info "---------------------------"
_info "Password = $(_red "${db_pass}")"
_info "---------------------------"

# Choose PHP version
while true; do
    _info "Please choose a version of the PHP:"
    _info "$(_green 1). PHP 7.4"
    _info "$(_green 2). PHP 8.0"
    _info "$(_green 3). PHP 8.1"
    _info "$(_green 4). PHP 8.2"
    _info "$(_green 5). PHP 8.3"
    _info "$(_green 6). PHP 8.4"
    _info "$(_green 7). PHP 8.5"
    read -r -p "[$(date)] Please input a number: (Default 1) " php_version
    [ -z "${php_version}" ] && php_version=1
    case "${php_version}" in
    1)
        php_ver="7.4"
        break
        ;;
    2)
        php_ver="8.0"
        break
        ;;
    3)
        php_ver="8.1"
        break
        ;;
    4)
        php_ver="8.2"
        break
        ;;
    5)
        php_ver="8.3"
        break
        ;;
    6)
        php_ver="8.4"
        break
        ;;
    7)
        php_ver="8.5"
        break
        ;;
    *)
        _info "Input error. Please input a number between 1 and 7"
        ;;
    esac
done
_info "---------------------------"
_info "PHP version = $(_red "${php_ver}")"
_info "---------------------------"

_info "Press any key to start...or Press Ctrl+C to cancel"
char=$(get_char)

_info "Initialization start"
configure_bbr
configure_journald
initialize_deb
echo
netstat -nxtulpe
echo
_info "Initialization completed"
sleep 3
clear
_info "LNMP (Linux + Nginx + MariaDB + PHP) installation start"
_info "Nginx installation start"
# https://packages.sury.org/nginx/
if check_sys debian; then
    _error_detect "curl -sSLo /usr/share/keyrings/deb.sury.org-nginx.gpg https://packages.sury.org/nginx/apt.gpg"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb.sury.org-nginx.gpg] https://packages.sury.org/nginx/ $(lsb_release -sc) main" >/etc/apt/sources.list.d/nginx.list
fi
# https://launchpad.net/~ondrej/+archive/ubuntu/nginx
if check_sys ubuntu; then
    _error_detect "add-apt-repository -y ppa:ondrej/nginx"
fi
_error_detect "apt-get update"
_error_detect "apt-get -y upgrade"
_error_detect "apt-get install -y nginx libnginx-mod-stream libnginx-mod-http-geoip libnginx-mod-http-image-filter libnginx-mod-http-perl libnginx-mod-http-xslt-filter libnginx-mod-mail libnginx-mod-stream-geoip"
_error_detect "systemctl stop nginx"
_info "Nginx installation completed"

_info "Setting up Nginx"
_error_detect "mkdir -p /data/www/default"
_error_detect "mkdir -p /data/wwwlog"
_error_detect "mkdir -p /etc/nginx/ssl"
_error_detect "mkdir -p /etc/nginx/vhost"
_error_detect "mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak"
_error_detect "cp -f ${cur_dir}/conf/nginx.conf /etc/nginx/"
_error_detect "cp -f ${cur_dir}/conf/proxy.conf /etc/nginx/"
_error_detect "cp -f ${cur_dir}/conf/cloudflare.conf /etc/nginx/"
_error_detect "cp -f -r ${cur_dir}/conf/rewrite /etc/nginx/"

_error_detect "cp -f ${cur_dir}/conf/favicon.ico /data/www/default/"
_error_detect "cp -f ${cur_dir}/conf/index.html /data/www/default/"
_error_detect "cp -f ${cur_dir}/conf/lnmp.png /data/www/default/"
_info "Nginx configuration completed"

_info "MariaDB installation start"
_error_detect "wget -qO mariadb_repo_setup.sh https://r.mariadb.com/downloads/mariadb_repo_setup"
_error_detect "chmod +x mariadb_repo_setup.sh"
_info "./mariadb_repo_setup.sh --mariadb-server-version=mariadb-${mariadb_ver}"
./mariadb_repo_setup.sh --mariadb-server-version=mariadb-${mariadb_ver} >/dev/null 2>&1
_error_detect "rm -f mariadb_repo_setup.sh"
_error_detect "apt-get install -y mariadb-common mariadb-server mariadb-client mariadb-backup"
mariadb_cnf="/etc/mysql/mariadb.conf.d/50-server.cnf"
_info "MariaDB installation completed"

_info "Setting up MariaDB"
lnum=$(sed -n '/\[mysqld\]/=' "${mariadb_cnf}")
[ -n "${lnum}" ] && sed -i "${lnum}ainnodb_buffer_pool_size = 100M\nmax_allowed_packet = 1024M\nnet_read_timeout = 3600\nnet_write_timeout = 3600" "${mariadb_cnf}"
lnum=$(sed -n '/\[mariadb\]/=' "${mariadb_cnf}" | tail -1)
[ -n "${lnum}" ] && sed -i "${lnum}acharacter-set-server = utf8mb4\n\n\[client-mariadb\]\ndefault-character-set = utf8mb4" "${mariadb_cnf}"
_error_detect "systemctl start mariadb"
sleep 3
/usr/bin/mariadb -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"${db_pass}\" with grant option;"
/usr/bin/mariadb -e "grant all privileges on *.* to root@'localhost' identified by \"${db_pass}\" with grant option;"
/usr/bin/mariadb -uroot -p"${db_pass}" 2>/dev/null <<EOF
drop database if exists test;
delete from mysql.db where user='';
delete from mysql.db where user='PUBLIC';
delete from mysql.user where user='';
delete from mysql.user where user='mysql';
delete from mysql.user where user='PUBLIC';
flush privileges;
exit
EOF

if [ -x "/etc/mysql/debian-start" ]; then
    # Add root password of MariaDB to file: /etc/mysql/debian.cnf
    cat >"/etc/mysql/debian.cnf" <<EOF
# THIS FILE IS OBSOLETE. STOP USING IT IF POSSIBLE.
# This file exists only for backwards compatibility for
# tools that run '--defaults-file=/etc/mysql/debian.cnf'
# and have root level access to the local filesystem.
# With those permissions one can run 'mariadb' directly
# anyway thanks to unix socket authentication and hence
# this file is useless. See package README for more info.
[client]
host     = localhost
user     = root
password = '${db_pass}'
[mysql_upgrade]
host     = localhost
user     = root
password = '${db_pass}'
# THIS FILE WILL BE REMOVED IN A FUTURE DEBIAN RELEASE.
EOF
    chmod 600 /etc/mysql/debian.cnf
fi

# Install phpMyAdmin
_error_detect "wget -qO pma.tar.gz https://files.phpmyadmin.net/phpMyAdmin/5.2.3/phpMyAdmin-5.2.3-all-languages.tar.gz"
_error_detect "tar zxf pma.tar.gz -C /data/www/default/"
_error_detect "mv /data/www/default/phpMyAdmin-5.2.3-all-languages /data/www/default/pma"
_error_detect "rm -f pma.tar.gz"
_info "/usr/bin/mariadb -uroot -p 2>/dev/null < /data/www/default/pma/sql/create_tables.sql"
/usr/bin/mariadb -uroot -p"${db_pass}" 2>/dev/null </data/www/default/pma/sql/create_tables.sql
_info "MariaDB configuration completed"

_info "PHP installation start"
php_conf="/etc/php/${php_ver}/fpm/pool.d/www.conf"
php_ini="/etc/php/${php_ver}/fpm/php.ini"
php_fpm="php${php_ver}-fpm"
php_sock="unix//run/php/php-fpm.sock"
sock_location="/run/mysqld/mysqld.sock"
# https://packages.sury.org/php/
if check_sys debian; then
    _error_detect "curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" >/etc/apt/sources.list.d/php.list
fi
# https://launchpad.net/~ondrej/+archive/ubuntu/php
if check_sys ubuntu; then
    _error_detect "add-apt-repository -y ppa:ondrej/php"
fi
_error_detect "apt-get update"
_error_detect "apt-get -y upgrade"
_error_detect "apt-get install -y php-common php${php_ver}-common php${php_ver}-cli php${php_ver}-fpm php${php_ver}-opcache php${php_ver}-readline"
_error_detect "apt-get install -y libphp${php_ver}-embed php${php_ver}-bcmath php${php_ver}-gd php${php_ver}-imap php${php_ver}-mysql php${php_ver}-dba php${php_ver}-mongodb php${php_ver}-sybase"
_error_detect "apt-get install -y php${php_ver}-pgsql php${php_ver}-odbc php${php_ver}-enchant php${php_ver}-gmp php${php_ver}-intl php${php_ver}-ldap php${php_ver}-snmp php${php_ver}-soap"
_error_detect "apt-get install -y php${php_ver}-mbstring php${php_ver}-curl php${php_ver}-pspell php${php_ver}-xml php${php_ver}-zip php${php_ver}-bz2 php${php_ver}-lz4 php${php_ver}-zstd"
_error_detect "apt-get install -y php${php_ver}-tidy php${php_ver}-sqlite3 php${php_ver}-imagick php${php_ver}-grpc php${php_ver}-yaml php${php_ver}-uuid"
_error_detect "mkdir -p -m770 /var/lib/php/{sessions,wsdlcache,opcache}"
_info "PHP installation completed"

_info "Setting up PHP"
sed -i "s@^user.*@user = www-data@" "${php_conf}"
sed -i "s@^group.*@group = www-data@" "${php_conf}"
sed -i "s@^listen.owner.*@;&@" "${php_conf}"
sed -i "s@^listen.group.*@;&@" "${php_conf}"
sed -i "s@^;listen.acl_users.*@listen.acl_users = www-data@" "${php_conf}"
sed -i "s@^;listen.allowed_clients.*@listen.allowed_clients = 127.0.0.1@" "${php_conf}"
sed -i "s@^pm.max_children.*@pm.max_children = 50@" "${php_conf}"
sed -i "s@^pm.start_servers.*@pm.start_servers = 5@" "${php_conf}"
sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 5@" "${php_conf}"
sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 35@" "${php_conf}"
sed -i "s@^;slowlog.*@slowlog = /var/log/www-slow.log@" "${php_conf}"
sed -i "s@^;php_admin_value\[error_log\].*@php_admin_value[error_log] = /var/log/www-error.log@" "${php_conf}"
sed -i "s@^;php_admin_flag\[log_errors\].*@php_admin_flag[log_errors] = on@" "${php_conf}"
cat >>"${php_conf}" <<EOF
php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php/sessions
php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
;php_value[opcache.file_cache]   = /var/lib/php/opcache //會導致奇怪錯誤 bug 所以禁用
EOF
sed -i "s@^disable_functions.*@disable_functions = passthru,exec,shell_exec,system,chroot,chgrp,chown,proc_open,proc_get_status,ini_alter,ini_alter,ini_restore@" "${php_ini}"
sed -i "s@^max_execution_time.*@max_execution_time = 300@" "${php_ini}"
sed -i "s@^max_input_time.*@max_input_time = 300@" "${php_ini}"
sed -i "s@^post_max_size.*@post_max_size = 128M@" "${php_ini}"
sed -i "s@^upload_max_filesize.*@upload_max_filesize = 128M@" "${php_ini}"
sed -i "s@^expose_php.*@expose_php = Off@" "${php_ini}"
sed -i "s@^short_open_tag.*@short_open_tag = On@" "${php_ini}"
sed -i "s#mysqli.default_socket.*#mysqli.default_socket = ${sock_location}#" "${php_ini}"
sed -i "s#pdo_mysql.default_socket.*#pdo_mysql.default_socket = ${sock_location}#" "${php_ini}"
_error_detect "chown root:www-data /var/lib/php/{sessions,wsdlcache,opcache}"
_info "PHP configuration completed"

_info "Addons installation start"
_error_detect "apt-get install -y redis-server php${php_ver}-redis php${php_ver}-ds"
[ -z "`grep ^maxmemory /etc/redis/redis.conf`" ] && sed -i "s@maxmemory <bytes>@maxmemory <bytes>\nmaxmemory 128000000@" /etc/redis/redis.conf
_error_detect "systemctl restart redis-server"
_error_detect "systemctl enable redis-server"
_info "Addons setup completed"

_error_detect "cp -f ${cur_dir}/conf/lnmp /usr/bin/"
_error_detect "chmod 755 /usr/bin/lnmp"
_error_detect "chown -R www-data:www-data /data/www /data/wwwlog"
_error_detect "systemctl daemon-reload"
_error_detect "systemctl start ${php_fpm}"
_error_detect "systemctl start nginx"
sleep 3
_error_detect "systemctl restart ${php_fpm}"
sleep 1
_error_detect "systemctl restart nginx"
sleep 1
_error_detect "systemctl restart mariadb"
sleep 1
_info "systemctl enable mariadb"
systemctl enable mariadb >/dev/null 2>&1
_info "systemctl enable ${php_fpm}"
systemctl enable "${php_fpm}" >/dev/null 2>&1
_info "systemctl enable nginx"
systemctl enable nginx >/dev/null 2>&1
pkill -9 gpg-agent
_info "systemctl status mariadb"
systemctl --no-pager -l status mariadb
_info "systemctl status ${php_fpm}"
systemctl --no-pager -l status "${php_fpm}"
_info "systemctl status nginx"
systemctl --no-pager -l status nginx
echo
netstat -nxtulpe
echo
_info "LNMP (Linux + Nginx + MariaDB + PHP) installation completed"

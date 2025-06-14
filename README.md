<div align="center">
    <a href="https://lnmp.999199.xyz/" target="_blank">
        <img alt="LNMP" src="https://github.com/a950216t/lnmp/blob/main/conf/lnmp.png">
    </a>
</div>

## Description

LNMP (Linux + Nginx + MariaDB + PHP) is a powerful bash script for the installation of Nginx + MariaDB + PHP and so on.

You can install Nginx + MariaDB + PHP in a smaller memory VPS by `apt-get` command, Just need to input numbers to choose what you want to install before installation.

And all things will be done in a few minutes.

- [Supported System](#supported-system)
- [System requirements](#system-requirements)
- [Supported Software](#supported-software)
- [Supported Architecture](#supported-architecture)
- [Installation](#installation)
- [Upgrade](#upgrade)
- [Uninstall](#uninstall)
- [Default Location](#default-location)
- [Process Management](#process-management)
- [lnmp command](#lnmp-command)
- [Bugs & Issues](#bugs--issues)
- [License](#license)

## Supported System

- Debian 11
- Debian 12
- Ubuntu 20.04
- Ubuntu 22.04
- Ubuntu 24.04

## System requirements

- Hard disk space: 5 GiB
- RAM: 512 MiB
- Internet connection is required
- Correct repository
- User: root

## Supported Software

- Nginx Latest Stable  ※ Nginx packages provided by [deb.sury.org](https://deb.sury.org/)
- MariaDB 10.11, 11.4  ※ MariaDB packages provided by [MariaDB Repository](https://dlm.mariadb.com/browse/mariadb_server/)
- PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4  ※ PHP packages provided by [deb.sury.org](https://deb.sury.org/)

## Supported Architecture

- x86_64 (amd64)
- aarch64 (arm64)

## Installation

```bash
apt-get -y install wget git
git clone -b deb https://github.com/a950216t/lnmp.git
cd lnmp
chmod 755 *.sh
./lnmp.sh 2>&1 | tee lnmp.log
```

## Upgrade

```bash
apt-get install --only-upgrade -y nginx
apt-get install --only-upgrade -y mariadb-*
# for example: php_ver=[7.4|8.0|8.1|8.2|8.3|8.4]
php_ver="8.2"
apt-get install --only-upgrade -y php${php_ver}-*
```

## Uninstall

```bash
apt-get remove -y nginx
apt-get remove -y mariadb-*
# for example: php_ver=[7.4|8.0|8.1|8.2|8.3|8.4]
php_ver="8.2"
apt-get remove -y php${php_ver}-*
```

## Default Location

| Nginx Location            | Path                                         |
|----------------------------|---------------------------------------------|
| Web root location          | /data/www/default                           |
| Main Configuration File    | /etc/nginx/nginx.conf                       |
| Sites Configuration Folder | /etc/nginx/vhost                            |

| MariaDB Location           | Path                                        |
|----------------------------|---------------------------------------------|
| Data Location              | /var/lib/mysql                              |
| my.cnf File                | /etc/mysql/my.cnf                           |

| PHP Location               | Path                                        |
|----------------------------|---------------------------------------------|
| php-fpm File               | /etc/php/${php_ver}/fpm/pool.d/www.conf     |
| php.ini File               | /etc/php/${php_ver}/fpm/php.ini             |

## Process Management

| Process     | Command                                                    |
|-------------|------------------------------------------------------------|
| Nginx       | systemctl [start\|stop\|status\|restart] nginx             |
| MariaDB     | systemctl [start\|stop\|status\|restart] mariadb           |
| PHP         | systemctl [start\|stop\|status\|restart] php${php_ver}-fpm |

## lnmp Command

| Command          | Description                                           |
|------------------|-------------------------------------------------------|
| lnmp start       | Start all of LNMP services                            |
| lnmp stop        | Stop all of LNMP services                             |
| lnmp restart     | Restart all of LNMP services                          |
| lnmp status      | Check all of LNMP services status                     |
| lnmp version     | Print all of LNMP software version                    |
| lnmp vhost add   | Create a new Nginx virtual host                       |
| lnmp vhost list  | List all of Nginx virtual hosts                       |
| lnmp vhost del   | Delete a Nginx virtual host                           |
| lnmp db add      | Create a MariaDB database and a user with same name   |
| lnmp db list     | List all of MariaDB databases                         |
| lnmp db del      | Delete a MariaDB database and a user with same name   |
| lnmp db edit     | Update a MariaDB database username's password         |

## Bugs & Issues

Please feel free to report any bugs or issues to us, email to: admin@999199.xyz or [open issues](https://github.com/a950216t/lnmp/issues) on Github.


## License

Copyright (C) 2013 - 2025 [Teddysun](https://teddysun.com/)

Copyright (C) 2025 [a950216t](https://999199.xyz/)

Licensed under the [GPLv3](LICENSE) License.

#!/bin/bash

WP_DB_NAME="wordpress"
WP_USER_NAME="wp"
WP_USER_PASS="wp"
WP_SERVER_IP=""

die() {
    echo "$*" >&2
    exit 2
}

warn() {
    echo "$*" >&1
}

# LAMP 

mariadb_install() {
   
   warn "Installing mariadb dependencies..."

   yum -y install mariadb-server mariadb  >/dev/null 2>&1 || die "Mariadb installation has failed!"

   systemctl start mariadb  || die "Unable to start mariadb service"

   mysql_secure_installation
   # TODO: Kendi otomatik girebilmesini sagla, ya da ayar dosyasindan okusun

   systemctl enable mariadb || warn "Unable to enable mariadb service"
   
   warn "Installation has been completed... Now adding wordpress database requirements..."

   add_wordpress_user_db_on_mysql
}

firewalld_conf() {
   
   firewall-cmd --permanent --zone=public --add-service=http
   firewall-cmd --permanent --zone=public --add-service=https
   firewall-cmd --reload

}

add_wordpress_user_db_on_mysql() {

    if [[ -e /root/.my.cnf ]]; then

        mysql -u root -e "CREATE DATABASE $WP_DB_NAME" ; >/dev/null 2>&1 || warn "$WP_DB_NAME is already exist, skipping..."
        mysql -u root -e "CREATE USER $WP_USER_NAME@$WP_SERVER_IP IDENTIFIED BY '$WP_USER_PASS';" >/dev/null 2>&1 || warn "$WP_USER_NAME is already exist, skipping..."
        mysql -u root -e "GRANT ALL PRIVILEGES ON wordpress.* TO $WP_USER_NAME@$WP_SERVER_IP IDENTIFIED BY '$WP_USER_PASSWORD';" >/dev/null 2>&1 || die "Wordpress database/user creation and auth. has failed."
        mysql -u root -e "FLUSH PRIVILEGES;" >/dev/null 2>&1

        warn "$WP_DB_NAME and $WP_USER_NAME has been successfuly created on $WP_SERVER_IP..."

    fi

}

install_wordpress() {

    yum -y install php-gd

    service httpd restart
    
    warn "Downloading wordpress... If you have a slow connection, this can take few minutes"

    wget -P /tmp/ http://wordpress.org/latest.tar.gz >/dev/null 2>&1 || die "Downloading wordpress is failed. Are you paying ISP bills ? "

    tar xzvf /tmp/latest.tar.gz >/dev/null 2>&1

    rsync -avP /tmp/wordpress/ /var/www/html/

    mkdir /var/www/html/wp-content/uploads

    chown -R apache:apache /var/www/html/*

    # Wp Configuration

    cp wp-config-sample.php wp-config.php

    sed -i "s/database_name_here/${WP_DB_NAME}/g" /var/www/html/wp-config.php
    sed -i "s/username_here/$WP_USER_NAME/g" /var/www/html/wp-config.php
    sed -i "s/password_here/$WP_USER_PASS/g" /var/www/html/wp-config.php

    warn "Wordpress installation has been completed."

    setenforce 0 
}

check_services() {

    service_list=("httpd" "mysqld")

}

check_packages() {

    package_list=("httpd" "mariadb-server" "php" "php-mysql" "php-gd" "wget")

    yum makecache fast >/dev/null 2>&1

    for package_name in "${package_list[@]}"; do

        if [[ ! 'yum list installed | grep -w $package_name | wc -l' -eq "0" ]]; then
            warn "$package_name is installed... Skipping installation..."
        else

             warn "$package_name is not installed... I am gonna install it for you. No worries but it may take some time... "

             if [[ $package_name -eq "mariadb-server" ]]; then
                 
                   mariadb_install

             else

                   yum -y install $package_name >/dev/null 2>&1 || die "Pay the bills! No connection, installation of $package_name is failed."
             fi
             
        fi
    done
   
    warn "All dependencies are installed!"
}

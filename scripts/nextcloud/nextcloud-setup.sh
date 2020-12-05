#!/bin/sh

# enable usage of own vimrc and bashrc
mkdir -p /root/.vim
cp /setup/basics/vimrc /root/.vim/
cp /setup/basics/.bashrc /root/.bashrc

# MAYBE use sed instead of copy conf file
# copy config stuff around and set permissions
cp /etc/php/7.2/apache2/php.ini /etc/php/7.2/apache2/php.ini.backup && \
mkdir -p "$NEXTCLOUD_DATA_PATH" && \
cp /setup/basics/php.ini /etc/php/7.2/apache2/php.ini && \
tar -xjf nextcloud-$NEXTCLOUD_VERSION.tar.bz2 && \
cp -r nextcloud /var/www && \
rm -r nextcloud nextcloud-$NEXTCLOUD_VERSION.tar.bz2 \
    nextcloud-$NEXTCLOUD_VERSION.tar.bz2.sha256 && \
chown -R www-data:www-data /var/www/nextcloud/ && \
# don't allow anyone but www-data to do stuff.
chmod -R 700 /var/www/nextcloud/ && \

# copy http config file and adapt name for given domain
sed -E -i "s/willBeReplacedByYourDomain/$DOMAIN_NAME/g" \
    /setup/basics/apache2-http-vhost.conf
mv /setup/basics/apache2-http-vhost.conf \
    /etc/apache2/sites-available/$DOMAIN_NAME.conf


# don't use standard www path for our data for security reasons
mkdir -p $NEXTCLOUD_DATA_PATH && \
chown -R www-data:www-data $NEXTCLOUD_DATA_PATH && \
chmod -R 700 $NEXTCLOUD_DATA_PATH && \

# apache2 enable domains and required modules
a2ensite $DOMAIN_NAME.conf
a2enmod dir env headers mime rewrite ssl
service apache2 restart

# only install once for multiple replicas
# wait 10s for the database to be set up.
# MAYBE use loop and check for condition instead of flat wait time
test -f $NEXTCLOUD_DATA_PATH/index.html || ( sleep 7s && cd /var/www/nextcloud/ && \
su www-data -s /bin/sh -c 'php occ maintenance:install --database="mysql" \
    --database-host="$MARIADB_SERVICE_NAME" \
    --database-name="$DB_NAME" --database-user="$DB_USER" \
    --database-pass="$DB_PASS" --admin-user="$ADMIN_LOGIN" \
    --admin-pass="$ADMIN_PASS" --data-dir="$NEXTCLOUD_DATA_PATH" && \
    php occ config:app:set --value 1 password_policy enforeNumericCharacters && \
    php occ config:app:set --value 1 password_policy enforeUpperLowerCase && \
    echo "setup completed succesfully." || echo "setup did not complete \
    succesfully"' && \
    # clean up default data (besides manual) from our server
    # MAYBE fix this, somehow not working currently
    mv "$NEXTCLOUD_DATA_PATH/nextcloud/files/Nextcloud Manual.pdf" ./nextcloud-manual.pdf && \
    rm -r $NEXTCLOUD_DATA_PATH/nextcloud/files/* && \
    mv ./nextcloud-manual.pdf $NEXTCLOUD_DATA_PATH/nextcloud/files/ )

# add redis mem caching if not yet using it AND domain of server as trusted
# domain for nextcloud hosting
egrep "'redis' =>" /var/www/nextcloud/config/config.php && \
    echo "Redis caching already enabled. Skip adding it." || \
    ( echo "Adding redis caching for nextcloud." && \
    chmod 666 /var/www/nextcloud/config/config.php && \
    ed /var/www/nextcloud/config/config.php << EOF
10i
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
       'host' => '$REDIS_SERVICE_NAME',
       'port' => 6379,
  ],
.
w
7i
  '2' => '$DOMAIN_NAME',
  '3' => 'www.$DOMAIN_NAME',
.
w
q
EOF
)
# set permissions to config.php again after writing to it
chmod 640 /var/www/nextcloud/config/config.php

# enable our site and disable the default
a2dissite 000-default.conf
# restart again with new config.php -- just in case its not dynamicly checked
service apache2 restart

# additional DATA encryption security settings
# disabled for now! find out how to use encrypted with docker to store
# encryption key in case container gets destroyed.
# sudo -u www-data php occ app:enable encryption
# sudo -u www-data php occ encryption:enable
# sudo -u www-data php occ encryption:encrypt-all

# generate own dh param instead of default 1024 bit openssl one.
# only if we did not create it already.
test -f $NEXTCLOUD_DH_DIR/dhparam.pem && \
    echo "DH(diffie hellmann) file already existing. Don't create new one." || \
    openssl dhparam -out $NEXTCLOUD_DH_DIR/dhparam.pem 2048

# certbot without interaction <3;
# only create cert if non existant
test -f /etc/letsencrypt/live/$DOMAIN_NAME/cert.pem \
    && echo "Certificate already existing. Don't create new one." || \
    # just create certificate here
    certbot certonly --webroot -w /var/www/nextcloud --non-interactive \
    --agree-tos --register-unsafely-without-email -d $DOMAIN_NAME

# version two
    # certbot certonly --webroot --webroot-path /var/www/nextcloud \
    # --non-interactive --agree-tos \
    # --register-unsafely-without-email -d $DOMAIN_NAME

# copy https config file and adapt name for given domain
sed -E -i "s/willBeReplacedByYourDomain/$DOMAIN_NAME/g" \
    /setup/basics/apache2-https-vhost.conf
mv /setup/basics/apache2-https-vhost.conf \
    /etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.conf

# add security hardened ssl settings and more secure apache2.conf
cp /setup/basics/options-ssl-apache.conf /etc/letsencrypt/
cp /setup/basics/apache2.conf /etc/apache2/
echo "Hardened TLS settings. Only allowing TLSv1.2 TLSv1.3 and strong ciphers."

a2ensite $DOMAIN_NAME-le-ssl.conf

# unset variables used for nextcloud setup
LOGFILE_PATH=$NEXTCLOUD_DATA_PATH/nextcloud.log
unset ADMIN_PASS ADMIN_LOGIN DB_NAME DB_PASS DB_USER NEXTCLOUD_DATA_PATH
# apply configs
service apache2 reload
# run forever and print error log to stdout
echo "Setup complete. Printing nextcloud log to stdout for better docker logs."
tail -f $LOGFILE_PATH

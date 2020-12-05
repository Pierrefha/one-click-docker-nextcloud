#!/bin/sh
# Allows connections from any ip. Mariadb standard 0.0.0.0 -> any ip
sed -i "s|.*bind-address\s*=.*|bind-address=0.0.0.0|g" /etc/my.cnf.d/mariadb-server.cnf \
    && echo "Allow connections from any ip. (bind-address-> 0.0.0.0)" || \
    ( echo "Allowing connections from any ip failed!" && \
    exit )

# Stores data in declared path and make sure permissions are correct.
mkdir -p $MARIADB_DATA_PATH && cp -r /var/lib/mysql/ $MARIADB_DATA_PATH && \
    chown -R mysql:mysql $MARIADB_DATA_PATH && \
    echo "Copying data dir and setting permissions was successful." || \
    ( echo "Failed settings permissions and copying the required data dir." && \
    exit )

# in alpine db will NOT be automaticly installed. do it ourselves
# although it is mariadb the user CURRENTLY(31.08.2020) is still mysql.
mysql_install_db --user "mysql" --basedir "/usr" --datadir="$MARIADB_DATA_PATH" \
    --skip-test-db > /dev/null && echo "Database installed." || \
    ( echo "Database failed to install." && \
    exit )

# Starts mysql database server with parameters declared in our config files.
# TODO: find out why we need skip-networking=0??
mysqld_safe --user=mysql --datadir="$MARIADB_DATA_PATH" --nowatch --skip-networking=0

# Wait until database server is set up.
# MAYBE adapt wait with grep aux
sleep 10s

# Use here document to create init file
cat << EOF > /runsetup/initdb
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Initializes database only if it does not exist yet.
test -d $MARIADB_DATA_PATH/$DB_NAME && \
    echo "Database: $DB_NAME already exists. Don't need to initialize it again." \
    || ( echo "Initializing database: $DB_NAME." && \
    mysql -u root < /runsetup/initdb )

# Pipes error messages into stdout to access them easily via docker container logs
echo "Printing database error log to stdout:"
tail -f $MARIADB_DATA_PATH/$HOSTNAME.err

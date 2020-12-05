#!/bin/sh

# allow connections from nextcloud-webserver
# redis CONFIG does not allow dns resolving inside docker container
# maybe even does not resolve at all.
# therefore just set protected mode to no and uncomment bind
# sed -E -i "s/^bind.*/bind\ apache2\-webserver/g" /etc/redis.conf

# allow connections from any ip
sed -E -i "s/^bind/#bind/g" /etc/redis.conf
# disable protected mode
sed -E -i "s/^protected-mode\ yes/protected-mode no/g" /etc/redis.conf
echo "Allowing connections from any ip for the redis server, not just localhost."

# create logfile if non existant (this is the std path for redis on alpine)
su redis -s /bin/sh -c 'touch /var/log/redis/redis.log'

# start redis server with our config
redis-server /etc/redis.conf &
echo "Starting redis server."


# Could monitor all commands by using redis-cli or telnet and MONITOR function.
# But running A SINGLE monitor command can decrease performance by up to 50%.
# https://redis.io/commands/monitor Rather log error log :]

echo "Printing redis error log to stdout"
tail -f /var/log/redis/redis.log

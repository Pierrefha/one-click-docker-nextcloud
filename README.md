## One click docker Nextcloud server
Hosting your own Nextcloud server can be just one click away.

### Prerequesites
- Port 80 and 443 are open.
- docker-compose is installed https://docs.docker.com/compose/install/

### Handling data
- Your data is preserved in mounted directories in the host system.\
The certificate, the nextcloud state and the data are all untouched
when removing the running container.\
And also won't be overwritten by starting a new instance.

### Apply your own settings
- The variable you have to adapt is DOMAIN_NAME which is stored in the .env file.
- The variables you should adapt are the password and login names stored in:
    - nextcloud-env
    - mariadb-env
- Make sure that DB_NAME DB_USER and DB_PASS inside nextcloud-env match\
the DB_NAME DB_USER DB_PASS values inside mariadb-env.

### Starting the server
```shell
docker-compose up -d
```

### Shutting down the server
```shell
docker container rm containerIdHere
```

### Features
- seperate container for webserver, mysql database and redis key value store.
- using redis memcache for enhanced performance.
- enhanced apache2 security settings which result in A+ from the ssllabs security test.\
You can check and compare results here: https://www.ssllabs.com/ssltest/

### security settings
- only accepting TLS 1.2 and TLS 1.3
- only using recommended ciphers
- enforcing hsts
- redirecting all http to https
- hide apache version from attacker
- disallow directory listing
- moved data directory away from webroot

### Tips
- opening ports
```shell
# using ufw
sudo ufw allow 80/tcp comment "nextcloud webserver"
sudo ufw allow 443/tcp comment "nextcloud webserver"
# or using iptables
# Allow incoming HTTPS
iptables -A INPUT -i eth0 -p tcp --dport 443 -m state \
    --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 443 -m state \
    --state ESTABLISHED -j ACCEPT
# Allow incoming HTTP
iptables -A INPUT -i eth0 -p tcp --dport 80 -m state \
   --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 80 -m state \
    --state ESTABLISHED -j ACCEPT
```
Hint: docker will generally ignore ufw if you did not adapt the iptables. \
More about this topic here: https://github.com/docker/for-linux/issues/690

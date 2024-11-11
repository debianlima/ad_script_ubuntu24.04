# Passo 1: Criação do usuário e configuração do shell
#sudo useradd -m -s /sbin/nologin proxysquid
#sudo passwd proxysquid

#script original:  em https://pastebin.com/jbDnvFji accessado em 11/11/2024.
#Vídeo original: em https://www.youtube.com/watch?v=3TQUF2a-Aw0 accessado em 11/11/2024.

# Step 1: Install dependencies
sudo apt -y install libssl-dev devscripts build-essential fakeroot debhelper dh-autoreconf dh-apparmor cdbs \
libcppunit-dev libsasl2-dev libxml2-dev libkrb5-dev libdb-dev libnetfilter-conntrack-dev libexpat1-dev \
libcap-dev libldap2-dev libpam0g-dev libgnutls28-dev libssl-dev libdbi-perl libecap3 libecap3-dev \
libsystemd-dev libtdb-dev libtool-bin

# Step 2: Clone Squid repository and configure
git clone https://github.com/squid-cache/squid.git
cd squid
git branch -r
git checkout v6
./bootstrap.sh
./configure --enable-auth-negotiate --with-auth-kerberos --with-openssl --enable-ssl-crtd --with-default-user=squid \
'--prefix=/usr' '--includedir=${prefix}/include' '--mandir=${prefix}/share/man' \
'--infodir=${prefix}/share/info' '--sysconfdir=/etc' '--localstatedir=/var' \
'--disable-silent-rules' '--libdir=${prefix}/lib/x86_64-linux-gnu' '--runstatedir=/run' \
'--datadir=/usr/share/squid' '--sysconfdir=/etc/squid' '--libexecdir=/usr/lib/squid' \
'--mandir=/usr/share/man' '--enable-large-cache-files' '--enable-inline' '--enable-async-io=8' \
'--enable-storeio=ufs,aufs,diskd,rock' '--enable-removal-policies=lru,heap' \
'--enable-delay-pools' '--enable-cache-digests' '--enable-icap-client' \
'--enable-follow-x-forwarded-for' '--with-swapdir=/var/spool/squid' '--with-logdir=/var/log/squid' \
'--with-pidfile=/run/squid.pid' '--with-large-files' '--with-default-user=proxy' \
'--enable-linux-netfilter' '--with-gnutls'
make
sudo make install

# Step 3: Edit squid.service file
sudo nano /lib/systemd/system/squid.service

# Contents for squid.service:
[Unit]
Description=Squid Web Proxy Server
Documentation=man:squid(8)
After=network.target network-online.target nss-lookup.target

[Service]
Type=notify
PIDFile=/var/run/squid.pid
ExecStartPre=/usr/sbin/squid --foreground -z
ExecStart=/usr/sbin/squid --foreground -sYC
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
NotifyAccess=all
-
[Install]
WantedBy=multi-user.target

# Reload systemd daemon
sudo systemctl daemon-reload

# Step 4: Edit Squid configuration file
mv /etc/squid/squid.conf /etc/squid/squid.conf.bkp
sudo nano /etc/squid/squid.conf

# Example squid.conf contents:
acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl nobumpSites ssl::server_name "/etc/squid/nobumpSites.list"
acl intermediate_fetching transaction_initiator certificate-fetching
http_access allow intermediate_fetching

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777

# Authentication parameters for Kerberos
auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -k /etc/squid/proxysquid.keytab
auth_param negotiate children 5
auth_param negotiate keep_alive on
acl kerberos_users proxy_auth REQUIRED
http_access allow kerberos_users


http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=20MB \
cert=/etc/squid/certs/squid-ca-cert-key.pem cipher=HIGH:MEDIUM:!LOW:!RC4:!SEED:!IDEA:!3DES:!MD5:!EXP:!PSK:!DSS \
options=NO_TLSv1,NO_SSLv3 tls-dh=prime256v1:/etc/squid/bump_dhparam.pem

sslproxy_cert_error allow all
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3
ssl_bump peek step1 all 
ssl_bump peek step2 nobumpSites
ssl_bump splice step3 nobumpSites
ssl_bump stare step2
ssl_bump bump step3

cache_dir ufs /opt/squid/cache 3000 16 256
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Step 5: Setting up SSL certificates
openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -keyout squid-ca-key.pem -out squid-ca-cert.pem
cat squid-ca-cert.pem squid-ca-key.pem >> squid-ca-cert-key.pem
sudo mkdir -p /etc/squid/certs
sudo cp squid-ca-cert-key.pem /etc/squid/certs/squid-ca-cert-key.pem
sudo chown proxy:proxy /etc/squid/certs/squid-ca-cert-key.pem
openssl ecparam -name prime256v1 -genkey -noout -out /etc/squid/bump_dhparam.pem
#sudo openssl dhparam -out /etc/squid/bump_dhparam.pem 2048
sudo chown proxy:proxy /etc/squid/bump_dhparam.pem
sudo /usr/lib/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB




sudo apt-get install libkrb5-dev -y

# Passo 3: Criação e teste do keytab para autenticação Kerberos
sudo samba-tool user add proxysquid --random-password
sudo samba-tool user show proxysquid
samba-tool domain exportkeytab /etc/squid/proxysquid.keytab --principal=HTTP/aulagit.lima.localdomain@LIMA.LOCALDOMAIN


sudo chown proxy:proxy /etc/squid/proxysquid.keytab
sudo chmod 600 /etc/squid/proxysquid.keytab

 sudo klist -kt /etc/squid/proxysquid.keytab


# Step 6: Setting cache and start Squid
sudo mkdir -p /opt/squid/cache
echo ".apple.com" | sudo tee /etc/squid/nobumpSites.list
sudo chown proxy:proxy /etc/squid/nobumpSites.list
sudo chown proxy:proxy /opt/squid/cache
sudo chown proxy:proxy /var/log/squid
sudo squid -z
sudo systemctl start squid.service
sudo systemctl enable squid.service

sudo systemctl status squid.service

#script original:  em https://pastebin.com/jbDnvFji accessado em 11/11/2024.
#Vídeo original: em https://www.youtube.com/watch?v=3TQUF2a-Aw0 accessado em 11/11/2024.
#link de apoio: em https://www.spinics.net/lists/squid/msg97303.html accessado em 11/11/2024.
#link de apoio: em https://webhostinggeeks.com/howto/how-to-configure-squid-proxy-server-for-ssl-bumping/ accessado em 11/11/2024.
#link de apoio:https://medium.com/big-data-blog/filtragem-avan%C3%A7ada-de-https-com-squid-proxy-e26d82b61e19 accessado em 11/11/2024.
#link de apoio:https://www.techforce.com.br/2023/12/instalar-squid-forward-proxy-com-ssl.html accessado em 11/11/2024.
#chat utilizado com IA: https://chatgpt.com/share/6731813e-66d0-8012-b089-a787a1e8b712 accessado em 11/11/2024.

#!/bin/bash
# Configuração completa para Samba AD DC com Kerberos, Bind9 e Squid Proxy com autenticação Kerberos
# Não esquecer de verificar a rota no gateway da rede local para o DNS

# Variáveis de Configuração Geral
DOMAIN="lima.internet"
UPPER_DOMAIN=${DOMAIN^^}
ADMIN_PASSWORD="abc@1234"  # Senha do administrador personalizável
SAMBA_CONF_DIR="/etc/samba"
BIND_CONF_DIR="/etc/bind"
RESOLV_CONF="/etc/resolv.conf"
HOSTS_CONF="/etc/hosts"
PRIVATE_KEYTAB_FILE="/var/lib/samba/private/dns.keytab"
BIND_KEYTAB_FILE="/var/lib/samba/bind-dns/dns.keytab"
ZONE_DIR="/var/lib/samba/bind-dns/dns/"
ZONE_FILE="${ZONE_DIR}${DOMAIN}.zone"

# Configuração de Rede
NETPLAN_CONF="/etc/netplan/50-cloud-init.yaml"
INTERFACE_NAME="ens34"  # Rede LAN
GATEWAY="172.16.0.1"
DNS_SERVERS="127.0.0.1"
DNS_GOOGLE="8.8.8.8"
SERVER="server"
IP="172.16.0.252"

# Configuração do systemd-resolved
RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_CONTENT="[Resolve]
DNS=127.0.0.1
FallbackDNS=${DNS_GOOGLE}
Domains=${DOMAIN}"

# Função para atualizar o sistema
update_system() {
    echo "Atualizando o sistema..."
    sudo apt-get update && sudo apt-get upgrade -y
}

# Função para configurar resolv.conf e hosts
configure_network_files() {
    echo "Configurando /etc/resolv.conf e /etc/hosts..."
    sudo bash -c "echo 'nameserver 127.0.0.1' > ${RESOLV_CONF}"
    sudo bash -c "echo '127.0.0.1 localhost' > ${HOSTS_CONF}"
    sudo bash -c "echo '${IP} ${SERVER}.${DOMAIN} ${SERVER}' >> ${HOSTS_CONF}"
    sudo bash -c "echo '${SERVER}' > /etc/hostname"
}

# Função para configurar systemd-resolved
configure_resolved() {
    echo "Configurando systemd-resolved..."
    sudo bash -c "echo '${RESOLVED_CONF_CONTENT}' > ${RESOLVED_CONF}"
    sudo systemctl restart systemd-resolved
}

# Função para configurar o netplan
configure_netplan() {
    echo "Configurando netplan..."
    sudo bash -c "cat > ${NETPLAN_CONF}" <<EOF
network:
    version: 2
    ethernets:
        ${INTERFACE_NAME}:
            dhcp4: no
            addresses: [${IP}/24]
            gateway4: ${GATEWAY}
            nameservers:
                addresses: [127.0.0.1, ${DNS_GOOGLE}]
EOF
    sudo netplan apply
}

# Função para parar e remover pacotes antigos
remove_packages() {
    echo "Removendo pacotes antigos..."
    sudo systemctl stop smbd nmbd winbind
    sudo systemctl disable smbd nmbd winbind
    sudo apt-get remove --purge -y samba samba-common-bin krb5-kdc krb5-admin-server \
        winbind libpam-winbind libnss-winbind libpam-krb5 libpam-mkhomedir \
        libpam-mount bind9 bind9utils bind9-doc squid krb5-user libkrb5-dev ssl-cert
    sudo apt-get autoremove -y
    sudo rm -rf /var/lib/samba /etc/samba /var/lib/krb5kdc /etc/krb5kdc /var/lib/bind /etc/bind /etc/krb5.conf 
}

# Função para reinstalar pacotes necessários
install_packages() {
    echo "Instalando pacotes necessários..."
    sudo apt-get update
    sudo apt-get install -y samba krb5-kdc krb5-admin-server winbind libpam-winbind \
        libnss-winbind libpam-krb5 libpam-mkhomedir libpam-mount bind9 bind9utils \
        bind9-doc squid krb5-user libkrb5-dev ssl-cert
}

# Função para configurar o Samba
configure_samba() {
    echo "Configurando Samba como controlador de domínio..."
    sudo rm -f ${SAMBA_CONF_DIR}/smb.conf
    sudo samba-tool domain provision --realm=${DOMAIN} --domain=${DOMAIN%%.*} \
        --server-role=dc --dns-backend=BIND9_DLZ --use-rfc2307 --function-level=2008_R2 \
        --adminpass=${ADMIN_PASSWORD}
    sudo cp ${SAMBA_CONF_DIR}/smb.conf ${SAMBA_CONF_DIR}/smb.conf.bak
    sudo bash -c "cat > ${SAMBA_CONF_DIR}/smb.conf" <<EOF
# Configurações do Samba
EOF
    sudo smbcontrol all reload-config
}

# Função para configurar o Kerberos
configure_kerberos() {
    echo "Configurando Kerberos..."
    sudo bash -c "cat > /etc/krb5.conf" <<EOF
[libdefaults]
    default_realm = ${UPPER_DOMAIN}
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    ${UPPER_DOMAIN} = {
        kdc = ${SERVER}.${DOMAIN}
        admin_server = ${SERVER}.${DOMAIN}
    }

[domain_realm]
    .${DOMAIN} = ${UPPER_DOMAIN}
    ${DOMAIN} = ${UPPER_DOMAIN}
EOF
}

# Função para configurar o Bind
configure_bind() {
    echo "Configurando Bind..."
    sudo mkdir -p /var/lib/samba/bind-dns
    sudo cp ${PRIVATE_KEYTAB_FILE} ${BIND_KEYTAB_FILE}
    sudo chown bind:bind ${BIND_KEYTAB_FILE}
    sudo chmod 640 ${BIND_KEYTAB_FILE}

    sudo bash -c "cat > ${BIND_CONF_DIR}/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";
    dnssec-validation no;
    auth-nxdomain no;
    listen-on-v6 { any; };
    forwarders { ${DNS_GOOGLE}; };
};
EOF
    sudo systemctl restart bind9
    sudo systemctl enable bind9
}

# Função para configurar o Squid com autenticação Kerberos
configure_squid() {
    echo "Configurando Squid com autenticação Kerberos..."
    sudo bash -c "cat > /etc/krb5.conf" <<EOF
[libdefaults]
    default_realm = ${UPPER_DOMAIN}
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF

    kinit usuario_squid@${UPPER_DOMAIN}
    kadmin -q "ktadd -k /etc/krb5.keytab HTTP/${SERVER}.${DOMAIN}"
    sudo chown proxy:proxy /etc/squid/squid.keytab
    sudo chmod 600 /etc/squid/squid.keytab

    sudo bash -c 'cat > /etc/squid/squid.conf' <<EOT
auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -s HTTP/${SERVER}.${DOMAIN}
auth_param negotiate children 10
auth_param negotiate keep_alive on

acl kerberos_auth proxy_auth REQUIRED
http_access allow kerberos_auth

acl rede_interna src 192.168.0.0/24
http_access allow kerberos_auth rede_interna
http_access deny all

https_port 3128 cert=/etc/squid/ssl_cert/squid.pem
EOT
    sudo systemctl restart squid
}

# Função principal
main() {
    update_system
    remove_packages
    install_packages
    configure_network_files
    configure_resolved
    configure_netplan
    configure_samba
    configure_kerberos
    configure_bind
    configure_squid
    echo "Script concluído."
}

# Executa o script
main

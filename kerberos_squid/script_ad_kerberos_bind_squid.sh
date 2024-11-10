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


# Defina as variáveis de configuração de rede
NETPLAN_CONF="/etc/netplan/50-cloud-init.yaml"
#Rede wan
INTERFACE_NAME_wan="ens33"  # Altere para o nome da sua interface de rede, se necessário
GATEWAY_wan="172.16.57.2"
IP_wan="172.16.57.3"

#Rede lan
INTERFACE_NAME="ens34"  # Altere para o nome da sua interface de rede, se necessário
GATEWAY="172.16.0.1"
DNS_SERVERS="127.0.0.1"
DNS_GOOGLE="8.8.8.8"
SERVER="server"
IP="172.16.0.252"
NETWORK=172.16.0.0/24 # ip para rede interna do squid.

# Configuração do systemd-resolved
RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_CONTENT="[Resolve]
DNS=127.0.0.1
FallbackDNS=${IP}
Domains=${DOMAIN}"

# Função para atualizar o sistema
update_system() {
      echo "Atualizando o sistema..."
    sudo apt-get update
    if [ $? -eq 0 ]; then
        echo "Atualização de pacotes concluída com sucesso."
    else
        echo "Falha na atualização dos pacotes."
    fi

    sudo apt-get upgrade -y
    if [ $? -eq 0 ]; then
        echo "Atualização dos pacotes concluída com sucesso."
    else
        echo "Falha na atualização dos pacotes."
    fi
}

# Função para configurar resolv.conf e hosts
configure_network_files() {
    echo "Configurando /etc/resolv.conf e /etc/hosts..."

    # Configuração temporária do resolv.conf
    sudo bash -c "cat > ${RESOLV_CONF}" <<EOF
nameserver 127.0.0.1
EOF

    if [ $? -eq 0 ]; then
        echo "Arquivo /etc/resolv.conf configurado com sucesso."
    else
        echo "Falha ao configurar o arquivo /etc/resolv.conf."
    fi

    # Configuração do hosts
    sudo bash -c "cat > ${HOSTS_CONF}" <<EOF
127.0.0.1       localhost
${IP}           ${SERVER}.${DOMAIN} ${SERVER}
EOF

    if [ $? -eq 0 ]; then
        echo "Arquivo /etc/hosts configurado com sucesso."
    else
        echo "Falha ao configurar o arquivo /etc/hosts."
    fi
}

# Função para configurar systemd-resolved
configure_resolved() {
     echo "Configurando /etc/resolv.conf e /etc/hosts..."

    # Configuração temporária do resolv.conf
    sudo bash -c "cat > ${RESOLV_CONF}" <<EOF
nameserver ${DNS_GOOGLE}
EOF

    if [ $? -eq 0 ]; then
        echo "Arquivo /etc/resolv.conf configurado com sucesso."
    else
        echo "Falha ao configurar o arquivo /etc/resolv.conf."
    fi

    # Configuração do hosts
    sudo bash -c "cat > ${HOSTS_CONF}" <<EOF
127.0.0.1       localhost
${IP}           ${SERVER}.${DOMAIN} ${SERVER}
EOF

    if [ $? -eq 0 ]; then
        echo "Arquivo /etc/hosts configurado com sucesso."
    else
        echo "Falha ao configurar o arquivo /etc/hosts."
    fi
       # Configuração do hostname
    sudo bash -c "cat > /etc/hostname" <<EOF
 ${SERVER}
EOF

    if [ $? -eq 0 ]; then
        echo "Arquivo /etc/hostname configurado com sucesso."
    else
        echo "Falha ao configurar o arquivo /etc/hostname."
    fi
    sudo systemctl restart systemd-resolved
}

# Função para configurar o netplan
configure_netplan() {
    echo "Configurando netplan..."
    sudo bash -c "cat > ${NETPLAN_CONF}" <<EOF
network:
    version: 2
    ethernets:
        ${INTERFACE_NAME_wan}:
            addresses:
                - ${IP_wan}/24
            dhcp4: false
            optional: true
            nameservers:
                addresses:
                    - 127.0.0.1
                    - ${DNS_GOOGLE}
            routes:
                - to: default
                  via: ${GATEWAY_wan}
         ${INTERFACE_NAME}:
            addresses:
                - ${IP}/24
            dhcp4: false
EOF
    sudo netplan apply
}

# Função para parar e remover pacotes antigos
remove_packages() {
    echo "Removendo pacotes antigos..."
    sudo systemctl stop smbd squid nmbd winbind
    sudo systemctl disable smbd squid nmbd winbind
     if [ $? -eq 0 ]; then
        echo "Serviços parados e desativados com sucesso."
    else
        echo "Falha ao parar e desativar os serviços."
    fi
    sudo apt-get remove --purge -y samba samba-common-bin krb5-kdc krb5-admin-server \
        winbind libpam-winbind libnss-winbind libpam-krb5 libpam-mkhomedir \
        libpam-mount bind9 bind9utils bind9-doc squid krb5-user libkrb5-dev ssl-cert
      if [ $? -eq 0 ]; then
        echo "Pacotes removidos com sucesso."
    else
        echo "Falha ao remover pacotes."
    fi
    sudo apt-get autoremove -y
    sudo rm -rf /var/lib/samba /etc/samba /var/lib/krb5kdc /etc/squid /etc/krb5kdc /var/lib/bind /etc/bind /etc/krb5.conf 
   if [ $? -eq 0 ]; then
        echo "Dados removidos com sucesso."
    else
        echo "Falha ao remover dados."
    fi
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
        kdc = ${IP}
        admin_server = ${IP}
    }

[domain_realm]
    .${DOMAIN} = ${UPPER_DOMAIN}
    ${DOMAIN} = ${UPPER_DOMAIN}
EOF
   sudo systemctl stop smbd squid nmbd winbind
    sudo systemctl disable smbd squid nmbd winbind
    sudo systemctl unmask samba-ad-dc

sudo chmod 640 /var/lib/samba/private/dns.keytab
sudo chown root:bind /var/lib/samba/private/dns.keytab

sudo chmod 770 /var/lib/samba/bind-dns/
sudo chown root:bind /var/lib/samba/bind-dns/
sudo chown root:bind /var/lib/samba/bind-dns/dns.keytab

sudo chmod 770 /var/lib/samba/bind-dns/dns/
sudo chown root:bind /var/lib/samba/bind-dns/dns/


sudo chown root:bind /etc/krb5.conf

}

# Função para configurar o Bind
configure_bind() {
    echo "Configurando Bind..."
    sudo mkdir -p /var/lib/samba/bind-dns
    sudo cp ${PRIVATE_KEYTAB_FILE} ${BIND_KEYTAB_FILE}
    sudo bash -c "cat > ${BIND_CONF_DIR}/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";
    tkey-gssapi-keytab "${BIND_KEYTAB_FILE}";
    minimal-responses yes;
    // Configuração de DNS recursivo
    recursion yes;
    forwarders {
        ${DNS_GOOGLE};
         8.8.4.4;
    };

    dnssec-validation auto;
    auth-nxdomain no;
    listen-on-v6 { any; };
    listen-on { any; };
    allow-query { any; };
    allow-transfer { any; };
    allow-update {
        key "rndc-key";
    };
};
EOF
      sudo chown root:bind "${BIND_KEYTAB_FILE}";

    # Identificar a versão do BIND9
    echo "Identificando a versão do BIND9..."
    BIND_VERSION=$(named -v | grep -oP '\d+\.\d+')

    # Descomentar a linha no arquivo /var/lib/samba/bind-dns/named.conf
    sudo sed -i '/^#.*dlopen.*dlz_bind9.*so/s/^#//' /var/lib/samba/bind-dns/named.conf

   sudo bash -c "echo 'include \"/var/lib/samba/bind-dns/named.conf\";' >> '${BIND_CONF_DIR}/named.conf.local'"

    # Verificar configuração e reiniciar BIND9
    echo "Verificando a configuração do BIND9..."

    echo "Reiniciando o BIND9..."
    sudo systemctl restart bind9
    if [ $? -eq 0 ]; then
        echo "BIND configurado e reiniciado com sucesso."
    else
        echo "Falha ao configurar e reiniciar o BIND."
       
    fi

    # Atualizar e configurar o DNS no Samba
    echo "Atualizando DNS no Samba..."
    sudo samba_upgradedns --dns-backend=BIND9_DLZ
    sudo systemctl restart bind9
    sudo systemctl enable bind9

    echo "Configuração do BIND9 concluída com sucesso."
}

# Função para configurar o Squid com autenticação Kerberos
configure_squid() {
    echo "Configurando Squid com autenticação Kerberos..."

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

acl rede_interna src ${NETWORK}
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

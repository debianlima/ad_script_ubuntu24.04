#!/bin/bash

# ================================================
# Variáveis Iniciais
# ================================================

# Configurações de Rede
NETWORK="172.16.0.0/24"         # Rede principal
SUBNET_MASK="255.255.255.0"    # Máscara de sub-rede
IP_LAN="172.16.0.1"            # IP da LAN
GATEWAY_LAN="172.16.0.1"       # Gateway da LAN
INTERFACE_WAN="ens33"          # Interface WAN
INTERFACE_LAN="ens37"          # Interface LAN

# Configurações de DNS
DNS_SERVERS="172.16.0.252"     # Servidor DNS primário
DNS_SERVERS_2="172.16.0.251"   # Servidor DNS secundário
DNS_GOOGLE="8.8.8.8"           # Servidor DNS do Google

# Configurações do Domínio
DOMAIN="lima.internet"         # Domínio principal
UPPER_DOMAIN=${DOMAIN^^}       # Domínio em maiúsculas
HOSTNAME="serverfire"          # Nome do host
HOSTNAME_AD="server"           # Nome do host para o Active Directory

# Configurações do Samba
SAMBA_CONF_DIR="/etc/samba"                     # Diretório de configuração do Samba
PRIVATE_KEYTAB_FILE="/var/lib/samba/private/dns.keytab"  # Arquivo de chave Kerberos para o Samba

# Configurações do BIND
BIND_CONF_DIR="/etc/bind"                      # Diretório de configuração do BIND
ZONE_DIR="/var/lib/samba/bind-dns/dns/"        # Diretório das zonas DNS
ZONE_FILE="${ZONE_DIR}${DOMAIN}.zone"          # Arquivo de zona DNS

# Configurações do Squid
SQUID_CONF="/etc/squid/squid.conf"             # Arquivo de configuração do Squid

# Configurações do DHCP
DHCP_CONF="/etc/dhcp/dhcpd.conf"                # Arquivo de configuração do DHCP
DHCP_RANGE_START="172.16.0.10"                 # Início do intervalo DHCP
DHCP_RANGE_END="172.16.0.200"                  # Fim do intervalo DHCP

# Configurações do Sistema
NETPLAN_CONF="/etc/netplan/50-cloud-init.yaml" # Arquivo de configuração do Netplan
RESOLV_CONF="/etc/resolv.conf"                  # Arquivo de configuração do DNS
HOSTS_CONF="/etc/hosts"                        # Arquivo de hosts
RESOLVED_CONF="/etc/systemd/resolved.conf"     # Arquivo de configuração do resolved

# ================================================
# Função para Remover Pacotes e Arquivos de Configuração
# ================================================

remove_packages() {
    echo "Removendo pacotes e arquivos de configuração..."
    
    # Lista de pacotes a serem removidos
    local packages=("bind9" "samba" "squid" "isc-dhcp-server" "krb5-user" "krb5-config" "winbind")

    for pkg in "${packages[@]}"; do
        sudo apt-get remove --purge -y $pkg
        sudo apt-get autoremove --purge -y
    done

    # Remove arquivos de configuração residuais
    sudo rm -rf /etc/bind /etc/samba /etc/squid /etc/dhcp /var/lib/samba
}

# ================================================
# Função para Instalar Pacotes Necessários
# ================================================

install_packages() {
    echo "Instalando pacotes necessários..."
    
    # Atualiza a lista de pacotes
    sudo apt-get update

    # Lista de pacotes a serem instalados
    local packages=("bind9" "samba" "squid" "isc-dhcp-server" "krb5-user" "krb5-config" "winbind")

    for pkg in "${packages[@]}"; do
        sudo apt-get install -y $pkg
    done
}

# ================================================
# Função para Configurar Variáveis Dinâmicas
# ================================================

configure_variables() {
    echo "Configurando variáveis dinâmicas..."

    # Define as variáveis de rede e DNS com base nas configurações fornecidas
    NETWORK="${NETWORK}"
    DNS_SERVERS="${DNS_SERVERS}"
    DNS_SERVERS_2="${DNS_SERVERS_2}"
    DOMAIN="${DOMAIN}"
    IP_LAN="${IP_LAN}"
    GATEWAY_LAN="${GATEWAY_LAN}"
    DHCP_RANGE_START="${DHCP_RANGE_START}"
    DHCP_RANGE_END="${DHCP_RANGE_END}"
}

# ================================================
# Função para Atualizar o Sistema
# ================================================

update_system() {
    echo "Atualizando o sistema..."
    sudo apt-get update
    sudo apt-get upgrade -y
}

# ================================================
# Função para Configurar o Netplan
# ================================================

configure_netplan() {
    echo "Configurando Netplan..."
    sudo bash -c "cat > ${NETPLAN_CONF}" <<EOF
network:
  version: 2
  ethernets:
    ${INTERFACE_WAN}:
      dhcp4: true
    ${INTERFACE_LAN}:
      addresses:
        - ${IP_LAN}/24
      dhcp4: false
EOF
    sudo netplan apply
}

# ================================================
# Função para Configurar /etc/resolv.conf e /etc/hosts
# ================================================

configure_network_files() {
    echo "Configurando /etc/resolv.conf e /etc/hosts..."
    sudo bash -c "cat > ${RESOLV_CONF}" <<EOF
[Resolve]
DNS=${DNS_SERVERS}
FallbackDNS=${DNS_GOOGLE}
Domains=${DOMAIN}
EOF
    sudo bash -c "cat > ${HOSTS_CONF}" <<EOF
127.0.0.1       localhost
${IP_LAN}       ${HOSTNAME}.${DOMAIN} ${HOSTNAME}
${DNS_SERVERS}  ${HOSTNAME_AD}.${DOMAIN} ${HOSTNAME_AD}
EOF
    sudo bash -c "echo '${HOSTNAME}' > /etc/hostname"
}

# ================================================
# Função para Configurar o Firewall, NAT e Squid
# ================================================

configure_firewall() {
    echo "Configurando firewall, NAT e Squid com Kerberos..."
    
    # Configura o roteamento de pacotes
    sudo bash -c "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
    sudo sysctl -p

    # Configura o firewall com iptables
    sudo bash -c "cat > /etc/init.d/firewall.sh" <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:          firewall
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Configurações do firewall
# Description:       Configurações de firewall usando iptables
### END INIT INFO

# Regras de firewall usando iptables
iptables -t nat -A POSTROUTING -o ${INTERFACE_WAN} -j MASQUERADE
iptables -A FORWARD -i ${INTERFACE_WAN} -o ${INTERFACE_LAN} -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${INTERFACE_LAN} -o ${INTERFACE_WAN} -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # Permitir SSH
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT  # Permitir Squid
iptables -A INPUT -i lo -j ACCEPT  # Permitir loopback
iptables -A INPUT -j DROP  # Bloquear tudo o mais
EOF

    sudo chmod +x /etc/init.d/firewall.sh
    sudo update-rc.d firewall.sh defaults
    sudo service firewall.sh start

    # Configura o Squid com Kerberos
    sudo bash -c "cat > ${SQUID_CONF}" <<EOF
http_port 3128
auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -s HTTP/${HOSTNAME}.${DOMAIN}@${UPPER_DOMAIN}
auth_param negotiate children 10
auth_param negotiate keep_alive on
acl kerberos-auth proxy_auth REQUIRED
http_access allow kerberos-auth
http_access deny all
access_log /var/log/squid/access.log squid
EOF

    sudo systemctl restart squid

    # Configura a chave Kerberos
    sudo kinit administrator@${UPPER_DOMAIN}
    sudo net ads join -U Administrator%${ADMIN_PASSWORD}
    sudo net ads keytab create
}

# ================================================
# Função para Configurar o DHCP
# ================================================

configure_dhcp() {
    echo "Configurando o servidor DHCP..."
    sudo bash -c "cat > ${DHCP_CONF}" <<EOF
# Configuração do servidor DHCP
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet ${NETWORK} netmask ${SUBNET_MASK} {
    range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
    option domain-name-servers ${DNS_SERVERS}, ${DNS_SERVERS_2};
    option routers ${IP_LAN};
    option broadcast-address ${NETWORK};
}
EOF
    sudo systemctl restart isc-dhcp-server
}

# ================================================
# Função para Configurar o Samba e Active Directory
# ================================================

configure_samba() {
    echo "Configurando o Samba e Active Directory..."
    sudo bash -c "cat > ${SAMBA_CONF_DIR}/smb.conf" <<EOF
[global]
   workgroup = ${UPPER_DOMAIN}
   server string = %h server (Samba, Ubuntu)
   netbios name = ${HOSTNAME_AD}
   security = ADS
   realm = ${UPPER_DOMAIN}
   password server = ${HOSTNAME_AD}.${DOMAIN}
   idmap config *:backend = tdb
   idmap config *:range = 1000000-1999999
   idmap config ${UPPER_DOMAIN}:backend = ad
   idmap config ${UPPER_DOMAIN}:range = 10000-999999
   idmap config ${UPPER_DOMAIN}:schema_mode = rfc2307
   template homedir = /home/%U
   template shell = /bin/bash
   kerberos method = secrets and keytab
   dns forwarder = ${DNS_SERVERS}

[netlogon]
   path = /var/lib/samba/sysvol/${DOMAIN}/scripts
   read only = yes

[sysvol]
   path = /var/lib/samba/sysvol
   read only = yes
EOF
    sudo systemctl restart samba-ad-dc
}

# ================================================
# Função para Configurar o BIND
# ================================================

configure_bind() {
    echo "Configurando o BIND..."
    sudo bash -c "cat > ${BIND_CONF_DIR}/named.conf.local" <<EOF
zone \"${DOMAIN}\" {
    type master;
    file \"${ZONE_FILE}\";
};
EOF
    sudo bash -c "cat > ${ZONE_FILE}" <<EOF
\$TTL 86400
@   IN  SOA ${HOSTNAME}.${DOMAIN}. admin.${DOMAIN}. (
                2024090201         ; Serial
                3600               ; Refresh
                1800               ; Retry
                1209600            ; Expire
                86400 )            ; Minimum TTL

@   IN  NS  ${HOSTNAME}.${DOMAIN}.
@   IN  A   ${IP_LAN}
EOF
    sudo systemctl restart bind9
}

# ================================================
# Execução das Funções
# ================================================

remove_packages
install_packages
configure_variables
update_system
configure_netplan
configure_network_files
configure_firewall
configure_dhcp
configure_samba
configure_bind

echo "Instalação e configuração concluídas!"

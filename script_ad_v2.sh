#!/bin/bash
#não esquecer de verificar a rota no gw da rede local para o dns
# Variáveis
DOMAIN="lima.internet"
UPPER_DOMAIN=${DOMAIN^^}
ADMIN_PASSWORD="abc@1234"  # Variável personalizável para a senha do administrador
SAMBA_CONF_DIR="/etc/samba"
BIND_CONF_DIR="/etc/bind"
RESOLV_CONF="/etc/resolv.conf"
HOSTS_CONF="/etc/hosts"
PRIVATE_KEYTAB_FILE="/var/lib/samba/private/dns.keytab"
BIND_KEYTAB_FILE="/var/lib/samba/bind-dns/dns.keytab"

# Defina o caminho do arquivo de zona
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

# Caminho para o arquivo de configuração do systemd-resolved
RESOLVED_CONF="/etc/systemd/resolved.conf"
# Define o conteúdo da configuração do systemd-resolved
RESOLVED_CONF_CONTENT="[Resolve]
DNS=127.0.0.1
FallbackDNS=172.16.0.252
Domains=lima.internet"

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

# Função para configurar resolv.conf e hosts com DNS do Google
configure_network_files2() {
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
}

# Função para parar e remover pacotes e dados
remove_packages() {
    echo "Parando e removendo pacotes Samba, Kerberos, Winbind, PAM libs e BIND9..."

    sudo systemctl stop smbd nmbd winbind
    sudo systemctl disable smbd nmbd winbind
    if [ $? -eq 0 ]; then
        echo "Serviços parados e desativados com sucesso."
    else
        echo "Falha ao parar e desativar os serviços."
    fi

    sudo apt-get remove --purge -y samba samba-common-bin krb5-kdc krb5-admin-server winbind libpam-winbind libnss-winbind libpam-krb5 libpam-mkhomedir libpam-mount bind9 bind9utils bind9-doc
    if [ $? -eq 0 ]; then
        echo "Pacotes removidos com sucesso."
    else
        echo "Falha ao remover pacotes."
    fi

    sudo apt-get autoremove -y
    sudo rm -rf /var/lib/samba /etc/samba /var/lib/krb5kdc /etc/krb5kdc /var/lib/bind /etc/bind /etc/krb5.conf 
    if [ $? -eq 0 ]; then
        echo "Dados removidos com sucesso."
    else
        echo "Falha ao remover dados."
    fi
}

# Função para reinstalar pacotes
install_packages() {
    echo "Instalando pacotes Samba, Kerberos, Winbind, PAM libs e BIND9..."

    configure_network_files2

    sudo apt-get update
    if [ $? -eq 0 ]; then
        echo "Pacotes atualizados com sucesso."
    else
        echo "Falha ao atualizar pacotes."
    fi

    sudo apt-get install -y samba krb5-kdc krb5-admin-server winbind libpam-winbind libnss-winbind libpam-krb5 libpam-mkhomedir libpam-mount bind9 bind9utils bind9-doc
    if [ $? -eq 0 ]; then
        echo "Pacotes instalados com sucesso."
    else
        echo "Falha ao instalar pacotes."
    fi

    configure_network_files
}

# Função para configurar o Samba
configure_samba() {
    echo "Configurando Samba como controlador de domínio..."

    sudo rm -f ${SAMBA_CONF_DIR}/smb.conf
    sudo samba-tool domain provision --realm=${DOMAIN} --domain=${DOMAIN%%.*} --server-role=dc --dns-backend=BIND9_DLZ --use-rfc2307 --function-level=2008_R2 --adminpass=${ADMIN_PASSWORD}
    if [ $? -eq 0 ]; then
        echo "Domínio provisionado com sucesso."
    else
        echo "Falha ao provisionar o domínio."
    fi

    sudo cp ${SAMBA_CONF_DIR}/smb.conf ${SAMBA_CONF_DIR}/smb.conf.bak
    sudo bash -c "cat > ${SAMBA_CONF_DIR}/smb.conf" <<EOF
[global]
    workgroup = ${DOMAIN%%.*}
    realm = ${DOMAIN}
    netbios name = ${SERVER}
    server services = -dns
    server role = active directory domain controller
    dns forwarder = 127.0.0.1 
    winbind refresh tickets = Yes
    dedicated keytab file = ${PRIVATE_KEYTAB_FILE}
    kerberos method = secrets and keytab
  

    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config $UPPER_DOMAIN : backend = rid
    idmap config $UPPER_DOMAIN : range = 10000-9999999

    winbind use default domain = Yes     
    winbind offline logon = false
    winbind enum users = yes
    winbind enum groups = yes 

    idmap_ldb:use rfc2307 = yes

    # Configuração para criar diretórios home dos usuários
    template homedir = /home/%D/%U
    template shell = /bin/bash
    obey pam restrictions = yes

[sysvol]
    path = /var/lib/samba/sysvol
    read only = no

[netlogon]
    path = /var/lib/samba/sysvol/${DOMAIN}/scripts
    read only = no

[homes]
    comment = Home Directories
    browseable = no
    read only = no
    create mask = 0700
    directory mask = 0700

[printers]
    comment = All Printers
    path = /var/spool/samba
    browseable = no
    printable = yes

[print$]
    comment = Printer Drivers
    path = /var/lib/samba/printers
EOF

    # Força winbind para recarregar o arquivo de configuração alterado.
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
    forwardable = yes
    ticket_lifetime = 24h

[realms]
    ${UPPER_DOMAIN} = {
        kdc = ${IP}
        admin_server = ${IP}
    }

[domain_realm]
    .${DOMAIN} = ${UPPER_DOMAIN}
    ${DOMAIN} = ${UPPER_DOMAIN}
EOF
    sudo systemctl stop smbd nmbd winbind
    sudo systemctl disable smbd nmbd winbind
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

# Função para configurar o BIND9
configure_bind() {

    echo "Configurando BIND9..."

    # Criar zonas diretas
   # sudo samba-tool dns zonecreate ${SERVER} ${DOMAIN} -U administrator
   # sudo samba-tool dns add ${SERVER} ${DOMAIN} ${SERVER} A ${IP} -U administrator

    # Configurar named.conf.options
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
    sudo chmod 640 "${BIND_KEYTAB_FILE}";

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




   

# Função para iniciar o Samba como controlador de domínio
start_samba() {
    echo "Iniciando Samba como controlador de domínio..."
    sudo systemctl restart named 
    sudo systemctl restart samba-ad-dc
    sudo systemctl enable samba-ad-dc
    sudo systemctl status samba-ad-dc
    if [ $? -eq 0 ]; then
        echo "Samba iniciado e habilitado com sucesso."
    else
        echo "Falha ao iniciar e habilitar o Samba."
    fi
}

# Função para configurar a rede
configure_network() {
    echo "Configurando o Netplan..."

    # Verifica se o arquivo Netplan já existe e cria uma cópia de segurança
    if [ -f "$NETPLAN_CONF" ]; then
        echo "Criando uma cópia de segurança do arquivo Netplan existente..."
        sudo cp "$NETPLAN_CONF" "$NETPLAN_CONF.bak"
    fi

    # Configura o arquivo Netplan com os dados fornecidos
    echo "Atualizando o arquivo de configuração $NETPLAN_CONF..."
    sudo bash -c "cat > $NETPLAN_CONF" <<EOF
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
                    - ${DNS_GOOGLE}
            routes:
                - to: default
                  via: ${GATEWAY_wan}
        ${INTERFACE_NAME}:
            addresses:
                - ${IP}/24
            dhcp4: false
EOF

    # Aplica a nova configuração do Netplan
    echo "Aplicando a configuração do Netplan..."
    sudo netplan apply

    # Verifica se a configuração foi aplicada com sucesso
    if [ $? -eq 0 ]; then
        echo "Configuração do Netplan aplicada com sucesso."
    else
        echo "Falha ao aplicar a configuração do Netplan."
    fi
}


# Configura o systemd-resolved
configure_resolved() {
   
  # Cria uma cópia de segurança do arquivo de configuração existente
	if [ -f "$RESOLVED_CONF" ]; then
    		echo "Criando cópia de segurança do arquivo de configuração existente..."
	        cp "$RESOLVED_CONF" "$RESOLVED_CONF.bak"
	fi

	# Escreve o conteúdo no arquivo de configuração
	echo "Atualizando o arquivo de configuração $RESOLVED_CONF..."
	echo "$RESOLVED_CONF_CONTENT" | sudo tee "$RESOLVED_CONF" > /dev/null

	      
         sudo rm -f /etc/resolv.conf
         sudo ln -sv /run/systemd/resolve/resolv.conf /etc/resolv.conf

   	# Reinicia o serviço systemd-resolved
	echo "Reiniciando o serviço systemd-resolved..."
	sudo systemctl restart systemd-resolved

	# Verifica o status do systemd-resolved
	echo "Verificando o status do serviço systemd-resolved..."
	systemd-resolve --status

        echo "Configuração concluída."
}
# Função para abrir todos os arquivos alterados
open_modified_files() {
    echo "Abrindo arquivos modificados..."

    # Arquivos modificados no script
    FILES_TO_OPEN=(
        "/etc/resolv.conf"
	"/etc/netplan/01-netcfg.yaml"
        "/etc/hosts"
	"/etc/hostname"
        "/etc/krb5.conf"
        "/etc/samba/smb.conf"
        "/etc/systemd/resolved.conf"
        "/etc/bind/named.conf.options"
        "/etc/bind/named.conf"
        "/var/lib/samba/bind-dns/dns/${DOMAIN}.zone"
        "/var/lib/samba/private/dns.keytab"
        "/var/lib/samba/bind-dns/dns.keytab"
        "/etc/pam.d/common-session"
    )

    # Abre os arquivos no editor especificado
    for FILE in "${FILES_TO_OPEN[@]}"; do
        if [ -f "$FILE" ]; then
            echo "Abrindo $FILE..."
            sudo nano "$FILE"
        else
            echo "Arquivo $FILE não encontrado."
        fi
    done
}


# Função para listar permissões dos arquivos e diretórios
list_permissions() {
    echo "Listando permissões dos arquivos e diretórios modificados..."

    # Arquivos e diretórios modificados
    ITEMS_TO_CHECK=(
        "/etc/resolv.conf"
        "/etc/netplan/01-netcfg.yaml"
        "/etc/hosts"
        "/etc/krb5.conf"
        "/etc/samba/smb.conf"
        "/etc/systemd/resolved.conf"
        "/var/lib/samba/bind-dns/named.conf"
        "/etc/bind/named.conf.options"
        "/var/lib/samba/bind-dns/dns/${DOMAIN}.zone"
        "/var/lib/samba/private/dns.keytab"
        "/var/lib/samba/bind-dns/dns.keytab"
        "/var/lib/samba/sysvol"
        "/var/lib/samba/sysvol/${DOMAIN}/scripts"
        "/var/spool/samba"
        "/var/lib/samba/printers"
    )

    # Lista as permissões de cada item
    for ITEM in "${ITEMS_TO_CHECK[@]}"; do
        if [ -e "$ITEM" ]; then
            echo "Permissões de $ITEM:"
            ls -ld "$ITEM"
        else
            echo "Arquivo ou diretório $ITEM não encontrado."
        fi
    done
}

# Função para habilitar a criação automática de diretórios home
create_home_directories() {
    echo "Habilitando a criação automática de diretórios home..."
    sudo pam-auth-update --enable winbind
    sudo pam-auth-update --enable mkhomedir 
  
 }



# Função principal para execução das etapas
main() {
    configure_network
    update_system
    remove_packages
    install_packages

    configure_samba
    configure_kerberos
    configure_bind
    configure_resolved
    start samba
    pause    
    create_home_directories
    open_modified_files
    pause
    list_permissions
   echo "finalizado" 
   pause
   sudo reboot

}

# Executa a função principal
main

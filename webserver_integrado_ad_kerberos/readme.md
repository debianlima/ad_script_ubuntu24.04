# Integração do Apache, FTP e MySQL com Active Directory Existente

Este repositório contém um script Bash que integra o Apache, FTP e MySQL com um Active Directory (AD) já configurado. O objetivo é garantir que cada usuário do AD tenha sua própria página web, banco de dados e acesso FTP, com melhorias de segurança.

## Índice

- [Descrição Geral](#descrição-geral)
- [Tecnologias Utilizadas](#tecnologias-utilizadas)
- [Pré-requisitos](#pré-requisitos)
- [Instruções de Uso](#instruções-de-uso)
- [Detalhamento do Script](#detalhamento-do-script)
  - [1. Atualização do Sistema](#1-atualização-do-sistema)
  - [2. Instalação de Pacotes Necessários](#2-instalação-de-pacotes-necessários)
  - [3. Configuração do Kerberos](#3-configuração-do-kerberos)
  - [4. Configuração do Winbind](#4-configuração-do-winbind)
  - [5. Configuração do Apache](#5-configuração-do-apache)
  - [6. Configuração do vsftpd](#6-configuração-do-vsftpd)
  - [7. Configuração do MySQL](#7-configuração-do-mysql)
  - [8. Criação do Script de Banco de Dados para Usuários](#8-criação-do-script-de-banco-de-dados-para-usuários)
  - [9. Configuração do phpMyAdmin](#9-configuração-do-phpmyadmin)
- [Considerações de Segurança](#considerações-de-segurança)
- [Testes e Validação](#testes-e-validação)
- [Contribuição](#contribuição)
- [Licença](#licença)

## Descrição Geral

O script automatiza a integração dos serviços Apache, FTP e MySQL com um Active Directory existente. Isso permite que usuários do AD:

- Acessem uma página pessoal via `http://seu_dominio/~usuario`.
- Tenham um banco de dados individual criado automaticamente.
- Acessem seus diretórios pessoais via FTP.

## Tecnologias Utilizadas

- **Bash Script**: Automação das configurações.
- **Active Directory (AD)**: Gerenciamento centralizado de usuários.
- **Kerberos**: Autenticação segura.
- **Winbind**: Integração de serviços Linux com o AD.
- **Apache2**: Servidor web.
- **vsftpd**: Servidor FTP.
- **MySQL**: Banco de dados relacional.
- **phpMyAdmin**: Interface web para gerenciamento do MySQL.
- **PAM (Pluggable Authentication Modules)**: Módulos de autenticação para Linux.

## Pré-requisitos

- Servidor Linux (preferencialmente Ubuntu/Debian).
- Active Directory já configurado e funcional.
- Acesso administrativo ao servidor.
- Conhecimento básico em administração de sistemas Linux.

## Instruções de Uso

1. **Clone o Repositório ou Copie o Script:**

   ```bash
   git clone https://github.com/seu_usuario/seu_repositorio.git
   cd seu_repositorio
   ```

2. **Edite o Script e Configure as Variáveis:**

   Antes de executar o script, abra-o em um editor de texto e ajuste as variáveis conforme o seu ambiente:

   ```bash
   nano integracao_ad.sh
   ```

   Variáveis a serem ajustadas:

   - `DOMAIN`: Seu domínio AD (e.g., `lima.internet`).
   - `ADMIN_USER`: Usuário administrador do AD (e.g., `administrator`).
   - `SERVER_IP`: IP do seu servidor AD.
   - Outras variáveis conforme necessário.

3. **Dê Permissão de Execução ao Script:**

   ```bash
   chmod +x integracao_ad.sh
   ```

4. **Execute o Script:**

   ```bash
   sudo ./integracao_ad.sh
   ```

   O script solicitará senhas e interações durante a execução. Siga as instruções atentamente.

## Detalhamento do Script

### 1. Atualização do Sistema

```bash
update_system() {
    echo "Atualizando o sistema..."
    sudo apt-get update && sudo apt-get upgrade -y
}
```

- **Objetivo:** Garantir que todos os pacotes instalados estejam atualizados para evitar incompatibilidades e vulnerabilidades.

### 2. Instalação de Pacotes Necessários

```bash
install_packages() {
    echo "Instalando pacotes necessários..."
    sudo apt-get install -y libpam-winbind libnss-winbind krb5-user samba-common-bin \
        apache2 libapache2-mod-auth-kerb vsftpd mysql-server libpam-mysql \
        php php-mysql phpmyadmin
}
```

- **Pacotes Instalados:**
  - **libpam-winbind & libnss-winbind:** Integração com o AD.
  - **krb5-user:** Cliente Kerberos para autenticação.
  - **samba-common-bin:** Ferramentas do Samba para integração com AD.
  - **apache2 & libapache2-mod-auth-kerb:** Servidor web e módulo de autenticação Kerberos.
  - **vsftpd:** Servidor FTP.
  - **mysql-server & libpam-mysql:** Banco de dados MySQL e integração com PAM.
  - **php & php-mysql:** Suporte PHP para web.
  - **phpMyAdmin:** Interface web para gerenciar o MySQL.

### 3. Configuração do Kerberos

```bash
configure_kerberos() {
    echo "Configurando Kerberos..."
    sudo bash -c "cat > /etc/krb5.conf" <<EOF
    [libdefaults]
        default_realm = ${KERBEROS_REALM}
        ...
EOF
}
```

- **Objetivo:** Configurar o cliente Kerberos para autenticar usuários no AD.
- **Arquivo Configurado:** `/etc/krb5.conf`
- **Parâmetros Importantes:**
  - `default_realm`: Define o domínio padrão para autenticação.

### 4. Configuração do Winbind

```bash
configure_winbind() {
    echo "Configurando Winbind..."
    ...
    # Adiciona o servidor ao domínio AD
    echo "Adicionando este servidor ao domínio AD..."
    sudo net ads join -U ${ADMIN_USER}
}
```

- **Objetivo:** Permitir que o sistema reconheça e autentique usuários do AD.
- **Arquivos Configurados:**
  - `/etc/nsswitch.conf`: Define a ordem dos serviços de nome (inclui winbind).
- **Comando Importante:**
  - `net ads join`: Adiciona o servidor ao domínio AD.

### 5. Configuração do Apache

```bash
configure_apache() {
    echo "Configurando Apache para autenticação com Kerberos e diretórios pessoais..."
    ...
    sudo systemctl restart apache2
}
```

- **Objetivo:** Permitir que usuários do AD acessem seus diretórios pessoais via web com autenticação Kerberos.
- **Módulos Habilitados:**
  - `userdir`: Permite diretórios pessoais (`~usuario`).
  - `auth_kerb`: Habilita autenticação Kerberos.
- **Arquivos Configurados:**
  - `/etc/apache2/mods-available/userdir.conf`: Configurações do módulo `userdir`.
  - `/etc/apache2/sites-available/000-default.conf`: Site padrão com autenticação Kerberos.

### 6. Configuração do vsftpd

```bash
configure_vsftpd() {
    echo "Configurando vsftpd para autenticação com o AD..."
    ...
    sudo systemctl restart vsftpd
}
```

- **Objetivo:** Permitir que usuários do AD acessem seus diretórios pessoais via FTP.
- **Arquivos Configurados:**
  - `/etc/vsftpd.conf`: Configurações do vsftpd.
  - `/etc/pam.d/vsftpd`: Integração do vsftpd com PAM/Winbind.

### 7. Configuração do MySQL

```bash
configure_mysql() {
    echo "Configurando MySQL para autenticação PAM..."
    ...
    sudo systemctl restart mysql
}
```

- **Objetivo:** Permitir que usuários do AD autentiquem no MySQL e tenham bancos de dados individuais.
- **Passos Realizados:**
  - Configuração segura do MySQL (`mysql_secure_installation`).
  - Instalação do plugin `auth_pam` para autenticação via PAM.
  - Criação do usuário `ad_users` com autenticação PAM.
- **Arquivo Configurado:**
  - `/etc/pam.d/mysqld`: Integração do MySQL com PAM/Winbind.

### 8. Criação do Script de Banco de Dados para Usuários

```bash
create_user_db_script() {
    echo "Criando script para criação automática de bancos de dados..."
    ...
}
```

- **Objetivo:** Automatizar a criação de bancos de dados individuais para cada usuário do AD.
- **Funcionamento:**
  - O script é executado sempre que um usuário inicia uma sessão.
  - Cria um banco de dados e um usuário MySQL com senha aleatória.
  - Salva as credenciais em `/home/usuario/db_credentials.txt` com permissões restritas.
- **Integração com PAM:**
  - Adiciona uma linha em `/etc/pam.d/common-session` para executar o script.

### 9. Configuração do phpMyAdmin

```bash
configure_phpmyadmin() {
    echo "Configurando phpMyAdmin..."
    ...
    sudo systemctl restart apache2
}
```

- **Objetivo:** Fornecer uma interface web para que os usuários gerenciem seus bancos de dados.
- **Configurações Realizadas:**
  - Cria um link simbólico para o phpMyAdmin em `/var/www/html/phpmyadmin`.
  - Ajusta as permissões para o Apache acessar o phpMyAdmin.

## Considerações de Segurança

- **Senhas:** O script solicita senhas durante a execução. Use senhas fortes e não as compartilhe.
- **Permissões:** As credenciais dos bancos de dados são armazenadas com permissões `600` para garantir que apenas o usuário possa acessá-las.
- **Autenticação Segura:** Utiliza Kerberos e PAM para autenticação, garantindo segurança nas comunicações.
- **Atualizações:** Mantenha o sistema sempre atualizado para corrigir possíveis vulnerabilidades.

## Testes e Validação

Após a execução do script, realize os seguintes testes:

1. **Login de Usuário do AD:**
   - Faça login no servidor ou via SSH com um usuário do AD.
   - Verifique se o diretório `/home/usuario` foi criado.

2. **Acesso Web:**
   - Crie o diretório `public_html` no home do usuário:
     ```bash
     mkdir /home/usuario/public_html
     ```
   - Adicione um arquivo `index.html`:
     ```bash
     echo "<h1>Bem-vindo, usuario!</h1>" > /home/usuario/public_html/index.html
     ```
   - Acesse `http://seu_dominio/~usuario` e verifique se é solicitada a autenticação.

3. **Acesso FTP:**
   - Conecte-se ao servidor FTP com o usuário do AD.
   - Verifique se está no diretório `/home/usuario`.

4. **Acesso ao MySQL:**
   - Encontre as credenciais em `/home/usuario/db_credentials.txt`.
   - Conecte-se ao MySQL:
     ```bash
     mysql -u usuario -p
     ```
   - Verifique se tem acesso ao banco de dados `usuario_db`.

5. **Acesso ao phpMyAdmin:**
   - Acesse `http://seu_dominio/phpmyadmin`.
   - Faça login com as credenciais do banco de dados.

## Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou enviar pull requests.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---

**Nota:** Este script deve ser usado com cautela. Certifique-se de entender cada etapa antes de executar em um ambiente de produção.

# Comentários Finais

Este script fornece uma integração completa entre serviços Linux e um Active Directory existente, permitindo uma experiência unificada para os usuários. Com autenticação centralizada e recursos automatizados, simplifica-se a gestão de usuários e serviços.

**Importante:** Sempre teste em um ambiente controlado antes de aplicar em produção. A segurança e integridade dos dados são primordiais.

---

**Autor:** [Seu Nome](https://github.com/seu_usuario)

**Contato:** [email@exemplo.com](mailto:email@exemplo.com)

---

**Changelog:**

- **v1.0.0**
  - Primeira versão do script e documentação.

---

**Referências:**

- [Documentação do Samba](https://www.samba.org/samba/docs/)
- [Apache Module mod_auth_kerb](https://modauthkerb.sourceforge.net/)
- [Winbind Manual](https://www.samba.org/samba/docs/current/man-html/winbindd.8.html)
- [vsftpd Documentation](https://security.appspot.com/vsftpd.html)
- [MySQL PAM Authentication Plugin](https://dev.mysql.com/doc/refman/8.0/en/pam-authentication-plugin.html)
- [phpMyAdmin Official Site](https://www.phpmyadmin.net/)

---

**Palavras-chave:** Active Directory, Apache, FTP, MySQL, Kerberos, Winbind, PAM, Linux Integration, User Automation.

---

**Agradecimentos:**

Agradeço a todos que contribuíram para o desenvolvimento e melhoria deste script e documentação.

---

# Anexos

## Código Completo do Script

```bash
#!/bin/bash

# Script para integrar Apache, FTP e MySQL com o Active Directory existente
# Garantindo que cada usuário tenha sua própria página, banco de dados e acesso FTP
# Com melhorias de segurança

# Definição de variáveis
DOMAIN="lima.internet"
UPPER_DOMAIN=${DOMAIN^^}
ADMIN_USER="administrator"
SERVER_IP="172.16.0.252"  # IP do servidor AD
KERBEROS_REALM=${UPPER_DOMAIN}
SAMBA_DOMAIN=${DOMAIN%%.*}
DNS_SERVER="127.0.0.1"

# Função para atualizar o sistema
update_system() {
    echo "Atualizando o sistema..."
    sudo apt-get update && sudo apt-get upgrade -y
}

# Função para instalar pacotes necessários
install_packages() {
    echo "Instalando pacotes necessários..."
    sudo apt-get install -y libpam-winbind libnss-winbind krb5-user samba-common-bin \
        apache2 libapache2-mod-auth-kerb vsftpd mysql-server libpam-mysql \
        php php-mysql phpmyadmin
}

# Função para configurar o Kerberos
configure_kerberos() {
    echo "Configurando Kerberos..."
    sudo bash -c "cat > /etc/krb5.conf" <<EOF
[libdefaults]
    default_realm = ${KERBEROS_REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
    ticket_lifetime = 24h
    forwardable = yes

[realms]
    ${KERBEROS_REALM} = {
        kdc = ${SERVER_IP}
        admin_server = ${SERVER_IP}
    }

[domain_realm]
    .${DOMAIN} = ${KERBEROS_REALM}
    ${DOMAIN} = ${KERBEROS_REALM}
EOF
}

# Função para configurar o Winbind
configure_winbind() {
    echo "Configurando Winbind..."
    sudo auth-client-config -t nss -p lac_kerberos_winbind
    sudo bash -c "cat > /etc/nsswitch.conf" <<EOF
passwd:         compat winbind
group:          compat winbind
shadow:         files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

    sudo pam-auth-update --enable mkhomedir --enable winbind

    # Adiciona o servidor ao domínio AD
    echo "Adicionando este servidor ao domínio AD..."
    sudo net ads join -U ${ADMIN_USER}
}

# Função para configurar o Apache
configure_apache() {
    echo "Configurando Apache para autenticação com Kerberos e diretórios pessoais..."

    # Instala o módulo auth_kerb
    sudo apt-get install -y libapache2-mod-auth-kerb

    # Habilita os módulos necessários
    sudo a2enmod userdir
    sudo a2enmod auth_kerb
    sudo systemctl restart apache2

    # Configura o módulo userdir
    sudo bash -c "cat > /etc/apache2/mods-available/userdir.conf" <<EOF
<IfModule mod_userdir.c>
    UserDir public_html
    UserDir disabled root

    <Directory /home/*/public_html>
        AllowOverride All
        Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
        Require all granted
    </Directory>
</IfModule>
EOF

    # Configura o site padrão para usar autenticação Kerberos
    sudo bash -c "cat > /etc/apache2/sites-available/000-default.conf" <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /home/*/public_html>
        AuthType Kerberos
        AuthName "Kerberos Login"
        Krb5Keytab /etc/krb5.keytab
        KrbAuthRealms ${KERBEROS_REALM}
        KrbMethodNegotiate On
        KrbMethodK5Passwd Off
        Require valid-user
        Options Indexes FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # Reinicia o Apache
    sudo systemctl restart apache2
}

# Função para configurar o vsftpd
configure_vsftpd() {
    echo "Configurando vsftpd para autenticação com o AD..."

    sudo bash -c "cat > /etc/vsftpd.conf" <<EOF
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pam_service_name=vsftpd
user_sub_token=\$USER
local_root=/home/\$USER
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF

    # Configura o PAM para o vsftpd
    sudo bash -c "cat > /etc/pam.d/vsftpd" <<EOF
auth    required    pam_winbind.so
account required    pam_winbind.so
session required    pam_mkhomedir.so skel=/etc/skel/ umask=0022
EOF

    # Reinicia o vsftpd
    sudo systemctl restart vsftpd
}

# Função para configurar o MySQL
configure_mysql() {
    echo "Configurando MySQL para autenticação PAM..."

    # Define senha para o usuário root do MySQL
    echo "Por favor, defina uma senha para o usuário root do MySQL:"
    sudo mysql_secure_installation

    # Habilita o plugin auth_pam
    sudo mysql -u root -p -e "INSTALL PLUGIN auth_pam SONAME 'auth_pam.so';"

    # Cria um usuário genérico para autenticação PAM
    sudo mysql -u root -p -e "CREATE USER 'ad_users'@'%' IDENTIFIED WITH auth_pam;"
    sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON *.* TO 'ad_users'@'%' WITH GRANT OPTION;"
    sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

    # Configura o PAM para o MySQL
    sudo bash -c "cat > /etc/pam.d/mysqld" <<EOF
auth    required    pam_winbind.so
account required    pam_winbind.so
EOF

    # Reinicia o MySQL
    sudo systemctl restart mysql
}

# Função para criar script de criação automática de bancos de dados
create_user_db_script() {
    echo "Criando script para criação automática de bancos de dados..."

    sudo bash -c "cat > /usr/local/bin/add_user_db.sh" <<'EOF'
#!/bin/bash
USERNAME=$PAM_USER
DATABASE="${USERNAME}_db"
PASSWORD=$(openssl rand -base64 12)

mysql -u root -p'SUA_SENHA_ROOT_MYSQL' <<MYSQL_EOF
CREATE DATABASE IF NOT EXISTS \`${DATABASE}\`;
CREATE USER IF NOT EXISTS '${USERNAME}'@'localhost' IDENTIFIED BY '${PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DATABASE}\`.* TO '${USERNAME}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF

echo "Banco de dados '${DATABASE}' criado para o usuário '${USERNAME}'." >> /var/log/user_db_creation.log
echo "Senha: ${PASSWORD}" > /home/${USERNAME}/db_credentials.txt
chown ${USERNAME}:${USERNAME} /home/${USERNAME}/db_credentials.txt
chmod 600 /home/${USERNAME}/db_credentials.txt
EOF

    # Substitui 'SUA_SENHA_ROOT_MYSQL' pela senha real
    echo "Por favor, insira a senha do usuário root do MySQL para o script de criação de bancos de dados:"
    read -s MYSQL_ROOT_PASSWORD
    sudo sed -i "s/SUA_SENHA_ROOT_MYSQL/${MYSQL_ROOT_PASSWORD}/g" /usr/local/bin/add_user_db.sh

    sudo chmod +x /usr/local/bin/add_user_db.sh

    # Configura o PAM para executar o script ao criar sessões
    sudo bash -c "echo 'session optional pam_exec.so /usr/local/bin/add_user_db.sh' >> /etc/pam.d/common-session"
}

# Função para configurar o phpMyAdmin
configure_phpmyadmin() {
    echo "Configurando phpMyAdmin..."

    # Configura o Apache para o phpMyAdmin
    sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

    # Ajusta as permissões
    sudo chown -R www-data:www-data /usr/share/phpmyadmin

    # Reinicia o Apache
    sudo systemctl restart apache2
}

# Função principal
main() {
    update_system
    install_packages
    configure_kerberos
    configure_winbind
    configure_apache
    configure_vsftpd
    configure_mysql
    create_user_db_script
    configure_phpmyadmin
    echo "Configuração concluída com sucesso!"
}

# Executa a função principal
main
```

---

Espero que este documento seja útil para você. Caso tenha dúvidas ou precise de assistência adicional, não hesite em entrar em contato.

---

**Disclaimer:** Este script e documentação são fornecidos "como estão", sem garantias de qualquer tipo. O uso é por sua conta e risco.

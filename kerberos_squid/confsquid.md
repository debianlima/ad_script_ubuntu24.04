# Configuração do Squid com Kerberos para Autenticação e Suporte a HTTPS

Este guia mostra como configurar o **Squid** com autenticação **Kerberos** e suporte para HTTPS, incluindo interceptação SSL (SSL Bumping). É uma solução poderosa para ambientes corporativos que necessitam de um proxy seguro e integrado com Active Directory (AD).

---

## 🔗 Link para o Script Completo

O script automatizado para configurar o Kerberos, Squid, BIND e AD pode ser acessado no GitHub:  
[Script Kerberos + Squid + AD](https://github.com/debianlima/ad_script_ubuntu24.04/blob/main/kerberos_squid/script_ad_kerberos_bind_squid.sh)

---

## 📄 Passos de Configuração

### Passo 1: Instalar o Squid e Dependências
1. Atualize os repositórios do sistema:
    ```bash
    sudo apt update
    ```

2. Instale o Squid e os pacotes necessários:
    ```bash
    sudo apt install squid krb5-user libpam-krb5 libkrb5-dev ssl-cert -y
    ```

---

### Passo 2: Configurar o Kerberos

1. Edite o arquivo `/etc/krb5.conf` para refletir as configurações do seu domínio AD:
    ```ini
    [libdefaults]
        default_realm = DOMINIO.AD
        dns_lookup_realm = false
        dns_lookup_kdc = true
    ```

2. Crie o principal de serviço para o Squid no AD:
   
   **Linux:**
    ```bash
    sudo samba-tool user add squiduser senha_do_usuario --given-name="Squid" --surname="User"
    sudo samba-tool user show squiduser
    sudo samba-tool domain exportkeytab /etc/squid/squiduser.keytab --principal=squiduser
    sudo ktutil
    ktutil:  rkt /etc/squid/squiduser.keytab
    ktutil:  list
    ```

   **Windows:**
    ```cmd
    ktpass -princ HTTP/nome_do_servidor@DOMINIO.AD -mapuser usuario_squid@DOMINIO.AD -crypto RC4-HMAC-NT -ptype KRB5_NT_PRINCIPAL -pass senha
    ```

3. Transfira o arquivo `squid.keytab` para o servidor Squid e configure as permissões:
    ```bash
    sudo chown proxy:proxy /etc/squid/squid.keytab
    sudo chmod 600 /etc/squid/squid.keytab
    ```

---

### Passo 3: Configurar o Squid para Usar Kerberos e HTTPS

1. Edite o arquivo de configuração do Squid `/etc/squid/squid.conf` para habilitar autenticação Kerberos:
    ```ini
    auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -k /etc/squid/squiduser.keytab
    auth_param negotiate children 5
    auth_param negotiate keep_alive on
    acl kerberos_users proxy_auth REQUIRED
    http_access allow kerberos_users
    ```

2. Configure o acesso à rede interna:
    ```ini
    acl rede_interna src 192.168.0.0/24
    http_access allow kerberos_users rede_interna
    http_access deny all
    ```

3. Habilite o proxy HTTPS (SSL Bumping):
    - Crie o certificado SSL para o Squid:
      ```bash
      sudo mkdir -p /etc/squid/ssl_cert
      sudo openssl genrsa -out /etc/squid/ssl_cert/squid.key 2048
      sudo openssl req -new -x509 -key /etc/squid/ssl_cert/squid.key -out /etc/squid/ssl_cert/squid.crt -days 3650
      sudo cat /etc/squid/ssl_cert/squid.crt /etc/ssl/certs/ca-certificates.crt > /etc/squid/ssl_cert/squid.pem
      sudo chmod 600 /etc/squid/ssl_cert/squid.key
      ```

    - Adicione as configurações de SSL Bumping ao Squid:
      ```ini
      https_port 3128 cert=/etc/squid/ssl_cert/squid.pem key=/etc/squid/ssl_cert/squid.key

      acl step1 at_step SslBump1
      acl step2 at_step SslBump2
      acl step3 at_step SslBump3

      ssl_bump peek step1 all
      ssl_bump splice step2 all
      ssl_bump bump step3 all

      http_access allow kerberos_users rede_interna
      http_access deny all
      ```

4. Configure o redirecionamento de tráfego HTTPS no firewall (proxy transparente):
    ```bash
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3128
    ```

---

### Passo 4: Configurar o Cache do Squid

1. Configure os parâmetros de cache no arquivo `/etc/squid/squid.conf`:
    ```ini
    cache_dir ufs /var/spool/squid 1000 16 256
    maximum_object_size 4096 KB
    cache_mem 256 MB
    ```

2. Defina políticas de expiração e armazenamento de objetos:
    ```ini
    refresh_pattern . 0 20% 4320
    ```

---

### Passo 5: Monitorar o Uso do Proxy

1. Ative os logs de acesso e de erros:
   Os logs podem ser encontrados em:
   - `/var/log/squid/access.log`
   - `/var/log/squid/cache.log`

2. Instale ferramentas para análise de logs (opcional):
    ```bash
    sudo apt install squidview -y
    ```

---

### Passo 6: Testar a Configuração

1. Reinicie o Squid para aplicar as configurações:
    ```bash
    sudo systemctl restart squid
    ```

2. Teste o acesso à internet e à autenticação Kerberos:
   - Certifique-se de que os usuários autenticados conseguem acessar a internet.
   - Teste o tráfego HTTPS para verificar a interceptação SSL.

---

## 🎯 Critérios de Avaliação

- **Configuração correta das ACLs:** Apenas usuários autenticados devem ter acesso.
- **Cache de conteúdo funcionando:** Verifique se o cache está otimizado.
- **Interceptação SSL funcionando:** Certifique-se de que o tráfego HTTPS é interceptado corretamente.
- **Logs de acesso e erro:** Verifique os logs para garantir que todas as requisições estão sendo registradas.

---

### 📂 Link para o Script

Acesse o script automatizado no GitHub:  
[Script para Configuração Kerberos + Squid](https://github.com/debianlima/ad_script_ubuntu24.04/blob/main/kerberos_squid/script_ad_kerberos_bind_squid.sh)

> **Nota:** Este guia é adaptável às necessidades de diferentes infraestruturas. Verifique e ajuste as configurações para atender ao seu ambiente específico.

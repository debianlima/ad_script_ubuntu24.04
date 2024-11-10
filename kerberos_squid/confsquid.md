# Configuração do Squid com Kerberos para Autenticação e Suporte a HTTPS

Para configurar o Squid com Kerberos para autenticação e garantir que o tráfego HTTPS seja adequadamente manipulado, incluindo o proxy de conteúdo HTTPS, você precisará de uma configuração adicional para interceptar e gerenciar esse tráfego.

Segue um passo a passo para configurar o Squid no Ubuntu com autenticação Kerberos e suporte para HTTPS:

## Passo 1: Instalar o Squid e Dependências

1. Atualizar os repositórios do sistema:

    ```bash
    sudo apt update
    ```

2. Instalar o Squid e pacotes necessários:

    ```bash
    sudo apt install squid krb5-user libpam-krb5 libkrb5-dev ssl-cert -y
    ```

## Passo 2: Configurar o Kerberos

1. Configurar o arquivo `/etc/krb5.conf` com as informações do seu domínio Active Directory:

   Modifique as entradas para refletir seu domínio AD.

   Exemplo:

    ```ini
    [libdefaults]
        default_realm = DOMINIO.AD
        dns_lookup_realm = false
        dns_lookup_kdc = true
    ```

2. Criar o Principal de Serviço para o Squid no AD:

   No Active Directory, execute o seguinte comando para criar um principal de serviço para o Squid:

   
**Linux**

```bash
kinit usuario_squid@DOMINIO.AD
kadmin -q "ktadd -k /etc/krb5.keytab HTTP/nome_do_servidor@DOMINIO.AD"
```

**Windows**

    ktpass -princ HTTP/nome_do_servidor@DOMINIO.AD -mapuser usuario_squid@DOMINIO.AD -crypto RC4-HMAC-NT -ptype KRB5_NT_PRINCIPAL -  pass senha
  

3. Transferir o arquivo `squid.keytab` para o servidor Squid e garantir que ele tenha as permissões corretas:

    ```bash
    sudo chown proxy:proxy /etc/squid/squid.keytab
    sudo chmod 600 /etc/squid/squid.keytab
    ```

## Passo 3: Configurar o Squid para Usar Kerberos e HTTPS

1. Editar o arquivo de configuração do Squid `/etc/squid/squid.conf`:

   Adicione as configurações de autenticação Kerberos:

    ```ini
    auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -s HTTP/nome_do_servidor@DOMINIO.AD
    auth_param negotiate children 10
    auth_param negotiate keep_alive on

    acl kerberos_auth proxy_auth REQUIRED
    http_access allow kerberos_auth
    ```

2. Configurar o acesso à rede interna:

   Defina as ACLs para permitir o acesso somente de clientes autenticados:

    ```ini
    acl rede_interna src 192.168.0.0/24
    http_access allow kerberos_auth rede_interna
    http_access deny all
    ```

3. Habilitar o Proxy HTTPS:

   Para interceptar o tráfego HTTPS, o Squid precisa ser configurado para atuar como um "transparent proxy" ou "SSL Bumping". Isso exige a criação de certificados SSL.

   - Criar o certificado SSL para o Squid:

    ```bash
    sudo mkdir -p /etc/squid/ssl_cert
    sudo openssl genrsa -out /etc/squid/ssl_cert/squid.key 2048
    sudo openssl req -new -x509 -key /etc/squid/ssl_cert/squid.key -out /etc/squid/ssl_cert/squid.crt -days 3650
    sudo cat /etc/squid/ssl_cert/squid.crt /etc/ssl/certs/ca-certificates.crt > /etc/squid/ssl_cert/squid.pem
    sudo chmod 600 /etc/squid/ssl_cert/squid.key
    ```

   - Configurar o Squid para SSL Bumping:

     Edite o arquivo `/etc/squid/squid.conf` para incluir as configurações de SSL Bumping:

    ```ini
    # Configurar o certificado do Squid
    https_port 3128 cert=/etc/squid/ssl_cert/squid.pem key=/etc/squid/ssl_cert/squid.key

    # Definir ACLs para controlar a interceptação SSL
    acl step1 at_step SslBump1
    acl step2 at_step SslBump2
    acl step3 at_step SslBump3
    acl step4 at_step SslBump4

    # Configurar regras de SSL Bumping
    ssl_bump peek step1 all
    ssl_bump splice step2 all
    ssl_bump bump step3 all

    # Regras de acesso
    http_access allow kerberos_auth rede_interna
    http_access deny all
    ```

4. Habilitar o redirecionamento de tráfego HTTPS (se o proxy for transparente):

   Se você estiver configurando um proxy transparente, adicione as seguintes regras no firewall:

    ```bash
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3128
    ```

## Passo 4: Configurar o Cache do Squid

1. Configure parâmetros de cache no arquivo `/etc/squid/squid.conf`:

    ```ini
    cache_dir ufs /var/spool/squid 1000 16 256
    maximum_object_size 4096 KB
    cache_mem 256 MB
    ```

2. Defina políticas de expiração e armazenamento de objetos:

    ```ini
    refresh_pattern . 0 20% 4320
    ```

## Passo 5: Monitorar o Uso do Proxy

1. Ativar logs de acesso e de erros:

   O Squid grava as informações de uso nos arquivos de log em `/var/log/squid/access.log` e `/var/log/squid/cache.log`.

2. Instalar ferramentas de análise de log (opcional):

   Para facilitar a visualização dos logs, você pode instalar ferramentas como o `squidview`:

    ```bash
    sudo apt install squidview -y
    ```

## Passo 6: Testar a Configuração

1. Reiniciar o Squid para aplicar as configurações:

    ```bash
    sudo systemctl restart squid
    ```

2. Testar o acesso à internet através do proxy configurado:

   Certifique-se de que os usuários consigam acessar a internet e que a autenticação Kerberos esteja funcionando corretamente.

   Teste também o tráfego HTTPS e verifique se a interceptação SSL (SSL Bumping) está funcionando corretamente.

---

## Critérios de Avaliação

- **Configuração correta do Squid e das ACLs:** Verifique se as ACLs estão controlando o acesso de forma eficiente.
- **Cache de conteúdo funcionando corretamente:** Certifique-se de que o cache está sendo usado para otimizar o tráfego.
- **Interceptação e proxy de tráfego HTTPS:** O tráfego HTTPS deve ser interceptado corretamente e os certificados SSL devem ser gerados e configurados adequadamente.
- **Relatórios de uso do proxy:** Certifique-se de que os logs de acesso estão sendo gerados e são acessíveis para análise.

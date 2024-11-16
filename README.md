
# 🌐 Configuração Completa: Proxy Squid, Samba4 (AD) e Redes Virtuais

📚 **Descrição da Playlist**  
Nesta playlist do YouTube, você aprenderá a configurar um ambiente completo e funcional para redes corporativas, utilizando máquinas virtuais, redes personalizadas e serviços avançados no Linux.  

🔗 **Acesse a Playlist no YouTube:**  
[Configuração Completa de Proxy Squid, Samba4 (AD) e Redes Virtuais](https://www.youtube.com/playlist?list=PLWtdOCrFeIoBPu5oZ9u00WH_xz4pfii5s)

---

## 🚀 O que você vai aprender:
1. **Criação de Máquinas Virtuais**  
   Configuração de servidores Ubuntu e clientes Windows 10 no VMware, utilizando redes NAT e segmentos internos para simular uma infraestrutura corporativa.  

2. **Controlador de Domínio Completo (AD)**  
   Configuração do Samba4 como controlador de domínio com Kerberos, Winbind e PAM, permitindo autenticação centralizada em dispositivos Linux e Windows.  

3. **Proxy Squid Avançado**  
   Implementação de um servidor Proxy Squid com SSL Bumping, geração de certificados e integração ao Active Directory (AD) configurado com o Samba4.  

4. **Outros Serviços Linux**  
   Ampliação da infraestrutura com serviços adicionais para atender diferentes cenários corporativos.  

---

## 🛠️ Tecnologias Utilizadas:
- **Virtualização**: VMware com redes NAT e segmentadas.  
- **Sistema Operacional**: Ubuntu Server e Windows 10.  
- **Autenticação Centralizada**: Samba4 (AD) com Kerberos.  
- **Proxy Avançado**: Squid Proxy com SSLBump.  

---

## 📂 Scripts Disponíveis
Os scripts prontos utilizados nos vídeos estão disponíveis neste repositório. Eles incluem:  
1. **Configuração do Samba4 como Controlador de Domínio.**  
2. **Configuração do Squid Proxy com SSL Bumping e integração ao AD.**

Certifique-se de revisar os scripts e adaptá-los às suas necessidades de rede antes de implementá-los em produção.

---

## 🎥 Assista Agora
📺 **Playlist Completa no YouTube:**  
[https://www.youtube.com/playlist?list=PLWtdOCrFeIoBPu5oZ9u00WH_xz4pfii5s](https://www.youtube.com/playlist?list=PLWtdOCrFeIoBPu5oZ9u00WH_xz4pfii5s)

---

> **Nota:** Esta playlist é ideal para profissionais e estudantes de TI que desejam aprender sobre configuração de proxies, redes corporativas e integração de serviços Linux em ambientes corporativos.

<h1>Explicação do Script Bash</h1>

<p>Este script em Bash configura um servidor Samba como um controlador de domínio Active Directory, juntamente com o serviço DNS usando BIND. Abaixo está uma explicação detalhada de cada parte do script:</p>

<h2>Variáveis</h2>
<p>As variáveis definidas no início do script são usadas para armazenar configurações importantes:</p>
<ul>
    <li><code>DOMAIN</code>: Define o domínio a ser configurado.</li>
    <li><code>UPPER_DOMAIN</code>: O domínio em letras maiúsculas.</li>
    <li><code>ADMIN_PASSWORD</code>: A senha do administrador.</li>
    <li><code>SAMBA_CONF_DIR</code>: Diretório de configuração do Samba.</li>
    <li><code>BIND_CONF_DIR</code>: Diretório de configuração do BIND.</li>
    <li><code>RESOLV_CONF</code>: Caminho do arquivo de configuração DNS.</li>
    <li><code>HOSTS_CONF</code>: Caminho do arquivo de hosts.</li>
    <li><code>PRIVATE_KEYTAB_FILE</code>: Caminho para o arquivo de chave do Samba.</li>
    <li><code>BIND_KEYTAB_FILE</code>: Caminho para o arquivo de chave do BIND.</li>
    <li><code>ZONE_DIR</code>: Diretório onde os arquivos de zona estão localizados.</li>
    <li><code>ZONE_FILE</code>: Caminho para o arquivo de zona do domínio.</li>
    <li><code>NETPLAN_CONF</code>: Caminho para o arquivo de configuração do Netplan.</li>
    <li><code>INTERFACE_NAME</code>: Nome da interface de rede.</li>
    <li><code>GATEWAY</code>: Gateway da rede local.</li>
    <li><code>DNS_SERVERS</code>: Servidores DNS.</li>
    <li><code>DNS_GOOGLE</code>: Servidor DNS do Google.</li>
    <li><code>SERVER</code>: Nome do servidor.</li>
    <li><code>IP</code>: Endereço IP do servidor.</li>
    <li><code>RESOLVED_CONF</code>: Caminho para o arquivo de configuração do systemd-resolved.</li>
    <li><code>RESOLVED_CONF_CONTENT</code>: Conteúdo da configuração do systemd-resolved.</li>
</ul>

<h2>Funções</h2>

<h3>Configurar Rede</h3>
<pre><code>configure_network() {
    echo "Configurando a rede..."
    # Define configurações de rede
    echo "network: {" > $NETPLAN_CONF
    echo "    version: 2" >> $NETPLAN_CONF
    echo "    renderer: networkd" >> $NETPLAN_CONF
    echo "    ethernets:" >> $NETPLAN_CONF
    echo "        $INTERFACE_NAME:" >> $NETPLAN_CONF
    echo "            dhcp4: no" >> $NETPLAN_CONF
    echo "            addresses: [$IP/24]" >> $NETPLAN_CONF
    echo "            gateway4: $GATEWAY" >> $NETPLAN_CONF
    echo "            nameservers:" >> $NETPLAN_CONF
    echo "                addresses: [$DNS_SERVERS]" >> $NETPLAN_CONF
    echo "}" >> $NETPLAN_CONF
    # Aplica as configurações
    netplan apply
}</code></pre>
<p>Esta função configura os parâmetros de rede necessários para o servidor, incluindo o endereço IP, máscara de sub-rede e gateway. O arquivo de configuração do Netplan é gerado e as configurações são aplicadas com <code>netplan apply</code>.</p>

<h3>Atualizar o Sistema</h3>
<pre><code>update_system() {
    echo "Atualizando o sistema..."
    apt-get update -y
    apt-get upgrade -y
}</code></pre>
<p>Esta função atualiza o sistema, garantindo que todos os pacotes estejam na versão mais recente. Ela usa <code>apt-get update</code> para atualizar a lista de pacotes disponíveis e <code>apt-get upgrade</code> para instalar as atualizações.</p>

<h3>Remover Pacotes</h3>
<pre><code>remove_packages() {
    echo "Removendo pacotes desnecessários..."
    apt-get remove --purge samba* krb5-user winbind bind9* -y
    rm -rf $SAMBA_CONF_DIR
    rm -rf $BIND_CONF_DIR
}</code></pre>
<p>Esta função remove os pacotes relacionados ao Samba, Kerberos, Winbind e BIND, além de limpar diretórios e arquivos de configuração. O uso do <code>--purge</code> garante que as configurações sejam removidas.</p>

<h3>Instalar Pacotes</h3>
<pre><code>install_packages() {
    echo "Instalando pacotes necessários..."
    apt-get install samba krb5-user winbind bind9 -y
    configure_network_files2
}</code></pre>
<p>Instala os pacotes necessários para o Samba e o BIND. Chama a função <code>configure_network_files2</code> para configurar os arquivos de rede com o DNS do Google após a instalação.</p>

<h3>Configurar Samba</h3>
<pre><code>configure_samba() {
    echo "Configurando o Samba..."
    samba-tool domain provision --use-rfc2307 --interactive --domain=$DOMAIN --realm=$UPPER_DOMAIN --adminpass=$ADMIN_PASSWORD
    cp /etc/samba/smb.conf $SAMBA_CONF_DIR
}</code></pre>
<p>Configura o Samba como um controlador de domínio, criando um novo domínio com <code>samba-tool domain provision</code> e configurando o arquivo <code>smb.conf</code> com as definições apropriadas. O comando <code>--use-rfc2307</code> permite o uso de atributos do RFC 2307.</p>

<h3>Configurar Kerberos</h3>
<pre><code>configure_kerberos() {
    echo "Configurando o Kerberos..."
    cat <<EOT > /etc/krb5.conf
[libdefaults]
    default_realm = $UPPER_DOMAIN
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    $UPPER_DOMAIN = {
        kdc = $SERVER
        admin_server = $SERVER
    }

[domain_realm]
    .$DOMAIN = $UPPER_DOMAIN
    $DOMAIN = $UPPER_DOMAIN
EOT
    systemctl stop smbd nmbd
    systemctl disable smbd nmbd
}</code></pre>
<p>Configura o Kerberos, definindo as informações do domínio no arquivo <code>/etc/krb5.conf</code>. O arquivo é gerado com um <code>heredoc</code> e os serviços desnecessários do Samba são parados e desabilitados.</p>

<h3>Configurar BIND</h3>
<pre><code>configure_bind() {
    echo "Configurando o BIND..."
    cp /etc/bind/named.conf.options $BIND_CONF_DIR
    cat <<EOT >> $BIND_CONF_DIR/named.conf.local
zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};
EOT
    cp $ZONE_FILE $ZONE_DIR
}</code></pre>
<p>Configura o BIND para resolver nomes de domínio, criando os arquivos de zona e configurando o servidor DNS. O arquivo <code>named.conf.local</code> é modificado para incluir a nova zona.</p>

<h3>Configurar Resolved</h3>
<pre><code>configure_resolved() {
    echo "Configurando o systemd-resolved..."
    echo "$RESOLVED_CONF_CONTENT" > $RESOLVED_CONF
}</code></pre>
<p>Configura o <code>systemd-resolved</code> para usar o DNS configurado no sistema, salvando o conteúdo especificado na variável <code>RESOLVED_CONF_CONTENT</code> no arquivo de configuração apropriado.</p>

<h3>Iniciar Samba</h3>
<pre><code>start_samba() {
    echo "Iniciando o Samba..."
    systemctl start samba
}</code></pre>
<p>Inicia o serviço do Samba, permitindo que ele comece a aceitar conexões e gerenciar o domínio configurado.</p>

<h3>Adicionar Zonas DNS</h3>
<pre><code>add_dns_zones() {
    echo "Adicionando zonas DNS..."
    # Adicione as zonas conforme necessário
}</code></pre>
<p>Esta função é um placeholder onde você pode adicionar zonas DNS conforme necessário. A implementação específica depende das necessidades da sua rede.</p>

<h3>Criar Diretórios Home</h3>
<pre><code>create_home_directories() {
    echo "Criando diretórios home para os usuários..."
    for user in $(getent passwd | awk -F: '{print $1}'); do
        if [ ! -d "/home/$user" ]; then
            mkdir "/home/$user"
            chown "$user:$user" "/home/$user"
            echo "Diretório home criado para $user"
        fi
    done
}</code></pre>
<p>Esta função cria diretórios home para todos os usuários existentes no sistema, caso ainda não tenham um. Utiliza <code>getent passwd</code> para obter a lista de usuários e <code>mkdir</code> para criar os diretórios. O proprietário do diretório é configurado para o respectivo usuário.</p>

<h3>Abrir Arquivos Modificados</h3>
<pre><code>open_modified_files() {
    echo "Abrindo arquivos que foram modificados recentemente..."
    find /path/to/files -type f -mtime -7 -exec xdg-open {} \;
}</code></pre>
<p>Esta função busca arquivos que foram modificados nos últimos 7 dias em um diretório especificado. Ela utiliza o comando <code>find</code> para localizar os arquivos e <code>xdg-open</code> para abri-los. O caminho deve ser ajustado conforme necessário.</p>

<h3>Listar Permissões</h3>
<pre><code>list_permissions() {
    echo "Listando permissões de diretórios e arquivos..."
    ls -l /path/to/directory
}</code></pre>
<p>Esta função lista as permissões dos arquivos e diretórios em um caminho especificado. O comando <code>ls -l</code> é utilizado para exibir as permissões em um formato legível.</p>

<h3>Executar Funções</h3>
<pre><code>main() {
    configure_network
    update_system
    remove_packages
    install_packages
    configure_samba
    configure_kerberos
    configure_bind
    configure_resolved
    start_samba
    add_dns_zones
    create_home_directories
    open_modified_files
    list_permissions
}</code></pre>
<p>A função principal que orquestra a execução de todas as funções definidas no script. Chama cada função na ordem apropriada para configurar o servidor.</p>



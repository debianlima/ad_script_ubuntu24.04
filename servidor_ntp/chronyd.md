Esse conjunto de comandos está relacionado à configuração de um servidor de tempo (NTP) integrado a um controlador de domínio Samba. A seguir, explico o que está acontecendo em cada etapa e como elas se conectam:

---

### **1. Remoção do NTP e NTPsec**
Esses comandos removem quaisquer pacotes relacionados ao NTP (ou NTPsec), limpando seus arquivos de configuração para evitar conflitos:

```bash
sudo apt-get remove --purge ntpsec ntpsec-common
sudo apt-get autoremove --purge
sudo apt-get remove --purge ntp
sudo apt-get autoremove --purge
```

Além disso, os arquivos e diretórios de configuração relacionados ao NTP são removidos manualmente:
```bash
sudo rm -rf /etc/ntp.conf
sudo rm -rf /etc/ntpsec/
sudo rm -rf /etc/ntp/
```

---

### **2. Instalação e configuração do Chrony**
Após remover o NTP, o Chrony é instalado como alternativa moderna para sincronização de tempo:
```bash
sudo apt update
sudo apt install chrony
```


Aqui está uma versão revisada do arquivo de configuração do Chrony (`/etc/chrony/chrony.conf`) para otimizar o serviço como provedor de horário para máquinas integradas ao Active Directory. As mudanças incluem melhorias na segurança, foco na precisão e ajuste para ambientes integrados ao AD:

```ini
# Diretório de configurações adicionais
confdir /etc/chrony/conf.d

# Servidores NTP primários
server a.st1.ntp.br iburst
server b.st1.ntp.br iburst
server c.st1.ntp.br iburst
server d.st1.ntp.br iburst

# Servidores secundários (redundância e fallback)
pool 0.ubuntu.pool.ntp.org iburst maxsources 3
pool 1.ubuntu.pool.ntp.org iburst maxsources 2
pool 2.ubuntu.pool.ntp.org iburst maxsources 2

# Diretórios para fontes adicionais de configuração e DHCP
sourcedir /run/chrony-dhcp
sourcedir /etc/chrony/sources.d

# Arquivo de chaves para autenticação
keyfile /etc/chrony/chrony.keys

# Arquivos de controle e estado
driftfile /var/lib/chrony/chrony.drift
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony

# Sincronizar com o relógio de hardware (RTC)
rtcsync

# Permitir ajustes grandes no início para rápida sincronização
makestep 1 3

# Configuração de segurança: permitir somente a rede local
allow 192.168.0.0/24
allow 10.0.0.0/8

# Servidor local como fallback (stratum alto para evitar conflitos)
local stratum 10
server 127.127.1.0 iburst

# Habilitar autenticação NTP para clientes do Active Directory
ntpsigndsocket /var/lib/samba/ntp_signd/

# Configurações de logs para monitoramento
log tracking measurements statistics

# Melhorar precisão do tempo para ambientes Windows (ajuste suave de tempo)
smoothtime 400 0.001

# Sincronização de Leap Seconds para UTC
leapsectz right/UTC
```

---

### **Alterações e Melhorias**
1. **Servidores NTP redundantes:** 
   - Adicionei servidores brasileiros como primários e pools Ubuntu como secundários para maior disponibilidade.
   - A linha server 127.127.1.0 iburst porque ela configura o "fake hardware clock" (servidor de tempo local) como uma fonte de tempo. Isso é geralmente usado como último recurso quando o servidor não consegue acessar nenhuma fonte NTP externa. 

3. **Segurança:**
   - Configurado `allow` para restringir a sincronização de tempo apenas às redes locais.
   - Autenticação habilitada via `ntpsigndsocket` para suporte a máquinas Windows integradas ao AD.

4. **Sincronização inicial:**
   - O parâmetro `makestep` garante ajustes rápidos durante a inicialização, útil para servidores em configuração inicial.

5. **Fallback local:**
   - Adicionado um servidor local com stratum 10, usado apenas se nenhum servidor externo estiver disponível.

6. **Logs e monitoramento:**
   - Habilitei logs detalhados para depurar e monitorar o desempenho do servidor de tempo.

7. **Compatibilidade com Windows:**
   - O parâmetro `smoothtime` melhora a precisão de sincronização para máquinas Windows que dependem do AD.

---


O arquivo de configuração do Chrony (`/etc/chrony/chrony.conf`) é editado para incluir servidores NTP e configurações específicas:

- **Servidores NTP adicionados:** 
  Servidores do Ubuntu (`ntp.ubuntu.com`) e brasileiros (`a.st1.ntp.br`, etc.).
- **Configuração para o Samba:** 
  A linha `ntpsigndsocket /var/lib/samba/ntp_signd/` habilita suporte ao NTP autenticado para clientes do Active Directory.
- **Permissões e diretórios:** 
  Diretório `/var/lib/samba/ntp_signd/` recebe as permissões corretas para ser usado pelo Samba:
  ```bash
  ls -ld /var/lib/samba/ntp_signd/
  sudo chown root:sambashare /var/lib/samba/ntp_signd
  sudo chmod 750 /var/lib/samba/ntp_signd/
  ```

Os serviços são ativados e reiniciados:
```bash
sudo systemctl enable chrony
sudo systemctl start chrony
sudo systemctl restart chronyd
sudo systemctl restart samba-ad-dc
```

---

### **3. Integração com o Samba**
No arquivo de configuração do Samba (`/etc/samba/smb.conf`), o suporte ao NTP autenticado é habilitado:
```bash
server services = ntp_signd
```

O serviço Samba é reiniciado para aplicar as alterações:
```bash
sudo systemctl restart samba-ad-dc
```

---

### **4. Configurações de Firewall**
Permite o tráfego UDP na porta 123 (NTP):
```bash
sudo ufw allow 123/udp
```

---

### **5. Testes e Logs**
- Verifica se o Chrony está funcionando e se a porta NTP está ativa:
  ```bash
  sudo systemctl status chronyd
  netstat -ulnp | grep 123
  chronyc ntpdata
  ```

- Checa os logs para depurar problemas:
  ```bash
  sudo tail -f /var/log/samba/log.smbd
  sudo journalctl -u chrony
  ```

---

### **6. Configuração do Cliente Windows**
O cliente Windows é configurado para sincronizar com o servidor NTP:
```cmd
w32tm /config /manualpeerlist:"<IP_DO_SERVIDOR>" /syncfromflags:manual /reliable:YES /update
w32tm /resync
w32tm /query /status
```

Isso permite que máquinas Windows sincronizem com o servidor de tempo configurado.

---

### **7. Verificações Gerais**
- Status do tempo e sincronização no servidor:
  ```bash
  timedatectl status
  ```

- Logs específicos para o serviço de tempo (NTP ou Chrony):
  ```bash
  sudo journalctl -u ntp
  sudo journalctl -u chrony
  ```

---

### **Resumo**
1. Remove-se o NTP para evitar conflitos e substituí-lo pelo Chrony.
2. Configura-se o Chrony como serviço de tempo principal.
3. Integra-se o Samba para autenticar o serviço NTP com suporte a AD.
4. Testa-se o funcionamento usando logs, ferramentas como `chronyc` e configurações no cliente Windows.

Se você precisar de mais detalhes ou ajustes, é só pedir!

# Configuração de rede da VM

## Objetivo
Deixar o servidor LAMP (dentro da VM) **acessível pelo navegador da máquina
hospedeira**, com IP fixo e domínio, **de forma automática** — de modo que a
mesma receita funcione em qualquer PC que rode a VM.

- **Máquina hospedeira:** Windows, Linux ou WSL (com VirtualBox).
- **Máquina virtual:** Ubuntu Server / Debian.
- **Rede:** adaptador **Host-only** (`192.168.56.0/24`) + **NAT** para internet.
- **IP fixo do servidor:** `192.168.56.10`
- **Domínio interno:** `www.grupo1.redes2.internal`

---

## Como funciona agora (automático)

O endereço do site **não é mais fixo no banco**: o WordPress usa **URL dinâmica**
(o mesmo host que o navegador usou — veja `scripts/ajustar-url-dinamica.sh`).
Por isso o MESMO site responde corretamente por:

- `http://192.168.56.10/`
- `http://www.grupo1.redes2.internal/`
- `http://localhost:8080/` (se usar NAT com redirecionamento de portas)

Assim ele funciona em **qualquer PC** sem editar nada ao trocar de máquina.

## Passo a passo automático

### 1) Na hospedeira (Windows, PowerShell)
Deixa o VirtualBox pronto: cria a rede Host-only, liga o 2º adaptador da VM,
(opcional) cria o port-forward e adiciona o domínio no `hosts` do Windows.

```powershell
.\host\configurar-virtualbox.ps1 -VM "lampredes"
# se a VM estiver ligada e precisar adicionar o adaptador:
.\host\configurar-virtualbox.ps1 -VM "lampredes" -Reiniciar
# + port-forward (http://localhost:8080):
.\host\configurar-virtualbox.ps1 -VM "lampredes" -PortForward
```

> Use o nome exato da VM (veja em `VBoxManage list vms` / interface do VirtualBox).
> Em Linux/WSL, use `bash host/configurar-virtualbox.sh --vm lampredes`.

### 2) Dentro da VM
Configura o IP fixo (detecta NetworkManager / netplan / Debian), adiciona a
entrada no `/etc/hosts`, sincroniza o VirtualHost e aplica a URL dinâmica:

```bash
cd atividade-lamp-wordpress
git pull
sudo bash scripts/configurar-rede.sh
```

Pronto. Na hospedeira, abra **http://192.168.56.10/** ou o domínio.

## O que o `configurar-rede.sh` faz

- escolhe automaticamente a interface **host-only** (a que não é a rota default);
- define o **IP fixo** `192.168.56.10/24` (via `nmcli`, netplan ou `/etc/network/interfaces`);
- garante `Listen 80` no Apache, libera 22/80/443 no UFW;
- adiciona `192.168.56.10  www.grupo1.redes2.internal grupo1.redes2.internal` no `/etc/hosts`;
- regenera o VirtualHost (script 06) e recarrega o Apache;
- aplica a URL dinâmica do WordPress (script `ajustar-url-dinamica.sh`);
- testa `localhost`, o IP e o domínio, mostrando o código HTTP.

## Acesso pelo domínio

O domínio não existe em DNS nenhum; ele precisa ser mapeado **no `hosts` de cada
máquina** que for acessar:

- **Hospedeira Windows:** o `host/configurar-virtualbox.ps1` já adiciona
  (se rodado como Administrador). Manual: edite
  `C:\Windows\System32\drivers\etc\hosts` e inclua
  `192.168.56.10  www.grupo1.redes2.internal grupo1.redes2.internal`.
- **Dentro da VM:** o `configurar-rede.sh` já adiciona.

## Alternativa sem adaptador host-only (NAT + port-forward)

Se a VM tiver **só NAT**, o site fica acessível por `http://localhost:8080/`:

```powershell
.\host\configurar-virtualbox.ps1 -VM "lampredes" -PortForward   # no Windows
# ou:
.\docs\host-nat-portforward.ps1 -VM "lampredes"
```

| Nome | Protocolo | Porta hosp. | Porta convidada |
|---|---|---|---|
| LAMP-HTTP  | TCP | 8080 | 80 |
| LAMP-HTTPS | TCP | 8443 | 443 |

Com a URL dinâmica, `http://localhost:8080/` funciona **sem editar o WordPress**.

## Verificação

Na **hospedeira**:
```bash
ping 192.168.56.10            # responde?
curl -I http://192.168.56.10  # HTTP 200?
```

Dentro da **VM** (diagnóstico completo):
```bash
bash scripts/diagnostico.sh
bash scripts/coletar-diagnostico.sh   # relatório p/ depuração
```

## Se algo não funcionar

1. Confirme que existe um **2º adaptador** na VM (`ip -brief addr` mostra ex. `enp0s8`).
   Se não aparecer, rode o `host/configurar-virtualbox.ps1 -Reiniciar` no PC.
2. Rode `sudo bash scripts/configurar-rede.sh` de novo (é idempotente).
3. Se usar domínio e não abrir, falta a linha no `hosts` da hospedeira.

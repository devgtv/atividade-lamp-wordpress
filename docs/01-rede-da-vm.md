# Configuração de rede da VM

## Objetivo
Fazer com que o servidor LAMP dentro da máquina virtual seja **acessível a partir
da máquina hospedeira** (o PC físico), usando um IP fixo.

## Cenário usado neste trabalho
- **Máquina hospedeira:** Windows, com VirtualBox (ou VMware).
- **Máquina virtual:** Ubuntu Server / Debian.
- **Rede:** adaptador **Host-only** (`vboxnet0`, faixa `192.168.56.0/24`).
- **IP fixo do servidor:** `192.168.56.10`.

### Por que Host-only (e não Bridge)?
- **Host-only:** VM e hospedeira ficam numa rede privada isolada. É ótimo para
  laboratório: endereços previsíveis e sem exposição à rede da faculdade/casa.
- **Bridge:** a VM "entra" na mesma rede física da hospedeira, recebendo IP do
  roteador (DHCP). Funciona igual para o navegador acessar, mas o IP pode mudar
  e a VM fica visível para toda a rede local.
- Com **Host-only + IP fixo**, a hospedeira sempre acessa `http://192.168.56.10/`.

## Passo a passo (VirtualBox)
1. **Gerenciador de Rede do VirtualBox** → aba *Rede somente host* → criar
   `vboxnet0` com faixa `192.168.56.1/24` e DHCP desabilitado.
2. Na VM → *Configurações → Rede* → Adaptador 1 → **Rede somente host** (`vboxnet0`).
3. (Opcional) Adicionar **Adaptador 2** em **NAT** para a VM ter internet e poder
   baixar pacotes (`apt`, `wget`).

## IP fixo dentro da VM (Ubuntu Server / netplan)
Arquivo `/etc/netplan/00-installer-config.yaml`:

```yaml
network:
  version: 2
  ethernets:
    enp0s8:                          # nome da interface host-only
      dhcp4: no
      addresses:
        - 192.168.56.10/24
      routes:
        - to: default
          via: 192.168.56.1          # IP da vboxnet0 (gateway da rede host-only)
      nameservers:
        addresses: [8.8.8.8]         # só se usar o adaptador NAT para internet
```

Aplicar:
```bash
sudo netplan apply
ip a            # confirme o IP 192.168.56.10 na interface
ip route        # confirme a rota default
```

> **Alternativa mais simples:** deixar o DHCP do host-only do VirtualBox ativo e
> reservar um IP fixo por MAC address (para o IP não mudar).

## Teste de conectividade
Na **hospedeira**:
```bash
ping 192.168.56.10          # responde?
curl -I http://192.168.56.10 # HTTP 200 OK?
```

### (Opcional) Acessar pelo domínio interno
Edite `C:\Windows\System32\drivers\etc\hosts` na hospedeira e adicione:
```
192.168.56.10   www.grupo1.redes2.internal
```
Assim também funciona: `http://www.grupo1.redes2.internal/`.

## Alternativa: NAT com redirecionamento de portas
Se preferir o modo **NAT** (aceito pelo enunciado), configure em
*Configurações → Rede → Avançado → Redirecionamento de Portas*:
| Nome | Protocolo | IP hospedeiro | Porta hosp. | IP convidado | Porta convidada |
|---|---|---|---|---|---|
| HTTP | TCP | 127.0.0.1 | 8080 | 10.0.2.15 | 80 |
| HTTPS | TCP | 127.0.0.1 | 8443 | 10.0.2.15 | 443 |

Acesso na hospedeira: `http://localhost:8080/`.

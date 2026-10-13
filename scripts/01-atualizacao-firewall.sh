#!/usr/bin/env bash
# =============================================================================
# 01-atualizacao-firewall.sh
# -----------------------------------------------------------------------------
# Parte 1 do roteiro: atualizar o sistema e configurar o firewall (UFW).
#
# UFW = Uncomplicated Firewall (interface amigável para o iptables).
# Liberamos apenas as portas que o servidor precisa:
#   - 22/tcp (OpenSSH): acesso remoto via SSH
#   - 80/tcp (HTTP)   : acesso ao site pelo navegador
# =============================================================================

# "set -e" interrompe o script se qualquer comando falhar (boa prática).
set -e

# Precisa de root (sudo). Abortamos se não estiver como root.
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Atualizando a lista de pacotes e instalando atualizações..."
apt update          # baixa a lista atualizada de pacotes dos repositórios
apt upgrade -y      # instala as atualizações de segurança/pacotes

echo ">>> Configurando o firewall (UFW)..."
# Liberamos por PORTA (22/tcp) e não pelo perfil "OpenSSH", pois o perfil só
# existe quando o pacote openssh-server está instalado. Sem ele, o UFW retorna
# "Could not find a profile matching 'OpenSSH'". A liberação por porta funciona
# sempre e é equivalente para o SSH.
#
# As falhas do UFW não interrompem o script (importante em WSL/containers, onde
# o firewall pode não ter suporte a iptables). Só emitimos um aviso.
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp          || echo "AVISO: não foi possível liberar a porta 22."
  ufw allow 80/tcp          || echo "AVISO: não foi possível liberar a porta 80."
  ufw --force enable        || echo "AVISO: não foi possível habilitar o UFW (ambiente sem suporte a iptables?)."

  echo ">>> Situação do firewall:"
  ufw status verbose        || echo "AVISO: não foi possível consultar o status do UFW."
else
  echo "AVISO: UFW não está instalado; pulando a configuração do firewall."
fi

echo ">>> Concluído: sistema atualizado e firewall ativo."

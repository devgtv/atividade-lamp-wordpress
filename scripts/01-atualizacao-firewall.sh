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
ufw allow OpenSSH  # libera a porta 22 (para não perder acesso via SSH)
ufw allow 80/tcp   # libera a porta 80 (HTTP -> site WordPress)
ufw --force enable # habilita o firewall sem pedir confirmação interativa

echo ">>> Situação do firewall:"
ufw status verbose # mostra as regras ativas

echo ">>> Concluído: sistema atualizado e firewall ativo."

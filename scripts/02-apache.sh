#!/usr/bin/env bash
# =============================================================================
# 02-apache.sh
# -----------------------------------------------------------------------------
# Parte 2 do roteiro: instalar e validar o Apache (servidor web - o "A" do LAMP).
#
# O Apache recebe as requisições HTTP dos clientes (navegador) e devolve as
# páginas. Por padrão ele serve arquivos de /var/www/html na porta 80.
# =============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Instalando o Apache..."
apt install -y apache2

echo ">>> Habilitando o Apache para iniciar junto com o sistema..."
systemctl enable apache2

echo ">>> Iniciando/garantindo que o Apache está rodando..."
systemctl restart apache2

echo ">>> Status do serviço:"
systemctl status apache2 --no-pager

echo ">>> Testando com uma requisição HTTP local (esperado: HTTP/1.1 200 OK)..."
# "curl -I" mostra apenas os CABEÇALHOS da resposta HTTP.
curl -I http://localhost || true

echo
echo ">>> Agora, no navegador da máquina hospedeira, acesse:"
echo "      http://$(hostname -I | awk '{print $1}')"
echo "    (ou o IP fixo da VM) e confirme a página padrão do Apache ('It works!')."

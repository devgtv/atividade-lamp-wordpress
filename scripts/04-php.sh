#!/usr/bin/env bash
# =============================================================================
# 04-php.sh
# -----------------------------------------------------------------------------
# Parte 4 do roteiro: instalar o PHP (o "P" do LAMP) e os módulos que o
# WordPress exige.
#
# Dos módulos instalados:
#   - libapache2-mod-php : faz o Apache processar arquivos .php
#   - php-mysql          : conexão do PHP com o MariaDB/MySQL
#   - php-curl           : requisições HTTP (updates, APIs)
#   - php-gd             : manipulação de imagens (miniaturas)
#   - php-mbstring       : caracteres multibyte (acentos/UTF-8)
#   - php-xml            : importar/exportar conteúdo
#   - php-zip            : instalar plugins/temas em .zip
#   - php-intl           : internacionalização (datas, moedas)
# =============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Instalando PHP e os módulos necessários ao WordPress..."
apt install -y php libapache2-mod-php php-mysql php-curl php-gd \
  php-mbstring php-xml php-zip php-intl

echo ">>> Reiniciando o Apache para carregar o módulo do PHP..."
systemctl restart apache2

# -----------------------------------------------------------------------------
# Arquivo de teste: cria um info.php que executa phpinfo().
# Isso mostra que o Apache está interpretando PHP corretamente.
# -----------------------------------------------------------------------------
echo ">>> Criando página de teste do PHP (/var/www/html/info.php)..."
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

echo
echo ">>> TESTE: acesse no navegador da hospedeira:"
echo "      http://$(hostname -I | awk '{print $1}')/info.php"
echo "    e confirme que aparece a página de informações do PHP."
echo
echo ">>> APÓS conferir, execute para REMOVER o arquivo de teste (segurança):"
echo "      sudo rm /var/www/html/info.php"

#!/usr/bin/env bash
# =============================================================================
# 06-virtualhost.sh
# -----------------------------------------------------------------------------
# Parte 6 do roteiro: configurar o VirtualHost do Apache para o WordPress.
#
# VirtualHost = permite que um mesmo servidor Apache sirva vários sites,
# diferenciando-os por nome de domínio (ServerName) ou porta.
# Aqui criamos um site cujo DocumentRoot é /var/www/wordpress.
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Criando o arquivo de VirtualHost em ${APACHE_SITE}..."
cat > "${APACHE_SITE}" <<EOF
<VirtualHost *:80>
    # ServerName: nome com que este site "se identifica"
    ServerName ${DOMINIO}
    # ServerAlias: nomes alternativos (aceita também acesso pelo IP)
    ServerAlias ${IP_SERVIDOR}

    # Pasta pública do site (onde está o WordPress)
    DocumentRoot ${WP_DIR}

    <Directory ${WP_DIR}>
        # AllowOverride All: permite que o .htaccess do WordPress funcione
        # (necessário para permalinks/URLs amigáveis)
        AllowOverride All
        Require all granted
    </Directory>

    # Logs específicos deste site (ajudam a depurar)
    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

echo ">>> Habilitando o site e desabilitando o site padrão..."
a2ensite wordpress
a2dissite 000-default

echo ">>> Habilitando o módulo rewrite (URLs amigáveis do WordPress)..."
a2enmod rewrite

echo ">>> Testando a sintaxe das configurações do Apache..."
apache2ctl configtest

echo ">>> Recarregando o Apache..."
systemctl reload apache2

echo
echo ">>> Concluído: VirtualHost ativo."
echo "    (Opcional) Adicione no /etc/hosts da hospedeira:"
echo "      ${IP_SERVIDOR}  ${DOMINIO}"
echo "    Assim você acessa por http://${DOMINIO} além do IP."

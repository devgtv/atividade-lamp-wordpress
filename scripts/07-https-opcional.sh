#!/usr/bin/env bash
# =============================================================================
# 07-https-opcional.sh  (DESAFIO EXTRA)
# -----------------------------------------------------------------------------
# Habilita HTTPS com certificado AUTOASSINADO.
#
# Objetivo: mostrar que, com TLS, a senha do login deixa de aparecer em texto
# puro no Wireshark (o tráfego passa criptografado).
#
# Aviso: certificado autoassinado NÃO é confiável para o navegador (ele emitirá
# um alerta). Serve apenas para fins didáticos/laboratório.
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Habilitando o módulo SSL do Apache..."
a2enmod ssl

echo ">>> Gerando certificado autoassinado (válido por 365 dias)..."
mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/wordpress.key \
  -out    /etc/apache2/ssl/wordpress.crt \
  -subj "/C=BR/ST=RS/L=Local/O=${GRUPO}/CN=${DOMINIO}"

echo ">>> Criando o VirtualHost HTTPS (porta 443)..."
cat > /etc/apache2/sites-available/wordpress-ssl.conf <<EOF
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName ${DOMINIO}
    ServerAlias ${IP_SERVIDOR}
    DocumentRoot ${WP_DIR}

    <Directory ${WP_DIR}>
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile    /etc/apache2/ssl/wordpress.crt
    SSLCertificateKeyFile /etc/apache2/ssl/wordpress.key

    ErrorLog \${APACHE_LOG_DIR}/wordpress_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_ssl_access.log combined
</VirtualHost>
</IfModule>
EOF

echo ">>> Habilitando o site SSL, liberando a porta no firewall e recarregando..."
a2ensite wordpress-ssl
ufw allow 443/tcp
apache2ctl configtest
systemctl reload apache2

echo
echo ">>> Concluído: HTTPS disponível em https://${IP_SERVIDOR}/"
echo "    Repita a captura no Wireshark acessando https://... e observe que a"
echo "    senha do login NÃO aparece mais em texto puro (tráfego TLS)."

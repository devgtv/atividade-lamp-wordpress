#!/usr/bin/env bash
# =============================================================================
# 08-testes-logs.sh
# -----------------------------------------------------------------------------
# Parte 8 do roteiro: testes rápidos e acompanhamento dos logs de acesso.
#
# Os logs de acesso mostram cada requisição HTTP recebida pelo Apache:
#   IP do cliente - - [data] "REQUISIÇÃO" CÓDIGO bytes "referer" "user-agent"
# Exemplo:
#   192.168.56.1 - - [13/Oct/2026:10:20:30 -0300] "GET / HTTP/1.1" 200 12345
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

echo ">>> Teste 1: cabeçalhos HTTP do site (esperado: 200 OK)"
curl -I "http://localhost/" || true

echo
echo ">>> Teste 2: página de login do WordPress (esperado: 200 OK)"
curl -I "http://localhost/wp-login.php" || true

echo
echo ">>> Logs de acesso do site (últimas 20 linhas):"
tail -n 20 /var/log/apache2/wordpress_access.log || true

echo
echo ">>> Para ACOMPANHAR em tempo real, rode em outro terminal:"
echo "      sudo tail -f /var/log/apache2/wordpress_access.log"
echo "    e navegue no site: as requisições aparecerão na hora."

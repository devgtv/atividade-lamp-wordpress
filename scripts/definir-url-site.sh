#!/usr/bin/env bash
# =============================================================================
# definir-url-site.sh
# -----------------------------------------------------------------------------
# Ajusta a URL do site no WordPress (opções "home" e "siteurl") para bater com
# o endereço pelo qual você acessa. Isso corrige o erro de REDIRECIONAMENTO
# INFINITO / "Unable to connect", que acontece quando o WP está configurado com
# um endereço diferente do que você digita no navegador.
#
# Exemplos:
#   sudo bash scripts/definir-url-site.sh http://192.168.56.10     # rede host-only
#   sudo bash scripts/definir-url-site.sh http://localhost:8080    # NAT port-forward
#   sudo bash scripts/definir-url-site.sh                          # usa IP_SERVIDOR
# =============================================================================

set -e
source "$(dirname "$0")/00-variaveis.sh"

URL="${1:-http://${IP_SERVIDOR}}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

# A URL dinâmica (ajustar-url-dinamica.sh) define WP_HOME/WP_SITEURL a partir do
# host acessado e TEM PRECEDÊNCIA sobre os valores salvos no banco. Se ela estiver
# ativa, este script (que grava nas opções) não terá efeito.
if grep -q "LAMP_URL_DINAMICA" "${WP_DIR}/wp-config.php" 2>/dev/null; then
  echo "AVISO: a URL dinâmica está ATIVA em ${WP_DIR}/wp-config.php."
  echo "       Ela tem prioridade e ignora o que este script grava no banco."
  echo "       Se você realmente quer um endereço fixo, remova o bloco"
  echo "       'LAMP_URL_DINAMICA' do wp-config.php e rode de novo."
  echo
fi

echo ">>> Definindo a URL do site para: ${URL}"

sudo -u www-data env WP_DIR="${WP_DIR}" NOVA_URL="${URL}" php -r '
require getenv("WP_DIR") . "/wp-load.php";
$url = getenv("NOVA_URL");
update_option( "home",    $url );
update_option( "siteurl", $url );
echo "home/siteurl atualizados para: " . get_option("home") . " | " . get_option("siteurl") . "\n";
'

echo
echo ">>> Pronto. Teste no navegador: ${URL}"
echo "    (Se você mudou de host-only para NAT, use http://localhost:<porta>)"

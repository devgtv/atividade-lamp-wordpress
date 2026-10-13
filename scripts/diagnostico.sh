#!/usr/bin/env bash
# =============================================================================
# diagnostico.sh
# -----------------------------------------------------------------------------
# Ajuda a descobrir por que o site "fica carregando infinitamente".
# Rode NA VM/servidor:   bash scripts/diagnostico.sh
#
# Faz 7 verificações e no fim dá uma dica do que está errado.
# =============================================================================

source "$(dirname "$0")/00-variaveis.sh" 2>/dev/null || { IP_SERVIDOR="192.168.56.10"; WP_DIR="/var/www/wordpress"; }
SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO="sudo"

echo "==================================================================="
echo " DIAGNÓSTICO - site carregando infinitamente"
echo "==================================================================="

echo
echo "[0] Ambiente"
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "  >>> RODANDO EM WSL <<<  (a hospedeira NÃO acessa pelo IP interno do WSL)"
  echo "      Use http://localhost no Windows (o WSL2 faz o encaminhamento),"
  echo "      não o IP 172.x que aparece abaixo."
fi

echo
echo "[1] Endereços e rotas"
ip -brief addr
ip route

echo
echo "[2] Apache está escutando na porta 80?"
ss -tlnp 2>/dev/null | grep -E ':80\b' || echo "  Nada escutando na 80! (Apache parado?)"

echo
echo "[3] Serviços"
systemctl is-active apache2 mariadb 2>/dev/null | paste -sd' ' - || echo "  (sem systemd)"

echo
echo "[4] Firewall (UFW)"
if command -v ufw >/dev/null 2>&1; then $SUDO ufw status verbose 2>/dev/null || ufw status; else echo "  ufw não instalado"; fi

echo
echo "[5] Teste HTTP local e pelo IP (código + tempo)"
for url in "http://localhost/" "http://${IP_SERVIDOR}/"; do
  printf "  %-28s -> " "$url"
  curl -s -o /dev/null -m 10 -w "HTTP %{http_code} em %{time_total}s\n" "$url" 2>&1 || echo "FALHOU/tempo esgotado"
done

echo
echo "[6] home/siteurl do WordPress (redirecionamento)"
if command -v wp >/dev/null 2>&1; then
  $SUDO -u www-data env HOME=/var/www wp --path="${WP_DIR}" option get home 2>/dev/null | sed 's/^/  home    = /'
  $SUDO -u www-data env HOME=/var/www wp --path="${WP_DIR}" option get siteurl 2>/dev/null | sed 's/^/  siteurl = /'
else
  echo "  (WP-CLI não instalado)"
fi

echo
echo "[7] Últimas linhas dos logs do Apache"
$SUDO tail -n 8 /var/log/apache2/wordpress_error.log 2>/dev/null || echo "  (sem wordpress_error.log)"
$SUDO tail -n 8 /var/log/apache2/error.log 2>/dev/null

echo
echo "==================================================================="
echo " DICAS"
echo "-------------------------------------------------------------------"
echo " - Se [2] mostra nada na 80  -> Apache parado: sudo systemctl restart apache2"
echo " - Se [5] 'localhost' responde mas o IP não -> problema de rede/firewall"
echo "   (host-only sem IP fixo, UFW bloqueando, ou WSL -> use localhost)"
echo " - Se [6] home/siteurl aponta para um domínio em vez do IP -> redireciona"
echo "   para algo que não resolve. Corrija com:"
echo "     sudo -u www-data wp --path=${WP_DIR} option update home    http://${IP_SERVIDOR}"
echo "     sudo -u www-data wp --path=${WP_DIR} option update siteurl http://${IP_SERVIDOR}"
echo " - Se estiver em WSL, acesse http://localhost no Windows (não o IP)."
echo "==================================================================="

#!/usr/bin/env bash
# =============================================================================
# coletar-diagnostico.sh
# -----------------------------------------------------------------------------
# Junta TODAS as informações úteis para depuração em um único relatório e
# mostra na tela (e salva em /tmp/relatorio-lamp.txt). Rode NA VM:
#
#   sudo bash scripts/coletar-diagnostico.sh
#
# Depois é só copiar/colar a saída aqui para a gente analisar.
# Este script NÃO altera nada no sistema (somente leitura).
# =============================================================================

source "$(dirname "$0")/00-variaveis.sh" 2>/dev/null || {
  IP_SERVIDOR="192.168.56.10"; WP_DIR="/var/www/wordpress"; GRUPO="grupo1"; DOMINIO="www.grupo1.redes2.internal";
  DB_NAME="wordpress"; DB_USER="wpuser";
}
OUT="/tmp/relatorio-lamp.txt"
: > "$OUT"

sec() { echo -e "\n==================== $* ===================="; }
run() { echo "\$ $*"; "$@" 2>&1 || echo "  (comando falhou: $*)"; echo; }

# Um "tee" para tela + arquivo.
exec > >(tee "$OUT") 2>&1

echo "##################### RELATORIO LAMP/WORDPRESS #####################"
echo "Data: $(date)"
echo "Host: $(hostname)   Kernel: $(uname -r)"

sec "1. Sistema operacional"
[ -f /etc/os-release ] && cat /etc/os-release
echo; echo "WSL? $(grep -qi microsoft /proc/version && echo SIM || echo nao)"
echo "systemd (pid 1): $(ps -p 1 -o comm= 2>/dev/null)"

sec "2. Rede - endereços e rotas"
run ip -brief addr
run ip route
echo "--- nameservers ---"; cat /etc/resolv.conf 2>/dev/null
echo "--- /etc/network/interfaces (Debian) ---"; cat /etc/network/interfaces 2>/dev/null || echo "(nao existe)"
echo "--- netplan (Ubuntu) ---"; cat /etc/netplan/*.yaml 2>/dev/null || echo "(nao existe)"

sec "3. Portas escutando"
run ss -tlnp

sec "4. Serviços"
for s in apache2 mariadb mysql; do
  printf "%-10s : " "$s"; systemctl is-active "$s" 2>/dev/null || echo "n/a"
  printf "%-10s enabled: " "$s"; systemctl is-enabled "$s" 2>/dev/null || echo "n/a"
done

sec "5. Firewall"
if command -v ufw >/dev/null 2>&1; then run ufw status verbose; else echo "ufw nao instalado"; fi

sec "6. Apache - versão, módulos, sites e configtest"
command -v apache2ctl >/dev/null && { run apache2 -v; run apache2ctl -M; run apache2ctl -S; run apache2ctl configtest; } || echo "Apache nao instalado"
echo "--- sites-enabled ---"; ls -l /etc/apache2/sites-enabled/ 2>/dev/null
echo "--- ports.conf ---"; cat /etc/apache2/ports.conf 2>/dev/null

sec "7. PHP - versão e módulos"
command -v php >/dev/null && { run php -v; run php -m; } || echo "PHP nao instalado"

sec "8. MariaDB - versão, bancos e usuários"
command -v mariadb >/dev/null && { run mariadb --version; } || echo "MariaDB nao instalado"
echo "--- SHOW DATABASES ---";   mariadb -e "SHOW DATABASES;" 2>&1
echo "--- usuarios ---";         mariadb -e "SELECT User,Host FROM mysql.user;" 2>&1
echo "--- grants wpuser ---";    mariadb -e "SHOW GRANTS FOR '${DB_USER}'@'localhost';" 2>&1
echo "--- teste login wpuser ---"
mariadb -u "${DB_USER}" -p"${DB_PASS:-SenhaForte123!}" -D "${DB_NAME}" -e "SELECT 1 AS conectou;" 2>&1

sec "9. WordPress - arquivos e config"
echo "--- diretório ---"; ls -la "${WP_DIR}" 2>/dev/null | head -30
echo "--- wp-config.php (dados do banco) ---"
grep -E "DB_NAME|DB_USER|DB_PASSWORD|DB_HOST|table_prefix" "${WP_DIR}/wp-config.php" 2>/dev/null
echo "--- chaves SALT trocadas? ---"
grep -q "put your unique phrase here" "${WP_DIR}/wp-config.php" 2>/dev/null && echo "NAO trocadas" || echo "trocadas (ou arquivo ausente)"

sec "10. WordPress - bootstrap via PHP (wp-load)"
if command -v php >/dev/null 2>&1 && [ -f "${WP_DIR}/wp-load.php" ]; then
  php -r "require '${WP_DIR}/wp-load.php'; echo is_blog_installed()?'instalado':'NAO instalado', PHP_EOL;" 2>&1
else
  echo "php ou wp-load.php ausente"
fi

sec "11. Logs do Apache (últimas linhas)"
tail -n 15 /var/log/apache2/error.log 2>/dev/null || echo "(sem error.log)"
tail -n 15 /var/log/apache2/wordpress_error.log 2>/dev/null || echo "(sem wordpress_error.log)"
echo "--- access log ---"; tail -n 10 /var/log/apache2/wordpress_access.log 2>/dev/null || echo "(sem wordpress_access.log)"

sec "12. Testes HTTP"
curl -s -o /dev/null -m 8 -w "localhost        -> HTTP %{http_code}\n" http://localhost/ 2>&1
curl -s -o /dev/null -m 8 -w "${IP_SERVIDOR}   -> HTTP %{http_code}\n" "http://${IP_SERVIDOR}/" 2>&1
echo "--- content-type do localhost ---"; curl -sI -m 8 http://localhost/ 2>&1 | head -15

echo
echo "##################### FIM DO RELATORIO #####################"
echo "Arquivo salvo em: $OUT"

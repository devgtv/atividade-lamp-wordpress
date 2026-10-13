#!/usr/bin/env bash
# =============================================================================
# chaves-seguranca.sh
# -----------------------------------------------------------------------------
# Corrige as chaves de segurança (SALT) do wp-config.php de uma instalação já
# existente, SEM reinstalar o WordPress.
#
# Útil quando o wp-config.php ainda tem "put your unique phrase here".
# Funciona COM ou SEM internet (gera as chaves localmente se necessário).
#
# Uso:  sudo bash scripts/chaves-seguranca.sh
# =============================================================================

set -e
source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

WP_CONFIG="${WP_DIR}/wp-config.php"
[ -f "${WP_CONFIG}" ] || { echo "ERRO: ${WP_CONFIG} não encontrado. Rode o script 05 antes."; exit 1; }

echo ">>> Baixando chaves oficiais (se houver internet)..."
SALTS="$(curl -fsS --max-time 15 https://api.wordpress.org/secret-key/1.1/salt/ 2>/dev/null || true)"
case "$SALTS" in
  *"define("*) : ;;
  *) SALTS="" ;;
esac
[ -z "$SALTS" ] && echo "    (sem internet: gerando chaves localmente)"

sudo -u www-data python3 - "${WP_CONFIG}" "$SALTS" <<'PY'
import re, sys, secrets, string

path = sys.argv[1]
salts = sys.argv[2].strip()
if not salts or "define(" not in salts:
    chars = string.ascii_letters + string.digits + "!@#$%^&*()-_[]{}<>~+=,.;:/?|"
    names = ["AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
             "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"]
    salts = "\n".join(
        "define( '%s', '%s' );" % (n, "".join(secrets.choice(chars) for _ in range(64)))
        for n in names)
    origem = "geradas localmente"
else:
    origem = "api.wordpress.org"

with open(path) as f:
    content = f.read()
text = content
content2, n = re.subn(r"define\( 'AUTH_KEY'.*?define\( 'NONCE_SALT',[^\n]*\n",
                      lambda m: salts.strip() + "\n", content, flags=re.S)
if n == 0 and "put your unique phrase here" in content:
    content2 = re.sub(r"<\?php\n", "<?php\n" + salts.strip() + "\n", content, count=1)
    n = 1
with open(path, "w") as f:
    f.write(content2)
print("    chaves aplicadas (%s)" % origem if n else "    AVISO: bloco de chaves não encontrado")
PY

echo ">>> Verificando..."
if grep -q "put your unique phrase here" "${WP_CONFIG}"; then
  echo "    AINDA há placeholders - verifique o wp-config.php"
  exit 1
fi
echo "    OK: chaves de segurança definidas."

# Se o WP-CLI estiver disponível, valida o wp-config.php.
if command -v wp >/dev/null 2>&1; then
  sudo -u www-data env HOME=/var/www wp --path="${WP_DIR}" config get AUTH_KEY >/dev/null 2>&1 \
    && echo "    OK: WP-CLI conseguiu carregar o wp-config.php." \
    || echo "    AVISO: WP-CLI não conseguiu carregar o wp-config.php (verifique erros de PHP)."
fi

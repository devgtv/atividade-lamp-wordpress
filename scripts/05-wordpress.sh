#!/usr/bin/env bash
# =============================================================================
# 05-wordpress.sh
# -----------------------------------------------------------------------------
# Parte 5 do roteiro: baixar, instalar e configurar o WordPress.
#
# Passos:
#   1. baixar o pacote "latest.tar.gz" do site oficial;
#   2. extrair e mover para /var/www/wordpress;
#   3. ajustar dono (www-data) e permissões de arquivos/pastas;
#   4. criar o wp-config.php a partir do exemplo e preencher os dados do banco;
#   5. substituir as chaves de segurança (SALT).
# =============================================================================

set -e

# Carrega as variáveis comuns
source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Baixando o WordPress mais recente..."
cd /tmp
wget -q https://wordpress.org/latest.tar.gz

echo ">>> Extraindo o pacote..."
tar -xzf latest.tar.gz

echo ">>> Movendo para ${WP_DIR}..."
[ -d "${WP_DIR}" ] && rm -rf "${WP_DIR}"   # remove instalação anterior, se houver
mv /tmp/wordpress "${WP_DIR}"

# -----------------------------------------------------------------------------
# Permissões
#   Dono  : www-data:www-data  -> é o usuário do Apache; ele precisa ler/escrever
#   pastas: 755 (rwxr-xr-x)
#   arquivos: 644 (rw-r--r--)
# -----------------------------------------------------------------------------
echo ">>> Ajustando dono e permissões..."
chown -R www-data:www-data "${WP_DIR}"
find "${WP_DIR}" -type d -exec chmod 755 {} \;
find "${WP_DIR}" -type f -exec chmod 644 {} \;

# -----------------------------------------------------------------------------
# Configuração da conexão com o banco (wp-config.php)
#   cp  : copia o arquivo de exemplo
#   sed : substitui os placeholders pelos valores reais
# -----------------------------------------------------------------------------
echo ">>> Criando e preenchendo o wp-config.php..."
cd "${WP_DIR}"
sudo -u www-data cp wp-config-sample.php wp-config.php
sudo -u www-data sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
sudo -u www-data sed -i "s/username_here/${DB_USER}/"     wp-config.php
sudo -u www-data sed -i "s/password_here/${DB_PASS}/"     wp-config.php

# -----------------------------------------------------------------------------
# Chaves de segurança (AUTH_KEY, SECURE_AUTH_KEY, LOGGED_IN_KEY, NONCE_KEY...)
# São strings aleatórias que melhoram a segurança das sessões/cookies.
# Tentamos baixar as oficiais de api.wordpress.org; se não houver internet
# (ex.: VM só em host-only), GERAMOS chaves aleatórias localmente. Assim as
# chaves NUNCA ficam com o valor de exemplo.
# -----------------------------------------------------------------------------
echo ">>> Aplicando as chaves de segurança (SALT)..."
SALTS="$(curl -fsS --max-time 15 https://api.wordpress.org/secret-key/1.1/salt/ 2>/dev/null || true)"
# Só aceitamos a resposta se ela realmente contiver definições "define(".
case "$SALTS" in
  *"define("*) : ;;
  *) SALTS="" ;;
esac
[ -z "$SALTS" ] && echo "    (sem internet ou resposta inválida: gerando chaves localmente)"

sudo -u www-data python3 - "$WP_DIR/wp-config.php" "$SALTS" <<'PY'
import re, sys, secrets, string

path = sys.argv[1]
salts = sys.argv[2].strip()

# Fallback offline: gera 8 chaves aleatórias no formato do WordPress.
if not salts or "define(" not in salts:
    chars = string.ascii_letters + string.digits + "!@#$%^&*()-_[]{}<>~+=,.;:/?|"
    names = ["AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
             "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"]
    salts = "\n".join(
        "define( '%s', '%s' );" % (n, "".join(secrets.choice(chars) for _ in range(64)))
        for n in names
    )
    origem = "geradas localmente"
else:
    origem = "api.wordpress.org"

with open(path) as f:
    content = f.read()

# Substitui todo o bloco entre o AUTH_KEY e o NONCE_SALT (formato do WordPress).
pattern = r"define\( 'AUTH_KEY'.*?define\( 'NONCE_SALT',[^\n]*\n"
content2, n = re.subn(pattern, lambda m: salts.strip() + "\n", content, flags=re.S)

# Sanidade: se o bloco não foi encontrado, grava as chaves após o <?php.
if n == 0:
    content2 = re.sub(r"<\?php\n", "<?php\n" + salts.strip() + "\n", content, count=1)

with open(path, "w") as f:
    f.write(content2)

print("    chaves de segurança aplicadas (%s)" % origem)
PY

# -----------------------------------------------------------------------------
# Dica de segurança: desabilitar edição de arquivos pelo painel (opcional).
# Descomente a linha abaixo no wp-config.php para ativar:
#   define('DISALLOW_FILE_EDIT', true);
# -----------------------------------------------------------------------------

echo
echo ">>> Concluído: WordPress instalado em ${WP_DIR}."
echo "    Próximo passo: configurar o VirtualHost (script 06)."

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
# Buscamos as chaves oficiais em api.wordpress.org e substituímos o bloco padrão.
# -----------------------------------------------------------------------------
echo ">>> Baixando e aplicando as chaves de segurança (SALT)..."
SALTS="$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)"

# Remove as 8 linhas de exemplo ("put your unique phrase here") e insere as reais.
# Usamos um arquivo temporário e reconstruímos o wp-config.php.
if [ -n "$SALTS" ]; then
  sudo -u www-data python3 - "$WP_DIR/wp-config.php" "$SALTS" <<'PY'
import re, sys
path, salts = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Substitui todo o bloco entre os marcadores padrão do WordPress
pattern = (r"define\( 'AUTH_KEY'.*?define\( 'NONCE_SALT',[^\n]*\n")
new = salts.strip() + "\n"
content = re.sub(pattern, new, content, flags=re.S)
with open(path, "w") as f:
    f.write(content)
PY
  echo "    chaves de segurança aplicadas."
else
  echo "    AVISO: não foi possível baixar as chaves (sem internet?). WordPress funciona, mas troque-as manualmente."
fi

# -----------------------------------------------------------------------------
# Dica de segurança: desabilitar edição de arquivos pelo painel (opcional).
# Descomente a linha abaixo no wp-config.php para ativar:
#   define('DISALLOW_FILE_EDIT', true);
# -----------------------------------------------------------------------------

echo
echo ">>> Concluído: WordPress instalado em ${WP_DIR}."
echo "    Próximo passo: configurar o VirtualHost (script 06)."

#!/usr/bin/env bash
# =============================================================================
# testar-conexao.sh
# -----------------------------------------------------------------------------
# Testa se TUDO se conecta automaticamente:
#   MariaDB rodando -> banco e usuário existem -> o usuário loga com a senha
#   -> o wp-config.php aponta para esse banco/usuário -> o WordPress acessa.
#
# Uso:  sudo bash scripts/testar-conexao.sh
#
# Saída: linhas [OK] ou [FALHA] e, no fim, um resumo.
# =============================================================================

source "$(dirname "$0")/00-variaveis.sh"

OK=0; FAIL=0
ok()   { echo "  [OK]    $1"; OK=$((OK+1)); }
falha(){ echo "  [FALHA] $1"; FAIL=$((FAIL+1)); }

echo "==================================================================="
echo " Teste de conexão do WordPress com o MariaDB"
echo "==================================================================="

# --- 1) Serviço do MariaDB ----------------------------------------------------
echo "1) Serviço MariaDB"
if systemctl is-active --quiet mariadb; then ok "mariadb está ativo"; else falha "mariadb NÃO está ativo (sudo systemctl start mariadb)"; fi

# --- 2) Banco existe ----------------------------------------------------------
echo "2) Banco de dados '${DB_NAME}'"
if mariadb -N -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" | grep -q "${DB_NAME}"; then
  ok "banco '${DB_NAME}' existe"
else
  falha "banco '${DB_NAME}' NÃO existe"
fi

# --- 3) Usuário e privilégios -------------------------------------------------
echo "3) Usuário '${DB_USER}' e privilégios"
if mariadb -N -e "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost'" | grep -q "${DB_USER}"; then
  ok "usuário '${DB_USER}'@localhost existe"
else
  falha "usuário '${DB_USER}'@localhost NÃO existe"
fi
if mariadb -N -e "SHOW GRANTS FOR '${DB_USER}'@'localhost'" 2>/dev/null | grep -q "${DB_NAME}"; then
  ok "usuário tem privilégios em ${DB_NAME}.*"
else
  falha "usuário NÃO tem privilégios em ${DB_NAME}.*"
fi

# --- 4) LOGIN de verdade com a senha do wp-config -----------------------------
echo "4) Login como '${DB_USER}' usando a senha configurada"
if mariadb -u "${DB_USER}" -p"${DB_PASS}" -D "${DB_NAME}" -e "SELECT 1;" >/dev/null 2>&1; then
  ok "login com usuário/senha FUNCIONOU (é assim que o WordPress conecta)"
else
  falha "login FALHOU (senha errada ou usuário sem acesso)"
fi

# --- 5) wp-config.php aponta para os dados corretos ---------------------------
echo "5) wp-config.php"
if [ -f "${WP_DIR}/wp-config.php" ]; then
  grep -q "DB_NAME', '${DB_NAME}'"     "${WP_DIR}/wp-config.php" && ok "DB_NAME correto"       || falha "DB_NAME diferente do esperado"
  grep -q "DB_USER', '${DB_USER}'"     "${WP_DIR}/wp-config.php" && ok "DB_USER correto"       || falha "DB_USER diferente do esperado"
  grep -q "password_here"              "${WP_DIR}/wp-config.php" && falha "senha ainda é placeholder" || ok "senha preenchida"
  grep -q "put your unique phrase"     "${WP_DIR}/wp-config.php" && falha "chaves de segurança NÃO trocadas" || ok "chaves de segurança trocadas"
else
  falha "wp-config.php NÃO encontrado em ${WP_DIR}"
fi

# --- 6) O PHP (como o WordPress) conecta no banco -----------------------------
echo "6) Conexão pelo PHP (mysqli) - é assim que o WordPress conecta"
if command -v php >/dev/null 2>&1; then
  if SAIDA_PHP="$(DB_USER="${DB_USER}" DB_PASS="${DB_PASS}" DB_NAME="${DB_NAME}" php -r \
      '$m=@new mysqli("localhost",getenv("DB_USER"),getenv("DB_PASS"),getenv("DB_NAME"));
       if($m->connect_error){fwrite(STDERR,$m->connect_error);exit(1);} echo "ok";' 2>&1)"; then
    ok "PHP conectou no banco (mysqli): ${SAIDA_PHP}"
  else
    falha "PHP NÃO conectou. Erro: ${SAIDA_PHP}"
  fi
else
  echo "  [--]    PHP indisponível; pulando"
fi

# --- 7) O WordPress carrega (bootstrap wp-load.php) ---------------------------
echo "7) O WordPress inicializa (carrega o núcleo)"
if command -v php >/dev/null 2>&1 && [ -f "${WP_DIR}/wp-config.php" ]; then
  if SAIDA_LOAD="$(sudo -u www-data php -r \
      "require '${WP_DIR}/wp-load.php'; echo is_blog_installed()?'instalado':'nao-instalado';" 2>&1)"; then
    ok "wp-load.php carregou: ${SAIDA_LOAD}"
  else
    falha "wp-load.php falhou. Erro:"
    echo "${SAIDA_LOAD}" | sed 's/^/          /'
  fi
else
  echo "  [--]    PHP/wp-config indisponível; pulando"
fi

# --- 8) REST API do WordPress (usada pelo editor de blocos) -------------------
# É o que gera o erro "Updating failed. The response is not a valid JSON response."
# quando o .htaccess/rewrite está faltando (permalinks bonitos sem regras).
echo "8) REST API do WordPress (wp-json) - usada pelo editor"
if command -v curl >/dev/null 2>&1 && command -v php >/dev/null 2>&1 && [ -f "${WP_DIR}/wp-config.php" ]; then
  REST_ROOT="$(sudo -u www-data php -r \
    "\$_SERVER['SERVER_SOFTWARE']='Apache/2.4'; \$_SERVER['HTTP_HOST']='localhost'; \$_SERVER['SERVER_PORT']='80'; require '${WP_DIR}/wp-load.php'; echo rest_url();" 2>/dev/null)"
  if [ -n "${REST_ROOT}" ] && curl -s -m 8 "${REST_ROOT}" | grep -q '^{'; then
    ok "REST API responde JSON em ${REST_ROOT}"
  else
    falha "REST API NÃO retornou JSON (${REST_ROOT:-indefinido}) -> o editor dará 'not a valid JSON response'"
    echo "          Correção: sudo bash scripts/09-finalizar-wordpress.sh (recria o .htaccess)"
  fi
else
  echo "  [--]    curl/PHP/WordPress indisponível; pulando"
fi

echo "==================================================================="
echo " RESUMO: ${OK} OK, ${FAIL} FALHA(S)"
[ "${FAIL}" -eq 0 ] && echo " => Conexão automática FUNCIONANDO." || echo " => Há falhas; revise os itens acima."
echo "==================================================================="

exit "${FAIL}"

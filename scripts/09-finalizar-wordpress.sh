#!/usr/bin/env bash
# =============================================================================
# 09-finalizar-wordpress.sh
# -----------------------------------------------------------------------------
# Parte 7 do roteiro, automatizada com o WP-CLI:
#   - conclui a instalação (título, usuário admin, senha, e-mail);
#   - cria a página "Integrantes do Grupo";
#   - define essa página como página inicial;
#   - ativa URLs amigáveis (permalinks).
#
# Isso substitui os cliques no navegador. Se preferir fazer pelo navegador,
# apenas NÃO rode este script (a instalação continua disponível em
# http://<IP>/wp-admin/install.php).
#
# O WP-CLI é uma ferramenta oficial de linha de comando para o WordPress.
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1) Instalar o WP-CLI (se ainda não existir)
# -----------------------------------------------------------------------------
if ! command -v wp >/dev/null 2>&1; then
  echo ">>> Instalando o WP-CLI em /usr/local/bin/wp..."
  curl -s -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /tmp/wp-cli.phar
  mv /tmp/wp-cli.phar /usr/local/bin/wp
fi

# Função utilitária: roda o wp como o usuário do Apache (www-data).
# HOME=/var/www evita avisos de cache; --path aponta para a instalação.
run_wp() {
  sudo -u www-data env HOME=/var/www wp --path="${WP_DIR}" "$@"
}

# -----------------------------------------------------------------------------
# 2) Concluir a instalação do núcleo (idempotente)
#    wp core is-installed retorna 0 se já instalado.
# -----------------------------------------------------------------------------
if run_wp core is-installed >/dev/null 2>&1; then
  echo ">>> WordPress já está instalado. Pulando 'wp core install'."
else
  echo ">>> Concluindo a instalação do WordPress (wp core install)..."
  run_wp core install \
    --url="http://${IP_SERVIDOR}" \
    --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" \
    --skip-email
fi

# -----------------------------------------------------------------------------
# 3) Montar o HTML da página de integrantes a partir do array MEMBROS
# -----------------------------------------------------------------------------
echo ">>> Montando a página de integrantes..."
ITENS=""
for membro in "${MEMBROS[@]}"; do
  ITENS="${ITENS}<li>${membro}</li>"
done

CONTEUDO="<h1>Integrantes do Grupo ${GRUPO}</h1>
<p>Disciplina: CIC1001 – Redes de Computadores II</p>
<ul>${ITENS}</ul>
<p>Servidor LAMP publicado em <strong>http://${DOMINIO}</strong>.</p>"

TITULO_PAGINA="Integrantes do Grupo ${GRUPO}"

# -----------------------------------------------------------------------------
# 4) Criar a página (ou reaproveitar, se já existir) e defini-la como inicial
# -----------------------------------------------------------------------------
PAGE_ID="$(run_wp post list --post_type=page --name=integrantes-do-grupo-${GRUPO} --field=ID 2>/dev/null || true)"

if [ -z "${PAGE_ID}" ]; then
  echo ">>> Criando a página '${TITULO_PAGINA}'..."
  PAGE_ID="$(run_wp post create \
    --post_type=page \
    --post_title="${TITULO_PAGINA}" \
    --post_content="${CONTEUDO}" \
    --post_status=publish \
    --porcelain)"
else
  echo ">>> Página já existe (ID ${PAGE_ID}). Atualizando conteúdo..."
  run_wp post update "${PAGE_ID}" --post_content="${CONTEUDO}"
fi

echo ">>> Definindo a página (ID ${PAGE_ID}) como página inicial..."
run_wp option update show_on_front page
run_wp option update page_on_front "${PAGE_ID}"

# -----------------------------------------------------------------------------
# 5) URLs amigáveis (permalinks) - exige o rewrite que já habilitamos no Apache
# -----------------------------------------------------------------------------
echo ">>> Ativando permalinks amigáveis..."
run_wp rewrite structure '/%postname%/' --hard
run_wp rewrite flush --hard || true

echo
echo ">>> Concluído! Acesse no navegador da hospedeira:"
echo "      Site     : http://${IP_SERVIDOR}/"
echo "      Painel   : http://${IP_SERVIDOR}/wp-admin/"
echo "      Usuário  : ${ADMIN_USER}"
echo "      Senha    : ${ADMIN_PASS}"

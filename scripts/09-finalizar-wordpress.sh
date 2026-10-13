#!/usr/bin/env bash
# =============================================================================
# 09-finalizar-wordpress.sh
# -----------------------------------------------------------------------------
# Parte 7 do roteiro, automatizada SEM depender do WP-CLI.
#
# Antes usávamos o WP-CLI (phar), mas em algumas VMs o phar fica corrompido e
# gera erros do tipo "phar ... launcher ... vendor". Aqui fazemos tudo com o
# próprio PHP do WordPress (já instalado):
#   - conclui a instalação (título, usuário admin, senha, e-mail);
#   - cria a página "Integrantes do Grupo";
#   - define essa página como página inicial;
#   - ativa URLs amigáveis (permalinks).
#
# Isso substitui os cliques no navegador. Se preferir fazer pelo navegador,
# NÃO rode este script e acesse http://<IP>/wp-admin/install.php.
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

if [ ! -f "${WP_DIR}/wp-config.php" ]; then
  echo "ERRO: ${WP_DIR}/wp-config.php não encontrado. Rode o script 05 antes."
  exit 1
fi

# -----------------------------------------------------------------------------
# Monta o HTML da página de integrantes a partir do array MEMBROS
# -----------------------------------------------------------------------------
ITENS=""
for membro in "${MEMBROS[@]}"; do
  # Escapa aspas simples (usamos env; o PHP lê como string simples)
  ITENS="${ITENS}<li>${membro}</li>"
done

PAGE_TITLE="Integrantes do Grupo ${GRUPO}"
PAGE_SLUG="integrantes-do-grupo-${GRUPO}"
PAGE_CONTENT="<h1>Integrantes do Grupo ${GRUPO}</h1>
<p>Disciplina: CIC1001 – Redes de Computadores II</p>
<ul>${ITENS}</ul>
<p>Servidor LAMP publicado em <strong>http://${DOMINIO}</strong>.</p>"

# -----------------------------------------------------------------------------
# Escreve um instalador PHP temporário
# -----------------------------------------------------------------------------
INSTALADOR="$(mktemp /tmp/wp-finalizar.XXXXXX.php)"
chmod 644 "${INSTALADOR}"

cat > "${INSTALADOR}" <<'PHP'
<?php
// Desabilita envio de e-mail (a VM pode não ter servidor de e-mail).
if ( ! function_exists( 'wp_mail' ) ) {
    function wp_mail( $to, $subject, $message, $headers = '', $attachments = array() ) {
        return false;
    }
}

// Define a URL/host ANTES de carregar o WordPress, para gravar o endereço certo.
$host = getenv( 'WP_HOST' );
$_SERVER['HTTP_HOST']   = $host;
$_SERVER['SERVER_NAME'] = $host;
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_PORT'] = '80';

define( 'WP_INSTALLING', true );
require_once getenv( 'WP_DIR' ) . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';

$title = getenv( 'WP_TITLE' );
$user  = getenv( 'WP_ADMIN_USER' );
$pass  = getenv( 'WP_ADMIN_PASS' );
$email = getenv( 'WP_ADMIN_EMAIL' );

if ( is_blog_installed() ) {
    fwrite( STDOUT, "WordPress já estava instalado.\n" );
} else {
    $result = wp_install( $title, $user, $email, true, '', $pass );
    fwrite( STDOUT, "WordPress instalado. Admin: {$user}\n" );
}

// Garante que o endereço do site seja o IP (http://<host>).
update_option( 'siteurl', "http://{$host}" );
update_option( 'home',    "http://{$host}" );

// --------------------------- Página de integrantes ---------------------------
$page_title = getenv( 'WP_PAGE_TITLE' );
$page_slug  = getenv( 'WP_PAGE_SLUG' );
$content    = getenv( 'WP_PAGE_CONTENT' );

$page = get_page_by_path( $page_slug );
if ( $page ) {
    wp_update_post( array( 'ID' => $page->ID, 'post_content' => $content ) );
    $page_id = $page->ID;
    fwrite( STDOUT, "Página de integrantes atualizada (ID {$page_id}).\n" );
} else {
    $page_id = wp_insert_post( array(
        'post_title'   => $page_title,
        'post_name'    => $page_slug,
        'post_content' => $content,
        'post_status'  => 'publish',
        'post_type'    => 'page',
    ) );
    if ( is_wp_error( $page_id ) ) {
        fwrite( STDERR, "Erro ao criar a página: " . $page_id->get_error_message() . "\n" );
        exit( 1 );
    }
    fwrite( STDOUT, "Página de integrantes criada (ID {$page_id}).\n" );
}

// --------------------------- Página inicial ----------------------------------
update_option( 'show_on_front', 'page' );
update_option( 'page_on_front', $page_id );
fwrite( STDOUT, "Definida como página inicial.\n" );

// --------------------------- Permalinks amigáveis ----------------------------
update_option( 'permalink_structure', '/%postname%/' );
global $wp_rewrite;
if ( $wp_rewrite ) {
    $wp_rewrite->set_permalink_structure( '/%postname%/' );
    $wp_rewrite->flush_rules( true );
}
fwrite( STDOUT, "Permalinks amigáveis ativados.\n" );
PHP

echo ">>> Concluindo a instalação do WordPress (via PHP)..."
if sudo -u www-data env \
    WP_DIR="${WP_DIR}" \
    WP_HOST="${IP_SERVIDOR}" \
    WP_TITLE="${SITE_TITLE}" \
    WP_ADMIN_USER="${ADMIN_USER}" \
    WP_ADMIN_PASS="${ADMIN_PASS}" \
    WP_ADMIN_EMAIL="${ADMIN_EMAIL}" \
    WP_PAGE_TITLE="${PAGE_TITLE}" \
    WP_PAGE_SLUG="${PAGE_SLUG}" \
    WP_PAGE_CONTENT="${PAGE_CONTENT}" \
    php "${INSTALADOR}"; then
  echo "    instalação concluída."
else
  echo "ERRO na finalização via PHP. Verifique:"
  echo "  - banco MariaDB ativo e credenciais corretas no wp-config.php"
  echo "  - o módulo php-mysql instalado (php -m | grep mysqli)"
  rm -f "${INSTALADOR}"
  exit 1
fi
rm -f "${INSTALADOR}"

echo
echo ">>> Concluído! Acesse no navegador da hospedeira:"
echo "      Site     : http://${IP_SERVIDOR}/"
echo "      Painel   : http://${IP_SERVIDOR}/wp-admin/"
echo "      Usuário  : ${ADMIN_USER}"
echo "      Senha    : ${ADMIN_PASS}"

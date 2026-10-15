#!/usr/bin/env bash
# =============================================================================
# garantir-htaccess.sh
# -----------------------------------------------------------------------------
# Garante que o WordPress tenha PERMALINKS amigáveis E o arquivo .htaccess com
# as regras de rewrite do Apache. É isso que faz a REST API (/wp-json/) responder
# JSON; sem ele o editor mostra:
#   "Updating failed. The response is not a valid JSON response."
#
# Por que este script existe:
#   Ao rodar o WordPress pela linha de comando (CLI), ele NÃO detecta o Apache
#   ($_SERVER['SERVER_SOFTWARE'] fica vazio => $is_apache = false). Nesse caso
#   apache_mod_loaded() retorna false, got_mod_rewrite() retorna false e o
#   flush_rules() NÃO grava o .htaccess. Aqui declaramos o Apache e gravamos o
#   arquivo explicitamente. É IDEMPOTENTE (pode rodar quantas vezes quiser).
#
# Uso:
#   sudo bash scripts/garantir-htaccess.sh
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash $0"
  exit 1
fi

if [ ! -f "${WP_DIR}/wp-config.php" ]; then
  echo ">>> ${WP_DIR}/wp-config.php ainda não existe; pulando o .htaccess."
  exit 0
fi

echo ">>> Garantindo permalinks e .htaccess do WordPress..."

sudo -u www-data env WP_DIR="${WP_DIR}" php -r '
$dir = getenv( "WP_DIR" );

// Em CLI o WordPress não sabe que roda sob Apache; sem isto ele não grava o .htaccess.
$_SERVER["SERVER_SOFTWARE"] = "Apache/2.4";
$_SERVER["HTTP_HOST"]       = "localhost";
$_SERVER["SERVER_NAME"]     = "localhost";
$_SERVER["REQUEST_URI"]     = "/";
$_SERVER["SERVER_PORT"]     = "80";

// Evita que o WordPress "morra" quando ainda não foi instalado (sem tabelas).
define( "WP_INSTALLING", true );

require $dir . "/wp-load.php";
require_once ABSPATH . "wp-admin/includes/file.php";
require_once ABSPATH . "wp-admin/includes/misc.php";

if ( ! is_blog_installed() ) {
    echo "    WordPress ainda não foi instalado; pulando o .htaccess.\n";
    exit( 0 );
}

if ( "/%postname%/" !== get_option( "permalink_structure" ) ) {
    update_option( "permalink_structure", "/%postname%/" );
}

global $wp_rewrite;
$wp_rewrite->set_permalink_structure( "/%postname%/" );
$wp_rewrite->flush_rules( true );

$htaccess = rtrim( ABSPATH, "/" ) . "/.htaccess";
$conteudo = is_readable( $htaccess ) ? (string) file_get_contents( $htaccess ) : "";
if ( false === strpos( $conteudo, "BEGIN WordPress" ) ) {
    $regras = "<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteBase /\n"
        . "RewriteRule ^index\\.php$ - [L]\n"
        . "RewriteCond %{REQUEST_FILENAME} !-f\n"
        . "RewriteCond %{REQUEST_FILENAME} !-d\n"
        . "RewriteRule . /index.php [L]\n</IfModule>";
    if ( function_exists( "insert_with_markers" ) ) {
        insert_with_markers( $htaccess, "WordPress", explode( "\n", $regras ) );
    } else {
        file_put_contents( $htaccess, "# BEGIN WordPress\n{$regras}\n# END WordPress\n" );
    }
    echo "    .htaccess criado/atualizado em {$htaccess}\n";
} else {
    echo "    .htaccess já contém as regras do WordPress (ok)\n";
}
echo "    permalinks amigáveis e rewrite garantidos.\n";
'

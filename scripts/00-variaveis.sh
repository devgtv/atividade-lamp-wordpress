#!/usr/bin/env bash
# =============================================================================
# 00-variaveis.sh
# -----------------------------------------------------------------------------
# Este arquivo NÃO é executado sozinho. Ele apenas centraliza as variáveis
# usadas por todos os outros scripts, para que o grupo altere os dados em um
# único lugar (evitando erro de digitação em vários arquivos).
#
# Os demais scripts fazem:  source "$(dirname "$0")/00-variaveis.sh"
# =============================================================================

# --- Dados do grupo -----------------------------------------------------------
export GRUPO="grupo1"                                   # identificador do grupo
export DOMINIO="www.${GRUPO}.redes2.internal"           # nome de domínio interno

# --- Dados de rede da VM ------------------------------------------------------
export IP_SERVIDOR="192.168.56.10"                      # IP fixo da VM (rede host-only/bridge)

# --- Dados do banco de dados (WordPress) --------------------------------------
export DB_NAME="wordpress"                              # nome do banco
export DB_USER="wpuser"                                 # usuário do WordPress no banco
export DB_PASS="SenhaForte123!"                         # senha do usuário do banco

# --- Caminhos do WordPress / Apache -------------------------------------------
export WP_DIR="/var/www/wordpress"                      # onde o WordPress ficará instalado
export APACHE_SITE="/etc/apache2/sites-available/wordpress.conf"

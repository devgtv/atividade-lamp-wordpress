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
export DOMINIO="www.${GRUPO}.redes2.internal"           # nome de domínio interno (com www)
export DOMINIO_CURTO="${GRUPO}.redes2.internal"         # variação sem o www (para o ServerAlias)

# --- Dados de rede da VM ------------------------------------------------------
export IP_SERVIDOR="192.168.56.10"                      # IP fixo da VM (rede host-only/bridge)
export IP_MASCARA="24"                                  # máscara da rede host-only (CIDR)

# Nomes que serão resolvidos para o IP_SERVIDOR no /etc/hosts.
export HOSTS_DOMINIOS="${DOMINIO} ${DOMINIO_CURTO}"

# URL "bonita" usada apenas em relatórios/mensagens. O site em si funciona
# TANTO por IP QUANTO por domínio, graças à URL dinâmica (ver
# scripts/ajustar-url-dinamica.sh): o WordPress assume o host que o navegador
# usou. Assim nada quebra ao rodar a VM em outro PC.
export URL_SITE="http://${DOMINIO}"

# --- Dados do banco de dados (WordPress) --------------------------------------
export DB_NAME="wordpress"                              # nome do banco
export DB_USER="wpuser"                                 # usuário do WordPress no banco
export DB_PASS="SenhaForte123!"                         # senha do usuário do banco

# --- Caminhos do WordPress / Apache -------------------------------------------
export WP_DIR="/var/www/wordpress"                      # onde o WordPress ficará instalado
export APACHE_SITE="/etc/apache2/sites-available/wordpress.conf"

# --- Site e usuário administrador (Parte 7 - conclusão da instalação) ---------
export SITE_TITLE="Blog do Grupo ${GRUPO}"
export ADMIN_USER="admin"
export ADMIN_PASS="AdminWordPress123!"
export ADMIN_EMAIL="admin@${DOMINIO}"

# --- Integrantes do grupo (usados na página inicial) --------------------------
# Troque pelos nomes/matrículas reais. Para mais/menos integrantes, basta
# adicionar ou remover linhas deste array.
export MEMBROS=(
  "Integrante 1 – matrícula"
  "Integrante 2 – matrícula"
  "Integrante 3 – matrícula"
  "Integrante 4 – matrícula"
  "Integrante 5 – matrícula"
)

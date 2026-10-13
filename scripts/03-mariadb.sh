#!/usr/bin/env bash
# =============================================================================
# 03-mariadb.sh
# -----------------------------------------------------------------------------
# Parte 3 do roteiro: instalar o MariaDB (banco de dados - o "M" do LAMP) e
# criar o banco e o usuário que o WordPress vai usar.
#
# Por que NÃO usar o usuário 'root' do banco no WordPress?
#   - Princípio do MENOR PRIVILÉGIO: o WordPress só precisa dos dados DELE.
#   - Se o site for invadido, o atacante não terá acesso a outros bancos.
# =============================================================================

set -e

# Carrega as variáveis comuns (DB_NAME, DB_USER, DB_PASS, etc.)
source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

echo ">>> Instalando o servidor MariaDB..."
apt install -y mariadb-server

echo ">>> Habilitando e iniciando o serviço..."
systemctl enable mariadb
systemctl restart mariadb

# -----------------------------------------------------------------------------
# mariadb-secure-installation (antes: mysql_secure_installation)
# Remove acessos anônimos, desabilita login remoto do root e afins.
# Neste script ele roda de forma não interativa usando heredoc (<<EOF).
# -----------------------------------------------------------------------------
echo ">>> Aplicando configuração básica de segurança do MariaDB..."
mariadb <<SQL
-- Remove anonimos e acesso remoto do root (equivalente ao secure-installation)
DELETE FROM mysql.global_priv WHERE User='';
DROP DATABASE IF EXISTS test;
SQL

# muda/define a senha do root do banco (opcional em ambientes locais):
# mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'SenhaRootForte!';"

# -----------------------------------------------------------------------------
# Criação do banco e do usuário do WordPress
#   utf8mb4  : suporta todos os caracteres Unicode (inclusive emojis)
#   @localhost: o usuário só pode conectar-se a partir da própria máquina
#               (o WordPress roda localmente, então não precisa de acesso remoto)
# -----------------------------------------------------------------------------
echo ">>> Criando o banco '$DB_NAME' e o usuário '$DB_USER'..."
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME}
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">>> Verificando se o banco foi criado:"
mariadb -e "SHOW DATABASES;"

echo ">>> Concluído: MariaDB instalado e banco pronto."

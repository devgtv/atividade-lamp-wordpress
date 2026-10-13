#!/usr/bin/env bash
# =============================================================================
# dependencias.sh
# -----------------------------------------------------------------------------
# Instala TODAS as dependências do projeto via apt em um único comando:
# utilitários, servidor web (Apache), banco (MariaDB) e PHP com os módulos
# exigidos pelo WordPress.
#
# Útil para preparar a VM do zero. Depois dele, basta rodar o script 05
# (WordPress) e o 06 (VirtualHost), ou o setup-completo.sh.
#
# Uso:
#   sudo bash scripts/dependencias.sh              # instala tudo
#   sudo bash scripts/dependencias.sh --so-baixar  # apenas baixa (não instala)
#   sudo bash scripts/dependencias.sh --help
#
# Referência de pacotes:
#   Utilitários        : curl wget ca-certificates gnupg lsb-release unzip python3 openssl
#   Servidor web       : apache2 libapache2-mod-php
#   Banco de dados     : mariadb-server mariadb-client
#   PHP (WordPress)    : php php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl
#   Firewall           : ufw
# =============================================================================

set -e

# ----------------------------- Flags -----------------------------------------
SO_BAIXAR=0
for arg in "$@"; do
  case "$arg" in
    --so-baixar) SO_BAIXAR=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0 ;;
    *)
      echo "Opção desconhecida: $arg (use --help)"
      exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

# Lista única de todas as dependências (fácil de manter/editar).
PACOTES=(
  # --- Utilitários básicos ---
  curl wget ca-certificates gnupg lsb-release unzip python3 openssl
  # --- Servidor web (A) ---
  apache2 libapache2-mod-php
  # --- Banco de dados (M) ---
  mariadb-server mariadb-client
  # --- Linguagem PHP + módulos exigidos pelo WordPress (P) ---
  php php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl
  # --- Firewall ---
  ufw
)

echo ">>> Atualizando a lista de pacotes..."
apt update

# "apt-get --download-only" só baixa para /var/cache/apt/archives.
# Sem a flag, instalamos de fato com -y (responde "sim" automaticamente).
if [ "$SO_BAIXAR" -eq 1 ]; then
  echo ">>> Baixando (sem instalar) ${#PACOTES[@]} pacotes..."
  apt-get install -y --download-only "${PACOTES[@]}"
  echo ">>> Download concluído. Para instalar depois: sudo bash $0"
else
  echo ">>> Instalando ${#PACOTES[@]} pacotes (pode demorar)..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACOTES[@]}"
fi

# Descomenta a linha abaixo se a VM não tiver os repositórios 'universe'.
# (Ubuntu Server normalmente já vem habilitado.)
# add-apt-repository -y universe && apt update

echo
echo ">>> Versões instaladas:"
command -v apache2   >/dev/null && apache2 -v        | head -1 || true
command -v mariadb   >/dev/null && mariadb --version | head -1 || true
command -v php       >/dev/null && php -v            | head -1 || true
command -v python3   >/dev/null && python3 --version         || true

echo
echo ">>> Concluído: todas as dependências foram processadas via apt."
echo "    Próximo passo: sudo bash scripts/05-wordpress.sh && sudo bash scripts/06-virtualhost.sh"
echo "    (ou simplesmente: sudo bash scripts/setup-completo.sh)"

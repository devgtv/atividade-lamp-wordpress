#!/usr/bin/env bash
# =============================================================================
# setup-completo.sh
# -----------------------------------------------------------------------------
# Executa TODAS as etapas na ordem correta (01 a 06).
# Use na apresentação para mostrar o processo completo, ou em uma VM nova.
#
# Uso:  sudo bash setup-completo.sh
#
# Observação: o wp-config.php é gerado automaticamente, mas a conclusão da
# instalação (título do site, usuário admin, senha) é feita PELO NAVEGADOR
# na Parte 7 do roteiro.
# =============================================================================

set -e

# Garante execução como root
if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash $0"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "###################################################################"
echo "# 0) Variáveis comuns"
echo "###################################################################"
source "${BASE_DIR}/00-variaveis.sh"
echo "  Grupo    : ${GRUPO}"
echo "  Domínio  : ${DOMINIO}"
echo "  IP       : ${IP_SERVIDOR}"
echo "  Banco    : ${DB_NAME} / usuário ${DB_USER}"

for script in \
  01-atualizacao-firewall.sh \
  02-apache.sh \
  03-mariadb.sh \
  04-php.sh \
  05-wordpress.sh \
  06-virtualhost.sh
do
  echo
  echo "###################################################################"
  echo "# Executando ${script}"
  echo "###################################################################"
  bash "${BASE_DIR}/${script}"
done

echo
echo "###################################################################"
echo "# FINALIZADO!"
echo "###################################################################"
echo "Agora acesse no navegador da hospedeira: http://${IP_SERVIDOR}/"
echo "e conclua a instalação do WordPress (Parte 7 do roteiro)."
echo
echo "Opcional (desafio extra HTTPS): sudo bash ${BASE_DIR}/07-https-opcional.sh"

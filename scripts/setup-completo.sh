#!/usr/bin/env bash
# =============================================================================
# setup-completo.sh
# -----------------------------------------------------------------------------
# Executa TODAS as etapas na ordem correta (01 a 06, 09 e verificação final).
# Use na apresentação para mostrar o processo completo, ou em uma VM nova.
#
# Uso:
#   sudo bash setup-completo.sh [opções]
#
# Opções (flags):
#   --com-dependencias  Instala TODAS as dependências via apt antes (script dependencias).
#   --https             Ao final, também habilita HTTPS autoassinado (script 07).
#   --sem-finalizar     NÃO conclui a instalação via PHP (script 09),
#                       deixando a Parte 7 para ser feita pelo navegador.
#   --sem-verificar     Não roda a verificação final (testar-conexao.sh).
#   -h, --help          Mostra esta ajuda.
#
# Sem flags, o comportamento é:
#   - instala a pilha LAMP (01 a 06);
#   - conclui o WordPress automaticamente (09): cria admin, a página dos
#     integrantes e a define como página inicial;
#   - verifica a conexão WordPress <-> MariaDB (testar-conexao.sh).
#
# Observação: para concluir pelo navegador em vez do PHP, use --sem-finalizar
# e acesse http://<IP>/wp-admin/install.php.
# =============================================================================

set -e

# --------------------------- Ajuda / flags -----------------------------------
FAZ_DEPENDENCIAS=0
FAZ_HTTPS=0
FAZ_FINALIZAR=1
FAZ_VERIFICAR=1

uso() {
  sed -n '2,27p' "$0"
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --com-dependencias) FAZ_DEPENDENCIAS=1 ;;
    --https)            FAZ_HTTPS=1 ;;
    --sem-finalizar)    FAZ_FINALIZAR=0 ;;
    --sem-verificar)    FAZ_VERIFICAR=0 ;;
    -h|--help)          uso ;;
    *)
      echo "Opção desconhecida: $arg"
      echo "Use --help para ver as opções."
      exit 1
      ;;
  esac
done

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
echo "  Grupo      : ${GRUPO}"
echo "  Domínio    : ${DOMINIO}"
echo "  IP         : ${IP_SERVIDOR}"
echo "  Banco      : ${DB_NAME} / usuário ${DB_USER}"
echo "  Dependências: $([ "$FAZ_DEPENDENCIAS" -eq 1 ] && echo sim || echo nao)"
echo "  HTTPS      : $([ "$FAZ_HTTPS" -eq 1 ] && echo sim || echo nao)"
echo "  Finalizar  : $([ "$FAZ_FINALIZAR" -eq 1 ] && echo 'sim (PHP)' || echo 'nao (navegador)')"
echo "  Verificar  : $([ "$FAZ_VERIFICAR" -eq 1 ] && echo sim || echo nao)"

# --------------------- 0.5) Dependências (opcional) --------------------------
if [ "$FAZ_DEPENDENCIAS" -eq 1 ]; then
  echo
  echo "###################################################################"
  echo "# Executando dependencias.sh (todos os pacotes via apt)"
  echo "###################################################################"
  bash "${BASE_DIR}/dependencias.sh"
fi

# --------------------------- Etapas base (01 a 06) ---------------------------
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

# --------- Garantia das chaves SALT (rede de segurança, idempotente) ---------
# O 05 já aplica as chaves (com fallback offline), mas reexecutamos para o caso
# de o wp-config.php ter ficado com "put your unique phrase here".
echo
echo "###################################################################"
echo "# Garantindo as chaves de segurança (chaves-seguranca.sh)"
echo "###################################################################"
bash "${BASE_DIR}/chaves-seguranca.sh" || echo "AVISO: revise as chaves de segurança."

# --------------------------- Parte 7 (09) ------------------------------------
if [ "$FAZ_FINALIZAR" -eq 1 ]; then
  echo
  echo "###################################################################"
  echo "# Executando 09-finalizar-wordpress.sh (Parte 7 via PHP)"
  echo "###################################################################"
  bash "${BASE_DIR}/09-finalizar-wordpress.sh"
fi

# --------------------------- Desafio extra (07) ------------------------------
if [ "$FAZ_HTTPS" -eq 1 ]; then
  echo
  echo "###################################################################"
  echo "# Executando 07-https-opcional.sh (desafio extra HTTPS)"
  echo "###################################################################"
  bash "${BASE_DIR}/07-https-opcional.sh"
fi

# --------------------------- Verificação final -------------------------------
if [ "$FAZ_VERIFICAR" -eq 1 ]; then
  echo
  echo "###################################################################"
  echo "# Verificando a conexão WordPress <-> MariaDB (testar-conexao.sh)"
  echo "###################################################################"
  bash "${BASE_DIR}/testar-conexao.sh" || echo "AVISO: a verificação encontrou falhas (veja acima)."
fi

echo
echo "###################################################################"
echo "# FINALIZADO!"
echo "###################################################################"
echo "Acesse no navegador da hospedeira:"
echo "  http://${IP_SERVIDOR}/"
[ "$FAZ_HTTPS" -eq 1 ] && echo "  https://${IP_SERVIDOR}/   (certificado autoassinado)"
if [ "$FAZ_FINALIZAR" -eq 0 ]; then
  echo "Conclua a instalação pelo navegador (Parte 7): http://${IP_SERVIDOR}/wp-admin/install.php"
else
  echo "Login do painel: ${ADMIN_USER} / ${ADMIN_PASS}"
fi
echo
echo "Se o site não abrir/travar, rode: bash ${BASE_DIR}/diagnostico.sh"

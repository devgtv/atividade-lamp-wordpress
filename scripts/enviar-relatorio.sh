#!/usr/bin/env bash
# =============================================================================
# enviar-relatorio.sh
# -----------------------------------------------------------------------------
# Gera o relatório de diagnóstico e ENVIA para um serviço de paste, imprimindo
# o LINK no final. Assim você não precisa copiar/colar nada: só me manda o link.
#
# Uso (na VM):
#   sudo bash scripts/enviar-relatorio.sh
#
# Se preferir só gerar o arquivo local:  sudo bash scripts/coletar-diagnostico.sh
# =============================================================================

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# 1) Gera o relatório (que também salva em /tmp/relatorio-lamp.txt)
echo ">>> Gerando o relatório..."
$SUDO bash "${DIR}/coletar-diagnostico.sh" >/dev/null 2>&1 || true

REL="/tmp/relatorio-lamp.txt"
if [ ! -s "${REL}" ]; then
  echo "!! Não consegui gerar ${REL}. Rodando o coletor mostrando os erros:"
  $SUDO bash "${DIR}/coletar-diagnostico.sh" || true
  [ -s "${REL}" ] || { echo "!! Falhou mesmo. Me avise a mensagem acima."; exit 1; }
fi

$SUDO chmod 644 "${REL}" 2>/dev/null || true
echo ">>> Relatório local: ${REL} ($(wc -l < "${REL}") linhas)"

# 2) Tenta enviar para 0x0.st; se falhar, tenta paste.rs
echo ">>> Enviando..."
URL="$($SUDO curl -s --max-time 60 -F "file=@${REL}" https://0x0.st 2>/dev/null || true)"
if ! echo "${URL}" | grep -q '^https\?://'; then
  URL="$(cat "${REL}" | $SUDO curl -s --max-time 60 --data-binary @- https://paste.rs 2>/dev/null || true)"
fi

echo
echo "==================================================================="
if echo "${URL}" | grep -q '^https\?://'; then
  echo " LINK DO RELATORIO:  ${URL}"
  echo "==================================================================="
  echo " Copie este link e me envie no chat."
else
  echo " Não consegui enviar (sem internet na VM?)."
  echo " O arquivo está em: ${REL}"
  echo " Tente: sudo curl -F \"file=@${REL}\" https://0x0.st"
  echo "==================================================================="
fi

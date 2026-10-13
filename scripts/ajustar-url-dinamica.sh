#!/usr/bin/env bash
# =============================================================================
# ajustar-url-dinamica.sh
# -----------------------------------------------------------------------------
# Faz o WordPress adotar COMO ENDEREÇO o mesmo host que o navegador usou.
#
# Por que isso existe:
#   O problema clássico é gravar um endereço fixo (ex.: http://192.168.56.10)
#   nas opções "home"/"siteurl" do banco. Aí, se a VM for usada em OUTRO PC,
#   com outro IP/porta, o WordPress passa a redirecionar para o endereço antigo
#   e o site "some" (erro de redirecionamento / "Unable to connect").
#
# A solução: definir as constantes WP_HOME e WP_SITEURL a partir de
# $_SERVER['HTTP_HOST']. Assim o MESMO site responde corretamente por:
#   - http://192.168.56.10/
#   - http://www.grupo1.redes2.internal/
#   - http://localhost:8080/            (NAT com redirecionamento de portas)
#   sem precisar editar nada ao trocar de máquina.
#
# O script edita APENAS o wp-config.php e é IDEMPOTENTE (pode rodar quantas
# vezes quiser; se já estiver aplicado, não duplica).
#
# Uso:
#   sudo bash scripts/ajustar-url-dinamica.sh
# =============================================================================

set -e

source "$(dirname "$0")/00-variaveis.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use: sudo $0)"
  exit 1
fi

CONFIG="${WP_DIR}/wp-config.php"
if [ ! -f "${CONFIG}" ]; then
  echo "ERRO: ${CONFIG} não encontrado. Rode o script 05 (WordPress) antes."
  exit 1
fi

# Backup (só uma vez; não sobrescreve backups anteriores).
if [ ! -f "${CONFIG}.bak.url" ]; then
  cp "${CONFIG}" "${CONFIG}.bak.url"
fi

echo ">>> Aplicando a URL dinâmica em ${CONFIG}..."

sudo -u www-data python3 - "${CONFIG}" <<'PY'
import sys

path = sys.argv[1]

bloco = """/* LAMP_URL_DINAMICA - inicio (gerado por scripts/ajustar-url-dinamica.sh) */
/*
 * O WordPress usa o mesmo host pelo qual o navegador acessou (IP ou domínio).
 * Isso torna o site portátil: funciona em qualquer PC sem trocar o endereço.
 */
if ( ! empty( $_SERVER['HTTP_HOST'] ) ) {
    $lamp_esquema = ( ! empty( $_SERVER['HTTPS'] ) && 'off' !== $_SERVER['HTTPS'] ) ? 'https' : 'http';
    define( 'WP_HOME',    $lamp_esquema . '://' . $_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', $lamp_esquema . '://' . $_SERVER['HTTP_HOST'] );
}
/* LAMP_URL_DINAMICA - fim */
"""

with open(path, encoding='utf-8') as f:
    txt = f.read()

if 'LAMP_URL_DINAMICA' in txt:
    print('    (já estava aplicada; nada a fazer)')
    sys.exit(0)

# Ponto de inserção: antes do bloco final padrão do wp-config.php.
marcadores = [
    "/* That's all, stop editing!",
    "/** Absolute path to the WordPress directory. */",
    "require_once ABSPATH",
]
idx = -1
for m in marcadores:
    idx = txt.find(m)
    if idx != -1:
        break

if idx == -1:
    # Último recurso: logo após a abertura do <?php
    fim_php = txt.find("<?php")
    idx = (fim_php + len("<?php")) if fim_php != -1 else 0

txt = txt[:idx] + bloco + "\n" + txt[idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(txt)

print('    URL dinâmica aplicada com sucesso.')
PY

echo
echo ">>> Pronto! O site agora responde por qualquer endereço de acesso:"
echo "      http://${IP_SERVIDOR}/"
echo "      http://${DOMINIO}/   (precisa da entrada no /etc/hosts ou no hosts do PC)"

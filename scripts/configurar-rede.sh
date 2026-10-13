#!/usr/bin/env bash
# =============================================================================
# configurar-rede.sh
# -----------------------------------------------------------------------------
# Configura o IP FIXO na interface de rede da VM (host-only) para o servidor
# ficar acessível pela máquina hospedeira, e garante que o Apache/UFW permitam
# o acesso. Detecta automaticamente Debian (/etc/network/interfaces) e
# Ubuntu (netplan).
#
# Uso:
#   sudo bash scripts/configurar-rede.sh
#   sudo bash scripts/configurar-rede.sh --iface enp0s8 --ip 192.168.56.10/24
#   sudo bash scripts/configurar-rede.sh --dry-run     # só mostra o que faria
#
# IMPORTANTE: não altera a interface que tem a rota default (a do NAT/internet).
# Configuramos APENAS o adaptador host-only, mantendo a internet da VM.
# =============================================================================

source "$(dirname "$0")/00-variaveis.sh"

# ----------------------------- Argumentos ------------------------------------
IFACE=""
CIDR=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --iface)   IFACE="$2"; shift 2 ;;
    --ip)      CIDR="$2";  shift 2 ;;
    --dry-run) DRY_RUN=1;  shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done
[ -z "$CIDR" ] && CIDR="${IP_SERVIDOR}/24"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash $0"
  exit 1
fi

echo "==================================================================="
echo " Configuração de rede da VM"
echo "==================================================================="

# ----------------------------- Detecta interfaces ----------------------------
DEF_IFACE="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
mapfile -t UP_IFACES < <(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' \
                          | grep -vE '^(lo|docker|veth|br-|tun|tap|virbr)')

echo ">>> Interfaces ativas : ${UP_IFACES[*]:-<nenhuma>}"
echo ">>> Interface default : ${DEF_IFACE:-<nenhuma>} (NAT/internet - NÃO mexer)"

# Escolhe a interface host-only: (1) a que já tem IP na faixa; (2) a que não é a default.
if [ -z "$IFACE" ]; then
  REDE="${IP_SERVIDOR%.*}"
  for i in "${UP_IFACES[@]}"; do
    if ip -o -4 addr show "$i" 2>/dev/null | grep -q " ${REDE}\."; then IFACE="$i"; break; fi
  done
  if [ -z "$IFACE" ]; then
    for i in "${UP_IFACES[@]}"; do
      [ "$i" != "$DEF_IFACE" ] && { IFACE="$i"; break; }
    done
  fi
fi

# Se não há interface host-only, orienta o usuário e sai.
if [ -z "$IFACE" ]; then
  echo
  echo "!! Não encontrei um adaptador host-only (só existe a interface default)."
  echo
  echo "   Opções:"
  echo "   A) Adicione um 2º adaptador 'Rede somente host' na VM (VirtualBox) e"
  echo "      rode este script novamente."
  echo "   B) Use NAT com redirecionamento de portas (sem IP fixo): no Windows rode"
  echo "      docs/host-nat-portforward.ps1 e acesse http://localhost:8080/"
  exit 2
fi

echo ">>> Interface escolhida: ${IFACE}  =>  ${CIDR}"

# ----------------------------- Modo de configuração --------------------------
if compgen -G "/etc/netplan/*.yaml" >/dev/null 2>&1; then
  MODO="netplan"
elif [ -f /etc/network/interfaces ]; then
  MODO="debian"
else
  MODO="manual"
fi
echo ">>> Método detectado: ${MODO}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "    [dry-run] definiria ${CIDR} em ${IFACE} via ${MODO}; ajustaria Apache e UFW."
fi

case "$MODO" in
  netplan)
    ARQ="/etc/netplan/99-lamp-hostonly.yaml"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp -n /etc/netplan/*.yaml /tmp/ 2>/dev/null || true
      cat > "${ARQ}" <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses: [${CIDR}]
EOF
      echo ">>> Validando e aplicando o netplan..."
      netplan generate
      if ! netplan apply; then
        echo "!! Falha ao aplicar o netplan. Removendo ${ARQ} para não travar o boot."
        rm -f "${ARQ}"
        netplan apply || true
        exit 1
      fi
    fi
    ;;
  debian)
    ARQ="/etc/network/interfaces"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp -n "${ARQ}" "${ARQ}.bak.$(date +%s)" 2>/dev/null || true
      echo ">>> Configurando ${IFACE} static ${CIDR} em ${ARQ}..."
      python3 - "${ARQ}" "${IFACE}" "${CIDR}" <<'PY'
import ipaddress, re, sys
arq, iface, cidr = sys.argv[1], sys.argv[2], sys.argv[3]
addr, prefix = (cidr.split('/', 1) + ['24'])[:2]
mask = str(ipaddress.IPv4Network('0.0.0.0/' + prefix).netmask)
with open(arq) as f:
    txt = f.read()
# remove bloco antigo desta interface (auto/iface + linhas indentadas)
txt = re.sub(r'\nauto %s\niface %s inet (?:static|dhcp)\n(?:[ \t].*\n)*' % (re.escape(iface), re.escape(iface)),
             '\n', txt)
bloco = '\nauto %s\niface %s inet static\n    address %s\n    netmask %s\n' % (iface, iface, addr, mask)
with open(arq, 'w') as f:
    f.write(txt.rstrip() + '\n' + bloco)
print("    bloco escrito para", iface)
PY
      echo ">>> Reiniciando a rede..."
      ifdown "${IFACE}" 2>/dev/null || true
      ifup "${IFACE}" 2>/dev/null || systemctl restart networking 2>/dev/null || true
    fi
    ;;
  manual)
    echo ">>> Não identifiquei netplan nem /etc/network/interfaces."
    echo "    Configure manualmente o IP ${CIDR} na interface ${IFACE}."
    ;;
esac

# ----------------------------- Apache ouvindo em todas as interfaces ----------
if [ -f /etc/apache2/ports.conf ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! grep -qE '^[[:space:]]*Listen[[:space:]]+80[[:space:]]*$' /etc/apache2/ports.conf; then
    echo ">>> Garantindo 'Listen 80' no Apache..."
    printf 'Listen 80\n' >> /etc/apache2/ports.conf
  fi
  systemctl restart apache2 2>/dev/null || true
fi

# ----------------------------- Firewall ---------------------------------------
if command -v ufw >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
  echo ">>> Ajustando o firewall (UFW)..."
  ufw allow 22/tcp  >/dev/null 2>&1 || true
  ufw allow 80/tcp  >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  ufw reload        >/dev/null 2>&1 || true
fi

# ----------------------------- Verificação ------------------------------------
echo
echo "==================================================================="
echo " Verificação"
echo "==================================================================="
sleep 1
echo "--- ip a ---";          ip -brief addr
echo "--- rota default ---"; ip route show default
echo "--- porta 80 ---";     ss -tlnp 2>/dev/null | grep -E ':80\b' || echo "  (nada escutando na 80)"
echo "--- HTTP ---"
curl -s -o /dev/null -m 8 -w "  http://localhost/     -> HTTP %{http_code}\n" http://localhost/ || echo "  localhost: falhou"
curl -s -o /dev/null -m 8 -w "  http://${IP_SERVIDOR}/ -> HTTP %{http_code}\n" "http://${IP_SERVIDOR}/" || echo "  ${IP_SERVIDOR}: falhou"

echo
echo "Se o IP acima respondeu, abra na hospedeira: http://${IP_SERVIDOR}/"
echo "Se a VM tiver só NAT, use: docs/host-nat-portforward.ps1 (http://localhost:8080/)"
echo "Ainda com problema? rode: bash scripts/diagnostico.sh"

#!/usr/bin/env bash
# =============================================================================
# configurar-virtualbox.sh
# -----------------------------------------------------------------------------
# Versão para LINUX / WSL (hospedeira) do configurar-virtualbox.ps1.
# Deixa a rede da VM pronta para o servidor LAMP em qualquer PC, sem cliques:
#   1. garante a rede Host-only 192.168.56.1/24 (cria se não existir);
#   2. liga o 2º adaptador da VM nessa rede;
#   3. (opcional) port-forward do NAT (8080->80, 8443->443);
#   4. adiciona o domínio no /etc/hosts da hospedeira.
#
# Uso:
#   bash host/configurar-virtualbox.sh --vm lampredes
#   bash host/configurar-virtualbox.sh --vm lampredes --port-forward
#   bash host/configurar-virtualbox.sh --vm lampredes --reiniciar
#   bash host/configurar-virtualbox.sh --vm lampredes --no-hosts
#
# No WSL, o VBoxManage.exe do Windows é detectado automaticamente.
# =============================================================================

set -e

IP="192.168.56.10"; NET="192.168.56.1"; MASK="255.255.255.0"
DOMINIO="www.grupo1.redes2.internal"; DOMINIO_CURTO="grupo1.redes2.internal"
VM=""; PORT_FORWARD=0; NO_HOSTS=0; REINICIAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --vm) VM="$2"; shift 2 ;;
    --ip) IP="$2"; shift 2 ;;
    --net) NET="$2"; shift 2 ;;
    --mask) MASK="$2"; shift 2 ;;
    --dominio) DOMINIO="$2"; shift 2 ;;
    --port-forward) PORT_FORWARD=1; shift ;;
    --no-hosts) NO_HOSTS=1; shift ;;
    --reiniciar) REINICIAR=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

# --------------------------- Localiza o VBoxManage ---------------------------
VBM=""
for c in "VBoxManage" "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"; do
  if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then VBM="$c"; break; fi
done
[ -z "$VBM" ] && { echo "ERRO: VBoxManage não encontrado."; exit 1; }
echo ">>> VBoxManage: $VBM"

# --------------------------- Escolhe a VM ------------------------------------
if [ -z "$VM" ]; then
  echo ">>> VMs disponíveis:"; "$VBM" list vms
  read -rp "Nome exato da VM: " VM
fi
"$VBM" list vms | grep -q "\"${VM}\"" || { echo "ERRO: VM '${VM}' não encontrada."; exit 1; }

# --------------------------- Rede Host-only ----------------------------------
HO_NOME="$("$VBM" list hostonlyifs | awk -F': *' '/^Name:/{n=$2} /^IPAddress:/{print n"|"$2}' \
           | awk -F'|' -v ip="$NET" '$2==ip{print $1; exit}')"
if [ -n "$HO_NOME" ]; then
  echo ">>> Rede Host-only já existe: '${HO_NOME}' (${NET})"
else
  echo ">>> Criando rede Host-only em ${NET} ..."
  SAIDA="$("$VBM" hostonlyif create)"
  HO_NOME="$(printf '%s' "$SAIDA" | sed -n "s/.*Interface '\([^']*\)'.*/\1/p")"
  [ -z "$HO_NOME" ] && HO_NOME="$("$VBM" list hostonlyifs | awk -F': *' '/^Name:/{print $2; exit}')"
  "$VBM" hostonlyif ipconfig "$HO_NOME" --ip "$NET" --netmask "$MASK"
  "$VBM" dhcpserver modify --ifname "$HO_NOME" --disable >/dev/null 2>&1 || true
  echo ">>> Rede Host-only '${HO_NOME}' em ${NET}/${MASK}"
fi

# --------------------------- Estado da VM ------------------------------------
MI="$("$VBM" showvminfo "$VM" --machinereadable)"
STATE="$(printf '%s\n' "$MI" | sed -n 's/^VMState="\([^"]*\)".*/\1/p')"

tem_hostonly=0
for i in 1 2 3 4 5 6 7 8; do
  printf '%s\n' "$MI" | grep -q "^nic${i}=\"hostonly\"" && tem_hostonly=1
done

if [ "$tem_hostonly" -eq 1 ]; then
  echo ">>> A VM já possui adaptador Host-only."
else
  if [ "$STATE" != "poweroff" ]; then
    if [ "$REINICIAR" -eq 1 ]; then
      echo ">>> Desligando a VM (ACPI)..."
      "$VBM" controlvm "$VM" acpipowerbutton >/dev/null 2>&1 || true
      for _ in $(seq 1 30); do
        sleep 3
        STATE="$("$VBM" showvminfo "$VM" --machinereadable | sed -n 's/^VMState="\([^"]*\)".*/\1/p')"
        [ "$STATE" = "poweroff" ] && break
      done
    else
      echo "!! A VM está '${STATE}'. Para adicionar o adaptador é preciso desligá-la."
      echo "   Rode de novo com --reiniciar (o script reinicia sozinho)."
    fi
  fi
  if [ "$STATE" = "poweroff" ]; then
    SLOT=2
    for i in 2 3 4 5 6 7 8; do
      printf '%s\n' "$MI" | grep -q "^nic${i}=\"none\"" && { SLOT=$i; break; }
    done
    echo ">>> Ligando o adaptador ${SLOT} na rede Host-only '${HO_NOME}'..."
    "$VBM" modifyvm "$VM" "--nic${SLOT}" hostonly "--hostonlyadapter${SLOT}" "$HO_NOME"
    echo ">>> Adaptador ${SLOT} agora é Host-only."
    [ "$REINICIAR" -eq 1 ] && { echo ">>> Ligando a VM..."; "$VBM" startvm "$VM" >/dev/null; }
  fi
fi

# --------------------------- Port-forward (opcional) -------------------------
if [ "$PORT_FORWARD" -eq 1 ]; then
  if printf '%s\n' "$MI" | grep -q '^nic1="nat"'; then
    if [ "$STATE" = "running" ]; then
      echo ">>> Configurando port-forward (8080->80, 8443->443)..."
      "$VBM" controlvm "$VM" natpf1 delete "LAMP-HTTP"  >/dev/null 2>&1 || true
      "$VBM" controlvm "$VM" natpf1 delete "LAMP-HTTPS" >/dev/null 2>&1 || true
      "$VBM" controlvm "$VM" natpf1 "LAMP-HTTP,tcp,,8080,,80"
      "$VBM" controlvm "$VM" natpf1 "LAMP-HTTPS,tcp,,8443,,443"
      echo ">>> Port-forward ativo: http://localhost:8080/"
    else
      echo "!! A VM precisa estar ligada p/ o port-forward."
    fi
  else
    echo "!! O adaptador 1 não é NAT; pulando port-forward."
  fi
fi

# --------------------------- /etc/hosts da hospedeira ------------------------
if [ "$NO_HOSTS" -eq 0 ]; then
  if grep -qE "^[^#]*[[:space:]]${IP}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    echo ">>> /etc/hosts já contém ${IP}."
  else
    printf '%s\t%s\t%s\n' "${IP}" "${DOMINIO}" "${DOMINIO_CURTO}" | sudo tee -a /etc/hosts >/dev/null 2>&1 \
      && echo ">>> Adicionado ao /etc/hosts: ${IP} ${DOMINIO}" \
      || echo "!! Sem permissão p/ editar /etc/hosts (use sudo)."
  fi
fi

echo
echo ">>> Host pronto! Agora, DENTRO da VM:"
echo "      cd atividade-lamp-wordpress && git pull"
echo "      sudo bash scripts/configurar-rede.sh"
echo
echo ">>> Acesse na hospedeira:"
echo "      http://${IP}/"
echo "      http://${DOMINIO}/"
[ "$PORT_FORWARD" -eq 1 ] && echo "      http://localhost:8080/"

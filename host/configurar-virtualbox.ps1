# =============================================================================
# configurar-virtualbox.ps1
# -----------------------------------------------------------------------------
# Rode no WINDOWS (hospedeira), com o VirtualBox instalado. Ele deixa a rede da
# VM pronta para o servidor LAMP, em QUALQUER PC, sem cliques na interface:
#
#   1. garante uma rede "Host-only" no VirtualBox com IP 192.168.56.1/24
#      (cria automaticamente se não existir);
#   2. liga o 2º adaptador da VM nessa rede Host-only;
#   3. (opcional) cria o redirecionamento de portas do NAT (http://localhost:8080);
#   4. adiciona o domínio no arquivo "hosts" do Windows
#      (www.grupo1.redes2.internal -> 192.168.56.10).
#
# Uso (PowerShell):
#   .\configurar-virtualbox.ps1                       # lista as VMs e pergunta
#   .\configurar-virtualbox.ps1 -VM "lampredes"       # configura a VM
#   .\configurar-virtualbox.ps1 -VM "lampredes" -PortForward
#   .\configurar-virtualbox.ps1 -VM "lampredes" -Reiniciar   # desliga/religa sozinho
#   .\configurar-virtualbox.ps1 -VM "lampredes" -NoHosts     # não mexe no hosts
#
# Obs.: alterar adaptadores de rede exige a VM DESLIGADA. Se ela estiver ligada,
# use -Reiniciar (o script desliga de forma graciosa, ajusta e liga de novo).
# =============================================================================

param(
    [string]$VM = "",
    [string]$IP = "192.168.56.10",
    [string]$Net = "192.168.56.1",
    [string]$Mask = "255.255.255.0",
    [string]$Dominio = "www.grupo1.redes2.internal",
    [string]$DominioCurto = "grupo1.redes2.internal",
    [switch]$PortForward,
    [switch]$NoHosts,
    [switch]$Reiniciar
)

$ErrorActionPreference = "Stop"

function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Erro($m)  { Write-Host $m -ForegroundColor Red }

# --- Localiza o VBoxManage ---------------------------------------------------
$VBoxManage = @(
    "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
    "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
    "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $VBoxManage) {
    Erro "VBoxManage.exe não encontrado. Instale o VirtualBox ou ajuste o caminho."
    exit 1
}
Info "VBoxManage: $VBoxManage"

# --- Escolhe a VM ------------------------------------------------------------
if (-not $VM) {
    Info "VMs disponíveis:"
    & $VBoxManage list vms
    $VM = (Read-Host "Digite o nome exato da VM").Trim()
}
$vms = (& $VBoxManage list vms) -join "`n"
if ($vms -notmatch [regex]::Escape("`"$VM`"")) {
    Erro "A VM '$VM' não foi encontrada. Veja a lista acima."
    exit 1
}

# --- Função: lista as interfaces Host-only -----------------------------------
function Get-HostOnlyIfs {
    $objs = @(); $cur = $null
    foreach ($line in (& $VBoxManage list hostonlyifs)) {
        if ($line -match '^Name:\s+(.*)$') {
            if ($cur) { $objs += $cur }
            $cur = [pscustomobject]@{ Name = $matches[1].Trim(); IPAddress = "" }
        } elseif ($line -match '^IPAddress:\s+(.*)$' -and $cur) {
            $cur.IPAddress = $matches[1].Trim()
        }
    }
    if ($cur) { $objs += $cur }
    return $objs
}

# --- 1) Garante a rede Host-only com o IP desejado ---------------------------
$iface = Get-HostOnlyIfs | Where-Object { $_.IPAddress -eq $Net } | Select-Object -First 1
if ($iface) {
    Ok "Rede Host-only já existe: '$($iface.Name)' ($Net)"
} else {
    Info "Criando uma rede Host-only e definindo $Net ..."
    $saida = (& $VBoxManage hostonlyif create) -join "`n"
    if ($saida -match "Interface '([^']+)'") {
        $nome = $matches[1]
    } else {
        # fallback: pega a primeira interface recém-listada
        $nome = (Get-HostOnlyIfs | Select-Object -First 1).Name
    }
    & $VBoxManage hostonlyif ipconfig $nome --ip $Net --netmask $Mask
    & $VBoxManage dhcpserver modify --ifname $nome --disable 2>$null | Out-Null
    $iface = [pscustomobject]@{ Name = $nome; IPAddress = $Net }
    Ok "Rede Host-only '$nome' criada em $Net/$Mask"
}

# --- Estado atual da VM ------------------------------------------------------
$info = @{}
foreach ($l in (& $VBoxManage showvminfo $VM --machinereadable)) {
    if ($l -match '^([^=]+)="(.*)"$') { $info[$matches[1]] = $matches[2] }
}
$state = $info['VMState']

# --- 2) Garante que a VM tenha um adaptador Host-only ------------------------
$temHostOnly = $false
$slotOcupado = 0
for ($i = 1; $i -le 8; $i++) {
    if ($info["nic$i"] -eq 'hostonly') { $temHostOnly = $true }
}
if ($temHostOnly) {
    Ok "A VM já possui um adaptador Host-only."
} else {
    if ($state -ne 'poweroff') {
        if ($Reiniciar) {
            Info "Desligando a VM (ACPI) para alterar o adaptador..."
            & $VBoxManage controlvm $VM acpipowerbutton | Out-Null
            for ($t = 0; $t -lt 30; $t++) {
                Start-Sleep -Seconds 3
                $s = (& $VBoxManage showvminfo $VM --machinereadable | Select-String '^VMState="([^"]+)"')
                if ($s -match 'poweroff') { break }
            }
            $state = 'poweroff'
        } else {
            Warn "A VM está '$state'. Para adicionar o adaptador Host-only é preciso"
            Warn "desligá-la. Rode de novo com -Reiniciar (o script reinicia sozinho)."
        }
    }

    if ($state -eq 'poweroff') {
        $slot = 2
        for ($i = 2; $i -le 8; $i++) { if ($info["nic$i"] -eq 'none') { $slot = $i; break } }
        Info "Ligando o adaptador $slot na rede Host-only '$($iface.Name)'..."
        & $VBoxManage modifyvm $VM "--nic$slot" hostonly "--hostonlyadapter$slot" $iface.Name
        Ok "Adaptador $slot agora é Host-only."
        if ($Reiniciar -and $state -eq 'poweroff') {
            Info "Ligando a VM novamente..."
            & $VBoxManage startvm $VM | Out-Null
        }
    }
}

# --- 3) Redirecionamento de portas (NAT) - opcional --------------------------
if ($PortForward) {
    if ($info['nic1'] -eq 'nat') {
        if ($state -eq 'running') {
            Info "Configurando redirecionamento de portas (8080->80, 8443->443)..."
            & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTP"  2>$null | Out-Null
            & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTPS" 2>$null | Out-Null
            & $VBoxManage controlvm $VM natpf1 "LAMP-HTTP,tcp,,8080,,80"
            & $VBoxManage controlvm $VM natpf1 "LAMP-HTTPS,tcp,,8443,,443"
            Ok "Port-forward ativo: http://localhost:8080/"
        } else {
            Warn "A VM precisa estar ligada p/ o port-forward. Ligue e rode de novo."
        }
    } else {
        Warn "O adaptador 1 não é NAT; pulando port-forward."
    }
}

# --- 4) Entrada no hosts do Windows ------------------------------------------
if (-not $NoHosts) {
    $hosts = Join-Path $env:windir "System32\drivers\etc\hosts"
    $linha = "$IP`t$Dominio`t$DominioCurto"
    $jaTem = $false
    try { $jaTem = (Select-String -Path $hosts -Pattern ([regex]::Escape($IP)) -Quiet) } catch {}
    if ($jaTem) {
        Ok "O hosts do Windows já contém $IP."
    } else {
        try {
            Add-Content -Path $hosts -Value "`n$linha" -ErrorAction Stop
            Ok "Adicionado ao hosts: $linha"
        } catch {
            Warn "Sem permissão para editar o hosts. Rode o PowerShell como ADMINISTRADOR"
            Warn "ou adicione manualmente:  $linha"
        }
    }
}

# --- Próximos passos ---------------------------------------------------------
Write-Host ""
Ok "Host pronto! Agora, DENTRO da VM, rode:"
Write-Host "    cd atividade-lamp-wordpress && git pull"
Write-Host "    sudo bash scripts/configurar-rede.sh"
Write-Host ""
Info "Depois acesse na hospedeira:"
Write-Host "    http://$IP/                       (IP)"
Write-Host "    http://$Dominio/       (domínio)"
if ($PortForward) { Write-Host "    http://localhost:8080/            (NAT port-forward)" }

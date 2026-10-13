# =============================================================================
# host-nat-portforward.ps1
# -----------------------------------------------------------------------------
# Rode este script no WINDOWS (máquina hospedeira) com o VirtualBox instalado.
#
# Ele configura o redirecionamento de portas do adaptador NAT da VM, para que
# você acesse o servidor por  http://localhost:8080/  (HTTP) e
# https://localhost:8443/  (HTTPS) - sem precisar de IP fixo / rede host-only.
#
# Uso (PowerShell):
#   .\host-nat-portforward.ps1                 # lista as VMs e pede o nome
#   .\host-nat-portforward.ps1 -VM "debian"    # configura direto a VM "debian"
#   .\host-nat-portforward.ps1 -VM "debian" -Remove   # remove as regras
#
# Pré-requisito: a VM precisa ter um adaptador em modo NAT (Adaptador 1).
# =============================================================================

param(
    [string]$VM = "",
    [switch]$Remove
)

# Localiza o VBoxManage
$VBoxManage = @(
    "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
    "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
    "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $VBoxManage) {
    Write-Error "VBoxManage.exe não encontrado. Instale o VirtualBox ou ajuste o caminho."
    exit 1
}

if (-not $VM) {
    Write-Host "VMs disponíveis:" -ForegroundColor Cyan
    & $VBoxManage list vms
    $VM = Read-Host "Digite o nome exato da VM (entre aspas, como aparece acima)"
}

if ($Remove) {
    Write-Host "Removendo regras de redirecionamento da VM '$VM'..." -ForegroundColor Yellow
    & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTP" 2>$null
    & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTPS" 2>$null
} else {
    Write-Host "Configurando redirecionamento de portas na VM '$VM'..." -ForegroundColor Green
    # (remove antes para não dar erro de regra duplicada)
    & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTP"  2>$null | Out-Null
    & $VBoxManage controlvm $VM natpf1 delete "LAMP-HTTPS" 2>$null | Out-Null
    # regra,proto,ipHospedeiro,portaHospedeira,ipConvidado,portaConvidada
    & $VBoxManage controlvm $VM natpf1 "LAMP-HTTP,tcp,,8080,,80"
    & $VBoxManage controlvm $VM natpf1 "LAMP-HTTPS,tcp,,8443,,443"
}

Write-Host ""
Write-Host "Regras atuais do adaptador NAT:" -ForegroundColor Cyan
& $VBoxManage showvminfo $VM --machinereadable | Select-String "Forwarding"

Write-Host ""
Write-Host "Acesse no navegador:" -ForegroundColor Green
Write-Host "  http://localhost:8080/          (site)"
Write-Host "  http://localhost:8080/wp-admin/ (painel)"
Write-Host "  https://localhost:8443/         (HTTPS, se habilitado)"
Write-Host ""
Write-Host "Obs.: a VM precisa estar LIGADA para o controlvm funcionar."

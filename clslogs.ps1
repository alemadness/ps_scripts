# ==========================================
# Script de limpeza Windows Server
# ==========================================

Write-Host "Iniciando limpeza..." -ForegroundColor Cyan

# ------------------------------------------
# Limpar logs de eventos do Windows
# ------------------------------------------

$eventLogs = @(
    "System",
    "Setup",
    "Application",
    "Security"
)

foreach ($log in $eventLogs) {
    try {
        Write-Host "Limpando log: $log"
        wevtutil cl $log
    }
    catch {
        Write-Host "Erro ao limpar log $log : $_" -ForegroundColor Red
    }
}

# ------------------------------------------
# Remover chave de registro Cloudbase-Init
# ------------------------------------------

$regPath = "HKLM:\SOFTWARE\Cloudbase Solutions\Cloudbase-Init"

if (Test-Path $regPath) {
    try {
        Remove-Item -Path $regPath -Recurse -Force
        Write-Host "Chave de registro removida."
    }
    catch {
        Write-Host "Erro ao remover chave de registro: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "Chave de registro não encontrada."
}

# ------------------------------------------
# Remover arquivo de log Cloudbase-Init
# ------------------------------------------

$logFile = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log"

if (Test-Path $logFile) {
    try {
        Remove-Item $logFile -Force
        Write-Host "Arquivo de log removido."
    }
    catch {
        Write-Host "Erro ao remover arquivo de log: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "Arquivo de log não encontrado."
}

# ------------------------------------------
# Limpar cache do Microsoft Edge
# ------------------------------------------

Write-Host "Fechando Microsoft Edge..."

Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force

$edgePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Network"
)

foreach ($path in $edgePaths) {
    if (Test-Path $path) {
        try {
            Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cache removido: $path"
        }
        catch {
            Write-Host "Erro ao limpar cache em $path : $_" -ForegroundColor Red
        }
    }
}

Write-Host "Limpeza concluída." -ForegroundColor Green

# Limpa arquivos recentes do usuario

Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue

# Limpa Jump Lists recentes

Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -ErrorAction SilentlyContinue

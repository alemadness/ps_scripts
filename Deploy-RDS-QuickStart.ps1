#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SINOPSE
    Implanta uma infraestrutura RDS (Remote Desktop Services) baseada em sessao,
    totalmente em um unico servidor Windows Server 2025 (cenario "tudo em um").

.DESCRICAO
    Este script automatiza de ponta a ponta:
      1. Validacao de pre-requisitos (SO, ingresso no dominio, execucao como Administrador)
      2. Instalacao das roles RDS (Connection Broker, Web Access, Session Host) no servidor local
      3. Criacao da colecao de sessoes (Session Collection)
      4. Configuracao do modo de licenciamento (opcional)
      5. Geracao de log de execucao em C:\Logs

    Indicado para labs, POCs, ambientes pequenos ou quando todas as roles ficarao
    no mesmo servidor. Para ambientes distribuidos, use Deploy-RDS-Distributed.ps1.

.PARAMETRO CollectionName
    Nome da colecao de sessoes a ser criada. Padrao: "Area de Trabalho"

.PARAMETRO LicenseServer
    (Opcional) FQDN do servidor de licenciamento RDS. Se omitido, o servidor entra
    no periodo de carencia de 120 dias e a licenca deve ser configurada depois.

.PARAMETRO LicenseMode
    (Opcional) PerUser ou PerDevice. Obrigatorio se -LicenseServer for informado.

.EXEMPLO
    .\Deploy-RDS-QuickStart.ps1 -CollectionName "Colecao-RDS" -LicenseServer rds-lic01.contoso.local -LicenseMode PerUser

.EXEMPLO
    .\Deploy-RDS-QuickStart.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CollectionName = "Area de Trabalho",
    [string]$CollectionDescription = "Colecao de sessoes RDS criada automaticamente",
    [string]$LicenseServer,
    [ValidateSet("PerUser", "PerDevice")]
    [string]$LicenseMode,
    [string]$LogPath = "C:\Logs\Deploy-RDS-QuickStart.log"
)

$ErrorActionPreference = "Stop"

# Permite rodar o script sem exigir assinatura digital, apenas nesta sessao/processo
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$server = $env:COMPUTERNAME

# ------------------------------------------------------------------
# Funcoes auxiliares
# ------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}

function Test-Prerequisitos {
    Write-Log "Validando pre-requisitos..."

    # Versao do SO (Windows Server 2025 = build 26100+)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Log "Sistema operacional detectado: $($os.Caption) (Build $($os.BuildNumber))"
    if ($os.ProductType -eq 1) {
        throw "Este script deve ser executado em um Windows Server, nao em uma workstation."
    }

    # Ingresso no dominio (necessario para RDS em producao)
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $cs.PartOfDomain) {
        Write-Log "AVISO: o servidor '$server' nao esta ingressado em um dominio Active Directory. Prosseguindo mesmo assim (cenario de lab)." "WARN"
    }
    else {
        Write-Log "Dominio detectado: $($cs.Domain)"
    }

    # WinRM precisa estar ativo (usado internamente pelos cmdlets de RDS)
    if ((Get-Service WinRM).Status -ne "Running") {
        Write-Log "Iniciando o servico WinRM..."
        Start-Service WinRM
    }
}

function Install-RDSModuleTools {
    Write-Log "Garantindo que as ferramentas de gerenciamento RDS (RSAT) estejam instaladas..."
    $feature = Get-WindowsFeature -Name RSAT-RDS-Tools
    if ($feature.InstallState -ne "Installed") {
        Install-WindowsFeature -Name RSAT-RDS-Tools -IncludeAllSubFeature | Out-Null
    }
    Import-Module RemoteDesktop -ErrorAction Stop
}

function New-Deployment {
    Write-Log "Verificando se ja existe uma implantacao RDS..."
    $existing = $null
    try { $existing = Get-RDServer -ErrorAction Stop } catch { }

    if ($existing) {
        Write-Log "Ja existe uma implantacao RDS neste ambiente. Etapa de criacao ignorada."
        return
    }

    if ($PSCmdlet.ShouldProcess($server, "Criar implantacao RDS (Connection Broker + Web Access + Session Host)")) {
        Write-Log "Criando a implantacao RDS 'tudo em um' no servidor '$server'..."
        New-RDSessionDeployment -ConnectionBroker $server -WebAccessServer $server -SessionHost $server
        Write-Log "Implantacao RDS criada com sucesso."
    }
}

function New-Collection {
    Write-Log "Verificando se a colecao '$CollectionName' ja existe..."
    $col = Get-RDSessionCollection -CollectionName $CollectionName -ConnectionBroker $server -ErrorAction SilentlyContinue

    if ($col) {
        Write-Log "A colecao '$CollectionName' ja existe. Etapa ignorada."
        return
    }

    if ($PSCmdlet.ShouldProcess($CollectionName, "Criar colecao de sessoes")) {
        Write-Log "Criando a colecao de sessoes '$CollectionName'..."
        New-RDSessionCollection -CollectionName $CollectionName `
            -SessionHost $server `
            -ConnectionBroker $server `
            -CollectionDescription $CollectionDescription
        Write-Log "Colecao '$CollectionName' criada com sucesso."
    }
}

function Set-Licenciamento {
    if (-not $LicenseServer) {
        Write-Log "Nenhum servidor de licenciamento informado. O servidor operara no periodo de carencia de 120 dias." "WARN"
        return
    }
    if (-not $LicenseMode) {
        throw "O parametro -LicenseMode (PerUser ou PerDevice) e obrigatorio quando -LicenseServer e informado."
    }

    if ($PSCmdlet.ShouldProcess($LicenseServer, "Configurar servidor de licenciamento RDS ($LicenseMode)")) {
        Write-Log "Adicionando role de licenciamento no servidor '$LicenseServer' (se necessario)..."
        $rdServers = Get-RDServer -ConnectionBroker $server
        if (-not ($rdServers | Where-Object { $_.Server -eq $LicenseServer -and $_.Roles -contains "RDS-LICENSING" })) {
            Add-RDServer -Server $LicenseServer -Role RDS-LICENSING -ConnectionBroker $server
        }

        Write-Log "Configurando modo de licenciamento '$LicenseMode' apontando para '$LicenseServer'..."
        Set-RDLicenseConfiguration -LicenseServer $LicenseServer -Mode $LicenseMode -ConnectionBroker $server -Force
        Write-Log "Licenciamento configurado. Lembre-se de ATIVAR o servidor de licenciamento no console 'Servicos de Area de Trabalho Remota' ou via Set-RDLicensing.ps1."
    }
}

# ------------------------------------------------------------------
# Execucao principal
# ------------------------------------------------------------------
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
Start-Transcript -Path ($LogPath -replace '\.log$', '-transcript.log') -Append | Out-Null

try {
    Write-Log "===== INICIO DO DEPLOY RDS QUICK START (servidor: $server) ====="
    Test-Prerequisitos
    Install-RDSModuleTools
    New-Deployment
    New-Collection
    Set-Licenciamento
    Write-Log "===== DEPLOY CONCLUIDO COM SUCESSO ====="
    Write-Log "Acesse via RD Web Access em: https://$server/RDWeb"
}
catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    throw
}
finally {
    Stop-Transcript | Out-Null
}

#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SINOPSE
    Descobre automaticamente o dominio Active Directory disponivel na rede
    (com base no servidor DNS ja configurado no adaptador de rede) e ingressa
    o servidor local nesse dominio.

.DESCRICAO
    Estrategia de descoberta (nessa ordem):
      1. Le o(s) servidor(es) DNS configurado(s) no adaptador de rede.
      2. Faz um PTR reverso (Resolve-DnsName -Type PTR) do IP do DNS para obter
         o FQDN do servidor DNS (ex.: dc01.contoso.local) e extrai o sufixo
         (contoso.local) como candidato a nome de dominio.
      3. Confirma o candidato consultando o registro SRV
         _ldap._tcp.dc._msdcs.<dominio>, que so existe se houver um
         Domain Controller respondendo para aquele dominio.
      4. Se confirmado, solicita as credenciais de ingresso e executa
         Add-Computer, com reinicializacao automatica opcional.

.PARAMETRO Restart
    Reinicia o servidor automaticamente apos o ingresso no dominio.

.PARAMETRO NewComputerName
    (Opcional) Renomeia o servidor durante o ingresso no dominio.

.EXEMPLO
    .\Discover-And-Join-Domain.ps1 -Restart

.EXEMPLO
    .\Discover-And-Join-Domain.ps1 -NewComputerName "WS2025RDS-3" -Restart
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Restart,
    [string]$NewComputerName,
    [string]$LogPath = "C:\Logs\Discover-And-Join-Domain.log"
)

$ErrorActionPreference = "Stop"

# Permite rodar o script sem exigir assinatura digital, apenas nesta sessao/processo
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Garante que a pasta de logs exista antes de qualquer escrita
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}

function Get-DominiosCandidatos {
    Write-Log "Lendo servidores DNS configurados nos adaptadores de rede..."
    $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses.Count -gt 0 } |
        Select-Object -ExpandProperty ServerAddresses -Unique

    if (-not $dnsServers) {
        throw "Nenhum servidor DNS configurado foi encontrado nos adaptadores de rede."
    }
    Write-Log "Servidores DNS encontrados: $($dnsServers -join ', ')"

    $candidatos = @()

    # Estrategia 1: consulta LDAP RootDSE diretamente no IP do DNS/DC.
    # Funciona mesmo sem zona de resolucao reversa configurada.
    foreach ($ip in $dnsServers) {
        try {
            $rootDse = [ADSI]"LDAP://$ip/RootDSE"
            $namingContext = $rootDse.defaultNamingContext
            if ($namingContext) {
                $dominio = ($namingContext -replace 'DC=', '') -replace ',', '.'
                Write-Log "RootDSE de $ip -> $namingContext (dominio candidato: $dominio)"
                $candidatos += $dominio
            }
        }
        catch {
            Write-Log "Nao foi possivel consultar RootDSE em $ip. $($_.Exception.Message)" "WARN"
        }
    }

    # Estrategia 2 (fallback): PTR reverso do IP do DNS -> extrai o sufixo do FQDN
    foreach ($ip in $dnsServers) {
        try {
            $ptr = Resolve-DnsName -Name $ip -Type PTR -ErrorAction Stop
            $fqdn = $ptr.NameHost
            if ($fqdn -and $fqdn.Contains(".")) {
                $dominio = $fqdn.Substring($fqdn.IndexOf(".") + 1).TrimEnd(".")
                Write-Log "PTR de $ip -> $fqdn (dominio candidato: $dominio)"
                $candidatos += $dominio
            }
        }
        catch {
            Write-Log "Nao foi possivel resolver PTR para $ip. $($_.Exception.Message)" "WARN"
        }
    }

    # Estrategia 3 (fallback): sufixo DNS primario/da conexao ja atribuido via DHCP
    $sufixos = (Get-DnsClient | Select-Object -ExpandProperty ConnectionSpecificSuffix) +
               (Get-DnsClientGlobalSetting | Select-Object -ExpandProperty SuffixSearchList)
    foreach ($s in $sufixos) {
        if ($s -and $s -ne "") {
            Write-Log "Sufixo DNS candidato encontrado via configuracao local: $s"
            $candidatos += $s
        }
    }

    return ($candidatos | Where-Object { $_ } | Select-Object -Unique)
}

function Confirm-Dominio {
    param([string]$Dominio)

    Write-Log "Validando '$Dominio' como dominio AD (procurando DC via SRV)..."
    try {
        $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$Dominio" -Type SRV -ErrorAction Stop
        if ($srv) {
            $dc = ($srv | Select-Object -First 1).NameTarget
            Write-Log "Dominio '$Dominio' CONFIRMADO. Domain Controller localizado: $dc"
            return $true
        }
    }
    catch {
        Write-Log "'$Dominio' nao respondeu como dominio AD valido." "WARN"
    }
    return $false
}

try {
    Write-Log "===== INICIO DA DESCOBERTA DE DOMINIO ====="

    $candidatos = Get-DominiosCandidatos
    if (-not $candidatos) {
        throw "Nenhum dominio candidato foi encontrado a partir da configuracao de DNS atual."
    }

    $dominioValido = $null
    foreach ($c in $candidatos) {
        if (Confirm-Dominio -Dominio $c) {
            $dominioValido = $c
            break
        }
    }

    if (-not $dominioValido) {
        throw "Nenhum dos dominios candidatos ($($candidatos -join ', ')) pode ser confirmado como Active Directory valido."
    }

    Write-Log "Dominio a ser utilizado para ingresso: $dominioValido"

    $cred = Get-Credential -Message "Informe uma conta com permissao para ingressar o servidor no dominio '$dominioValido' (ex.: $dominioValido\usuario)"

    $paramsIngresso = @{
        DomainName = $dominioValido
        Credential = $cred
        Force      = $true
    }
    if ($NewComputerName) { $paramsIngresso["NewName"] = $NewComputerName }
    if ($Restart)         { $paramsIngresso["Restart"] = $true }

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Ingressar no dominio '$dominioValido'")) {
        Write-Log "Executando Add-Computer para ingressar no dominio '$dominioValido'..."
        Add-Computer @paramsIngresso
        Write-Log "Ingresso no dominio solicitado com sucesso."
        if ($Restart) {
            Write-Log "O servidor sera reiniciado agora para concluir o ingresso."
        }
        else {
            Write-Log "Reinicie o servidor manualmente para concluir o ingresso no dominio." "WARN"
        }
    }

    Write-Log "===== FIM DA DESCOBERTA DE DOMINIO ====="
}
catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"
    throw
}

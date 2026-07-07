# Configure-RDS.ps1
# Windows Server 2025 - RDS Deploy (Parte 2)

$Root="C:\RDSDeploy"
$Log="$Root\Install.log"
$Cfg="$Root\Config.xml"

function Log($m){
    ("{0} - {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$m) | Out-File $Log -Append -Encoding utf8
}

Start-Sleep 60

[xml]$cfg=Get-Content $Cfg
$fqdn=$cfg.Config.FQDN

Import-Module RemoteDesktop

try{
    Log "Criando deployment."

    if(-not(Get-RDServer -ConnectionBroker $fqdn -ErrorAction SilentlyContinue)){
        New-RDSessionDeployment `
            -ConnectionBroker $fqdn `
            -WebAccessServer $fqdn `
            -SessionHost $fqdn
    }

    if(-not(Get-RDSessionCollection -ConnectionBroker $fqdn -ErrorAction SilentlyContinue)){
        New-RDSessionCollection `
            -CollectionName "RDS" `
            -SessionHost $fqdn `
            -ConnectionBroker $fqdn
    }

    Unregister-ScheduledTask -TaskName "Configure-RDS" -Confirm:$false -ErrorAction SilentlyContinue

    Log "Deployment concluído."
}
catch{
    Log $_.Exception.Message
    throw
}

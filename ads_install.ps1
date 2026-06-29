Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment
$SafeModePwd = ConvertTo-SecureString "Ativy@2024" -AsPlainText -Force

Install-ADDSForest `
    -DomainName "wevy.local" `
    -DomainNetbiosName "WEVY" `
    -SafeModeAdministratorPassword $SafeModePwd `
    -InstallDNS `
    -Force
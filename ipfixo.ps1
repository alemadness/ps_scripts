# Obtém o primeiro adaptador de rede ativo
$Adapter = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1

# Obtém a configuração IPv4 atual
$IPConfig = Get-NetIPConfiguration -InterfaceIndex $Adapter.InterfaceIndex

$IPAddress   = $IPConfig.IPv4Address.IPAddress
$PrefixLength = $IPConfig.IPv4Address.PrefixLength
$Gateway     = $IPConfig.IPv4DefaultGateway.NextHop
$DNS         = (Get-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4).ServerAddresses

Write-Host "Adaptador : $($Adapter.Name)"
Write-Host "IP         : $IPAddress/$PrefixLength"
Write-Host "Gateway    : $Gateway"
Write-Host "DNS        : $($DNS -join ', ')"

# Remove o endereço IPv4 atual (DHCP)
Get-NetIPAddress `
    -InterfaceIndex $Adapter.InterfaceIndex `
    -AddressFamily IPv4 |
    Remove-NetIPAddress -Confirm:$false

# Configura IP estático
New-NetIPAddress `
    -InterfaceIndex $Adapter.InterfaceIndex `
    -IPAddress $IPAddress `
    -PrefixLength $PrefixLength `
    -DefaultGateway $Gateway

# Configura os servidores DNS
Set-DnsClientServerAddress `
    -InterfaceIndex $Adapter.InterfaceIndex `
    -ServerAddresses $DNS

# Desabilita IPv6 na interface
Disable-NetAdapterBinding `
    -Name $Adapter.Name `
    -ComponentID ms_tcpip6

Write-Host "IPv4 configurado como estático."
Write-Host "IPv6 desabilitado."
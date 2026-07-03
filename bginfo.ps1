# =====================================================================
# ServerInfo Wallpaper
# Windows Server 2022
# =====================================================================

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Obtém resolução atual
$Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$Width  = $Bounds.Width
$Height = $Bounds.Height

# Cria imagem
$Bitmap = New-Object System.Drawing.Bitmap($Width,$Height)
$Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

# Fundo
$Graphics.Clear([System.Drawing.Color]::FromArgb(25,25,30))

# Fonte
$Font = New-Object System.Drawing.Font("Consolas",18,[System.Drawing.FontStyle]::Regular)
$Brush = [System.Drawing.Brushes]::Lime

# Coleta informações

$OS = Get-CimInstance Win32_OperatingSystem
$CS = Get-CimInstance Win32_ComputerSystem

$Adapter = Get-NetIPConfiguration |
Where-Object {$_.IPv4Address -ne $null} |
Select-Object -First 1

$IP      = $Adapter.IPv4Address.IPAddress
$Gateway = $Adapter.IPv4DefaultGateway.NextHop
$DNS     = (Get-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4).ServerAddresses -join ", "

$FQDN = "$($CS.DNSHostName).$($CS.Domain)"

$RAM = "{0:N1} GB" -f ($CS.TotalPhysicalMemory / 1GB)

$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$Free = "{0:N1} GB" -f ($Disk.FreeSpace/1GB)
$Total = "{0:N1} GB" -f ($Disk.Size/1GB)

$Uptime = (Get-Date) - $OS.LastBootUpTime

$Lines = @(
"SERVER INFORMATION"
""
"Hostname : $($env:COMPUTERNAME)"
"FQDN     : $FQDN"
"Domain   : $($CS.Domain)"
""
"IPv4     : $IP"
"Gateway  : $Gateway"
"DNS      : $DNS"
""
"OS       : $($OS.Caption)"
"Version  : $($OS.Version)"
"RAM      : $RAM"
"Disk C:  : $Free GB livres de $Total GB"
""
"Uptime   : $($Uptime.Days) dias $($Uptime.Hours) horas"
""
"Generated: $(Get-Date)"
)

$Y = 40

foreach($Line in $Lines)
{
    $Graphics.DrawString($Line,$Font,$Brush,40,$Y)
    $Y += 34
}

# Salva imagem
$Wallpaper = "C:\Windows\Web\Wallpaper\ServerInfo.jpg"

$Bitmap.Save($Wallpaper,[System.Drawing.Imaging.ImageFormat]::Jpeg)

$Graphics.Dispose()
$Bitmap.Dispose()

# Define wallpaper

Add-Type @"
using System.Runtime.InteropServices;

public class Wallpaper
{
    [DllImport("user32.dll",SetLastError=true)]
    public static extern bool SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni);
}
"@

[Wallpaper]::SystemParametersInfo(20,0,$Wallpaper,3)

Write-Host "Wallpaper criado em $Wallpaper"
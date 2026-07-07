# Install-RDS.ps1
# Windows Server 2025 - RDS Deploy (Parte 1)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root="C:\RDSDeploy"
New-Item -ItemType Directory -Force -Path $Root | Out-Null
$Log="$Root\Install.log"
$Cfg="$Root\Config.xml"

function Log($m){
    ("{0} - {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$m) | Out-File $Log -Append -Encoding utf8
}

if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
[Security.Principal.WindowsBuiltInRole]::Administrator)){
    [System.Windows.Forms.MessageBox]::Show("Execute como Administrador.")
    exit
}

$form=New-Object Windows.Forms.Form
$form.Text="RDS Deploy"
$form.Size='420,180'
$form.StartPosition='CenterScreen'

$l=New-Object Windows.Forms.Label
$l.Text="FQDN:"
$l.Location='10,20'
$form.Controls.Add($l)

$t=New-Object Windows.Forms.TextBox
$t.Location='60,18'
$t.Size='320,20'
try{$t.Text=[System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName}catch{}
$form.Controls.Add($t)

$p=New-Object Windows.Forms.ProgressBar
$p.Location='10,60'
$p.Size='370,20'
$form.Controls.Add($p)

$b=New-Object Windows.Forms.Button
$b.Text="Instalar"
$b.Location='150,95'
$form.Controls.Add($b)

$b.Add_Click({
    $fqdn=$t.Text.Trim()
    if([string]::IsNullOrWhiteSpace($fqdn)){[Windows.Forms.MessageBox]::Show("Informe o FQDN.");return}

    Log "Iniciando instalação."

    $xml=@"
<Config>
  <FQDN>$fqdn</FQDN>
</Config>
"@
    $xml | Set-Content $Cfg

    $features=@(
        "RDS-RD-Server",
        "RDS-Connection-Broker",
        "RDS-Web-Access"
    )

    $i=0
    foreach($f in $features){
        $i++
        $p.Value=[int](($i-1)/$features.Count*100)
        Log "Instalando $f"
        Install-WindowsFeature $f -IncludeManagementTools | Out-Null
        $p.Value=[int]($i/$features.Count*100)
    }

    $action=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\RDSDeploy\Configure-RDS.ps1"
    $trigger=New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "Configure-RDS" -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null

    Log "Reiniciando."
    Restart-Computer -Force
})

$form.ShowDialog()

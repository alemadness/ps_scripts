$config=Get-Content C:\Scripts\AD-Config.json | ConvertFrom-Json
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form=New-Object Windows.Forms.Form
$form.Text="Deploy Active Directory"
$form.Size=New-Object Drawing.Size(520,230)
$form.StartPosition="CenterScreen"
$form.ControlBox=$false
$form.TopMost=$true

$label=New-Object Windows.Forms.Label
$label.Location=New-Object Drawing.Point(20,20)
$label.Size=New-Object Drawing.Size(460,20)
$form.Controls.Add($label)

$progress=New-Object Windows.Forms.ProgressBar
$progress.Location=New-Object Drawing.Point(20,55)
$progress.Size=New-Object Drawing.Size(460,25)
$form.Controls.Add($progress)

$log=New-Object Windows.Forms.ListBox
$log.Location=New-Object Drawing.Point(20,95)
$log.Size=New-Object Drawing.Size(460,90)
$form.Controls.Add($log)

$form.Show()

function Step($Percent,$Text){

    $progress.Value=$Percent
    $label.Text=$Text
    $log.Items.Add($Text)

    [System.Windows.Forms.Application]::DoEvents()
}
Step 10 "Validando configuração..."

Start-Sleep 1

Step 20 "Instalando Active Directory Domain Services..."

Install-WindowsFeature AD-Domain-Services `
    -IncludeManagementTools `
    -ErrorAction Stop

Step 50 "Importando módulos..."

Import-Module ADDSDeployment

Step 70 "Preparando promoção..."

$Secure=ConvertTo-SecureString $config.DSRM -AsPlainText -Force

Step 90 "Promovendo servidor para Domain Controller..."

Install-ADDSForest `
    -DomainName $config.Domain `
    -DomainNetbiosName $config.Netbios `
    -InstallDNS `
    -SafeModeAdministratorPassword $Secure `
    -Force
# Remove a tarefa agendada
Unregister-ScheduledTask -TaskName "adinst" -Confirm:$false -ErrorAction SilentlyContinue
Step 100 "Concluido. Reiniciando servidor..."

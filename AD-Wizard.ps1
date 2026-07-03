Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configFile = "C:\Scripts\AD-Config.json"
New-Item "C:\Scripts" -ItemType Directory -Force | Out-Null

$form = New-Object System.Windows.Forms.Form
$form.Text = "Deploy Automtico do Active Directory"
$form.Size = New-Object Drawing.Size(470,320)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

[System.Windows.Forms.MessageBox]::Show(
"Deploy automático do Active Directory.`n`nAps clicar em Instalar aguarde a conclusão do processo. O servidor ser reiniciado automaticamente.",
"Deploy AD",
"OK",
"Information") | Out-Null

function Add-Label($text,$x,$y){
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object Drawing.Point($x,$y)
    $l.AutoSize = $true
    $form.Controls.Add($l)
}

function Add-TextBox($x,$y,$readonly=$false,$password=$false){

    $t = New-Object Windows.Forms.TextBox
    $t.Location = New-Object Drawing.Point($x,$y)
    $t.Size = New-Object Drawing.Size(260,22)
    $t.ReadOnly = $readonly
    $t.UseSystemPasswordChar = $password
    $form.Controls.Add($t)
    return $t
}

Add-Label "Servidor:" 20 25
$txtHost = Add-TextBox 150 22 $true
$txtHost.Text = $env:COMPUTERNAME

Add-Label "Domnio:" 20 60
$txtDomain = Add-TextBox 150 57

Add-Label "NetBIOS:" 20 95
$txtNetbios = Add-TextBox 150 92

Add-Label "Senha DSRM:" 20 130
$txtPass = Add-TextBox 150 127 $false $true

Add-Label "Confirmar:" 20 165
$txtPass2 = Add-TextBox 150 162 $false $true

$txtDomain.Add_TextChanged({
    if($txtDomain.Text.Contains(".")){
        $txtNetbios.Text=$txtDomain.Text.Split(".")[0].ToUpper()
    }
})

$btn = New-Object Windows.Forms.Button
$btn.Text="Instalar"
$btn.Location=New-Object Drawing.Point(120,220)
$form.Controls.Add($btn)

$cancel=New-Object Windows.Forms.Button
$cancel.Text="Cancelar"
$cancel.Location=New-Object Drawing.Point(240,220)
$form.Controls.Add($cancel)

$cancel.Add_Click({$form.Close()})

$btn.Add_Click({

    if($txtPass.Text -ne $txtPass2.Text){
        [Windows.Forms.MessageBox]::Show("As senhas não conferem.")
        return
    }

    $cfg=@{
        Hostname=$txtHost.Text
        Domain=$txtDomain.Text
        Netbios=$txtNetbios.Text
        DSRM=$txtPass.Text
    }

    $cfg | ConvertTo-Json | Set-Content $configFile

    Start-Process powershell.exe `
        -ArgumentList "-ExecutionPolicy Bypass -File C:\Scripts\AD-Deploy.ps1"

    $form.Close()

})

$form.ShowDialog()
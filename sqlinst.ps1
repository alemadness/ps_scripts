$ErrorActionPreference = "Continue"

# Cria pasta de logs
New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null

# Inicia log
Start-Transcript -Path "C:\Logs\InstalacaoSQL.log" -Append

# =========================
# CAMINHO DOS ARQUIVOS OFFLINE
# =========================

$SqlSetupPath = "C:\sqlinst\setup.exe"
$SqlMediaPath = "C:\sqlinst"

# =========================
# INSTALA SQL SERVER STANDARD 2025
# =========================

if (Test-Path $SqlSetupPath) {

    Start-Process `
        -FilePath $SqlSetupPath `
        -WindowStyle Hidden `
        -ArgumentList @(
            "/Q",
            "/ACTION=Install",
            "/FEATURES=SQLEngine",
            "/INSTANCENAME=MSSQLSERVER",
            "/IACCEPTSQLSERVERLICENSETERMS",
            "/TCPENABLED=1",
            "/SECURITYMODE=SQL",
            "/SAPWD=SKAkNAknu83ghdfgh2022!Secure#",
            "/SQLSVCSTARTUPTYPE=Automatic",
            "/SQLSYSADMINACCOUNTS=$env:USERNAME",
            "/MEDIASOURCE=$SqlMediaPath"
        ) -Wait

} else {

    [System.Windows.MessageBox]::Show(
        "Arquivo setup.exe nao encontrado em C:\sqlinst.",
        "Erro Instalacao SQL",
        "OK",
        "Error"
    )

    Stop-Transcript
    exit
}

# =========================
# CRIA ATALHO DO SSMS NA AREA DE TRABALHO
# =========================

$SSMSPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\Ssms.exe"

if (Test-Path $SSMSPath) {

    $WScriptShell = New-Object -ComObject WScript.Shell

    $Shortcut = $WScriptShell.CreateShortcut(
        "$([Environment]::GetFolderPath('Desktop'))\SQL Server Management Studio.lnk"
    )

    $Shortcut.TargetPath = $SSMSPath
    $Shortcut.WorkingDirectory = Split-Path $SSMSPath
    $Shortcut.IconLocation = $SSMSPath
    $Shortcut.Save()

    Write-Host "Atalho do SSMS criado na area de trabalho"

} else {

    Write-Host "SSMS nao encontrado para criar atalho"
}

# =========================
# REMOVE PASTA SQLINST
# =========================

if (Test-Path "C:\sqlinst") {
    Remove-Item "C:\sqlinst" -Recurse -Force
}

# Remove a tarefa agendada
Unregister-ScheduledTask -TaskName "sqlinst" -Confirm:$false -ErrorAction SilentlyContinue

# Caminho do proprio script
$ScriptPath = $MyInvocation.MyCommand.Path

# Cria BAT temporario para apagar o script
@"
timeout /t 2 >nul
del "$ScriptPath"
"@ | Out-File "$env:TEMP\remove_script.bat" -Encoding ascii

# Executa o BAT
Start-Process "cmd.exe" "/c `"$env:TEMP\remove_script.bat`"" -WindowStyle Hidden

# Finaliza log
Stop-Transcript
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
    "A instalação do SQL Server 2025 foi concluida com sucesso.",
    "Instalação Concluida",
    "OK",
    "Information"
)
# Desativa o SA

Add-Type -AssemblyName "Microsoft.VisualBasic"

$ConnectionString = "Server=localhost;Database=master;Integrated Security=True;TrustServerCertificate=True"

$Connection = New-Object System.Data.SqlClient.SqlConnection
$Connection.ConnectionString = $ConnectionString

$Connection.Open()
$Command = $Connection.CreateCommand()
$Command.CommandText = "ALTER LOGIN sa DISABLE"
$Command.ExecuteNonQuery()
$Connection.Close()

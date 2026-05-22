$ErrorActionPreference = "Continue"
Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(
    "O SQL Server 2022 esta sendo instalado.`n`nAguarde a finalizao do processo.",
        "Instalao SQL Server 2022",
            "OK",
                "Warning"
                )

# Cria pasta de logs
New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null

# Inicia log
Start-Transcript -Path "C:\Logs\InstalacaoSQL.log" -Append

# =========================
# INSTALA SQL EXPRESS 2022
# =========================

Invoke-WebRequest `
    -Uri "https://go.microsoft.com/fwlink/?linkid=2200812" `
    -OutFile "$env:TEMP\SQLEXPR_x64_ENU.exe"

Start-Process `
    -FilePath "$env:TEMP\SQLEXPR_x64_ENU.exe" `
    -ArgumentList "/Q /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=SQLEXPRESS /IACCEPTSQLSERVERLICENSETERMS /TCPENABLED=1 /SECURITYMODE=SQL /SAPWD=SenhaForte123!" `
    -Wait

# =========================
# INSTALA SSMS
# =========================

Invoke-WebRequest `
    -Uri "https://aka.ms/ssmsfullsetup" `
    -OutFile "$env:TEMP\SSMS-Setup.exe"

Start-Process `
    -FilePath "$env:TEMP\SSMS-Setup.exe" `
    -ArgumentList "/install /quiet /norestart" `
    -Wait

Write-Host "Instalacao concluida"

# Remove a tarefa agendada
Unregister-ScheduledTask -TaskName "MinhaTarefaLogon" -Confirm:$false

# Caminho do prprio script
$ScriptPath = $MyInvocation.MyCommand.Path
# Cria BAT temporrio para apagar o script
@"
timeout /t 2 >nul
del "$ScriptPath"
"@ | Out-File "$env:TEMP\remove_script.bat" -Encoding ascii

# Executa o BAT
Start-Process "cmd.exe" "/c `"$env:TEMP\remove_script.bat`"" -WindowStyle Hidden
# Finaliza log
Stop-Transcript

[System.Windows.MessageBox]::Show(    "A instalao do SQL Server 2022 foi concluda com sucesso.",
    "Instalao Concluda",
        "OK",
            "Information"
            )
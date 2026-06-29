Set-ExecutionPolicy Bypass -Scope Process -Force

Install-WindowsFeature `
    RDS-RD-Server, `
    RDS-Connection-Broker, `
    RDS-Licensing `
    -IncludeManagementTools

$Action = New-ScheduledTaskAction `
   -Execute "powershell.exe" `
   -Argument "-ExecutionPolicy Bypass -File C:\temp\rds_install2.ps1"

$Trigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask `
   -TaskName "ContinueRDS" `
   -Action $Action `
   -Trigger $Trigger `
   -RunLevel Highest `
   -User SYSTEM

Restart-Computer -Force

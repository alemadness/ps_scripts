Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(
    "A instalacao do SQL Server 2025 Standard foi iniciada em segundo plano.`n`nAguarde a mensagem de finalização do processo.",
    "Microsoft SQL Server 2025 - NAO DESLIGUE!",
    "OK",
    "Warning"
)
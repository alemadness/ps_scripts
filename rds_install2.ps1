Import-Module RemoteDesktop

New-RDSessionDeployment `
    -ConnectionBroker WS2025wRDS.wevy.local `
    -SessionHost WS2025wRDS.wevy.local `
    -WebAccessServer WS2025wRDS.wevy.local

New-RDSessionCollection `
    -CollectionName "RDS" `
    -SessionHost WS2025wRDS.wevy.local `
    -ConnectionBroker WS2025wRDS.wevy.local


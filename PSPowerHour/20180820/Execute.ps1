$SaPassword = 'Pa55w0rd'
$Containers = @{
    'sql1' = @{
        Image = 'microsoft/mssql-server-windows-developer:latest'
        Port = 50000
    }
    'sql2' = @{
        Image = 'microsoft/mssql-server-windows-developer:latest'
        Port = 50001
    }
    'sql3' = @{
        Image = 'microsoft/mssql-server-windows-developer:latest'
        Port = 50002
    }
}
$TraceFlags = @(1117, 1118, 2371, 3226)

$secureString = ConvertTo-SecureString $SaPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('sa', $secureString)

$servers = @()
foreach ($container in $Containers.GetEnumerator()) {
    $servers += $container.Key
}

$null = Read-Host "Press Enter to Start Setup"
. '.\01-SetupContainers.ps1'

$null = Read-Host -Prompt "Press Enter to Continue to Step #2"
. '.\02-SetupPowerShell.ps1'

$null = Read-Host -Prompt "Press Enter to Continue to Step #3"
. '.\03-SetupSqlAliases.ps1'

$null = Read-Host -Prompt "Press Enter to Continue to Step #4"
. '.\04-CheckTraceFlags.ps1'

$null = Read-Host -Prompt "Press Enter to Continue to Step #5"
. '.\05-SetTraceFlags.ps1'

$null = Read-Host -Prompt "Press Enter to Continue to Step #6"
. '.\06-CheckTraceFlags.ps1'
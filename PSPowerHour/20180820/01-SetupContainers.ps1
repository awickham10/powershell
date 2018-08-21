Write-Host "Login to Docker" -ForegroundColor 'Yellow'
docker login

Write-Host "Setting up containers" -ForegroundColor 'Green'
foreach ($container in $Containers.GetEnumerator()) {
    $name = $container.Key

    $exists = docker ps -a | Select-String $name
    $running = $exists | Select-String 'Up'

    if ($exists -and $running) {
        Write-Host "Container $name is already running" -ForegroundColor 'Green'
        continue
    }
    elseif ($exists -and -not $running) {
        Write-Host "Starting container $name on port $($container.Value.Port)" -ForegroundColor 'Yellow'
        $command = "docker container start $name"
    }
    else {
        Write-Host "Creating container $name on port $($container.Value.Port)" -ForegroundColor 'Yellow'
        $command = "docker run -d -p $($container.Value.Port):1433 -e sa_password=$SaPassword -e ACCEPT_EULA=Y --name=$name $($container.Value.Image)"
    }

    Write-Host "Executing $command" -ForegroundColor 'Yellow'
    $null = Invoke-Command -ScriptBlock ([ScriptBlock]::Create($command))
}

Write-Host "Container setup complete" -ForegroundColor 'Green'
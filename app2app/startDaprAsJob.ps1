# pre-requisites:
# - initialized with: dapr init --slim
#   so that redis is running as container and placement service is started on demand

# --------------------------------------------------------------------------------
# project / service configuration
# - appId       = needs to be Dapr id commonly used to address service
# - folder      = relative folder of .NET project (containing components folder and tracing.yaml)
# - projectFile = name of service project file
# - settingName = name of launch setting (Launch:Project; not IIS Express) which is 
#                 modified for startup
# - debug       = $true  : no background instance is started; waiting for (debugging)
#                          instance started from VS
#                 $false : background instance of service is started with dotnet run

$configProjects = @(
    @{
        appId       = "app1"
        folder      = "./app1"
        projectFile = "app1.csproj"
        settingName = "app1"
        debug       = $false
    }
    @{
        appId       = "app2"
        folder      = "./app2"
        projectFile = "app2.csproj"
        settingName = "app2"
        debug       = $true
    }
)

# --------------------------------------------------------------------------------
# helper function : update environment variable in launch setting
function Update-EnvironmentVariable ($environmentVariables, $name, $value) {
    $m = $environmentVariables | Get-Member $name
    if ($m) {
        $environmentVariables.PSObject.Properties.Remove($name)
    }
    $environmentVariables | Add-Member -MemberType NoteProperty -Name $name -Value $value
}

# --------------------------------------------------------------------------------
# INIT

$ErrorActionPreference = "Stop"

# check environment and files (implicitly with -Resolve)
foreach ($configProject in $configProjects) {
    $projectFile = Join-Path $configProject.folder $configProject.projectFile -Resolve
    $launchSettingsFile = Join-Path $configProject.folder "Properties/launchSettings.json" -Resolve
    $componentsPath = Join-Path $configProject.folder "components/" -Resolve
    $configFile = Join-Path $configProject.folder "tracing.yaml" -Resolve
}

# stop and remove previous jobs
$jobNamePattern = $configProjects | Join-String -Property appId -Separator "|" -OutputPrefix "(placement|" -OutputSuffix ")"
Get-Job | ? { $_.Name -match $jobNamePattern } | Stop-Job -PassThru | Remove-Job

# --------------------------------------------------------------------------------
# MAIN

$jobs = @()

# start placement service/job
$DAPR_PLACEMENT_PORT = 6050
$jobName = "placement"
Start-Job -Name $jobName -ScriptBlock {
    param( $port )
    
    C:\Dapr\placement.exe --port $port

} -Argument $DAPR_PLACEMENT_PORT
$jobs += $jobName

# start jobs for app and dapr sidecar
$DAPR_HTTP_PORT = 3500
$DAPR_GRPC_PORT = 50001
$METRICS_PORT = 9091
$APP_PORT = 5000

foreach ($configProject in $configProjects) {
    $projectFile = Join-Path $configProject.folder $configProject.projectFile -Resolve
    $launchSettingsFile = Join-Path $configProject.folder "Properties/launchSettings.json" -Resolve
    $componentsPath = Join-Path $configProject.folder "components/" -Resolve
    $configFile = Join-Path $configProject.folder "tracing.yaml" -Resolve

    $ASPNETCORE_URLS = "http://localhost:" + $APP_PORT + ";https://localhost:" + $($APP_PORT + 1)

    $launchSettings = Get-Content $launchSettingsFile | ConvertFrom-Json

    "-" * 80

    foreach ($profile in $launchSettings.profiles.PSObject.Properties) {
        if ($profile.Name -eq $configProject.settingName) {
            Update-EnvironmentVariable $profile.Value.environmentVariables "ASPNETCORE_URLS" $ASPNETCORE_URLS
            Update-EnvironmentVariable $profile.Value.environmentVariables "DAPR_HTTP_PORT" $DAPR_HTTP_PORT.ToString()
            Update-EnvironmentVariable $profile.Value.environmentVariables "DAPR_GRPC_PORT" $DAPR_GRPC_PORT.ToString()
        }
    }

    $launchSettings | ConvertTo-Json -Depth 10 | Set-Content $launchSettingsFile
    Write-Host "updated" $launchSettingsFile

    $jobName = $configProject.appId + "-daprd"

    Write-Host "start Daprd in background" $configProject.appId $APP_PORT $env:DAPR_HTTP_PORT $env:DAPR_GRPC_PORT $env:METRICS_PORT

    Start-Job -Name $jobName -ScriptBlock {
        param( $appId, $appPort, $DAPR_HTTP_PORT, $DAPR_GRPC_PORT, $DAPR_PLACEMENT_PORT, $METRICS_PORT, $componentsPath, $configFile)

        daprd --app-id $appId  `
            --app-port $appPort `
            --placement-address $("localhost:" + $DAPR_PLACEMENT_PORT) `
            --log-level debug `
            --components-path $componentsPath `
            --config $configFile `
            --dapr-http-port $DAPR_HTTP_PORT `
            --dapr-grpc-port $DAPR_GRPC_PORT `
            --metrics-port $METRICS_PORT

    } -Argument $configProject.appId, $APP_PORT, $DAPR_HTTP_PORT, $DAPR_GRPC_PORT, $DAPR_PLACEMENT_PORT, $METRICS_PORT, $componentsPath, $configFile

    $jobs += $jobName

    if ($configProject.debug) {
        Write-Host "expecting" $projectFile "to be started from development environment"
    } else {
        $jobName = $configProject.appId + "-app"

        Start-Job -Name $jobName -ScriptBlock {
            param($projectFile, $launchProfile)

            dotnet run -p $projectFile --urls $env:ASPNETCORE_URLS --launch-profile $launchProfile

        } -Argument $projectFile, $configProject.settingName

        $jobs += $jobName
    }

    $DAPR_HTTP_PORT += 10
    $DAPR_GRPC_PORT += 10
    $APP_PORT += 10
    $METRICS_PORT += 1
}

# --------------------------------------------------------------------------------
# handle menu

$running = $true

while ($running) {
    "-" * 80
    Write-Host "t: test call health endpoint"
    Write-Host "s: job status"
    Write-Host "e: check all logs for errors"
    Write-Host "q: stop jobs and quit"
    $jobId = 0
    foreach ($job in $jobs) {
        Write-Host $($jobId.ToString() + ": show log of " + $job)
        $jobId += 1
    }

    $option = Read-Host "Enter option"

    switch ($option.ToUpper()) {
        "T" {
            "-" * 80
            Write-Host "App1 health"
            Invoke-RestMethod -Method Get -Uri "http://localhost:3500/v1.0/invoke/app1/method/health"
            Write-Host "App2 health (through App1)"
            Invoke-RestMethod -Method Get -Uri "http://localhost:3500/v1.0/invoke/app1/method/healthapp2"
        }
        "S" {
            Get-Job | ? { $_.Name -match $jobNamePattern } | Format-Table Name, State
        }
        "E" {
            foreach ($job in $jobs) {
                $errors = $null
                if ($job -match "-app$") {
                    $errors = (Receive-Job -Name $job -Keep) -match "(error|fail)\:"
                }
                else {
                    $errors = (Receive-Job -Name $job -Keep) -match "level\=error"
                }
                if ($errors) {
                    "-" * 80
                    Write-Host "ERROR IN JOB:" $job -ForegroundColor Red
                    $errors
                }
            }
        }
        "Q" {
            Get-Job | ? { $_.Name -match $jobNamePattern } | Stop-Job -PassThru | Remove-Job
            $running = $false            
        }
        default {
            if ([int32]::TryParse($option , [ref]$jobId )) {
                if ($jobId -ge 0 -and $jobId -lt $jobs.Count) {
                    Receive-Job -Name $jobs[$jobId] -Keep | code -
                }
            }
        }
    }
}

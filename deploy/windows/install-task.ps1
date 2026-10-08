# Registers the "Draftmancer" scheduled task: starts the supervisor (server +
# Cloudflare Tunnel) hidden at logon for the current user. No admin needed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File deploy\windows\install-task.ps1
$vbs = Join-Path $PSScriptRoot "start-hidden.vbs"
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbs`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = "PT30S"
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName "Draftmancer" -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description "Self-hosted Draftmancer (deploy/windows/supervise.mjs)" -Force | Out-Null
Write-Output "Registered scheduled task 'Draftmancer' -> $vbs"

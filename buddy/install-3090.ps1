# Register nsk-buddy tasks on the 3090 (run as admin nsketch). ASCII only (PowerShell 5.1).
#  - nsk-buddy-check-macmini   : every 30 min, watch the Mac mini and post to Slack on trouble
#  - nsk-buddy-restart-macmini : daily 04:00; the script restarts the Mac mini only on the 1st of each month
$bash = 'C:\Program Files\Git\bin\bash.exe'
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.nsk-buddy" | Out-Null
$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$env:USERNAME" -LogonType S4U -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$a1 = New-ScheduledTaskAction -Execute $bash -Argument '-lc "~/claude-dotfiles/buddy/buddy-check.sh macmini"'
$t1 = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddHours((Get-Date).Hour + 1)) -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'nsk-buddy-check-macmini' -Action $a1 -Trigger $t1 -Principal $principal -Settings $settings -Description 'nsk-buddy: watch the Mac mini every 30 min, notify Slack (claude-dotfiles/buddy)' -Force | Out-Null
$a2 = New-ScheduledTaskAction -Execute $bash -Argument '-lc "~/claude-dotfiles/buddy/restart-macmini.sh"'
$t2 = New-ScheduledTaskTrigger -Daily -At '04:00'
Register-ScheduledTask -TaskName 'nsk-buddy-restart-macmini' -Action $a2 -Trigger $t2 -Principal $principal -Settings $settings -Description 'nsk-buddy: restart the Mac mini on the 1st of each month 04:00 (claude-dotfiles/buddy)' -Force | Out-Null
Get-ScheduledTask -TaskName 'nsk-buddy-*' | ForEach-Object { "$($_.TaskName) state=$($_.State) next=$((Get-ScheduledTaskInfo -TaskName $_.TaskName).NextRunTime)" }
if (-not (Test-Path "$env:USERPROFILE\.nsk-buddy\slack_webhook_url")) { 'NOTE: no slack_webhook_url yet; notifications go to ~/.nsk-buddy/buddy.log only' }

$s = Get-Service Parsec -ErrorAction SilentlyContinue; if ($s) { "parsec_svc=$($s.Status)" } else { "parsec_svc=missing" }
"parsecd=$(@(Get-Process -Name parsecd -ErrorAction SilentlyContinue).Count)"
try { "web=$((Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 https://www.google.com).StatusCode)" } catch { "web=000" }
"tw=$(@(Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue).Count)"
$m = Select-String -Path C:\ProgramData\Parsec\log_cl.txt -Pattern 'successful /me' -ErrorAction SilentlyContinue | Select-Object -Last 1; if ($m -and ($m.Line -match '^\[\w (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]')) { "me_age_min=$([int]((Get-Date) - [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)).TotalMinutes)" } else { "me_age_min=-1" }
"disk_free_gb=$([math]::Round((Get-PSDrive C).Free / 1GB))"
"uptime_days=$([int]((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalDays)"


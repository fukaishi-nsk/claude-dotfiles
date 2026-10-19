# Mac mini の状態を key=value で出す（3090 から ssh macmini 'bash -s' < この中身 で流す・読み取りのみ）
echo "tw=$(netstat -an -p tcp 2>/dev/null | grep -c TIME_WAIT)"
echo "web=$(curl -s -o /dev/null -m 8 -w '%{http_code}' https://www.google.com)"
if pgrep -qf /Applications/Parsec.app; then echo parsec_running=1; else echo parsec_running=0; fi
if pgrep -qif sunshine; then echo sunshine_running=1; else echo sunshine_running=0; fi
boot=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ,)
echo "uptime_days=$(( ($(date +%s) - boot) / 86400 ))"
echo "parsec_err_recent=$(grep -E 'successful /me|failed with error 17' ~/.parsec/log.txt 2>/dev/null | tail -5 | grep -c 'error 17')"

#!/bin/bash

echo "=================================="
echo " AI Linux SysAdmin Agent"
echo " Basic System Health Check"
echo "=================================="

echo
echo "[SYSTEM]"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"

echo
echo "[MEMORY]"
free -h

echo
echo "[DISK USAGE]"
df -h /


disk_usage=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
threshold=80

if [ "$disk_usage" -ge "$threshold" ]; then
    echo "WARNING: Disk usage is ${disk_usage}%"
else
    echo "OK: Disk usage is ${disk_usage}%"
fi

echo
echo "[SYSTEM LOAD]"
uptime

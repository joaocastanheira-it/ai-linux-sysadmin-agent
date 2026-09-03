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

memory_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
memory_threshold=80

if [ "$memory_usage" -ge "$memory_threshold" ]; then
    echo "WARNING: Memory usage is ${memory_usage}%"
else
    echo "OK: Memory usage is ${memory_usage}%"
fi
echo
echo "[DISK USAGE]"
df -h /


disk_usage=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
disk_threshold=80

if [ "$disk_usage" -ge "$disk_threshold" ]; then
    echo "WARNING: Disk usage is ${disk_usage}%"
else
    echo "OK: Disk usage is ${disk_usage}%"
fi

echo
echo "[SYSTEM LOAD]"
uptime

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

echo
echo "[SYSTEM LOAD]"
uptime

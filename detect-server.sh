#!/bin/bash

echo "========================================="
echo "     Server Type Detection v1.0"
echo "========================================="
echo

SERVER_TYPE="Unknown"
SCORE=0

# -----------------------------
# Container Detection
# -----------------------------
if [ -f /.dockerenv ]; then
    echo "[+] Docker environment detected"
    SERVER_TYPE="Container"
fi

if grep -qaE 'docker|lxc|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
    echo "[+] Container cgroup detected"
    SERVER_TYPE="Container"
fi

if systemd-detect-virt --container >/dev/null 2>&1; then
    echo "[+] Container virtualization detected"
    SERVER_TYPE="Container"
fi

if [ "$SERVER_TYPE" = "Container" ]; then
    echo
    echo "Detected Type: CONTAINER"
    exit 0
fi

# -----------------------------
# Virtualization Detection
# -----------------------------
VIRT=$(systemd-detect-virt 2>/dev/null)

if [ -n "$VIRT" ] && [ "$VIRT" != "none" ]; then
    echo "[+] Virtualization: $VIRT"
else
    echo "[+] No virtualization detected"
    echo
    echo "Detected Type: BARE METAL"
    exit 0
fi

# -----------------------------
# Q35 Detection
# -----------------------------
Q35_FOUND=0

if dmesg 2>/dev/null | grep -qi "Q35"; then
    Q35_FOUND=1
fi

if command -v dmidecode >/dev/null 2>&1; then
    if dmidecode 2>/dev/null | grep -qi "Q35"; then
        Q35_FOUND=1
    fi
fi

if [ "$Q35_FOUND" = "1" ]; then
    echo "[+] Q35 machine type detected"
    SCORE=$((SCORE+3))
else
    echo "[-] Q35 machine type not detected"
fi

# -----------------------------
# CPU Steal Time Check
# -----------------------------
STEAL=$(top -bn1 | grep "Cpu(s)" | awk -F',' '{for(i=1;i<=NF;i++) if($i~/%st/) print $i}' | sed 's/[^0-9.]//g')

if [ -n "$STEAL" ]; then
    echo "[+] CPU Steal Time: ${STEAL}%"

    STEAL_INT=$(printf "%.0f" "$STEAL")

    if [ "$STEAL_INT" -eq 0 ]; then
        SCORE=$((SCORE+2))
    fi
fi

# -----------------------------
# CPU Information
# -----------------------------
CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2)

echo "[+] CPU: $CPU_MODEL"

if echo "$CPU_MODEL" | grep -qiE "Xeon|EPYC|Ryzen"; then
    SCORE=$((SCORE+1))
fi

# -----------------------------
# Hypervisor Check
# -----------------------------
if command -v virt-what >/dev/null 2>&1; then
    HV=$(virt-what | head -n1)

    if [ -n "$HV" ]; then
        echo "[+] Hypervisor: $HV"
    fi
fi

# -----------------------------
# Final Classification
# -----------------------------
echo
echo "========================================="
echo "Analysis Score: $SCORE"
echo "========================================="
echo

if [ "$SCORE" -ge 4 ]; then
    SERVER_TYPE="LIKELY VDS"
else
    SERVER_TYPE="LIKELY VPS"
fi

echo "Detected Type : $SERVER_TYPE"

echo
echo "Virtualization : $VIRT"
echo "CPU Cores      : $(nproc)"
echo "RAM            : $(free -h | awk '/Mem:/ {print $2}')"
echo "Disk           : $(df -h / | awk 'NR==2 {print $2}')"

echo
echo "NOTE:"
echo "- VDS vs VPS cannot be determined with 100% certainty from inside Linux."
echo "- Q35 is treated as a positive indicator for VDS."
echo "- This result is an educated guess, not proof."

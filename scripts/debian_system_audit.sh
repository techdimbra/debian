#!/usr/bin/env bash
# Debian 13 XFCE Initial System Audit Script
# Generates an extensive report covering system, hardware, network,
# package, and service details for a freshly installed Debian system.

set -uo pipefail

print_usage() {
  cat <<'USAGE'
Usage: debian_system_audit.sh [OUTPUT_FILE]

If OUTPUT_FILE is omitted, the report will be saved to
"./debian_system_audit_YYYYmmdd_HHMMSS.log".
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  print_usage
  exit 0
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DEFAULT_REPORT="debian_system_audit_${TIMESTAMP}.log"
REPORT_FILE=${1:-$DEFAULT_REPORT}
REPORT_DIR=$(dirname "$REPORT_FILE")

mkdir -p "$REPORT_DIR"
: > "$REPORT_FILE"

exec > >(tee -a "$REPORT_FILE")
exec 2>&1

section() {
  local title="$1"
  local line="======================================================================"
  printf '\n%s\n%s\n%s\n' "$line" "$title" "$line"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_or_note() {
  local title="$1"
  shift
  local cmd="$1"
  section "$title"
  if command_exists "$cmd"; then
    "$@"
  else
    printf "Command '%s' not found on this system.\n" "$cmd"
  fi
}

run_privileged() {
  local title="$1"
  shift
  local cmd="$1"
  section "$title"
  if [[ $EUID -eq 0 ]]; then
    if command_exists "$cmd"; then
      "$cmd" "${@:2}"
    else
      printf "Command '%s' not found on this system.\n" "$cmd"
    fi
  elif command_exists sudo; then
    sudo "$cmd" "${@:2}"
  else
    printf "Command '%s' requires elevated privileges and 'sudo' is unavailable.\n" "$cmd"
  fi
}

smartctl_scan() {
  if ! command_exists smartctl; then
    return 1
  fi
  if [[ $EUID -eq 0 ]]; then
    smartctl --scan-open
  elif command_exists sudo; then
    sudo smartctl --scan-open
  else
    smartctl --scan-open
  fi
}

run_custom() {
  local title="$1"
  local statement="$2"
  section "$title"
  bash -c "$statement"
}

section "Debian 13 XFCE Initial System Audit"
printf "Report generated: %s\n" "$(date)"
printf "Report location : %s\n" "$(realpath "$REPORT_FILE")"
printf "Executed by      : %s\n" "$(whoami)"
printf "Host            : %s\n" "$(hostname)"

section "Operating System Details"
if command_exists lsb_release; then
  lsb_release -a
else
  printf "Command 'lsb_release' not found. Falling back to /etc/os-release.\n"
fi
if [[ -r /etc/os-release ]]; then
  cat /etc/os-release
fi

run_or_note "Hostname and Kernel" hostnamectl
run_or_note "Kernel Information" uname -a
run_or_note "System Uptime" uptime -p
run_custom "Boot History" "last -x | head -n 10"
run_or_note "Time Synchronization" timedatectl status
run_or_note "Virtualization Detection" systemd-detect-virt

section "Hardware Overview"
run_or_note "CPU Information" lscpu
run_or_note "Memory Information" free -h
run_privileged "Memory Devices" dmidecode -t memory
run_privileged "BIOS Information" dmidecode -t bios
run_or_note "Block Devices" lsblk -fio NAME,FSTYPE,LABEL,SIZE,TYPE,MOUNTPOINT
run_or_note "Disk Usage" df -hT
run_custom "Mounted Filesystems" "mount | column -t"
run_or_note "PCI Devices" lspci -nn
run_or_note "USB Devices" lsusb -tv
run_or_note "SCSI Devices" lsscsi
run_or_note "Loaded Kernel Modules" lsmod
run_or_note "Sensors" sensors
run_or_note "Graphics (VGA/3D Controllers)" bash -c 'lspci -nn | grep -i "vga\|3d"'
run_or_note "Display Info (xrandr)" xrandr --verbose
run_or_note "Audio Devices" aplay -l

section "Storage Health"
run_privileged "SMART Status" smartctl --scan-open
if command_exists smartctl; then
  SMART_OUTPUT=$(smartctl_scan 2>&1)
  SMART_STATUS=$?
  if [[ $SMART_STATUS -eq 0 ]]; then
    mapfile -t SMART_DEVICES < <(printf '%s\n' "$SMART_OUTPUT" | awk '{print $1}')
    if [[ ${#SMART_DEVICES[@]} -gt 0 ]]; then
      for device in "${SMART_DEVICES[@]}"; do
        run_privileged "SMART Details for ${device}" smartctl -a "$device"
      done
    else
      section "SMART Detailed Reports"
      printf "Nenhum dispositivo compatível com SMART foi detectado.\n"
    fi
  else
    section "SMART Detailed Reports"
    printf "Falha ao executar smartctl --scan-open (%s). Saída completa:\n%s\n" "$SMART_STATUS" "$SMART_OUTPUT"
  fi
else
  section "SMART Detailed Reports"
  printf "Command 'smartctl' not found on this system.\n"
fi

section "Network Configuration"
run_or_note "IP Configuration" ip address show
run_or_note "Routing Table" ip route show
run_or_note "DNS Configuration" resolvectl status
run_or_note "NetworkManager Devices" nmcli device status
run_or_note "Active Network Connections" ss -tulpn
run_or_note "Firewall Status (ufw)" ufw status verbose
run_or_note "Firewall Status (firewalld)" firewall-cmd --state

section "Package and Repository Information"
run_or_note "APT Policy" apt-cache policy
run_or_note "APT Sources" cat /etc/apt/sources.list
run_custom "APT Additional Sources" 'find /etc/apt/sources.list.d -type f -print -exec cat {} \; 2>/dev/null'
run_or_note "Pending Upgrades" apt list --upgradable
run_custom "Package Upgrade Summary" "apt-get -s upgrade | grep -E '^Inst|^Conf'"
run_custom "Installed Package Count" "dpkg-query -f='${binary:Package}\n' -W | wc -l"
run_or_note "Flatpak Remotes" flatpak remotes
run_or_note "Snap Packages" snap list

section "Service Status"
run_or_note "Running Systemd Services" systemctl list-units --type=service --state=running
run_or_note "Failed Systemd Services" systemctl list-units --type=service --state=failed
run_or_note "Enabled Systemd Services" systemctl list-unit-files --type=service --state=enabled
run_or_note "Timers" systemctl list-timers
run_or_note "Login Sessions" loginctl list-sessions

section "Security Checks"
run_or_note "Listening Ports" netstat -tulpn
run_or_note "AppArmor Status" aa-status
run_or_note "SELinux Status" sestatus
run_custom "Sudoers Customizations" 'grep -Rhv "^#" /etc/sudoers /etc/sudoers.d 2>/dev/null'
run_or_note "Fail2Ban Status" fail2ban-client status

section "Logs and Diagnostics"
run_or_note "Recent Critical Journal Entries" journalctl -p 3 -n 50
run_or_note "dmesg (Last 200 lines)" dmesg | tail -n 200
run_custom "Xorg Logs" 'find /var/log -maxdepth 1 -name "Xorg.*.log" -exec echo "--- {} ---" \; -exec tail -n 50 {} \; 2>/dev/null'

section "Desktop Environment"
run_or_note "XFCE Version" xfce4-about --version
run_or_note "XFCE Settings (xfconf channels)" xfconf-query -l
run_or_note "Display Manager" systemctl status display-manager
run_or_note "LightDM Configuration" cat /etc/lightdm/lightdm.conf
run_or_note "Autostart Entries" bash -c 'find ~/.config/autostart /etc/xdg/autostart -type f -print 2>/dev/null'

section "User Environment"
run_custom "Logged-In Users" who
run_custom "Shell History Size" 'echo "$HISTFILE" && wc -l "$HISTFILE" 2>/dev/null'
run_custom "Environment Variables" 'env | sort'
run_custom "Home Directory Disk Usage" 'du -sh ~ 2>/dev/null'

section "Snapshots and Backups"
run_or_note "Timeshift Snapshots" timeshift --list
run_or_note "Btrfs Subvolumes" btrfs subvolume list /
run_or_note "ZFS Datasets" zfs list

section "Virtualization and Containers"
run_or_note "Running Containers (podman)" podman ps -a
run_or_note "Running Containers (docker)" docker ps -a
run_or_note "Libvirt Domains" virsh list --all

section "End of Report"
printf "Audit completed at: %s\n" "$(date)"
printf "Report saved to : %s\n" "$(realpath "$REPORT_FILE")"

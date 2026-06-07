#!/bin/sh
# Xboard-Node Multi-Panel Instance Uninstaller for Alpine Linux
#
# Usage:
#   curl -fsSL URL | sh -s -- --name INSTANCE
#
# Documentation: https://github.com/lei33440/xboard-node-multi-panel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
[ "$(id -u)" -ne 0 ] && log_error "Please run as root" && exit 1

# Parse arguments
INSTANCE_NAME=""

while [ $# -gt 0 ]; do
    case "$1" in
        --name) INSTANCE_NAME="$2"; shift 2;;
        --help) cat <<'HELP'
Xboard-Node Multi-Panel Instance Uninstaller

Usage:
  curl -fsSL URL | sh -s -- --name INSTANCE

Arguments:
  --name INSTANCE   Instance name to uninstall (required)
  --help            Show this help

Examples:
  # Uninstall specific instance
  curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/uninstall-instance.sh | sh -s -- --name mypanel

Documentation: https://github.com/lei33440/xboard-node-multi-panel
HELP
exit 0 ;;
        *) shift;;
    esac
done

# Validate arguments
[ -z "$INSTANCE_NAME" ] && log_error "Missing --name argument" && exit 1

SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
CONFIG_DIR="/etc/xboard-node-${INSTANCE_NAME}"
BINARY_PATH="/usr/local/bin/xboard-node"
LOG_PATH="/var/log/xboard-node-${INSTANCE_NAME}.log"
PID_FILE="/run/xboard-node-${INSTANCE_NAME}.pid"

echo ""
echo "=============================================="
echo "  Xboard-Node Instance Uninstaller"
echo "=============================================="
echo ""
log_info "Uninstalling instance: ${INSTANCE_NAME}"
echo ""

# Check if instance exists
if [ ! -d "$CONFIG_DIR" ]; then
    log_error "Instance '${INSTANCE_NAME}' not found!"
    log_error "Config directory does not exist: ${CONFIG_DIR}"

    # List available instances
    echo ""
    log_info "Available instances:"
    ls -d /etc/xboard-node-* 2>/dev/null | while read dir; do
        basename "$dir" | sed 's/^xboard-node-//'
    done
    exit 1
fi

# Confirm uninstallation
log_warn "This will remove:"
log_warn "  - Service: /etc/init.d/${SERVICE_NAME}"
log_warn "  - Config: ${CONFIG_DIR}"
log_warn "  - Logs: ${LOG_PATH}"
log_warn "  - PID: ${PID_FILE}"
echo ""

printf "Are you sure you want to uninstall '${INSTANCE_NAME}'? (y/N): "
read -r confirm
case "$confirm" in
    y|Y) ;;
    *) log_info "Aborted." && exit 0 ;;
esac

# Stop service
log_info "Stopping service..."
rc-service "$SERVICE_NAME" stop 2>/dev/null
killall -n xboard-node 2>/dev/null || true
rm -f "$PID_FILE"

# Remove service script
log_info "Removing service script..."
rm -f "/etc/init.d/${SERVICE_NAME}"

# Remove config directory
log_info "Removing configuration..."
rm -rf "$CONFIG_DIR"

# Remove logs
log_info "Removing logs..."
rm -f "$LOG_PATH"
rm -f "${LOG_PATH}.err"

# Remove autostart
rc-update del "$SERVICE_NAME" default 2>/dev/null

echo ""
echo "=============================================="
log_info "Instance '${INSTANCE_NAME}' uninstalled successfully!"
echo "=============================================="
echo ""
log_info "Note: xboard-node binary was NOT removed"
log_info "      Other instances may still be using it"
echo ""
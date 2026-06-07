#!/bin/sh
# Xboard-Node Multi-Panel Uninstall All for Alpine Linux
#
# Usage:
#   curl -fsSL URL | sh
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

echo ""
echo "=============================================="
echo "  Xboard-Node Uninstall All"
echo "=============================================="
echo ""

# Find all instances
INSTANCES=$(ls -d /etc/xboard-node-* 2>/dev/null | while read dir; do
    basename "$dir" | sed 's/^xboard-node-//'
done)

if [ -z "$INSTANCES" ]; then
    log_info "No xboard-node instances found"
    exit 0
fi

log_warn "Found the following instances:"
echo ""
for name in $INSTANCES; do
    log_warn "  - ${name}"
done
echo ""

printf "Are you sure you want to uninstall ALL instances? (yes/NO): "
read -r confirm
case "$confirm" in
    yes|YES) ;;
    *) log_info "Aborted." && exit 0 ;;
esac

echo ""

# Uninstall each instance
for name in $INSTANCES; do
    SERVICE_NAME="xboard-node-${name}"
    CONFIG_DIR="/etc/xboard-node-${name}"
    LOG_PATH="/var/log/xboard-node-${name}.log"
    PID_FILE="/run/xboard-node-${name}.pid"

    log_info "Uninstalling ${name}..."

    # Stop service
    rc-service "$SERVICE_NAME" stop 2>/dev/null

    # Remove files
    rm -f "/etc/init.d/${SERVICE_NAME}"
    rm -rf "$CONFIG_DIR"
    rm -f "$LOG_PATH" "${LOG_PATH}.err"
    rm -f "$PID_FILE"

    # Remove autostart
    rc-update del "$SERVICE_NAME" default 2>/dev/null

    log_info "  Removed: ${name}"
done

# Remove binary
log_info "Removing xboard-node binary..."
rm -f /usr/local/bin/xboard-node

echo ""
echo "=============================================="
log_info "All instances uninstalled!"
echo "=============================================="
echo ""
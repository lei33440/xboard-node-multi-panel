#!/bin/sh
# Xboard-Node Multi-Panel Installer for Alpine Linux
#
# Usage:
#   curl -fsSL URL | sh -s -- --name INSTANCE --panel URL --token TOKEN --machine-id ID
#
# Documentation: https://github.com/lei33440/xboard-node-multi-panel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="1.0.0"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check root
[ "$(id -u)" -ne 0 ] && log_error "Please run as root" && exit 1

# Check Alpine Linux
[ ! -f /etc/alpine-release ] && log_error "This script only supports Alpine Linux" && exit 1

# Parse arguments
INSTANCE_NAME=""
PANEL_URL=""
TOKEN=""
MACHINE_ID=""
INSTALL_VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --name) INSTANCE_NAME="$2"; shift 2;;
        --panel) PANEL_URL="$2"; shift 2;;
        --token) TOKEN="$2"; shift 2;;
        --machine-id) MACHINE_ID="$2"; shift 2;;
        --version) INSTALL_VERSION="$2"; shift 2;;
        --help) cat <<'HELP'
Xboard-Node Multi-Panel Installer v1.0.0

Usage:
  curl -fsSL URL | sh -s -- --name INSTANCE --panel URL --token TOKEN --machine-id ID

Arguments:
  --name NAME       Instance name (required, unique identifier)
  --panel URL       Panel URL (required)
  --token TOKEN     Auth token (required)
  --machine-id ID   Machine ID (required)
  --version VER     Xboard-Node version (default: latest)
  --help            Show this help

Examples:
  # Add first panel
  curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/install-instance.sh | sh -s -- \
    --name mypanel --panel http://panel1.com --token xxx --machine-id 1

  # Add second panel
  curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/install-instance.sh | sh -s -- \
    --name backup --panel http://panel2.com --token yyy --machine-id 1

Documentation: https://github.com/lei33440/xboard-node-multi-panel
HELP
exit 0 ;;
        *) shift;;
    esac
done

# Validate arguments
[ -z "$INSTANCE_NAME" ] && log_error "Missing --name argument" && exit 1
[ -z "$PANEL_URL" ] && log_error "Missing --panel argument" && exit 1
[ -z "$TOKEN" ] && log_error "Missing --token argument" && exit 1
[ -z "$MACHINE_ID" ] && log_error "Missing --machine-id argument" && exit 1

# Validate instance name (alphanumeric and hyphen only)
case "$INSTANCE_NAME" in
    *[^a-zA-Z0-9-]*) log_error "Instance name must contain only letters, numbers, and hyphens" && exit 1 ;;
esac

# Service name
SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
CONFIG_DIR="/etc/xboard-node-${INSTANCE_NAME}"
BINARY_PATH="/usr/local/bin/xboard-node"
LOG_PATH="/var/log/xboard-node-${INSTANCE_NAME}.log"
PID_FILE="/run/xboard-node-${INSTANCE_NAME}.pid"

# Banner
echo ""
echo "=============================================="
echo "  Xboard-Node Multi-Panel Installer v${VERSION}"
echo "=============================================="
echo ""
log_info "Instance: ${INSTANCE_NAME}"
log_info "Panel: ${PANEL_URL}"
log_info "Machine ID: ${MACHINE_ID}"
echo ""

# Check if instance already exists
if [ -d "$CONFIG_DIR" ]; then
    log_warn "Instance '${INSTANCE_NAME}' already exists!"
    log_warn "Config directory: ${CONFIG_DIR}"
    echo ""
    printf "Do you want to overwrite it? (y/N): "
    read -r confirm
    case "$confirm" in
        y|Y) log_info "Overwriting existing instance..." ;;
        *) log_info "Aborted." && exit 0 ;;
    esac
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_NAME="amd64" ;;
    aarch64|arm64) ARCH_NAME="arm64" ;;
    *) log_error "Unsupported architecture: $ARCH" && exit 1 ;;
esac
log_info "Architecture: $ARCH ($ARCH_NAME)"

# Install dependencies
log_step "Installing dependencies..."
apk add --no-cache curl ca-certificates openrc >/dev/null 2>&1

# Create directories
log_step "Creating directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p /var/log

# Download binary (if not exists or forced update)
if [ ! -f "$BINARY_PATH" ]; then
    log_step "Downloading xboard-node..."
    BASE="https://github.com/cedar2025/xboard-node/releases"
    if [ "$INSTALL_VERSION" = "latest" ]; then
        DOWNLOAD_URL="$BASE/latest/download/xboard-node-linux-$ARCH_NAME"
    else
        DOWNLOAD_URL="$BASE/download/$INSTALL_VERSION/xboard-node-linux-$ARCH_NAME"
    fi

    curl -fsSL -o "$BINARY_PATH" "$DOWNLOAD_URL" || {
        log_error "Failed to download xboard-node"
        exit 1
    }
    chmod +x "$BINARY_PATH"
    log_info "Binary downloaded successfully"
else
    log_info "Binary already exists, skipping download"
fi

# Create config
log_step "Creating configuration..."
INSTANCE_ID="$(echo "$PANEL_URL" | sed 's|https\?://||' | tr './' '-')-machine-${MACHINE_ID}-$(date +%s)"
cat > "$CONFIG_DIR/config.yml" <<EOF
instances:
    - id: ${INSTANCE_ID}
      panel:
        url: ${PANEL_URL}
      machine:
        machine_id: ${MACHINE_ID}
        token: ${TOKEN}
EOF
log_info "Config created: ${CONFIG_DIR}/config.yml"

# Create OpenRC service script
log_step "Creating OpenRC service script..."
cat > "/etc/init.d/${SERVICE_NAME}" <<'SVCEOF'
#!/sbin/openrc-run

description="Xboard Node - INSTANCE_NAME"
command="/usr/local/bin/xboard-node"
command_args="-c CONFIG_DIR/config.yml"
command_background=true
pidfile="/run/xboard-node-INSTANCE_NAME.pid"
output_log="/var/log/xboard-node-INSTANCE_NAME.log"
error_log="/var/log/xboard-node-INSTANCE_NAME.log"

depend() {
    need net
}

start_pre() {
    checkpath --directory --mode 0755 --owner root:root /var/log
    checkpath --file --mode 0644 --owner root:root /var/log/xboard-node-INSTANCE_NAME.log
}
SVCEOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_NAME/${INSTANCE_NAME}/g" "/etc/init.d/${SERVICE_NAME}"
sed -i "s|CONFIG_DIR|${CONFIG_DIR}|g" "/etc/init.d/${SERVICE_NAME}"
chmod +x "/etc/init.d/${SERVICE_NAME}"
log_info "Service created: /etc/init.d/${SERVICE_NAME}"

# Stop existing service if running
log_step "Stopping existing service..."
rc-service "$SERVICE_NAME" stop 2>/dev/null
killall -n xboard-node 2>/dev/null || true
rm -f "$PID_FILE"

# Start service
log_step "Starting xboard-node..."
rc-service "$SERVICE_NAME" start

# Wait for startup
sleep 3

# Check status
if pgrep -x xboard-node >/dev/null; then
    echo ""
    echo "=============================================="
    log_info "Instance '${INSTANCE_NAME}' installed successfully!"
    echo "=============================================="
    echo ""
    log_info "Service: ${SERVICE_NAME}"
    log_info "Config: ${CONFIG_DIR}/config.yml"
    log_info "Log: ${LOG_PATH}"
    echo ""
    log_info "Commands:"
    log_info "  Status:  rc-service ${SERVICE_NAME} status"
    log_info "  Restart: rc-service ${SERVICE_NAME} restart"
    log_info "  Logs:    tail -f ${LOG_PATH}"
    echo ""

    # Enable on boot
    rc-update add "$SERVICE_NAME" default 2>/dev/null
    log_info "Autostart enabled"
else
    echo ""
    echo "=============================================="
    log_error "Service failed to start"
    echo "=============================================="
    echo ""
    log_error "Please check logs:"
    log_error "  tail -30 ${LOG_PATH}"
    echo ""
    exit 1
fi
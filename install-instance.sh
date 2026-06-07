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

VERSION="1.0.1"

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
Xboard-Node Multi-Panel Installer v1.0.1

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

# Paths
SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
CONFIG_DIR="/etc/xboard-node-${INSTANCE_NAME}"
BINARY_PATH="/usr/local/bin/xboard-node"
LOG_PATH="/var/log/xboard-node-${INSTANCE_NAME}.log"

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
    printf "Do you want to overwrite it? (y/N): "
    read -r confirm
    case "$confirm" in
        y|Y) log_info "Overwriting..." ;;
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
mkdir -p "$CONFIG_DIR"
mkdir -p /var/log

# Download binary
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
    log_info "Binary downloaded"
else
    log_info "Binary exists, skipping"
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
log_info "Config: ${CONFIG_DIR}/config.yml"

# Create unified startup script if first instance
if [ ! -f /etc/local/start-xboard-all ]; then
    log_step "Creating startup manager..."
    cat > /etc/local/start-xboard-all <<'STRTALL'
#!/bin/sh
# Start all xboard-node instances
sleep 2
for config in /etc/xboard-node-*/config.yml; do
    instance=$(basename $(dirname $config))
    logfile="/var/log/${instance}.log"
    mkdir -p /var/log
    /usr/local/bin/xboard-node -c "$config" >> "$logfile" 2>&1 &
done
exit 0
STRTALL
    chmod +x /etc/local/start-xboard-all
    log_info "Startup manager created"
fi

# Stop all instances
log_step "Stopping existing instances..."
pkill -9 xboard-node 2>/dev/null || true
rm -f /run/xboard-node-*.pid

# Start this instance
log_step "Starting xboard-node..."
/usr/local/bin/xboard-node -c "$CONFIG_DIR/config.yml" >> "$LOG_PATH" 2>&1 &

sleep 3

# Check status
if pgrep -f "xboard-node.*${CONFIG_DIR}" >/dev/null; then
    echo ""
    echo "=============================================="
    log_info "Instance '${INSTANCE_NAME}' installed!"
    echo "=============================================="
    echo ""
    log_info "Config: ${CONFIG_DIR}/config.yml"
    log_info "Log: ${LOG_PATH}"
    log_info "Panel: ${PANEL_URL}"
    echo ""
    log_info "View logs: tail -f ${LOG_PATH}"
    echo ""

    # Set up autostart (using unified startup script)
    if ! grep -q "start-xboard-all" /etc/local.d/xboard-node.start 2>/dev/null; then
        cat > /etc/local.d/xboard-node.start <<'AUTOSTART'
#!/bin/sh
/etc/local/start-xboard-all
AUTOSTART
        chmod +x /etc/local.d/xboard-node.start
        log_info "Autostart configured"
    fi
else
    echo ""
    log_error "Service failed to start"
    log_error "Check logs: tail -30 ${LOG_PATH}"
    exit 1
fi
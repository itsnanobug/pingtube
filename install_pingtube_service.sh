#!/bin/bash
set -e

BASE_NAME="pingtube"
SERVICE_DIR="/etc/systemd/system"

# Ask if a custom service name should be used
read -p "Do you want to choose a custom service name? (y/N): " choose
choose=$(echo "$choose" | tr '[:upper:]' '[:lower:]')

if [[ "$choose" == "y" || "$choose" == "yes" ]]; then
    read -p "Enter custom service name (just the suffix, e.g. 'itsnanobug'): " custom_name
    # If the name starts with "pingtube", use it directly, otherwise prefix with "pingtube-"
    if [[ "$custom_name" == pingtube* ]]; then
        SERVICE_NAME="$custom_name"
    else
        SERVICE_NAME="pingtube-${custom_name}"
    fi
else
    # Automatically pick the next available service name
    SERVICE_NAME="$BASE_NAME"
    n=2
    while [ -f "${SERVICE_DIR}/${SERVICE_NAME}.service" ]; do
        SERVICE_NAME="${BASE_NAME}-${n}"
        n=$((n+1))
    done
fi

echo "[INFO] Service name selected: ${SERVICE_NAME}"

# Ask which Linux user should run the service
read -p "Enter the Linux username that should run this service: " USER_NAME
if ! id "$USER_NAME" &>/dev/null; then
    echo "[INFO] User '$USER_NAME' does not exist. Creating user..."
    sudo useradd --system --create-home --shell /usr/sbin/nologin "$USER_NAME"
fi

INSTALL_DIR="/opt/${SERVICE_NAME}"
SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}.service"
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="/var/log/${SERVICE_NAME}"
LOGROTATE_FILE="/etc/logrotate.d/${SERVICE_NAME}"

# Stop existing service with same name (if running)
echo "[INFO] Stopping existing service if running..."
sudo systemctl stop ${SERVICE_NAME}.service || true

# Install Python and venv
echo "[INFO] Installing Python and venv..."
sudo apt update
sudo apt install -y python3 python3-pip

# Prepare installation directory
echo "[INFO] Preparing ${INSTALL_DIR}"
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# Copy main files
echo "[INFO] Copying files from $SOURCE_DIR to $INSTALL_DIR"
sudo cp "$SOURCE_DIR"/pingtube.py "$INSTALL_DIR"/
sudo cp "$SOURCE_DIR"/config.json "$INSTALL_DIR"/

# Copy virtualenv if it exists, otherwise create a new one
if [ -d "$SOURCE_DIR/venv" ]; then
    echo "[INFO] Copying existing venv..."
    sudo cp -r "$SOURCE_DIR/venv" "$INSTALL_DIR"/
else
    echo "[INFO] Creating a new virtualenv..."
    sudo -u "$USER_NAME" /bin/bash <<EOF
cd "$INSTALL_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install feedparser requests
EOF
fi

# Fix file ownership
echo "[INFO] Setting ownership for $INSTALL_DIR"
sudo chown -R $USER_NAME:$USER_NAME "$INSTALL_DIR"

# Create log directory
echo "[INFO] Creating log directory $LOG_DIR"
sudo mkdir -p "$LOG_DIR"
sudo chown $USER_NAME:$USER_NAME "$LOG_DIR"

# Create logrotate configuration
echo "[INFO] Creating logrotate configuration $LOGROTATE_FILE"
sudo bash -c "cat > $LOGROTATE_FILE" <<EOF
$LOG_DIR/pingtube.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 640 $USER_NAME $USER_NAME
    postrotate
        systemctl restart ${SERVICE_NAME}.service >/dev/null 2>&1 || true
    endscript
}
EOF

PYTHON_CMD="${INSTALL_DIR}/venv/bin/python"

# Create systemd service file
echo "[INFO] Creating service file $SERVICE_FILE"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Pingtube RSS Checker Service (${SERVICE_NAME})
After=network.target

[Service]
Type=simple
User=${USER_NAME}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${PYTHON_CMD} ${INSTALL_DIR}/pingtube.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable the service
echo "[INFO] Reloading systemd..."
sudo systemctl daemon-reload

echo "[INFO] Enabling and starting ${SERVICE_NAME}.service..."
sudo systemctl enable --now ${SERVICE_NAME}.service

echo "[SUCCESS] Installation complete."
echo "Check logs with: sudo journalctl -u ${SERVICE_NAME}.service -f"

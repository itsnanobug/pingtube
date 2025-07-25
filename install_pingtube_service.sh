#!/bin/bash
set -e

INSTALL_DIR="/opt/pingtube"
USER_NAME="nanoservice"            # username (not UID)
SERVICE_NAME="pingtube"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="/var/log/pingtube"
LOGROTATE_FILE="/etc/logrotate.d/pingtube"

echo "[INFO] Stopping existing service if running..."
sudo systemctl stop ${SERVICE_NAME}.service || true

echo "[INFO] Installing Python and venv..."
sudo apt update
sudo apt install -y python3 python3-pip

echo "[INFO] Preparing ${INSTALL_DIR}"
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

echo "[INFO] Copying files from $SOURCE_DIR to $INSTALL_DIR"
sudo cp "$SOURCE_DIR"/pingtube.py "$INSTALL_DIR"/
sudo cp "$SOURCE_DIR"/config.json "$INSTALL_DIR"/

# Copy venv if present, else create
if [ -d "$SOURCE_DIR/venv" ]; then
    echo "[INFO] Copying existing venv..."
    sudo cp -r "$SOURCE_DIR/venv" "$INSTALL_DIR"/
else
    echo "[INFO] Creating new virtualenv..."
    sudo -u "$USER_NAME" /bin/bash <<EOF
cd "$INSTALL_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install feedparser requests
EOF
fi

# Fix ownership
echo "[INFO] Setting ownership for $INSTALL_DIR"
sudo chown -R $USER_NAME:$USER_NAME "$INSTALL_DIR"

# Ensure log dir exists
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

# Create systemd service
echo "[INFO] Creating service file $SERVICE_FILE"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Pingtube RSS Checker Service
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

echo "[INFO] Reloading systemd..."
sudo systemctl daemon-reload

echo "[INFO] Enabling and starting ${SERVICE_NAME}.service..."
sudo systemctl enable --now ${SERVICE_NAME}.service

echo "[SUCCESS] Installation complete."
echo "Check logs with: sudo journalctl -u ${SERVICE_NAME}.service -f"

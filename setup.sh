#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  Zorzer L4 / ItsMeVictus — Universal One-Click Installer (VPS & Replit)
#  Run:  bash setup.sh
# ──────────────────────────────────────────────────────────────────────────────

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "======================================================================"
echo "  ⚡  ZORZER L4 — ONE-CLICK SETUP"
echo "======================================================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. System Package & Python Check ──────────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking and installing system dependencies...${NC}"

install_pkg() {
    if command -v apt-get &>/dev/null; then
        echo -e "${CYAN}→ Debian/Ubuntu detected. Installing Python3 & venv...${NC}"
        sudo apt-get update -y && sudo apt-get install -y python3 python3-pip python3-venv curl
    elif command -v dnf &>/dev/null; then
        echo -e "${CYAN}→ RHEL/CentOS/Fedora detected. Installing Python3 & pip...${NC}"
        sudo dnf install -y python3 python3-pip curl
    elif command -v yum &>/dev/null; then
        echo -e "${CYAN}→ Yum detected. Installing Python3 & pip...${NC}"
        sudo yum install -y python3 python3-pip curl
    elif command -v pacman &>/dev/null; then
        echo -e "${CYAN}→ Arch Linux detected. Installing Python3...${NC}"
        sudo pacman -Sy --noconfirm python python-pip curl
    fi
}

if ! command -v python3 &>/dev/null; then
    echo -e "${YELLOW}python3 not found. Attempting automatic installation...${NC}"
    install_pkg
fi

# Ensure venv module is present
if ! python3 -c 'import venv' &>/dev/null; then
    echo -e "${YELLOW}python3-venv missing. Attempting automatic installation...${NC}"
    install_pkg
fi

PYTHON_BIN="$(command -v python3)"
if [ -z "$PYTHON_BIN" ]; then
    echo -e "${RED}✗ Python3 could not be installed or found. Please install Python 3.8+ manually.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ $("$PYTHON_BIN" --version) ready${NC}"

# ── 2. Virtual Environment Setup ──────────────────────────────────────────────
echo -e "${YELLOW}[2/5] Setting up Python virtual environment...${NC}"
VENV_DIR="$SCRIPT_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Virtual environment created at $VENV_DIR${NC}"
else
    echo -e "${GREEN}✓ Virtual environment already exists${NC}"
fi

VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

# Fallback for Replit / systems where venv symlink execution differs
if [ ! -f "$VENV_PYTHON" ]; then
    VENV_PYTHON="$PYTHON_BIN"
    VENV_PIP="pip3"
fi

# ── 3. Install Requirements ───────────────────────────────────────────────────
echo -e "${YELLOW}[3/5] Installing dependencies...${NC}"
"$VENV_PIP" install --upgrade pip --quiet 2>/dev/null || true
if ! "$VENV_PIP" install -r "$SCRIPT_DIR/requirements.txt" --quiet; then
    echo -e "${RED}✗ Failed to install packages via venv pip, attempting user install...${NC}"
    "$PYTHON_BIN" -m pip install --user -r "$SCRIPT_DIR/requirements.txt" --quiet
fi
echo -e "${GREEN}✓ flask, flask-cors, requests installed${NC}"

# ── 4. Proxies Directory & File ───────────────────────────────────────────────
echo -e "${YELLOW}[4/5] Setting up proxies directory...${NC}"
PROXY_DIR="$SCRIPT_DIR/proxies"
PROXY_FILE="$PROXY_DIR/proxies.txt"
mkdir -p "$PROXY_DIR"
if [ ! -f "$PROXY_FILE" ]; then
    cat > "$PROXY_FILE" <<'EOF'
# Zorzer Proxy List — one proxy per line
# Supported formats:
#   socks5://host:port
#   socks5://user:pass@host:port
#   host:port
#   host:port:user:pass
EOF
    echo -e "${GREEN}✓ proxies/proxies.txt created (empty — add your SOCKS5 proxies)${NC}"
else
    echo -e "${GREEN}✓ proxies/proxies.txt already exists${NC}"
fi

# ── 5. Supabase & Environment Configuration ──────────────────────────────────
echo -e "${YELLOW}[5/6] Supabase & Environment Configuration...${NC}"
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    CURRENT_URL="${SUPABASE_URL:-https://fyzbqbubsdkjrmppkdsl.supabase.co}"
    CURRENT_TABLE="${SUPABASE_TABLE:-layer4_apis}"
    
    if [ -z "$SUPABASE_KEY" ]; then
        echo -e "${CYAN}Please enter your Supabase Secret Key (sb_secret_...):${NC}"
        read -r CURRENT_KEY
    else
        CURRENT_KEY="$SUPABASE_KEY"
    fi

    cat > "$ENV_FILE" <<EOF
SUPABASE_URL="$CURRENT_URL"
SUPABASE_KEY="$CURRENT_KEY"
SUPABASE_TABLE="$CURRENT_TABLE"
API_PORT=5000
EOF
    echo -e "${GREEN}✓ .env created and configured with Supabase credentials${NC}"
else
    echo -e "${GREEN}✓ .env already present${NC}"
fi

# ── 6. Systemd Service (VPS background management) ────────────────────────────
echo -e "${YELLOW}[6/6] Checking systemd service option...${NC}"
if command -v systemctl &>/dev/null && [ -d "/etc/systemd/system" ] && [ "$(id -u)" -eq 0 ]; then
    SERVICE_FILE="/etc/systemd/system/itsmevictus.service"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=ItsMeVictus Zorzer L4 API Service
After=network.target

[Service]
Type=simple
User=$(logname 2>/dev/null || echo root)
WorkingDirectory=$SCRIPT_DIR
ExecStart=$VENV_PYTHON $SCRIPT_DIR/main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable itsmevictus.service
    echo -e "${GREEN}✓ systemd service installed: itsmevictus.service (starts on boot)${NC}"
    echo -e "${CYAN}  To start now: sudo systemctl start itsmevictus${NC}"
    echo -e "${CYAN}  To check logs: sudo journalctl -u itsmevictus -f${NC}"
fi

echo ""
echo "======================================================================"
echo -e "${GREEN}  ✅  Setup complete!${NC}"
echo ""
echo "  Run manually:"
echo "    $VENV_PYTHON $SCRIPT_DIR/main.py"
echo ""
if command -v systemctl &>/dev/null && [ -f "/etc/systemd/system/itsmevictus.service" ]; then
echo "  Or manage with systemd:"
echo "    sudo systemctl start itsmevictus"
echo "    sudo systemctl stop itsmevictus"
echo "    sudo systemctl status itsmevictus"
fi
echo "======================================================================"
echo ""

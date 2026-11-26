"""
Global configuration — all tuneable values live here.
"""

import os
import socket
from pathlib import Path

# Load .env file automatically if present
env_path = Path(__file__).resolve().parent / ".env"
if env_path.exists():
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

# ── Server ────────────────────────────────────────────────────────────────────
API_PORT = int(os.environ.get("API_PORT", 5000))

# ── Packet limits ─────────────────────────────────────────────────────────────
MAX_PACKET_SIZE = 65507
MIN_PACKET_SIZE = 64
DEFAULT_PACKET_SIZE = 1400
DEFAULT_DURATION = 999999

# ── Supabase ──────────────────────────────────────────────────────────────────
SUPABASE_URL   = os.environ.get("SUPABASE_URL", "https://fyzbqbubsdkjrmppkdsl.supabase.co")
SUPABASE_KEY   = os.environ.get("SUPABASE_KEY", "")
SUPABASE_TABLE = os.environ.get("SUPABASE_TABLE", "layer4_apis")

# ── Linux socket optimisations ────────────────────────────────────────────────
try:
    USE_SENDMMSG = hasattr(socket, "sendmmsg")
except Exception:
    USE_SENDMMSG = False

SO_REUSEPORT = 15
SEND_BUFFER = 8_000_000  # 8 MB SO_SNDBUF

#!/usr/bin/env python3
"""
Ultra UDP Flood Simulator — Replit Edition  v5.0.0
Entry point: boots Flask and registers the stable Replit URL with Supabase.
"""

import multiprocessing as mp
import os
import sys
import time
import threading
import logging

# Load dependencies installed by setup.sh before importing the application
# modules that depend on Flask and Requests.
LOCAL_PACKAGES = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              '.python-packages')
if os.path.isdir(LOCAL_PACKAGES) and LOCAL_PACKAGES not in sys.path:
    sys.path.insert(0, LOCAL_PACKAGES)

# Configure logging before any local imports so all modules inherit the format.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s  [%(levelname)-8s]  %(name)s — %(message)s',
    datefmt='%H:%M:%S',
)

import config
import state
from utils     import kill_port
from registry  import register_url
from lifecycle import register_handlers
from api       import create_app


# ── Banner ────────────────────────────────────────────────────────────────────

def _banner():
    print("=" * 70)
    print("  🚀  ULTRA UDP FLOOD SIMULATOR  —  REPLIT EDITION  v5.0.0")
    print("=" * 70)
    print(f"  CPU cores  :  {mp.cpu_count()}")
    print(f"  sendmmsg   :  {config.USE_SENDMMSG}")
    print(f"  Supabase   :  {config.SUPABASE_URL}")
    print("=" * 70 + "\n")


# ── Flask runner (thread) ─────────────────────────────────────────────────────

def _run_flask(app):
    try:
        app.run(host='0.0.0.0', port=config.API_PORT,
                debug=False, threaded=True)
    except Exception as e:
        print(f"⚠️  Flask error: {e}")
    finally:
        state.flask_shutting_down = True


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    mp.freeze_support()

    register_handlers()
    _banner()

    print(f"🔄  Freeing port {config.API_PORT}...")
    kill_port(config.API_PORT)
    time.sleep(0.5)

    print(f"📡  Starting Flask on port {config.API_PORT}...")
    app    = create_app()
    thread = threading.Thread(target=_run_flask, args=(app,),
                              daemon=True, name='Flask')
    thread.start()
    time.sleep(2)

    # Resolve server public URL (Replit domain, custom env var, or VPS public IP)
    domain = os.environ.get('REPLIT_DEV_DOMAIN')
    custom_url = os.environ.get('SERVER_URL')
    if custom_url:
        server_url = custom_url.rstrip('/')
    elif domain:
        server_url = f"https://{domain}"
    else:
        # Detect public IP on VPS
        print("🔍 Detecting VPS public IP address...")
        public_ip = None
        ip_services = (
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com",
            "https://checkip.amazonaws.com",
            "http://ipinfo.io/ip",
            "http://checkip.dyndns.org",
        )
        for ip_service in ip_services:
            try:
                resp = requests.get(ip_service, timeout=4, headers={'User-Agent': 'curl/7.88.1'})
                if resp.status_code == 200:
                    import re
                    match = re.search(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', resp.text)
                    if match:
                        candidate = match.group(1)
                        if not candidate.startswith(("127.", "10.", "192.168.", "172.16.")):
                            public_ip = candidate
                            print(f"   ✓ Detected public IP: {public_ip} (via {ip_service})")
                            break
            except Exception:
                continue

        # If HTTP requests timed out or failed, try system curl directly
        if not public_ip:
            import subprocess
            for ip_cmd in ("curl -s4 ifconfig.me", "curl -s4 icanhazip.com", "curl -s4 api.ipify.org"):
                try:
                    out = subprocess.check_output(ip_cmd, shell=True, timeout=3, stderr=subprocess.DEVNULL).decode().strip()
                    import re
                    match = re.search(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', out)
                    if match:
                        candidate = match.group(1)
                        if not candidate.startswith(("127.", "10.", "192.168.", "172.16.")):
                            public_ip = candidate
                            print(f"   ✓ Detected public IP: {public_ip} (via system {ip_cmd})")
                            break
                except Exception:
                    continue

        if public_ip:
            server_url = f"http://{public_ip}:{config.API_PORT}"
        else:
            print("   ⚠️ Could not detect public IP. Localhost will NOT be registered to Supabase.")
            server_url = None

    if server_url:
        print(f"\n{'='*70}")
        print(f"  🌐  {server_url}")
        print(f"{'='*70}\n")

        if register_url(server_url):
            print(f"✅  API is live at {server_url}\n")
        else:
            print(f"⚠️   Supabase registration failed — API still running at {server_url}\n")
    else:
        local_url = f"http://localhost:{config.API_PORT}"
        print(f"\n{'='*70}")
        print(f"  🌐  {local_url} (Local only, not registered to Supabase)")
        print(f"{'='*70}\n")

    # Keep main thread alive
    try:
        while not state.shutdown_in_progress:
            time.sleep(1)
    except KeyboardInterrupt:
        pass

# ItsMeVictus — Zorzer L4

Universal One-Click Installer for VPS & Linux servers.

### One-Click Setup & Run

```bash
git clone https://github.com/deadman9306-byte/ItsMeVictus.git && cd ItsMeVictus && bash setup.sh && ./venv/bin/python main.py
```

### Background Service (systemd)

If run with `sudo` or as `root`, `setup.sh` automatically creates and enables a `systemd` service:

```bash
sudo systemctl start itsmevictus
sudo systemctl status itsmevictus
sudo journalctl -u itsmevictus -f
```

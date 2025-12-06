# piTAK  
# OpenTAKServer Raspberry Pi + VPS Relay Installer  

> Deploy a split OpenTAKServer setup:  
> • **Raspberry Pi 4** hosts the real OpenTAKServer instance.  
> • **VPS** exposes the Pi to the Internet using a **chisel** reverse‑tunnel relay (TCP only).  
> TLS is handled by OpenTAKServer on the Pi; the VPS never terminates TLS.

---

## Architecture Overview

| Component | Role | Ports | Notes |
|-----------|------|-------|-------|
| **Raspberry Pi 4** | Runs OpenTAKServer (official installer) | 8443 (Web UI), 8446 (Cert Enroll), 8088 (CoT TCP), 8089 (CoT TLS) | chisel **client** opens reverse tunnels to the VPS. |
| **VPS** | Runs chisel **server** | 9443 (chisel server), forwards 8443/8446/8088/8089 | No OpenTAKServer installed; simply relays traffic. |

> **Only the Raspberry Pi** installs and runs OpenTAKServer.

---

## Repository Contents

| File | Purpose |
|------|---------|
| `install_opentak_rpi.sh` | Installs OpenTAKServer on a Raspberry Pi 4 and configures a systemd chisel client. |
| `install_ots_relay_vps.sh` | Installs a chisel server on a VPS and configures it as a TCP relay. |

---

## Requirements

### Raspberry Pi

| Item | Details |
|------|---------|
| Hardware | Raspberry Pi 4 (or compatible) |
| OS | Raspberry Pi OS Bookworm **or** Ubuntu Server for ARM |
| Connectivity | Internet access |
| User | Non‑root user (e.g. `pi` or `ubuntu`) |
| Utilities | `curl` (installed by the script if missing) |

### VPS

| Item | Details |
|------|---------|
| OS | Ubuntu 22.04 or newer (x86_64/amd64 or arm64) |
| IP | Public IP |
| User | Non‑root user with `sudo` (e.g. `ubuntu`) |
| DNS | A‑record pointing to the VPS IP (e.g. `tak.example.com`) |
| Firewall | Open the following TCP ports: |
| | * `9443` – chisel server (from the Pi) |
| | * `8443`, `8446`, `8088`, `8089` – exposed to the Internet (if desired) |

---

## Configuration

Both scripts contain a configuration section at the top that you should edit before running.

### `install_opentak_rpi.sh`

```bash
# Name or IP of your VPS
VPS_DOMAIN="tak.example.com"

# Port where the chisel server listens on the VPS
CHISEL_PORT="9443"

# Chisel version to install
CHISEL_VERSION="1.11.3"
```

### `install_ots_relay_vps.sh`

```bash
# Port where the VPS will listen for the Raspberry Pi chisel client
CHISEL_PORT="9443"

# Chisel version to install
CHISEL_VERSION="1.11.3"

# System user that will run the chisel server (must already exist)
CHISEL_USER="ubuntu"
```

> *`VPS_DOMAIN`* must match the DNS name (or IP) of your VPS.  
> *`CHISEL_PORT`* must be identical in both scripts.  
> *`CHISEL_USER`* must be an existing user on the VPS (e.g. `ubuntu` on cloud images).

---

## Installation Steps

### 1. Clone the Repository

```bash
git clone <repo‑url>.git
cd <repo‑directory>
```

> You can also copy the individual scripts to their respective machines.

---

### 2. Install on the Raspberry Pi

1. **Edit configuration**  
   ```bash
   nano install_opentak_rpi.sh
   ```
   Set `VPS_DOMAIN` and `CHISEL_PORT`.

2. **Make script executable**  
   ```bash
   chmod +x install_opentak_rpi.sh
   ```

3. **Run the script**  
   ```bash
   ./install_opentak_rpi.sh
   ```

4. **Verify services**  
   ```bash
   systemctl status opentakserver
   systemctl status chisel-client
   ```
   Both should show `active (running)`.

---

### 3. Install on the VPS

1. **Edit configuration**  
   ```bash
   nano install_ots_relay_vps.sh
   ```
   Set `CHISEL_PORT` and `CHISEL_USER`.

2. **Make script executable**  
   ```bash
   chmod +x install_ots_relay_vps.sh
   ```

3. **Run the script**  
   ```bash
   ./install_ots_relay_vps.sh
   ```

4. **Verify the chisel server**  
   ```bash
   systemctl status chisel-server
   ```

5. **Open firewall ports** (example with UFW)  
   ```bash
   ufw allow 9443/tcp
   ufw allow 8443/tcp
   ufw allow 8446/tcp
   ufw allow 8088/tcp
   ufw allow 8089/tcp
   ```

---

## How to Use

Once both scripts finish and the tunnel is established, access the following endpoints via the VPS domain:

| Service | URL / Host:Port |
|---------|-----------------|
| OpenTAKServer Web UI | `https://<your-domain>:8443` |
| Certificate enrollment | `https://<your-domain>:8446` |
| CoT TCP | `<your-domain>:8088` |
| CoT TLS | `<your-domain>:8089` |

All traffic is forwarded over the chisel reverse tunnel to the Raspberry Pi.

---

## Troubleshooting

| Symptom | Possible Cause | Fix |
|---------|----------------|-----|
| Web UI or CoT ports not reachable | Chisel client on Pi not running or can't reach VPS | `systemctl status chisel-client` on Pi; check network/firewall |
| DNS not resolving | A‑record missing or pointing to wrong IP | Verify DNS records |
| Wrong user in VPS script | `CHISEL_USER` does not exist | Run `id <user>`; update script accordingly |
| Ports not listening on VPS | Firewall blocked | Use `sudo ss -lntp` to check; adjust UFW/iptables |
| Service failed | Missing dependencies or wrong permissions | Inspect `journalctl -u <service>` logs |

---

## Notes

* OpenTAKServer itself (Web UI, CA, CoT services) is installed and managed only on the Raspberry Pi by the official installer.  
* The scripts **do not** configure OpenTAKServer settings beyond installation; use the Web UI for user, certificate, and feed configuration.  
* The VPS purely acts as a TCP relay; it never terminates TLS and never runs OpenTAKServer.

---

Happy deploying! 🚀


readme generated by AI.

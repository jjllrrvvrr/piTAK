# piTAK
# OpenTAKServer Raspberry Pi + VPS Relay Installer

This repository contains two installation scripts to deploy a split OpenTAKServer setup:

- A **Raspberry Pi 4** runs the actual **OpenTAKServer** instance.
- A **VPS** exposes OpenTAKServer to the Internet using **chisel** reverse tunnels (TCP relay only).

TLS is handled by OpenTAKServer on the Raspberry Pi (via its own CA).  
The VPS does **not** terminate TLS and does **not** run OpenTAKServer itself.

---

## Architecture Overview

**Raspberry Pi 4:**

- Runs the official OpenTAKServer installer for Raspberry Pi OS.
- Runs a `chisel` **client** that opens reverse tunnels to the VPS:
  - Web UI (HTTPS): `8443`
  - Certificate enrollment: `8446`
  - CoT TCP: `8088`
  - CoT TLS: `8089`

**VPS:**

- Runs a `chisel` **server** that listens on a configurable port (default `9443`).
- Receives reverse tunnels from the Raspberry Pi and exposes the same ports externally:
  - `https://<your-domain>:8443` → OpenTAKServer Web UI
  - `https://<your-domain>:8446` → Certificate enrollment
  - `<your-domain>:8088` → CoT TCP
  - `<your-domain>:8089` → CoT TLS

OpenTAKServer is installed and configured **only** on the Raspberry Pi.

---

## Files in This Repository

- `install_opentak_rpi.sh`  
  Installs OpenTAKServer on a Raspberry Pi 4 (via the official installer) and configures a `chisel` client with a systemd service.

- `install_ots_relay_vps.sh`  
  Installs a `chisel` server on a VPS and configures it as a TCP relay for OpenTAKServer running on the Raspberry Pi.

---

## Requirements

### Raspberry Pi

- Raspberry Pi 4 (or similar) with:
  - Raspberry Pi OS (Bookworm recommended) **or** Ubuntu Server for ARM.
  - Internet connectivity.
- You can log in as a **non-root** user (for example `pi` or `ubuntu`).
- `curl` must be available (installed by the script if missing).

### VPS

- Ubuntu 22.04 or newer (x86_64 / amd64 or arm64).
- Public IP address.
- A non-root user (for example `ubuntu`) with `sudo` privileges.
- A DNS record pointing to your VPS IP, for example:

  ```text
  tak.example.com   A   <your_vps_public_ip>

Firewall / security group must allow:
The chisel server port (default 9443/tcp) from the Raspberry Pi.
The following ports from the Internet, if you want to expose them:
8443/tcp – OpenTAKServer Web UI (HTTPS)
8446/tcp – Certificate enrollment
8088/tcp – CoT TCP
8089/tcp – CoT TLS






Configuration
Both scripts have a configuration section at the top that you should edit before running them.
install_opentak_rpi.sh
Key variables:
# Name or IP of your VPS
VPS_DOMAIN="tak.example.com"

# Port where the chisel server listens on the VPS
CHISEL_PORT="9443"

# Chisel version to install
CHISEL_VERSION="1.11.3"

VPS_DOMAIN should match the DNS name (or IP) of your VPS.
CHISEL_PORT must match the CHISEL_PORT value in the VPS script.
CHISEL_VERSION can be updated to a newer stable version if needed.

The script:

Updates the system packages.
Runs the official OpenTAKServer Raspberry Pi installer.
Enables and starts the opentakserver systemd service.
Installs chisel and configures the chisel-client systemd service with reverse tunnels.

install_ots_relay_vps.sh
Key variables:
# Port where the VPS will listen for the Raspberry Pi chisel client
CHISEL_PORT="9443"

# Chisel version to install
CHISEL_VERSION="1.11.3"

# System user that will run the chisel server (must already exist)
CHISEL_USER="ubuntu"

CHISEL_PORT must match the Pi script.
CHISEL_USER must be an existing user (for example ubuntu on cloud images).

The script:

Updates the system packages.
Installs chisel.
Creates a chisel-server systemd service listening on CHISEL_PORT with --reverse enabled.


Installation Steps
1. Clone or copy the repository
On both the Raspberry Pi and the VPS, clone the repository or copy the two scripts:
git clone <this-repo-url>.git
cd <repo-directory>
Or manually copy install_opentak_rpi.sh to the Pi and install_ots_relay_vps.sh to the VPS.

2. Install on the Raspberry Pi

Log in to your Raspberry Pi as a non-root user (for example pi or ubuntu).

Edit the configuration at the top of install_opentak_rpi.sh:
nano install_opentak_rpi.sh
Set:

VPS_DOMAIN to your VPS domain or IP.
CHISEL_PORT to the same port configured in the VPS script.


Make the script executable:
chmod +x install_opentak_rpi.sh

Run the script:
./install_opentak_rpi.sh

After completion, check that services are running:
systemctl status opentakserver
systemctl status chisel-client
Both should be active (running).



3. Install on the VPS

Log in to your VPS as a non-root user with sudo privileges (for example ubuntu).

Edit the configuration at the top of install_ots_relay_vps.sh:
nano install_ots_relay_vps.sh
Set:

CHISEL_PORT to match the Pi script.
CHISEL_USER to the user that should run chisel (for example ubuntu).


Make the script executable:
chmod +x install_ots_relay_vps.sh

Run the script:
./install_ots_relay_vps.sh

Check that the chisel-server service is running:
systemctl status chisel-server

Ensure your firewall / cloud security group allows:

TCP CHISEL_PORT from the Raspberry Pi (for the tunnel).
TCP 8443, 8446, 8088, 8089 from the networks that should access OTS.




How to Use
Once both scripts have completed successfully and the tunnel is up:

OpenTAKServer Web UI:
https://<your-domain>:8443

Certificate enrollment endpoint:
https://<your-domain>:8446

CoT servers from TAK clients:

CoT TCP: <your-domain>:8088
CoT TLS: <your-domain>:8089



All of these connections are forwarded over chisel to the Raspberry Pi, where OpenTAKServer is actually running.

Troubleshooting
Check services
On the Raspberry Pi:
systemctl status opentakserver
systemctl status chisel-client
journalctl -u opentakserver -n 100
journalctl -u chisel-client -n 100
On the VPS:
systemctl status chisel-server
journalctl -u chisel-server -n 100
Check listening ports (VPS)
sudo ss -lntp | grep -E '9443|8443|8446|8088|8089'
You should see:

chisel listening on CHISEL_PORT (default 9443).
chisel exposing 8443, 8446, 8088, 8089 once the Pi client is connected.

Common issues

No connection to Web UI / CoT ports:
Verify that the chisel-client on the Pi is running and can reach the VPS on CHISEL_PORT.
Check firewall rules on the VPS.


DNS doesn’t resolve:
Confirm that <your-domain> points to the VPS public IP (DNS A record).


Wrong user in VPS script:
Make sure CHISEL_USER exists (id <user>).
Adjust the script if needed and re-run.




Notes

OpenTAKServer itself (web UI, CA, CoT services) is installed and managed by the official installer on the Raspberry Pi.
These scripts focus on:
Automating the OTS installation on Raspberry Pi.
Providing a clean TCP relay setup via chisel between a private Pi and a public VPS.


For OpenTAKServer-specific configuration (users, certificates, feeds, etc.), use the Web UI and documentation of OpenTAKServer.

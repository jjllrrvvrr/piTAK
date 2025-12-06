#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG À ADAPTER
########################################

# Nom DNS (ou IP) de ton VPS
VPS_DOMAIN="tak.example.com"

# Port du serveur chisel sur le VPS
CHISEL_PORT="9443"

# Version de chisel à installer (voir https://github.com/jpillora/chisel/releases)
CHISEL_VERSION="1.11.3"

########################################
# NE RIEN MODIFIER EN-DESSOUS SAUF SI TU SAIS CE QUE TU FAIS
########################################

if [[ $EUID -eq 0 ]]; then
  echo "⚠ Ne PAS exécuter ce script en root."
  echo "Connecte-toi en utilisateur normal (ex: ubuntu ou pi), puis relance."
  exit 1
fi

echo "=== Mise à jour du système ==="
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y curl ca-certificates

echo
echo "=== Installation d'OpenTAKServer (installeur officiel Raspberry Pi) ==="
# Installeur officiel OTS pour Raspberry Pi OS
# Réf doc : https://docs.opentakserver.io/installation/installation.html
curl -s -L https://i.opentakserver.io/raspberry_pi_installer | bash -

echo
echo "=== Activation du service opentakserver ==="
sudo systemctl enable --now opentakserver

echo
echo "=== Installation du client chisel (reverse tunnel vers le VPS) ==="

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64)
    CHISEL_ARCH="linux_arm64"
    ;;
  armv7l)
    CHISEL_ARCH="linux_armv7"
    ;;
  *)
    echo "Architecture $ARCH non supportée par ce script pour chisel."
    exit 1
    ;;
esac

TMPFILE="$(mktemp)"
echo "Téléchargement de chisel v${CHISEL_VERSION} pour ${CHISEL_ARCH}..."
curl -L -o "${TMPFILE}.gz" "https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_${CHISEL_ARCH}.gz"
gunzip -f "${TMPFILE}.gz"
chmod +x "${TMPFILE}"
sudo mv "${TMPFILE}" /usr/local/bin/chisel

echo
echo "=== Création du service systemd chisel-client ==="

sudo tee /etc/systemd/system/chisel-client.service >/dev/null <<EOF
[Unit]
Description=Chisel client (reverse tunnel) vers le VPS pour OpenTAKServer
After=network-online.target
Wants=network-online.target

[Service]
User=${USER}
ExecStart=/usr/local/bin/chisel client --keepalive 60s ${VPS_DOMAIN}:${CHISEL_PORT} \\
  R:8443:127.0.0.1:8443 \\
  R:8446:127.0.0.1:8446 \\
  R:8088:127.0.0.1:8088 \\
  R:8089:127.0.0.1:8089
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Recharge de systemd et démarrage du client chisel..."
sudo systemctl daemon-reload
sudo systemctl enable --now chisel-client

echo
echo "==============================================="
echo "✅ Installation Raspberry Pi terminée."
echo
echo "Quand le serveur chisel sera en route sur le VPS,"
echo "les services suivants seront accessibles via le VPS :"
echo "  - UI Web HTTPS : https://${VPS_DOMAIN}:8443"
echo "  - Enrôlement certificats : https://${VPS_DOMAIN}:8446"
echo "  - CoT TCP       : ${VPS_DOMAIN}:8088"
echo "  - CoT SSL/TLS   : ${VPS_DOMAIN}:8089"
echo
echo "Sur le VPS, lance maintenant le script d'installation chisel-server."
echo "==============================================="

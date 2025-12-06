#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG À ADAPTER
########################################

# Port où le VPS écoutera pour le client chisel du Raspberry
CHISEL_PORT="9443"

# Version chisel à installer (voir https://github.com/jpillora/chisel/releases)
CHISEL_VERSION="1.11.3"

# Utilisateur système qui exécutera chisel (doit déjà exister)
CHISEL_USER="ubuntu"

########################################
# NE RIEN MODIFIER EN-DESSOUS SAUF SI TU SAIS CE QUE TU FAIS
########################################

if ! id "${CHISEL_USER}" >/dev/null 2>&1; then
  echo "⚠ L'utilisateur ${CHISEL_USER} n'existe pas sur ce VPS."
  echo "   Modifie CHISEL_USER dans le script ou crée cet utilisateur."
  exit 1
fi

echo "=== Mise à jour du système sur le VPS ==="
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y curl ca-certificates

echo
echo "=== Installation du serveur chisel ==="

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    CHISEL_ARCH="linux_amd64"
    ;;
  arm64|aarch64)
    CHISEL_ARCH="linux_arm64"
    ;;
  *)
    echo "Architecture $ARCH non supportée pour chisel."
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
echo "=== Création du service systemd chisel-server ==="

sudo tee /etc/systemd/system/chisel-server.service >/dev/null <<EOF
[Unit]
Description=Chisel server pour tunnels OpenTAKServer (RPi -> VPS)
After=network-online.target
Wants=network-online.target

[Service]
User=${CHISEL_USER}
ExecStart=/usr/local/bin/chisel server --port ${CHISEL_PORT} --reverse --keepalive 60s
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Recharge de systemd et démarrage du serveur chisel..."
sudo systemctl daemon-reload
sudo systemctl enable --now chisel-server

echo
echo "==============================================="
echo "✅ Installation VPS terminée."
echo
echo "Assure-toi que ton firewall / sécurité cloud autorise ces ports :"
echo "  - ${CHISEL_PORT}/tcp (tunnel chisel RPi -> VPS)"
echo "  - 8443/tcp, 8446/tcp, 8088/tcp, 8089/tcp (exposés par le tunnel vers le RPi)"
echo
echo "Dès que le service chisel-client sur le Raspberry est UP, tu pourras :"
echo "  - Ouvrir l'UI : https://<ton_domaine>:8443"
echo "  - Faire l'enrôlement certs : https://<ton_domaine>:8446"
echo "  - Connecter ATAK/WinTAK/iTAK :"
echo "        * TCP  : <ton_domaine>:8088"
echo "        * SSL  : <ton_domaine>:8089"
echo
echo "Tous ces ports arriveront en réalité sur l'OpenTAKServer du Raspberry,"
echo "avec les services et la configuration standard installés par l'installeur officiel."
echo "==============================================="

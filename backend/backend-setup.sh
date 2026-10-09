#!/bin/bash
# =====================================================================
# INSTANCIA BACKEND (VPC 2) - Ubuntu 22.04
# Uso:  nano backend-setup.sh  (edita CONFIG)  ->  bash backend-setup.sh
# =====================================================================
set -euo pipefail

# ---------------- CONFIG ----------------
DOMAIN="raul-zerotrust.duckdns.org"
REPO_BACK="https://github.com/Raul-T2/zerotrust-backend.git"
DEMO_USER="admin"
DEMO_PASSWORD="Admin123!"      # solo para el laboratorio
# ----------------------------------------



echo "== 1/5 Paquetes y Node.js 22"
sudo apt-get update -y
sudo apt-get install -y git curl openssl
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v

echo "== 2/5 Clonar backend"
cd "$HOME"
rm -rf zerotrust-backend
git clone "$REPO_BACK" zerotrust-backend
cd zerotrust-backend
npm install --omit=dev

echo "== 3/5 Crear .env con un JWT_SECRET nuevo (solo existe en esta instancia)"
cat > .env <<ENV
PORT=3000
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRES_IN=1h
CORS_ORIGIN=https://${DOMAIN}
DEMO_USER=${DEMO_USER}
DEMO_PASSWORD=${DEMO_PASSWORD}
ENV
chmod 600 .env

echo "== 4/5 Servicio systemd (arranca solo y se reinicia si falla)"
sudo tee /etc/systemd/system/zerotrust-backend.service >/dev/null <<UNIT
[Unit]
Description=Backend Zero Trust
After=network.target

[Service]
User=${USER}
WorkingDirectory=${HOME}/zerotrust-backend
ExecStart=/usr/bin/node src/main.js
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now zerotrust-backend
sleep 2

echo "== 5/5 Prueba local"
curl -s http://localhost:3000/api/health ; echo
echo "Si ves {\"status\":\"ok\"} el backend esta vivo."
echo "Prueba entre VPCs (desde el FRONTEND):  curl http://IP_PRIVADA_BACKEND:3000/api/health"

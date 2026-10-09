#!/bin/bash
# =====================================================================
# INSTANCIA FRONTEND (VPC 1) - Ubuntu 22.04
# Uso:  DUCK_TOKEN="tu-token" bash frontend-setup.sh
# NO subas este archivo con tu token a GitHub.
# =====================================================================
set -euo pipefail

# Verificar sistema operativo (los scripts estan probados en Ubuntu 22.04)
OS_VER="$(. /etc/os-release && echo "$VERSION_ID")"
if [[ "$OS_VER" != "22.04" ]]; then
  echo "ERROR: esta instancia tiene Ubuntu $OS_VER. Relanza la EC2 con la AMI 'Ubuntu Server 22.04 LTS'."; exit 1
fi

# ---------------- CONFIG (edita estas 5 lineas) ----------------
DOMAIN="raul-zerotrust.duckdns.org"
DUCK_SUB="raul-zerotrust"
DUCK_TOKEN="${DUCK_TOKEN:-PEGA_AQUI_TU_TOKEN}"   # mejor: DUCK_TOKEN=tu-token bash frontend-setup.sh
BACKEND_IP="${BACKEND_IP:-10.0.1.10}"   # IP PRIVADA fija que le pones a ec2-backend al lanzarla
REPO_FRONT="https://github.com/Raul-T2/zerotrust-frontend.git"
# ---------------------------------------------------------------

if [[ "$DUCK_TOKEN" == PEGA_* || "$BACKEND_IP" == 10.X* ]]; then
  echo "Edita primero la seccion CONFIG del script."; exit 1
fi
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== 1/7 Paquetes del sistema"
sudo apt-get update -y
sudo apt-get install -y nginx git curl certbot python3-certbot-nginx fail2ban

echo "== 2/7 Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v && npm -v

echo "== 3/7 Apuntar DuckDNS a la IP publica de ESTA instancia"
curl -s "https://www.duckdns.org/update?domains=${DUCK_SUB}&token=${DUCK_TOKEN}&ip=" ; echo
# Debe responder OK. Si dice KO, revisa subdominio y token.

echo "== 4/7 Clonar y compilar el frontend"
cd "$HOME"
rm -rf zerotrust-frontend
git clone "$REPO_FRONT" zerotrust-frontend
cd zerotrust-frontend
npm install
npm run build
sudo mkdir -p /var/www/zerotrust
sudo rm -rf /var/www/zerotrust/*
sudo cp -r dist/* /var/www/zerotrust/

echo "== 5/7 Configurar nginx"
sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__BACKEND_IP__/${BACKEND_IP}/g" \
  "$HERE/nginx/zerotrust.conf" | sudo tee /etc/nginx/sites-available/zerotrust >/dev/null
sudo ln -sf /etc/nginx/sites-available/zerotrust /etc/nginx/sites-enabled/zerotrust
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

echo "== 6/7 Fail2Ban"
sudo cp "$HERE/fail2ban/nginx-login.conf"  /etc/fail2ban/filter.d/nginx-login.conf
sudo cp "$HERE/fail2ban/nginx-login.local" /etc/fail2ban/jail.d/nginx-login.local
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
sleep 2
sudo fail2ban-client status nginx-login

echo "== 7/7 Listo. SIGUE A MANO (ver LEEME.md):"
echo "   a) comprobar:  ping -c1 ${DOMAIN}   (debe mostrar la IP publica de esta EC2)"
echo "   b) ensayo:     sudo certbot --nginx -d ${DOMAIN} --dry-run"
echo "   c) real:       sudo certbot --nginx -d ${DOMAIN}   (solo en la sesion de evidencias)"

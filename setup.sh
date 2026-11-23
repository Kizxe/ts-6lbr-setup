#!/bin/bash
# Tailscale + nginx + 6LBR setup untuk gateway Pi
# Guna: edit site.conf & templates/node_config.conf, lepas tu: bash setup.sh
set -e
cd "$(dirname "$0")"
source ./site.conf

echo ">> 0. Install Tailscale (skip kalau dah ada)"
if ! command -v tailscale >/dev/null; then
  CODENAME=$(. /etc/os-release; echo "$VERSION_CODENAME")
  curl -fsSL "https://pkgs.tailscale.com/stable/debian/$CODENAME.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL "https://pkgs.tailscale.com/stable/debian/$CODENAME.tailscale-keyring.list" \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt update && sudo apt install -y tailscale
fi

echo ">> 1. Tailscale login (bukak link kat browser)"
sudo tailscale up
echo "Tailscale IP: $(tailscale ip -4)"

echo ">> 2. Enable IP forwarding"
printf 'net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n' \
  | sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

echo ">> 3. nginx"
sudo apt install -y nginx
awk -v ip="$LBR_IP" -v ports="$PORTS" '
  /\{\{LISTEN\}\}/ { n=split(ports,a," "); for(i=1;i<=n;i++) print "    listen " a[i] ";"; next }
  { gsub(/\{\{LBR_IP\}\}/, ip); print }
' templates/nginx-6lbr.conf | sudo tee /etc/nginx/sites-available/6lbr >/dev/null
sudo ln -sf /etc/nginx/sites-available/6lbr /etc/nginx/sites-enabled/6lbr
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

echo ">> 4. 6LBR node_config"
sudo cp templates/node_config.conf /etc/6lbr/node_config.conf
grep -q '^NODE_CONFIG=' /etc/6lbr/6lbr.conf || \
  sudo sed -i '/^BAUDRATE/a NODE_CONFIG=/etc/6lbr/node_config.conf' /etc/6lbr/6lbr.conf
sudo systemctl restart 6lbr 2>/dev/null || sudo service 6lbr restart

echo ">> 5. 4via6 route"
ROUTE=$(sudo tailscale debug via "$SITE_ID" "$SUBNET")
sudo tailscale set --advertise-routes="$ROUTE"
echo "Route: $ROUTE"

echo ""
echo "SIAP. Manual kat Tailscale admin console:"
echo "  - Disable key expiry device ni"
echo "  - Approve subnet route $ROUTE"
echo "  - 6LBR web: Configuration > IP64 > DHCP Off, set static IP"

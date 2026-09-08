#!/usr/bin/env bash
#
# One-time setup for the VPS that serves davey.mywindowwashing.com.
#
#   sudo ./deploy/setup-vps.sh
#
# Run this once on a fresh Debian or Ubuntu VPS. It is safe to re-run — every
# step checks before it acts.
#
# Before running, point DNS at this server:
#   A     davey.mywindowwashing.com    -> <this server's IPv4>
#   AAAA  davey.mywindowwashing.com    -> <this server's IPv6, if it has one>
#
# Certbot cannot issue a certificate until that A record resolves here.
#
set -euo pipefail

DOMAIN="davey.mywindowwashing.com"
DEPLOY_USER="deploy"
WEBROOT="/var/www/davey/public"
ACME_ROOT="/var/www/certbot"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "Run this with sudo." >&2; exit 1; }

# --- Packages ---------------------------------------------------------------
say "Installing nginx, certbot and rsync"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx rsync ufw

# --- Deploy user ------------------------------------------------------------
# GitHub Actions connects as this user. It is not root and owns nothing but
# the web root, so a leaked deploy key cannot take over the server.
say "Creating the '$DEPLOY_USER' user"
if id "$DEPLOY_USER" >/dev/null 2>&1; then
    echo "    already exists"
else
    adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi

install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
touch "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"

# --- Directories ------------------------------------------------------------
say "Creating $WEBROOT and $ACME_ROOT"
# The deploy user owns the web root because rsync --delete writes here.
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /var/www/davey "$WEBROOT"
# ACME challenges live outside the web root so rsync --delete cannot remove a
# challenge file while certbot is mid-renewal.
install -d -m 755 -o root -g root "$ACME_ROOT"

if [ ! -f "$WEBROOT/index.html" ]; then
    cat > "$WEBROOT/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Coming soon</title>
<p>Site is being set up.</p>
HTML
    chown "$DEPLOY_USER:$DEPLOY_USER" "$WEBROOT/index.html"
fi

# --- Certificate ------------------------------------------------------------
# The real config references certificate files, so nginx cannot start until
# they exist. Serve plain HTTP first, issue the certificate, then swap in the
# full config.
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    say "Issuing the TLS certificate"
    cat > "$NGINX_AVAILABLE" <<BOOTSTRAP
server {
    listen 80;
    server_name $DOMAIN;
    location ^~ /.well-known/acme-challenge/ { root $ACME_ROOT; }
    location / { return 404; }
}
BOOTSTRAP
    ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx

    certbot certonly --webroot -w "$ACME_ROOT" -d "$DOMAIN" \
        --non-interactive --agree-tos --register-unsafely-without-email \
        --keep-until-expiring
else
    say "Certificate already present for $DOMAIN"
fi

# certonly does not write these two files, but the site config includes them.
if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    cat > /etc/letsencrypt/options-ssl-nginx.conf <<'SSLOPTS'
ssl_session_cache   shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
SSLOPTS
fi
if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    say "Generating DH parameters (this takes a minute)"
    openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
fi

# --- Site configuration -----------------------------------------------------
say "Installing the nginx site configuration"
cp "$REPO_DIR/deploy/nginx/$DOMAIN.conf" "$NGINX_AVAILABLE"

# nginx refuses to start with `listen [::]` on a host that has no IPv6 stack,
# which is common on cheap VPS plans. Comment those lines out when there is
# no IPv6 address configured.
if ! ip -6 addr show scope global 2>/dev/null | grep -q inet6; then
    say "No global IPv6 address found — disabling the IPv6 listeners"
    sed -i 's/^\( *\)listen \(  *\)\?\[::\]/\1# listen [::]/' "$NGINX_AVAILABLE"
fi

ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# --- Renewal ----------------------------------------------------------------
# The certbot package installs a renewal timer. Make sure nginx picks up the
# new certificate after a renewal.
say "Configuring certificate renewal"
install -d /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'HOOK'
#!/bin/sh
systemctl reload nginx
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
systemctl enable --now certbot.timer 2>/dev/null || true

# --- Firewall ---------------------------------------------------------------
say "Configuring the firewall"
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

say "Done"
cat <<SUMMARY

  Site root     $WEBROOT
  Deploy user   $DEPLOY_USER
  Config        $NGINX_AVAILABLE

  Remaining steps, on your own machine:

  1. Make a deploy key:
       ssh-keygen -t ed25519 -f ~/.ssh/davey_deploy -N "" -C "github-actions"

  2. Authorise it on this server (restrictions keep the key to file transfer):
       KEY=\$(cat ~/.ssh/davey_deploy.pub)
       ssh root@$DOMAIN "echo 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty \$KEY' \\
         >> /home/$DEPLOY_USER/.ssh/authorized_keys"

  3. Get the host key fingerprint for the SSH_KNOWN_HOSTS secret:
       ssh-keyscan -t rsa,ecdsa,ed25519 $DOMAIN

  4. Add these repository secrets on GitHub
     (Settings -> Secrets and variables -> Actions):

       SSH_PRIVATE_KEY   contents of ~/.ssh/davey_deploy   (the private one)
       SSH_KNOWN_HOSTS   output of the ssh-keyscan above
       VPS_HOST          $DOMAIN
       VPS_USER          $DEPLOY_USER
       VPS_PATH          $WEBROOT

SUMMARY

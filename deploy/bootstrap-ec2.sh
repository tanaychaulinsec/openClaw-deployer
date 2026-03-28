#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl docker.io docker-compose-v2 git jq

systemctl enable docker
systemctl start docker

if id ubuntu >/dev/null 2>&1; then
  usermod -aG docker ubuntu
fi

mkdir -p /opt/openclaw/home
mkdir -p /opt/openclaw/releases
chown -R ubuntu:ubuntu /opt/openclaw

cat >/usr/local/bin/openclaw-host-cleanup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
docker system prune -af || true
journalctl --vacuum-size=100M || true
EOF

chmod +x /usr/local/bin/openclaw-host-cleanup

cat >/etc/cron.weekly/openclaw-host-cleanup <<'EOF'
#!/usr/bin/env bash
/usr/local/bin/openclaw-host-cleanup
EOF

chmod +x /etc/cron.weekly/openclaw-host-cleanup


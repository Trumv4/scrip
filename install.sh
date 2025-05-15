#!/bin/bash
# === 1. Cập nhật hệ thống ===
apt-get update -y
apt-get install -y wget curl sudo net-tools

# === 2. Cho phép đăng nhập SSH bằng mật khẩu và root ===
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "root:01062007Tu#" | chpasswd
systemctl restart sshd

# === 3. Cài 3proxy ===
wget -q -O /tmp/3proxy.deb "https://github.com/z3APA3A/3proxy/releases/download/0.9.4/3proxy-0.9.4.x86_64.deb"
if [ $? -ne 0 ]; then
    wget -q -O /tmp/3proxy.deb "https://github.com/z3APA3A/3proxy/releases/download/0.9.3/3proxy-0.9.3.x86_64.deb"
fi
dpkg -i /tmp/3proxy.deb || (apt-get -f install -y && dpkg -i /tmp/3proxy.deb)
rm -f /tmp/3proxy.deb

# === 4. Cấu hình proxy (port 23456 / user: anhtu / pass: anhtuproxy) ===
mkdir -p /etc/3proxy/conf
cat > /etc/3proxy/conf/3proxy.cfg <<EOF
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
auth strong
users anhtu:CL:anhtuproxy
allow anhtu
socks -p23456
EOF

# === 5. Tạo service tự khởi động sau reboot ===
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy SOCKS5 Service
After=network.target

[Service]
ExecStart=/usr/bin/3proxy /etc/3proxy/conf/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# === 6. Gửi thông tin về Telegram ===
BOT_TOKEN="7661562599:AAG5AvXpwl87M5up34-nj9AvMiJu-jYuWlA"
CHAT_ID="7051936083"
IP=$(curl -s ifconfig.me || curl -s icanhazip.com)

MESSAGE="🎯 Proxy Created!
➡️ $IP:23456
👤 anhtu
🔑 anhtuproxy

-> $IP:23456:anhtu:anhtuproxy

🔹 SSH VPS
➡️ $IP
👤 root
🔑 01062007Tu#
-> Cách Login Vào VPS Trên Command : ssh root@$IP

✅ Sẵn sàng!"
curl -s --data-urlencode "text=$MESSAGE" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID"

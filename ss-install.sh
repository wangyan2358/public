#!/bin/bash
set -e
echo "========================================"
echo "  Shadowsocks-rust 一键安装脚本（小火箭专用）"
echo "  适用于 AlmaLinux 8 + 宝塔面板"
echo "========================================"

# 随机端口（20000-59999）
PORT=$((20000 + RANDOM % 40000))
while [[ $PORT -eq 8388 || $PORT -eq 1080 || $PORT -eq 443 || $PORT -eq 80 ]]; do
    PORT=$((20000 + RANDOM % 40000))
done

# 随机20位强密码
PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c 20)

echo "正在安装 shadowsocks-rust..."

# 安装
dnf install -y yum-utils epel-release
dnf config-manager --set-enabled epel
dnf config-manager --add-repo https://dl.lamp.sh/shadowsocks/rhel/teddysun.repo
dnf makecache
dnf install -y shadowsocks-rust curl

# 写入配置
cat > /etc/shadowsocks/shadowsocks-rust-config.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": $PORT,
  "password": "$PASSWORD",
  "timeout": 300,
  "method": "chacha20-ietf-poly1305",
  "mode": "tcp_only",
  "tcp_no_delay": true,
  "fast_open": false
}
EOF

# 启动服务
systemctl daemon-reload
systemctl enable --now shadowsocks-rust-server
systemctl restart shadowsocks-rust-server

# BBR 加速
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

# 防火墙放行（firewalld）
firewall-cmd --permanent --add-port=${PORT}/tcp --add-port=${PORT}/udp
firewall-cmd --reload

# 获取公网IP
IP=$(curl -4s https://ifconfig.me || curl -4s https://ipinfo.io/ip || echo "请手动查看你的服务器IP")

# 生成一键链接
ENCODED=$(echo -n "chacha20-ietf-poly1305:$PASSWORD" | base64 -w0)
SS_LINK="ss://${ENCODED}@${IP}:${PORT}#Alma节点"

echo "=================================================="
echo "✅ 安装完成！"
echo ""
echo "服务器 IP   : $IP"
echo "端口        : $PORT"
echo "密码        : $PASSWORD"
echo "加密        : chacha20-ietf-poly1305"
echo ""
echo "小火箭一键导入链接："
echo "$SS_LINK"
echo ""
echo "=================================================="
echo "请在宝塔面板 → 安全 → 防火墙 确认端口 $PORT 已放行（入站）"
echo "把上面链接复制到手机小火箭 → 从剪贴板导入 → 连接即可"
echo "=================================================="
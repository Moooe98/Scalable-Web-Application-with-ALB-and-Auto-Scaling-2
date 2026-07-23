#!/bin/bash
# Do NOT use set -e — allow individual steps to fail without killing the whole script

exec > /var/log/user-data.log 2>&1

echo "=== Starting user-data script $(date) ==="

# ── System Updates ────────────────────────────────────────────────────────────
dnf update -y || true

# Install nginx, python3, and CloudWatch agent
# Note: 'mysql' CLI is not in AL2023 repos; use 'mariadb105' for mysql client
dnf install -y nginx python3 python3-pip amazon-cloudwatch-agent || true

echo "=== Packages installed ==="

# ── Nginx Configuration ───────────────────────────────────────────────────────
cat > /etc/nginx/conf.d/app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    # Health check endpoint for ALB
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ /index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "strict-origin-when-cross-origin";
    }

    # Cache static assets
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;
}
EOF

echo "=== Nginx config written ==="

# ── Deploy Sample Web Application ─────────────────────────────────────────────
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scalable Web Application — AWS Architecture Demo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', system-ui, sans-serif;
      background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
    }
    .card {
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.2);
      border-radius: 24px;
      padding: 48px;
      max-width: 700px;
      text-align: center;
      box-shadow: 0 32px 64px rgba(0,0,0,0.4);
    }
    .badge {
      background: linear-gradient(135deg, #FF9900, #FF6600);
      color: white;
      padding: 8px 20px;
      border-radius: 50px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 1px;
      display: inline-block;
      margin-bottom: 24px;
    }
    h1 { font-size: 2.4rem; font-weight: 700; margin-bottom: 16px; }
    p { color: rgba(255,255,255,0.7); margin-bottom: 32px; line-height: 1.7; }
    .services {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
      margin-top: 24px;
    }
    .service {
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.15);
      border-radius: 12px;
      padding: 16px;
      font-size: 13px;
    }
    .service .icon { font-size: 24px; margin-bottom: 8px; }
    .service .name { font-weight: 600; color: #FF9900; }
    .instance-info {
      margin-top: 32px;
      background: rgba(0,0,0,0.3);
      border-radius: 12px;
      padding: 16px;
      font-size: 13px;
      color: rgba(255,255,255,0.6);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">🚀 AWS PRODUCTION DEPLOYMENT</div>
    <h1>Scalable Web Application</h1>
    <p>This application is running on a production-grade AWS architecture featuring Auto Scaling, Application Load Balancing, Multi-AZ RDS, CloudFront CDN, and WAF protection.</p>
    <div class="services">
      <div class="service"><div class="icon">🌐</div><div class="name">CloudFront</div><div>CDN + Cache</div></div>
      <div class="service"><div class="icon">🛡️</div><div class="name">WAF</div><div>OWASP Top 10</div></div>
      <div class="service"><div class="icon">⚖️</div><div class="name">ALB</div><div>Layer 7 Routing</div></div>
      <div class="service"><div class="icon">⚡</div><div class="name">EC2 + ASG</div><div>Auto Scaling</div></div>
      <div class="service"><div class="icon">🗄️</div><div class="name">RDS MySQL</div><div>MySQL 8.0</div></div>
      <div class="service"><div class="icon">📊</div><div class="name">CloudWatch</div><div>Monitoring</div></div>
    </div>
    <div class="instance-info">
      Served by EC2 Auto Scaling Group | Region: us-east-1 | Multi-AZ HA
    </div>
  </div>
</body>
</html>
HTMLEOF

echo "=== HTML deployed ==="

# ── CloudWatch Agent Config ───────────────────────────────────────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWEOF'
{
  "metrics": {
    "namespace": "ScalableWebApp/EC2",
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_user"], "metrics_collection_interval": 60 },
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": { "measurement": ["disk_used_percent"], "metrics_collection_interval": 60 }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/nginx/access.log", "log_group_name": "/scalable-web-app/nginx/access" },
          { "file_path": "/var/log/nginx/error.log", "log_group_name": "/scalable-web-app/nginx/error" }
        ]
      }
    }
  }
}
CWEOF

# Store DB connection info
cat > /etc/app.env <<ENVEOF
DB_HOST=${db_endpoint}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
ENVEOF
chmod 600 /etc/app.env

# ── Start Services ────────────────────────────────────────────────────────────
systemctl enable nginx
systemctl start nginx
echo "=== Nginx started: $(systemctl is-active nginx) ==="

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s || true

echo "=== User data script completed successfully $(date) ==="

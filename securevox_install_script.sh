#!/bin/bash
set -e

echo "🚀 Installazione SecureVox su Oracle Cloud"
echo "=========================================="

# Aggiorna il sistema
echo "📦 Aggiornando sistema..."
sudo apt update && sudo apt upgrade -y

# Installa Docker
echo "🐳 Installando Docker..."
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Installa dipendenze
echo "📚 Installando dipendenze..."
sudo apt install -y git curl wget python3 python3-pip nodejs npm

# Crea directory
mkdir -p /home/ubuntu/securevox
cd /home/ubuntu/securevox

# Crea docker-compose.yml per SecureVox
cat > docker-compose.yml << 'DOCKER_EOF'
version: '3.8'
services:
  securevox-backend:
    image: python:3.9-slim
    ports:
      - "8001:8001"
    volumes:
      - ./server:/app
    working_dir: /app
    command: >
      bash -c "
        pip install -r requirements.txt &&
        python manage.py migrate &&
        python manage.py runserver 0.0.0.0:8001
      "
    environment:
      - DEBUG=True
      - ALLOWED_HOSTS=*
      - SECRET_KEY=dev-secret-key-not-for-production
      - DATABASE_URL=sqlite:///db.sqlite3

  securevox-call:
    image: node:16-slim
    ports:
      - "8002:8002"
    volumes:
      - ./call-server:/app
    working_dir: /app
    command: >
      bash -c "
        npm install &&
        SECUREVOX_CALL_PORT=8002 JWT_SECRET=test-secret NODE_ENV=development HOST=0.0.0.0 MAIN_SERVER_URL=http://localhost:8001 NOTIFY_SERVER_URL=http://localhost:8003 node src/securevox-call-server.js
      "

  securevox-notify:
    image: python:3.9-slim
    ports:
      - "8003:8003"
    volumes:
      - ./server:/app
    working_dir: /app
    command: >
      bash -c "
        pip install fastapi uvicorn websockets &&
        python securevox_notify.py
      "
    environment:
      - DEBUG=True

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - securevox-backend
      - securevox-call
      - securevox-notify
DOCKER_EOF

# Crea nginx.conf
cat > nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server securevox-backend:8001;
    }
    
    upstream call_server {
        server securevox-call:8002;
    }
    
    upstream notify_server {
        server securevox-notify:8003;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /app-distribution/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /call/ {
            proxy_pass http://call_server/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /notify/ {
            proxy_pass http://notify_server/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF

echo "✅ Script di installazione creato"
echo "🌐 SecureVox sarà disponibile su:"
echo "   - Backend: http://$PUBLIC_IP:8001"
echo "   - Call Server: http://$PUBLIC_IP:8002"
echo "   - Notify Server: http://$PUBLIC_IP:8003"
echo "   - Nginx: http://$PUBLIC_IP"

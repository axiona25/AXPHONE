#!/bin/bash
set -e

echo "🚀 Installazione SecureVox Semplificata"
echo "======================================"

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
sudo apt install -y git curl wget python3 python3-pip nodejs npm nginx

# Crea directory
mkdir -p /home/ubuntu/securevox
cd /home/ubuntu/securevox

# Crea un server web semplice per test
cat > index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SecureVox - Installazione in Corso</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 500px;
        }
        .logo {
            font-size: 2rem;
            font-weight: bold;
            color: #333;
            margin-bottom: 1rem;
        }
        .status {
            color: #28a745;
            font-size: 1.2rem;
            margin-bottom: 1rem;
        }
        .info {
            color: #666;
            line-height: 1.6;
        }
        .progress {
            background: #f0f0f0;
            border-radius: 10px;
            height: 20px;
            margin: 1rem 0;
            overflow: hidden;
        }
        .progress-bar {
            background: linear-gradient(90deg, #667eea, #764ba2);
            height: 100%;
            width: 0%;
            animation: progress 3s ease-in-out infinite;
        }
        @keyframes progress {
            0% { width: 0%; }
            50% { width: 70%; }
            100% { width: 100%; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔐 SecureVox</div>
        <div class="status">✅ Server Attivo</div>
        <div class="progress">
            <div class="progress-bar"></div>
        </div>
        <div class="info">
            <p><strong>Installazione in corso...</strong></p>
            <p>Il server SecureVox è stato avviato con successo.</p>
            <p>I servizi saranno disponibili a breve su:</p>
            <ul style="text-align: left; display: inline-block;">
                <li>Backend: Porta 8001</li>
                <li>Call Server: Porta 8002</li>
                <li>Notify Server: Porta 8003</li>
            </ul>
        </div>
    </div>
</body>
</html>
HTML_EOF

# Configura Nginx
echo "🌐 Configurando Nginx..."
sudo tee /etc/nginx/sites-available/securevox << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    root /home/ubuntu/securevox;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api/ {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /app-distribution/ {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

sudo ln -sf /etc/nginx/sites-available/securevox /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
sudo systemctl enable nginx

# Crea un server Python semplice
cat > simple_server.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import os

class SecureVoxHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "message": "SecureVOX Django API",
                "status": "ok",
                "services": {
                    "backend": "http://localhost:8001",
                    "call_server": "http://localhost:8002",
                    "notify_server": "http://localhost:8003"
                }
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/app-distribution/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = '''
            <!DOCTYPE html>
            <html>
            <head><title>SecureVox App Distribution</title></head>
            <body>
                <h1>🔐 SecureVox App Distribution</h1>
                <p>Servizio in fase di installazione...</p>
                <p>Le app saranno disponibili a breve.</p>
            </body>
            </html>
            '''
            self.wfile.write(html.encode())
        else:
            super().do_GET()

if __name__ == "__main__":
    PORT = 8001
    with socketserver.TCPServer(("", PORT), SecureVoxHandler) as httpd:
        print(f"🚀 Server SecureVox avviato su porta {PORT}")
        httpd.serve_forever()
PYTHON_EOF

chmod +x simple_server.py

# Avvia il server in background
echo "🚀 Avviando server SecureVox..."
nohup python3 simple_server.py > server.log 2>&1 &

echo "✅ Installazione completata!"
echo "🌐 SecureVox disponibile su:"
echo "   - Web: http://$PUBLIC_IP"
echo "   - API: http://$PUBLIC_IP/api/"
echo "   - App Distribution: http://$PUBLIC_IP/app-distribution/"

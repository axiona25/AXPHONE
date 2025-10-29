#!/bin/bash

echo "🖥️ Installazione Desktop Remoto VNC"
echo "===================================="

# Variabili
INSTANCE_ID="ocid1.instance.oc1.eu-milan-1.anwgsljrqoeuthacollibbry4wd2muukk4ejtiul6tg6dw27o6rdavcj5v6q"
REGION="eu-milan-1"
PUBLIC_IP="130.110.3.186"

echo "📍 Istanza: $INSTANCE_ID"
echo "🌐 IP Pubblico: $PUBLIC_IP"
echo ""

# Crea script di installazione VNC
cat > install_vnc.sh << 'EOF'
#!/bin/bash
set -e

echo "🖥️ Installazione Desktop Remoto VNC"
echo "===================================="

# Aggiorna il sistema
echo "📦 Aggiornando sistema..."
sudo apt update && sudo apt upgrade -y

# Installa desktop environment
echo "🖥️ Installando desktop environment..."
sudo apt install -y ubuntu-desktop-minimal

# Installa VNC server
echo "🔌 Installando VNC server..."
sudo apt install -y tightvncserver

# Installa dipendenze aggiuntive
echo "📚 Installando dipendenze..."
sudo apt install -y xfce4 xfce4-goodies

# Crea utente per VNC
echo "👤 Configurando utente VNC..."
sudo useradd -m vncuser
sudo usermod -aG sudo vncuser
echo "vncuser:vncpassword" | sudo chpasswd

# Configura VNC
echo "⚙️ Configurando VNC..."
sudo -u vncuser mkdir -p /home/vncuser/.vnc
sudo -u vncuser vncpasswd -f <<< "vncpassword" > /home/vncuser/.vnc/passwd
sudo chmod 600 /home/vncuser/.vnc/passwd

# Crea script di avvio VNC
sudo tee /home/vncuser/.vnc/xstartup << 'VNC_EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
VNC_EOF

sudo chmod +x /home/vncuser/.vnc/xstartup
sudo chown -R vncuser:vncuser /home/vncuser/.vnc

# Crea servizio VNC
sudo tee /etc/systemd/system/vncserver@.service << 'SERVICE_EOF'
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=vncuser
Group=vncuser
WorkingDirectory=/home/vncuser

PIDFile=/home/vncuser/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Avvia servizio VNC
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1.service

# Installa NoVNC per accesso via browser
echo "🌐 Installando NoVNC..."
sudo apt install -y novnc websockify
sudo -u vncuser websockify -D --web=/usr/share/novnc/ 6080 localhost:5901

# Configura firewall
echo "🔥 Configurando firewall..."
sudo ufw allow 5901
sudo ufw allow 6080
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Installa SecureVox
echo "🚀 Installando SecureVox..."
cd /home/vncuser
git clone https://github.com/your-repo/securevox.git || mkdir -p securevox
cd securevox

# Crea server web semplice
cat > index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SecureVox - Desktop Remoto</title>
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
            max-width: 600px;
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
            margin-bottom: 1rem;
        }
        .button {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 5px;
            margin: 10px;
            font-weight: bold;
        }
        .button:hover {
            background: #5a6fd8;
        }
        .credentials {
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🖥️ SecureVox Desktop</div>
        <div class="status">✅ Desktop Remoto Attivo</div>
        
        <div class="info">
            <p><strong>Desktop remoto configurato con successo!</strong></p>
            <p>Puoi accedere al desktop remoto in due modi:</p>
        </div>

        <div class="credentials">
            <strong>Credenziali VNC:</strong><br>
            Username: vncuser<br>
            Password: vncpassword<br>
            Porta: 5901
        </div>

        <a href="http://localhost:6080/vnc.html" class="button" target="_blank">
            🌐 Apri Desktop via Browser
        </a>
        
        <a href="http://localhost:8001" class="button" target="_blank">
            🔐 SecureVox Web
        </a>

        <div class="info">
            <p><strong>Servizi disponibili:</strong></p>
            <ul style="text-align: left; display: inline-block;">
                <li>Desktop Remoto: Porta 6080 (Browser)</li>
                <li>VNC Direct: Porta 5901</li>
                <li>SecureVox Web: Porta 8001</li>
                <li>SSH: Porta 22</li>
            </ul>
        </div>
    </div>
</body>
</html>
HTML_EOF

# Avvia server web
python3 -m http.server 8001 &
echo "✅ Server web avviato su porta 8001"

echo "✅ Installazione completata!"
echo ""
echo "🌐 Accesso Desktop Remoto:"
echo "   - Browser: http://$PUBLIC_IP:6080/vnc.html"
echo "   - VNC Direct: $PUBLIC_IP:5901"
echo "   - Web: http://$PUBLIC_IP:8001"
echo ""
echo "🔑 Credenziali:"
echo "   - Username: vncuser"
echo "   - Password: vncpassword"
EOF

echo "✅ Script VNC creato"
echo ""
echo "🎯 PROSSIMI PASSI:"
echo "=================="
echo "1. Vai su https://cloud.oracle.com"
echo "2. Accedi con le tue credenziali"
echo "3. Vai su Compute → Instances"
echo "4. Clicca su 'securevox-production-new'"
echo "5. Cerca 'Console' o 'Terminal' nella pagina"
echo "6. Se non trovi la console, prova a cercare 'Launch Console' o 'VNC Console'"
echo "7. Una volta nella console, esegui:"
echo "   wget https://raw.githubusercontent.com/your-repo/install_vnc.sh"
echo "   chmod +x install_vnc.sh"
echo "   ./install_vnc.sh"
echo ""
echo "🌐 Dopo l'installazione, potrai accedere al desktop remoto su:"
echo "   - http://$PUBLIC_IP:6080/vnc.html"
echo "   - Username: vncuser"
echo "   - Password: vncpassword"

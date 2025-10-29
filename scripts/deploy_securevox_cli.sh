#!/bin/bash

echo "🚀 Deploy Automatico SecureVox via OCI CLI"
echo "=========================================="

# Variabili
INSTANCE_ID="ocid1.instance.oc1.eu-milan-1.anwgsljrqoeuthacollibbry4wd2muukk4ejtiul6tg6dw27o6rdavcj5v6q"
REGION="eu-milan-1"
PUBLIC_IP="130.110.3.186"
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaa4mih7gc5nndai7ysnb34rhfxzf3mekc6qe3f4phoi2jnxxsxtw2q"

echo "📍 Istanza: $INSTANCE_ID"
echo "🌐 IP Pubblico: $PUBLIC_IP"
echo ""

# 1. Crea uno script di installazione
echo "📝 Creando script di installazione..."
cat > securevox_install_script.sh << 'EOF'
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
EOF

# 2. Crea un volume di boot personalizzato
echo "💾 Creando volume di boot personalizzato..."

# Prima crea un'immagine personalizzata
echo "📸 Creando immagine personalizzata..."

# Crea un'istanza temporanea per preparare l'immagine
echo "🔄 Creando istanza temporanea per preparare l'immagine..."
oci compute instance launch \
  --availability-domain gKhW:EU-MILAN-1-AD-1 \
  --compartment-id $COMPARTMENT_ID \
  --shape VM.Standard.E2.1.Micro \
  --image-id ocid1.image.oc1.eu-milan-1.aaaaaaaalpc3px3jykr6zs6z4iouadyh4xfzpi7f4phoi2jnxxsxtw2q \
  --subnet-id ocid1.subnet.oc1.eu-milan-1.aaaaaaaadn5slnfsez65yevsna7sxdrkokytrswqopp2vuuq4yila4u7s6uq \
  --assign-public-ip true \
  --display-name securevox-temp \
  --region $REGION \
  --metadata '{"ssh_authorized_keys": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCdhgTKlCoF4jYJYg/iyrmNzJ+MhEZhve9AqFzUqY0Vy2k9RSl28QBeOFR0ygY/FdC2eatsfMeuMHZojQZt8J8DFO2uMzdPkEOi26/q81bPUfLZLD/ImRc62GYlpbaxqqjvoAqfNKRpKaD5eSQgAMPFuSZMF1e3ohTHgiwaYEU1+XUdYWfOFGL3sVqmwortyABgnQd4JHglcuSUW3lxGRdYtvHjB69rB678gyUuNUCinzDgoE7/3g7lSftvvEBPBarrtFRrpHWlRNlkjNji+kY0XkZqckD8e9ZBrpOBawI9OsX/JCg+coyKeE2UWTKwmf8CYZnavDicgvCFKOFJUmln r.amoroso@MacBook-Pro-di-Raffaele.local"}' \
  --wait-for-state RUNNING

echo "✅ Istanza temporanea creata"

# Aspetta che l'istanza sia pronta
echo "⏳ Aspettando che l'istanza sia pronta..."
sleep 60

# Ottieni l'IP dell'istanza temporanea
TEMP_IP=$(oci compute instance list-vnics --instance-id $(oci compute instance list --compartment-id $COMPARTMENT_ID --region $REGION --query "data[?display-name=='securevox-temp'].id" --raw-output) --region $REGION --query "data[0].\"public-ip\"" --raw-output)

echo "🌐 IP Istanza temporanea: $TEMP_IP"

# Prova a connetterti all'istanza temporanea
echo "🔌 Tentativo di connessione SSH all'istanza temporanea..."
if ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.oci/oci_api_key_final ubuntu@$TEMP_IP "echo 'SSH Connection Test'"; then
    echo "✅ Connessione SSH riuscita!"
    
    # Copia lo script di installazione
    echo "📤 Copiando script di installazione..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.oci/oci_api_key_final securevox_install_script.sh ubuntu@$TEMP_IP:/home/ubuntu/
    
    # Esegui lo script di installazione
    echo "🚀 Eseguendo script di installazione..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.oci/oci_api_key_final ubuntu@$TEMP_IP "chmod +x securevox_install_script.sh && ./securevox_install_script.sh"
    
    echo "✅ Installazione completata!"
    echo "🌐 SecureVox disponibile su: http://$TEMP_IP"
    
else
    echo "❌ Connessione SSH fallita. Usa la console del browser:"
    echo "1. Vai su https://cloud.oracle.com"
    echo "2. Accedi con le tue credenziali"
    echo "3. Vai su Compute → Instances"
    echo "4. Clicca su 'securevox-temp'"
    echo "5. Clicca su 'Console' per accedere via browser"
fi

echo ""
echo "🎯 PROSSIMI PASSI:"
echo "=================="
echo "1. Verifica che l'installazione sia completata"
echo "2. Testa l'accesso a http://$TEMP_IP"
echo "3. Se funziona, puoi terminare l'istanza temporanea"
echo "4. Configura il dominio www.securevox.it per puntare a $TEMP_IP"

#!/bin/bash

# Build script per SecureVOX Admin Dashboard
echo "🛡️ Building SecureVOX Admin Dashboard..."

# Vai nella directory admin
cd admin

# Installa le dipendenze se necessario
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build della dashboard
echo "🔨 Building dashboard..."
npm run build

# Verifica che il build sia stato completato
if [ -d "build" ]; then
    echo "✅ Build completata con successo!"
    echo "📁 File di build disponibili in: admin/build/"
    
    # Mostra le dimensioni dei file
    echo "📊 Dimensioni dei file di build:"
    du -sh build/*
    
    echo ""
    echo "🚀 La dashboard è pronta per essere servita!"
    echo "💡 Usa ./start_server_8001.sh per avviare il server Django"
else
    echo "❌ Errore durante il build!"
    exit 1
fi

cd ..

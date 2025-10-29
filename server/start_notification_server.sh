#!/bin/bash

echo "🚀 Avvio SecureVOX Notify..."

# Controlla se Python è installato
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trovato. Installa Python3 prima di continuare."
    exit 1
fi

# Controlla se l'ambiente virtuale esiste
if [ ! -d "venv" ]; then
    echo "📦 Creazione ambiente virtuale..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "❌ Errore nella creazione dell'ambiente virtuale."
        exit 1
    fi
fi

# Attiva l'ambiente virtuale
echo "🔧 Attivazione ambiente virtuale..."
source venv/bin/activate

# Controlla se il file requirements.txt esiste
if [ ! -f "notification_requirements.txt" ]; then
    echo "❌ File notification_requirements.txt non trovato."
    exit 1
fi

echo "📦 Controllo dipendenze..."
pip install -r notification_requirements.txt

if [ $? -ne 0 ]; then
    echo "❌ Errore nell'installazione delle dipendenze."
    exit 1
fi

echo "✅ Dipendenze installate con successo"
echo ""
echo "🔥 Avvio server su http://localhost:8002"
echo "📡 WebSocket disponibile su ws://localhost:8002/ws/{device_token}"
echo "📱 Supporta iOS, Android e Web"
echo ""
echo "Premi Ctrl+C per fermare il server"
echo ""

python securevox_notify.py

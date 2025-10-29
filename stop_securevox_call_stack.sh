#!/bin/bash

# SecureVOX Call Stack Shutdown Script

echo "🛑 Stopping SecureVOX Call Stack..."

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Leggi PID salvati
if [ -f .securevox_call_pids ]; then
    PIDS=$(cat .securevox_call_pids)
    echo -e "${YELLOW}🔄 Stopping saved processes: $PIDS${NC}"
    kill $PIDS 2>/dev/null
    rm -f .securevox_call_pids
fi

# Kill processi su porte specifiche
echo -e "${YELLOW}🔄 Killing processes on ports 8001, 8002...${NC}"
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
lsof -ti:8002 | xargs kill -9 2>/dev/null || true

# Kill processi Node.js e Python relativi a SecureVOX
echo -e "${YELLOW}🔄 Cleaning up SecureVOX processes...${NC}"
pkill -f "securevox-call-server.js" 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true

sleep 2

# Verifica che tutto sia fermato
if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${RED}⚠️ Port 8001 still in use${NC}"
else
    echo -e "${GREEN}✅ Port 8001 free${NC}"
fi

if lsof -Pi :8002 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${RED}⚠️ Port 8002 still in use${NC}"
else
    echo -e "${GREEN}✅ Port 8002 free${NC}"
fi

echo -e "${GREEN}✅ SecureVOX Call Stack stopped${NC}"

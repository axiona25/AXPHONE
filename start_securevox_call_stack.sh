#!/bin/bash

# SecureVOX Call Stack Startup Script
# Avvia tutti i servizi necessari per testare le chiamate reali

echo "🚀 Starting SecureVOX Call Stack..."

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per verificare se una porta è in uso
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        return 0
    else
        return 1
    fi
}

# Funzione per killare processi su una porta
kill_port() {
    local port=$1
    echo -e "${YELLOW}🔄 Killing processes on port $port...${NC}"
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
    sleep 1
}

# Cleanup eventuali processi precedenti
echo -e "${YELLOW}🧹 Cleaning up previous processes...${NC}"
kill_port 8001
kill_port 8002

# 1. Avvia Django Backend
echo -e "${BLUE}📊 Starting Django Backend (port 8001)...${NC}"
cd server
python manage.py runserver 0.0.0.0:8001 &
DJANGO_PID=$!
cd ..

# Attendi che Django sia pronto
echo -e "${YELLOW}⏳ Waiting for Django backend...${NC}"
for i in {1..30}; do
    if check_port 8001; then
        echo -e "${GREEN}✅ Django backend ready on port 8001${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Django backend failed to start${NC}"
        exit 1
    fi
done

# 2. Avvia SecureVOX Call Server
echo -e "${BLUE}📞 Starting SecureVOX Call Server (port 8002)...${NC}"
cd call-server
npm start &
CALL_SERVER_PID=$!
cd ..

# Attendi che Call Server sia pronto
echo -e "${YELLOW}⏳ Waiting for SecureVOX Call Server...${NC}"
for i in {1..30}; do
    if check_port 8002; then
        echo -e "${GREEN}✅ SecureVOX Call Server ready on port 8002${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ SecureVOX Call Server failed to start${NC}"
        kill $DJANGO_PID 2>/dev/null
        exit 1
    fi
done

# 3. Test health checks
echo -e "${BLUE}🏥 Testing health checks...${NC}"

# Test Django
DJANGO_HEALTH=$(curl -s http://localhost:8001/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Django backend healthy${NC}"
else
    echo -e "${RED}❌ Django backend health check failed${NC}"
fi

# Test Call Server
CALL_HEALTH=$(curl -s http://localhost:8002/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SecureVOX Call Server healthy${NC}"
    echo "   $(echo $CALL_HEALTH | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"Service: {data.get('service')}, Active calls: {data.get('activeCalls')}\")" 2>/dev/null || echo "Raw: $CALL_HEALTH")"
else
    echo -e "${RED}❌ SecureVOX Call Server health check failed${NC}"
fi

# 4. Informazioni per testing
echo -e "\n${GREEN}🎉 SecureVOX Call Stack is running!${NC}"
echo -e "${BLUE}📋 Services:${NC}"
echo "   🖥️  Django Backend:        http://localhost:8001"
echo "   📞 SecureVOX Call Server: http://localhost:8002"
echo ""
echo -e "${BLUE}🧪 To test:${NC}"
echo "   1. Open Flutter app: cd mobile/securevox_app && flutter run"
echo "   2. Login with test user: $TEST_USER_EMAIL"
echo "   3. Make a call to another user"
echo "   4. Check real audio/video communication!"
echo ""
echo -e "${BLUE}📊 Monitoring:${NC}"
echo "   • Django health:     curl http://localhost:8001/health"
echo "   • Call server health: curl http://localhost:8002/health"
echo "   • Call server stats:  curl http://localhost:8002/api/call/stats"
echo ""
echo -e "${YELLOW}⚠️  To stop all services:${NC}"
echo "   kill $DJANGO_PID $CALL_SERVER_PID"
echo "   or press Ctrl+C and run: ./stop_securevox_call_stack.sh"

# Salva PID per cleanup
echo "$DJANGO_PID $CALL_SERVER_PID" > .securevox_call_pids

# Attendi interruzione
trap 'echo -e "\n${YELLOW}🛑 Shutting down SecureVOX Call Stack...${NC}"; kill $DJANGO_PID $CALL_SERVER_PID 2>/dev/null; rm -f .securevox_call_pids; exit 0' INT

echo -e "${GREEN}🚀 Press Ctrl+C to stop all services${NC}"
wait

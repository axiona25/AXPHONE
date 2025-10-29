# SecureVOX Call Server - Dockerfile
FROM node:18-alpine

# Metadata
LABEL maintainer="SecureVOX Team"
LABEL description="SecureVOX Call - Proprietary WebRTC signaling server"
LABEL version="1.0.0"

# Crea directory di lavoro
WORKDIR /app

# Copia package files
COPY package*.json ./

# Installa dipendenze
RUN npm ci --only=production && npm cache clean --force

# Crea utente non-root per sicurezza
RUN addgroup -g 1001 -S securevox && \
    adduser -S securevox -u 1001

# Copia codice sorgente
COPY src/ ./src/

# Cambia ownership
RUN chown -R securevox:securevox /app
USER securevox

# Esponi porta
EXPOSE 8002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); \
    const options = { hostname: 'localhost', port: 8002, path: '/health', timeout: 2000 }; \
    const req = http.request(options, (res) => { \
        if (res.statusCode === 200) process.exit(0); else process.exit(1); \
    }); \
    req.on('error', () => process.exit(1)); \
    req.on('timeout', () => process.exit(1)); \
    req.end();"

# Variabili ambiente di default
ENV NODE_ENV=production
ENV SECUREVOX_CALL_PORT=8002
ENV DJANGO_BACKEND_URL=http://localhost:8001

# Avvia server
CMD ["npm", "start"]

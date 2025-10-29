#!/usr/bin/env node

/**
 * SecureVOX Call Server
 * Signaling server proprietario per chiamate audio/video WebRTC
 * Alternativa self-hosted ad Agora/Twilio
 */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const fetch = require('node-fetch');

class SecureVOXCallServer {
    constructor() {
        this.app = express();
        this.server = http.createServer(this.app);
        this.io = socketIo(this.server, {
            cors: {
                origin: "*", // TODO: Configurare per produzione
                methods: ["GET", "POST"]
            }
        });
        
        // Stato del server
        this.activeCalls = new Map(); // sessionId -> callData
        this.userSockets = new Map(); // userId -> socketId
        this.socketUsers = new Map(); // socketId -> userId
        
        // Configurazione
        this.JWT_SECRET = process.env.SECUREVOX_CALL_JWT_SECRET || 'securevox-call-secret-2024';
        this.PORT = process.env.SECUREVOX_CALL_PORT || 8002;
        this.DJANGO_BACKEND = process.env.DJANGO_BACKEND_URL || 'http://localhost:8000';
        
        this.setupMiddleware();
        this.setupRoutes();
        this.setupWebSocketHandlers();
        
        console.log('🚀 SecureVOX Call Server initializing...');
    }
    
    setupMiddleware() {
        this.app.use(cors());
        this.app.use(express.json());
        
        // Logging middleware
        this.app.use((req, res, next) => {
            console.log(`📞 ${new Date().toISOString()} - ${req.method} ${req.path}`);
            next();
        });
    }
    
    setupRoutes() {
        // Health check
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                service: 'SecureVOX Call Server',
                version: '1.0.0',
                timestamp: new Date().toISOString(),
                activeCalls: this.activeCalls.size,
                connectedUsers: this.userSockets.size
            });
        });
        
        // Genera token di accesso per le chiamate
        this.app.post('/api/call/token', this.authenticateRequest.bind(this), (req, res) => {
            const { userId, sessionId, role } = req.body;
            
            if (!userId || !sessionId) {
                return res.status(400).json({ error: 'userId and sessionId required' });
            }
            
            const token = this.generateCallToken(userId, sessionId, role);
            
            res.json({
                token,
                expires_in: 3600, // 1 ora
                ice_servers: this.getIceServers()
            });
        });
        
        // Statistiche chiamate attive
        this.app.get('/api/call/stats', this.authenticateRequest.bind(this), (req, res) => {
            const stats = {
                activeCalls: Array.from(this.activeCalls.values()).map(call => ({
                    sessionId: call.sessionId,
                    participants: call.participants.length,
                    startTime: call.startTime,
                    duration: Date.now() - call.startTime
                })),
                totalActiveCalls: this.activeCalls.size,
                connectedUsers: this.userSockets.size,
                serverUptime: process.uptime()
            };
            
            res.json(stats);
        });
    }
    
    setupWebSocketHandlers() {
        this.io.on('connection', (socket) => {
            console.log(`🔌 Client connected: ${socket.id}`);
            
            // Autenticazione WebSocket
            socket.on('authenticate', (data) => {
                this.handleAuthentication(socket, data);
            });
            
            // Gestione chiamate
            socket.on('join_call', (data) => {
                this.handleJoinCall(socket, data);
            });
            
            socket.on('leave_call', (data) => {
                this.handleLeaveCall(socket, data);
            });
            
            // Signaling WebRTC
            socket.on('offer', (data) => {
                this.handleOffer(socket, data);
            });
            
            socket.on('answer', (data) => {
                this.handleAnswer(socket, data);
            });
            
            socket.on('ice_candidate', (data) => {
                this.handleIceCandidate(socket, data);
            });
            
            // Controlli chiamata
            socket.on('mute_audio', (data) => {
                this.handleMuteAudio(socket, data);
            });
            
            socket.on('mute_video', (data) => {
                this.handleMuteVideo(socket, data);
            });
            
            // Disconnessione
            socket.on('disconnect', () => {
                this.handleDisconnection(socket);
            });
        });
    }
    
    // Autentica richieste HTTP con Django backend
    async authenticateRequest(req, res, next) {
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Token ')) {
            return res.status(401).json({ error: 'Authentication required' });
        }
        
        const token = authHeader.substring(6);
        
        try {
            // Verifica token con Django backend
            const response = await fetch(`${this.DJANGO_BACKEND}/api/auth/verify-token/`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Token ${token}`
                }
            });
            
            if (!response.ok) {
                return res.status(401).json({ error: 'Invalid token' });
            }
            
            const userData = await response.json();
            req.user = userData;
            next();
            
        } catch (error) {
            console.error('❌ Token verification error:', error);
            res.status(500).json({ error: 'Authentication service unavailable' });
        }
    }
    
    // Gestisce autenticazione WebSocket
    handleAuthentication(socket, data) {
        const { token, userId } = data;
        
        try {
            // Verifica token JWT per chiamate
            const decoded = jwt.verify(token, this.JWT_SECRET);
            
            if (decoded.userId !== userId) {
                socket.emit('auth_error', { error: 'Token mismatch' });
                return;
            }
            
            // Associa socket all'utente
            this.userSockets.set(userId, socket.id);
            this.socketUsers.set(socket.id, userId);
            
            socket.emit('authenticated', { 
                userId,
                sessionId: decoded.sessionId 
            });
            
            console.log(`✅ User ${userId} authenticated on socket ${socket.id}`);
            
        } catch (error) {
            console.error('❌ WebSocket auth error:', error);
            socket.emit('auth_error', { error: 'Invalid token' });
        }
    }
    
    // Gestisce ingresso in chiamata
    handleJoinCall(socket, data) {
        const { sessionId, userId } = data;
        const socketUserId = this.socketUsers.get(socket.id);
        
        if (!socketUserId || socketUserId !== userId) {
            socket.emit('call_error', { error: 'Not authenticated' });
            return;
        }
        
        // Crea o recupera chiamata
        let call = this.activeCalls.get(sessionId);
        if (!call) {
            call = {
                sessionId,
                participants: [],
                startTime: Date.now(),
                createdBy: userId
            };
            this.activeCalls.set(sessionId, call);
            console.log(`📞 New call created: ${sessionId}`);
        }
        
        // Aggiungi partecipante
        const participant = {
            userId,
            socketId: socket.id,
            joinedAt: Date.now(),
            audioMuted: false,
            videoMuted: false
        };
        
        call.participants.push(participant);
        socket.join(sessionId);
        
        // Notifica altri partecipanti
        socket.to(sessionId).emit('participant_joined', {
            participant: {
                userId: participant.userId,
                joinedAt: participant.joinedAt
            }
        });
        
        // Invia lista partecipanti al nuovo utente
        socket.emit('call_joined', {
            sessionId,
            participants: call.participants.map(p => ({
                userId: p.userId,
                joinedAt: p.joinedAt,
                audioMuted: p.audioMuted,
                videoMuted: p.videoMuted
            }))
        });
        
        console.log(`👥 User ${userId} joined call ${sessionId} (${call.participants.length} participants)`);
        
        // Notifica Django backend
        this.notifyDjangoCallUpdate(sessionId, 'participant_joined', { userId });
    }
    
    // Gestisce uscita da chiamata
    handleLeaveCall(socket, data) {
        const { sessionId, userId } = data;
        const call = this.activeCalls.get(sessionId);
        
        if (!call) return;
        
        // Rimuovi partecipante
        call.participants = call.participants.filter(p => p.userId !== userId);
        socket.leave(sessionId);
        
        // Notifica altri partecipanti
        socket.to(sessionId).emit('participant_left', { userId });
        
        // Se non ci sono più partecipanti, rimuovi chiamata
        if (call.participants.length === 0) {
            this.activeCalls.delete(sessionId);
            console.log(`📞 Call ${sessionId} ended (no participants)`);
            this.notifyDjangoCallUpdate(sessionId, 'call_ended', { reason: 'no_participants' });
        }
        
        console.log(`👋 User ${userId} left call ${sessionId}`);
        this.notifyDjangoCallUpdate(sessionId, 'participant_left', { userId });
    }
    
    // Gestisce WebRTC offer
    handleOffer(socket, data) {
        const { sessionId, targetUserId, offer } = data;
        const targetSocketId = this.userSockets.get(targetUserId);
        
        if (targetSocketId) {
            this.io.to(targetSocketId).emit('offer', {
                sessionId,
                fromUserId: this.socketUsers.get(socket.id),
                offer
            });
            console.log(`📡 Offer relayed from ${this.socketUsers.get(socket.id)} to ${targetUserId}`);
        }
    }
    
    // Gestisce WebRTC answer
    handleAnswer(socket, data) {
        const { sessionId, targetUserId, answer } = data;
        const targetSocketId = this.userSockets.get(targetUserId);
        
        if (targetSocketId) {
            this.io.to(targetSocketId).emit('answer', {
                sessionId,
                fromUserId: this.socketUsers.get(socket.id),
                answer
            });
            console.log(`📡 Answer relayed from ${this.socketUsers.get(socket.id)} to ${targetUserId}`);
        }
    }
    
    // Gestisce ICE candidates
    handleIceCandidate(socket, data) {
        const { sessionId, targetUserId, candidate } = data;
        const targetSocketId = this.userSockets.get(targetUserId);
        
        if (targetSocketId) {
            this.io.to(targetSocketId).emit('ice_candidate', {
                sessionId,
                fromUserId: this.socketUsers.get(socket.id),
                candidate
            });
        }
    }
    
    // Gestisce mute audio
    handleMuteAudio(socket, data) {
        const { sessionId, muted } = data;
        const userId = this.socketUsers.get(socket.id);
        const call = this.activeCalls.get(sessionId);
        
        if (call) {
            const participant = call.participants.find(p => p.userId === userId);
            if (participant) {
                participant.audioMuted = muted;
                socket.to(sessionId).emit('participant_audio_muted', { userId, muted });
            }
        }
    }
    
    // Gestisce mute video
    handleMuteVideo(socket, data) {
        const { sessionId, muted } = data;
        const userId = this.socketUsers.get(socket.id);
        const call = this.activeCalls.get(sessionId);
        
        if (call) {
            const participant = call.participants.find(p => p.userId === userId);
            if (participant) {
                participant.videoMuted = muted;
                socket.to(sessionId).emit('participant_video_muted', { userId, muted });
            }
        }
    }
    
    // Gestisce disconnessione
    handleDisconnection(socket) {
        const userId = this.socketUsers.get(socket.id);
        
        if (userId) {
            // Rimuovi da tutte le chiamate attive
            for (const [sessionId, call] of this.activeCalls.entries()) {
                const participantIndex = call.participants.findIndex(p => p.userId === userId);
                if (participantIndex !== -1) {
                    call.participants.splice(participantIndex, 1);
                    socket.to(sessionId).emit('participant_left', { userId });
                    
                    if (call.participants.length === 0) {
                        this.activeCalls.delete(sessionId);
                        this.notifyDjangoCallUpdate(sessionId, 'call_ended', { reason: 'all_disconnected' });
                    }
                }
            }
            
            // Pulisci mappature
            this.userSockets.delete(userId);
            this.socketUsers.delete(socket.id);
        }
        
        console.log(`🔌 Client disconnected: ${socket.id}`);
    }
    
    // Genera token JWT per le chiamate
    generateCallToken(userId, sessionId, role = 'participant') {
        const payload = {
            userId,
            sessionId,
            role,
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + 3600 // 1 ora
        };
        
        return jwt.sign(payload, this.JWT_SECRET);
    }
    
    // Restituisce server ICE (STUN/TURN)
    getIceServers() {
        return [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' },
            // TODO: Aggiungere TURN server proprietario
        ];
    }
    
    // Notifica Django backend degli aggiornamenti chiamate
    async notifyDjangoCallUpdate(sessionId, event, data) {
        try {
            await fetch(`${this.DJANGO_BACKEND}/api/webrtc/calls/update-from-signaling/`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-SecureVOX-Call-Secret': this.JWT_SECRET
                },
                body: JSON.stringify({
                    sessionId,
                    event,
                    data,
                    timestamp: new Date().toISOString()
                })
            });
        } catch (error) {
            console.error('❌ Failed to notify Django backend:', error);
        }
    }
    
    start() {
        this.server.listen(this.PORT, () => {
            console.log('🚀 SecureVOX Call Server started');
            console.log(`📞 Signaling server: http://localhost:${this.PORT}`);
            console.log(`🔗 Django backend: ${this.DJANGO_BACKEND}`);
            console.log(`👥 Ready for WebRTC calls!`);
        });
    }
}

// Avvia server
const callServer = new SecureVOXCallServer();
callServer.start();

// Gestione graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 SecureVOX Call Server shutting down...');
    process.exit(0);
});

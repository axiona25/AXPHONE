/**
 * SecureVox Signaling Service con Crittografia E2E
 * Gestisce lo scambio SDP/ICE per WebRTC con supporto SFrame encryption
 */

const logger = require('../utils/logger');
const crypto = require('crypto');

class SignalingService {
  constructor(io, callManager) {
    this.io = io;
    this.callManager = callManager;
    this.activeCalls = new Map(); // sessionId -> call data
    this.userSockets = new Map(); // userId -> socket
    this.encryptedCalls = new Map(); // sessionId -> encryption info
  }

  /**
   * Gestisce nuova connessione WebSocket
   */
  handleConnection(socket) {
    const userId = socket.userId;
    
    // Registra socket per l'utente
    this.userSockets.set(userId, socket);
    
    logger.info(`🔌 SignalingService - User ${userId} connected via WebSocket`);

    // === EVENTI SIGNALING ===
    
    // Offer SDP
    socket.on('webrtc:offer', (data) => {
      this.handleOffer(socket, data);
    });

    // Answer SDP
    socket.on('webrtc:answer', (data) => {
      this.handleAnswer(socket, data);
    });

    // ICE Candidate
    socket.on('webrtc:ice-candidate', (data) => {
      this.handleIceCandidate(socket, data);
    });

    // Avvio chiamata
    socket.on('call:start', (data) => {
      this.handleCallStart(socket, data);
    });

    // Risposta chiamata
    socket.on('call:answer', (data) => {
      this.handleCallAnswer(socket, data);
    });

    // Rifiuto chiamata
    socket.on('call:reject', (data) => {
      this.handleCallReject(socket, data);
    });

    // Termine chiamata
    socket.on('call:end', (data) => {
      this.handleCallEnd(socket, data);
    });

    // Eventi crittografia E2E
    socket.on('encryption:key-exchange', (data) => {
      this.handleKeyExchange(socket, data);
    });

    socket.on('encryption:key-rotation', (data) => {
      this.handleKeyRotation(socket, data);
    });

    // Heartbeat per mantenere connessione
    socket.on('ping', () => {
      socket.emit('pong');
    });

    logger.info(`✅ SignalingService - Event handlers registered for user ${userId}`);
  }

  /**
   * Gestisce disconnessione WebSocket
   */
  handleDisconnection(socket) {
    const userId = socket.userId;
    
    // Rimuovi socket dell'utente
    this.userSockets.delete(userId);
    
    // Termina chiamate attive dell'utente
    this.endUserCalls(userId);
    
    logger.info(`🔌 SignalingService - User ${userId} disconnected`);
  }

  /**
   * Gestisce avvio chiamata
   */
  async handleCallStart(socket, data) {
    try {
      const { calleeId, callType, sessionId } = data;
      const callerId = socket.userId;

      logger.info(`📞 Call Start: ${callerId} -> ${calleeId} (${callType})`);

      // Verifica che il destinatario sia online
      const calleeSocket = this.userSockets.get(calleeId);
      if (!calleeSocket) {
        socket.emit('call:error', {
          error: 'USER_OFFLINE',
          message: 'Il destinatario non è online'
        });
        return;
      }

      // Crea record della chiamata con crittografia E2E
      const callData = {
        sessionId,
        callerId,
        calleeId,
        callType,
        status: 'ringing',
        startTime: new Date(),
        callerSocket: socket,
        calleeSocket: calleeSocket,
        encrypted: true,
        encryptionAlgorithm: 'SFrame-AES-GCM-256'
      };

      // Setup crittografia per la chiamata
      this.setupCallEncryption(sessionId, callerId, calleeId);

      this.activeCalls.set(sessionId, callData);

      // Notifica chiamata in arrivo al destinatario
      calleeSocket.emit('call:incoming', {
        sessionId,
        callerId,
        callerName: await this.getUserName(callerId),
        callType,
        timestamp: new Date().toISOString()
      });

      // Conferma al chiamante
      socket.emit('call:outgoing', {
        sessionId,
        calleeId,
        status: 'ringing'
      });

      // Timeout per chiamata non risposta (30 secondi)
      setTimeout(() => {
        this.handleCallTimeout(sessionId);
      }, 30000);

      logger.info(`✅ Call initiated: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ Call start error: ${error.message}`);
      socket.emit('call:error', {
        error: 'CALL_START_FAILED',
        message: 'Impossibile avviare la chiamata'
      });
    }
  }

  /**
   * Gestisce risposta alla chiamata
   */
  async handleCallAnswer(socket, data) {
    try {
      const { sessionId } = data;
      const calleeId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData || callData.calleeId !== calleeId) {
        socket.emit('call:error', {
          error: 'INVALID_SESSION',
          message: 'Sessione di chiamata non valida'
        });
        return;
      }

      // Aggiorna stato chiamata
      callData.status = 'connecting';
      callData.answerTime = new Date();

      // Notifica il chiamante che la chiamata è stata accettata
      callData.callerSocket.emit('call:answered', {
        sessionId,
        calleeId,
        status: 'connecting'
      });

      // Conferma al destinatario
      socket.emit('call:answer-sent', {
        sessionId,
        status: 'connecting'
      });

      logger.info(`✅ Call answered: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ Call answer error: ${error.message}`);
      socket.emit('call:error', {
        error: 'CALL_ANSWER_FAILED',
        message: 'Impossibile rispondere alla chiamata'
      });
    }
  }

  /**
   * Gestisce rifiuto chiamata
   */
  async handleCallReject(socket, data) {
    try {
      const { sessionId } = data;
      const calleeId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData || callData.calleeId !== calleeId) {
        return;
      }

      // Notifica il chiamante del rifiuto
      callData.callerSocket.emit('call:rejected', {
        sessionId,
        calleeId,
        reason: 'declined'
      });

      // Rimuovi chiamata
      this.activeCalls.delete(sessionId);

      logger.info(`❌ Call rejected: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ Call reject error: ${error.message}`);
    }
  }

  /**
   * Gestisce termine chiamata
   */
  async handleCallEnd(socket, data) {
    try {
      const { sessionId } = data;
      const userId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData) {
        return;
      }

      // Determina l'altro partecipante
      const otherSocket = callData.callerId === userId 
        ? callData.calleeSocket 
        : callData.callerSocket;

      // Notifica l'altro partecipante
      if (otherSocket && otherSocket.connected) {
        otherSocket.emit('call:ended', {
          sessionId,
          endedBy: userId,
          reason: 'user_ended'
        });
      }

      // Calcola durata chiamata
      const duration = callData.answerTime 
        ? new Date() - callData.answerTime 
        : 0;

      // Salva statistiche chiamata
      await this.saveCallStats(sessionId, {
        duration,
        endTime: new Date(),
        endedBy: userId
      });

      // Pulisci dati crittografia
      this.cleanupCallEncryption(sessionId);

      // Rimuovi chiamata
      this.activeCalls.delete(sessionId);

      logger.info(`✅ Call ended: ${sessionId} (duration: ${duration}ms)`);

    } catch (error) {
      logger.error(`❌ Call end error: ${error.message}`);
    }
  }

  /**
   * Gestisce SDP Offer
   */
  handleOffer(socket, data) {
    try {
      const { sessionId, sdp } = data;
      const callerId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData || callData.callerId !== callerId) {
        socket.emit('signaling:error', {
          error: 'INVALID_SESSION',
          message: 'Sessione non valida per offer'
        });
        return;
      }

      // Inoltra offer al destinatario
      callData.calleeSocket.emit('webrtc:offer', {
        sessionId,
        sdp,
        callerId
      });

      logger.info(`📤 SDP Offer forwarded: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ Offer handling error: ${error.message}`);
    }
  }

  /**
   * Gestisce SDP Answer
   */
  handleAnswer(socket, data) {
    try {
      const { sessionId, sdp } = data;
      const calleeId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData || callData.calleeId !== calleeId) {
        socket.emit('signaling:error', {
          error: 'INVALID_SESSION',
          message: 'Sessione non valida per answer'
        });
        return;
      }

      // Aggiorna stato a connesso
      callData.status = 'connected';
      callData.connectTime = new Date();

      // Inoltra answer al chiamante
      callData.callerSocket.emit('webrtc:answer', {
        sessionId,
        sdp,
        calleeId
      });

      logger.info(`📤 SDP Answer forwarded: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ Answer handling error: ${error.message}`);
    }
  }

  /**
   * Gestisce ICE Candidate
   */
  handleIceCandidate(socket, data) {
    try {
      const { sessionId, candidate } = data;
      const userId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      if (!callData) {
        return; // Sessione non trovata, ignora
      }

      // Determina il destinatario
      const targetSocket = callData.callerId === userId 
        ? callData.calleeSocket 
        : callData.callerSocket;

      if (targetSocket && targetSocket.connected) {
        targetSocket.emit('webrtc:ice-candidate', {
          sessionId,
          candidate,
          from: userId
        });
      }

      logger.debug(`🧊 ICE Candidate forwarded: ${sessionId}`);

    } catch (error) {
      logger.error(`❌ ICE candidate error: ${error.message}`);
    }
  }

  /**
   * Gestisce timeout chiamata
   */
  handleCallTimeout(sessionId) {
    const callData = this.activeCalls.get(sessionId);
    if (!callData || callData.status !== 'ringing') {
      return; // Chiamata già gestita
    }

    // Notifica timeout ai partecipanti
    callData.callerSocket.emit('call:timeout', {
      sessionId,
      reason: 'no_answer'
    });

    callData.calleeSocket.emit('call:missed', {
      sessionId,
      callerId: callData.callerId
    });

    // Rimuovi chiamata
    this.activeCalls.delete(sessionId);

    logger.info(`⏰ Call timeout: ${sessionId}`);
  }

  /**
   * Termina tutte le chiamate di un utente
   */
  endUserCalls(userId) {
    for (const [sessionId, callData] of this.activeCalls) {
      if (callData.callerId === userId || callData.calleeId === userId) {
        // Notifica l'altro partecipante
        const otherSocket = callData.callerId === userId 
          ? callData.calleeSocket 
          : callData.callerSocket;

        if (otherSocket && otherSocket.connected) {
          otherSocket.emit('call:ended', {
            sessionId,
            endedBy: userId,
            reason: 'user_disconnected'
          });
        }

        this.activeCalls.delete(sessionId);
        logger.info(`🔌 Call ended due to disconnection: ${sessionId}`);
      }
    }
  }

  /**
   * Ottiene nome utente (mock per ora)
   */
  async getUserName(userId) {
    // TODO: Integrare con database utenti
    const userNames = {
      '2': 'Raffaele Amoroso',
      '3': 'Riccardo Dicamillo'
    };
    return userNames[userId] || `User ${userId}`;
  }

  /**
   * Salva statistiche chiamata
   */
  async saveCallStats(sessionId, stats) {
    try {
      // TODO: Salvare nel database
      logger.info(`📊 Call stats saved: ${sessionId}`, stats);
    } catch (error) {
      logger.error(`❌ Failed to save call stats: ${error.message}`);
    }
  }

  /**
   * Ottiene statistiche signaling
   */
  getStats() {
    return {
      activeCalls: this.activeCalls.size,
      connectedUsers: this.userSockets.size,
      callsByStatus: this.getCallsByStatus()
    };
  }

  /**
   * Raggruppa chiamate per stato
   */
  getCallsByStatus() {
    const stats = {};
    for (const callData of this.activeCalls.values()) {
      stats[callData.status] = (stats[callData.status] || 0) + 1;
    }
    return stats;
  }

  /**
   * Setup crittografia E2E per una chiamata
   */
  setupCallEncryption(sessionId, callerId, calleeId) {
    try {
      // Genera chiavi temporanee per la demo (in produzione verranno dal Signal Protocol)
      const callerKey = crypto.randomBytes(32);
      const calleeKey = crypto.randomBytes(32);
      
      const encryptionInfo = {
        sessionId,
        algorithm: 'SFrame-AES-GCM-256',
        keyRotationInterval: 300000, // 5 minuti
        participants: {
          [callerId]: {
            keyId: 0,
            key: callerKey.toString('base64'),
            lastRotation: Date.now()
          },
          [calleeId]: {
            keyId: 1,
            key: calleeKey.toString('base64'),
            lastRotation: Date.now()
          }
        },
        createdAt: Date.now()
      };

      this.encryptedCalls.set(sessionId, encryptionInfo);

      logger.info(`🔐 Crittografia E2E configurata per chiamata ${sessionId}`);
      
      // Programma rotazione automatica delle chiavi
      this.scheduleKeyRotation(sessionId);

    } catch (error) {
      logger.error(`❌ Errore setup crittografia: ${error.message}`);
    }
  }

  /**
   * Gestisce scambio chiavi di crittografia
   */
  handleKeyExchange(socket, data) {
    try {
      const { sessionId, keyData } = data;
      const userId = socket.userId;

      const callData = this.activeCalls.get(sessionId);
      const encryptionInfo = this.encryptedCalls.get(sessionId);

      if (!callData || !encryptionInfo) {
        socket.emit('encryption:error', {
          error: 'INVALID_SESSION',
          message: 'Sessione non valida per scambio chiavi'
        });
        return;
      }

      // Verifica che l'utente sia partecipante alla chiamata
      if (callData.callerId !== userId && callData.calleeId !== userId) {
        socket.emit('encryption:error', {
          error: 'UNAUTHORIZED',
          message: 'Utente non autorizzato per questa chiamata'
        });
        return;
      }

      // Determina il destinatario
      const targetUserId = callData.callerId === userId ? callData.calleeId : callData.callerId;
      const targetSocket = this.userSockets.get(targetUserId);

      if (targetSocket && targetSocket.connected) {
        // Inoltra i dati di crittografia al destinatario
        targetSocket.emit('encryption:key-exchange', {
          sessionId,
          from: userId,
          keyData: keyData,
          algorithm: encryptionInfo.algorithm
        });

        logger.info(`🔑 Scambio chiavi inoltrato per sessione ${sessionId}`);
      }

    } catch (error) {
      logger.error(`❌ Errore scambio chiavi: ${error.message}`);
      socket.emit('encryption:error', {
        error: 'KEY_EXCHANGE_FAILED',
        message: 'Errore durante lo scambio delle chiavi'
      });
    }
  }

  /**
   * Gestisce rotazione delle chiavi
   */
  handleKeyRotation(socket, data) {
    try {
      const { sessionId, newKeyData } = data;
      const userId = socket.userId;

      const encryptionInfo = this.encryptedCalls.get(sessionId);
      if (!encryptionInfo) {
        socket.emit('encryption:error', {
          error: 'INVALID_SESSION',
          message: 'Sessione non valida per rotazione chiavi'
        });
        return;
      }

      // Aggiorna chiave per l'utente
      if (encryptionInfo.participants[userId]) {
        encryptionInfo.participants[userId].key = newKeyData.key;
        encryptionInfo.participants[userId].keyId += 1;
        encryptionInfo.participants[userId].lastRotation = Date.now();

        logger.info(`🔄 Chiave ruotata per utente ${userId} in sessione ${sessionId}`);

        // Notifica gli altri partecipanti della nuova chiave
        this.broadcastKeyRotation(sessionId, userId, newKeyData);
      }

    } catch (error) {
      logger.error(`❌ Errore rotazione chiavi: ${error.message}`);
    }
  }

  /**
   * Programma rotazione automatica delle chiavi
   */
  scheduleKeyRotation(sessionId) {
    const encryptionInfo = this.encryptedCalls.get(sessionId);
    if (!encryptionInfo) return;

    setTimeout(() => {
      this.rotateAllKeys(sessionId);
    }, encryptionInfo.keyRotationInterval);
  }

  /**
   * Ruota tutte le chiavi di una sessione
   */
  rotateAllKeys(sessionId) {
    try {
      const callData = this.activeCalls.get(sessionId);
      const encryptionInfo = this.encryptedCalls.get(sessionId);

      if (!callData || !encryptionInfo || callData.status !== 'connected') {
        return; // Chiamata terminata o non attiva
      }

      logger.info(`🔄 Rotazione automatica chiavi per sessione ${sessionId}`);

      // Genera nuove chiavi per tutti i partecipanti
      for (const userId of Object.keys(encryptionInfo.participants)) {
        const newKey = crypto.randomBytes(32);
        
        encryptionInfo.participants[userId].key = newKey.toString('base64');
        encryptionInfo.participants[userId].keyId += 1;
        encryptionInfo.participants[userId].lastRotation = Date.now();

        // Notifica il partecipante della nuova chiave
        const userSocket = this.userSockets.get(userId);
        if (userSocket && userSocket.connected) {
          userSocket.emit('encryption:key-rotation', {
            sessionId,
            keyId: encryptionInfo.participants[userId].keyId,
            key: encryptionInfo.participants[userId].key,
            algorithm: encryptionInfo.algorithm
          });
        }
      }

      // Programma prossima rotazione
      this.scheduleKeyRotation(sessionId);

    } catch (error) {
      logger.error(`❌ Errore rotazione automatica chiavi: ${error.message}`);
    }
  }

  /**
   * Notifica rotazione chiave agli altri partecipanti
   */
  broadcastKeyRotation(sessionId, fromUserId, keyData) {
    const callData = this.activeCalls.get(sessionId);
    if (!callData) return;

    // Determina gli altri partecipanti
    const otherParticipants = [callData.callerId, callData.calleeId]
      .filter(id => id !== fromUserId);

    for (const participantId of otherParticipants) {
      const socket = this.userSockets.get(participantId);
      if (socket && socket.connected) {
        socket.emit('encryption:peer-key-rotated', {
          sessionId,
          from: fromUserId,
          keyData
        });
      }
    }
  }

  /**
   * Ottiene informazioni crittografia per una sessione
   */
  getEncryptionInfo(sessionId) {
    const encryptionInfo = this.encryptedCalls.get(sessionId);
    if (!encryptionInfo) return null;

    return {
      algorithm: encryptionInfo.algorithm,
      participantCount: Object.keys(encryptionInfo.participants).length,
      keyRotationInterval: encryptionInfo.keyRotationInterval,
      lastRotations: Object.fromEntries(
        Object.entries(encryptionInfo.participants)
          .map(([userId, info]) => [userId, info.lastRotation])
      )
    };
  }

  /**
   * Pulisce dati crittografia quando la chiamata termina
   */
  cleanupCallEncryption(sessionId) {
    if (this.encryptedCalls.has(sessionId)) {
      this.encryptedCalls.delete(sessionId);
      logger.info(`🧹 Dati crittografia rimossi per sessione ${sessionId}`);
    }
  }
}

module.exports = SignalingService;


/**
 * SecureVox Call Manager - Enterprise Scalable
 * Gestisce sessioni di chiamata distribuite con alta disponibilità
 */

const { v4: uuidv4 } = require('uuid');
const EventEmitter = require('events');
const logger = require('../utils/logger');
const MetricsCollector = require('../utils/metrics');

class CallManager extends EventEmitter {
  constructor() {
    super();
    
    // Per testing, usiamo memoria locale invece di Redis
    this.activeCalls = new Map(); // sessionId -> callData
    this.userCalls = new Map();   // userId -> Set(sessionIds)
    
    // Metriche per monitoring enterprise
    this.metrics = new MetricsCollector();
    
    // Cache locale per performance (L1 cache)
    this.localCache = new Map();
    this.cacheTimeout = 30000; // 30 secondi
    
    // Configurazioni enterprise
    this.config = {
      maxConcurrentCalls: parseInt(process.env.MAX_CONCURRENT_CALLS) || 10000,
      maxCallDuration: parseInt(process.env.MAX_CALL_DURATION) || 7200, // 2 ore
      sessionTimeout: parseInt(process.env.SESSION_TIMEOUT) || 300, // 5 minuti
      heartbeatInterval: parseInt(process.env.HEARTBEAT_INTERVAL) || 30, // 30 secondi
      loadBalancingStrategy: process.env.LOAD_BALANCING || 'round_robin', // round_robin, least_connections, geo_proximity
      replicationFactor: parseInt(process.env.REPLICATION_FACTOR) || 3,
      autoScalingThreshold: parseFloat(process.env.AUTOSCALING_THRESHOLD) || 0.8
    };

    this.serverId = process.env.SERVER_ID || `call-server-${uuidv4().slice(0, 8)}`;
    this.serverRegion = process.env.SERVER_REGION || 'local';
    this.serverZone = process.env.SERVER_ZONE || 'a';
    
    // Inizializzazione semplificata per testing
    this.init();
  }

  async init() {
    try {
      // Setup monitoring e metriche
      this.setupMetrics();
      
      // Avvio cleanup tasks
      this.startCleanupTasks();
      
      logger.info(`🚀 CallManager initialized - Server: ${this.serverId} (${this.serverRegion}-${this.serverZone})`);
      
    } catch (error) {
      logger.error(`❌ CallManager initialization failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Setup Pub/Sub semplificato per testing
   */
  async setupPubSub() {
    // Per testing, usiamo EventEmitter locale
    logger.info('📡 Local event system setup complete');
  }

  /**
   * Crea una nuova sessione di chiamata (Versione semplificata per testing)
   */
  async createCall(callerId, calleeId, callType = 'video', options = {}) {
    const startTime = Date.now();
    
    try {
      const callId = uuidv4();
      const sessionData = {
        id: callId,
        callerId,
        calleeId,
        callType,
        status: 'initializing',
        createdAt: new Date().toISOString(),
        serverId: this.serverId,
        options: {
          encryption: options.encryption || 'aes-256-gcm',
          codec: options.codec || 'opus',
          bitrate: options.bitrate || 128000,
          resolution: options.resolution || '720p',
          ...options
        },
        participants: {
          [callerId]: { status: 'connecting', joinedAt: null },
          [calleeId]: { status: 'invited', joinedAt: null }
        },
        metrics: {
          startTime: Date.now(),
          packetsLost: 0,
          latency: 0,
          quality: 'unknown'
        }
      };

      // Salvataggio in memoria locale
      this.activeCalls.set(callId, sessionData);
      
      // Traccia chiamate per utente
      if (!this.userCalls.has(callerId)) {
        this.userCalls.set(callerId, new Set());
      }
      if (!this.userCalls.has(calleeId)) {
        this.userCalls.set(calleeId, new Set());
      }
      this.userCalls.get(callerId).add(callId);
      this.userCalls.get(calleeId).add(callId);

      // Metriche
      this.metrics.incrementCounter('calls_created_total');
      this.metrics.recordHistogram('call_creation_duration', Date.now() - startTime);

      logger.info(`📞 Call created: ${callId} (${callerId} → ${calleeId})`);
      
      return {
        callId,
        sessionData,
        iceServers: await this.getOptimalIceServers(callerId, calleeId),
        signalingEndpoint: `ws://${process.env.HOST || 'localhost'}:${process.env.PORT || 8001}`,
        turnCredentials: await this.generateTurnCredentials(callId)
      };

    } catch (error) {
      this.metrics.incrementCounter('calls_creation_errors_total');
      logger.error(`❌ Call creation failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Selezione server ottimale per load balancing enterprise
   */
  async selectOptimalServer(callerId, calleeId) {
    try {
      const servers = await this.getActiveServers();
      
      switch (this.config.loadBalancingStrategy) {
        case 'least_connections':
          return this.selectLeastConnectionsServer(servers);
          
        case 'geo_proximity':
          return await this.selectGeoProximityServer(servers, callerId, calleeId);
          
        case 'resource_based':
          return await this.selectResourceBasedServer(servers);
          
        case 'round_robin':
        default:
          return this.selectRoundRobinServer(servers);
      }
      
    } catch (error) {
      logger.warn(`Server selection failed, using current server: ${error.message}`);
      return this.serverId;
    }
  }

  /**
   * Validazione limiti enterprise (rate limiting, quotas)
   */
  async validateCallLimits(callerId, calleeId) {
    const pipeline = this.redis.pipeline();
    
    // Check concurrent calls per user
    const callerCalls = await this.redis.scard(`user:${callerId}:active_calls`);
    const calleeCalls = await this.redis.scard(`user:${calleeId}:active_calls`);
    
    if (callerCalls >= this.config.maxConcurrentCalls) {
      throw new Error(`Caller ${callerId} has reached maximum concurrent calls limit`);
    }
    
    if (calleeCalls >= this.config.maxConcurrentCalls) {
      throw new Error(`Callee ${calleeId} has reached maximum concurrent calls limit`);
    }

    // Check system-wide limits
    const totalActiveCalls = await this.redis.scard('system:active_calls');
    const systemLimit = parseInt(process.env.SYSTEM_MAX_CALLS) || 100000;
    
    if (totalActiveCalls >= systemLimit) {
      throw new Error('System has reached maximum calls capacity');
    }

    // Rate limiting per user
    const callerRate = await this.redis.incr(`rate:${callerId}:calls`);
    if (callerRate === 1) {
      await this.redis.expire(`rate:${callerId}:calls`, 60); // 1 minuto
    }
    
    const maxCallsPerMinute = parseInt(process.env.MAX_CALLS_PER_MINUTE) || 10;
    if (callerRate > maxCallsPerMinute) {
      throw new Error(`Rate limit exceeded for user ${callerId}`);
    }
  }

  /**
   * Salvataggio sessione con replicazione multi-zona
   */
  async saveCallSession(callId, sessionData) {
    const pipeline = this.redis.pipeline();
    
    // Salvataggio primario
    pipeline.hset(`call:${callId}`, sessionData);
    pipeline.expire(`call:${callId}`, this.config.sessionTimeout);
    
    // Indicizzazione per query rapide
    pipeline.sadd(`user:${sessionData.callerId}:active_calls`, callId);
    pipeline.sadd(`user:${sessionData.calleeId}:active_calls`, callId);
    pipeline.sadd(`server:${this.serverId}:calls`, callId);
    pipeline.sadd('system:active_calls', callId);
    
    // Replicazione cross-zona per disaster recovery
    for (let i = 0; i < this.config.replicationFactor; i++) {
      const replicaKey = `call:${callId}:replica:${i}`;
      pipeline.hset(replicaKey, sessionData);
      pipeline.expire(replicaKey, this.config.sessionTimeout * 2);
    }
    
    await pipeline.exec();
  }

  /**
   * Gestione heartbeat e health check distribuito
   */
  startHeartbeat() {
    setInterval(async () => {
      try {
        const serverStats = {
          serverId: this.serverId,
          region: this.serverRegion,
          zone: this.serverZone,
          activeCalls: await this.redis.scard(`server:${this.serverId}:calls`),
          cpuUsage: process.cpuUsage(),
          memoryUsage: process.memoryUsage(),
          uptime: process.uptime(),
          timestamp: Date.now(),
          version: process.env.npm_package_version || '1.0.0'
        };

        // Aggiorna stato server
        await this.redis.hset(`server:${this.serverId}:stats`, serverStats);
        await this.redis.expire(`server:${this.serverId}:stats`, this.config.heartbeatInterval * 3);
        
        // Notifica cluster
        await this.publisher.publish('server:heartbeat', JSON.stringify(serverStats));
        
        // Auto-scaling check
        await this.checkAutoScaling(serverStats);
        
      } catch (error) {
        logger.error(`Heartbeat failed: ${error.message}`);
      }
    }, this.config.heartbeatInterval * 1000);
  }

  /**
   * Auto-scaling enterprise
   */
  async checkAutoScaling(stats) {
    const cpuThreshold = this.config.autoScalingThreshold;
    const memoryThreshold = this.config.autoScalingThreshold;
    
    const cpuUsage = stats.cpuUsage.system / (stats.cpuUsage.user + stats.cpuUsage.system);
    const memoryUsage = stats.memoryUsage.heapUsed / stats.memoryUsage.heapTotal;
    
    if (cpuUsage > cpuThreshold || memoryUsage > memoryThreshold) {
      logger.warn(`🔥 High resource usage detected - CPU: ${(cpuUsage * 100).toFixed(2)}%, Memory: ${(memoryUsage * 100).toFixed(2)}%`);
      
      // Notifica sistema di auto-scaling
      await this.publisher.publish('scaling:event', JSON.stringify({
        type: 'scale_up',
        serverId: this.serverId,
        reason: 'high_resource_usage',
        metrics: { cpuUsage, memoryUsage },
        timestamp: Date.now()
      }));
    }
  }

  /**
   * Registrazione server (versione semplificata)
   */
  async registerServer() {
    const serverInfo = {
      id: this.serverId,
      region: this.serverRegion,
      zone: this.serverZone,
      host: process.env.HOST,
      port: process.env.PORT,
      version: '1.0.0',
      capabilities: ['webrtc', 'signaling'],
      maxCapacity: this.config.maxConcurrentCalls,
      registeredAt: new Date().toISOString()
    };
    
    logger.info(`🌐 Server registered: ${this.serverId} (${this.serverRegion}-${this.serverZone})`);
  }

  /**
   * Cleanup tasks semplificato per testing
   */
  startCleanupTasks() {
    // Cleanup ogni 5 minuti
    setInterval(async () => {
      try {
        await this.cleanupExpiredSessions();
        
      } catch (error) {
        logger.error(`Cleanup task failed: ${error.message}`);
      }
    }, 5 * 60 * 1000);
  }

  // Cleanup methods semplificati
  async cleanupExpiredSessions() {
    try {
      const now = Date.now();
      const expiredCalls = [];
      
      // Trova chiamate scadute (più di 1 ora)
      for (const [callId, callData] of this.activeCalls) {
        if (now - callData.metrics.startTime > 3600000) { // 1 ora
          expiredCalls.push(callId);
        }
      }
      
      // Rimuovi chiamate scadute
      for (const callId of expiredCalls) {
        this.activeCalls.delete(callId);
        logger.info(`🧹 Cleaned up expired call: ${callId}`);
      }
      
      if (expiredCalls.length > 0) {
        logger.info(`🧹 Cleanup completed: ${expiredCalls.length} expired calls removed`);
      }
      
    } catch (error) {
      logger.error(`Cleanup expired sessions failed: ${error.message}`);
    }
  }

  /**
   * Setup metriche per monitoring enterprise
   */
  setupMetrics() {
    // Metriche custom per Prometheus/Grafana
    this.metrics.createCounter('calls_created_total', 'Total calls created');
    this.metrics.createCounter('calls_ended_total', 'Total calls ended');
    this.metrics.createCounter('calls_creation_errors_total', 'Total call creation errors');
    this.metrics.createHistogram('call_creation_duration', 'Call creation duration in ms');
    this.metrics.createHistogram('call_duration', 'Call duration in seconds');
    this.metrics.createGauge('active_calls', 'Current active calls');
    this.metrics.createGauge('server_load', 'Current server load');
    
    // Export metriche ogni 30 secondi
    setInterval(() => {
      this.exportMetrics();
    }, 30000);
  }

  /**
   * Export metriche per monitoring esterno (versione semplificata)
   */
  async exportMetrics() {
    try {
      // Usa dati locali invece di Redis per testing
      const activeCalls = this.activeCalls.size;
      const serverLoad = activeCalls / this.config.maxConcurrentCalls;
      
      this.metrics.setGauge('active_calls', activeCalls);
      this.metrics.setGauge('server_load', serverLoad);
      
      logger.debug(`📊 Metrics exported - Active calls: ${activeCalls}, Load: ${(serverLoad * 100).toFixed(1)}%`);
      
    } catch (error) {
      logger.error(`Metrics export failed: ${error.message}`);
    }
  }

  // Metodi semplificati per testing
  async getOptimalIceServers(callerId, calleeId) {
    // ICE servers di base
    return [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' }
    ];
  }

  async generateTurnCredentials(callId) {
    // Credenziali TURN mock per testing
    return {
      username: `test_${callId}`,
      password: 'test_password',
      ttl: 3600
    };
  }

  async endCall(callId) {
    const callData = this.activeCalls.get(callId);
    if (callData) {
      callData.status = 'ended';
      callData.endedAt = new Date().toISOString();
      
      // Rimuovi dalle chiamate utente
      this.userCalls.get(callData.callerId)?.delete(callId);
      this.userCalls.get(callData.calleeId)?.delete(callId);
      
      // Rimuovi chiamata attiva
      this.activeCalls.delete(callId);
      
      logger.info(`✅ Call ended: ${callId}`);
      return { success: true, duration: Date.now() - callData.metrics.startTime };
    }
    return { success: false, error: 'CALL_NOT_FOUND' };
  }

  async getCallMetrics(callId) {
    const callData = this.activeCalls.get(callId);
    return callData?.metrics || null;
  }

  async getActiveCalls(userId) {
    const userCallIds = this.userCalls.get(userId) || new Set();
    const activeCalls = [];
    
    for (const callId of userCallIds) {
      const callData = this.activeCalls.get(callId);
      if (callData) {
        activeCalls.push(callData);
      }
    }
    
    return activeCalls;
  }
}

module.exports = CallManager;

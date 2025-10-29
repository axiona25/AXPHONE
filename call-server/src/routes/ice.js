/**
 * SecureVox Call Server - ICE Routes
 * API endpoints per server ICE/TURN
 */

const express = require('express');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * GET /api/ice/servers
 * Ottiene configurazione server ICE/TURN per WebRTC
 */
router.get('/servers', async (req, res) => {
  try {
    const user_id = req.user.id;
    const device_id = req.user.deviceId || `device_${user_id}`;

    logger.info(`🧊 Getting ICE servers for user ${user_id}`);

    // Server STUN pubblici (sempre disponibili)
    const stunServers = [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
      { urls: 'stun:stun2.l.google.com:19302' },
      { urls: 'stun:stun.services.mozilla.com' }
    ];

    // Server TURN (se configurati)
    const turnServers = [];
    
    if (process.env.TURN_SERVER_URL && process.env.TURN_USERNAME && process.env.TURN_PASSWORD) {
      const turnUrl = process.env.TURN_SERVER_URL;
      const username = process.env.TURN_USERNAME;
      const password = process.env.TURN_PASSWORD;
      
      // Genera credenziali temporanee per sicurezza
      const timestamp = Math.floor(Date.now() / 1000) + 3600; // Valide per 1 ora
      const tempUsername = `${timestamp}:${user_id}:${device_id}`;
      
      // Genera credenziale HMAC (semplificata per demo)
      const crypto = require('crypto');
      const credential = crypto
        .createHmac('sha1', password)
        .update(tempUsername)
        .digest('base64');

      turnServers.push(
        {
          urls: `turn:${turnUrl}?transport=udp`,
          username: tempUsername,
          credential: credential
        },
        {
          urls: `turn:${turnUrl}?transport=tcp`,
          username: tempUsername,
          credential: credential
        },
        {
          urls: `turns:${turnUrl}?transport=tcp`,
          username: tempUsername,
          credential: credential
        }
      );
    }

    // Combina tutti i server
    const iceServers = [...stunServers, ...turnServers];

    res.json({
      ice_servers: iceServers,
      ttl: 3600, // Tempo di vita in secondi
      generated_at: new Date().toISOString()
    });

    logger.info(`✅ ICE servers provided to user ${user_id}: ${iceServers.length} servers`);

  } catch (error) {
    logger.error(`❌ ICE servers error: ${error.message}`);
    res.status(500).json({
      error: 'INTERNAL_ERROR',
      message: 'Errore nel recupero server ICE'
    });
  }
});

/**
 * POST /api/ice/test
 * Testa connettività ai server ICE/TURN
 */
router.post('/test', async (req, res) => {
  try {
    const { ice_servers } = req.body;
    const user_id = req.user.id;

    logger.info(`🧪 Testing ICE connectivity for user ${user_id}`);

    // Simula test di connettività (in produzione usare librerie WebRTC)
    const testResults = [];

    for (const server of ice_servers || []) {
      const result = {
        url: server.urls,
        status: 'unknown',
        latency: null,
        error: null
      };

      try {
        // Test semplificato - in produzione implementare test reale
        if (server.urls.startsWith('stun:')) {
          result.status = 'reachable';
          result.latency = Math.floor(Math.random() * 100) + 20; // Mock latency
        } else if (server.urls.startsWith('turn:') || server.urls.startsWith('turns:')) {
          result.status = 'reachable';
          result.latency = Math.floor(Math.random() * 150) + 30; // Mock latency
        }
      } catch (testError) {
        result.status = 'unreachable';
        result.error = testError.message;
      }

      testResults.push(result);
    }

    res.json({
      test_results: testResults,
      summary: {
        total: testResults.length,
        reachable: testResults.filter(r => r.status === 'reachable').length,
        unreachable: testResults.filter(r => r.status === 'unreachable').length,
        average_latency: testResults
          .filter(r => r.latency)
          .reduce((sum, r) => sum + r.latency, 0) / 
          testResults.filter(r => r.latency).length || 0
      },
      tested_at: new Date().toISOString()
    });

    logger.info(`✅ ICE connectivity test completed for user ${user_id}`);

  } catch (error) {
    logger.error(`❌ ICE test error: ${error.message}`);
    res.status(500).json({
      error: 'INTERNAL_ERROR',
      message: 'Errore nel test di connettività'
    });
  }
});

/**
 * GET /api/ice/stats
 * Statistiche utilizzo server ICE/TURN
 */
router.get('/stats', async (req, res) => {
  try {
    // Solo admin possono vedere le statistiche globali
    if (req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'FORBIDDEN',
        message: 'Accesso non autorizzato'
      });
    }

    // Mock statistics - in produzione recuperare da database/monitoring
    const stats = {
      stun_usage: {
        total_requests: Math.floor(Math.random() * 10000),
        successful_requests: Math.floor(Math.random() * 9500),
        failed_requests: Math.floor(Math.random() * 500),
        average_response_time: Math.floor(Math.random() * 50) + 20
      },
      turn_usage: {
        total_allocations: Math.floor(Math.random() * 1000),
        active_allocations: Math.floor(Math.random() * 100),
        data_relayed_mb: Math.floor(Math.random() * 50000),
        average_session_duration: Math.floor(Math.random() * 300) + 60
      },
      server_health: {
        stun_servers: [
          { url: 'stun.l.google.com:19302', status: 'healthy', uptime: '99.9%' },
          { url: 'stun1.l.google.com:19302', status: 'healthy', uptime: '99.8%' }
        ],
        turn_servers: [
          { url: process.env.TURN_SERVER_URL || 'localhost:3478', status: 'healthy', uptime: '99.5%' }
        ]
      },
      period: {
        start: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
        end: new Date().toISOString()
      }
    };

    res.json(stats);

    logger.info(`📊 ICE stats provided to admin ${req.user.id}`);

  } catch (error) {
    logger.error(`❌ ICE stats error: ${error.message}`);
    res.status(500).json({
      error: 'INTERNAL_ERROR',
      message: 'Errore nel recupero statistiche'
    });
  }
});

module.exports = router;

